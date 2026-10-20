package crossref

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"
)

const fixtureWorks = `{
  "status": "ok",
  "message-type": "work-list",
  "message": {
    "total-results": 1,
    "items": [
      {
        "DOI": "10.1038/s41586-020-2649-2",
        "title": ["An accurate protein structure prediction with AlphaFold"],
        "abstract": "<jats:p>Proteins are essential to life, and understanding their structure can shed light on biological mechanisms.</jats:p>",
        "issued": {
          "date-parts": [[2021, 7, 15]]
        },
        "published-online": {
          "date-parts": [[2021, 7, 15]]
        },
        "container-title": ["Nature"],
        "type": "journal-article",
        "author": [
          {
            "given": "John",
            "family": "Jumper",
            "name": "John Jumper"
          },
          {
            "given": "Demis",
            "family": "Hassabis",
            "name": "Demis Hassabis"
          }
        ],
        "is-referenced-by-count": 15000,
        "URL": "http://dx.doi.org/10.1038/s41586-020-2649-2",
        "subject": ["Biophysics", "Structural Biology"]
      }
    ]
  }
}`

func TestCrossrefSearch(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/works" {
			http.NotFound(w, r)
			return
		}
		if r.URL.Query().Get("query") != "AlphaFold" {
			t.Errorf("unexpected query: %s", r.URL.Query().Get("query"))
		}
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(fixtureWorks))
	}))
	defer srv.Close()

	p := New(Options{
		BaseURL: srv.URL,
		Mailto:  "dev@example.com",
	})

	papers, err := p.Search(context.Background(), "AlphaFold", 10)
	if err != nil {
		t.Fatalf("Search failed: %v", err)
	}

	if len(papers) != 1 {
		t.Fatalf("expected 1 paper, got %d", len(papers))
	}

	paper := papers[0]
	if paper.Title != "An accurate protein structure prediction with AlphaFold" {
		t.Errorf("unexpected title: %s", paper.Title)
	}
	if paper.DOI() != "10.1038/s41586-020-2649-2" {
		t.Errorf("unexpected DOI: %s", paper.DOI())
	}
	if len(paper.Authors) != 2 {
		t.Errorf("expected 2 authors, got %d", len(paper.Authors))
	}
	if paper.Authors[0].DisplayName != "John Jumper" {
		t.Errorf("expected author John Jumper, got %s", paper.Authors[0].DisplayName)
	}
	if paper.Abstract == "" {
		t.Errorf("expected non-empty abstract")
	}
	if paper.CitedByCount != 15000 {
		t.Errorf("expected 15000 citations, got %d", paper.CitedByCount)
	}
}

func TestCrossrefSearch_EmptyQuery(t *testing.T) {
	p := New(Options{
		BaseURL: "http://localhost",
		Mailto:  "dev@example.com",
	})

	_, err := p.Search(context.Background(), "   ", 10)
	if err == nil {
		t.Errorf("expected error on empty query, got nil")
	}
}
