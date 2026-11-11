package europepmc

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"athena/backend/internal/domain/research"
	"athena/backend/internal/infrastructure/providers"
)

const sampleSearchResponseJSON = `{
  "version": "6.9",
  "hitCount": 1,
  "nextCursorMark": "AoE/testcursor123",
  "resultList": {
    "result": [
      {
        "id": "38271625",
        "source": "MED",
        "pmid": "38271625",
        "pmcid": "PMC10800001",
        "doi": "10.1038/s41586-024-07000-0",
        "title": "<i>Structure</i> and mechanism of the human &amp; primate receptor",
        "authorString": "Doe J, Smith A.",
        "authorList": {
          "author": [
            {
              "fullName": "John Doe",
              "firstName": "John",
              "lastName": "Doe",
              "authorId": {
                "@type": "ORCID",
                "#text": "0000-0002-1825-0097"
              }
            },
            {
              "fullName": "Alice Smith",
              "firstName": "Alice",
              "lastName": "Smith"
            }
          ]
        },
        "journalInfo": {
          "journal": {
            "title": "Nature Medicine"
          },
          "yearOfPublication": 2024,
          "dateOfPublication": "2024 Jan 15"
        },
        "pubYear": "2024",
        "firstPublicationDate": "2024-01-15",
        "abstractText": "<p><b>Background:</b> Structural insights into <i>membrane</i> targets.</p>",
        "isOpenAccess": "Y",
        "inEPMC": "Y",
        "inPMC": "Y",
        "hasPDF": "Y",
        "citedByCount": 38,
        "fullTextUrlList": {
          "fullTextUrl": [
            {
              "availability": "Subscription required",
              "availabilityCode": "S",
              "documentStyle": "html",
              "site": "DOI",
              "url": "https://doi.org/10.1038/s41586-024-07000-0"
            },
            {
              "availability": "Open access",
              "availabilityCode": "OA",
              "documentStyle": "pdf",
              "site": "Europe_PMC",
              "url": "https://europepmc.org/articles/PMC10800001?pdf=render"
            }
          ]
        },
        "keywordList": {
          "keyword": ["Structural Biology", "Membrane Protein"]
        },
        "meshHeadingList": {
          "meshHeading": [
            {
              "descriptorName": "Cryoelectron Microscopy"
            }
          ]
        },
        "pubTypeList": {
          "pubType": ["journal article", "Research Support, Non-U.S. Gov't"]
        }
      }
    ]
  }
}`

func TestSearchMapsNormalizedPapers(t *testing.T) {
	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		assert.Equal(t, "/search", r.URL.Path)
		assert.Equal(t, "crispr", r.URL.Query().Get("query"))
		assert.Equal(t, "json", r.URL.Query().Get("format"))
		assert.Equal(t, "core", r.URL.Query().Get("resultType"))
		assert.Equal(t, "25", r.URL.Query().Get("pageSize"))

		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(sampleSearchResponseJSON))
	}))
	defer ts.Close()

	p := New(Options{
		BaseURL: ts.URL,
		MaxRPS:  100,
	})

	papers, err := p.Search(context.Background(), "crispr", 25)
	require.NoError(t, err)
	require.Len(t, papers, 1)

	paper := papers[0]
	assert.Equal(t, "Structure and mechanism of the human & primate receptor", paper.Title)
	assert.Equal(t, "Background: Structural insights into membrane targets.", paper.Abstract)
	assert.Equal(t, "Nature Medicine", paper.VenueName)
	assert.Equal(t, "journal", paper.VenueType)
	assert.Equal(t, 2024, paper.Year)
	require.NotNil(t, paper.PublishedOn)
	assert.Equal(t, "2024-01-15", paper.PublishedOn.Format("2006-01-02"))
	assert.Equal(t, 38, paper.CitedByCount)
	assert.Equal(t, research.PubTypeArticle, paper.PubType)

	// Identifiers
	assert.Equal(t, "10.1038/s41586-024-07000-0", paper.DOI())
	assert.Equal(t, "38271625", paper.PubMedID())
	assert.Contains(t, paper.Identifiers, research.Identifier{
		Type:  research.IDTypeOther,
		Value: "pmc:10800001",
	})

	// Authors
	require.Len(t, paper.Authors, 2)
	assert.Equal(t, "John Doe", paper.Authors[0].DisplayName)
	assert.Equal(t, 1, paper.Authors[0].Position)
	assert.Equal(t, "orcid:0000-0002-1825-0097", paper.Authors[0].ProviderIDs[research.IDTypeOther])
	assert.Equal(t, "Alice Smith", paper.Authors[1].DisplayName)
	assert.Equal(t, 2, paper.Authors[1].Position)

	// Open Access & PDF
	assert.Equal(t, research.OAStatusGold, paper.OA.Status)
	assert.Equal(t, "https://europepmc.org/articles/PMC10800001?pdf=render", paper.OA.URL)
	require.NotEmpty(t, paper.Versions)
	assert.Equal(t, "https://europepmc.org/articles/PMC10800001?pdf=render", paper.Versions[0].URL)

	// Topics
	require.Len(t, paper.Topics, 3)
	assert.Equal(t, "Structural Biology", paper.Topics[0].Name)
	assert.True(t, paper.Topics[0].IsPrimary)
	assert.Equal(t, "Membrane Protein", paper.Topics[1].Name)
	assert.Equal(t, "Cryoelectron Microscopy", paper.Topics[2].Name)

	// Provenance
	assert.Equal(t, Slug, paper.Provenance.ProviderSlug)
	assert.Equal(t, "38271625", paper.Provenance.NativeID)
}

func TestSearchRequiresQuery(t *testing.T) {
	p := New(Options{})
	_, err := p.Search(context.Background(), "   ", 10)
	require.Error(t, err)
	assert.True(t, errors.Is(err, providers.ErrBadWindow))
}

func TestSearchSchemaDrift(t *testing.T) {
	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(`{not valid json`))
	}))
	defer ts.Close()

	p := New(Options{BaseURL: ts.URL})
	_, err := p.Search(context.Background(), "cancer", 10)
	require.Error(t, err)
	assert.True(t, errors.Is(err, providers.ErrSchemaDrift))
}

func TestFetchWindowMapsPageAndCursor(t *testing.T) {
	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		assert.Equal(t, "/search", r.URL.Path)
		assert.Contains(t, r.URL.Query().Get("query"), "FIRST_PDATE:[2026-01-01 TO 2026-01-07]")
		assert.Equal(t, "*", r.URL.Query().Get("cursorMark"))
		assert.Equal(t, "P_PDATE_D asc", r.URL.Query().Get("sort"))

		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(sampleSearchResponseJSON))
	}))
	defer ts.Close()

	p := New(Options{BaseURL: ts.URL})
	from := time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)
	to := time.Date(2026, 1, 7, 0, 0, 0, 0, time.UTC)

	page, err := p.FetchWindow(context.Background(), research.Window{
		From: from,
		To:   to,
	})
	require.NoError(t, err)
	assert.Len(t, page.Papers, 1)
	assert.Equal(t, "AoE/testcursor123", page.NextCursor)
}

func TestFetchWindowValidatesWindow(t *testing.T) {
	p := New(Options{})
	_, err := p.FetchWindow(context.Background(), research.Window{})
	require.Error(t, err)
	assert.True(t, errors.Is(err, providers.ErrBadWindow))

	now := time.Now()
	_, err = p.FetchWindow(context.Background(), research.Window{
		From: now,
		To:   now.Add(-time.Hour),
	})
	require.Error(t, err)
	assert.True(t, errors.Is(err, providers.ErrBadWindow))
}

func TestStripHTMLAndEntities(t *testing.T) {
	raw := `<p>The <i>in vivo</i> effect of &lt;drug A&gt; &amp; &apos;B&apos;.</p>`
	clean := stripHTML(raw)
	assert.Equal(t, "The in vivo effect of <drug A> & 'B'.", clean)
}
