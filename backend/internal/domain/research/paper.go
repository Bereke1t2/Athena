package research

import (
	"time"

	"github.com/google/uuid"
)

type IdentifierType string

const (
	IDTypeDOI             IdentifierType = "doi"
	IDTypeArxiv           IdentifierType = "arxiv"
	IDTypeSemanticScholar IdentifierType = "semantic_scholar"
	IDTypeOpenAlex        IdentifierType = "openalex"
	IDTypePubMed          IdentifierType = "pubmed"
	IDTypeCorpusID        IdentifierType = "corpus_id"
	IDTypeOther           IdentifierType = "other"
)

type OAStatus string

const (
	OAStatusGold    OAStatus = "gold"
	OAStatusGreen   OAStatus = "green"
	OAStatusHybrid  OAStatus = "hybrid"
	OAStatusBronze  OAStatus = "bronze"
	OAStatusClosed  OAStatus = "closed"
	OAStatusUnknown OAStatus = "unknown"
)

type PublicationType string

const (
	PubTypeArticle         PublicationType = "article"
	PubTypeReview          PublicationType = "review"
	PubTypePreprint        PublicationType = "preprint"
	PubTypeConferencePaper PublicationType = "conference_paper"
	PubTypeBookChapter     PublicationType = "book_chapter"
	PubTypeDataset         PublicationType = "dataset"
	PubTypeOther           PublicationType = "other"
)

type VersionKind string

const (
	VersionPreprint   VersionKind = "preprint"
	VersionPublisher  VersionKind = "publisher"
	VersionOther      VersionKind = "other"
)

// Identifier is one external identifier attached to a paper. The pair
// (Type, Value) is globally unique across Athena and forms the dedup spine.
type Identifier struct {
	Type  IdentifierType
	Value string
}

// AuthorRef is an author as seen on a specific paper.
type AuthorRef struct {
	DisplayName string
	ORCID       string
	Position    int // 1-based
	Affiliation []string
	ProviderIDs map[IdentifierType]string
}

// TopicRef associates a paper with a topic from the taxonomy.
type TopicRef struct {
	Name        string
	Slug        string
	Score       float64
	IsPrimary   bool
	ProviderKey string
}

// VersionRef points at a retrievable rendition of the paper.
type VersionRef struct {
	Kind        VersionKind
	URL         string
	DOI         string
	ArxivID     string
	PublishedOn *time.Time
	IsPrimary   bool
}

// Provenance records which provider contributed a normalized paper and how to
// recognize it again on re-sync.
type Provenance struct {
	ProviderSlug        string
	NativeID            string
	FetchedAt           time.Time
	PayloadFingerprint  string
}

// OpenAccess captures legal/access classification per ADR-0010.
type OpenAccess struct {
	Status OAStatus
	URL    string
	License string
}

func (o OpenAccess) IsOpen() bool {
	switch o.Status {
	case OAStatusGold, OAStatusGreen, OAStatusHybrid, OAStatusBronze:
		return true
	default:
		return false
	}
}

// Paper is Athena's canonical, provider-independent research model. Provider
// adapters produce it; nothing downstream may carry vendor-specific shapes.
type Paper struct {
	Title           string
	TitleNormalized string
	Fingerprint     string
	Abstract        string

	PublishedOn *time.Time
	Year        int

	VenueName string
	VenueType string
	PubType   PublicationType
	Language  string

	Identifiers []Identifier

	Authors []AuthorRef
	Topics  []TopicRef
	Versions []VersionRef

	OA              OpenAccess
	CitedByCount    int
	ReferenceCount  int
	ReferencedIDs   []Identifier
	Provenance      Provenance
}

// DOI returns the canonicalized DOI when present.
func (p Paper) DOI() string {
	return lookupIdentifier(p.Identifiers, IDTypeDOI)
}

// ArxivID returns the canonical arXiv base identifier when present.
func (p Paper) ArxivID() string {
	return lookupIdentifier(p.Identifiers, IDTypeArxiv)
}

func lookupIdentifier(ids []Identifier, t IdentifierType) string {
	for _, id := range ids {
		if id.Type == t {
			return id.Value
		}
	}
	return ""
}

// UpsertResult reports what the persistence layer did with a paper.
type UpsertResult struct {
	PaperID uuid.UUID
	Created bool

	// ContentChanged is false when an incoming record was byte-identical to
	// what was already stored (idempotent no-op).
	ContentChanged bool
}
