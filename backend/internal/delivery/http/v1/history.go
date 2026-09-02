package v1

import (
	"errors"
	"log/slog"
	"net/http"
	"strconv"

	"github.com/google/uuid"

	apphistory "athena/backend/internal/application/history"
	domainhistory "athena/backend/internal/domain/history"
	"athena/backend/internal/domain/research"
)

// HistoryHandlers manage reading progress and history endpoints.
type HistoryHandlers struct {
	Svc    *apphistory.Service
	Logger *slog.Logger
}

func NewHistoryHandlers(svc *apphistory.Service, log *slog.Logger) *HistoryHandlers {
	return &HistoryHandlers{Svc: svc, Logger: log}
}

// DTOs

type recordProgressRequestDTO struct {
	PaperID         string  `json:"paper_id"`
	ProgressPercent float64 `json:"progress_percent"`
}

type progressResponseDTO struct {
	PaperID         string  `json:"paper_id"`
	ProgressPercent float64 `json:"progress_percent"`
	Completed       bool    `json:"completed"`
	LastReadAt      string  `json:"last_read_at"`
}

type historyItemDTO struct {
	Paper           paperSummaryDTO `json:"paper"`
	ProgressPercent float64         `json:"progress_percent"`
	Completed       bool            `json:"completed"`
	LastReadAt      string          `json:"last_read_at"`
}

type historyListResponseDTO struct {
	Items []historyItemDTO `json:"items"`
	Meta  listMetaDTO      `json:"meta"`
}

// RecordProgress: POST /api/v1/me/history/progress
func (h *HistoryHandlers) RecordProgress(w http.ResponseWriter, r *http.Request) {
	user, ok := UserFromContext(r.Context())
	if !ok {
		WriteError(w, r, http.StatusUnauthorized, CodeUnauthorized, "authentication required")
		return
	}
	var req recordProgressRequestDTO
	if err := decodeJSON(r, &req); err != nil {
		WriteError(w, r, http.StatusBadRequest, CodeInvalidRequest, "invalid JSON body")
		return
	}
	paperID, err := uuid.Parse(req.PaperID)
	if err != nil {
		WriteErrorWithDetails(w, r, http.StatusBadRequest, CodeInvalidRequest,
			"paper_id must be a UUID",
			[]errorDetail{{Field: "paper_id", Issue: "must be a UUID"}})
		return
	}

	p, err := h.Svc.RecordProgress(r.Context(), user.ID, paperID, req.ProgressPercent)
	switch {
	case errors.Is(err, domainhistory.ErrInvalidInput):
		WriteError(w, r, http.StatusBadRequest, CodeInvalidRequest, err.Error())
	case err != nil:
		h.Logger.Error("record progress failed", "error", err, "request_id", RequestIDFrom(r.Context()))
		WriteError(w, r, http.StatusInternalServerError, CodeInternal, "internal error")
	default:
		WriteJSON(w, http.StatusOK, progressResponseDTO{
			PaperID:         p.PaperID.String(),
			ProgressPercent: p.ProgressPercent,
			Completed:       p.Completed,
			LastReadAt:      p.LastReadAt.Format(timeFormatRFC3339),
		})
	}
}

// GetProgress: GET /api/v1/me/history/progress/{paperId}
func (h *HistoryHandlers) GetProgress(w http.ResponseWriter, r *http.Request) {
	user, ok := UserFromContext(r.Context())
	if !ok {
		WriteError(w, r, http.StatusUnauthorized, CodeUnauthorized, "authentication required")
		return
	}
	paperID, err := uuid.Parse(r.PathValue("paperId"))
	if err != nil {
		WriteErrorWithDetails(w, r, http.StatusBadRequest, CodeInvalidRequest,
			"paperId must be a UUID",
			[]errorDetail{{Field: "paperId", Issue: "must be a UUID"}})
		return
	}

	p, err := h.Svc.GetProgress(r.Context(), user.ID, paperID)
	switch {
	case errors.Is(err, domainhistory.ErrNotFound):
		WriteError(w, r, http.StatusNotFound, CodeNotFound, "progress not found")
	case err != nil:
		h.Logger.Error("get progress failed", "error", err, "request_id", RequestIDFrom(r.Context()))
		WriteError(w, r, http.StatusInternalServerError, CodeInternal, "internal error")
	default:
		WriteJSON(w, http.StatusOK, progressResponseDTO{
			PaperID:         p.PaperID.String(),
			ProgressPercent: p.ProgressPercent,
			Completed:       p.Completed,
			LastReadAt:      p.LastReadAt.Format(timeFormatRFC3339),
		})
	}
}

// List: GET /api/v1/me/history
func (h *HistoryHandlers) List(w http.ResponseWriter, r *http.Request) {
	user, ok := UserFromContext(r.Context())
	if !ok {
		WriteError(w, r, http.StatusUnauthorized, CodeUnauthorized, "authentication required")
		return
	}
	q := r.URL.Query()
	limit := 20
	if raw := q.Get("limit"); raw != "" {
		if n, err := strconv.Atoi(raw); err == nil && n >= 1 && n <= 100 {
			limit = n
		}
	}

	items, next, err := h.Svc.ListHistory(r.Context(), user.ID, q.Get("cursor"), limit)
	switch {
	case errors.Is(err, research.ErrInvalidInput):
		WriteError(w, r, http.StatusBadRequest, CodeInvalidRequest, "malformed cursor")
	case err != nil:
		h.Logger.Error("list history failed", "error", err, "request_id", RequestIDFrom(r.Context()))
		WriteError(w, r, http.StatusInternalServerError, CodeInternal, "internal error")
	default:
		dtos := make([]historyItemDTO, 0, len(items))
		for _, item := range items {
			dtos = append(dtos, historyItemDTO{
				Paper:           newSummaryDTO(item.Paper),
				ProgressPercent: item.ProgressPercent,
				Completed:       item.Completed,
				LastReadAt:      item.LastReadAt.Format(timeFormatRFC3339),
			})
		}
		resp := historyListResponseDTO{
			Items: dtos,
			Meta:  listMetaDTO{Limit: limit},
		}
		if next != "" {
			resp.Meta.NextCursor = &next
		}
		WriteJSON(w, http.StatusOK, resp)
	}
}

// Clear: DELETE /api/v1/me/history
func (h *HistoryHandlers) Clear(w http.ResponseWriter, r *http.Request) {
	user, ok := UserFromContext(r.Context())
	if !ok {
		WriteError(w, r, http.StatusUnauthorized, CodeUnauthorized, "authentication required")
		return
	}
	if err := h.Svc.ClearHistory(r.Context(), user.ID); err != nil {
		h.Logger.Error("clear history failed", "error", err, "request_id", RequestIDFrom(r.Context()))
		WriteError(w, r, http.StatusInternalServerError, CodeInternal, "internal error")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
