// Package ai implements the Phase 4 AI features: cached structured
// summaries, RAG ingestion (extract → chunk → embed), hybrid retrieval, and
// the shared grounding prompt contract (docs/architecture/ai-rag.md,
// ADR-0004).
package ai

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"regexp"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/prometheus/client_golang/prometheus"

	domainai "athena/backend/internal/domain/ai"
	"athena/backend/internal/domain/research"
)

// PromptVersion is bumped whenever the summary/chat prompt contract changes;
// stored on every artifact for reproducibility.
const PromptVersion = "2026-08-25.1"

// ---- ports ------------------------------------------------------------------

// SummaryStore persists cached summaries.
type SummaryStore interface {
	GetSummary(ctx context.Context, paperID uuid.UUID, level domainai.ExplanationLevel) (domainai.Summary, error)
	SaveSummary(ctx context.Context, sum domainai.Summary) error
}

// ChunkSource supplies a paper's RAG chunks.
type ChunkSource interface {
	ListChunks(ctx context.Context, paperID uuid.UUID) ([]domainai.Chunk, error)
}

// PaperSource loads paper detail (title/abstract/versions/OA).
type PaperSource interface {
	GetDetailByID(ctx context.Context, id uuid.UUID) (research.PaperDetail, error)
}

// Indexer lazily builds RAG chunks for a paper (implemented by RAGService).
type Indexer interface {
	IngestPaper(ctx context.Context, paperID uuid.UUID) (int, error)
}

// ---- metrics ----------------------------------------------------------------

var (
	tokensTotal = prometheus.NewCounterVec(prometheus.CounterOpts{
		Name: "athena_ai_tokens_total",
		Help: "LLM token usage per feature and kind (prompt|completion).",
	}, []string{"feature", "model", "kind"})

	requestsTotal = prometheus.NewCounterVec(prometheus.CounterOpts{
		Name: "athena_ai_requests_total",
		Help: "AI requests per feature, model and status (ok|error|refused|cache_hit).",
	}, []string{"feature", "model", "status"})
)

func init() {
	prometheus.MustRegister(tokensTotal, requestsTotal)
}

func recordUsage(feature, model string, u domainai.TokenUsage) {
	if u.PromptTokens > 0 {
		tokensTotal.WithLabelValues(feature, model, "prompt").Add(float64(u.PromptTokens))
	}
	if u.CompletionTokens > 0 {
		tokensTotal.WithLabelValues(feature, model, "completion").Add(float64(u.CompletionTokens))
	}
}

func recordStatus(feature, model, status string) {
	requestsTotal.WithLabelValues(feature, model, status).Inc()
}

// RecordUsage exports token accounting for sibling AI features (chat).
func RecordUsage(feature, model string, u domainai.TokenUsage) { recordUsage(feature, model, u) }

// RecordChatStatus counts one chat outcome (ok|refused|uncited|error).
func RecordChatStatus(status string) {
	recordStatus("chat", "any", status)
}

// EstimateUsage approximates token counts when the upstream stream does not
// report usage (~4 chars/token; documented in ai-rag.md §8).
func EstimateUsage(prompt, completion string) domainai.TokenUsage {
	p, c := approxTokens(prompt), approxTokens(completion)
	return domainai.TokenUsage{PromptTokens: p, CompletionTokens: c, TotalTokens: p + c}
}

// GroundingSystem returns the system prompt carrying the grounding contract.
func GroundingSystem() string { return groundingSystem }

// ---- grounding prompt -------------------------------------------------------

const groundingSystem = `You are Athena, a careful research assistant.

Rules you must never break:
1. Answer ONLY from the provided context. Cite sources as [chunk N] where N is the chunk number.
2. Distinguish findings from interpretation from speculation; keep stated limitations.
3. If the context is insufficient to answer, reply exactly: "The provided material does not contain enough evidence to answer this."
4. Numbers and statistics must appear verbatim in the context or be omitted.
5. Never invent citations, authors, papers, or figures.`

// ---- summary service --------------------------------------------------------

// SummaryService produces levelled paper summaries with a content-hash keyed
// cache: hits cost zero tokens.
type SummaryService struct {
	LLM    domainai.LLMProvider // nil ⇒ AI disabled upstream
	Store  SummaryStore
	Papers PaperSource
	Chunks ChunkSource
	Logger *slog.Logger

	// Indexer optionally builds full-text chunks on first use; nil keeps the
	// service strictly abstract-grounded.
	Indexer Indexer

	// MaxContextChars bounds how much full text is fed to the model.
	MaxContextChars int

	indexTimeout time.Duration
}

func NewSummaryService(llm domainai.LLMProvider, store SummaryStore,
	papers PaperSource, chunks ChunkSource, log *slog.Logger) *SummaryService {
	return &SummaryService{LLM: llm, Store: store, Papers: papers,
		Chunks: chunks, Logger: log, MaxContextChars: 24000,
		indexTimeout: 30 * time.Second}
}

// Summarize returns the cached summary when the source content is unchanged,
// otherwise generates and caches one. Grounding degrades honestly:
// based_on = "abstract+full_text" with chunks, "abstract" without.
func (s *SummaryService) Summarize(ctx context.Context, paperID uuid.UUID,
	level domainai.ExplanationLevel) (domainai.Summary, error) {

	detail, err := s.Papers.GetDetailByID(ctx, paperID)
	if err != nil {
		return domainai.Summary{}, mapReadErr(err)
	}
	chunks, err := s.Chunks.ListChunks(ctx, paperID)
	if err != nil {
		return domainai.Summary{}, fmt.Errorf("load chunks: %w", err)
	}
	if len(chunks) == 0 && s.Indexer != nil {
		// First touch: try to index the full text inline so summaries ground
		// on more than the abstract. Failure degrades honestly below.
		ictx, cancel := context.WithTimeout(ctx, s.indexTimeout)
		if _, ierr := s.Indexer.IngestPaper(ictx, paperID); ierr != nil {
			s.Logger.Info("lazy rag indexing unavailable; abstract grounding",
				"paper_id", paperID, "error", ierr)
			cancel()
		} else {
			chunks, err = s.Chunks.ListChunks(ctx, paperID)
			cancel()
			if err != nil {
				return domainai.Summary{}, fmt.Errorf("reload chunks: %w", err)
			}
		}
	}
	contentHash := ContentHash(detail.Summary.Title, abstractOf(detail), chunks)

	// Cache path — zero tokens by construction.
	if cached, err := s.Store.GetSummary(ctx, paperID, level); err == nil {
		if cached.InputContentHash == contentHash {
			cached.CacheHit = true
			cached.TokenUsage = domainai.TokenUsage{} // served free of charge
			cached.Grounding = groundingFor(chunks)
			recordStatus("summary", cached.ModelID, "cache_hit")
			return cached, nil
		}
		// Stale content falls through to regeneration.
	} else if !errors.Is(err, domainai.ErrNotFound) {
		return domainai.Summary{}, fmt.Errorf("summary cache lookup: %w", err)
	}

	if s.LLM == nil {
		return domainai.Summary{}, domainai.ErrNotGrounded // AI disabled
	}

	prompt := buildSummaryPrompt(detail, abstractOf(detail), chunks, level, s.MaxContextChars)
	resp, err := s.LLM.Generate(ctx, domainai.GenerateRequest{
		System:      groundingSystem,
		Prompt:      prompt,
		Temperature: 0.2,
		MaxTokens:   8192,
	})
	if err != nil {
		recordStatus("summary", s.LLM.Model(), "error")
		return domainai.Summary{}, fmt.Errorf("generate summary: %w", err)
	}
	recordUsage("summary", resp.Model, resp.Usage)

	sections, tldr, err := parseSummaryJSON(resp.Text)
	if err != nil {
		recordStatus("summary", resp.Model, "error")
		return domainai.Summary{}, fmt.Errorf("parse summary output (%q): %w", resp.Text, err)
	}

	sum := domainai.Summary{
		PaperID:          paperID,
		Level:            level,
		ModelID:          resp.Model,
		PromptVersion:    PromptVersion,
		InputContentHash: contentHash,
		TLDR:             tldr,
		Sections:         sections,
		TokenUsage:       resp.Usage,
		Grounding:        groundingFor(chunks),
		GeneratedAt:      time.Now().UTC(),
	}
	if err := s.Store.SaveSummary(ctx, sum); err != nil {
		s.Logger.Warn("summary cache write failed", "error", err)
	}
	recordStatus("summary", resp.Model, "ok")
	return sum, nil
}

func groundingFor(chunks []domainai.Chunk) domainai.Grounding {
	if len(chunks) > 0 {
		return domainai.Grounding{BasedOn: "abstract+full_text", ChunkCount: len(chunks)}
	}
	return domainai.Grounding{BasedOn: "abstract"}
}

// ContentHash is the invalidation key: any change to title, abstract or the
// underlying chunk set forces re-summarization.
func ContentHash(title, abstract string, chunks []domainai.Chunk) string {
	h := sha256.New()
	h.Write([]byte(title))
	h.Write([]byte{0})
	h.Write([]byte(abstract))
	for _, c := range chunks {
		h.Write([]byte{0})
		h.Write([]byte(c.ContentHash))
	}
	return hex.EncodeToString(h.Sum(nil))
}

func buildSummaryPrompt(detail research.PaperDetail, abstract string,
	chunks []domainai.Chunk, level domainai.ExplanationLevel, maxChars int) string {
	var b strings.Builder
	b.WriteString("Summarize the following academic paper for a ")
	b.WriteString(string(level))
	b.WriteString(`-level reader.

Respond with ONLY a COMPLETE JSON object with exactly these keys. Do not use markdown code fences around the JSON:
{"tldr": string, "simple_explanation": string, "academic_explanation": string,
 "key_findings": [string], "methodology": string, "results": string,
 "limitations": [string], "why_it_matters": string}

TITLE: `)
	b.WriteString(detail.Summary.Title)
	b.WriteString("\nABSTRACT: ")
	b.WriteString(firstNonEmpty(abstract, "(none available)"))

	if len(chunks) > 0 {
		b.WriteString("\n\n### CONTEXT\nFull-text excerpts; cite as [chunk N] inside your explanations.\n")
		budget := maxChars
		for _, c := range chunks {
			if budget <= 0 {
				break
			}
			content := c.Content
			if len(content) > budget {
				content = content[:budget]
			}
			budget -= len(content)
			fmt.Fprintf(&b, "\n[chunk %d] (%s)\n%s\n", c.Seq+1, sectionLabel(c), content)
		}
	} else if abstract == "" {
		b.WriteString("\n\n### CONTEXT\nNo abstract available. If you cannot produce a faithful summary, say so explicitly.")
	} else {
		b.WriteString("\n\nNOTE: Only metadata (title/abstract) is available for this paper. Keep every claim grounded in it.")
	}
	return b.String()
}

func sectionLabel(c domainai.Chunk) string {
	if c.SectionPath != "" {
		return c.SectionPath
	}
	if c.Heading != "" {
		return c.Heading
	}
	return "body"
}

// parseSummaryJSON tolerates markdown fences around the JSON object.
func parseSummaryJSON(text string) (domainai.SummarySections, string, error) {
	trimmed := strings.TrimSpace(text)
	trimmed = strings.TrimPrefix(trimmed, "```json")
	trimmed = strings.TrimPrefix(trimmed, "```")
	trimmed = strings.TrimSuffix(trimmed, "```")
	start := strings.IndexByte(trimmed, '{')
	end := strings.LastIndexByte(trimmed, '}')
	
	var raw struct {
		TLDR                string   `json:"tldr"`
		SimpleExplanation   string   `json:"simple_explanation"`
		AcademicExplanation string   `json:"academic_explanation"`
		KeyFindings         []string `json:"key_findings"`
		Methodology         string   `json:"methodology"`
		Results             string   `json:"results"`
		Limitations         []string `json:"limitations"`
		WhyItMatters        string   `json:"why_it_matters"`
	}

	if start >= 0 {
		if end > start {
			if err := json.Unmarshal([]byte(trimmed[start:end+1]), &raw); err == nil {
				return domainai.SummarySections{
					SimpleExplanation:   raw.SimpleExplanation,
					AcademicExplanation: raw.AcademicExplanation,
					KeyFindings:         raw.KeyFindings,
					Methodology:         raw.Methodology,
					Results:             raw.Results,
					Limitations:         raw.Limitations,
					WhyItMatters:        raw.WhyItMatters,
				}, strings.TrimSpace(raw.TLDR), nil
			}
		}
		
		repairIdx := strings.LastIndex(trimmed, `",`)
		if repairIdx2 := strings.LastIndex(trimmed, `],`); repairIdx2 > repairIdx {
			repairIdx = repairIdx2
		}
		if repairIdx > start {
			repaired := trimmed[start:repairIdx+1] + `}`
			if err := json.Unmarshal([]byte(repaired), &raw); err == nil {
				return domainai.SummarySections{
					SimpleExplanation:   raw.SimpleExplanation,
					AcademicExplanation: raw.AcademicExplanation,
					KeyFindings:         raw.KeyFindings,
					Methodology:         raw.Methodology,
					Results:             raw.Results,
					Limitations:         raw.Limitations,
					WhyItMatters:        raw.WhyItMatters,
				}, strings.TrimSpace(raw.TLDR), nil
			}
		}
	}

	re := regexp.MustCompile(`(?is)"tldr"\s*:\s*"([^"\\]*(?:\\.[^"\\]*)*)"`)
	if matches := re.FindStringSubmatch(trimmed); len(matches) > 1 {
		tldr := strings.ReplaceAll(matches[1], `\"`, `"`)
		tldr = strings.ReplaceAll(tldr, `\n`, "\n")
		return domainai.SummarySections{}, strings.TrimSpace(tldr), nil
	}

	return domainai.SummarySections{}, "", errors.New("no JSON object in model output")
}

func abstractOf(d research.PaperDetail) string {
	if d.Summary.Abstract != nil {
		return *d.Summary.Abstract
	}
	return ""
}

func firstNonEmpty(vals ...string) string {
	for _, v := range vals {
		if v != "" {
			return v
		}
	}
	return ""
}

func mapReadErr(err error) error {
	if errors.Is(err, research.ErrNotFound) {
		return domainai.ErrNotFound
	}
	return err
}
