package v1

import (
	"errors"
	"log/slog"
	"net/http"
	"strconv"
	"strings"

	appfeed "athena/backend/internal/application/feed"
)

// FeedHandlers serve GET /api/v1/feed (api-specification.md §2).
type FeedHandlers struct {
	Svc    *appfeed.Service
	Logger *slog.Logger
}

func NewFeedHandlers(svc *appfeed.Service, log *slog.Logger) *FeedHandlers {
	return &FeedHandlers{Svc: svc, Logger: log}
}

// ---- DTOs -------------------------------------------------------------------

type feedItemDTO struct {
	Section string          `json:"section"`
	Reason  string          `json:"reason,omitempty"`
	Paper   paperSummaryDTO `json:"paper"`
}

type feedResponseDTO struct {
	Items []feedItemDTO `json:"items"`
	Meta  listMetaDTO   `json:"meta"`
}

// ---- GET /api/v1/feed -------------------------------------------------------

func (h *FeedHandlers) Get(w http.ResponseWriter, r *http.Request) {
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

	// topic accepts a single slug or a comma-separated list (the mobile app
	// sends the user's followed topics); slugs OR-match.
	var topicSlugs []string
	for _, t := range strings.Split(q.Get("topic"), ",") {
		if t = strings.TrimSpace(t); t != "" {
			topicSlugs = append(topicSlugs, t)
		}
	}

	items, next, err := h.Svc.Get(r.Context(), appfeed.Section(q.Get("section")),
		topicSlugs, q.Get("field"), q.Get("cursor"), limit)
	if errors.Is(err, appfeed.ErrInvalidSection) {
		WriteErrorWithDetails(w, r, http.StatusBadRequest, CodeInvalidRequest,
			"unknown section", []errorDetail{{Field: "section", Issue: "must be latest|trending|recommended"}})
		return
	}
	if errors.Is(err, appfeed.ErrNotImplemented) {
		WriteError(w, r, http.StatusNotImplemented, CodeNotImplemented,
			"recommended arrives in Phase 5 (requires auth + personalization)")
		return
	}
	if err != nil {
		h.Logger.Error("feed failed", "error", err, "request_id", RequestIDFrom(r.Context()))
		WriteError(w, r, http.StatusInternalServerError, CodeInternal, "internal error")
		return
	}

	out := feedResponseDTO{
		Items: make([]feedItemDTO, 0, len(items)),
		Meta:  listMetaDTO{Limit: limit},
	}
	for _, it := range items {
		out.Items = append(out.Items, feedItemDTO{
			Section: string(it.Section),
			Reason:  it.Reason,
			Paper:   newSummaryDTO(it.Paper),
		})
	}
	if next != "" {
		out.Meta.NextCursor = &next
	}
	WriteJSON(w, http.StatusOK, out)
}
