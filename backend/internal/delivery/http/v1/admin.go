package v1

import (
	"context"
	"crypto/subtle"
	"encoding/json"
	"errors"
	"log/slog"
	"net/http"
	"strconv"
	"time"

	"athena/backend/internal/application/ingestion"
)

// AdminHandlers expose ingestion operations guarded by the admin token
// (ingestion-pipeline.md §5). The token comes from ATHENA_ADMIN_TOKEN.
type AdminHandlers struct {
	Queue      ingestion.JobQueue
	Logger     *slog.Logger
	AdminToken string

	// RagQueue optionally enables POST /admin/rag/index (nil when AI off).
	RagQueue RagIndexQueue
}

// RagIndexQueue enqueues bulk full-text RAG indexing jobs.
type RagIndexQueue interface {
	EnqueueRagIndex(ctx context.Context, paperIDs []string) ([]string, error)
}

func NewAdminHandlers(adminToken string, log *slog.Logger) *AdminHandlers {
	return &AdminHandlers{AdminToken: adminToken, Logger: log}
}

// parseRFC3339 parses a required timestamp; empty input returns the zero time.
func parseRFC3339(field, raw string) (time.Time, error) {
	if raw == "" {
		return time.Time{}, errors.New(field + " is required")
	}
	return time.Parse(time.RFC3339, raw)
}

type createJobRequest struct {
	Provider string `json:"provider"`
	From     string `json:"from"`
	To       string `json:"to"`
	Query    string `json:"query,omitempty"`
	MaxPages int    `json:"max_pages,omitempty"`
}

// requireAdmin enforces bearer-token auth; returns false when denied.
func (h *AdminHandlers) requireAdmin(w http.ResponseWriter, r *http.Request) bool {
	if h.AdminToken == "" {
		WriteError(w, r, http.StatusServiceUnavailable, CodeInternal,
			"admin API disabled: no ATHENA_ADMIN_TOKEN configured")
		return false
	}
	const prefix = "Bearer "
	raw := r.Header.Get("Authorization")
	if len(raw) <= len(prefix) || subtle.ConstantTimeCompare(
		[]byte(raw[:len(prefix)]), []byte(prefix)) != 1 {
		WriteError(w, r, http.StatusUnauthorized, CodeUnauthorized, "missing bearer token")
		return false
	}
	if subtle.ConstantTimeCompare([]byte(raw[len(prefix):]), []byte(h.AdminToken)) != 1 {
		WriteError(w, r, http.StatusForbidden, CodeForbidden, "invalid admin token")
		return false
	}
	return true
}

// CreateIngestionJob handles POST /api/v1/admin/ingestion/jobs.
func (h *AdminHandlers) CreateIngestionJob(w http.ResponseWriter, r *http.Request) {
	if !h.requireAdmin(w, r) {
		return
	}
	if h.Queue == nil {
		WriteError(w, r, http.StatusServiceUnavailable, CodeInternal, "job queue unavailable")
		return
	}

	var req createJobRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		WriteError(w, r, http.StatusBadRequest, CodeInvalidRequest, "malformed JSON body")
		return
	}
	from, fromErr := parseRFC3339("from", req.From)
	to, toErr := parseRFC3339("to", req.To)
	var details []errorDetail
	if req.Provider == "" {
		details = append(details, errorDetail{Field: "provider", Issue: "required"})
	}
	if fromErr != nil || toErr != nil || from.IsZero() || to.IsZero() || to.Before(from) {
		details = append(details, errorDetail{Field: "from/to", Issue: "must be RFC3339 with from <= to"})
	}
	if len(details) > 0 {
		WriteErrorWithDetails(w, r, http.StatusBadRequest, CodeInvalidRequest, "invalid request", details)
		return
	}

	job, err := h.Queue.EnqueueWindowSync(r.Context(), ingestion.EnqueueRequest{
		Provider: req.Provider,
		From:     from,
		To:       to,
		Query:    req.Query,
		MaxPages: req.MaxPages,
	})
	if err != nil {
		h.Logger.Error("admin job insert failed", "error", err)
		if errors.Is(err, ingestion.ErrUnknownProviderSlug) {
			WriteErrorWithDetails(w, r, http.StatusBadRequest, CodeInvalidRequest,
				err.Error(), []errorDetail{{Field: "provider", Issue: "not configured"}})
			return
		}
		WriteError(w, r, http.StatusInternalServerError, CodeInternal, "could not enqueue job")
		return
	}
	WriteJSON(w, http.StatusAccepted, map[string]any{
		"job_id":   job.ID,
		"state":    job.State,
		"provider": req.Provider,
	})
}

// CreateRagIndexJobs handles POST /api/v1/admin/rag/index {paper_ids:[...]}.
func (h *AdminHandlers) CreateRagIndexJobs(w http.ResponseWriter, r *http.Request) {
	if !h.requireAdmin(w, r) {
		return
	}
	if h.RagQueue == nil {
		WriteError(w, r, http.StatusServiceUnavailable, CodeInternal,
			"AI layer disabled: no RAG queue configured")
		return
	}
	var req struct {
		PaperIDs []string `json:"paper_ids"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || len(req.PaperIDs) == 0 {
		WriteErrorWithDetails(w, r, http.StatusBadRequest, CodeInvalidRequest,
			"paper_ids is required (1..100 ids)",
			[]errorDetail{{Field: "paper_ids", Issue: "is required"}})
		return
	}
	jobIDs, err := h.RagQueue.EnqueueRagIndex(r.Context(), req.PaperIDs)
	if err != nil && len(jobIDs) == 0 {
		h.Logger.Error("rag index enqueue failed", "error", err)
		WriteErrorWithDetails(w, r, http.StatusBadRequest, CodeInvalidRequest,
			err.Error(), []errorDetail{{Field: "paper_ids", Issue: err.Error()}})
		return
	}
	WriteJSON(w, http.StatusAccepted, map[string]any{
		"job_ids":     jobIDs,
		"enqueued":    len(jobIDs),
		"partial_err": errString(err),
	})
}

func errString(err error) string {
	if err != nil {
		return err.Error()
	}
	return ""
}

// ListIngestionJobs handles GET /api/v1/admin/ingestion/jobs?state=&limit=.
func (h *AdminHandlers) ListIngestionJobs(w http.ResponseWriter, r *http.Request) {
	if !h.requireAdmin(w, r) {
		return
	}
	if h.Queue == nil {
		WriteError(w, r, http.StatusServiceUnavailable, CodeInternal, "job queue unavailable")
		return
	}

	state := r.URL.Query().Get("state")
	limit := 50
	if raw := r.URL.Query().Get("limit"); raw != "" {
		n, err := strconv.Atoi(raw)
		if err != nil || n < 1 || n > 200 {
			WriteErrorWithDetails(w, r, http.StatusBadRequest, CodeInvalidRequest,
				"limit must be between 1 and 200",
				[]errorDetail{{Field: "limit", Issue: "must be between 1 and 200"}})
			return
		}
		limit = n
	}

	jobs, err := h.Queue.ListJobs(r.Context(), state, limit)
	if err != nil {
		h.Logger.Error("job listing failed", "error", err)
		WriteError(w, r, http.StatusInternalServerError, CodeInternal, "could not list jobs")
		return
	}
	if jobs == nil {
		jobs = []ingestion.JobInfo{}
	}
	WriteJSON(w, http.StatusOK, map[string]any{"items": jobs, "meta": map[string]int{"limit": limit}})
}
