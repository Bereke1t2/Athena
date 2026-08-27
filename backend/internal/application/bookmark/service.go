// Package bookmark implements saved-paper use cases on top of the
// domain bookmark store. All methods require an authenticated user; the
// HTTP layer enforces that and injects the account.
package bookmark

import (
	"context"
	"errors"
	"fmt"

	"github.com/google/uuid"

	domainbookmark "athena/backend/internal/domain/bookmark"
	"athena/backend/internal/domain/research"
)

// ErrInvalidInput marks malformed requests (nil paper id, oversized note).
var ErrInvalidInput = errors.New("bookmark: invalid input")

const maxNoteLength = 2000

// Service wires the store with request validation.
type Service struct {
	store domainbookmark.Store
}

func NewService(store domainbookmark.Store) *Service { return &Service{store: store} }

// Add saves a paper for the user. Idempotent on repeats.
func (s *Service) Add(ctx context.Context, userID, paperID uuid.UUID, note string) (domainbookmark.Bookmark, error) {
	if paperID == uuid.Nil {
		return domainbookmark.Bookmark{}, fmt.Errorf("%w: paper_id required", ErrInvalidInput)
	}
	if len(note) > maxNoteLength {
		return domainbookmark.Bookmark{}, fmt.Errorf("%w: note exceeds %d characters", ErrInvalidInput, maxNoteLength)
	}
	b, err := s.store.Add(ctx, domainbookmark.Bookmark{
		UserID: userID, PaperID: paperID, Note: note,
	})
	if err != nil {
		return domainbookmark.Bookmark{}, err
	}
	return b, nil
}

// Remove unsaves a paper; absent bookmarks still succeed.
func (s *Service) Remove(ctx context.Context, userID, paperID uuid.UUID) error {
	if paperID == uuid.Nil {
		return fmt.Errorf("%w: paper_id required", ErrInvalidInput)
	}
	return s.store.Remove(ctx, userID, paperID)
}

// List returns one page of the user's bookmarks, newest first.
func (s *Service) List(ctx context.Context, userID uuid.UUID, cursor string, limit int) ([]research.PaperSummary, string, error) {
	if limit <= 0 {
		limit = 20
	}
	if limit > 100 {
		limit = 100
	}
	return s.store.List(ctx, userID, cursor, limit)
}
