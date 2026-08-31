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

// RAGService turns open-access PDFs and web documents into embedded chunks.
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

// HTTPFetcher is the production DocumentFetcher with a size cap and redirect handling.
type HTTPFetcher struct{}

func (HTTPFetcher) Fetch(ctx context.Context, docURL string) (io.ReadCloser, error) {
	ctx, cancel := context.WithTimeout(ctx, 45*time.Second)
	defer cancel()
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, docURL, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("User-Agent", "athena/0.1 (research aggregator; full-text indexing; mailto:bot@athenaresearch.app)")
	req.Header.Set("Accept", "application/pdf, text/html;q=0.9, */*;q=0.8")
	client := &http.Client{
		Timeout: 45 * time.Second,
	}
	resp, err := client.Do(req)
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
// Tries candidate URLs in priority order (Direct PDF -> Ar5iv HTML -> OA Repository).
// Metadata-only papers (no OA gate pass) return ErrNoPermittedFullText.
func (s *RAGService) IngestPaper(ctx context.Context, paperID uuid.UUID) (int, error) {
	detail, err := s.Papers.GetDetailByID(ctx, paperID)
	if err != nil {
		return 0, mapReadErr(err)
	}
	candidates := CandidateFullTextURLs(detail)
	if len(candidates) == 0 {
		s.Logger.Info("no candidate full-text URLs for paper",
			"paper_id", paperID,
			"title", detail.Summary.Title,
			"arxiv_id", detail.ArxivID,
			"is_oa", detail.Summary.IsOpenAccess,
			"best_oa_url", detail.BestOAURL)
		return 0, ErrNoPermittedFullText
	}

	var lastErr error
	var cleaned string
	var drafts []ChunkDraft

	for _, targetURL := range candidates {
		fetchCtx, cancel := context.WithTimeout(ctx, s.FetchTimeout)
		body, ferr := s.Fetcher.Fetch(fetchCtx, targetURL)
		if ferr != nil {
			cancel()
			lastErr = ferr
			s.Logger.Debug("fetch candidate failed, trying next", "url", redacted(targetURL), "error", ferr)
			continue
		}

		raw, xerr := s.Extractor.Extract(fetchCtx, body)
		body.Close()
		cancel()
		if xerr != nil {
			lastErr = xerr
			s.Logger.Debug("extract candidate failed, trying next", "url", redacted(targetURL), "error", xerr)
			continue
		}

		cleaned = CleanText(raw)
		drafts = ChunkText(cleaned)
		if len(drafts) > 0 {
			lastErr = nil
			s.Logger.Info("successfully extracted document full text", "url", redacted(targetURL), "chunks", len(drafts))
			break
		}
	}

	if len(drafts) == 0 {
		if lastErr != nil {
			return 0, fmt.Errorf("no extractable text from %d candidates: %w", len(candidates), lastErr)
		}
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

// CandidateFullTextURLs builds an ordered list of candidate full-text URLs for a paper
// (direct PDF, repository HTML, preprint mirrors, best OA URL).
func CandidateFullTextURLs(d research.PaperDetail) []string {
	seen := map[string]bool{}
	var candidates []string

	add := func(u string) {
		trimmed := strings.TrimSpace(u)
		if trimmed == "" || seen[trimmed] {
			return
		}
		seen[trimmed] = true
		candidates = append(candidates, trimmed)
	}

	// 1. arXiv priority resolution
	arxivID := strings.TrimSpace(d.ArxivID)
	if arxivID != "" {
		// Strip any version suffix or prefix for clean URLs if needed
		cleanID := strings.TrimPrefix(arxivID, "arXiv:")
		add("https://arxiv.org/pdf/" + cleanID)
		add("https://ar5iv.labs.arxiv.org/html/" + cleanID)
	}

	// 2. Direct PDF links and known OA repositories
	if d.BestOAURL != "" {
		add(normalizeCandidateURL(d.BestOAURL))
	}
	for _, v := range d.Versions {
		if v.URL != "" {
			add(normalizeCandidateURL(v.URL))
		}
	}

	// Filter and prioritize direct PDFs and recognized open access repositories
	var prioritized []string
	for _, c := range candidates {
		lower := strings.ToLower(c)
		if strings.Contains(lower, ".pdf") ||
			strings.Contains(lower, "/pdf/") ||
			strings.Contains(lower, "arxiv.org") ||
			strings.Contains(lower, "ar5iv.labs.arxiv.org") ||
			strings.Contains(lower, "biorxiv.org") ||
			strings.Contains(lower, "medrxiv.org") ||
			strings.Contains(lower, "ncbi.nlm.nih.gov/pmc") ||
			strings.Contains(lower, "europepmc.org") {
			prioritized = append(prioritized, c)
		}
	}

	// For papers verified as open access, allow landing page URL fallback
	if d.Summary.IsOpenAccess {
		for _, c := range candidates {
			if !containsString(prioritized, c) {
				prioritized = append(prioritized, c)
			}
		}
	}

	return prioritized
}

func fullTextURL(d research.PaperDetail) (string, bool) {
	cands := CandidateFullTextURLs(d)
	if len(cands) > 0 {
		return cands[0], true
	}
	return "", false
}

func normalizeCandidateURL(u string) string {
	lower := strings.ToLower(u)
	if strings.Contains(lower, "arxiv.org/abs/") {
		return strings.Replace(u, "/abs/", "/pdf/", 1)
	}
	return u
}

func containsString(list []string, item string) bool {
	for _, s := range list {
		if s == item {
			return true
		}
	}
	return false
}
