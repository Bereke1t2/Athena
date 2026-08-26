package v1

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/google/uuid"

	"athena/backend/internal/domain/research"
)

// ResearchHandlers serve the public research endpoints.
type ResearchHandlers struct {
	Reader research.PaperReader
	Logger *slog.Logger
}

func NewResearchHandlers(reader research.PaperReader, log *slog.Logger) *ResearchHandlers {
	return &ResearchHandlers{Reader: reader, Logger: log}
}

// ---- DTOs (snake_case per API spec) ----------------------------------------

type paperSummaryDTO struct {
	ID              uuid.UUID  `json:"id"`
	Title           string     `json:"title"`
	Abstract        *string    `json:"abstract"`
	PublicationDate *time.Time `json:"publication_date"`
	PublicationYear int        `json:"publication_year"`
	Venue           venueDTO   `json:"venue"`
	PublicationType string     `json:"publication_type"`
	OAStatus        string     `json:"oa_status"`
	IsOpenAccess    bool       `json:"is_open_access"`
	CitedByCount    int        `json:"cited_by_count"`
}

type venueDTO struct {
	Name string `json:"name"`
	Type string `json:"type,omitempty"`
}

func newSummaryDTO(s research.PaperSummary) paperSummaryDTO {
	var abs *string
	if s.Abstract != nil && strings.TrimSpace(*s.Abstract) != "" {
		abs = s.Abstract
	}
	return paperSummaryDTO{
		ID:              s.ID,
		Title:           s.Title,
		Abstract:        abs,
		PublicationDate: s.PublishedOn,
		PublicationYear: s.Year,
		Venue:           venueDTO{Name: s.VenueName},
		PublicationType: string(s.PublicationType),
		OAStatus:        string(s.OAStatus),
		IsOpenAccess:    s.IsOpenAccess,
		CitedByCount:    s.CitedByCount,
	}
}

type listMetaDTO struct {
	NextCursor *string `json:"next_cursor"`
	Limit      int     `json:"limit"`
}

type listResponseDTO struct {
	Items []paperSummaryDTO `json:"items"`
	Meta  listMetaDTO       `json:"meta"`
}

// ---- GET /api/v1/research/papers -------------------------------------------

func (h *ResearchHandlers) List(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query()

	limit := 20
	if raw := q.Get("limit"); raw != "" {
		n, err := strconv.Atoi(raw)
		if err != nil || n < 1 {
			WriteErrorWithDetails(w, r, http.StatusBadRequest, CodeInvalidRequest,
				"limit must be a positive integer", []errorDetail{{Field: "limit", Issue: "must be a positive integer"}})
			return
		}
		limit = n
	}
	if limit > 100 {
		WriteErrorWithDetails(w, r, http.StatusBadRequest, CodeInvalidRequest,
			"limit must be <= 100", []errorDetail{{Field: "limit", Issue: "must be <= 100"}})
		return
	}

	sort := q.Get("sort")
	switch sort {
	case "", string(research.SortNewest), string(research.SortCitations):
	default:
		WriteErrorWithDetails(w, r, http.StatusBadRequest, CodeInvalidRequest,
			"unknown sort", []errorDetail{{Field: "sort", Issue: "must be newest|citations"}})
		return
	}

	query := research.ListQuery{
		Sort:       research.SortOrder(sort),
		Limit:      limit,
		Cursor:     q.Get("cursor"),
		TopicSlug:  q.Get("topic"),
		FieldSlug:  q.Get("field"),
		SourceSlug: q.Get("source"),
	}

	if oa := q.Get("open_access"); oa != "" {
		v, err := strconv.ParseBool(oa)
		if err != nil {
			WriteErrorWithDetails(w, r, http.StatusBadRequest, CodeInvalidRequest,
				"open_access must be true|false",
				[]errorDetail{{Field: "open_access", Issue: "must be true|false"}})
			return
		}
		query.OpenAccess = &v
	}
	parseDay := func(name, raw string) (*time.Time, error) {
		t, err := time.Parse("2006-01-02", raw)
		if err != nil {
			return nil, err
		}
		return &t, nil
	}
	for name, dst := range map[string](**time.Time){
		"published_after":  &query.PublishedAfter,
		"published_before": &query.PublishedBefore,
	} {
		if raw := q.Get(name); raw != "" {
			t, err := parseDay(name, raw)
			if err != nil {
				WriteErrorWithDetails(w, r, http.StatusBadRequest, CodeInvalidRequest,
					name+" must be YYYY-MM-DD",
					[]errorDetail{{Field: name, Issue: "must be YYYY-MM-DD"}})
				return
			}
			*dst = t
		}
	}

	items, next, err := h.Reader.ListPapers(r.Context(), query)
	if err != nil {
		h.fail(w, r, err, "listing papers")
		return
	}

	out := listResponseDTO{Items: make([]paperSummaryDTO, 0, len(items)), Meta: listMetaDTO{Limit: limit}}
	for _, it := range items {
		out.Items = append(out.Items, newSummaryDTO(it))
	}
	if next != "" {
		out.Meta.NextCursor = &next
	}
	WriteJSON(w, http.StatusOK, out)
}

// ---- GET /api/v1/research/papers/{id} --------------------------------------

// resolvePaperID accepts UUIDs, DOIs, and arXiv identifiers (spec:
// GET /research/{id} — UUID, DOI, or arXiv ID all accepted).
func (h *ResearchHandlers) resolvePaperID(ctx context.Context, raw string) (uuid.UUID, error) {
	raw = strings.TrimSpace(raw)
	if id, err := uuid.Parse(raw); err == nil {
		return id, nil
	}
	if doi := research.CanonicalizeDOI(raw); doi != "" {
		return h.Reader.FindIDByIdentifier(ctx, research.IDTypeDOI, doi)
	}
	if arxivid := research.CanonicalizeArxivID(raw); arxivid != "" {
		return h.Reader.FindIDByIdentifier(ctx, research.IDTypeArxiv, arxivid)
	}
	return uuid.Nil, research.ErrNotFound
}

func (h *ResearchHandlers) Get(w http.ResponseWriter, r *http.Request) {
	id, err := h.resolvePaperID(r.Context(), r.PathValue("id"))
	if errors.Is(err, research.ErrNotFound) || id == uuid.Nil {
		WriteError(w, r, http.StatusNotFound, CodeNotFound, "paper not found")
		return
	}
	if err != nil {
		h.fail(w, r, err, "resolving identifier")
		return
	}

	detail, err := h.Reader.GetDetailByID(r.Context(), id)
	if errors.Is(err, research.ErrNotFound) {
		WriteError(w, r, http.StatusNotFound, CodeNotFound, "paper not found")
		return
	}
	if err != nil {
		h.fail(w, r, err, "loading paper")
		return
	}
	WriteJSON(w, http.StatusOK, newDetailDTO(detail))
}

// ---- citations / related ----------------------------------------------------

func (h *ResearchHandlers) Citations(w http.ResponseWriter, r *http.Request) {
	id, ok := h.lookupByPathID(w, r)
	if !ok {
		return
	}

	dir := research.CitedBy // default: cited-by listing
	switch r.URL.Query().Get("direction") {
	case "", "in":
	case "out":
		dir = research.References
	default:
		WriteErrorWithDetails(w, r, http.StatusBadRequest, CodeInvalidRequest,
			"direction must be in|out",
			[]errorDetail{{Field: "direction", Issue: "must be in|out"}})
		return
	}
	limit, okLimit := h.clampLimit(w, r, 25, 100)
	if !okLimit {
		return
	}

	items, err := h.Reader.ListCitations(r.Context(), id, dir, limit)
	if err != nil {
		h.fail(w, r, err, "traversing citations")
		return
	}
	out := listResponseDTO{Items: make([]paperSummaryDTO, 0, len(items)), Meta: listMetaDTO{Limit: limit}}
	for _, it := range items {
		out.Items = append(out.Items, newSummaryDTO(it))
	}
	WriteJSON(w, http.StatusOK, out)
}

func (h *ResearchHandlers) Related(w http.ResponseWriter, r *http.Request) {
	id, ok := h.lookupByPathID(w, r)
	if !ok {
		return
	}
	limit, okLimit := h.clampLimit(w, r, 10, 50)
	if !okLimit {
		return
	}
	items, err := h.Reader.RelatedBySharedTopics(r.Context(), id, limit)
	if err != nil {
		h.fail(w, r, err, "finding related papers")
		return
	}
	out := listResponseDTO{Items: make([]paperSummaryDTO, 0, len(items)), Meta: listMetaDTO{Limit: limit}}
	for _, it := range items {
		out.Items = append(out.Items, newSummaryDTO(it))
	}
	WriteJSON(w, http.StatusOK, out)
}

// ---- helpers -----------------------------------------------------------------

// lookupByPathID resolves {id} and maps resolution failures to responses.
func (h *ResearchHandlers) lookupByPathID(w http.ResponseWriter, r *http.Request) (uuid.UUID, bool) {
	id, err := h.resolvePaperID(r.Context(), r.PathValue("id"))
	switch {
	case err == nil && id != uuid.Nil:
		return id, true
	case errors.Is(err, research.ErrNotFound), id == uuid.Nil:
		WriteError(w, r, http.StatusNotFound, CodeNotFound, "paper not found")
	default:
		h.fail(w, r, err, "resolving identifier")
	}
	return uuid.Nil, false
}

func (h *ResearchHandlers) clampLimit(w http.ResponseWriter, r *http.Request, def, max int) (int, bool) {
	raw := r.URL.Query().Get("limit")
	if raw == "" {
		return def, true
	}
	n, err := strconv.Atoi(raw)
	if err != nil || n < 1 || n > max {
		WriteErrorWithDetails(w, r, http.StatusBadRequest, CodeInvalidRequest,
			fmt.Sprintf("limit must be between 1 and %d", max),
			[]errorDetail{{Field: "limit", Issue: fmt.Sprintf("must be between 1 and %d", max)}})
		return 0, false
	}
	return n, true
}

// fail maps domain/persistence failures to the error envelope. Unexpected
// errors are logged but never leak internals to clients.
func (h *ResearchHandlers) fail(w http.ResponseWriter, r *http.Request, err error, action string) {
	h.Logger.Error("request failed", "action", action, "error", err,
		"request_id", RequestIDFrom(r.Context()))
	status := http.StatusInternalServerError
	code := CodeInternal
	msg := "internal error"
	if errors.Is(err, research.ErrInvalidInput) {
		status, code, msg = http.StatusBadRequest, CodeInvalidRequest, "invalid request"
	}
	WriteError(w, r, status, code, msg)
}
