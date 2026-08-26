package openalex

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"athena/backend/internal/domain/research"
	"athena/backend/internal/infrastructure/providers"
)

const fixtureWork = `{
  "meta": {"count": 2, "next_cursor": "CURSOR-2"},
  "results": [{
    "id": "https://openalex.org/W2741809807",
    "doi": "https://doi.org/10.7717/PEERJ-CS.134",
    "title": "  Attention   Is All You Need ",
    "display_name": "Attention Is All You Need",
    "publication_date": "2017-06-12",
    "publication_year": 2017,
    "type": "article",
    "language": "en",
    "open_access": {"is_oa": true, "oa_status": "gold", "oa_url": "https://oa.example/pdf"},
    "primary_location": {
      "landing_page_url": "https://doi.org/10.7717/peerj-cs.134",
      "license": "cc-by",
      "source": {"display_name": "PeerJ Computer Science", "type": "journal"}
    },
    "best_oa_location": {
      "pdf_url": "https://oa.example/pdf", "license": "cc-by",
      "version": "publishedVersion",
      "source": {"display_name": "PeerJ Computer Science", "type": "journal"}
    },
    "authorships": [
      {"author_position": "first",
       "author": {"id": "https://openalex.org/A1", "display_name": "Ashish Vaswani",
                  "orcid": "https://orcid.org/0000-0002-1111-2222"},
       "institutions": [{"display_name": "Google Brain"}]},
      {"author_position": "middle",
       "author": {"id": "https://openalex.org/A2", "display_name": "Noam Shazeer"},
       "institutions": []}
    ],
    "topics": [
      {"id": "https://openalex.org/T1", "display_name": "Neural Networks", "score": 0.98},
      {"id": "https://openalex.org/T2", "display_name": "Semantics", "score": 0.31}
    ],
    "ids": {"openalex": "https://openalex.org/W2741809807",
            "doi": "https://doi.org/10.7717/peerj-cs.134",
            "arxiv": "https://arxiv.org/abs/1706.03762v5"},
    "cited_by_count": 90001,
    "referenced_works_count": 2,
    "referenced_works": ["https://openalex.org/W2100837269", "https://openalex.org/W999"],
    "abstract_inverted_index": {"deep": [2], "learning": [3], "advances": [0, 4]}
  }]
}`

func testProvider(t *testing.T, handler http.HandlerFunc) (*Provider, *httptest.Server) {
	t.Helper()
	srv := httptest.NewServer(handler)
	p := New(Options{BaseURL: srv.URL})
	return p, srv
}

func TestFetchWindowMapsNormalizedPaper(t *testing.T) {
	var gotQuery string
	p, srv := testProvider(t, func(w http.ResponseWriter, r *http.Request) {
		gotQuery = r.URL.Query().Get("filter")
		_, _ = w.Write([]byte(fixtureWork))
	})
	defer srv.Close()

	page, err := p.FetchWindow(context.Background(), research.Window{
		From: time.Date(2026, 8, 1, 0, 0, 0, 0, time.UTC),
		To:   time.Date(2026, 8, 2, 0, 0, 0, 0, time.UTC),
	})
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(gotQuery, "from_publication_date:2026-08-01") ||
		!strings.Contains(gotQuery, "to_publication_date:2026-08-02") {
		t.Fatalf("window filters missing from query %q", gotQuery)
	}

	if page.NextCursor != "CURSOR-2" {
		t.Fatalf("expected continuation cursor, got %q", page.NextCursor)
	}
	if len(page.Papers) != 1 {
		t.Fatalf("expected 1 paper, got %d", len(page.Papers))
	}
	got := page.Papers[0]

	if got.Title != "Attention Is All You Need" || got.Year != 2017 {
		t.Fatalf("bad title/year: %q %d", got.Title, got.Year)
	}
	if got.DOI() != "10.7717/peerj-cs.134" {
		t.Fatalf("doi not canonicalized: %q", got.DOI())
	}
	if got.ArxivID() != "1706.03762" {
		t.Fatalf("arxiv id not canonicalized (version stripped): %q", got.ArxivID())
	}
	wantIDs := map[string]bool{
		"openalex|W2741809807": true, "doi|10.7717/peerj-cs.134": true,
		"arxiv|1706.03762": true,
	}
	if len(got.Identifiers) != len(wantIDs) {
		t.Fatalf("unexpected identifier count %d: %+v", len(got.Identifiers), got.Identifiers)
	}
	for _, id := range got.Identifiers {
		key := string(id.Type) + "|" + id.Value
		if !wantIDs[key] {
			t.Fatalf("unexpected identifier %q", key)
		}
		delete(wantIDs, key)
	}
	for k := range wantIDs {
		t.Fatalf("missing identifier %q", k)
	}
	if got.Abstract != "advances deep learning advances" {
		t.Fatalf("inverted index not rebuilt: %q", got.Abstract)
	}
	if len(got.Authors) != 2 || got.Authors[0].DisplayName != "Ashish Vaswani" ||
		got.Authors[0].Position != 1 || got.Authors[0].ORCID != "0000-0002-1111-2222" ||
		len(got.Authors[0].Affiliation) != 1 {
		t.Fatalf("authors not mapped: %+v", got.Authors)
	}
	if len(got.Topics) != 2 || got.Topics[0].Name != "Neural Networks" || !got.Topics[0].IsPrimary {
		t.Fatalf("topics not mapped: %+v", got.Topics)
	}
	if got.OA.Status != research.OAStatusGold || got.OA.License != "cc-by" ||
		got.OA.URL != "https://oa.example/pdf" {
		t.Fatalf("OA not mapped: %+v", got.OA)
	}
	if got.CitedByCount != 90001 || len(got.ReferencedIDs) != 2 {
		t.Fatalf("citation data wrong: cited=%d refs=%v", got.CitedByCount, got.ReferencedIDs)
	}
	if got.Provenance.ProviderSlug != "openalex" ||
		got.Provenance.NativeID != "W2741809807" ||
		got.Provenance.PayloadFingerprint == "" {
		t.Fatalf("provenance incomplete: %+v", got.Provenance)
	}
	if got.TitleNormalized == "" || got.Fingerprint == "" {
		t.Fatal("DeriveIdentity did not run")
	}
	hasPreprintVersion := false
	for _, v := range got.Versions {
		if v.Kind == research.VersionPreprint && v.ArxivID == "1706.03762" {
			hasPreprintVersion = true
		}
	}
	if !hasPreprintVersion {
		t.Fatalf("preprint version missing: %+v", got.Versions)
	}
}

func TestFetchWindowValidatesWindow(t *testing.T) {
	p, srv := testProvider(t, func(http.ResponseWriter, *http.Request) {})
	defer srv.Close()

	if _, err := p.FetchWindow(context.Background(), research.Window{}); !errors.Is(err, providers.ErrBadWindow) {
		t.Fatalf("want ErrBadWindow, got %v", err)
	}
}

func TestFetchWindowSkipsSparseRecords(t *testing.T) {
	p, srv := testProvider(t, func(w http.ResponseWriter, _ *http.Request) {
		_, _ = w.Write([]byte(`{"results": [{"id":"https://openalex.org/W1"}]}`))
	})
	defer srv.Close()

	page, err := p.FetchWindow(context.Background(), research.Window{
		From: time.Now(), To: time.Now().Add(time.Hour)})
	if err != nil {
		t.Fatalf("sparse record should be skipped, got %v", err)
	}
	if len(page.Papers) != 0 {
		t.Fatalf("want 0 papers, got %d", len(page.Papers))
	}
}

func TestFetchWindowSchemaDriftStillStructural(t *testing.T) {
	// A payload whose results array itself is malformed must fail loudly.
	p, srv := testProvider(t, func(w http.ResponseWriter, _ *http.Request) {
		_, _ = w.Write([]byte(`{"results": "not-an-array"}`))
	})
	defer srv.Close()

	_, err := p.FetchWindow(context.Background(), research.Window{
		From: time.Now(), To: time.Now().Add(time.Hour)})
	if !errors.Is(err, providers.ErrSchemaDrift) {
		t.Fatalf("want ErrSchemaDrift, got %v", err)
	}
}
