package v1

import (
	"errors"
	"log/slog"
	"net/http"
	"strconv"

	"github.com/google/uuid"

	appnotif "athena/backend/internal/application/notification"
	domainnotif "athena/backend/internal/domain/notification"
	"athena/backend/internal/domain/research"
)

// NotificationsHandlers handle user alerts and notification delivery.
type NotificationsHandlers struct {
	Svc    *appnotif.Service
	Logger *slog.Logger
}

func NewNotificationsHandlers(svc *appnotif.Service, log *slog.Logger) *NotificationsHandlers {
	return &NotificationsHandlers{Svc: svc, Logger: log}
}

// DTOs

type notificationDTO struct {
	ID        string         `json:"id"`
	Type      string         `json:"type"`
	Title     string         `json:"title"`
	Body      string         `json:"body,omitempty"`
	Data      map[string]any `json:"data,omitempty"`
	ReadAt    *string        `json:"read_at,omitempty"`
	CreatedAt string         `json:"created_at"`
}

type notificationListResponseDTO struct {
	Items []notificationDTO `json:"items"`
	Meta  listMetaDTO       `json:"meta"`
}

type unreadCountResponseDTO struct {
	Count int `json:"count"`
}

// List: GET /api/v1/me/notifications
func (h *NotificationsHandlers) List(w http.ResponseWriter, r *http.Request) {
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
	unreadOnly := q.Get("unread") == "true" || q.Get("unread") == "1"

	items, next, err := h.Svc.List(r.Context(), user.ID, unreadOnly, q.Get("cursor"), limit)
	switch {
	case errors.Is(err, research.ErrInvalidInput):
		WriteError(w, r, http.StatusBadRequest, CodeInvalidRequest, "malformed cursor")
	case err != nil:
		h.Logger.Error("list notifications failed", "error", err, "request_id", RequestIDFrom(r.Context()))
		WriteError(w, r, http.StatusInternalServerError, CodeInternal, "internal error")
	default:
		dtos := make([]notificationDTO, 0, len(items))
		for _, item := range items {
			var readAtStr *string
			if item.ReadAt != nil {
				formatted := item.ReadAt.Format(timeFormatRFC3339)
				readAtStr = &formatted
			}
			dtos = append(dtos, notificationDTO{
				ID:        item.ID.String(),
				Type:      string(item.Type),
				Title:     item.Title,
				Body:      item.Body,
				Data:      item.Data,
				ReadAt:    readAtStr,
				CreatedAt: item.CreatedAt.Format(timeFormatRFC3339),
			})
		}
		resp := notificationListResponseDTO{
			Items: dtos,
			Meta:  listMetaDTO{Limit: limit},
		}
		if next != "" {
			resp.Meta.NextCursor = &next
		}
		WriteJSON(w, http.StatusOK, resp)
	}
}

// MarkRead: POST /api/v1/me/notifications/{id}/read
func (h *NotificationsHandlers) MarkRead(w http.ResponseWriter, r *http.Request) {
	user, ok := UserFromContext(r.Context())
	if !ok {
		WriteError(w, r, http.StatusUnauthorized, CodeUnauthorized, "authentication required")
		return
	}
	notifID, err := uuid.Parse(r.PathValue("id"))
	if err != nil {
		WriteErrorWithDetails(w, r, http.StatusBadRequest, CodeInvalidRequest,
			"id must be a UUID",
			[]errorDetail{{Field: "id", Issue: "must be a UUID"}})
		return
	}

	if err := h.Svc.MarkAsRead(r.Context(), user.ID, notifID); err != nil {
		if errors.Is(err, domainnotif.ErrNotFound) {
			WriteError(w, r, http.StatusNotFound, CodeNotFound, "notification not found")
			return
		}
		h.Logger.Error("mark notification read failed", "error", err, "request_id", RequestIDFrom(r.Context()))
		WriteError(w, r, http.StatusInternalServerError, CodeInternal, "internal error")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// MarkAllRead: POST /api/v1/me/notifications/read-all
func (h *NotificationsHandlers) MarkAllRead(w http.ResponseWriter, r *http.Request) {
	user, ok := UserFromContext(r.Context())
	if !ok {
		WriteError(w, r, http.StatusUnauthorized, CodeUnauthorized, "authentication required")
		return
	}
	if err := h.Svc.MarkAllAsRead(r.Context(), user.ID); err != nil {
		h.Logger.Error("mark all notifications read failed", "error", err, "request_id", RequestIDFrom(r.Context()))
		WriteError(w, r, http.StatusInternalServerError, CodeInternal, "internal error")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// UnreadCount: GET /api/v1/me/notifications/unread-count
func (h *NotificationsHandlers) UnreadCount(w http.ResponseWriter, r *http.Request) {
	user, ok := UserFromContext(r.Context())
	if !ok {
		WriteError(w, r, http.StatusUnauthorized, CodeUnauthorized, "authentication required")
		return
	}
	count, err := h.Svc.UnreadCount(r.Context(), user.ID)
	if err != nil {
		h.Logger.Error("unread count failed", "error", err, "request_id", RequestIDFrom(r.Context()))
		WriteError(w, r, http.StatusInternalServerError, CodeInternal, "internal error")
		return
	}
	WriteJSON(w, http.StatusOK, unreadCountResponseDTO{Count: count})
}
