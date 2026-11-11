// Package mail provides transactional and digest email delivery adapters.
package mail

import (
	"context"
	"errors"
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
