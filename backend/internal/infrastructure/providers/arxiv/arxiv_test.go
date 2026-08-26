package arxiv

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"athena/backend/internal/domain/research"
)

const fixtureFeed = `<?xml version="1.0" encoding="UTF-8"?>
<feed xmlns="http://www.w3.org/2005/Atom"
      xmlns:arxiv="http://arxiv.org/schemas/atom"
      xmlns:opensearch="http://a9.com/-/spec/opensearch/1.1/">
  <title type="text">arXiv Query</title>
  <id>https://arxiv.org/api/query</id>
  <updated>2026-08-22T00:00:00Z</updated>
  <opensearch:totalResults>3</opensearch:totalResults>
  <entry>
    <id>http://arxiv.org/abs/2401.12345v2</id>
    <published>2024-01-23T17:59:59Z</published>
    <updated>2024-02-02T10:11:12Z</updated>
    <title>
      Grounded   Answers
      for Research QA
    </title>
    <summary>  We propose a RAG
        pipeline for papers. </summary>
    <author><name>Alice   Chen</name></author>
    <author><name>Bob Doe</name></author>
    <category term="cs.CL"/>
    <category term="cs.AI"/>
    <arxiv:primary_category term="cs.CL"/>
    <link href="https://arxiv.org/pdf/2401.12345v2" type="application/pdf" rel="related"/>
    <arxiv:doi>10.1234/Grounded.Answers</arxiv:doi>
  </entry>
  <entry>
    <id>not-an-arxiv-id</id>
    <title>Malformed entry</title>
  </entry>
</feed>`

func testProvider(t *testing.T, handler http.HandlerFunc) (*Provider, *httptest.Server) {
	t.Helper()
	srv := httptest.NewServer(handler)
	p := New(Options{BaseURL: srv.URL, UserAgent: "athena-test", MinInterval: time.Millisecond})
	return p, srv
}

func TestFetchWindowParsesAtom(t *testing.T) {
	var gotQuery string
	p, srv := testProvider(t, func(w http.ResponseWriter, r *http.Request) {
		gotQuery = r.URL.Query().Get("search_query")
		w.Header().Set("Content-Type", "application/atom+xml")
		_, _ = w.Write([]byte(fixtureFeed))
	})
	defer srv.Close()

	page, err := p.FetchWindow(context.Background(), research.Window{
		From: time.Date(2026, 8, 1, 0, 0, 0, 0, time.UTC),
		To:   time.Date(2026, 8, 2, 0, 0, 0, 0, time.UTC),
	})
	if err != nil {
		t.Fatal(err)
	}

	if !strings.Contains(gotQuery, "submittedDate:[202608010000 TO 202608022359]") {
		t.Fatalf("submittedDate filter missing: %q", gotQuery)
	}
	if page.NextCursor != "2" {
		t.Fatalf("expected next start=2 (2 entries of total 3), got %q", page.NextCursor)
	}
	if len(page.Papers) != 1 {
		t.Fatalf("malformed entry should be skipped; got %d papers", len(page.Papers))
	}
	got := page.Papers[0]

	if got.Title != "Grounded Answers for Research QA" {
		t.Fatalf("whitespace not collapsed: %q", got.Title)
	}
	if got.ArxivID() != "2401.12345" || got.Identifiers[0].Value != "2401.12345" {
		t.Fatalf("arxiv id wrong: %q", got.ArxivID())
	}
	if got.DOI() != "10.1234/grounded.answers" {
		t.Fatalf("doi wrong: %q", got.DOI())
	}
	if len(got.Authors) != 2 || got.Authors[0].DisplayName != "Alice Chen" ||
		got.Authors[0].Position != 2-1 {
		t.Fatalf("authors wrong: %+v", got.Authors)
	}
	if got.Abstract != "We propose a RAG pipeline for papers." {
		t.Fatalf("abstract wrong: %q", got.Abstract)
	}
	if got.PubType != research.PubTypePreprint || got.VenueName != "arXiv" {
		t.Fatalf("type/venue wrong: %q %q", got.PubType, got.VenueName)
	}
	if got.OA.Status != research.OAStatusGreen || got.OA.URL != "https://arxiv.org/pdf/2401.12345v2" {
		t.Fatalf("OA wrong: %+v", got.OA)
	}
	if len(got.Topics) != 3 || !got.Topics[0].IsPrimary || got.Topics[0].Name != "cs.CL" {
		t.Fatalf("topics wrong: %+v", got.Topics)
	}
	if got.Year != 2024 || got.PublishedOn == nil {
		t.Fatalf("dates wrong: year=%d pub=%v", got.Year, got.PublishedOn)
	}
	if got.Provenance.NativeID != "2401.12345" {
		t.Fatalf("native id should be version-stripped: %+v", got.Provenance)
	}
}
