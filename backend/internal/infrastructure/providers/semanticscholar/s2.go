// Package semanticscholar adapts the Semantic Scholar Graph API to Athena's
// normalized research model (ADR-0002). Window sync is query-driven: the bulk
// search endpoint requires a query, so callers pass seed topics in
// research.Window.Query.
package semanticscholar

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"net/url"
	"strconv"
	"strings"
	"time"

	"athena/backend/internal/domain/research"
	"athena/backend/internal/infrastructure/providers"
)

const (
	defaultBaseURL = "https://api.semanticscholar.org"
	Slug           = "semanticscholar"
	pageSize       = 500 // bulk search maximum

	fieldsParam = "paperId,title,abstract,year,publicationDate,venue,journal," +
		"publicationTypes,externalIds,isOpenAccess,openAccessPdf,citationCount," +
		"referenceCount,influentialCitationCount,fieldsOfStudy,authors.name,authors.authorId"
)

// Options configures the adapter.
type Options struct {
	APIKey  string             // recommended; raises rate limits
	MaxRPS  float64            // default 0.8 without a key
	BaseURL string             // override for tests
	Client  *providers.Fetcher // shared transport; constructed when nil
}

type Provider struct {
	fetch   *providers.Fetcher
	baseURL string
}

func New(opts Options) *Provider {
	if opts.BaseURL == "" {
		opts.BaseURL = defaultBaseURL
	}
	if opts.MaxRPS <= 0 {
		opts.MaxRPS = 0.8
	}
	interval := time.Duration(float64(time.Second) / opts.MaxRPS)
	fetch := opts.Client
	if fetch == nil {
		hdrs := map[string]string{}
		if opts.APIKey != "" {
			hdrs["x-api-key"] = opts.APIKey
		}
		fetch = providers.NewFetcher("athena/0.1 (research aggregator)", hdrs,
			providers.NewLimiter(interval), providers.NewBreaker(4, 2*time.Minute))
	}
	return &Provider{fetch: fetch, baseURL: strings.TrimRight(opts.BaseURL, "/")}
}

func (p *Provider) Slug() string { return Slug }

// Search runs a live relevance-ranked query against the Graph API's standard
// paper search endpoint. Independent of window ingestion.
func (p *Provider) Search(ctx context.Context, query string, limit int) ([]research.Paper, error) {
	query = strings.TrimSpace(query)
	if query == "" {
		return nil, fmt.Errorf("%w: s2 search needs a query", providers.ErrBadWindow)
	}
	if limit <= 0 {
		limit = 25
	}
	if limit > 100 {
		limit = 100 // single page maximum on the standard endpoint
	}

	q := url.Values{}
	q.Set("query", query)
	q.Set("fields", fieldsParam)
	q.Set("limit", strconv.Itoa(limit))

	raw, err := p.fetch.Get(ctx, Slug, p.baseURL+"/graph/v1/paper/search?"+q.Encode())
	if err != nil {
		return nil, err
	}

	var resp bulkResponseDTO
	if err := json.Unmarshal(raw, &resp); err != nil {
		return nil, fmt.Errorf("%w: s2 paper search: %v", providers.ErrSchemaDrift, err)
	}

	papers := make([]research.Paper, 0, len(resp.Data))
	for i := range resp.Data {
		paper, perr := p.normalize(&resp.Data[i])
		if perr != nil {
			continue // skip malformed records; live search must not fail wholesale
		}
		papers = append(papers, paper)
	}
	return papers, nil
}

// ---- wire format -----------------------------------------------------------

type externalIDsDTO struct {
	DOI    *string `json:"DOI"`
	Arxiv  *string `json:"ArXiv"`
	PubMed *string `json:"PubMed"`
	// CorpusId arrives as a number or string depending on payload vintage.
	CorpusID flexString `json:"CorpusId"`
}

// flexString unmarshals JSON string-or-number values.
type flexString struct{ s string }

func (f *flexString) UnmarshalJSON(b []byte) error {
	b = trimSpaceBytes(b)
	if len(b) == 0 || string(b) == "null" {
		f.s = ""
		return nil
	}
	if b[0] == '"' {
		var s string
		if err := json.Unmarshal(b, &s); err != nil {
			return err
		}
		f.s = s
		return nil
	}
	f.s = string(b)
	return nil
}

func trimSpaceBytes(b []byte) []byte { return []byte(strings.TrimSpace(string(b))) }

func (f flexString) String() string { return f.s }

type journalDTO struct {
	Name string `json:"name"`
}

type authorDTO struct {
	AuthorID string `json:"authorId"`
	Name     string `json:"name"`
}

type paperDTO struct {
	PaperID          string         `json:"paperId"`
	Title            string         `json:"title"`
	Abstract         *string        `json:"abstract"`
	Year             int            `json:"year"`
	PublicationDate  string         `json:"publicationDate"`
	Venue            string         `json:"venue"`
	Journal          *journalDTO    `json:"journal"`
	PublicationTypes []string       `json:"publicationTypes"`
	ExternalIDs      externalIDsDTO `json:"externalIds"`
	IsOpenAccess     bool           `json:"isOpenAccess"`
	OpenAccessPDF    *struct {
		URL string `json:"url"`
	} `json:"openAccessPdf"`
	CitationCount    int      `json:"citationCount"`
	ReferenceCount   int      `json:"referenceCount"`
	InfluentialCount int      `json:"influentialCitationCount"`
	FieldsOfStudy    []string `json:"fieldsOfStudy"`
	Authors          []authorDTO `json:"authors"`
}

type bulkResponseDTO struct {
	Total int        `json:"total"`
	Token string     `json:"token"`
	Data  []paperDTO `json:"data"`
}

// ---- port implementation ---------------------------------------------------

func (p *Provider) FetchWindow(ctx context.Context, w research.Window) (research.Page, error) {
	if w.From.IsZero() || w.To.IsZero() || w.To.Before(w.From) {
		return research.Page{}, fmt.Errorf("%w: s2 sync needs from<=to", providers.ErrBadWindow)
	}
	if strings.TrimSpace(w.Query) == "" {
		return research.Page{}, fmt.Errorf("%w: s2 bulk search requires a seed query", providers.ErrBadWindow)
	}

	q := url.Values{}
	q.Set("query", w.Query)
	q.Set("fields", fieldsParam)
	q.Set("limit", fmt.Sprintf("%d", pageSize))
	q.Set("sort", "publicationDate:asc")
	q.Set("publicationDateOrYear", fmt.Sprintf("%s:%s",
		w.From.Format("2006-01-02"), w.To.Format("2006-01-02")))
	if w.Cursor != "" {
		q.Set("token", w.Cursor)
	}

	raw, err := p.fetch.Get(ctx, Slug, p.baseURL+"/graph/v1/paper/search/bulk?"+q.Encode())
	if err != nil {
		return research.Page{}, err
	}

	var resp bulkResponseDTO
	if err := json.Unmarshal(raw, &resp); err != nil {
		return research.Page{}, fmt.Errorf("%w: s2 bulk search: %v", providers.ErrSchemaDrift, err)
	}

	page := research.Page{Papers: make([]research.Paper, 0, len(resp.Data))}
	for i := range resp.Data {
		paper, perr := p.normalize(&resp.Data[i])
		if perr != nil {
			return page, perr
		}
		page.Papers = append(page.Papers, paper)
	}
	// An absent/empty continuation token terminates the window.
	if resp.Token != "" {
		page.NextCursor = resp.Token
	}
	return page, nil
}

func (p *Provider) normalize(dto *paperDTO) (research.Paper, error) {
	title := strings.TrimSpace(dto.Title)
	if title == "" || strings.TrimSpace(dto.PaperID) == "" {
		return research.Paper{}, fmt.Errorf("%w: s2 paper %q lacks id/title", providers.ErrSchemaDrift, dto.PaperID)
	}

	paper := research.Paper{
		Title:        title,
		Year:         dto.Year,
		VenueName:    firstNonEmpty(strings.TrimSpace(dto.Venue), venueFromJournal(dto.Journal)),
		VenueType:    venueKind(dto.Venue),
		PubType:      mapPubTypes(dto.PublicationTypes),
		Abstract:     strings.TrimSpace(deref(dto.Abstract)),
		CitedByCount: dto.CitationCount,
	}

	if d := parseDate(dto.PublicationDate); d != nil {
		paper.PublishedOn = d
		if paper.Year == 0 {
			paper.Year = d.Year()
		}
	} else if dto.Year > 0 {
		t := time.Date(dto.Year, 1, 1, 0, 0, 0, 0, time.UTC)
		paper.PublishedOn = &t
	}

	identifiers := []research.Identifier{{Type: research.IDTypeSemanticScholar, Value: dto.PaperID}}
	addID := func(t research.IdentifierType, v *string, canon func(string) string) {
		if v == nil || strings.TrimSpace(*v) == "" {
			return
		}
		val := strings.TrimSpace(*v)
		if canon != nil {
			val = canon(val)
			if val == "" {
				return
			}
		}
		identifiers = append(identifiers, research.Identifier{Type: t, Value: val})
	}
	addID(research.IDTypeDOI, dto.ExternalIDs.DOI, research.CanonicalizeDOI)
	addID(research.IDTypeArxiv, dto.ExternalIDs.Arxiv, research.CanonicalizeArxivID)
	addID(research.IDTypePubMed, dto.ExternalIDs.PubMed, nil)
	if v := dto.ExternalIDs.CorpusID.String(); v != "" {
		identifiers = append(identifiers, research.Identifier{Type: research.IDTypeCorpusID, Value: v})
	}
	paper.Identifiers = identifiers

	if v := paper.ArxivID(); v != "" {
		paper.Versions = append(paper.Versions, research.VersionRef{
			Kind: research.VersionPreprint, URL: "https://arxiv.org/abs/" + v, ArxivID: v,
		})
	}
	if dto.OpenAccessPDF != nil && strings.TrimSpace(dto.OpenAccessPDF.URL) != "" {
		paper.Versions = append(paper.Versions, research.VersionRef{
			Kind: research.VersionOther, URL: strings.TrimSpace(dto.OpenAccessPDF.URL),
		})
	}

	switch {
	case dto.IsOpenAccess && dto.OpenAccessPDF != nil && dto.OpenAccessPDF.URL != "":
		paper.OA = research.OpenAccess{Status: research.OAStatusGreen, URL: dto.OpenAccessPDF.URL}
	case !dto.IsOpenAccess:
		paper.OA = research.OpenAccess{Status: research.OAStatusClosed}
	default:
		paper.OA = research.OpenAccess{Status: research.OAStatusUnknown}
	}

	for pos, au := range dto.Authors {
		ref := research.AuthorRef{
			DisplayName: strings.TrimSpace(au.Name),
			Position:    pos + 1,
			ProviderIDs: map[research.IdentifierType]string{},
		}
		if au.AuthorID != "" {
			ref.ProviderIDs[research.IDTypeSemanticScholar] = au.AuthorID
		}
		paper.Authors = append(paper.Authors, ref)
	}

	for i, f := range dto.FieldsOfStudy {
		if strings.TrimSpace(f) == "" {
			continue
		}
		paper.Topics = append(paper.Topics, research.TopicRef{
			Name: strings.TrimSpace(f), Slug: topicSlug(f),
			Score: 1, IsPrimary: i == 0,
		})
	}

	sum := sha256.Sum256([]byte(fmt.Sprintf("%s|%s|%d|%d|%s|%s",
		dto.PaperID, title, dto.CitationCount, dto.ReferenceCount,
		dto.PublicationDate, deref(dto.Abstract))))
	paper.Provenance = research.Provenance{
		ProviderSlug:       Slug,
		NativeID:           dto.PaperID,
		FetchedAt:          time.Now().UTC(),
		PayloadFingerprint: hex.EncodeToString(sum[:]),
	}

	research.DeriveIdentity(&paper)
	return paper, nil
}

// mapPubTypes picks the most specific publication type: S2 papers often list
// several ("JournalArticle", "Review"), and generic labels must not mask
// specific ones.
func mapPubTypes(types []string) research.PublicationType {
	precedence := []research.PublicationType{
		research.PubTypeReview,
		research.PubTypeDataset,
		research.PubTypeBookChapter,
		research.PubTypeConferencePaper,
		research.PubTypePreprint,
	}
	present := map[research.PublicationType]bool{}
	for _, t := range types {
		switch strings.ToLower(strings.TrimSpace(t)) {
		case "review":
			present[research.PubTypeReview] = true
		case "journalarticle":
			present[research.PubTypeArticle] = true
		case "conference":
			present[research.PubTypeConferencePaper] = true
		case "preprint":
			present[research.PubTypePreprint] = true
		case "dataset", "datapaper":
			present[research.PubTypeDataset] = true
		case "bookchapter":
			present[research.PubTypeBookChapter] = true
		}
	}
	for _, pt := range precedence {
		if present[pt] {
			return pt
		}
	}
	return research.PubTypeArticle
}

func venueFromJournal(j *journalDTO) string {
	if j != nil {
		return strings.TrimSpace(j.Name)
	}
	return ""
}

func venueKind(venue string) string {
	v := strings.ToLower(venue)
	switch {
	case strings.Contains(v, "arxiv"):
		return "repository"
	case strings.Contains(v, "conf"), strings.Contains(v, "proceedings"):
		return "conference"
	default:
		return ""
	}
}

func topicSlug(name string) string {
	return strings.ReplaceAll(research.NormalizeTitle(name), " ", "-")
}

func parseDate(s string) *time.Time {
	if s == "" {
		return nil
	}
	t, err := time.Parse("2006-01-02", s)
	if err != nil {
		return nil
	}
	return &t
}

func deref(s *string) string {
	if s == nil {
		return ""
	}
	return *s
}

func firstNonEmpty(vals ...string) string {
	for _, v := range vals {
		if v != "" {
			return v
		}
	}
	return ""
}
