package v1

import (
	"errors"
	"log/slog"
	"net/http"
	"strconv"

	"github.com/google/uuid"

	appbookmark "athena/backend/internal/application/bookmark"
	domainbookmark "athena/backend/internal/domain/bookmark"
	"athena/backend/internal/domain/research"
)

// BookmarksHandlers serve /api/v1/me/bookmarks (Phase 5). All routes are
// mounted behind RequireAuth.
type BookmarksHandlers struct {
	Svc    *appbookmark.Service
	Logger *slog.Logger
}

func NewBookmarksHandlers(svc *appbookmark.Service, log *slog.Logger) *BookmarksHandlers {
	return &BookmarksHandlers{Svc: svc, Logger: log}
}

// ---- DTOs -------------------------------------------------------------------

type addBookmarkRequestDTO struct {
	PaperID string `json:"paper_id"`
	Note    string `json:"note"`
}

type bookmarkDTO struct {
	PaperID   string `json:"paper_id"`
	Note      string `json:"note,omitempty"`
	CreatedAt string `json:"created_at"`
}

type bookmarkListResponseDTO struct {
	Items []paperSummaryDTO `json:"items"`
	Meta  listMetaDTO       `json:"meta"`
}

// ---- POST /api/v1/me/bookmarks ----------------------------------------------

func (h *BookmarksHandlers) Add(w http.ResponseWriter, r *http.Request) {
	user, ok := UserFromContext(r.Context())
	if !ok {
		WriteError(w, r, http.StatusUnauthorized, CodeUnauthorized, "authentication required")
		return
	}
	var req addBookmarkRequestDTO
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
	b, err := h.Svc.Add(r.Context(), user.ID, paperID, req.Note)
	switch {
	case errors.Is(err, appbookmark.ErrInvalidInput):
		WriteError(w, r, http.StatusBadRequest, CodeInvalidRequest, err.Error())
	case errors.Is(err, research.ErrNotFound):
		WriteError(w, r, http.StatusNotFound, CodeNotFound, "no such paper")
	case err != nil:
		h.Logger.Error("add bookmark failed", "error", err, "request_id", RequestIDFrom(r.Context()))
		WriteError(w, r, http.StatusInternalServerError, CodeInternal, "internal error")
	default:
		WriteJSON(w, http.StatusCreated, bookmarkDTO{
			PaperID:   b.PaperID.String(),
			Note:      b.Note,
			CreatedAt: b.CreatedAt.Format(timeFormatRFC3339),
		})
	}
}

// ---- GET /api/v1/me/bookmarks -----------------------------------------------

func (h *BookmarksHandlers) List(w http.ResponseWriter, r *http.Request) {
	user, ok := UserFromContext(r.Context())
	if !ok {
		WriteError(w, r, http.StatusUnauthorized, CodeUnauthorized, "authentication required")
		return
	}
	q := r.URL.Query()
	limit := 20
	if raw := q.Get("limit"); raw != "" {
		n, err := strconv.Atoi(raw)
		if err != nil || n < 1 || n > 100 {
			WriteErrorWithDetails(w, r, http.StatusBadRequest, CodeInvalidRequest,
				"limit must be between 1 and 100",
				[]errorDetail{{Field: "limit", Issue: "must be between 1 and 100"}})
			return
		}
		limit = n
	}

	papers, next, err := h.Svc.List(r.Context(), user.ID, q.Get("cursor"), limit)
	switch {
	case errors.Is(err, research.ErrInvalidInput):
		WriteError(w, r, http.StatusBadRequest, CodeInvalidRequest, "malformed cursor")
	case errors.Is(err, domainbookmark.ErrNotFound):
		WriteError(w, r, http.StatusNotFound, CodeNotFound, "bookmark not found")
	case err != nil:
		h.Logger.Error("list bookmarks failed", "error", err, "request_id", RequestIDFrom(r.Context()))
		WriteError(w, r, http.StatusInternalServerError, CodeInternal, "internal error")
	default:
		out := bookmarkListResponseDTO{
			Items: make([]paperSummaryDTO, 0, len(papers)),
			Meta:  listMetaDTO{Limit: limit},
		}
		for _, p := range papers {
			out.Items = append(out.Items, newSummaryDTO(p))
		}
		if next != "" {
			out.Meta.NextCursor = &next
		}
		WriteJSON(w, http.StatusOK, out)
	}
}

// ---- DELETE /api/v1/me/bookmarks/{paperId} -----------------------------------

func (h *BookmarksHandlers) Remove(w http.ResponseWriter, r *http.Request) {
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
	if err := h.Svc.Remove(r.Context(), user.ID, paperID); err != nil {
		if errors.Is(err, appbookmark.ErrInvalidInput) {
			WriteError(w, r, http.StatusBadRequest, CodeInvalidRequest, err.Error())
			return
		}
		h.Logger.Error("remove bookmark failed", "error", err, "request_id", RequestIDFrom(r.Context()))
		WriteError(w, r, http.StatusInternalServerError, CodeInternal, "internal error")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
