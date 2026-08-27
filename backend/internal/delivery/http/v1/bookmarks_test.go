package v1

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"

	appbookmark "athena/backend/internal/application/bookmark"
	domainbookmark "athena/backend/internal/domain/bookmark"
	"athena/backend/internal/domain/research"
	domainuser "athena/backend/internal/domain/user"
)

func fixedTime() time.Time { return time.Date(2026, 8, 26, 12, 0, 0, 0, time.UTC) }

type fakeBookmarkStore struct {
	mu      sync.Mutex
	rows    map[uuid.UUID]map[uuid.UUID]domainbookmark.Bookmark
	nextAdd error
}

func newFakeBookmarkStore() *fakeBookmarkStore {
	return &fakeBookmarkStore{rows: map[uuid.UUID]map[uuid.UUID]domainbookmark.Bookmark{}}
}

func (f *fakeBookmarkStore) Add(_ context.Context, b domainbookmark.Bookmark) (domainbookmark.Bookmark, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	if f.nextAdd != nil {
		err := f.nextAdd
		f.nextAdd = nil
		return domainbookmark.Bookmark{}, err
	}
	if f.rows[b.UserID] == nil {
		f.rows[b.UserID] = map[uuid.UUID]domainbookmark.Bookmark{}
	}
	b.CreatedAt = fixedTime()
	f.rows[b.UserID][b.PaperID] = b
	return b, nil
}

func (f *fakeBookmarkStore) Remove(_ context.Context, userID, paperID uuid.UUID) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	delete(f.rows[userID], paperID)
	return nil
}

func (f *fakeBookmarkStore) List(_ context.Context, userID uuid.UUID, _ string, limit int) ([]research.PaperSummary, string, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	out := make([]research.PaperSummary, 0, limit)
	for _, b := range f.rows[userID] {
		if len(out) == limit {
			break
		}
		out = append(out, research.PaperSummary{ID: b.PaperID})
	}
	return out, "", nil
}

func bookmarkTestHandler() (*BookmarksHandlers, *fakeBookmarkStore) {
	store := newFakeBookmarkStore()
	return NewBookmarksHandlers(appbookmark.NewService(store), testLogger()), store
}

func authedRequest(method, path string) *http.Request {
	r := httptest.NewRequest(method, path, nil)
	user := domainuser.User{ID: uuid.MustParse("0197c0de-0000-7000-8000-000000000001")}
	return r.WithContext(context.WithValue(r.Context(), userKey{}, user))
}

func TestBookmarksRequireAuth(t *testing.T) {
	h, _ := bookmarkTestHandler()
	w := httptest.NewRecorder()
	h.Add(w, httptest.NewRequest(http.MethodPost, "/api/v1/me/bookmarks", strings.NewReader("{}")))
	if w.Code != http.StatusUnauthorized {
		t.Fatalf("anonymous add: %d", w.Code)
	}

	w = httptest.NewRecorder()
	h.List(w, httptest.NewRequest(http.MethodGet, "/api/v1/me/bookmarks", nil))
	if w.Code != http.StatusUnauthorized {
		t.Fatalf("anonymous list: %d", w.Code)
	}

	w = httptest.NewRecorder()
	h.Remove(w, httptest.NewRequest(http.MethodDelete, "/api/v1/me/bookmarks/"+uuid.NewString(), nil))
	if w.Code != http.StatusUnauthorized {
		t.Fatalf("anonymous remove: %d", w.Code)
	}
}

func TestBookmarkAddListRemoveFlow(t *testing.T) {
	h, _ := bookmarkTestHandler()
	paperID := uuid.MustParse("0197c0de-0000-7000-8000-00000000000a")

	userCtx := context.WithValue(context.Background(), userKey{},
		domainuser.User{ID: uuid.MustParse("0197c0de-0000-7000-8000-000000000001")})

	r := httptest.NewRequest(http.MethodPost, "/api/v1/me/bookmarks",
		strings.NewReader(`{"paper_id":"`+paperID.String()+`","note":"later"}`)).WithContext(userCtx)
	w := httptest.NewRecorder()
	h.Add(w, r)
	if w.Code != http.StatusCreated {
		t.Fatalf("add: %d: %s", w.Code, w.Body.String())
	}

	r2 := httptest.NewRequest(http.MethodGet, "/api/v1/me/bookmarks", nil).WithContext(userCtx)
	w2 := httptest.NewRecorder()
	h.List(w2, r2)
	if w2.Code != http.StatusOK {
		t.Fatalf("list: %d: %s", w2.Code, w2.Body.String())
	}
	var list bookmarkListResponseDTO
	if err := json.Unmarshal(w2.Body.Bytes(), &list); err != nil {
		t.Fatal(err)
	}
	if len(list.Items) != 1 || list.Items[0].ID != paperID {
		t.Fatalf("unexpected list body %+v", list.Items)
	}

	r3 := httptest.NewRequest(http.MethodDelete, "/api/v1/me/bookmarks/"+paperID.String(), nil).WithContext(userCtx)
	r3.SetPathValue("paperId", paperID.String())
	w3 := httptest.NewRecorder()
	h.Remove(w3, r3)
	if w3.Code != http.StatusNoContent {
		t.Fatalf("remove: %d: %s", w3.Code, w3.Body.String())
	}

	r4 := httptest.NewRequest(http.MethodGet, "/api/v1/me/bookmarks", nil).WithContext(userCtx)
	w4 := httptest.NewRecorder()
	h.List(w4, r4)
	var empty bookmarkListResponseDTO
	if err := json.Unmarshal(w4.Body.Bytes(), &empty); err != nil {
		t.Fatal(err)
	}
	if len(empty.Items) != 0 {
		t.Fatalf("expected empty after remove, got %+v", empty.Items)
	}
}

func TestBookmarkAddRejectsBadInput(t *testing.T) {
	h, _ := bookmarkTestHandler()
	userCtx := context.WithValue(context.Background(), userKey{},
		domainuser.User{ID: uuid.New()})

	// malformed JSON
	w := httptest.NewRecorder()
	h.Add(w, httptest.NewRequest(http.MethodPost, "/api/v1/me/bookmarks",
		strings.NewReader("{bad")).WithContext(userCtx))
	if w.Code != http.StatusBadRequest {
		t.Fatalf("malformed json: %d", w.Code)
	}

	// non-UUID paper id
	w5 := httptest.NewRecorder()
	h.Add(w5, httptest.NewRequest(http.MethodPost, "/api/v1/me/bookmarks",
		strings.NewReader(`{"paper_id":"not-a-uuid"}`)).WithContext(userCtx))
	if w5.Code != http.StatusBadRequest {
		t.Fatalf("non-uuid paper id: %d", w5.Code)
	}
}

func TestBookmarkAddMapsUnknownPaperTo404(t *testing.T) {
	h, store := bookmarkTestHandler()
	store.nextAdd = research.ErrNotFound

	r := httptest.NewRequest(http.MethodPost, "/api/v1/me/bookmarks",
		strings.NewReader(`{"paper_id":"`+uuid.NewString()+`"}`)).WithContext(
		context.WithValue(context.Background(), userKey{},
			domainuser.User{ID: uuid.New()}))
	w := httptest.NewRecorder()
	h.Add(w, r)
	if w.Code != http.StatusNotFound {
		t.Fatalf("unknown paper: %d: %s", w.Code, w.Body.String())
	}
}
