package digest

import (
	"context"
	"errors"
	"time"

	"github.com/google/uuid"

	"athena/backend/internal/domain/research"
)

var (
	ErrDigestNotFound  = errors.New("digest not found")
	ErrInvalidUserID   = errors.New("invalid user id for digest")
	ErrFrequencyInvalid = errors.New("invalid digest frequency")
)

// Frequency represents how often a digest is generated.
type Frequency string

const (
	FrequencyDaily  Frequency = "daily"
	FrequencyWeekly Frequency = "weekly"
)

// TopicPulse captures momentum and key themes within a specific topic area.
type TopicPulse struct {
	TopicSlug  string   `json:"topic_slug"`
	TopicName  string   `json:"topic_name"`
	PaperCount int      `json:"paper_count"`
	Velocity   float64  `json:"velocity"`
	KeyThemes  []string `json:"key_themes"`
}

// DigestSection groups curated papers under a specific narrative theme.
type DigestSection struct {
	Title       string                  `json:"title"`
	Description string                  `json:"description"`
	Papers      []research.PaperSummary `json:"papers"`
}

// UserDigest is a structured, personalized research briefing for a user.
type UserDigest struct {
	ID           uuid.UUID       `json:"id"`
	UserID       uuid.UUID       `json:"user_id"`
	GeneratedAt  time.Time       `json:"generated_at"`
	Frequency    Frequency       `json:"frequency"`
	Pulses       []TopicPulse    `json:"pulses"`
	Sections     []DigestSection `json:"sections"`
	TopTakeaways []string        `json:"top_takeaways"`
}

// DigestRepository manages persistence and retrieval of generated digests.
type DigestRepository interface {
	SaveDigest(ctx context.Context, d UserDigest) error
	GetLatestDigest(ctx context.Context, userID uuid.UUID) (UserDigest, error)
	ListDigests(ctx context.Context, userID uuid.UUID, limit int) ([]UserDigest, error)
}
