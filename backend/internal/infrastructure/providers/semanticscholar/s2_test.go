package semanticscholar

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"athena/backend/internal/domain/research"
	"athena/backend/internal/infrastructure/providers"
)

const fixtureBulk = `{
  "total": 2,
  "token": "NEXT-TOKEN",
  "data": [{
    "paperId": "abc123",
    "title": "Scaling Laws for Neural Language Models",
    "abstract": "We study empirical scaling laws.",
    "year": 2020,
    "publicationDate": "2020-01-23",
    "venue": "",
    "journal": {"name": "arXiv (cs.CL)"},
    "publicationTypes": ["JournalArticle", "Review"],
    "externalIds": {"DOI": "10.48550/ARXIV.2001.08361", "ArXiv": "2001.08361v3", "CorpusId": 211528405},
    "isOpenAccess": true,
    "openAccessPdf": {"url": "https://pdf.example/paper.pdf"},
    "citationCount": 4242,
    "referenceCount": 88,
    "influentialCitationCount": 500,
    "fieldsOfStudy": ["Computer Science", "Mathematics"],
    "authors": [
      {"authorId": "a1", "name": "Jared Kaplan"},
      {"authorId": "", "name": "Sam McCandlish"}
    ]
  }]
}`

func testProvider(t *testing.T, handler http.HandlerFunc) (*Provider, *httptest.Server) {
	t.Helper()
	srv := httptest.NewServer(handler)
	p := New(Options{BaseURL: srv.URL})
	return p, srv
}

func TestFetchWindowRequiresQuery(t *testing.T) {
	p, srv := testProvider(t, func(http.ResponseWriter, *http.Request) {})
	defer srv.Close()

	win := research.Window{From: time.Now(), To: time.Now().Add(time.Hour)}
	if _, err := p.FetchWindow(context.Background(), win); !errors.Is(err, providers.ErrBadWindow) {
		t.Fatalf("query-less window must fail with ErrBadWindow, got %v", err)
	}
}

func TestFetchWindowMapsPaperAndCursor(t *testing.T) {
	var gotQuery, gotToken string
	p, srv := testProvider(t, func(w http.ResponseWriter, r *http.Request) {
		q := r.URL.Query()
		gotQuery = q.Get("publicationDateOrYear")
		gotToken = q.Get("token")
		_, _ = w.Write([]byte(fixtureBulk))
	})
	defer srv.Close()

	page, err := p.FetchWindow(context.Background(), research.Window{
		From:   time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC),
		To:     time.Date(2026, 1, 31, 0, 0, 0, 0, time.UTC),
		Query:  "scaling laws",
		Cursor: "TOK-1",
	})
	if err != nil {
		t.Fatal(err)
	}

	if gotQuery != "2026-01-01:2026-01-31" || gotToken != "TOK-1" {
		t.Fatalf("request params wrong: date=%q token=%q", gotQuery, gotToken)
	}
	if page.NextCursor != "NEXT-TOKEN" {
		t.Fatalf("expected continuation token, got %q", page.NextCursor)
	}

	got := page.Papers[0]
	if got.Title != "Scaling Laws for Neural Language Models" ||
		got.PublishedOn == nil || got.Year != 2020 {
		t.Fatalf("core fields wrong: %+v", got)
	}
	if got.DOI() != "10.48550/arxiv.2001.08361" {
		t.Fatalf("doi not canonicalized: %q", got.DOI())
	}
	if got.ArxivID() != "2001.08361" {
		t.Fatalf("arxiv id wrong: %q", got.ArxivID())
	}
	hasCorpus := false
	for _, id := range got.Identifiers {
		if id.Type == research.IDTypeCorpusID && id.Value == "211528405" {
			hasCorpus = true
		}
	}
	if !hasCorpus {
		t.Fatal("corpus id missing")
	}
	if got.VenueName != "arXiv (cs.CL)" {
		t.Fatalf("journal fallback not applied: %q", got.VenueName)
	}
	if got.PubType != research.PubTypeReview {
		t.Fatalf("review should win type precedence, got %q", got.PubType)
	}
	if got.OA.Status != research.OAStatusGreen || got.OA.URL != "https://pdf.example/paper.pdf" {
		t.Fatalf("OA wrong: %+v", got.OA)
	}
	if len(got.Authors) != 2 || got.Authors[1].ProviderIDs[research.IDTypeSemanticScholar] != "" {
		t.Fatalf("authors wrong: %+v", got.Authors)
	}
	if len(got.Topics) != 2 || got.Topics[0].Name != "Computer Science" || !got.Topics[0].IsPrimary {
		t.Fatalf("topics wrong: %+v", got.Topics)
	}
	if got.CitedByCount != 4242 {
		t.Fatalf("cited_by_count wrong: %d", got.CitedByCount)
	}
	if got.Provenance.NativeID != "abc123" || got.Provenance.ProviderSlug != "semanticscholar" {
		t.Fatalf("provenance wrong: %+v", got.Provenance)
	}
}

func TestFetchWindowSchemaDrift(t *testing.T) {
	p, srv := testProvider(t, func(w http.ResponseWriter, _ *http.Request) {
		_, _ = w.Write([]byte(`{"data":[{"paperId":"","title":""}]}`))
	})
	defer srv.Close()

	_, err := p.FetchWindow(context.Background(), research.Window{
		From: time.Now(), To: time.Now().Add(time.Hour), Query: "x"})
	if !errors.Is(err, providers.ErrSchemaDrift) {
		t.Fatalf("want ErrSchemaDrift, got %v", err)
	}
}
