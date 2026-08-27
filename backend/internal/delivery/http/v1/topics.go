package v1

import (
	"errors"
	"log/slog"
	"net/http"
	"strconv"

	"athena/backend/internal/domain/taxonomy"
)

// TopicsHandlers serve the /api/v1/topics endpoints (api-specification.md §2).
type TopicsHandlers struct {
	Reader   taxonomy.Reader
	Research *ResearchHandlers // /topics/{slug}/research delegates to the list endpoint
	Logger   *slog.Logger
}

func NewTopicsHandlers(reader taxonomy.Reader, research *ResearchHandlers, log *slog.Logger) *TopicsHandlers {
	return &TopicsHandlers{Reader: reader, Research: research, Logger: log}
}

// ---- DTOs -------------------------------------------------------------------

type topicParentDTO struct {
	Slug string `json:"slug"`
	Name string `json:"name"`
}

type topicDTO struct {
	Slug               string          `json:"slug"`
	Name               string          `json:"name"`
	Description        string          `json:"description,omitempty"`
	Kind               string          `json:"kind"`
	Parent             *topicParentDTO `json:"parent,omitempty"`
	PaperCountEstimate int64           `json:"paper_count_estimate"`
	Children           []string        `json:"children,omitempty"`
}

type topicListMetaDTO struct {
	NextCursor *string `json:"next_cursor"`
	Limit      int     `json:"limit"`
}

type topicListResponseDTO struct {
	Items []topicDTO       `json:"items"`
	Meta  topicListMetaDTO `json:"meta"`
}

func newTopicDTO(s taxonomy.Summary) topicDTO {
	out := topicDTO{
		Slug:               s.Slug,
		Name:               s.Name,
		Description:        s.Description,
		Kind:               string(s.Kind),
		PaperCountEstimate: s.PaperCount,
	}
	if s.ParentSlug != "" {
		out.Parent = &topicParentDTO{Slug: s.ParentSlug, Name: s.ParentName}
	}
	return out
}

// ---- GET /api/v1/topics -----------------------------------------------------

func (h *TopicsHandlers) List(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query()

	lq := taxonomy.ListQuery{
		Kind:       taxonomy.Kind(q.Get("kind")),
		Q:          q.Get("q"),
		ParentSlug: q.Get("parent"),
		Cursor:     q.Get("cursor"),
		Limit:      50,
	}
	if raw := q.Get("limit"); raw != "" {
		n, err := strconv.Atoi(raw)
		if err != nil || n < 1 || n > 200 {
			WriteErrorWithDetails(w, r, http.StatusBadRequest, CodeInvalidRequest,
				"limit must be between 1 and 200",
				[]errorDetail{{Field: "limit", Issue: "must be between 1 and 200"}})
			return
		}
		lq.Limit = n
	}
	switch lq.Kind {
	case "", taxonomy.KindField, taxonomy.KindTopic:
	default:
		WriteErrorWithDetails(w, r, http.StatusBadRequest, CodeInvalidRequest,
			"unknown kind", []errorDetail{{Field: "kind", Issue: "must be field|topic"}})
		return
	}

	items, next, err := h.Reader.List(r.Context(), lq)
	if err != nil {
		h.fail(w, r, err)
		return
	}

	out := topicListResponseDTO{
		Items: make([]topicDTO, 0, len(items)),
		Meta:  topicListMetaDTO{Limit: lq.Limit},
	}
	for _, it := range items {
		out.Items = append(out.Items, newTopicDTO(it))
	}
	if next != "" {
		out.Meta.NextCursor = &next
	}
	WriteJSON(w, http.StatusOK, out)
}

// ---- GET /api/v1/topics/{slug} ---------------------------------------------

func (h *TopicsHandlers) Get(w http.ResponseWriter, r *http.Request) {
	d, err := h.Reader.GetBySlug(r.Context(), r.PathValue("slug"))
	if errors.Is(err, taxonomy.ErrNotFound) {
		WriteError(w, r, http.StatusNotFound, CodeNotFound, "topic not found")
		return
	}
	if err != nil {
		h.fail(w, r, err)
		return
	}

	out := newTopicDTO(d.Summary)
	out.Children = d.Children
	if out.Children == nil {
		out.Children = []string{}
	}
	WriteJSON(w, http.StatusOK, out)
}

// ---- GET /api/v1/topics/{slug}/research ------------------------------------

// ListResearch reuses the papers listing with the topic filter pinned to the
// path slug ("same filters as /research" per spec).
func (h *TopicsHandlers) ListResearch(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query()
	q.Set("topic", r.PathValue("slug"))
	r.URL.RawQuery = q.Encode()
	h.Research.List(w, r)
}

func (h *TopicsHandlers) fail(w http.ResponseWriter, r *http.Request, err error) {
	status, code, msg := http.StatusInternalServerError, CodeInternal, "internal error"
	switch {
	case errors.Is(err, taxonomy.ErrNotFound):
		status, code, msg = http.StatusNotFound, CodeNotFound, "topic not found"
	case errors.Is(err, taxonomy.ErrInvalidQuery):
		status, code, msg = http.StatusBadRequest, CodeInvalidRequest, "invalid request"
	}
	h.Logger.Error("topics request failed", "error", err, "request_id", RequestIDFrom(r.Context()))
	WriteError(w, r, status, code, msg)
}
