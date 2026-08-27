// Package ai defines the AI layer's ports and entities: LLM/embedding
// provider abstractions (ADR-0004), explanation levels, cached summaries,
// RAG chunks, and grounded-chat contracts (docs/architecture/ai-rag.md).
package ai

import (
	"context"
	"errors"
	"fmt"
	"io"
	"time"

	"athena/backend/internal/domain/research"
	"github.com/google/uuid"
)

// ExplanationLevel mirrors the wire enum for summary depth.
type ExplanationLevel string

const (
	LevelBeginner     ExplanationLevel = "beginner"
	LevelIntermediate ExplanationLevel = "intermediate"
	LevelAdvanced     ExplanationLevel = "advanced"
	LevelExpert       ExplanationLevel = "expert"
)

var levelSet = map[ExplanationLevel]bool{
	LevelBeginner: true, LevelIntermediate: true,
	LevelAdvanced: true, LevelExpert: true,
}

// ParseExplanationLevel validates a wire value.
func ParseExplanationLevel(s string) (ExplanationLevel, error) {
	l := ExplanationLevel(s)
	if !levelSet[l] {
		return "", fmt.Errorf("%w: unknown explanation_level %q", ErrInvalidQuery, s)
	}
	return l, nil
}

// TokenUsage records per-call usage for the cost dashboard.
type TokenUsage struct {
	PromptTokens     int `json:"prompt_tokens,omitempty"`
	CompletionTokens int `json:"completion_tokens,omitempty"`
	TotalTokens      int `json:"total_tokens"`
}

// GenerateRequest is one completion call. System+Prompt are plain text;
// adapters translate to their wire format.
type GenerateRequest struct {
	System      string
	Prompt      string
	MaxTokens   int
	Temperature float64

	// Stream callback receives incremental text deltas when used via
	// LLMProvider.GenerateStream.
}

// GenerateResponse is one completed completion call.
type GenerateResponse struct {
	Text  string
	Model string
	Usage TokenUsage
}

// StreamReader yields text deltas until EOF.
type StreamReader interface {
	Next(ctx context.Context) (string, error) // io.EOF when done
	Close() error
}

// LLMProvider abstracts chat-completion models (ADR-0004).
type LLMProvider interface {
	Model() string
	Generate(ctx context.Context, req GenerateRequest) (GenerateResponse, error)
	GenerateStream(ctx context.Context, req GenerateRequest) (StreamReader, error)
}

// EmbeddingProvider turns texts into vectors (one output per input).
type EmbeddingProvider interface {
	Embed(ctx context.Context, texts []string) ([][]float32, error)
	Model() string
}

// ---- summaries -------------------------------------------------------------

// SummarySections holds the structured summary payload (ai_summaries.sections).
type SummarySections struct {
	SimpleExplanation   string   `json:"simple_explanation,omitempty"`
	AcademicExplanation string   `json:"academic_explanation,omitempty"`
	KeyFindings         []string `json:"key_findings,omitempty"`
	Methodology         string   `json:"methodology,omitempty"`
	Results             string   `json:"results,omitempty"`
	Limitations         []string `json:"limitations,omitempty"`
	WhyItMatters        string   `json:"why_it_matters,omitempty"`
}

// Grounding reports what the artifact was built from ("abstract+full_text" or
// "abstract") per the honest-degradation contract.
type Grounding struct {
	BasedOn    string `json:"based_on"`
	ChunkCount int    `json:"chunk_count,omitempty"`
}

// Summary is a generated (or cached) paper summary.
type Summary struct {
	PaperID          uuid.UUID
	Level            ExplanationLevel
	ModelID          string
	PromptVersion    string
	InputContentHash string
	TLDR             string
	Sections         SummarySections
	TokenUsage       TokenUsage
	CacheHit         bool // true when served without any model call
	Grounding        Grounding
	GeneratedAt      time.Time
}

// SummarySource supplies the raw material a summary is generated from.
type SummarySource struct {
	Paper    research.PaperDetail
	Chunks   []Chunk // empty ⇒ metadata-only / abstract grounding
	Abstract string
}

// ErrInvalidQuery, ErrNotFound shared with other domains' semantics but namespaced.
var (
	ErrInvalidQuery = errors.New("invalid query")
	ErrNotFound     = errors.New("not found")
	ErrNotGrounded  = errors.New("answer failed citation validation")
	ErrRateLimited  = errors.New("rate limited")
)

// ---- chunks & retrieval ----------------------------------------------------

// Chunk is one RAG unit (paper_chunks row).
type Chunk struct {
	ID          uuid.UUID
	PaperID     uuid.UUID
	Seq         int
	SectionPath string
	Heading     string
	Content     string
	TokenCount  int
	ContentHash string
}

// RetrievedChunk pairs a chunk with its fused retrieval score.
type RetrievedChunk struct {
	Chunk
	Score float64
}

// ChunkQuery retrieves top-k chunks for one paper (chat scope) or globally
// (future semantic search).
type ChunkQuery struct {
	PaperID  uuid.UUID
	Question string
	TopK     int
}

// ChunkRetriever is the retrieval port implemented over embeddings+FTS.
type ChunkRetriever interface {
	Retrieve(ctx context.Context, q ChunkQuery) ([]RetrievedChunk, error)
}

// TextExtractor pulls plain text out of a document stream (PDF today; other
// formats behind the same port later). Implementations must tolerate
// partially-garbage documents by returning an error, never panicking.
type TextExtractor interface {
	Extract(ctx context.Context, r io.Reader) (string, error)
}

// ---- chat ------------------------------------------------------------------

// Role enumerates chat message authors.
type Role string

const (
	RoleUser      Role = "user"
	RoleAssistant Role = "assistant"
	RoleSystem    Role = "system"
)

// Citation links an assistant claim to its supporting chunk.
type Citation struct {
	ChunkID     uuid.UUID `json:"chunk_id"`
	SectionPath string    `json:"section_path,omitempty"`
	Quote       string    `json:"quote"`
}

// Session is a single-paper chat container.
type Session struct {
	ID            uuid.UUID
	PaperID       uuid.UUID
	UserID        *uuid.UUID
	Title         string
	MessageCount  int
	LastMessageAt *time.Time
	CreatedAt     time.Time
}

// Message is one stored chat turn.
type Message struct {
	ID         uuid.UUID
	SessionID  uuid.UUID
	Role       Role
	Content    string
	Citations  []Citation
	ModelID    string
	TokenUsage TokenUsage
	CreatedAt  time.Time
}

// NewSessionInput gates session creation.
type NewSessionInput struct {
	PaperID uuid.UUID
	UserID  *uuid.UUID
	Title   string
}

// HistoryTurn is prior conversation context fed back to the model.
type HistoryTurn struct {
	Role    Role
	Content string
}
