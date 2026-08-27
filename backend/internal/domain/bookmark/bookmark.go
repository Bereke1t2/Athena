// Package bookmark
//
// Domain: saved-paper bookmarks. One row per (user, paper); notes optional.
package bookmark

import (
	"context"
	"errors"
	"time"

	"github.com/google/uuid"

	"athena/backend/internal/domain/research"
)

// Sentinel errors mapped by delivery/application layers.
var (
	// ErrNotFound means no such bookmark (or the referenced paper is gone).
	ErrNotFound = errors.New("bookmark: not found")
)

// Bookmark is one saved-paper record.
type Bookmark struct {
	UserID    uuid.UUID
	PaperID   uuid.UUID
	Note      string
	CreatedAt time.Time
}

// Store persists bookmarks ordered newest-first for listing.
type Store interface {
	// Add saves a paper. Adding an existing pair is a no-op (idempotent).
	Add(ctx context.Context, b Bookmark) (Bookmark, error)
	// Remove deletes the pair; removing an absent bookmark is not an error.
	Remove(ctx context.Context, userID, paperID uuid.UUID) error
	// List returns one keyset page of bookmarked papers, newest first.
	List(ctx context.Context, userID uuid.UUID, cursor string, limit int) ([]research.PaperSummary, string, error)
}
