package v1

import (
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"time"

	"github.com/google/uuid"

	appai "athena/backend/internal/application/ai"
	appchat "athena/backend/internal/application/chat"
	domainai "athena/backend/internal/domain/ai"
)

// AIHandlers serve the Phase 4 endpoints: paper summaries and grounded chat
// (api-specification.md §2, docs/architecture/ai-rag.md).
type AIHandlers struct {
	Summary    *appai.SummaryService
	Chat       *appchat.Service
	Comparison *appai.ComparisonService
	Logger     *slog.Logger
}

func NewAIHandlers(summary *appai.SummaryService, chat *appchat.Service, log *slog.Logger) *AIHandlers {
	return &AIHandlers{Summary: summary, Chat: chat, Logger: log}
}

// ---- DTOs -------------------------------------------------------------------

type summaryRequestDTO struct {
	Level string `json:"level"`
}

type citationDTO struct {
	ChunkID     uuid.UUID `json:"chunk_id"`
	SectionPath string    `json:"section_path,omitempty"`
	Quote       string    `json:"quote"`
}

type messageDTO struct {
	ID         uuid.UUID     `json:"id"`
	SessionID  uuid.UUID     `json:"session_id"`
	Role       string        `json:"role"`
	Content    string        `json:"content"`
	Citations  []citationDTO `json:"citations"`
	ModelID    string        `json:"model_id,omitempty"`
	TokenUsage struct {
		PromptTokens     int `json:"prompt_tokens,omitempty"`
		CompletionTokens int `json:"completion_tokens,omitempty"`
		TotalTokens      int `json:"total_tokens"`
	} `json:"token_usage"`
	CreatedAt time.Time `json:"created_at"`
}

func newMessageDTO(m domainai.Message) messageDTO {
	out := messageDTO{
		ID: m.ID, SessionID: m.SessionID, Role: string(m.Role),
		Content: m.Content, ModelID: m.ModelID, CreatedAt: m.CreatedAt,
	}
	out.TokenUsage.PromptTokens = m.TokenUsage.PromptTokens
	out.TokenUsage.CompletionTokens = m.TokenUsage.CompletionTokens
	out.TokenUsage.TotalTokens = m.TokenUsage.TotalTokens
	out.Citations = make([]citationDTO, 0, len(m.Citations))
	for _, c := range m.Citations {
		out.Citations = append(out.Citations, citationDTO{
			ChunkID: c.ChunkID, SectionPath: c.SectionPath, Quote: c.Quote,
		})
	}
	return out
}

type sessionDTO struct {
	ID            uuid.UUID  `json:"id"`
	PaperID       uuid.UUID  `json:"paper_id"`
	Title         string     `json:"title,omitempty"`
	MessageCount  int        `json:"message_count"`
	LastMessageAt *time.Time `json:"last_message_at,omitempty"`
	CreatedAt     time.Time  `json:"created_at"`
}

func newSessionDTO(s domainai.Session) sessionDTO {
	return sessionDTO{
		ID: s.ID, PaperID: s.PaperID, Title: s.Title,
		MessageCount: s.MessageCount, LastMessageAt: s.LastMessageAt,
		CreatedAt: s.CreatedAt,
	}
}

// ---- POST /api/v1/research/papers/{id}/summary ------------------------------

func (h *AIHandlers) SummaryPost(w http.ResponseWriter, r *http.Request) {
	if h.Summary == nil {
		WriteError(w, r, http.StatusNotImplemented, CodeNotImplemented,
			"AI layer is not enabled on this deployment")
		return
	}
	paperID, err := uuid.Parse(r.PathValue("id"))
	if err != nil {
		WriteError(w, r, http.StatusBadRequest, CodeInvalidRequest, "invalid paper id")
		return
	}

	var req summaryRequestDTO
	if r.Body != nil {
		// An absent body defaults to intermediate level.
		if err := json.NewDecoder(io.LimitReader(r.Body, 1<<16)).Decode(&req); err != nil && !errors.Is(err, io.EOF) {
			WriteErrorWithDetails(w, r, http.StatusBadRequest, CodeInvalidRequest,
				"body must be JSON", []errorDetail{{Field: "body", Issue: "must be JSON"}})
			return
		}
	}
	level := domainai.LevelIntermediate
	if req.Level != "" {
		level, err = domainai.ParseExplanationLevel(req.Level)
		if err != nil {
			WriteErrorWithDetails(w, r, http.StatusBadRequest, CodeInvalidRequest,
				"unknown explanation_level",
				[]errorDetail{{Field: "level", Issue: "must be beginner|intermediate|advanced|expert"}})
			return
		}
	}

	sum, err := h.Summary.Summarize(r.Context(), paperID, level)
	if err != nil {
		h.fail(w, r, err)
		return
	}

	type summaryResponseDTO struct {
		PaperID     uuid.UUID                `json:"paper_id"`
		Level       string                   `json:"level"`
		TLDR        string                   `json:"tldr"`
		Sections    domainai.SummarySections `json:"sections"`
		BasedOn     string                   `json:"based_on"`
		ChunkCount  int                      `json:"chunk_count,omitempty"`
		CacheHit    bool                     `json:"cache_hit"`
		ModelID     string                   `json:"model_id"`
		TokenUsage  domainai.TokenUsage      `json:"token_usage"`
		GeneratedAt time.Time                `json:"generated_at"`
	}
	WriteJSON(w, http.StatusOK, summaryResponseDTO{
		PaperID: sum.PaperID, Level: string(sum.Level), TLDR: sum.TLDR,
		Sections: sum.Sections, BasedOn: sum.Grounding.BasedOn,
		ChunkCount: sum.Grounding.ChunkCount, CacheHit: sum.CacheHit,
		ModelID: sum.ModelID, TokenUsage: sum.TokenUsage, GeneratedAt: sum.GeneratedAt,
	})
}

// ---- GET /api/v1/research/papers/{id}/reader --------------------------------

type readerSectionDTO struct {
	Seq         int    `json:"seq"`
	SectionPath string `json:"section_path,omitempty"`
	Heading     string `json:"heading,omitempty"`
	Content     string `json:"content"`
	TokenCount  int    `json:"token_count"`
}

type paperReaderResponseDTO struct {
	PaperID     uuid.UUID          `json:"paper_id"`
	Title       string             `json:"title"`
	Abstract    string             `json:"abstract,omitempty"`
	SourceURL   string             `json:"source_url,omitempty"`
	Format      string             `json:"format"`
	Sections    []readerSectionDTO `json:"sections"`
	TotalChunks int                `json:"total_chunks"`
}

func (h *AIHandlers) ReaderGet(w http.ResponseWriter, r *http.Request) {
	if h.Summary == nil {
		WriteError(w, r, http.StatusNotImplemented, CodeNotImplemented,
			"AI layer is not enabled on this deployment")
		return
	}
	paperID, err := uuid.Parse(r.PathValue("id"))
	if err != nil {
		WriteError(w, r, http.StatusBadRequest, CodeInvalidRequest, "invalid paper id")
		return
	}

	content, err := h.Summary.GetArticleContent(r.Context(), paperID)
	if err != nil {
		h.fail(w, r, err)
		return
	}

	sections := make([]readerSectionDTO, 0, len(content.Chunks))
	for _, c := range content.Chunks {
		sections = append(sections, readerSectionDTO{
			Seq:         c.Seq,
			SectionPath: c.SectionPath,
			Heading:     c.Heading,
			Content:     c.Content,
			TokenCount:  c.TokenCount,
		})
	}

	WriteJSON(w, http.StatusOK, paperReaderResponseDTO{
		PaperID:     content.PaperID,
		Title:       content.Title,
		Abstract:    content.Abstract,
		SourceURL:   content.SourceURL,
		Format:      content.Format,
		Sections:    sections,
		TotalChunks: len(sections),
	})
}

// ---- POST /api/v1/chat/sessions ---------------------------------------------

type createSessionRequestDTO struct {
	PaperID uuid.UUID `json:"paper_id"`
	Title   string    `json:"title"`
}

func (h *AIHandlers) CreateSession(w http.ResponseWriter, r *http.Request) {
	if h.Chat == nil {
		WriteError(w, r, http.StatusNotImplemented, CodeNotImplemented,
			"AI layer is not enabled on this deployment")
		return
	}
	var req createSessionRequestDTO
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.PaperID == uuid.Nil {
		WriteErrorWithDetails(w, r, http.StatusBadRequest, CodeInvalidRequest,
			"paper_id is required", []errorDetail{{Field: "paper_id", Issue: "is required"}})
		return
	}
	sess, err := h.Chat.CreateSession(r.Context(), domainai.NewSessionInput{
		PaperID: req.PaperID, Title: req.Title,
	})
	if err != nil {
		h.fail(w, r, err)
		return
	}
	WriteJSON(w, http.StatusCreated, newSessionDTO(sess))
}

// ---- GET /api/v1/chat/sessions/{id}/messages --------------------------------

func (h *AIHandlers) ListMessages(w http.ResponseWriter, r *http.Request) {
	if h.Chat == nil {
		WriteError(w, r, http.StatusNotImplemented, CodeNotImplemented,
			"AI layer is not enabled on this deployment")
		return
	}
	sessionID, err := uuid.Parse(r.PathValue("id"))
	if err != nil {
		WriteError(w, r, http.StatusBadRequest, CodeInvalidRequest, "invalid session id")
		return
	}
	msgs, err := h.Chat.Messages(r.Context(), sessionID)
	if err != nil {
		h.fail(w, r, err)
		return
	}
	out := make([]messageDTO, 0, len(msgs))
	for _, m := range msgs {
		out = append(out, newMessageDTO(m))
	}
	WriteJSON(w, http.StatusOK, out)
}

// ---- POST /api/v1/chat/sessions/{id}/messages (SSE) -------------------------

type askRequestDTO struct {
	Content string `json:"content"`
}

func (h *AIHandlers) Ask(w http.ResponseWriter, r *http.Request) {
	if h.Chat == nil {
		WriteError(w, r, http.StatusNotImplemented, CodeNotImplemented,
			"AI layer is not enabled on this deployment")
		return
	}
	sessionID, err := uuid.Parse(r.PathValue("id"))
	if err != nil {
		WriteError(w, r, http.StatusBadRequest, CodeInvalidRequest, "invalid session id")
		return
	}
	var req askRequestDTO
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.Content == "" {
		WriteErrorWithDetails(w, r, http.StatusBadRequest, CodeInvalidRequest,
			"content is required", []errorDetail{{Field: "content", Issue: "is required"}})
		return
	}

	flusher, ok := w.(http.Flusher)
	if !ok {
		WriteError(w, r, http.StatusInternalServerError, CodeInternal, "streaming unsupported")
		return
	}

	w.Header().Set("Content-Type", "text/event-stream")
	w.Header().Set("Cache-Control", "no-cache")
	w.Header().Set("Connection", "keep-alive")
	w.Header().Set("X-Accel-Buffering", "no")

	writeEvent := func(payload any) bool {
		b, err := json.Marshal(payload)
		if err != nil {
			return false
		}
		if _, werr := fmt.Fprintf(w, "data: %s\n\n", b); werr != nil {
			return false
		}
		flusher.Flush()
		return true
	}

	msg, err := h.Chat.Ask(r.Context(), sessionID, req.Content, func(delta string) {
		writeEvent(map[string]any{"type": "delta", "text": delta})
	})
	if err != nil {
		// Headers are already sent; report the failure as a terminal event.
		_ = writeEvent(map[string]any{"type": "error", "message": sseErrMessage(err)})
		return
	}
	_ = writeEvent(map[string]any{"type": "done", "message": newMessageDTO(msg)})
}

func sseErrMessage(err error) string {
	switch {
	case errors.Is(err, domainai.ErrNotFound):
		return "session not found"
	case errors.Is(err, domainai.ErrInvalidQuery):
		return "invalid question"
	case errors.Is(err, domainai.ErrRateLimited):
		return "AI is rate limited. Please wait a moment and try again."
	default:
		return "generation failed"
	}
}

func (h *AIHandlers) fail(w http.ResponseWriter, r *http.Request, err error) {
	status, code, msg := http.StatusInternalServerError, CodeInternal, "internal error"
	switch {
	case errors.Is(err, domainai.ErrNotFound):
		status, code, msg = http.StatusNotFound, CodeNotFound, "not found"
	case errors.Is(err, domainai.ErrInvalidQuery):
		status, code, msg = http.StatusBadRequest, CodeInvalidRequest, "invalid request"
	case errors.Is(err, domainai.ErrRateLimited):
		status, code, msg = http.StatusTooManyRequests, CodeInternal,
			"AI is rate limited. Please wait a moment and try again."
	case errors.Is(err, appai.ErrNoPermittedFullText), errors.Is(err, domainai.ErrNotGrounded):
		status, code, msg = http.StatusUnprocessableEntity, CodeInvalidRequest,
			"no text-mining-permitted full text available for this paper"
	}
	if status == http.StatusInternalServerError {
		h.Logger.Error("ai request failed", "error", err, "request_id", RequestIDFrom(r.Context()))
	}
	WriteError(w, r, status, code, msg)
}

type compareRequestDTO struct {
	PaperIDs []string `json:"paper_ids"`
	Facets   []string `json:"facets,omitempty"`
}

// Compare: POST /api/v1/research/compare
func (h *AIHandlers) Compare(w http.ResponseWriter, r *http.Request) {
	if h.Comparison == nil {
		WriteError(w, r, http.StatusServiceUnavailable, CodeInternal, "comparison service unavailable")
		return
	}
	var req compareRequestDTO
	if err := decodeJSON(r, &req); err != nil {
		WriteError(w, r, http.StatusBadRequest, CodeInvalidRequest, "invalid JSON body")
		return
	}
	if len(req.PaperIDs) < 2 {
		WriteError(w, r, http.StatusBadRequest, CodeInvalidRequest, "at least 2 paper_ids are required")
		return
	}
	if len(req.PaperIDs) > 5 {
		WriteError(w, r, http.StatusBadRequest, CodeInvalidRequest, "maximum 5 paper_ids can be compared")
		return
	}
	paperUUIDs := make([]uuid.UUID, 0, len(req.PaperIDs))
	for _, idStr := range req.PaperIDs {
		id, err := uuid.Parse(idStr)
		if err != nil {
			WriteError(w, r, http.StatusBadRequest, CodeInvalidRequest, "all paper_ids must be valid UUIDs")
			return
		}
		paperUUIDs = append(paperUUIDs, id)
	}

	report, err := h.Comparison.Compare(r.Context(), paperUUIDs, nil)
	if err != nil {
		h.Logger.Error("paper comparison failed", "error", err, "request_id", RequestIDFrom(r.Context()))
		WriteError(w, r, http.StatusInternalServerError, CodeInternal, "failed to generate comparison")
		return
	}
	WriteJSON(w, http.StatusOK, report)
}
