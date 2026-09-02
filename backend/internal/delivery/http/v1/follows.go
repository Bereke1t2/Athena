package v1

import (
	"errors"
	"log/slog"
	"net/http"

	"github.com/google/uuid"

	appfollow "athena/backend/internal/application/follow"
	domainfollow "athena/backend/internal/domain/follow"
)

// FollowsHandlers handle topic and author follow management.
type FollowsHandlers struct {
	Svc    *appfollow.Service
	Logger *slog.Logger
}

func NewFollowsHandlers(svc *appfollow.Service, log *slog.Logger) *FollowsHandlers {
	return &FollowsHandlers{Svc: svc, Logger: log}
}

// DTOs

type followTopicRequestDTO struct {
	TopicSlug string `json:"topic_slug"`
	Notify    *bool  `json:"notify,omitempty"`
}

type followTopicResponseDTO struct {
	TopicID   string `json:"topic_id"`
	TopicSlug string `json:"topic_slug"`
	TopicName string `json:"topic_name"`
	Notify    bool   `json:"notify"`
	CreatedAt string `json:"created_at"`
}

type followAuthorRequestDTO struct {
	AuthorID string `json:"author_id"`
}

type followAuthorResponseDTO struct {
	AuthorID   string `json:"author_id"`
	AuthorName string `json:"author_name"`
	CreatedAt  string `json:"created_at"`
}

type followedTopicsResponseDTO struct {
	Items []followTopicResponseDTO `json:"items"`
}

type followedAuthorsResponseDTO struct {
	Items []followAuthorResponseDTO `json:"items"`
}

// ---- Topic Handlers ----

// FollowTopic: POST /api/v1/me/follows/topics
func (h *FollowsHandlers) FollowTopic(w http.ResponseWriter, r *http.Request) {
	user, ok := UserFromContext(r.Context())
	if !ok {
		WriteError(w, r, http.StatusUnauthorized, CodeUnauthorized, "authentication required")
		return
	}
	var req followTopicRequestDTO
	if err := decodeJSON(r, &req); err != nil {
		WriteError(w, r, http.StatusBadRequest, CodeInvalidRequest, "invalid JSON body")
		return
	}
	notify := true
	if req.Notify != nil {
		notify = *req.Notify
	}

	tf, err := h.Svc.FollowTopicBySlug(r.Context(), user.ID, req.TopicSlug, notify)
	switch {
	case errors.Is(err, domainfollow.ErrInvalidInput):
		WriteError(w, r, http.StatusBadRequest, CodeInvalidRequest, err.Error())
	case errors.Is(err, domainfollow.ErrNotFound):
		WriteError(w, r, http.StatusNotFound, CodeNotFound, "topic not found")
	case err != nil:
		h.Logger.Error("follow topic failed", "error", err, "request_id", RequestIDFrom(r.Context()))
		WriteError(w, r, http.StatusInternalServerError, CodeInternal, "internal error")
	default:
		WriteJSON(w, http.StatusOK, followTopicResponseDTO{
			TopicID:   tf.TopicID.String(),
			TopicSlug: tf.TopicSlug,
			TopicName: tf.TopicName,
			Notify:    tf.Notify,
			CreatedAt: tf.CreatedAt.Format(timeFormatRFC3339),
		})
	}
}

// UnfollowTopic: DELETE /api/v1/me/follows/topics/{slug}
func (h *FollowsHandlers) UnfollowTopic(w http.ResponseWriter, r *http.Request) {
	user, ok := UserFromContext(r.Context())
	if !ok {
		WriteError(w, r, http.StatusUnauthorized, CodeUnauthorized, "authentication required")
		return
	}
	slug := r.PathValue("slug")
	if slug == "" {
		WriteError(w, r, http.StatusBadRequest, CodeInvalidRequest, "topic slug is required")
		return
	}
	if err := h.Svc.UnfollowTopicBySlug(r.Context(), user.ID, slug); err != nil {
		h.Logger.Error("unfollow topic failed", "error", err, "request_id", RequestIDFrom(r.Context()))
		WriteError(w, r, http.StatusInternalServerError, CodeInternal, "internal error")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// ListFollowedTopics: GET /api/v1/me/follows/topics
func (h *FollowsHandlers) ListFollowedTopics(w http.ResponseWriter, r *http.Request) {
	user, ok := UserFromContext(r.Context())
	if !ok {
		WriteError(w, r, http.StatusUnauthorized, CodeUnauthorized, "authentication required")
		return
	}
	topics, err := h.Svc.ListFollowedTopics(r.Context(), user.ID)
	if err != nil {
		h.Logger.Error("list followed topics failed", "error", err, "request_id", RequestIDFrom(r.Context()))
		WriteError(w, r, http.StatusInternalServerError, CodeInternal, "internal error")
		return
	}
	items := make([]followTopicResponseDTO, 0, len(topics))
	for _, t := range topics {
		items = append(items, followTopicResponseDTO{
			TopicID:   t.TopicID.String(),
			TopicSlug: t.TopicSlug,
			TopicName: t.TopicName,
			Notify:    t.Notify,
			CreatedAt: t.CreatedAt.Format(timeFormatRFC3339),
		})
	}
	WriteJSON(w, http.StatusOK, followedTopicsResponseDTO{Items: items})
}

// ---- Author Handlers ----

// FollowAuthor: POST /api/v1/me/follows/authors
func (h *FollowsHandlers) FollowAuthor(w http.ResponseWriter, r *http.Request) {
	user, ok := UserFromContext(r.Context())
	if !ok {
		WriteError(w, r, http.StatusUnauthorized, CodeUnauthorized, "authentication required")
		return
	}
	var req followAuthorRequestDTO
	if err := decodeJSON(r, &req); err != nil {
		WriteError(w, r, http.StatusBadRequest, CodeInvalidRequest, "invalid JSON body")
		return
	}
	authorID, err := uuid.Parse(req.AuthorID)
	if err != nil {
		WriteError(w, r, http.StatusBadRequest, CodeInvalidRequest, "author_id must be a UUID")
		return
	}

	af, err := h.Svc.FollowAuthor(r.Context(), user.ID, authorID)
	switch {
	case errors.Is(err, domainfollow.ErrInvalidInput):
		WriteError(w, r, http.StatusBadRequest, CodeInvalidRequest, err.Error())
	case errors.Is(err, domainfollow.ErrNotFound):
		WriteError(w, r, http.StatusNotFound, CodeNotFound, "author not found")
	case err != nil:
		h.Logger.Error("follow author failed", "error", err, "request_id", RequestIDFrom(r.Context()))
		WriteError(w, r, http.StatusInternalServerError, CodeInternal, "internal error")
	default:
		WriteJSON(w, http.StatusOK, followAuthorResponseDTO{
			AuthorID:   af.AuthorID.String(),
			AuthorName: af.AuthorName,
			CreatedAt:  af.CreatedAt.Format(timeFormatRFC3339),
		})
	}
}

// UnfollowAuthor: DELETE /api/v1/me/follows/authors/{authorId}
func (h *FollowsHandlers) UnfollowAuthor(w http.ResponseWriter, r *http.Request) {
	user, ok := UserFromContext(r.Context())
	if !ok {
		WriteError(w, r, http.StatusUnauthorized, CodeUnauthorized, "authentication required")
		return
	}
	authorID, err := uuid.Parse(r.PathValue("authorId"))
	if err != nil {
		WriteError(w, r, http.StatusBadRequest, CodeInvalidRequest, "authorId must be a UUID")
		return
	}
	if err := h.Svc.UnfollowAuthor(r.Context(), user.ID, authorID); err != nil {
		h.Logger.Error("unfollow author failed", "error", err, "request_id", RequestIDFrom(r.Context()))
		WriteError(w, r, http.StatusInternalServerError, CodeInternal, "internal error")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// ListFollowedAuthors: GET /api/v1/me/follows/authors
func (h *FollowsHandlers) ListFollowedAuthors(w http.ResponseWriter, r *http.Request) {
	user, ok := UserFromContext(r.Context())
	if !ok {
		WriteError(w, r, http.StatusUnauthorized, CodeUnauthorized, "authentication required")
		return
	}
	authors, err := h.Svc.ListFollowedAuthors(r.Context(), user.ID)
	if err != nil {
		h.Logger.Error("list followed authors failed", "error", err, "request_id", RequestIDFrom(r.Context()))
		WriteError(w, r, http.StatusInternalServerError, CodeInternal, "internal error")
		return
	}
	items := make([]followAuthorResponseDTO, 0, len(authors))
	for _, a := range authors {
		items = append(items, followAuthorResponseDTO{
			AuthorID:   a.AuthorID.String(),
			AuthorName: a.AuthorName,
			CreatedAt:  a.CreatedAt.Format(timeFormatRFC3339),
		})
	}
	WriteJSON(w, http.StatusOK, followedAuthorsResponseDTO{Items: items})
}
