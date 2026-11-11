// Package mail provides transactional and digest email delivery adapters.
package mail

import (
	"bytes"
	"context"
	"crypto/tls"
	"encoding/base64"
	"errors"
	"fmt"
	"log/slog"
	"mime/multipart"
	"net"
	"net/smtp"
	"net/textproto"
	"strings"
	"sync"
	"time"
)

var (
	ErrInvalidRecipient = errors.New("mail: invalid or empty recipient")
	ErrEmptySubject     = errors.New("mail: empty subject")
	ErrEmptyBody        = errors.New("mail: both text and html bodies are empty")
)

// Message encapsulates an outbound email.
type Message struct {
	To       string
	Subject  string
	TextBody string
	HTMLBody string
}

// Sender delivers outbound emails.
type Sender interface {
	Send(ctx context.Context, msg Message) error
}

// ---- NoopSender -------------------------------------------------------------

type NoopSender struct{}

func (s *NoopSender) Send(_ context.Context, _ Message) error {
	return nil
}

// ---- LoggingSender ----------------------------------------------------------

type LoggingSender struct {
	Logger *slog.Logger
	From   string
}

func (s *LoggingSender) Send(_ context.Context, msg Message) error {
	if strings.TrimSpace(msg.To) == "" {
		return ErrInvalidRecipient
	}
	logger := s.Logger
	if logger == nil {
		logger = slog.Default()
	}
	logger.Info("email dispatched (logging mode)",
		"from", s.From,
		"to", msg.To,
		"subject", msg.Subject,
		"has_text", msg.TextBody != "",
		"has_html", msg.HTMLBody != "",
	)
	return nil
}

// ---- MockSender -------------------------------------------------------------

type MockSender struct {
	mu       sync.Mutex
	messages []Message
}

func NewMockSender() *MockSender {
	return &MockSender{messages: make([]Message, 0)}
}

func (m *MockSender) Send(_ context.Context, msg Message) error {
	if strings.TrimSpace(msg.To) == "" {
		return ErrInvalidRecipient
	}
	if strings.TrimSpace(msg.Subject) == "" {
		return ErrEmptySubject
	}
	if msg.TextBody == "" && msg.HTMLBody == "" {
		return ErrEmptyBody
	}

	m.mu.Lock()
	defer m.mu.Unlock()
	m.messages = append(m.messages, msg)
	return nil
}

func (m *MockSender) Messages() []Message {
	m.mu.Lock()
	defer m.mu.Unlock()
	out := make([]Message, len(m.messages))
	copy(out, m.messages)
	return out
}

func (m *MockSender) Last() *Message {
	m.mu.Lock()
	defer m.mu.Unlock()
	if len(m.messages) == 0 {
		return nil
	}
	msg := m.messages[len(m.messages)-1]
	return &msg
}

func (m *MockSender) Reset() {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.messages = m.messages[:0]
}

// ---- SMTPSender -------------------------------------------------------------

type SMTPSender struct {
	Host     string
	Port     int
	Username string
	Password string
	From     string
	Logger   *slog.Logger
}

func (s *SMTPSender) Send(ctx context.Context, msg Message) error {
	if strings.TrimSpace(msg.To) == "" {
		return ErrInvalidRecipient
	}
	if strings.TrimSpace(msg.Subject) == "" {
		return ErrEmptySubject
	}
	if msg.TextBody == "" && msg.HTMLBody == "" {
		return ErrEmptyBody
	}

	addr := net.JoinHostPort(s.Host, fmt.Sprintf("%d", s.Port))

	var auth smtp.Auth
	if s.Username != "" {
		auth = smtp.PlainAuth("", s.Username, s.Password, s.Host)
	}

	mimePayload, err := s.buildMIME(msg)
	if err != nil {
		return fmt.Errorf("build mime: %w", err)
	}

	type result struct {
		err error
	}
	resCh := make(chan result, 1)

	go func() {
		err := s.sendMail(addr, auth, s.From, []string{msg.To}, mimePayload)
		resCh <- result{err: err}
	}()

	select {
	case <-ctx.Done():
		return ctx.Err()
	case res := <-resCh:
		return res.err
	}
}

func (s *SMTPSender) sendMail(addr string, a smtp.Auth, from string, to []string, msg []byte) error {
	// If port is 465 (SMTPS), dial TLS directly
	if s.Port == 465 {
		tlsConfig := &tls.Config{ServerName: s.Host}
		conn, err := tls.Dial("tcp", addr, tlsConfig)
		if err != nil {
			return fmt.Errorf("tls dial: %w", err)
		}
		defer conn.Close()

		client, err := smtp.NewClient(conn, s.Host)
		if err != nil {
			return fmt.Errorf("smtp client: %w", err)
		}
		defer client.Close()

		if a != nil {
			if ok, _ := client.Extension("AUTH"); ok {
				if err = client.Auth(a); err != nil {
					return fmt.Errorf("smtp auth: %w", err)
				}
			}
		}

		if err = client.Mail(from); err != nil {
			return fmt.Errorf("mail from: %w", err)
		}
		for _, addr := range to {
			if err = client.Rcpt(addr); err != nil {
				return fmt.Errorf("rcpt to: %w", err)
			}
		}

		w, err := client.Data()
		if err != nil {
			return fmt.Errorf("data: %w", err)
		}
		if _, err = w.Write(msg); err != nil {
			return fmt.Errorf("write msg: %w", err)
		}
		if err = w.Close(); err != nil {
			return fmt.Errorf("close writer: %w", err)
		}
		return client.Quit()
	}

	return smtp.SendMail(addr, a, from, to, msg)
}

func (s *SMTPSender) buildMIME(msg Message) ([]byte, error) {
	var buf bytes.Buffer
	buf.WriteString(fmt.Sprintf("From: %s\r\n", s.From))
	buf.WriteString(fmt.Sprintf("To: %s\r\n", msg.To))
	buf.WriteString(fmt.Sprintf("Subject: %s\r\n", encodeRFC2047(msg.Subject)))
	buf.WriteString("MIME-Version: 1.0\r\n")
	buf.WriteString(fmt.Sprintf("Date: %s\r\n", time.Now().UTC().Format(time.RFC1123Z)))

	if msg.HTMLBody != "" && msg.TextBody != "" {
		writer := multipart.NewWriter(&buf)
		buf.WriteString(fmt.Sprintf("Content-Type: multipart/alternative; boundary=%s\r\n\r\n", writer.Boundary()))

		// Text part
		textHeader := textproto.MIMEHeader{
			"Content-Type":              {"text/plain; charset=UTF-8"},
			"Content-Transfer-Encoding": {"quoted-printable"},
		}
		part, err := writer.CreatePart(textHeader)
		if err != nil {
			return nil, err
		}
		if _, err = part.Write([]byte(msg.TextBody)); err != nil {
			return nil, err
		}

		// HTML part
		htmlHeader := textproto.MIMEHeader{
			"Content-Type":              {"text/html; charset=UTF-8"},
			"Content-Transfer-Encoding": {"quoted-printable"},
		}
		part, err = writer.CreatePart(htmlHeader)
		if err != nil {
			return nil, err
		}
		if _, err = part.Write([]byte(msg.HTMLBody)); err != nil {
			return nil, err
		}

		if err = writer.Close(); err != nil {
			return nil, err
		}
	} else if msg.HTMLBody != "" {
		buf.WriteString("Content-Type: text/html; charset=UTF-8\r\n\r\n")
		buf.WriteString(msg.HTMLBody)
	} else {
		buf.WriteString("Content-Type: text/plain; charset=UTF-8\r\n\r\n")
		buf.WriteString(msg.TextBody)
	}

	return buf.Bytes(), nil
}

func encodeRFC2047(s string) string {
	for i := 0; i < len(s); i++ {
		if s[i] > 127 {
			return fmt.Sprintf("=?UTF-8?B?%s?=", base64.StdEncoding.EncodeToString([]byte(s)))
		}
	}
	return s
}
