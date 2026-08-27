package v1

import (
	"context"
	"encoding/json"
	"errors"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/google/uuid"

	appsearch "athena/backend/internal/application/search"
	"athena/backend/internal/domain/research"
	domainsearch "athena/backend/internal/domain/search"
)

func newTestService(e domainsearch.Searcher) *appsearch.Service {
	return appsearch.NewService(e, nil)
}

func newServiceWithCache(e domainsearch.Searcher, c mapCache) *appsearch.Service {
	return appsearch.NewService(e, c)
}

func testLogger() *slog.Logger { return slog.New(slog.DiscardHandler) }

// testUUID is a stable UUID for assertions.
func testUUID() uuid.UUID {
	id, _ := uuid.Parse("0197c0de-0000-7000-8000-000000000001")
	return id
}

type fakeSearcher struct {
	page domainsearch.ResultPage
	err  error
	last domainsearch.Query
}

func (f *fakeSearcher) Search(_ context.Context, q domainsearch.Query) (domainsearch.ResultPage, error) {
	f.last = q
	return f.page, f.err
}
func (*fakeSearcher) Related(context.Context, uuid.UUID, int) ([]domainsearch.ScoredPaper, error) {
	return nil, nil
}

type mapCache map[string][]byte

func (m mapCache) GetJSON(_ context.Context, _, key string) ([]byte, error) {
	b, ok := m[key]
	if !ok {
		return nil, nil
	}
	return b, nil
}
func (m mapCache) SetJSON(_ context.Context, _, key string, v any) error {
	b, _ := json.Marshal(v)
	m[key] = b
	return nil
}

func TestSearchHandlerHappyPath(t *testing.T) {
	engine := &fakeSearcher{page: domainsearch.ResultPage{
		Items:         []domainsearch.ScoredPaper{{Score: 0.9, Paper: research.PaperSummary{ID: testUUID(), Title: "T"}}},
		ModeUsed:      domainsearch.ModeKeyword,
		TotalEstimate: 42,
	}}
	h := NewSearchHandlers(newTestService(engine), testLogger())

	r := httptest.NewRequest(http.MethodGet, "/api/v1/search?q=attention&limit=10", nil)
	w := httptest.NewRecorder()
	h.Get(w, r)

	if w.Code != http.StatusOK {
		t.Fatalf("status %d: %s", w.Code, w.Body.String())
	}
	var out searchResponseDTO
	if err := json.Unmarshal(w.Body.Bytes(), &out); err != nil {
		t.Fatal(err)
	}
	if len(out.Items) != 1 || out.Items[0].Score == 0 ||
		out.Items[0].Paper.Title != "T" || out.Meta.TotalEstimate != 42 ||
		out.Meta.ModeUsed != "keyword" {
		t.Fatalf("unexpected response %+v", out)
	}
	if engine.last.Q != "attention" || engine.last.Limit != 10 {
		t.Fatalf("query not passed through: %+v", engine.last)
	}
}

func TestSearchHandlerValidationErrors(t *testing.T) {
	cases := []struct{ url string }{
		{"/api/v1/search?mode=bogus"},
		{"/api/v1/search?sort=hot"},
		{"/api/v1/search?limit=999"},
		{"/api/v1/search?open_access=yes"},
		{"/api/v1/search?published_after=2026-13-01"},
		{"/api/v1/search?min_citations=-3"},
	}
	for _, tc := range cases {
		t.Run(tc.url, func(t *testing.T) {
			h := NewSearchHandlers(newTestService(&fakeSearcher{}), testLogger())
			r := httptest.NewRequest(http.MethodGet, tc.url, nil)
			w := httptest.NewRecorder()
			h.Get(w, r)
			if w.Code != http.StatusBadRequest {
				t.Fatalf("want 400, got %d (%s)", w.Code, w.Body.String())
			}
		})
	}
}

func TestSearchSemanticModeDegradesToKeyword(t *testing.T) {
	// The ENGINE owns mode_used honesty: Phase 2 always reports keyword.
	engine := &fakeSearcher{page: domainsearch.ResultPage{ModeUsed: domainsearch.ModeKeyword}}
	h := NewSearchHandlers(newTestService(engine), testLogger())

	r := httptest.NewRequest(http.MethodGet, "/api/v1/search?q=x&mode=semantic", nil)
	w := httptest.NewRecorder()
	if h.Get(w, r); w.Code != http.StatusOK {
		t.Fatalf("status %d", w.Code)
	}
	var out searchResponseDTO
	_ = json.Unmarshal(w.Body.Bytes(), &out)
	if out.Meta.ModeUsed != "keyword" {
		t.Fatalf("mode_used must reflect reality; got %q", out.Meta.ModeUsed)
	}
}

func TestSearchEngineErrorIs500(t *testing.T) {
	engine := &fakeSearcher{err: errors.New("pool exhausted")}
	h := NewSearchHandlers(newTestService(engine), testLogger())
	r := httptest.NewRequest(http.MethodGet, "/api/v1/search?q=x", nil)
	w := httptest.NewRecorder()
	h.Get(w, r)
	if w.Code != http.StatusInternalServerError {
		t.Fatalf("want 500, got %d", w.Code)
	}
}

func TestSearchResponseIsCached(t *testing.T) {
	engine := &fakeSearcher{page: domainsearch.ResultPage{ModeUsed: domainsearch.ModeKeyword}}
	cacheStore := mapCache{}
	svc := newServiceWithCache(engine, cacheStore)
	h := NewSearchHandlers(svc, testLogger())

	url := "/api/v1/search?q=cached&limit=5"
	for i := 0; i < 2; i++ {
		r := httptest.NewRequest(http.MethodGet, url, nil)
		w := httptest.NewRecorder()
		h.Get(w, r)
		if w.Code != http.StatusOK {
			t.Fatalf("call %d status %d", i, w.Code)
		}
	}
	if len(cacheStore) == 0 {
		t.Fatal("expected cache writes")
	}
}
