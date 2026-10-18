package v1

import (
	"errors"
	"log/slog"
	"net/http"

	"github.com/google/uuid"

	appexport "athena/backend/internal/application/export"
	domainexport "athena/backend/internal/domain/export"
	"athena/backend/internal/domain/research"
)

// ExportHandlers serve paper citation export endpoints.
type ExportHandlers struct {
	Svc    *appexport.Service
	Logger *slog.Logger
}

func NewExportHandlers(svc *appexport.Service, log *slog.Logger) *ExportHandlers {
	return &ExportHandlers{Svc: svc, Logger: log}
}

// DTOs

type bulkExportRequestDTO struct {
	PaperIDs []string `json:"paper_ids"`
	Format   string   `json:"format"`
}

type exportResponseDTO struct {
	Format      string `json:"format"`
	ContentType string `json:"content_type"`
	Content     string `json:"content"`
}

// ExportPaper: GET /api/v1/research/papers/{id}/export
func (h *ExportHandlers) ExportPaper(w http.ResponseWriter, r *http.Request) {
	paperID, err := uuid.Parse(r.PathValue("id"))
	if err != nil {
		WriteErrorWithDetails(w, r, http.StatusBadRequest, CodeInvalidRequest,
			"id must be a UUID",
			[]errorDetail{{Field: "id", Issue: "must be a UUID"}})
		return
	}

	fmtParam := r.URL.Query().Get("format")
	if fmtParam == "" {
		fmtParam = "bibtex"
	}
	format := domainexport.Format(fmtParam)

	content, contentType, err := h.Svc.ExportPaper(r.Context(), paperID, format)
	switch {
	case errors.Is(err, research.ErrNotFound):
		WriteError(w, r, http.StatusNotFound, CodeNotFound, "paper not found")
	case errors.Is(err, domainexport.ErrUnsupportedFormat):
		WriteError(w, r, http.StatusBadRequest, CodeInvalidRequest, "unsupported format (supported: bibtex, ris, apa, mla, markdown)")
	case err != nil:
		h.Logger.Error("export paper failed", "error", err, "request_id", RequestIDFrom(r.Context()))
		WriteError(w, r, http.StatusInternalServerError, CodeInternal, "internal error")
	default:
		// If query has raw=true, return plain text with format Content-Type, otherwise JSON
		if r.URL.Query().Get("raw") == "true" {
			w.Header().Set("Content-Type", contentType)
			w.WriteHeader(http.StatusOK)
			_, _ = w.Write([]byte(content))
			return
		}
		WriteJSON(w, http.StatusOK, exportResponseDTO{
			Format:      string(format),
			ContentType: contentType,
			Content:     content,
		})
	}
}

// BulkExport: POST /api/v1/research/papers/export
func (h *ExportHandlers) BulkExport(w http.ResponseWriter, r *http.Request) {
	var req bulkExportRequestDTO
	if err := decodeJSON(r, &req); err != nil {
		WriteError(w, r, http.StatusBadRequest, CodeInvalidRequest, "invalid JSON body")
		return
	}
	if len(req.PaperIDs) == 0 {
		WriteError(w, r, http.StatusBadRequest, CodeInvalidRequest, "paper_ids cannot be empty")
		return
	}
	if len(req.PaperIDs) > 50 {
		WriteError(w, r, http.StatusBadRequest, CodeInvalidRequest, "maximum 50 papers per export")
		return
	}

	paperUUIDs := make([]uuid.UUID, 0, len(req.PaperIDs))
	for _, idStr := range req.PaperIDs {
		id, err := uuid.Parse(idStr)
		if err != nil {
			WriteError(w, r, http.StatusBadRequest, CodeInvalidRequest, "invalid paper ID in paper_ids")
			return
		}
		paperUUIDs = append(paperUUIDs, id)
	}

	if req.Format == "" {
		req.Format = "bibtex"
	}
	format := domainexport.Format(req.Format)

	content, contentType, err := h.Svc.ExportPapersBulk(r.Context(), paperUUIDs, format)
	switch {
	case errors.Is(err, domainexport.ErrUnsupportedFormat):
		WriteError(w, r, http.StatusBadRequest, CodeInvalidRequest, "unsupported format (supported: bibtex, ris, apa, mla, markdown)")
	case err != nil:
		h.Logger.Error("bulk export failed", "error", err, "request_id", RequestIDFrom(r.Context()))
		WriteError(w, r, http.StatusInternalServerError, CodeInternal, "internal error")
	default:
		WriteJSON(w, http.StatusOK, exportResponseDTO{
			Format:      string(format),
			ContentType: contentType,
			Content:     content,
		})
	}
}
