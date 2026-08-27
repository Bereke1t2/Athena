// Package search defines the query-model and engine port for discovery
// (ADR-0005). The domain stays engine-agnostic: Phase 2 ships a Postgres FTS
// implementation; semantic/hybrid modes arrive with embeddings in Phase 4.
package search

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"

	"athena/backend/internal/domain/research"
)

// UUID aliases the canonical UUID type so engine implementations need not
// import google/uuid directly in signatures.
type UUID = uuid.UUID

// Errors surfaced by query validation.
var (
	ErrInvalidQuery = errors.New("search: invalid query")
	ErrNotFound     = errors.New("search: not found")
)

// Mode selects the retrieval strategy. Semantic/hybrid are accepted but fall
// back to keyword until embeddings exist (Phase 4).
type Mode string

const (
	ModeAuto    Mode = "auto"
	ModeKeyword Mode = "keyword"
	ModeSemantic Mode = "semantic"
	ModeHybrid  Mode = "hybrid"
)

// Sort enumerates whitelisted search orderings.
type Sort string

const (
	SortRelevance Sort = "relevance"
	SortNewest    Sort = "newest"
	SortCitations Sort = "citations"
)

// Query is a validated search request. Use NewQuery to build one; zero-value
// defaults apply (mode=auto, sort=relevance, limit=20).
type Query struct {
	Q          string
	Mode       Mode
	TopicSlug  string
	FieldSlug  string
	SourceSlug string

	PublishedAfter  *time.Time
	PublishedBefore *time.Time
	OpenAccess      *bool
	MinCitations    int

	Sort   Sort
	Cursor string
	Limit  int
}

// NewQuery applies defaults and validates user-supplied fields. Unknown
// values are rejected, never silently ignored (search.md §5).
func NewQuery(q string, mode Mode, sort Sort, limit int) (Query, error) {
	out := Query{Q: q, Mode: ModeAuto, Sort: SortRelevance, Limit: 20}
	if mode != "" {
		switch mode {
		case ModeAuto, ModeKeyword, ModeSemantic, ModeHybrid:
			out.Mode = mode
		default:
			return out, invalid("mode", string(mode))
		}
	}
	if sort != "" {
		switch sort {
		case SortRelevance, SortNewest, SortCitations:
			out.Sort = sort
		default:
			return out, invalid("sort", string(sort))
		}
	}
	if limit != 0 {
		if limit < 1 || limit > 100 {
			return out, invalid("limit", "must be between 1 and 100")
		}
		out.Limit = limit
	}
	return out, nil
}

func invalid(field, issue string) error {
	return fmt.Errorf("%w: %s %s", ErrInvalidQuery, field, issue)
}

// ScoredPaper pairs the public paper summary with its retrieval score.
type ScoredPaper struct {
	Score float64
	Paper research.PaperSummary
}

// ResultPage is one page of results plus search metadata per API spec.
type ResultPage struct {
	Items         []ScoredPaper
	NextCursor    string
	ModeUsed      Mode
	TookMS        int64
	TotalEstimate int64 // -1 when unknown
}

// Searcher isolates the retrieval engine (ADR-0005). Implemented by pgsearcher
// in Phase 2; hybrid fusion lands in Phase 4 behind the same interface.
type Searcher interface {
	Search(ctx context.Context, q Query) (ResultPage, error)
	Related(ctx context.Context, paperID UUID, limit int) ([]ScoredPaper, error)
}
