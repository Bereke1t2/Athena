package research

import (
	"context"
	"time"

	"github.com/google/uuid"
)

// PaperWriter is the ingestion-side port implemented by the persistence layer
// (infrastructure/database). Implementations must be safe to call twice with
// equivalent input: the second call is a no-op update, not a duplicate row.
type PaperWriter interface {
	UpsertPaper(ctx context.Context, p Paper) (UpsertResult, error)

	// ResolveCitationEdges links the paper to locally known references,
	// ignoring edges whose target is not yet ingested.
	ResolveCitationEdges(ctx context.Context, citingPaperID uuid.UUID, refs []Identifier) (int, error)
}

// SortOrder enumerates whitelisted list orderings.
type SortOrder string

const (
	SortNewest    SortOrder = "newest"
	SortCitations SortOrder = "citations"
)

// ListQuery is a validated read query for paper lists. Cursor is an opaque
// continuation token issued by the reader implementation.
type ListQuery struct {
	Sort            SortOrder
	Limit           int
	Cursor          string
	TopicSlug       string
	TopicSlugs      []string // OR-match; overrides TopicSlug when non-empty
	FieldSlug       string // parent field; matches its topics too
	SourceSlug      string
	OpenAccess      *bool
	PublishedAfter  *time.Time
	PublishedBefore *time.Time
}

// CitationDirection selects traversal side of citation edges.
type CitationDirection string

const (
	CitedBy     CitationDirection = "in"  // papers citing this one
	References  CitationDirection = "out" // papers this one cites
)

// PaperSummary is the compact projection used by lists and feeds.
type PaperSummary struct {
	ID              uuid.UUID
	Title           string
	Abstract        *string
	PublishedOn     *time.Time
	Year            int
	VenueName       string
	PublicationType PublicationType
	OAStatus        OAStatus
	IsOpenAccess    bool
	CitedByCount    int
}

// AuthorLine is display data for a paper's ordered authorship.
type AuthorLine struct {
	ID          uuid.UUID
	Name        string
	ORCID       string
	Affiliation []string
}

// TopicLine is display data for a paper's topic assignment.
type TopicLine struct {
	Slug      string
	Name      string
	Score     float64
	IsPrimary bool
}

// VersionLine is display data for retrievable renditions.
type VersionLine struct {
	Kind   VersionKind
	URL    string
	IsPreprint bool
}

// PaperDetail is the full public projection of a stored paper.
type PaperDetail struct {
	Summary         PaperSummary
	Language        string
	License         string
	BestOAURL       string
	DOI             string
	ArxivID         string
	Authors         []AuthorLine
	Topics          []TopicLine
	Versions        []VersionLine
	ReferenceCount  int
	SourceSlugs     []string
	CreatedAt       time.Time
	UpdatedAt       time.Time
}

// PaperReader is the query-side port used by application services and HTTP
// handlers. Cursor semantics are owned by the implementation.
type PaperReader interface {
	GetDetailByID(ctx context.Context, id uuid.UUID) (PaperDetail, error)
	FindIDByIdentifier(ctx context.Context, t IdentifierType, value string) (uuid.UUID, error)
	ListPapers(ctx context.Context, q ListQuery) ([]PaperSummary, string, error)
	ListCitations(ctx context.Context, paperID uuid.UUID, dir CitationDirection, limit int) ([]PaperSummary, error)
	RelatedBySharedTopics(ctx context.Context, paperID uuid.UUID, limit int) ([]PaperSummary, error)
}
