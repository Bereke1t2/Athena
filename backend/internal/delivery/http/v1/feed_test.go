package v1

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"

	appfeed "athena/backend/internal/application/feed"
	"athena/backend/internal/domain/research"
)

type fakeFeedSource struct {
	research.PaperReader
	papers   []research.PaperSummary
	trending []research.PaperSummary
	err      error
}

func (f *fakeFeedSource) ListPapers(context.Context, research.ListQuery) ([]research.PaperSummary, string, error) {
	return f.papers, "", f.err
}

func (f *fakeFeedSource) Trending(context.Context, []string, string, int) ([]research.PaperSummary, error) {
	return f.trending, f.err
}

func TestFeedLatest(t *testing.T) {
	h := NewFeedHandlers(appfeed.NewService(&fakeFeedSource{}), testLogger())
	r := httptest.NewRequest(http.MethodGet, "/api/v1/feed?section=latest", nil)
	w := httptest.NewRecorder()
	h.Get(w, r)

	if w.Code != http.StatusOK {
		t.Fatalf("status %d: %s", w.Code, w.Body.String())
	}
	var out feedResponseDTO
	if err := json.Unmarshal(w.Body.Bytes(), &out); err != nil {
		t.Fatal(err)
	}
	if len(out.Items) != 0 || out.Meta.Limit != 20 {
		t.Fatalf("unexpected body %+v", out)
	}
}

func TestFeedRecommended(t *testing.T) {
	h := NewFeedHandlers(appfeed.NewService(&fakeFeedSource{}), testLogger())
	r := httptest.NewRequest(http.MethodGet, "/api/v1/feed?section=recommended", nil)
	w := httptest.NewRecorder()
	h.Get(w, r)

	if w.Code != http.StatusOK {
		t.Fatalf("want 200 for recommended, got %d", w.Code)
	}
}

func TestFeedInvalidSection(t *testing.T) {
	h := NewFeedHandlers(appfeed.NewService(&fakeFeedSource{}), testLogger())
	r := httptest.NewRequest(http.MethodGet, "/api/v1/feed?section=hot", nil)
	w := httptest.NewRecorder()
	h.Get(w, r)

	if w.Code != http.StatusBadRequest {
		t.Fatalf("want 400, got %d", w.Code)
	}
}

func TestFeedTrendingMapsItems(t *testing.T) {
	src := &fakeFeedSource{trending: []research.PaperSummary{{ID: testUUID(), Title: "Hot paper"}}}
	h := NewFeedHandlers(appfeed.NewService(src), testLogger())
	r := httptest.NewRequest(http.MethodGet, "/api/v1/feed?section=trending", nil)
	w := httptest.NewRecorder()
	h.Get(w, r)

	if w.Code != http.StatusOK {
		t.Fatalf("status %d", w.Code)
	}
	var out feedResponseDTO
	_ = json.Unmarshal(w.Body.Bytes(), &out)
	if len(out.Items) != 1 || out.Items[0].Section != "trending" ||
		out.Items[0].Paper.Title != "Hot paper" {
		t.Fatalf("unexpected items %+v", out.Items)
	}
}

func TestFeedInternalError(t *testing.T) {
	src := &fakeFeedSource{err: errors.New("db down")}
	h := NewFeedHandlers(appfeed.NewService(src), testLogger())
	r := httptest.NewRequest(http.MethodGet, "/api/v1/feed", nil)
	w := httptest.NewRecorder()
	h.Get(w, r)

	if w.Code != http.StatusInternalServerError {
		t.Fatalf("want 500, got %d", w.Code)
	}
}
