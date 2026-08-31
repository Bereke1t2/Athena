package ai

import (
	"context"
	"errors"
	"log/slog"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"

	domainai "athena/backend/internal/domain/ai"
	"athena/backend/internal/domain/research"
)

// ---- fakes ------------------------------------------------------------------

type fakeLLM struct {
	calls   int
	prompts []string
}

func (f *fakeLLM) Model() string { return "fake-1" }

func (f *fakeLLM) Generate(_ context.Context, req domainai.GenerateRequest) (domainai.GenerateResponse, error) {
	f.calls++
	f.prompts = append(f.prompts, req.Prompt)
	return domainai.GenerateResponse{
		Text:  summaryJSON(),
		Model: f.Model(),
		Usage: domainai.TokenUsage{PromptTokens: 10, CompletionTokens: 5, TotalTokens: 15},
	}, nil
}

func (f *fakeLLM) GenerateStream(context.Context, domainai.GenerateRequest) (domainai.StreamReader, error) {
	return nil, errors.New("not used in summary tests")
}

// blockingLLM blocks in Generate until the context is cancelled, simulating a
// slow or unreachable provider.
type blockingLLM struct{}

func (blockingLLM) Model() string { return "blocking-1" }

func (blockingLLM) Generate(ctx context.Context, _ domainai.GenerateRequest) (domainai.GenerateResponse, error) {
	<-ctx.Done()
	return domainai.GenerateResponse{}, ctx.Err()
}

func (blockingLLM) GenerateStream(context.Context, domainai.GenerateRequest) (domainai.StreamReader, error) {
	return nil, errors.New("not used")
}

func testLogger() *slog.Logger { return slog.New(slog.DiscardHandler) }

func summaryJSON() string {
	return `{"tldr":"Short.","simple_explanation":"Simple words.","academic_explanation":"Formal.",
		"key_findings":["A","B"],"methodology":"M","results":"R","limitations":["L"],
		"why_it_matters":"W"}`
}

func detailWithAbstract() research.PaperDetail {
	abs := "We study transformers."
	return research.PaperDetail{
		Summary: research.PaperSummary{
			ID: uuid.New(), Title: "Attention Paper", Abstract: &abs,
			PublicationType: research.PubTypeArticle,
		},
	}
}

// ---- tests ------------------------------------------------------------------

// Acceptance: "Summary cache hit path costs zero tokens (content-hash keyed)."
func TestSummarizeCacheHitCostsZeroTokens(t *testing.T) {
	llm := &fakeLLM{}
	store := &fakeSummaryStore{saved: map[string]domainai.Summary{}}
	svc := NewSummaryService(llm, store, &fakePapers{detailWithAbstract()},
		&fakeChunks{}, testLogger())

	first, err := svc.Summarize(context.Background(), uuid.New(), domainai.LevelBeginner)
	if err != nil {
		t.Fatal(err)
	}
	if first.CacheHit || llm.calls != 1 {
		t.Fatalf("first call must be a miss: hit=%v calls=%d", first.CacheHit, llm.calls)
	}

	second, err := svc.Summarize(context.Background(), first.PaperID, domainai.LevelBeginner)
	if err != nil {
		t.Fatal(err)
	}
	if !second.CacheHit {
		t.Fatal("second call must be a cache hit")
	}
	if second.TokenUsage.TotalTokens != 0 {
		t.Fatalf("cache hit must cost zero tokens, got %+v", second.TokenUsage)
	}
	if llm.calls != 1 {
		t.Fatalf("cache hit must not call the model, calls=%d", llm.calls)
	}
}

// Content change invalidates the cache even at the same level.
func TestSummarizeRegeneratesWhenContentChanges(t *testing.T) {
	llm := &fakeLLM{}
	store := &fakeSummaryStore{saved: map[string]domainai.Summary{}}
	papers := &fakePapers{detailWithAbstract()}
	svc := NewSummaryService(llm, store, papers, &fakeChunks{}, testLogger())

	id := uuid.New()
	if _, err := svc.Summarize(context.Background(), id, domainai.LevelExpert); err != nil {
		t.Fatal(err)
	}
	abs := "Completely different findings now."
	papers.detail.Summary.Abstract = &abs

	if _, err := svc.Summarize(context.Background(), id, domainai.LevelExpert); err != nil {
		t.Fatal(err)
	}
	if llm.calls != 2 {
		t.Fatalf("changed content must regenerate, calls=%d", llm.calls)
	}
}

// Acceptance: "Metadata-only papers degrade honestly (based_on: abstract)."
func TestSummarizeMetadataOnlyDegradesHonestly(t *testing.T) {
	llm := &fakeLLM{}
	svc := NewSummaryService(llm, &fakeSummaryStore{saved: map[string]domainai.Summary{}},
		&fakePapers{detailWithAbstract()}, &fakeChunks{}, testLogger())

	sum, err := svc.Summarize(context.Background(), uuid.New(), domainai.LevelIntermediate)
	if err != nil {
		t.Fatal(err)
	}
	if sum.Grounding.BasedOn != "abstract" || sum.Grounding.ChunkCount != 0 {
		t.Fatalf("expected abstract grounding, got %+v", sum.Grounding)
	}
	if strings.Contains(llm.prompts[0], "### CONTEXT") {
		t.Fatal("metadata-only prompt must not fabricate a full-text context section")
	}
}

func TestSummarizeFullTextGrounding(t *testing.T) {
	llm := &fakeLLM{}
	chunks := []domainai.Chunk{{ID: uuid.New(), Seq: 0, ContentHash: "h1", Content: "methods text"}}
	svc := NewSummaryService(llm, &fakeSummaryStore{saved: map[string]domainai.Summary{}},
		&fakePapers{detailWithAbstract()}, &fakeChunks{list: chunks}, testLogger())

	sum, err := svc.Summarize(context.Background(), uuid.New(), domainai.LevelExpert)
	if err != nil {
		t.Fatal(err)
	}
	if sum.Grounding.BasedOn != "abstract+full_text" || sum.Grounding.ChunkCount != 1 {
		t.Fatalf("wrong grounding: %+v", sum.Grounding)
	}
	if !strings.Contains(llm.prompts[0], "[chunk 1]") {
		t.Fatal("prompt must embed numbered chunks")
	}
	if !strings.Contains(llm.prompts[0], "expert-level reader") {
		t.Fatal("prompt must carry the explanation level")
	}
}

// A cache write failure must not fail the request.
func TestSummarizeCacheWriteFailureStillServes(t *testing.T) {
	llm := &fakeLLM{}
	svc := NewSummaryService(llm, &fakeSummaryStore{fail: true},
		&fakePapers{detailWithAbstract()}, &fakeChunks{}, testLogger())
	if _, err := svc.Summarize(context.Background(), uuid.New(), domainai.LevelBeginner); err != nil {
		t.Fatalf("summary should survive cache write failure: %v", err)
	}
}

// Lazy indexing runs when no chunks exist yet.
func TestSummarizeTriggersLazyIndexing(t *testing.T) {
	llm := &fakeLLM{}
	store := &fakeSummaryStore{saved: map[string]domainai.Summary{}}
	chunkSrc := &fakeChunks{}
	indexed := &fakeIndexer{
		chunks: []domainai.Chunk{{ID: uuid.New(), Seq: 0, ContentHash: "h", Content: "full text"}},
		target: &chunkSrc.list,
	}
	svc := NewSummaryService(llm, store, &fakePapers{detailWithAbstract()},
		chunkSrc, testLogger())
	svc.Indexer = indexed

	sum, err := svc.Summarize(context.Background(), uuid.New(), domainai.LevelBeginner)
	if err != nil {
		t.Fatal(err)
	}
	if indexed.calls != 1 {
		t.Fatalf("indexer must run exactly once, got %d", indexed.calls)
	}
	if sum.Grounding.BasedOn != "abstract+full_text" {
		t.Fatalf("post-index grounding wrong: %+v", sum.Grounding)
	}
}

// A stalling LLM must be bounded by genTimeout so the request fails fast
// instead of hanging the handler.
func TestSummarizeBoundsSlowGeneration(t *testing.T) {
	svc := NewSummaryService(blockingLLM{}, &fakeSummaryStore{saved: map[string]domainai.Summary{}},
		&fakePapers{detailWithAbstract()}, &fakeChunks{}, testLogger())
	svc.genTimeout = 20 * time.Millisecond

	start := time.Now()
	_, err := svc.Summarize(context.Background(), uuid.New(), domainai.LevelBeginner)
	elapsed := time.Since(start)

	if !errors.Is(err, context.DeadlineExceeded) {
		t.Fatalf("expected deadline exceeded, got %v", err)
	}
	if elapsed > time.Second {
		t.Fatalf("Summarize must fail fast at the deadline, took %v", elapsed)
	}
}

func TestParseSummaryJSONToleratesFences(t *testing.T) {
	text := "```json\n" + summaryJSON() + "\n```"
	sections, tldr, err := parseSummaryJSON(text)
	if err != nil {
		t.Fatal(err)
	}
	if tldr == "" || len(sections.KeyFindings) != 2 {
		t.Fatalf("bad parse: tldr=%q sections=%+v", tldr, sections)
	}
}

func TestContentHashChangesWithInput(t *testing.T) {
	a := ContentHash("t", "abs", nil)
	b := ContentHash("t", "abs2", nil)
	c := ContentHash("t", "abs", []domainai.Chunk{{ContentHash: "x"}})
	if a == b || a == c {
		t.Fatal("content hash must be input-sensitive")
	}
}

func TestFullTextURLResolution(t *testing.T) {
	cases := []struct {
		name    string
		detail  research.PaperDetail
		wantURL string
		wantOK  bool
	}{
		{
			name: "arxiv id always resolves",
			detail: research.PaperDetail{
				ArxivID: "2301.00001",
			},
			wantURL: "https://arxiv.org/pdf/2301.00001",
			wantOK:  true,
		},
		{
			name: "direct pdf best oa url without is_open_access flag",
			detail: research.PaperDetail{
				Summary:   research.PaperSummary{IsOpenAccess: false},
				BestOAURL: "https://example.org/papers/test.pdf",
			},
			wantURL: "https://example.org/papers/test.pdf",
			wantOK:  true,
		},
		{
			name: "biorxiv version url without is_open_access flag",
			detail: research.PaperDetail{
				Summary:   research.PaperSummary{IsOpenAccess: false},
				BestOAURL: "https://example.org/landing/123",
				Versions: []research.VersionLine{
					{Kind: research.VersionPreprint, URL: "https://www.biorxiv.org/content/10.1101/123.full.pdf"},
				},
			},
			wantURL: "https://www.biorxiv.org/content/10.1101/123.full.pdf",
			wantOK:  true,
		},
		{
			name: "open access with landing page best oa url fallback",
			detail: research.PaperDetail{
				Summary:   research.PaperSummary{IsOpenAccess: true},
				BestOAURL: "https://openaccess.org/article/123",
			},
			wantURL: "https://openaccess.org/article/123",
			wantOK:  true,
		},
		{
			name: "closed access with only landing page returns false",
			detail: research.PaperDetail{
				Summary:   research.PaperSummary{IsOpenAccess: false},
				BestOAURL: "https://publisher.com/article/123",
				Versions: []research.VersionLine{
					{Kind: research.VersionPublisher, URL: "https://publisher.com/article/123"},
				},
			},
			wantURL: "",
			wantOK:  false,
		},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			gotURL, gotOK := fullTextURL(tc.detail)
			if gotOK != tc.wantOK {
				t.Fatalf("fullTextURL() ok = %v, want %v", gotOK, tc.wantOK)
			}
			if gotURL != tc.wantURL {
				t.Fatalf("fullTextURL() url = %q, want %q", gotURL, tc.wantURL)
			}
		})
	}
}

