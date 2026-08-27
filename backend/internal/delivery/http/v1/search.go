package v1

import (
	"errors"
	"log/slog"
	"net/http"
	"strconv"
	"strings"
	"time"

	domainsearch "athena/backend/internal/domain/search"

	appdiscover "athena/backend/internal/application/discover"
	appsearch "athena/backend/internal/application/search"
)

// SearchHandlers serve GET /api/v1/search and GET /api/v1/search/live
// (api-specification.md §2).
type SearchHandlers struct {
	Svc    *appsearch.Service
	Live   *appdiscover.Service // nil disables the federated endpoint
	Logger *slog.Logger
}

func NewSearchHandlers(svc *appsearch.Service, log *slog.Logger) *SearchHandlers {
	return &SearchHandlers{Svc: svc, Logger: log}
}

// NewSearchHandlersWithLive also enables the federated live endpoint.
func NewSearchHandlersWithLive(svc *appsearch.Service, live *appdiscover.Service, log *slog.Logger) *SearchHandlers {
	return &SearchHandlers{Svc: svc, Live: live, Logger: log}
}

// ---- DTOs -------------------------------------------------------------------

type scoredPaperDTO struct {
	Score float64         `json:"score"`
	Paper paperSummaryDTO `json:"paper"`
}

type searchMetaDTO struct {
	NextCursor    *string `json:"next_cursor"`
	ModeUsed      string  `json:"mode_used"`
	TookMS        int64   `json:"took_ms"`
	TotalEstimate int64   `json:"total_estimate"`
}

type sourceStatusDTO struct {
	Slug   string `json:"slug"`
	OK     bool   `json:"ok"`
	Papers int    `json:"papers"`
	Error  string `json:"error,omitempty"`
}

type liveSearchMetaDTO struct {
	TookMS  int64             `json:"took_ms"`
	Sources []sourceStatusDTO `json:"sources"`
}

type liveSearchResponseDTO struct {
	Items []scoredPaperDTO  `json:"items"`
	Meta  liveSearchMetaDTO `json:"meta"`
}

type searchResponseDTO struct {
	Items []scoredPaperDTO `json:"items"`
	Meta  searchMetaDTO    `json:"meta"`
}

// ---- GET /api/v1/search -----------------------------------------------------

func (h *SearchHandlers) Get(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query()

	query, err := domainsearch.NewQuery(q.Get("q"),
		domainsearch.Mode(q.Get("mode")),
		domainsearch.Sort(q.Get("sort")),
		parseLimitDefault(q.Get("limit"), 20))
	if err != nil {
		WriteErrorWithDetails(w, r, http.StatusBadRequest, CodeInvalidRequest,
			err.Error(), []errorDetail{{Field: "query", Issue: err.Error()}})
		return
	}
	query.TopicSlug = q.Get("topic")
	query.FieldSlug = q.Get("field")
	query.SourceSlug = q.Get("source")
	query.Cursor = q.Get("cursor")

	if raw := q.Get("min_citations"); raw != "" {
		n, perr := strconv.Atoi(raw)
		if perr != nil || n < 0 {
			WriteErrorWithDetails(w, r, http.StatusBadRequest, CodeInvalidRequest,
				"min_citations must be a non-negative integer",
				[]errorDetail{{Field: "min_citations", Issue: "must be a non-negative integer"}})
			return
		}
		query.MinCitations = n
	}
	if oa := q.Get("open_access"); oa != "" {
		v, perr := strconv.ParseBool(oa)
		if perr != nil {
			WriteErrorWithDetails(w, r, http.StatusBadRequest, CodeInvalidRequest,
				"open_access must be true|false",
				[]errorDetail{{Field: "open_access", Issue: "must be true|false"}})
			return
		}
		query.OpenAccess = &v
	}
	for name, dst := range map[string](**time.Time){
		"published_after":  &query.PublishedAfter,
		"published_before": &query.PublishedBefore,
	} {
		if raw := q.Get(name); raw != "" {
			t, perr := time.Parse("2006-01-02", raw)
			if perr != nil {
				WriteErrorWithDetails(w, r, http.StatusBadRequest, CodeInvalidRequest,
					name+" must be YYYY-MM-DD",
					[]errorDetail{{Field: name, Issue: "must be YYYY-MM-DD"}})
				return
			}
			*dst = &t
		}
	}

	page, err := h.Svc.Search(r.Context(), query)
	if err != nil {
		h.fail(w, r, err)
		return
	}

	out := searchResponseDTO{
		Items: make([]scoredPaperDTO, 0, len(page.Items)),
		Meta: searchMetaDTO{
			ModeUsed:      string(page.ModeUsed),
			TookMS:        page.TookMS,
			TotalEstimate: page.TotalEstimate,
		},
	}
	for _, it := range page.Items {
		out.Items = append(out.Items, scoredPaperDTO{Score: it.Score, Paper: newSummaryDTO(it.Paper)})
	}
	if page.NextCursor != "" {
		out.Meta.NextCursor = &page.NextCursor
	}
	WriteJSON(w, http.StatusOK, out)
}

// parseLimitDefault returns def when raw is empty; callers report range
// errors through NewQuery validation.
func parseLimitDefault(raw string, def int) int {
	if raw == "" {
		return def
	}
	n, err := strconv.Atoi(raw)
	if err != nil {
		return -1 // triggers NewQuery's limit validation error
	}
	return n
}

// ---- GET /api/v1/search/live ------------------------------------------------

// GetLive runs a federated live search across every configured research
// provider and returns the merged, ranked union. Results are persisted, so
// every item carries a stable paper id usable with /research/papers/{id}.
func (h *SearchHandlers) GetLive(w http.ResponseWriter, r *http.Request) {
	if h.Live == nil {
		WriteError(w, r, http.StatusNotImplemented, CodeNotImplemented,
			"live search is not enabled on this deployment")
		return
	}

	q := r.URL.Query()
	query, err := domainsearch.NewQuery(q.Get("q"), "",
		domainsearch.Sort(q.Get("sort")), parseLimitDefault(q.Get("limit"), 20))
	if err != nil {
		WriteErrorWithDetails(w, r, http.StatusBadRequest, CodeInvalidRequest,
			err.Error(), []errorDetail{{Field: "query", Issue: err.Error()}})
		return
	}
	if strings.TrimSpace(query.Q) == "" {
		WriteErrorWithDetails(w, r, http.StatusBadRequest, CodeInvalidRequest,
			"q is required", []errorDetail{{Field: "q", Issue: "is required"}})
		return
	}
	if raw := q.Get("min_citations"); raw != "" {
		n, perr := strconv.Atoi(raw)
		if perr != nil || n < 0 {
			WriteErrorWithDetails(w, r, http.StatusBadRequest, CodeInvalidRequest,
				"min_citations must be a non-negative integer",
				[]errorDetail{{Field: "min_citations", Issue: "must be a non-negative integer"}})
			return
		}
		query.MinCitations = n
	}
	if oa := q.Get("open_access"); oa != "" {
		v, perr := strconv.ParseBool(oa)
		if perr != nil {
			WriteErrorWithDetails(w, r, http.StatusBadRequest, CodeInvalidRequest,
				"open_access must be true|false",
				[]errorDetail{{Field: "open_access", Issue: "must be true|false"}})
			return
		}
		query.OpenAccess = &v
	}

	res, err := h.Live.Search(r.Context(), query)
	if err != nil {
		h.Logger.Error("live search failed", "error", err, "request_id", RequestIDFrom(r.Context()))
		WriteError(w, r, http.StatusInternalServerError, CodeInternal, "internal error")
		return
	}

	out := liveSearchResponseDTO{
		Items: make([]scoredPaperDTO, 0, len(res.Items)),
		Meta: liveSearchMetaDTO{
			TookMS:  res.TookMS,
			Sources: make([]sourceStatusDTO, 0, len(res.Sources)),
		},
	}
	for _, s := range res.Sources {
		out.Meta.Sources = append(out.Meta.Sources, sourceStatusDTO{
			Slug: s.Slug, OK: s.OK, Papers: s.Papers, Error: s.Error,
		})
	}
	for _, it := range res.Items {
		out.Items = append(out.Items, scoredPaperDTO{Score: it.Score, Paper: newSummaryDTO(it.Paper)})
	}
	WriteJSON(w, http.StatusOK, out)
}

func (h *SearchHandlers) fail(w http.ResponseWriter, r *http.Request, err error) {
	status, code, msg := http.StatusInternalServerError, CodeInternal, "internal error"
	switch {
	case errors.Is(err, domainsearch.ErrInvalidQuery):
		status, code, msg = http.StatusBadRequest, CodeInvalidRequest, "invalid query"
	case errors.Is(err, domainsearch.ErrNotFound):
		status, code, msg = http.StatusNotFound, CodeNotFound, "not found"
	}
	h.Logger.Error("search failed", "error", err, "request_id", RequestIDFrom(r.Context()))
	WriteError(w, r, status, code, msg)
}
