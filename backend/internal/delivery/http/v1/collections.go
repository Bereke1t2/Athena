package v1

import (
	"errors"
	"log/slog"
	"net/http"

	"github.com/google/uuid"

	appcollection "athena/backend/internal/application/collection"
	domaincollection "athena/backend/internal/domain/collection"
	domainexport "athena/backend/internal/domain/export"
)

// CollectionsHandlers serve /api/v1/collections endpoints.
type CollectionsHandlers struct {
	Svc    *appcollection.Service
	Logger *slog.Logger
}

func NewCollectionsHandlers(svc *appcollection.Service, log *slog.Logger) *CollectionsHandlers {
	return &CollectionsHandlers{Svc: svc, Logger: log}
}

// ---- DTOs -------------------------------------------------------------------

type createCollectionRequestDTO struct {
	Name        string `json:"name"`
	Description string `json:"description"`
	Color       string `json:"color"`
	IsPublic    bool   `json:"is_public"`
}

type updateCollectionRequestDTO struct {
	Name        *string `json:"name,omitempty"`
	Description *string `json:"description,omitempty"`
	Color       *string `json:"color,omitempty"`
	IsPublic    *bool   `json:"is_public,omitempty"`
}

type addCollectionPaperRequestDTO struct {
	PaperID string `json:"paper_id"`
	Note    string `json:"note"`
}

type collectionDTO struct {
	ID          string `json:"id"`
	UserID      string `json:"user_id"`
	Name        string `json:"name"`
	Description string `json:"description"`
	Color       string `json:"color"`
	IsPublic    bool   `json:"is_public"`
	PaperCount  int    `json:"paper_count"`
	CreatedAt   string `json:"created_at"`
	UpdatedAt   string `json:"updated_at"`
}

type collectionPaperDTO struct {
	CollectionID string          `json:"collection_id"`
	PaperID      string          `json:"paper_id"`
	Paper        paperSummaryDTO `json:"paper"`
	Note         string          `json:"note"`
	Position     int             `json:"position"`
	AddedAt      string          `json:"added_at"`
}

type collectionDetailResponseDTO struct {
	Collection collectionDTO        `json:"collection"`
	Papers     []collectionPaperDTO `json:"papers"`
}

type paperMembershipDTO struct {
	CollectionID   string `json:"collection_id"`
	CollectionName string `json:"collection_name"`
	Color          string `json:"color"`
	ContainsPaper  bool   `json:"contains_paper"`
	Note           string `json:"note,omitempty"`
}

func toCollectionDTO(c domaincollection.Collection) collectionDTO {
	return collectionDTO{
		ID:          c.ID.String(),
		UserID:      c.UserID.String(),
		Name:        c.Name,
		Description: c.Description,
		Color:       c.Color,
		IsPublic:    c.IsPublic,
		PaperCount:  c.PaperCount,
		CreatedAt:   c.CreatedAt.Format(timeFormatRFC3339),
		UpdatedAt:   c.UpdatedAt.Format(timeFormatRFC3339),
	}
}

// ---- Endpoints --------------------------------------------------------------

// Create: POST /api/v1/collections
func (h *CollectionsHandlers) Create(w http.ResponseWriter, r *http.Request) {
	user, ok := UserFromContext(r.Context())
	if !ok {
		WriteError(w, r, http.StatusUnauthorized, CodeUnauthorized, "authentication required")
		return
	}

	var req createCollectionRequestDTO
	if err := decodeJSON(r, &req); err != nil {
		WriteError(w, r, http.StatusBadRequest, CodeInvalidRequest, "invalid JSON body")
		return
	}

	c, err := h.Svc.CreateCollection(r.Context(), domaincollection.CreateInput{
		UserID:      user.ID,
		Name:        req.Name,
		Description: req.Description,
		Color:       req.Color,
		IsPublic:    req.IsPublic,
	})
	switch {
	case errors.Is(err, domaincollection.ErrInvalidInput):
		WriteError(w, r, http.StatusBadRequest, CodeInvalidRequest, err.Error())
	case errors.Is(err, domaincollection.ErrDuplicateName):
		WriteError(w, r, http.StatusConflict, CodeConflict, "a collection with this name already exists")
	case err != nil:
		h.Logger.Error("create collection failed", "error", err, "request_id", RequestIDFrom(r.Context()))
		WriteError(w, r, http.StatusInternalServerError, CodeInternal, "internal error")
	default:
		WriteJSON(w, http.StatusCreated, toCollectionDTO(c))
	}
}

// List: GET /api/v1/collections
func (h *CollectionsHandlers) List(w http.ResponseWriter, r *http.Request) {
	user, ok := UserFromContext(r.Context())
	if !ok {
		WriteError(w, r, http.StatusUnauthorized, CodeUnauthorized, "authentication required")
		return
	}

	collections, err := h.Svc.ListCollections(r.Context(), user.ID)
	if err != nil {
		h.Logger.Error("list collections failed", "error", err, "request_id", RequestIDFrom(r.Context()))
		WriteError(w, r, http.StatusInternalServerError, CodeInternal, "internal error")
		return
	}

	dtos := make([]collectionDTO, len(collections))
	for i, c := range collections {
		dtos[i] = toCollectionDTO(c)
	}
	WriteJSON(w, http.StatusOK, map[string]any{"items": dtos})
}

// Get: GET /api/v1/collections/{id}
func (h *CollectionsHandlers) Get(w http.ResponseWriter, r *http.Request) {
	var userID uuid.UUID
	if user, ok := UserFromContext(r.Context()); ok {
		userID = user.ID
	}

	id, err := uuid.Parse(r.PathValue("id"))
	if err != nil {
		WriteErrorWithDetails(w, r, http.StatusBadRequest, CodeInvalidRequest,
			"id must be a UUID", []errorDetail{{Field: "id", Issue: "must be a UUID"}})
		return
	}

	c, papers, err := h.Svc.GetCollection(r.Context(), userID, id)
	switch {
	case errors.Is(err, domaincollection.ErrNotFound):
		WriteError(w, r, http.StatusNotFound, CodeNotFound, "collection not found")
	case errors.Is(err, domaincollection.ErrUnauthorized):
		WriteError(w, r, http.StatusForbidden, CodeForbidden, "access denied")
	case err != nil:
		h.Logger.Error("get collection failed", "error", err, "request_id", RequestIDFrom(r.Context()))
		WriteError(w, r, http.StatusInternalServerError, CodeInternal, "internal error")
	default:
		paperDTOs := make([]collectionPaperDTO, len(papers))
		for i, p := range papers {
			paperDTOs[i] = collectionPaperDTO{
				CollectionID: p.CollectionID.String(),
				PaperID:      p.PaperID.String(),
				Paper:        newSummaryDTO(p.Paper),
				Note:         p.Note,
				Position:     p.Position,
				AddedAt:      p.AddedAt.Format(timeFormatRFC3339),
			}
		}
		WriteJSON(w, http.StatusOK, collectionDetailResponseDTO{
			Collection: toCollectionDTO(c),
			Papers:     paperDTOs,
		})
	}
}

// Update: PATCH /api/v1/collections/{id}
func (h *CollectionsHandlers) Update(w http.ResponseWriter, r *http.Request) {
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

	var req updateCollectionRequestDTO
	if err := decodeJSON(r, &req); err != nil {
		WriteError(w, r, http.StatusBadRequest, CodeInvalidRequest, "invalid JSON body")
		return
	}

	updated, err := h.Svc.UpdateCollection(r.Context(), user.ID, id, domaincollection.UpdateInput{
		Name:        req.Name,
		Description: req.Description,
		Color:       req.Color,
		IsPublic:    req.IsPublic,
	})
	switch {
	case errors.Is(err, domaincollection.ErrNotFound):
		WriteError(w, r, http.StatusNotFound, CodeNotFound, "collection not found")
	case errors.Is(err, domaincollection.ErrUnauthorized):
		WriteError(w, r, http.StatusForbidden, CodeForbidden, "cannot modify collection owned by another user")
	case errors.Is(err, domaincollection.ErrDuplicateName):
		WriteError(w, r, http.StatusConflict, CodeConflict, "a collection with this name already exists")
	case errors.Is(err, domaincollection.ErrInvalidInput):
		WriteError(w, r, http.StatusBadRequest, CodeInvalidRequest, err.Error())
	case err != nil:
		h.Logger.Error("update collection failed", "error", err, "request_id", RequestIDFrom(r.Context()))
		WriteError(w, r, http.StatusInternalServerError, CodeInternal, "internal error")
	default:
		WriteJSON(w, http.StatusOK, toCollectionDTO(updated))
	}
}

// Delete: DELETE /api/v1/collections/{id}
func (h *CollectionsHandlers) Delete(w http.ResponseWriter, r *http.Request) {
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

	err = h.Svc.DeleteCollection(r.Context(), user.ID, id)
	switch {
	case errors.Is(err, domaincollection.ErrNotFound):
		WriteError(w, r, http.StatusNotFound, CodeNotFound, "collection not found")
	case errors.Is(err, domaincollection.ErrUnauthorized):
		WriteError(w, r, http.StatusForbidden, CodeForbidden, "cannot delete collection owned by another user")
	case err != nil:
		h.Logger.Error("delete collection failed", "error", err, "request_id", RequestIDFrom(r.Context()))
		WriteError(w, r, http.StatusInternalServerError, CodeInternal, "internal error")
	default:
		w.WriteHeader(http.StatusNoContent)
	}
}

// AddPaper: POST /api/v1/collections/{id}/papers
func (h *CollectionsHandlers) AddPaper(w http.ResponseWriter, r *http.Request) {
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

	var req addCollectionPaperRequestDTO
	if err := decodeJSON(r, &req); err != nil {
		WriteError(w, r, http.StatusBadRequest, CodeInvalidRequest, "invalid JSON body")
		return
	}

	paperID, err := uuid.Parse(req.PaperID)
	if err != nil {
		WriteErrorWithDetails(w, r, http.StatusBadRequest, CodeInvalidRequest,
			"paper_id must be a UUID", []errorDetail{{Field: "paper_id", Issue: "must be a UUID"}})
		return
	}

	err = h.Svc.AddPaper(r.Context(), user.ID, id, paperID, req.Note)
	switch {
	case errors.Is(err, domaincollection.ErrNotFound):
		WriteError(w, r, http.StatusNotFound, CodeNotFound, "collection not found")
	case errors.Is(err, domaincollection.ErrPaperNotFound):
		WriteError(w, r, http.StatusNotFound, CodeNotFound, "paper not found")
	case errors.Is(err, domaincollection.ErrUnauthorized):
		WriteError(w, r, http.StatusForbidden, CodeForbidden, "cannot modify collection owned by another user")
	case err != nil:
		h.Logger.Error("add paper to collection failed", "error", err, "request_id", RequestIDFrom(r.Context()))
		WriteError(w, r, http.StatusInternalServerError, CodeInternal, "internal error")
	default:
		WriteJSON(w, http.StatusCreated, map[string]string{"status": "added"})
	}
}

// RemovePaper: DELETE /api/v1/collections/{id}/papers/{paper_id}
func (h *CollectionsHandlers) RemovePaper(w http.ResponseWriter, r *http.Request) {
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

	paperID, err := uuid.Parse(r.PathValue("paper_id"))
	if err != nil {
		WriteErrorWithDetails(w, r, http.StatusBadRequest, CodeInvalidRequest,
			"paper_id must be a UUID", []errorDetail{{Field: "paper_id", Issue: "must be a UUID"}})
		return
	}

	err = h.Svc.RemovePaper(r.Context(), user.ID, id, paperID)
	switch {
	case errors.Is(err, domaincollection.ErrNotFound):
		WriteError(w, r, http.StatusNotFound, CodeNotFound, "collection not found")
	case errors.Is(err, domaincollection.ErrUnauthorized):
		WriteError(w, r, http.StatusForbidden, CodeForbidden, "cannot modify collection owned by another user")
	case err != nil:
		h.Logger.Error("remove paper from collection failed", "error", err, "request_id", RequestIDFrom(r.Context()))
		WriteError(w, r, http.StatusInternalServerError, CodeInternal, "internal error")
	default:
		w.WriteHeader(http.StatusNoContent)
	}
}

// Export: GET /api/v1/collections/{id}/export
func (h *CollectionsHandlers) Export(w http.ResponseWriter, r *http.Request) {
	var userID uuid.UUID
	if user, ok := UserFromContext(r.Context()); ok {
		userID = user.ID
	}

	id, err := uuid.Parse(r.PathValue("id"))
	if err != nil {
		WriteErrorWithDetails(w, r, http.StatusBadRequest, CodeInvalidRequest,
			"id must be a UUID", []errorDetail{{Field: "id", Issue: "must be a UUID"}})
		return
	}

	fmtParam := r.URL.Query().Get("format")
	if fmtParam == "" {
		fmtParam = "bibtex"
	}
	format := domainexport.Format(fmtParam)

	content, contentType, err := h.Svc.ExportCollection(r.Context(), userID, id, format)
	switch {
	case errors.Is(err, domaincollection.ErrNotFound):
		WriteError(w, r, http.StatusNotFound, CodeNotFound, "collection not found")
	case errors.Is(err, domaincollection.ErrUnauthorized):
		WriteError(w, r, http.StatusForbidden, CodeForbidden, "access denied")
	case errors.Is(err, domainexport.ErrUnsupportedFormat):
		WriteError(w, r, http.StatusBadRequest, CodeInvalidRequest, "unsupported format (supported: bibtex, ris, apa, mla, markdown)")
	case err != nil:
		h.Logger.Error("export collection failed", "error", err, "request_id", RequestIDFrom(r.Context()))
		WriteError(w, r, http.StatusInternalServerError, CodeInternal, "internal error")
	default:
		WriteJSON(w, http.StatusOK, exportResponseDTO{
			Format:      string(format),
			ContentType: contentType,
			Content:     content,
		})
	}
}

// PaperMemberships: GET /api/v1/papers/{id}/collections
func (h *CollectionsHandlers) PaperMemberships(w http.ResponseWriter, r *http.Request) {
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

	memberships, err := h.Svc.GetPaperMemberships(r.Context(), user.ID, paperID)
	if err != nil {
		h.Logger.Error("get paper memberships failed", "error", err, "request_id", RequestIDFrom(r.Context()))
		WriteError(w, r, http.StatusInternalServerError, CodeInternal, "internal error")
		return
	}

	dtos := make([]paperMembershipDTO, len(memberships))
	for i, m := range memberships {
		dtos[i] = paperMembershipDTO{
			CollectionID:   m.CollectionID.String(),
			CollectionName: m.CollectionName,
			Color:          m.Color,
			ContainsPaper:  m.ContainsPaper,
			Note:           m.Note,
		}
	}
	WriteJSON(w, http.StatusOK, map[string]any{"items": dtos})
}
