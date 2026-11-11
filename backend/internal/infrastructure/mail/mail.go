// Package mail provides transactional and digest email delivery adapters.
package mail

import (
	"context"
	"errors"
	"log/slog"
	"strings"
	"sync"
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
