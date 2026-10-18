package history_test

import (
	"context"
	"errors"
	"testing"

	"github.com/google/uuid"

	apphistory "athena/backend/internal/application/history"
	domainhistory "athena/backend/internal/domain/history"
	"athena/backend/internal/domain/research"
)

type mockHistoryStore struct {
	progress map[uuid.UUID]map[uuid.UUID]domainhistory.ReadingProgress
}

func newMockHistoryStore() *mockHistoryStore {
	return &mockHistoryStore{
		progress: make(map[uuid.UUID]map[uuid.UUID]domainhistory.ReadingProgress),
	}
}

func (m *mockHistoryStore) RecordProgress(ctx context.Context, p domainhistory.ReadingProgress) (domainhistory.ReadingProgress, error) {
	if m.progress[p.UserID] == nil {
		m.progress[p.UserID] = make(map[uuid.UUID]domainhistory.ReadingProgress)
	}
	m.progress[p.UserID][p.PaperID] = p
	return p, nil
}

func (m *mockHistoryStore) GetProgress(ctx context.Context, userID, paperID uuid.UUID) (domainhistory.ReadingProgress, error) {
	if m.progress[userID] == nil {
		return domainhistory.ReadingProgress{}, domainhistory.ErrNotFound
	}
	p, ok := m.progress[userID][paperID]
	if !ok {
		return domainhistory.ReadingProgress{}, domainhistory.ErrNotFound
	}
	return p, nil
}

func (m *mockHistoryStore) ListHistory(ctx context.Context, userID uuid.UUID, cursor string, limit int) ([]domainhistory.HistoryEntry, string, error) {
	out := make([]domainhistory.HistoryEntry, 0)
	if m.progress[userID] != nil {
		for _, p := range m.progress[userID] {
			out = append(out, domainhistory.HistoryEntry{
				Paper: research.PaperSummary{
					ID:    p.PaperID,
					Title: "Sample paper",
				},
				ProgressPercent: p.ProgressPercent,
				Completed:       p.Completed,
				LastReadAt:      p.LastReadAt,
			})
		}
	}
	return out, "", nil
}

func (m *mockHistoryStore) ClearHistory(ctx context.Context, userID uuid.UUID) error {
	delete(m.progress, userID)
	return nil
}

func TestHistoryService(t *testing.T) {
	ctx := context.Background()
	store := newMockHistoryStore()
	svc := apphistory.NewService(store)
	userID := uuid.New()
	paperID := uuid.New()

	// Validation
	if _, err := svc.RecordProgress(ctx, uuid.Nil, paperID, 50); !errors.Is(err, domainhistory.ErrInvalidInput) {
		t.Fatalf("expected ErrInvalidInput for nil user, got %v", err)
	}
	if _, err := svc.RecordProgress(ctx, userID, uuid.Nil, 50); !errors.Is(err, domainhistory.ErrInvalidInput) {
		t.Fatalf("expected ErrInvalidInput for nil paper, got %v", err)
	}

	// Record progress
	p, err := svc.RecordProgress(ctx, userID, paperID, 95.0)
	if err != nil {
		t.Fatalf("RecordProgress failed: %v", err)
	}
	if !p.Completed {
		t.Fatalf("expected completed=true for 95%% progress")
	}

	// Get progress
	p2, err := svc.GetProgress(ctx, userID, paperID)
	if err != nil {
		t.Fatalf("GetProgress failed: %v", err)
	}
	if p2.ProgressPercent != 95.0 {
		t.Fatalf("expected progress 95.0, got %f", p2.ProgressPercent)
	}

	// List history
	list, _, err := svc.ListHistory(ctx, userID, "", 20)
	if err != nil || len(list) != 1 {
		t.Fatalf("expected 1 history entry, got %d (err: %v)", len(list), err)
	}

	// Clear history
	if err := svc.ClearHistory(ctx, userID); err != nil {
		t.Fatalf("ClearHistory failed: %v", err)
	}

	listAfter, _, _ := svc.ListHistory(ctx, userID, "", 20)
	if len(listAfter) != 0 {
		t.Fatalf("expected 0 entries after clear, got %d", len(listAfter))
	}
}
