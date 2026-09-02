package v1

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/google/uuid"

	apphistory "athena/backend/internal/application/history"
	domainhistory "athena/backend/internal/domain/history"
	"athena/backend/internal/domain/research"
	domainuser "athena/backend/internal/domain/user"
)

type fakeHistoryDeliveryStore struct {
	progress map[uuid.UUID]map[uuid.UUID]domainhistory.ReadingProgress
}

func newFakeHistoryDeliveryStore() *fakeHistoryDeliveryStore {
	return &fakeHistoryDeliveryStore{
		progress: make(map[uuid.UUID]map[uuid.UUID]domainhistory.ReadingProgress),
	}
}

func (f *fakeHistoryDeliveryStore) RecordProgress(ctx context.Context, p domainhistory.ReadingProgress) (domainhistory.ReadingProgress, error) {
	if f.progress[p.UserID] == nil {
		f.progress[p.UserID] = make(map[uuid.UUID]domainhistory.ReadingProgress)
	}
	f.progress[p.UserID][p.PaperID] = p
	return p, nil
}

func (f *fakeHistoryDeliveryStore) GetProgress(ctx context.Context, userID, paperID uuid.UUID) (domainhistory.ReadingProgress, error) {
	if f.progress[userID] == nil {
		return domainhistory.ReadingProgress{}, domainhistory.ErrNotFound
	}
	p, ok := f.progress[userID][paperID]
	if !ok {
		return domainhistory.ReadingProgress{}, domainhistory.ErrNotFound
	}
	return p, nil
}

func (f *fakeHistoryDeliveryStore) ListHistory(ctx context.Context, userID uuid.UUID, cursor string, limit int) ([]domainhistory.HistoryEntry, string, error) {
	out := make([]domainhistory.HistoryEntry, 0)
	if f.progress[userID] != nil {
		for _, p := range f.progress[userID] {
			out = append(out, domainhistory.HistoryEntry{
				Paper: research.PaperSummary{
					ID:    p.PaperID,
					Title: "History paper",
				},
				ProgressPercent: p.ProgressPercent,
				Completed:       p.Completed,
				LastReadAt:      p.LastReadAt,
			})
		}
	}
	return out, "", nil
}

func (f *fakeHistoryDeliveryStore) ClearHistory(ctx context.Context, userID uuid.UUID) error {
	delete(f.progress, userID)
	return nil
}

func historyTestHandler() (*HistoryHandlers, *fakeHistoryDeliveryStore) {
	store := newFakeHistoryDeliveryStore()
	return NewHistoryHandlers(apphistory.NewService(store), testLogger()), store
}

func TestHistoryRequireAuth(t *testing.T) {
	h, _ := historyTestHandler()

	w := httptest.NewRecorder()
	h.RecordProgress(w, httptest.NewRequest(http.MethodPost, "/api/v1/me/history/progress", strings.NewReader("{}")))
	if w.Code != http.StatusUnauthorized {
		t.Fatalf("anonymous record progress: %d", w.Code)
	}

	w = httptest.NewRecorder()
	h.List(w, httptest.NewRequest(http.MethodGet, "/api/v1/me/history", nil))
	if w.Code != http.StatusUnauthorized {
		t.Fatalf("anonymous list history: %d", w.Code)
	}
}

func TestHistoryFlow(t *testing.T) {
	h, _ := historyTestHandler()
	userID := uuid.New()
	paperID := uuid.New()
	userCtx := context.WithValue(context.Background(), userKey{}, domainuser.User{ID: userID})

	// Record progress
	reqBody := `{"paper_id":"` + paperID.String() + `","progress_percent":85.5}`
	r1 := httptest.NewRequest(http.MethodPost, "/api/v1/me/history/progress", strings.NewReader(reqBody)).WithContext(userCtx)
	w1 := httptest.NewRecorder()
	h.RecordProgress(w1, r1)
	if w1.Code != http.StatusOK {
		t.Fatalf("record progress status: %d: %s", w1.Code, w1.Body.String())
	}
	var prog progressResponseDTO
	if err := json.Unmarshal(w1.Body.Bytes(), &prog); err != nil || prog.ProgressPercent != 85.5 {
		t.Fatalf("expected progress 85.5, got %+v", prog)
	}

	// Get progress
	r2 := httptest.NewRequest(http.MethodGet, "/api/v1/me/history/progress/"+paperID.String(), nil).WithContext(userCtx)
	r2.SetPathValue("paperId", paperID.String())
	w2 := httptest.NewRecorder()
	h.GetProgress(w2, r2)
	if w2.Code != http.StatusOK {
		t.Fatalf("get progress status: %d: %s", w2.Code, w2.Body.String())
	}

	// List history
	r3 := httptest.NewRequest(http.MethodGet, "/api/v1/me/history", nil).WithContext(userCtx)
	w3 := httptest.NewRecorder()
	h.List(w3, r3)
	if w3.Code != http.StatusOK {
		t.Fatalf("list history status: %d: %s", w3.Code, w3.Body.String())
	}
	var listResp historyListResponseDTO
	if err := json.Unmarshal(w3.Body.Bytes(), &listResp); err != nil || len(listResp.Items) != 1 {
		t.Fatalf("expected 1 item, got %+v", listResp)
	}

	// Clear history
	r4 := httptest.NewRequest(http.MethodDelete, "/api/v1/me/history", nil).WithContext(userCtx)
	w4 := httptest.NewRecorder()
	h.Clear(w4, r4)
	if w4.Code != http.StatusNoContent {
		t.Fatalf("clear history status: %d", w4.Code)
	}
}
