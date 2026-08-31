package discover

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"

	"athena/backend/internal/domain/research"
	domainsearch "athena/backend/internal/domain/search"
)

type fakeProvider struct {
	slug   string
	papers []research.Paper
	err    error
}

func (f *fakeProvider) Slug() string { return f.slug }

func (f *fakeProvider) Search(context.Context, string, int) ([]research.Paper, error) {
	return f.papers, f.err
}

type fakeStore struct {
	upserted []research.Paper
}

func (f *fakeStore) UpsertPaper(_ context.Context, p research.Paper) (research.UpsertResult, error) {
	f.upserted = append(f.upserted, p)
	return research.UpsertResult{PaperID: uuid.New(), Created: true}, nil
}

func paperWithDOI(doi, title string, cites int, year int) research.Paper {
	p := research.Paper{
		Title:        title,
		CitedByCount: cites,
		Year:         year,
		PublishedOn:  ptr(time.Date(year, 6, 1, 0, 0, 0, 0, time.UTC)),
		Identifiers: []research.Identifier{
			{Type: research.IDTypeDOI, Value: doi},
		},
	}
	p.Provenance.ProviderSlug = "test"
	p.Provenance.NativeID = doi
	research.DeriveIdentity(&p)
	return p
}

func ptr[T any](v T) *T { return &v }

func TestSearchMergesDuplicatesAcrossProviders(t *testing.T) {
	a := paperWithDOI("10.1000/abc", "Attention Is All You Need", 90000, 2017)
	b := paperWithDOI("10.1000/abc", "Attention Is All You Need", 95000, 2017)
	b.VenueName = "NeurIPS" // richer record arrives from second source

	store := &fakeStore{}
	svc := NewService(
		[]ProviderSearcher{
			&fakeProvider{slug: "one", papers: []research.Paper{a}},
			&fakeProvider{slug: "two", papers: []research.Paper{b}},
			&fakeProvider{slug: "broken", err: context.DeadlineExceeded},
		}, store, nil, nil)

	res, err := svc.Search(context.Background(),
		domainsearch.Query{Q: "attention", Limit: 10})
	if err != nil {
		t.Fatal(err)
	}
	if len(res.Items) != 1 {
		t.Fatalf("want 1 merged item, got %d", len(res.Items))
	}
	if res.Items[0].Paper.CitedByCount != 95000 || res.Items[0].Paper.VenueName != "NeurIPS" {
		t.Fatalf("merge kept wrong fields: %+v", res.Items[0].Paper)
	}
	if len(res.Items[0].Paper.ID) == 0 {
		t.Fatal("expected persisted uuid on summary")
	}
	if len(store.upserted) != 1 {
		t.Fatalf("expected exactly one upsert, got %d", len(store.upserted))
	}
	var brokenOK bool
	for _, s := range res.Sources {
		if s.Slug == "broken" && !s.OK && s.Error != "" {
			brokenOK = true
		}
	}
	if !brokenOK {
		t.Fatal("provider failure not surfaced in sources status")
	}
}

func TestSearchSortNewest(t *testing.T) {
	old := paperWithDOI("10.1/old", "Old topic paper", 5, 2001)
	new := paperWithDOI("10.1/new", "New topic paper", 5, 2025)

	svc := NewService(
		[]ProviderSearcher{&fakeProvider{slug: "p", papers: []research.Paper{old, new}}},
		&fakeStore{}, nil, nil)

	res, err := svc.Search(context.Background(),
		domainsearch.Query{Q: "topic", Sort: domainsearch.SortNewest, Limit: 10})
	if err != nil {
		t.Fatal(err)
	}
	if res.Items[0].Paper.Year != 2025 {
		t.Fatalf("newest sort failed: first item year %d", res.Items[0].Paper.Year)
	}
}

func TestRelevanceRewardsTextAndAgreement(t *testing.T) {
	multi := &merged{paper: paperWithDOI("10.1/x", "Graph neural networks survey", 10, 2023),
		sources: []string{"a", "b"}}
	single := &merged{paper: paperWithDOI("10.2/y", "Graph neural networks survey", 10, 2023),
		sources: []string{"a"}}

	tokens, phrase := tokenize("graph neural networks")
	if relevance(tokens, phrase, multi) <= relevance(tokens, phrase, single) {
		t.Fatal("cross-source agreement must raise the score")
	}

	onTopic := &merged{paper: paperWithDOI("10.3/z", "Graph neural networks", 0, 2024), sources: []string{"a"}}
	offTopic := &merged{paper: paperWithDOI("10.4/w", "Coastal erosion dynamics", 5000, 2024), sources: []string{"a"}}
	if relevance(tokens, phrase, offTopic) >= relevance(tokens, phrase, onTopic) {
		t.Fatal("textual relevance must outweigh raw citations here")
	}
}

func TestRicherMerge(t *testing.T) {
	a := paperWithDOI("10.1000/abc", "Paper Title", 10, 2023)
	a.OA = research.OpenAccess{
		Status: research.OAStatusClosed,
		URL:    "https://publisher.com/article/123",
	}
	a.Versions = []research.VersionRef{
		{Kind: research.VersionPublisher, URL: "https://publisher.com/article/123"},
	}

	b := paperWithDOI("10.1000/abc", "Paper Title", 15, 2023)
	b.Identifiers = []research.Identifier{
		{Type: research.IDTypeDOI, Value: "10.1000/abc"},
		{Type: research.IDTypeArxiv, Value: "2301.00001"},
	}
	b.OA = research.OpenAccess{
		Status: research.OAStatusGreen,
		URL:    "https://arxiv.org/pdf/2301.00001",
	}
	b.Versions = []research.VersionRef{
		{Kind: research.VersionPreprint, URL: "https://arxiv.org/pdf/2301.00001"},
	}

	merged := richer(a, b)

	if !merged.OA.IsOpen() || merged.OA.Status != research.OAStatusGreen {
		t.Fatalf("richer should have upgraded to Green OA, got %+v", merged.OA)
	}
	if merged.OA.URL != "https://arxiv.org/pdf/2301.00001" {
		t.Fatalf("richer should prefer direct PDF URL, got %q", merged.OA.URL)
	}
	if len(merged.Versions) != 2 {
		t.Fatalf("richer should merge both unique versions, got %d versions: %+v", len(merged.Versions), merged.Versions)
	}
	if len(merged.Identifiers) != 2 {
		t.Fatalf("richer should retain all unique identifiers, got %d", len(merged.Identifiers))
	}
}

