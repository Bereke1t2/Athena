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

func TestRenderDigestEmail(t *testing.T) {
	user := domainuser.User{
		ID:          uuid.New(),
		Email:       "ada@athena.dev",
		DisplayName: "Ada Lovelace",
	}

	paperID := uuid.New()
	digest := domaindigest.UserDigest{
		ID:          uuid.New(),
		UserID:      user.ID,
		GeneratedAt: time.Date(2026, 11, 11, 0, 0, 0, 0, time.UTC),
		Frequency:   domaindigest.FrequencyWeekly,
		AISummary:   "This week witnessed major advances in diffusion models for protein design.\n\nResearchers demonstrated zero-shot generalization on novel scaffolds.",
		TopTakeaways: []string{
			"Structure prediction achieved sub-angstrom accuracy across 42 targets.",
			"In-context learning emerged in small parameter models with curriculum pruning.",
		},
		Sections: []domaindigest.DigestSection{
			{
				Title:       "Machine Learning in Biology",
				Description: "Frontier advances bridging deep learning and structural biology.",
				Papers: []research.PaperSummary{
					{
						ID:           paperID,
						Title:        "De Novo Protein Design via Latent Diffusion",
						Year:         2026,
						VenueName:    "Nature Machine Intelligence",
						CitedByCount: 14,
						IsOpenAccess: true,
					},
				},
			},
		},
		Pulses: []domaindigest.TopicPulse{
			{
				TopicName:  "Computational Biology",
				PaperCount: 18,
				KeyThemes:  []string{"Diffusion", "Folding"},
			},
		},
	}

	subject, text, htmlBody, err := RenderDigestEmail(user, digest, "https://athena.dev")
	require.NoError(t, err)

	assert.Contains(t, subject, "Athena Weekly Briefing")
	assert.Contains(t, subject, "Nov 11, 2026")

	// Verify plaintext contents
	assert.Contains(t, text, "Ada Lovelace")
	assert.Contains(t, text, "EXECUTIVE AI SYNTHESIS")
	assert.Contains(t, text, "De Novo Protein Design via Latent Diffusion")
	assert.Contains(t, text, "Structure prediction achieved sub-angstrom accuracy")
	assert.Contains(t, text, "https://athena.dev/papers/"+paperID.String())

	// Verify HTML contents
	assert.Contains(t, htmlBody, "Ada Lovelace")
	assert.Contains(t, htmlBody, "Executive AI Weekly Synthesis")
	assert.Contains(t, htmlBody, "De Novo Protein Design via Latent Diffusion")
	assert.Contains(t, htmlBody, "OPEN ACCESS")
	assert.Contains(t, htmlBody, "https://athena.dev/papers/"+paperID.String())
	assert.Contains(t, htmlBody, "Delivered to ada@athena.dev")
}

