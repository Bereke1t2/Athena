package mail

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	domaindigest "athena/backend/internal/domain/digest"
	"athena/backend/internal/domain/research"
	domainuser "athena/backend/internal/domain/user"
)

func TestMockSender(t *testing.T) {
	m := NewMockSender()
	assert.Empty(t, m.Messages())
	assert.Nil(t, m.Last())

	// Validation
	err := m.Send(context.Background(), Message{})
	require.ErrorIs(t, err, ErrInvalidRecipient)

	err = m.Send(context.Background(), Message{To: "ada@athena.dev"})
	require.ErrorIs(t, err, ErrEmptySubject)

	err = m.Send(context.Background(), Message{To: "ada@athena.dev", Subject: "Hi"})
	require.ErrorIs(t, err, ErrEmptyBody)

	// Valid Send
	msg := Message{
		To:       "ada@athena.dev",
		Subject:  "Test Subject",
		TextBody: "Hello Text",
		HTMLBody: "<p>Hello HTML</p>",
	}
	err = m.Send(context.Background(), msg)
	require.NoError(t, err)

	assert.Len(t, m.Messages(), 1)
	assert.Equal(t, "ada@athena.dev", m.Last().To)
	assert.Equal(t, "Test Subject", m.Last().Subject)

	m.Reset()
	assert.Empty(t, m.Messages())
	assert.Nil(t, m.Last())
}

func TestNoopAndLoggingSenders(t *testing.T) {
	noop := &NoopSender{}
	err := noop.Send(context.Background(), Message{To: "ada@athena.dev", Subject: "Hi", TextBody: "Body"})
	assert.NoError(t, err)

	logging := &LoggingSender{From: "noreply@athena.dev"}
	err = logging.Send(context.Background(), Message{To: "ada@athena.dev", Subject: "Hi", TextBody: "Body"})
	assert.NoError(t, err)

	err = logging.Send(context.Background(), Message{})
	assert.ErrorIs(t, err, ErrInvalidRecipient)
}

func TestSMTPSenderBuildMIME(t *testing.T) {
	s := &SMTPSender{
		Host: "localhost",
		Port: 587,
		From: "Athena <briefing@athena.dev>",
	}

	msg := Message{
		To:       "researcher@athena.dev",
		Subject:  "🔬 Breakthrough in Deep Learning",
		TextBody: "Hello plain world",
		HTMLBody: "<h1>Hello HTML world</h1>",
	}

	raw, err := s.buildMIME(msg)
	require.NoError(t, err)

	str := string(raw)
	assert.Contains(t, str, "From: Athena <briefing@athena.dev>")
	assert.Contains(t, str, "To: researcher@athena.dev")
	assert.Contains(t, str, "Subject: =?UTF-8?B?") // RFC 2047 encoded due to emoji
	assert.Contains(t, str, "multipart/alternative")
	assert.Contains(t, str, "text/plain; charset=UTF-8")
	assert.Contains(t, str, "text/html; charset=UTF-8")
	assert.Contains(t, str, "Hello plain world")
	assert.Contains(t, str, "<h1>Hello HTML world</h1>")
}

