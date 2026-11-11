// Package mail provides transactional and digest email delivery adapters.
package mail

import (
	"context"
	"errors"
	"log/slog"
	"strings"
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
