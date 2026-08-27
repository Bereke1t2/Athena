// RAG ingestion: fetch permitted full text, extract, clean, chunk, embed and
// persist (docs/architecture/ai-rag.md §3–§5). Papers without a
// text-mining-permitted OA copy stay metadata-only by design.
package ai

import (
	"context"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"net/url"
	"strings"
	"time"

	"github.com/google/uuid"

	domainai "athena/backend/internal/domain/ai"
	"athena/backend/internal/domain/research"
)

// ChunkWriter persists the chunk set (+embeddings) for one paper.
type ChunkWriter interface {
	ReplaceChunks(ctx context.Context, paperID uuid.UUID,
		chunks []domainai.Chunk, vectors [][]float32, modelID string) error
}

// DocumentFetcher retrieves full-text documents over HTTP.
type DocumentFetcher interface {
	Fetch(ctx context.Context, docURL string) (io.ReadCloser, error)
}

// RAGService turns open-access PDFs into embedded chunks.
type RAGService struct {
	Papers    PaperSource
	Chunks    ChunkWriter
	Extractor domainai.TextExtractor
	Embedder  domainai.EmbeddingProvider // nil ⇒ chunks stored unembedded
	Fetcher   DocumentFetcher
	Logger    *slog.Logger

	FetchTimeout time.Duration
}

func NewRAGService(papers PaperSource, chunks ChunkWriter,
	extractor domainai.TextExtractor, embedder domainai.EmbeddingProvider,
	fetcher DocumentFetcher, log *slog.Logger) *RAGService {
	return &RAGService{
		Papers: papers, Chunks: chunks, Extractor: extractor,
		Embedder: embedder, Fetcher: fetcher, Logger: log,
		FetchTimeout: 45 * time.Second,
	}
}

// HTTPFetcher is the production DocumentFetcher with a size cap.
type HTTPFetcher struct{}

func (HTTPFetcher) Fetch(ctx context.Context, docURL string) (io.ReadCloser, error) {
	ctx, cancel := context.WithTimeout(ctx, 45*time.Second)
	defer cancel()
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, docURL, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("User-Agent", "athena/0.1 (research aggregator; full-text indexing)")
	resp, err := (&http.Client{}).Do(req)
	if err != nil {
		return nil, fmt.Errorf("fetch %s: %w", redacted(docURL), err)
	}
	if resp.StatusCode != http.StatusOK {
		resp.Body.Close()
		return nil, fmt.Errorf("fetch %s: http %d", redacted(docURL), resp.StatusCode)
	}
	return resp.Body, nil
}

func redacted(u string) string {
	if parsed, err := url.Parse(u); err == nil {
		return parsed.Host + parsed.Path
	}
	return u
}

var ErrNoPermittedFullText = fmt.Errorf("%w: no text-mining-permitted full text",
	domainai.ErrNotGrounded)

// IngestPaper indexes one paper's full text. Returns the chunk count.
// Metadata-only papers (no OA gate pass) return ErrNoPermittedFullText.
func (s *RAGService) IngestPaper(ctx context.Context, paperID uuid.UUID) (int, error) {
	detail, err := s.Papers.GetDetailByID(ctx, paperID)
	if err != nil {
		return 0, mapReadErr(err)
	}
	pdfURL, ok := fullTextURL(detail)
	if !ok {
		return 0, ErrNoPermittedFullText
	}

	fetchCtx, cancel := context.WithTimeout(ctx, s.FetchTimeout)
	defer cancel()
	body, err := s.Fetcher.Fetch(fetchCtx, pdfURL)
	if err != nil {
		return 0, err
	}
	defer body.Close()

	raw, err := s.Extractor.Extract(fetchCtx, body)
	if err != nil {
		return 0, fmt.Errorf("extract text: %w", err)
	}
	cleaned := CleanText(raw)
	drafts := ChunkText(cleaned)
	if len(drafts) == 0 {
		return 0, fmt.Errorf("no chunks produced for paper %s", paperID)
	}

	chunks := make([]domainai.Chunk, len(drafts))
	for i, d := range drafts {
		chunks[i] = domainai.Chunk{
			PaperID:     paperID,
			Seq:         d.Seq,
			SectionPath: d.SectionPath,
			Content:     d.Content,
			TokenCount:  d.TokenCount,
			ContentHash: d.ContentHash,
		}
	}

	var vectors [][]float32
	modelID := ""
	if s.Embedder != nil {
		texts := make([]string, len(chunks))
		for i, c := range chunks {
			texts[i] = c.Content
		}
		vectors, err = s.Embedder.Embed(ctx, texts)
		if err != nil {
			return 0, fmt.Errorf("embed chunks: %w", err)
		}
		modelID = s.Embedder.Model()
	}

	if err := s.Chunks.ReplaceChunks(ctx, paperID, chunks, vectors, modelID); err != nil {
		return 0, err
	}
	s.Logger.Info("rag ingestion complete", "paper_id", paperID,
		"chunks", len(chunks), "embedded", vectors != nil)
	return len(chunks), nil
}

// fullTextURL applies the legal gate (ADR-0010): only open-access papers or
// arXiv preprints proceed, and only when a plausible PDF URL exists.
func fullTextURL(d research.PaperDetail) (string, bool) {
	open := d.Summary.IsOpenAccess || d.ArxivID != ""
	if !open {
		return "", false
	}
	candidates := []string{}
	if d.BestOAURL != "" {
		candidates = append(candidates, d.BestOAURL)
	}
	for _, v := range d.Versions {
		if v.URL != "" {
			candidates = append(candidates, v.URL)
		}
	}
	if d.ArxivID != "" {
		candidates = append(candidates, "https://arxiv.org/pdf/"+d.ArxivID)
	}
	for _, c := range candidates {
		if strings.Contains(strings.ToLower(c), ".pdf") ||
			strings.Contains(c, "/pdf/") ||
			strings.Contains(c, "arxiv.org") {
			return c, true
		}
	}
	return "", false
}
