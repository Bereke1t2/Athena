package bookmark

import (
	"context"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"

	domainbookmark "athena/backend/internal/domain/bookmark"
	"athena/backend/internal/domain/research"
)

type memBookmarks struct {
	mu   sync.Mutex
	rows map[uuid.UUID]map[uuid.UUID]domainbookmark.Bookmark
}

func newMemBookmarks() *memBookmarks {
	return &memBookmarks{rows: map[uuid.UUID]map[uuid.UUID]domainbookmark.Bookmark{}}
}

func (m *memBookmarks) Add(_ context.Context, b domainbookmark.Bookmark) (domainbookmark.Bookmark, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	if m.rows[b.UserID] == nil {
		m.rows[b.UserID] = map[uuid.UUID]domainbookmark.Bookmark{}
	}
	if _, exists := m.rows[b.UserID][b.PaperID]; !exists {
		b.CreatedAt = time.Now().UTC()
		m.rows[b.UserID][b.PaperID] = b
	}
	return m.rows[b.UserID][b.PaperID], nil
}

func (m *memBookmarks) Remove(_ context.Context, userID, paperID uuid.UUID) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	delete(m.rows[userID], paperID)
	return nil
}

func (m *memBookmarks) List(_ context.Context, userID uuid.UUID, _ string, limit int) ([]research.PaperSummary, string, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	out := make([]research.PaperSummary, 0, limit)
	for _, b := range m.rows[userID] {
		if len(out) == limit {
			break
		}
		out = append(out, research.PaperSummary{ID: b.PaperID})
	}
	return out, "", nil
}

func TestAddValidation(t *testing.T) {
	svc := NewService(newMemBookmarks())
	ctx := context.Background()

	if _, err := svc.Add(ctx, uuid.New(), uuid.Nil, ""); err == nil {
		t.Fatal("nil paper id must be rejected")
	}
	if _, err := svc.Add(ctx, uuid.New(), uuid.New(), strings.Repeat("x", 2001)); err == nil {
		t.Fatal("oversized note must be rejected")
	}
}

func TestAddIdempotent(t *testing.T) {
	svc := NewService(newMemBookmarks())
	user, paper := uuid.New(), uuid.New()
	ctx := context.Background()

	first, err := svc.Add(ctx, user, paper, "great read")
	if err != nil {
		t.Fatal(err)
	}
	second, err := svc.Add(ctx, user, paper, "")
	if err != nil {
		t.Fatalf("re-add should succeed: %v", err)
	}
	if !first.CreatedAt.Equal(second.CreatedAt) {
		t.Fatal("re-add created a second bookmark row")
	}
	if first.Note != "great read" && second.Note != "" {
		t.Fatalf("note handling unexpected: %q / %q", first.Note, second.Note)
	}
}

func TestRemoveAbsentSucceeds(t *testing.T) {
	svc := NewService(newMemBookmarks())
	if err := svc.Remove(context.Background(), uuid.New(), uuid.New()); err != nil {
		t.Fatalf("removing absent bookmark: %v", err)
	}
}

func TestListClampsLimit(t *testing.T) {
	svc := NewService(newMemBookmarks())
	user := uuid.New()
	ctx := context.Background()
	for i := 0; i < 5; i++ {
		if _, err := svc.Add(ctx, user, uuid.New(), ""); err != nil {
			t.Fatal(err)
		}
	}
	papers, _, err := svc.List(ctx, user, "", 0) // 0 -> default 20
	if err != nil {
		t.Fatal(err)
	}
	if len(papers) != 5 {
		t.Fatalf("got %d papers", len(papers))
	}
}
