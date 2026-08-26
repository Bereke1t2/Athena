package v1

import (
	"context"
	"encoding/json"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"

	"athena/backend/internal/application/ingestion"
	"athena/backend/internal/domain/research"
)

// ---- fakes -------------------------------------------------------------------

type fakeReader struct {
	detail    research.PaperDetail
	detailErr error
	findID    uuid.UUID
	findErr   error
	list      []research.PaperSummary
	listNext  string
	listErr   error
	citations []research.PaperSummary
	citErr    error
	related   []research.PaperSummary
	relErr    error

	lastQuery     research.ListQuery
	lastDirection research.CitationDirection
}

func (f *fakeReader) GetDetailByID(context.Context, uuid.UUID) (research.PaperDetail, error) {
	return f.detail, f.detailErr
}

func (f *fakeReader) FindIDByIdentifier(context.Context, research.IdentifierType, string) (uuid.UUID, error) {
	if f.findErr != nil {
		return uuid.Nil, f.findErr
	}
	if f.findID == uuid.Nil {
		return uuid.Nil, research.ErrNotFound
	}
	return f.findID, nil
}

func (f *fakeReader) ListPapers(_ context.Context, q research.ListQuery) ([]research.PaperSummary, string, error) {
	f.lastQuery = q
	if f.listErr != nil {
		return nil, "", f.listErr
	}
	return f.list, f.listNext, nil
}

func (f *fakeReader) ListCitations(_ context.Context, _ uuid.UUID, dir research.CitationDirection, _ int) ([]research.PaperSummary, error) {
	f.lastDirection = dir
	return f.citations, f.citErr
}

func (f *fakeReader) RelatedBySharedTopics(context.Context, uuid.UUID, int) ([]research.PaperSummary, error) {
	return f.related, f.relErr
}

func summary(id string) research.PaperSummary {
	return research.PaperSummary{
		ID:              uuid.MustParse(id),
		Title:           "Athena: discovery at scale",
		PublicationType: research.PubTypeArticle,
		OAStatus:        research.OAStatusGold,
		IsOpenAccess:    true,
		CitedByCount:    7,
		VenueName:       "J. Open Science",
		Year:            2026,
	}
}

func newResearchServer(r *fakeReader) http.Handler {
	h := NewResearchHandlers(r, discardLogger())
	mux := http.NewServeMux()
	mux.HandleFunc("GET /api/v1/research/papers", h.List)
	mux.HandleFunc("GET /api/v1/research/papers/{id}", h.Get)
	mux.HandleFunc("GET /api/v1/research/papers/{id}/citations", h.Citations)
	mux.HandleFunc("GET /api/v1/research/papers/{id}/related", h.Related)
	return WithRequestID(mux)
}

// ---- list ----------------------------------------------------------------------

func TestListPapersHappyPath(t *testing.T) {
	r := &fakeReader{list: []research.PaperSummary{summary("11111111-1111-4111-8111-111111111111")}, listNext: "abc"}
	srv := newResearchServer(r)

	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet,
		"/api/v1/research/papers?limit=5&sort=citations&open_access=true&published_after=2020-01-01", nil)
	srv.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, body = %s", rec.Code, rec.Body.String())
	}
	var body struct {
		Items []struct {
			ID         string `json:"id"`
			Title      string `json:"title"`
			CitedByCnt int    `json:"cited_by_count"`
		} `json:"items"`
		Meta struct {
			NextCursor *string `json:"next_cursor"`
			Limit      int     `json:"limit"`
		} `json:"meta"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatalf("bad JSON: %v", err)
	}
	if len(body.Items) != 1 || body.Items[0].Title != "Athena: discovery at scale" || body.Items[0].CitedByCnt != 7 {
		t.Fatalf("unexpected items: %+v", body.Items)
	}
	if body.Meta.NextCursor == nil || *body.Meta.NextCursor != "abc" || body.Meta.Limit != 5 {
		t.Fatalf("unexpected meta: %+v", body.Meta)
	}
	if r.lastQuery.Limit != 5 ||
		r.lastQuery.Sort != research.SortCitations ||
		r.lastQuery.OpenAccess == nil || !*r.lastQuery.OpenAccess ||
		r.lastQuery.PublishedAfter == nil {
		t.Fatalf("query not propagated: %+v", r.lastQuery)
	}
}

func TestListPapersValidation(t *testing.T) {
	cases := []struct{ name, qs string }{
		{"limit zero", "limit=0"},
		{"limit over max", "limit=101"},
		{"bad sort", "sort=hottest"},
		{"bad oa flag", "open_access=yes"},
		{"bad date", "published_after=2020-13-99"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			srv := newResearchServer(&fakeReader{})
			rec := httptest.NewRecorder()
			srv.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/api/v1/research/papers?"+tc.qs, nil))
			if rec.Code != http.StatusBadRequest {
				t.Fatalf("status = %d, want 400", rec.Code)
			}
			assertErrorEnvelope(t, rec, CodeInvalidRequest)
		})
	}
}

// ---- get -----------------------------------------------------------------------

const paperUUID = "22222222-2222-4222-8222-222222222222"

func TestGetByIDentifierVariants(t *testing.T) {
	cases := []struct{ name, id string }{
		{"uuid", paperUUID},
		// DOIs contain slashes; clients must percent-encode them in paths.
		{"doi", "10.1234%2FAthena.2026"},
		{"arxiv", "2401.01234v2"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			r := &fakeReader{detail: detailFixture()}
			r.findID = r.detail.Summary.ID
			srv := newResearchServer(r)

			rec := httptest.NewRecorder()
			srv.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/api/v1/research/papers/"+tc.id, nil))
			if rec.Code != http.StatusOK {
				t.Fatalf("status = %d, body = %s", rec.Code, rec.Body.String())
			}
			var body map[string]any
			if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
				t.Fatalf("bad json: %v", err)
			}
			if body["id"].(string) != paperUUID {
				t.Fatalf("wrong id in response: %v", body["id"])
			}
			if _, ok := body["authors"].([]any); !ok {
				t.Fatalf("authors missing")
			}
		})
	}
}

func TestGetNotFound(t *testing.T) {
	srv := newResearchServer(&fakeReader{}) // find returns ErrNotFound; detail not reached
	rec := httptest.NewRecorder()
	srv.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/api/v1/research/papers/not-an-id", nil))
	if rec.Code != http.StatusNotFound {
		t.Fatalf("status = %d, want 404", rec.Code)
	}
	assertErrorEnvelope(t, rec, CodeNotFound)
}

// ---- citations / related ---------------------------------------------------------

func TestCitationsDirectionMapping(t *testing.T) {
	r := &fakeReader{citations: []research.PaperSummary{summary(paperUUID)}}
	srv := newResearchServer(r)

	rec := httptest.NewRecorder()
	srv.ServeHTTP(rec, httptest.NewRequest(http.MethodGet,
		"/api/v1/research/papers/"+paperUUID+"/citations?direction=out", nil))
	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d", rec.Code)
	}
	if r.lastDirection != research.References {
		t.Fatalf("direction = %q, want references", r.lastDirection)
	}

	rec = httptest.NewRecorder()
	srv.ServeHTTP(rec, httptest.NewRequest(http.MethodGet,
		"/api/v1/research/papers/"+paperUUID+"/citations?direction=sideways", nil))
	if rec.Code != http.StatusBadRequest {
		t.Fatalf("bad direction status = %d, want 400", rec.Code)
	}
}

func TestRelatedOK(t *testing.T) {
	r := &fakeReader{related: []research.PaperSummary{summary(paperUUID)}}
	srv := newResearchServer(r)
	rec := httptest.NewRecorder()
	srv.ServeHTTP(rec, httptest.NewRequest(http.MethodGet,
		"/api/v1/research/papers/"+paperUUID+"/related?limit=3", nil))
	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, body = %s", rec.Code, rec.Body.String())
	}
}

// ---- admin ---------------------------------------------------------------------

type fakeQueue struct {
	enqueued  ingestion.EnqueueRequest
	job       *ingestion.JobInfo
	err       error
	jobs      []ingestion.JobInfo
	listErr   error
	lastState string
	lastLimit int
}

func (f *fakeQueue) EnqueueWindowSync(ctx context.Context, req ingestion.EnqueueRequest) (*ingestion.JobInfo, error) {
	f.enqueued = req
	if f.err != nil {
		return nil, f.err
	}
	return f.job, nil
}

func (f *fakeQueue) ListJobs(ctx context.Context, state string, limit int) ([]ingestion.JobInfo, error) {
	f.lastState, f.lastLimit = state, limit
	return f.jobs, f.listErr
}

func adminServer(q ingestion.JobQueue) http.Handler {
	h := NewAdminHandlers("sekrit", discardLogger())
	h.Queue = q
	mux := http.NewServeMux()
	mux.HandleFunc("POST /api/v1/admin/ingestion/jobs", h.CreateIngestionJob)
	mux.HandleFunc("GET /api/v1/admin/ingestion/jobs", h.ListIngestionJobs)
	return WithRequestID(mux)
}

func TestAdminAuthEnforced(t *testing.T) {
	q := &fakeQueue{}
	srv := adminServer(q)

	t.Run("no token configured", func(t *testing.T) {
		h := NewAdminHandlers("", discardLogger())
		rec := httptest.NewRecorder()
		h.CreateIngestionJob(rec, httptest.NewRequest(http.MethodPost, "/x", nil))
		if rec.Code != http.StatusServiceUnavailable {
			t.Fatalf("status = %d, want 503", rec.Code)
		}
	})

	t.Run("missing bearer", func(t *testing.T) {
		rec := httptest.NewRecorder()
		srv.ServeHTTP(rec, httptest.NewRequest(http.MethodPost, "/api/v1/admin/ingestion/jobs", nil))
		if rec.Code != http.StatusUnauthorized {
			t.Fatalf("status = %d, want 401", rec.Code)
		}
	})

	t.Run("wrong bearer", func(t *testing.T) {
		rec := httptest.NewRecorder()
		req := httptest.NewRequest(http.MethodPost, "/api/v1/admin/ingestion/jobs", nil)
		req.Header.Set("Authorization", "Bearer wrong")
		srv.ServeHTTP(rec, req)
		if rec.Code != http.StatusForbidden {
			t.Fatalf("status = %d, want 403", rec.Code)
		}
	})
}

func TestCreateIngestionJobAccepted(t *testing.T) {
	q := &fakeQueue{job: &ingestion.JobInfo{ID: 42, State: "available"}}
	srv := adminServer(q)

	body := `{"provider":"arxiv","from":"2026-08-20T00:00:00Z","to":"2026-08-21T00:00:00Z","max_pages":2}`
	rec := httptest.NewRecorder()
	req := signed(body)
	req.Header.Set("Authorization", "Bearer sekrit")
	srv.ServeHTTP(rec, req)

	if rec.Code != http.StatusAccepted {
		t.Fatalf("status = %d, body = %s", rec.Code, rec.Body.String())
	}
	if q.enqueued.Provider != "arxiv" || !q.enqueued.To.After(q.enqueued.From) || q.enqueued.MaxPages != 2 {
		t.Fatalf("request not propagated: %+v", q.enqueued)
	}
	var resp struct {
		JobID int64 `json:"job_id"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &resp); err != nil || resp.JobID != 42 {
		t.Fatalf("bad response: %s (%v)", rec.Body.String(), err)
	}
}

func TestCreateIngestionJobValidationAndUnknownProvider(t *testing.T) {
	t.Run("bad window", func(t *testing.T) {
		srv := adminServer(&fakeQueue{})
		body := `{"provider":"arxiv","from":"2026-08-21T00:00:00Z","to":"2026-08-20T00:00:00Z"}`
		req := signed(body)
		rec := httptest.NewRecorder()
		srv.ServeHTTP(rec, req)
		if rec.Code != http.StatusBadRequest {
			t.Fatalf("status = %d", rec.Code)
		}
	})

	t.Run("unknown provider", func(t *testing.T) {
		q := &fakeQueue{err: ingestion.ErrUnknownProviderSlug}
		srv := adminServer(q)
		body := `{"provider":"scihub","from":"2026-08-20T00:00:00Z","to":"2026-08-21T00:00:00Z"}`
		req := signed(body)
		rec := httptest.NewRecorder()
		srv.ServeHTTP(rec, req)
		if rec.Code != http.StatusBadRequest {
			t.Fatalf("status = %d", rec.Code)
		}
		assertErrorEnvelope(t, rec, CodeInvalidRequest)
	})
}

func TestListIngestionJobsParams(t *testing.T) {
	q := &fakeQueue{jobs: []ingestion.JobInfo{{ID: 9, Kind: "sync_provider_window", State: "running"}}}
	srv := adminServer(q)

	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet,
		"/api/v1/admin/ingestion/jobs?state=running&limit=10", nil)
	req.Header.Set("Authorization", "Bearer sekrit")
	srv.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, body = %s", rec.Code, rec.Body.String())
	}
	if q.lastState != "running" || q.lastLimit != 10 {
		t.Fatalf("filters not passed: state=%q limit=%d", q.lastState, q.lastLimit)
	}
	var resp struct {
		Items []ingestion.JobInfo `json:"items"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &resp); err != nil || len(resp.Items) != 1 || resp.Items[0].Kind != "sync_provider_window" {
		t.Fatalf("bad response: %s (%v)", rec.Body.String(), err)
	}
}

// ---- helpers -------------------------------------------------------------------

func signed(body string) *http.Request {
	req := httptest.NewRequest(http.MethodPost, "/api/v1/admin/ingestion/jobs", strings.NewReader(body))
	req.Header.Set("Authorization", "Bearer sekrit")
	return req
}

func discardLogger() *slog.Logger {
	return slog.New(slog.DiscardHandler)
}

func detailFixture() research.PaperDetail {
	id := uuid.MustParse(paperUUID)
	title := "Athena: discovery at scale"
	abs := "An abstract."
	pub := time.Date(2026, 5, 1, 0, 0, 0, 0, time.UTC)
	return research.PaperDetail{
		Summary: research.PaperSummary{
			ID:              id,
			Title:           title,
			Abstract:        &abs,
			PublishedOn:     &pub,
			Year:            2026,
			PublicationType: research.PubTypeArticle,
			OAStatus:        research.OAStatusGold,
			IsOpenAccess:    true,
			CitedByCount:    7,
		},
		Language:    "en",
		BestOAURL:   "https://example.org/pdf",
		DOI:         "10.1234/athena.2026",
		ArxivID:     "2401.01234v2",
		Authors:     []research.AuthorLine{{ID: uuid.MustParse("33333333-3333-4333-8333-333333333333"), Name: "Ada Lovelace"}},
		Topics:      []research.TopicLine{{Slug: "information-retrieval", Name: "Information Retrieval", Score: 1, IsPrimary: true}},
		Versions:    []research.VersionLine{{Kind: research.VersionPreprint, URL: "https://arxiv.org/abs/2401.01234", IsPreprint: true}},
		SourceSlugs: []string{"openalex"},
	}
}

func assertErrorEnvelope(t *testing.T, rec *httptest.ResponseRecorder, wantCode string) {
	t.Helper()
	var env struct {
		Error struct {
			Code      string `json:"code"`
			RequestID string `json:"request_id"`
		} `json:"error"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &env); err != nil {
		t.Fatalf("not an envelope: %v / %s", err, rec.Body.String())
	}
	if env.Error.Code != wantCode {
		t.Fatalf("code = %q, want %q", env.Error.Code, wantCode)
	}
	if env.Error.RequestID == "" {
		t.Fatalf("request_id missing from envelope")
	}
}
