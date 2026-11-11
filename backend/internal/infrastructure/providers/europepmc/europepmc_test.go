package europepmc

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"athena/backend/internal/domain/research"
	"athena/backend/internal/infrastructure/providers"
)

func TestSearch_Mapping(t *testing.T) {
	fixture := `{
		"hitCount": 1,
		"resultList": {
			"result": [
				{
					"id": "32109876",
					"source": "MED",
					"pmid": "32109876",
					"pmcid": "PMC7654321",
					"doi": "10.1016/j.cell.2020.02.001",
					"title": "Cryo-EM structure of the SARS-CoV-2 spike in the prefusion conformation",
					"authorString": "Wrapp D, Wang N, Corbett KS.",
					"authorList": {
						"author": [
							{
								"fullName": "Daniel Wrapp",
								"firstName": "Daniel",
								"lastName": "Wrapp",
								"authorId": {"@type": "ORCID", "#text": "0000-0002-8610-8025"}
							},
							{
								"fullName": "Nianshuang Wang",
								"firstName": "Nianshuang",
								"lastName": "Wang"
							}
						]
					},
					"journalInfo": {
						"journal": {"title": "Science"},
						"yearOfPublication": 2020,
						"dateOfPublication": "2020 Mar 13"
					},
					"firstPublicationDate": "2020-02-19",
					"abstractText": "&lt;p&gt;The recent outbreak of SARS-CoV-2...&lt;/p&gt;",
					"isOpenAccess": "Y",
					"inPMC": "Y",
					"hasPDF": "Y",
					"citedByCount": 6500,
					"fullTextUrlList": {
						"fullTextUrl": [
							{"documentStyle": "html", "url": "https://doi.org/10.1016/j.cell.2020.02.001"},
							{"documentStyle": "pdf", "url": "https://europepmc.org/articles/pmc7654321?pdf=render"}
						]
					},
					"keywordList": {"keyword": ["coronavirus", "spike glycoprotein"]},
					"meshHeadingList": {"meshHeading": [{"descriptorName": "COVID-19"}]},
					"pubTypeList": {"pubType": ["Journal Article", "Research Support"]}
				}
			]
		}
	}`

	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte(fixture))
	}))
	defer srv.Close()

	p := New(Options{BaseURL: srv.URL, Email: "test@resarc.app"})
	papers, err := p.Search(context.Background(), "covid-19 spike", 10)
	if err != nil {
		t.Fatalf("Search failed: %v", err)
	}
	if len(papers) != 1 {
		t.Fatalf("expected 1 paper, got %d", len(papers))
	}

	paper := papers[0]
	if paper.Title != "Cryo-EM structure of the SARS-CoV-2 spike in the prefusion conformation" {
		t.Errorf("unexpected title: %q", paper.Title)
	}
	if paper.PubMedID() != "32109876" {
		t.Errorf("expected PubMedID 32109876, got %q", paper.PubMedID())
	}
	if paper.DOI() != "10.1016/j.cell.2020.02.001" {
		t.Errorf("unexpected DOI: %q", paper.DOI())
	}
	if paper.OA.Status != research.OAStatusGold {
		t.Errorf("expected OAStatusGold, got %s", paper.OA.Status)
	}
	if paper.OA.URL != "https://europepmc.org/articles/pmc7654321?pdf=render" {
		t.Errorf("expected PDF URL, got %q", paper.OA.URL)
	}
	if paper.CitedByCount != 6500 {
		t.Errorf("expected 6500 citations, got %d", paper.CitedByCount)
	}
	if paper.VenueName != "Science" {
		t.Errorf("expected Science venue, got %q", paper.VenueName)
	}
	if len(paper.Authors) != 2 {
		t.Fatalf("expected 2 authors, got %d", len(paper.Authors))
	}
	if paper.Authors[0].ProviderIDs[research.IDTypeOther] != "orcid:0000-0002-8610-8025" {
		t.Errorf("expected ORCID id, got %v", paper.Authors[0].ProviderIDs)
	}
	if paper.Abstract != "The recent outbreak of SARS-CoV-2..." {
		t.Errorf("unexpected abstract cleanup: %q", paper.Abstract)
	}
}
