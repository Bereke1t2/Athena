// Package openalex adapts the OpenAlex REST API to Athena's normalized
// research model (ADR-0002). It owns pagination, polite-pool headers, and DTO
// translation; consumers see domain papers only.
package openalex

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"net/url"
	"sort"
	"strconv"
	"strings"
	"time"

	"athena/backend/internal/domain/research"
	"athena/backend/internal/infrastructure/providers"
)

const (
	defaultBaseURL = "https://api.openalex.org"
	pageSize       = 200

	// Slug is the provider slug used in sources.slug and job args.
	Slug = "openalex"
)

// Options configures the adapter.
type Options struct {
	Mailto  string             // polite-pool contact
	MaxRPS  float64            // default 8
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
		opts.MaxRPS = 8
	}
	interval := time.Duration(float64(time.Second) / opts.MaxRPS)
	fetch := opts.Client
	if fetch == nil {
		hdrs := map[string]string{}
		if opts.Mailto != "" {
			hdrs["From"] = opts.Mailto
		}
		fetch = providers.NewFetcher(politeUA(opts.Mailto), hdrs,
			providers.NewLimiter(interval), providers.NewBreaker(6, time.Minute))
	}
	return &Provider{fetch: fetch, baseURL: strings.TrimRight(opts.BaseURL, "/")}
}

func politeUA(mailto string) string {
	if mailto == "" {
		return "athena/0.1 (research aggregator)"
	}
	return fmt.Sprintf("athena/0.1 (mailto:%s)", mailto)
}

func (p *Provider) Slug() string { return Slug }

// Search runs a live relevance-ranked query against the OpenAlex works
// endpoint (the `search` parameter triggers relevance_score ordering by
// default). Independent of window ingestion.
func (p *Provider) Search(ctx context.Context, query string, limit int) ([]research.Paper, error) {
	query = strings.TrimSpace(query)
	if query == "" {
		return nil, fmt.Errorf("%w: openalex search needs a query", providers.ErrBadWindow)
	}
	if limit <= 0 {
		limit = 25
	}
	if limit > 100 {
		limit = 100
	}

	q := url.Values{}
	q.Set("search", query)
	q.Set("per-page", strconv.Itoa(limit))

	raw, err := p.fetch.Get(ctx, Slug, p.baseURL+"/works?"+q.Encode())
	if err != nil {
		return nil, err
	}

	var resp worksResponseDTO
	if err := json.Unmarshal(raw, &resp); err != nil {
		return nil, fmt.Errorf("%w: openalex works search: %v", providers.ErrSchemaDrift, err)
	}

	papers := make([]research.Paper, 0, len(resp.Results))
	for i := range resp.Results {
		paper, perr := p.normalize(&resp.Results[i])
		if perr != nil {
			continue // skip malformed records
		}
		papers = append(papers, paper)
	}
	return papers, nil
}

// ---- wire format -----------------------------------------------------------

type metaDTO struct {
	NextCursor *string `json:"next_cursor"`
}

type sourceDTO struct {
	DisplayName string `json:"display_name"`
	Type        string `json:"type"`
}

type locationDTO struct {
	LandingPageURL *string    `json:"landing_page_url"`
	PDFURL         *string    `json:"pdf_url"`
	License        *string    `json:"license"`
	Version        *string    `json:"version"`
	Source         *sourceDTO `json:"source"`
}

type openAccessDTO struct {
	IsOA   bool    `json:"is_oa"`
	Status string  `json:"oa_status"`
	OAURL  *string `json:"oa_url"`
}

type authorDTO struct {
	ID          string `json:"id"`
	DisplayName string `json:"display_name"`
	ORCID       string `json:"orcid"`
}

type authorshipDTO struct {
	AuthorPosition string      `json:"author_position"`
	Author         authorDTO   `json:"author"`
	Institutions   []sourceDTO `json:"institutions"`
}

type topicDTO struct {
	ID          string  `json:"id"`
	DisplayName string  `json:"display_name"`
	Score       float64 `json:"score"`
}

type idsDTO struct {
	OpenAlex string  `json:"openalex"`
	DOI      *string `json:"doi"`
	Arxiv    *string `json:"arxiv"`
	Pubmed   *string `json:"pmid"`
}

type workDTO struct {
	ID              string           `json:"id"`
	DOI             *string          `json:"doi"`
	Title           string           `json:"title"`
	DisplayName     string           `json:"display_name"`
	PublicationDate string           `json:"publication_date"`
	PublicationYear int              `json:"publication_year"`
	Type            string           `json:"type"`
	Language        string           `json:"language"`
	OpenAccess      openAccessDTO    `json:"open_access"`
	PrimaryLocation *locationDTO     `json:"primary_location"`
	BestOALocation  *locationDTO     `json:"best_oa_location"`
	Locations       []locationDTO    `json:"locations"`
	Authorships     []authorshipDTO  `json:"authorships"`
	Topics          []topicDTO       `json:"topics"`
	IDs             idsDTO           `json:"ids"`
	CitedByCount    int              `json:"cited_by_count"`
	ReferencedCount int              `json:"referenced_works_count"`
	ReferencedWorks []string         `json:"referenced_works"`
	AbstractInvIdx  map[string][]int `json:"abstract_inverted_index"`
}

type worksResponseDTO struct {
	Meta    metaDTO   `json:"meta"`
	Results []workDTO `json:"results"`
}

// ---- port implementation ---------------------------------------------------

func (p *Provider) FetchWindow(ctx context.Context, w research.Window) (research.Page, error) {
	if w.From.IsZero() || w.To.IsZero() || w.To.Before(w.From) {
		return research.Page{}, fmt.Errorf("%w: openalex sync needs from<=to", providers.ErrBadWindow)
	}

	cursor := w.Cursor
	if cursor == "" {
		cursor = "*"
	}

	filter := fmt.Sprintf("from_publication_date:%s,to_publication_date:%s",
		w.From.Format("2006-01-02"), w.To.Format("2006-01-02"))
	if w.Query != "" {
		filter += ",title_and_abstract.search:" + w.Query
	}
	q := url.Values{}
	q.Set("cursor", cursor)
	q.Set("per-page", fmt.Sprintf("%d", pageSize))
	// display_name breaks ties within equal publication dates: cursor
	// pagination over a non-unique sort key yields unstable page boundaries,
	// which fragments window coverage across runs.
	q.Set("sort", "publication_date:asc,display_name:asc")
	q.Set("filter", filter)

	raw, err := p.fetch.Get(ctx, Slug, p.baseURL+"/works?"+q.Encode())
	if err != nil {
		return research.Page{}, err
	}

	var resp worksResponseDTO
	if err := json.Unmarshal(raw, &resp); err != nil {
		return research.Page{}, fmt.Errorf("%w: openalex works: %v", providers.ErrSchemaDrift, err)
	}

	page := research.Page{Papers: make([]research.Paper, 0, len(resp.Results))}
	for i := range resp.Results {
		paper, perr := p.normalize(&resp.Results[i])
		if perr != nil {
			// Individual malformed records are skipped: one sparse record
			// must not poison the whole page (and retry-loop the window).
			// Structural failures (bad JSON, missing results array) still
			// surface as ErrSchemaDrift above.
			continue
		}
		page.Papers = append(page.Papers, paper)
	}
	if resp.Meta.NextCursor != nil && *resp.Meta.NextCursor != "" {
		page.NextCursor = *resp.Meta.NextCursor
	}
	return page, nil
}

// normalize translates one wire record into the canonical model.
func (p *Provider) normalize(dto *workDTO) (research.Paper, error) {
	title := collapseWS(firstNonEmpty(dto.Title, dto.DisplayName))
	if title == "" || strings.TrimSpace(dto.ID) == "" {
		return research.Paper{}, fmt.Errorf("%w: openalex work %q lacks id/title", providers.ErrSchemaDrift, dto.ID)
	}

	paper := research.Paper{
		Title:           title,
		Year:            dto.PublicationYear,
		VenueName:       venueName(dto.PrimaryLocation),
		VenueType:       venueType(dto.PrimaryLocation),
		PubType:         mapPubType(dto.Type),
		Language:        dto.Language,
		CitedByCount:    dto.CitedByCount,
		ReferenceCount:  dto.ReferencedCount,
	}

	if d := parseDate(dto.PublicationDate); d != nil {
		paper.PublishedOn = d
	} else if dto.PublicationYear > 0 {
		t := time.Date(dto.PublicationYear, 1, 1, 0, 0, 0, 0, time.UTC)
		paper.PublishedOn = &t
	}
	if paper.Year == 0 && paper.PublishedOn != nil {
		paper.Year = paper.PublishedOn.Year()
	}

	// Abstracts arrive as an inverted word-position index.
	paper.Abstract = rebuildAbstract(dto.AbstractInvIdx)

	identifiers := []research.Identifier{{Type: research.IDTypeOpenAlex, Value: nativeID(dto.ID)}}
	if dto.DOI != nil && *dto.DOI != "" {
		if v := research.CanonicalizeDOI(*dto.DOI); v != "" {
			identifiers = append(identifiers, research.Identifier{Type: research.IDTypeDOI, Value: v})
		}
	}
	if dto.IDs.Arxiv != nil && *dto.IDs.Arxiv != "" {
		if v := research.CanonicalizeArxivID(*dto.IDs.Arxiv); v != "" {
			identifiers = append(identifiers, research.Identifier{Type: research.IDTypeArxiv, Value: v})
			paper.Versions = append(paper.Versions, research.VersionRef{
				Kind: research.VersionPreprint, URL: "https://arxiv.org/abs/" + v, ArxivID: v,
			})
		}
	}
	if dto.IDs.Pubmed != nil && *dto.IDs.Pubmed != "" {
		identifiers = append(identifiers, research.Identifier{
			Type: research.IDTypePubMed, Value: strings.TrimSpace(*dto.IDs.Pubmed)})
	}
	for _, rw := range dto.ReferencedWorks {
		if v := nativeID(rw); v != "" {
			paper.ReferencedIDs = append(paper.ReferencedIDs,
				research.Identifier{Type: research.IDTypeOpenAlex, Value: v})
		}
	}
	paper.Identifiers = identifiers

	for pos, au := range dto.Authorships {
		ref := research.AuthorRef{
			DisplayName: strings.TrimSpace(au.Author.DisplayName),
			Position:    pos + 1,
			ProviderIDs: map[research.IdentifierType]string{},
		}
		ref.ORCID = strings.TrimPrefix(strings.TrimSpace(au.Author.ORCID), "https://orcid.org/")
		for _, inst := range au.Institutions {
			if inst.DisplayName != "" {
				ref.Affiliation = append(ref.Affiliation, inst.DisplayName)
			}
		}
		if au.Author.ID != "" {
			ref.ProviderIDs[research.IDTypeOpenAlex] = nativeID(au.Author.ID)
		}
		paper.Authors = append(paper.Authors, ref)
	}

	for i, t := range dto.Topics {
		if t.DisplayName == "" {
			continue
		}
		paper.Topics = append(paper.Topics, research.TopicRef{
			Name: t.DisplayName, Slug: topicSlug(t.DisplayName),
			Score: t.Score, IsPrimary: i == 0, ProviderKey: nativeID(t.ID),
		})
	}

	paper.OA = mapOpenAccess(dto)
	paper.Versions = append(paper.Versions, versionsFromLocations(dto)...)

	fpSrc, _ := json.Marshal(dto)
	sum := sha256.Sum256(fpSrc)
	paper.Provenance = research.Provenance{
		ProviderSlug:       Slug,
		NativeID:           nativeID(dto.ID),
		FetchedAt:          time.Now().UTC(),
		PayloadFingerprint: hex.EncodeToString(sum[:]),
	}

	research.DeriveIdentity(&paper)
	return paper, nil
}

func mapOpenAccess(dto *workDTO) research.OpenAccess {
	oa := research.OpenAccess{Status: research.OAStatusUnknown}
	switch dto.OpenAccess.Status {
	case "gold", "green", "hybrid", "bronze", "closed":
		oa.Status = research.OAStatus(dto.OpenAccess.Status)
	}
	if dto.BestOALocation != nil {
		if dto.BestOALocation.PDFURL != nil {
			oa.URL = strings.TrimSpace(*dto.BestOALocation.PDFURL)
		} else if dto.BestOALocation.LandingPageURL != nil {
			oa.URL = strings.TrimSpace(*dto.BestOALocation.LandingPageURL)
		}
		if dto.BestOALocation.License != nil {
			oa.License = strings.TrimSpace(*dto.BestOALocation.License)
		}
	}
	if oa.URL == "" && dto.OpenAccess.OAURL != nil {
		oa.URL = strings.TrimSpace(*dto.OpenAccess.OAURL)
	}
	if oa.Status == research.OAStatusUnknown && dto.OpenAccess.IsOA {
		if oa.URL != "" {
			oa.Status = research.OAStatusGreen
		}
	}
	return oa
}

func versionsFromLocations(dto *workDTO) []research.VersionRef {
	var out []research.VersionRef
	seen := map[string]bool{}
	add := func(kind research.VersionKind, u string) {
		u = strings.TrimSpace(u)
		if u == "" || seen[u] || len(out) >= 4 {
			return
		}
		seen[u] = true
		out = append(out, research.VersionRef{Kind: kind, URL: u})
	}
	if dto.PrimaryLocation != nil && dto.PrimaryLocation.Source != nil &&
		dto.PrimaryLocation.Source.Type == "journal" && dto.PrimaryLocation.LandingPageURL != nil {
		add(research.VersionPublisher, *dto.PrimaryLocation.LandingPageURL)
	}
	if dto.BestOALocation != nil && dto.BestOALocation.PDFURL != nil {
		add(research.VersionOther, *dto.BestOALocation.PDFURL)
	}
	return out
}

func rebuildAbstract(inv map[string][]int) string {
	if len(inv) == 0 {
		return ""
	}
	type pair struct {
		pos int
		w   string
	}
	pairs := make([]pair, 0, 256)
	for word, positions := range inv {
		for _, pos := range positions {
			pairs = append(pairs, pair{pos, word})
		}
	}
	sort.Slice(pairs, func(i, j int) bool { return pairs[i].pos < pairs[j].pos })
	b := strings.Builder{}
	for i, pr := range pairs {
		if i > 0 {
			b.WriteByte(' ')
		}
		b.WriteString(pr.w)
	}
	return b.String()
}

func mapPubType(t string) research.PublicationType {
	switch strings.ToLower(strings.TrimSpace(t)) {
	case "article":
		return research.PubTypeArticle
	case "review":
		return research.PubTypeReview
	case "preprint":
		return research.PubTypePreprint
	case "dataset":
		return research.PubTypeDataset
	case "book-chapter":
		return research.PubTypeBookChapter
	default:
		return research.PubTypeOther
	}
}

func venueName(loc *locationDTO) string {
	if loc != nil && loc.Source != nil {
		return strings.TrimSpace(loc.Source.DisplayName)
	}
	return ""
}

func venueType(loc *locationDTO) string {
	if loc != nil && loc.Source != nil {
		switch strings.ToLower(loc.Source.Type) {
		case "journal":
			return "journal"
		case "repository":
			return "repository"
		case "conference":
			return "conference"
		case "publisher":
			return "publisher"
		}
	}
	return ""
}

func nativeID(u string) string {
	if i := strings.LastIndex(u, "/"); i >= 0 && i+1 < len(u) {
		return u[i+1:]
	}
	return strings.TrimSpace(u)
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

func firstNonEmpty(vals ...string) string {
	for _, v := range vals {
		if strings.TrimSpace(v) != "" {
			return v
		}
	}
	return ""
}

// collapseWS flattens the newlines/indentation embedded in provider text.
func collapseWS(s string) string {
	return strings.Join(strings.Fields(s), " ")
}
