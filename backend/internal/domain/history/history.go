// Package history defines domain models and store interfaces for user reading history
// and reading progress tracking.
package history

import (
	"context"
	"errors"
	"time"

	"github.com/google/uuid"

	"athena/backend/internal/domain/research"
)

var (
	// ErrNotFound is returned when reading progress is not found.
	ErrNotFound = errors.New("history: not found")
	// ErrInvalidInput marks malformed inputs.
	ErrInvalidInput = errors.New("history: invalid input")
)

// ReadingProgress represents a user's reading position in a paper.
type ReadingProgress struct {
	UserID          uuid.UUID
	PaperID         uuid.UUID
	ProgressPercent float64
	Completed       bool
	LastReadAt      time.Time
}

// HistoryEntry is a reading history record paired with the paper summary.
type HistoryEntry struct {
	Paper           research.PaperSummary
	ProgressPercent float64
	Completed       bool
	LastReadAt      time.Time
}

// Store persists reading progress and history.
type Store interface {
	// RecordProgress creates or updates progress for a paper.
	RecordProgress(ctx context.Context, p ReadingProgress) (ReadingProgress, error)
	// GetProgress retrieves the progress for a specific paper.
	GetProgress(ctx context.Context, userID, paperID uuid.UUID) (ReadingProgress, error)
	// ListHistory lists reading history for a user, newest first.
	ListHistory(ctx context.Context, userID uuid.UUID, cursor string, limit int) ([]HistoryEntry, string, error)
	// ClearHistory removes reading history for a user.
	ClearHistory(ctx context.Context, userID uuid.UUID) error
}
