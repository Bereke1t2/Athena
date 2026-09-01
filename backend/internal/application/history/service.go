// Package history implements reading history and progress tracking use cases.
package history

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"

	domainhistory "athena/backend/internal/domain/history"
)

// Service manages paper reading progress.
type Service struct {
	store domainhistory.Store
}

// NewService constructs a history service.
func NewService(store domainhistory.Store) *Service {
	return &Service{store: store}
}

// RecordProgress updates or creates reading progress for a paper.
func (s *Service) RecordProgress(ctx context.Context, userID, paperID uuid.UUID, percent float64) (domainhistory.ReadingProgress, error) {
	if userID == uuid.Nil || paperID == uuid.Nil {
		return domainhistory.ReadingProgress{}, fmt.Errorf("%w: user_id and paper_id are required", domainhistory.ErrInvalidInput)
	}
	if percent < 0 {
		percent = 0
	}
	if percent > 100 {
		percent = 100
	}
	completed := percent >= 90.0

	p := domainhistory.ReadingProgress{
		UserID:          userID,
		PaperID:         paperID,
		ProgressPercent: percent,
		Completed:       completed,
		LastReadAt:      time.Now().UTC(),
	}

	return s.store.RecordProgress(ctx, p)
}

// GetProgress returns reading progress for a given paper.
func (s *Service) GetProgress(ctx context.Context, userID, paperID uuid.UUID) (domainhistory.ReadingProgress, error) {
	if userID == uuid.Nil || paperID == uuid.Nil {
		return domainhistory.ReadingProgress{}, fmt.Errorf("%w: user_id and paper_id are required", domainhistory.ErrInvalidInput)
	}
	return s.store.GetProgress(ctx, userID, paperID)
}

// ListHistory returns the user's reading history, newest first.
func (s *Service) ListHistory(ctx context.Context, userID uuid.UUID, cursor string, limit int) ([]domainhistory.HistoryEntry, string, error) {
	if userID == uuid.Nil {
		return nil, "", fmt.Errorf("%w: user_id is required", domainhistory.ErrInvalidInput)
	}
	if limit <= 0 {
		limit = 20
	}
	if limit > 100 {
		limit = 100
	}
	return s.store.ListHistory(ctx, userID, cursor, limit)
}

// ClearHistory clears all reading history for the user.
func (s *Service) ClearHistory(ctx context.Context, userID uuid.UUID) error {
	if userID == uuid.Nil {
		return fmt.Errorf("%w: user_id is required", domainhistory.ErrInvalidInput)
	}
	return s.store.ClearHistory(ctx, userID)
}
