package ai

import (
	"context"
	"strings"
	"testing"

	"github.com/google/uuid"

	domainai "athena/backend/internal/domain/ai"
)

func TestCleanTextDehyphenatesAndTrims(t *testing.T) {
	in := "atten-\ntion is all\r\n\r\n\r\ntext  with\tgaps\nx\ny"
	out := CleanText(in)
	if !strings.Contains(out, "attention") {
		t.Fatalf("dehyphenation failed: %q", out)
	}
	if strings.Contains(out, "\nx\n") || strings.Contains(out, " x ") {
		t.Fatalf("single-char junk lines must be dropped: %q", out)
	}
}

func TestChunkTextRespectsTargetSize(t *testing.T) {
	para := strings.Repeat("word ", 200) // ~1000 chars ≈ 250 tokens
	cleaned := CleanText(strings.Repeat(para+"\n\n", 10))
	chunks := ChunkText(cleaned)
	if len(chunks) < 2 {
		t.Fatalf("expected multiple chunks, got %d", len(chunks))
	}
	for _, c := range chunks {
		if c.TokenCount > chunkTargetTokens*2 {
			t.Fatalf("chunk %d oversized: %d tokens", c.Seq, c.TokenCount)
		}
		if c.ContentHash == "" || c.Content == "" {
			t.Fatalf("chunk %d missing content/hash", c.Seq)
		}
	}
	// Sequential ids
	for i, c := range chunks {
		if c.Seq != i {
			t.Fatalf("seq mismatch at %d: %d", i, c.Seq)
		}
	}
}

func TestChunkTextDetectsSections(t *testing.T) {
	intro := strings.Repeat("We study attention mechanisms in depth. ", 6)
	methods := strings.Repeat("We trained transformer models carefully. ", 6)
	cleaned := "1. Introduction\n" + intro + "\n\n2. Methods\n" + methods + "\n"
	chunks := ChunkText(CleanText(cleaned))
	if len(chunks) < 2 {
		t.Fatalf("want >=2 sectioned chunks, got %d", len(chunks))
	}
	foundIntro, foundMethods := false, false
	for _, c := range chunks {
		if strings.Contains(c.SectionPath, "Introduction") {
			foundIntro = true
		}
		if strings.Contains(c.SectionPath, "Methods") && strings.Contains(c.Content, "trained") {
			foundMethods = true
		}
	}
	if !foundIntro || !foundMethods {
		t.Fatalf("section detection failed: %+v", chunks)
	}
}

func TestChunkTextOverlapCarriesContext(t *testing.T) {
	long := strings.Repeat("sentence about transformers here. ", 120) // > 800 tokens
	chunks := ChunkText(CleanText(long))
	if len(chunks) < 2 {
		t.Skip("text fit in one chunk")
	}
	// The tail of chunk N's content should appear in chunk N+1 (overlap).
	tail := lastWords(chunks[0].Content, 8)
	if !strings.Contains(chunks[1].Content, tail) {
		t.Fatalf("overlap missing: %q not in next chunk head", tail)
	}
}

// ---- retrieval --------------------------------------------------------------

type fakeSearcher struct {
	vec     []domainai.RetrievedChunk
	kw      []domainai.RetrievedChunk
	leading []domainai.RetrievedChunk
	errV    error
	errK    error
	errL    error
}

func (f *fakeSearcher) SearchByVector(context.Context, uuid.UUID, []float32, string, int) ([]domainai.RetrievedChunk, error) {
	return f.vec, f.errV
}

func (f *fakeSearcher) SearchKeyword(context.Context, uuid.UUID, string, int) ([]domainai.RetrievedChunk, error) {
	return f.kw, f.errK
}

func (f *fakeSearcher) ListLeadingChunks(context.Context, uuid.UUID, int) ([]domainai.RetrievedChunk, error) {
	return f.leading, f.errL
}

func TestRetrieveFusesBothLegs(t *testing.T) {
	a := domainai.RetrievedChunk{Chunk: domainai.Chunk{ID: uuid.New(), Seq: 0}}
	b := domainai.RetrievedChunk{Chunk: domainai.Chunk{ID: uuid.New(), Seq: 1}}
	c := domainai.RetrievedChunk{Chunk: domainai.Chunk{ID: uuid.New(), Seq: 2}}

	svc := NewRetrievalService(stubEmbedder{}, &fakeSearcher{
		vec: []domainai.RetrievedChunk{a, b}, // a ranks first on vector leg
		kw:  []domainai.RetrievedChunk{b, c}, // b ranks first on keyword leg
	})

	got, err := svc.Retrieve(context.Background(), domainai.ChunkQuery{
		PaperID: uuid.New(), Question: "attention", TopK: 3})
	if err != nil {
		t.Fatal(err)
	}
	if len(got) != 3 {
		t.Fatalf("want 3 fused, got %d", len(got))
	}
	// b appears top on both legs → must outrank everything.
	if got[0].ID != b.ID {
		t.Fatalf("RRF fusion wrong: winner %v", got[0].ID)
	}
}

func TestRetrieveKeywordOnlyWithoutEmbedder(t *testing.T) {
	b := domainai.RetrievedChunk{Chunk: domainai.Chunk{ID: uuid.New()}}
	svc := NewRetrievalService(nil, &fakeSearcher{kw: []domainai.RetrievedChunk{b}})
	got, err := svc.Retrieve(context.Background(), domainai.ChunkQuery{
		PaperID: uuid.New(), Question: "q"})
	if err != nil || len(got) != 1 {
		t.Fatalf("keyword-only retrieval failed: %v %v", got, err)
	}
}

func TestRetrieveSurvivesEmbeddingOutage(t *testing.T) {
	kw := domainai.RetrievedChunk{Chunk: domainai.Chunk{ID: uuid.New()}}
	svc := NewRetrievalService(failEmbedder{}, &fakeSearcher{
		errV: errFakeWrite, kw: []domainai.RetrievedChunk{kw}})
	got, err := svc.Retrieve(context.Background(), domainai.ChunkQuery{
		PaperID: uuid.New(), Question: "q"})
	if err != nil || len(got) != 1 {
		t.Fatalf("vector outage must degrade to keyword: %v %v", got, err)
	}
}

func TestRetrieveFallbackToLeadingChunks(t *testing.T) {
	lead := domainai.RetrievedChunk{Chunk: domainai.Chunk{ID: uuid.New(), Content: "Introduction excerpt"}}
	svc := NewRetrievalService(stubEmbedder{}, &fakeSearcher{
		vec:     nil, // 0 hits on vector
		kw:      nil, // 0 hits on keyword
		leading: []domainai.RetrievedChunk{lead},
	})
	got, err := svc.Retrieve(context.Background(), domainai.ChunkQuery{
		PaperID: uuid.New(), Question: "what is this paper about?", TopK: 3})
	if err != nil || len(got) != 1 || got[0].ID != lead.ID {
		t.Fatalf("broad question with 0 search hits must fallback to leading chunks: got %+v, err %v", got, err)
	}
}

// ---- stub embedders ---------------------------------------------------------

type stubEmbedder struct{}

func (stubEmbedder) Model() string { return "stub" }

func (stubEmbedder) Embed(_ context.Context, texts []string) ([][]float32, error) {
	out := make([][]float32, len(texts))
	for i := range texts {
		out[i] = []float32{1, 0, 0}
	}
	return out, nil
}

type failEmbedder struct{}

func (failEmbedder) Model() string { return "fail" }

func (failEmbedder) Embed(context.Context, []string) ([][]float32, error) {
	return nil, errFakeWrite
}

func lastWords(s string, n int) string {
	fields := strings.Fields(s)
	if len(fields) <= n {
		return s
	}
	return strings.Join(fields[len(fields)-n:], " ")
}
