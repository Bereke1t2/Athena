package v1

import (
	"errors"
	"log/slog"
	"net/http"
	"strconv"

	"github.com/google/uuid"

	appannotation "athena/backend/internal/application/annotation"
	domainannotation "athena/backend/internal/domain/annotation"
)

// AnnotationsHandlers serve paper annotations endpoints.
type AnnotationsHandlers struct {
	Svc    *appannotation.Service
	Logger *slog.Logger
}

func NewAnnotationsHandlers(svc *appannotation.Service, log *slog.Logger) *AnnotationsHandlers {
	return &AnnotationsHandlers{Svc: svc, Logger: log}
}

// ---- DTOs -------------------------------------------------------------------

type annotationDTO struct {
	ID           string `json:"id"`
	UserID       string `json:"user_id"`
	PaperID      string `json:"paper_id"`
	PageNumber   int    `json:"page_number"`
	SectionIndex int    `json:"section_index"`
	SelectedText string `json:"selected_text"`
	Note         string `json:"note"`
	Color        string `json:"color"`
	CreatedAt    string `json:"created_at"`
	UpdatedAt    string `json:"updated_at"`
}

type userAnnotationDTO struct {
	annotationDTO
	PaperTitle string `json:"paper_title"`
	PaperYear  int    `json:"paper_year"`
	PaperVenue string `json:"paper_venue,omitempty"`
	PaperDOI   string `json:"paper_doi,omitempty"`
}

type createAnnotationRequestDTO struct {
	PageNumber   int    `json:"page_number"`
	SectionIndex int    `json:"section_index"`
	SelectedText string `json:"selected_text"`
	Note         string `json:"note"`
	Color        string `json:"color"`
}

type updateAnnotationRequestDTO struct {
	Note  *string `json:"note,omitempty"`
	Color *string `json:"color,omitempty"`
}

func toAnnotationDTO(a domainannotation.Annotation) annotationDTO {
	return annotationDTO{
		ID:           a.ID.String(),
		UserID:       a.UserID.String(),
		PaperID:      a.PaperID.String(),
		PageNumber:   a.PageNumber,
		SectionIndex: a.SectionIndex,
		SelectedText: a.SelectedText,
		Note:         a.Note,
		Color:        a.Color,
		CreatedAt:    a.CreatedAt.Format(timeFormatRFC3339),
		UpdatedAt:    a.UpdatedAt.Format(timeFormatRFC3339),
	}
}

func toUserAnnotationDTO(a domainannotation.UserAnnotation) userAnnotationDTO {
	return userAnnotationDTO{
		annotationDTO: toAnnotationDTO(a.Annotation),
		PaperTitle:    a.PaperTitle,
		PaperYear:     a.PaperYear,
		PaperVenue:    a.PaperVenue,
		PaperDOI:      a.PaperDOI,
	}
}

// ---- Endpoints --------------------------------------------------------------

// ListMe: GET /api/v1/me/annotations
// Returns all annotations created by the authenticated user across papers with optional color and query filtering.
func (h *AnnotationsHandlers) ListMe(w http.ResponseWriter, r *http.Request) {
	user, ok := UserFromContext(r.Context())
	if !ok {
		WriteError(w, r, http.StatusUnauthorized, CodeUnauthorized, "authentication required")
		return
	}

	color := r.URL.Query().Get("color")
	q := r.URL.Query().Get("q")
	limit := 50
	if lStr := r.URL.Query().Get("limit"); lStr != "" {
		if l, err := strconv.Atoi(lStr); err == nil && l > 0 {
			limit = l
		}
	}

	filter := domainannotation.ListUserAnnotationsFilter{
		UserID: user.ID,
		Color:  color,
		Query:  q,
		Limit:  limit,
	}

	items, err := h.Svc.ListUserAnnotations(r.Context(), filter)
	if err != nil {
		h.Logger.Error("list user annotations failed", "error", err, "request_id", RequestIDFrom(r.Context()))
		WriteError(w, r, http.StatusInternalServerError, CodeInternal, "internal error")
		return
	}

	dtos := make([]userAnnotationDTO, len(items))
	for i, it := range items {
		dtos[i] = toUserAnnotationDTO(it)
	}
	WriteJSON(w, http.StatusOK, map[string]any{"items": dtos})
}

// List: GET /api/v1/papers/{id}/annotations
// Authenticated users get their personal annotations; guest users get an empty list.
func (h *AnnotationsHandlers) List(w http.ResponseWriter, r *http.Request) {
	paperID, err := uuid.Parse(r.PathValue("id"))
	if err != nil {
		WriteErrorWithDetails(w, r, http.StatusBadRequest, CodeInvalidRequest,
			"id must be a UUID", []errorDetail{{Field: "id", Issue: "must be a UUID"}})
		return
	}

	var userID uuid.UUID
	if user, ok := UserFromContext(r.Context()); ok {
		userID = user.ID
	}

	annotations, err := h.Svc.ListAnnotations(r.Context(), paperID, userID)
	if err != nil {
		h.Logger.Error("list annotations failed", "error", err, "request_id", RequestIDFrom(r.Context()))
		WriteError(w, r, http.StatusInternalServerError, CodeInternal, "internal error")
		return
	}

	dtos := make([]annotationDTO, len(annotations))
	for i, a := range annotations {
		dtos[i] = toAnnotationDTO(a)
	}
	WriteJSON(w, http.StatusOK, map[string]any{"items": dtos})
}

// Create: POST /api/v1/papers/{id}/annotations
func (h *AnnotationsHandlers) Create(w http.ResponseWriter, r *http.Request) {
	user, ok := UserFromContext(r.Context())
	if !ok {
		WriteError(w, r, http.StatusUnauthorized, CodeUnauthorized, "authentication required")
		return
	}

	paperID, err := uuid.Parse(r.PathValue("id"))
	if err != nil {
		WriteErrorWithDetails(w, r, http.StatusBadRequest, CodeInvalidRequest,
			"id must be a UUID", []errorDetail{{Field: "id", Issue: "must be a UUID"}})
		return
	}

	var req createAnnotationRequestDTO
	if err := decodeJSON(r, &req); err != nil {
		WriteError(w, r, http.StatusBadRequest, CodeInvalidRequest, "invalid JSON body")
		return
	}

	a, err := h.Svc.CreateAnnotation(r.Context(), domainannotation.CreateAnnotationInput{
		UserID:       user.ID,
		PaperID:      paperID,
		PageNumber:   req.PageNumber,
		SectionIndex: req.SectionIndex,
		SelectedText: req.SelectedText,
		Note:         req.Note,
		Color:        req.Color,
	})
	switch {
	case errors.Is(err, domainannotation.ErrInvalidInput):
		WriteError(w, r, http.StatusBadRequest, CodeInvalidRequest, err.Error())
	case err != nil:
		h.Logger.Error("create annotation failed", "error", err, "request_id", RequestIDFrom(r.Context()))
		WriteError(w, r, http.StatusInternalServerError, CodeInternal, "internal error")
	default:
		WriteJSON(w, http.StatusCreated, toAnnotationDTO(a))
	}
}

// Update: PATCH /api/v1/annotations/{id}
func (h *AnnotationsHandlers) Update(w http.ResponseWriter, r *http.Request) {
	user, ok := UserFromContext(r.Context())
	if !ok {
		WriteError(w, r, http.StatusUnauthorized, CodeUnauthorized, "authentication required")
		return
	}

	id, err := uuid.Parse(r.PathValue("id"))
	if err != nil {
		WriteErrorWithDetails(w, r, http.StatusBadRequest, CodeInvalidRequest,
			"id must be a UUID", []errorDetail{{Field: "id", Issue: "must be a UUID"}})
		return
	}

	var req updateAnnotationRequestDTO
	if err := decodeJSON(r, &req); err != nil {
		WriteError(w, r, http.StatusBadRequest, CodeInvalidRequest, "invalid JSON body")
		return
	}

	a, err := h.Svc.UpdateAnnotation(r.Context(), domainannotation.UpdateAnnotationInput{
		ID:     id,
		UserID: user.ID,
		Note:   req.Note,
		Color:  req.Color,
	})
	switch {
	case errors.Is(err, domainannotation.ErrNotFound):
		WriteError(w, r, http.StatusNotFound, CodeNotFound, "annotation not found")
	case errors.Is(err, domainannotation.ErrUnauthorized):
		WriteError(w, r, http.StatusForbidden, CodeForbidden, "access denied")
	case errors.Is(err, domainannotation.ErrInvalidInput):
		WriteError(w, r, http.StatusBadRequest, CodeInvalidRequest, err.Error())
	case err != nil:
		h.Logger.Error("update annotation failed", "error", err, "request_id", RequestIDFrom(r.Context()))
		WriteError(w, r, http.StatusInternalServerError, CodeInternal, "internal error")
	default:
		WriteJSON(w, http.StatusOK, toAnnotationDTO(a))
	}
}

// Delete: DELETE /api/v1/annotations/{id}
func (h *AnnotationsHandlers) Delete(w http.ResponseWriter, r *http.Request) {
	user, ok := UserFromContext(r.Context())
	if !ok {
		WriteError(w, r, http.StatusUnauthorized, CodeUnauthorized, "authentication required")
		return
	}

	id, err := uuid.Parse(r.PathValue("id"))
	if err != nil {
		WriteErrorWithDetails(w, r, http.StatusBadRequest, CodeInvalidRequest,
			"id must be a UUID", []errorDetail{{Field: "id", Issue: "must be a UUID"}})
		return
	}

	err = h.Svc.DeleteAnnotation(r.Context(), id, user.ID)
	switch {
	case errors.Is(err, domainannotation.ErrNotFound):
		WriteError(w, r, http.StatusNotFound, CodeNotFound, "annotation not found")
	case errors.Is(err, domainannotation.ErrUnauthorized):
		WriteError(w, r, http.StatusForbidden, CodeForbidden, "access denied")
	case errors.Is(err, domainannotation.ErrInvalidInput):
		WriteError(w, r, http.StatusBadRequest, CodeInvalidRequest, err.Error())
	case err != nil:
		h.Logger.Error("delete annotation failed", "error", err, "request_id", RequestIDFrom(r.Context()))
		WriteError(w, r, http.StatusInternalServerError, CodeInternal, "internal error")
	default:
		w.WriteHeader(http.StatusNoContent)
	}
}
