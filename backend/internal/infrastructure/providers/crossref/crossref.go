// Package crossref adapts the Crossref REST API to Athena's normalized
// research model (ADR-0002). Crossref requires no authentication; polite-pool
// etiquette is a Mailto contact plus a descriptive user agent.
package crossref

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"net/url"
	"regexp"
	"strings"
	"time"

	"athena/backend/internal/domain/research"
	"athena/backend/internal/infrastructure/providers"
)

const (
	defaultBaseURL = "https://api.crossref.org"
	Slug           = "crossref"
	pageSize       = 50

	selectFields = "DOI,title,abstract,issued,published-print,published-online," +
		"container-title,type,author,is-referenced-by-count,URL,subject"
)

// Options configures the adapter.
type Options struct {
	Mailto  string             // polite-pool contact
	MaxRPS  float64            // default 4
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
		opts.MaxRPS = 4
	}
	interval := time.Duration(float64(time.Second) / opts.MaxRPS)
	fetch := opts.Client
	if fetch == nil {
		hdrs := map[string]string{}
		if opts.Mailto != "" {
			hdrs["From"] = opts.Mailto
		}
		fetch = providers.NewFetcher(politeUA(opts.Mailto), hdrs,
			providers.NewLimiter(interval), providers.NewBreaker(5, time.Minute))
	}
	return &Provider{fetch: fetch, baseURL: strings.TrimRight(opts.BaseURL, "/")}
}

func politeUA(mailto string) string {
	if mailto == "" {
		return "athena/0.1 (research aggregator)"
	}
	return fmt.Sprintf("athena/0.1 (research aggregator; mailto:%s)", mailto)
}

func (p *Provider) Slug() string { return Slug }

// ---- wire format -----------------------------------------------------------

type dateDTO struct {
	DateParts [][]int `json:"date-parts"`
}

type authorDTO struct {
	Given  string `json:"given"`
	Family string `json:"family"`
	Name   string `json:"name"`
}

type itemDTO struct {
	DOI             string      `json:"DOI"`
	Title           []string    `json:"title"`
	Abstract        string      `json:"abstract"`
	Issued          dateDTO     `json:"issued"`
	PublishedPrint  dateDTO     `json:"published-print"`
	PublishedOnline dateDTO     `json:"published-online"`
	Container       []string    `json:"container-title"`
	Type            string      `json:"type"`
	Authors         []authorDTO `json:"author"`
	CitedByCount    int         `json:"is-referenced-by-count"`
	URL             string      `json:"URL"`
	Subjects        []string    `json:"subject"`
}

type messageDTO struct {
	Items []itemDTO `json:"items"`
	Total int       `json:"total-results"`
}

type responseDTO struct {
	Message messageDTO `json:"message"`
	Status  string     `json:"status"`
}

// Search runs a live relevance-ranked query against /works. Crossref's
// default ordering for `query` is relevance.
func (p *Provider) Search(ctx context.Context, query string, limit int) ([]research.Paper, error) {
	query = strings.TrimSpace(query)
	if query == "" {
		return nil, fmt.Errorf("%w: crossref search needs a query", providers.ErrBadWindow)
	}
	if limit <= 0 {
		limit = 25
	}
	if limit > pageSize {
		limit = pageSize
	}

	q := url.Values{}
	q.Set("query", query)
	q.Set("rows", fmt.Sprintf("%d", limit))
	q.Set("select", selectFields)

	raw, err := p.fetch.Get(ctx, Slug, p.baseURL+"/works?"+q.Encode())
	if err != nil {
		return nil, err
	}

	var resp responseDTO
	if err := json.Unmarshal(raw, &resp); err != nil {
		return nil, fmt.Errorf("%w: crossref works: %v", providers.ErrSchemaDrift, err)
	}

	papers := make([]research.Paper, 0, len(resp.Message.Items))
	for i := range resp.Message.Items {
		paper, perr := p.normalize(&resp.Message.Items[i])
		if perr != nil {
			continue // skip malformed records
		}
		papers = append(papers, paper)
	}
	return papers, nil
}

var jatsTags = regexp.MustCompile(`<[^>]*>`)

// normalize translates one Crossref record into the canonical model.
func (p *Provider) normalize(dto *itemDTO) (research.Paper, error) {
	title := collapseWS(firstString(dto.Title))
	doi := research.CanonicalizeDOI(dto.DOI)
	if title == "" || doi == "" {
		return research.Paper{}, fmt.Errorf("%w: crossref item %q lacks doi/title",
			providers.ErrSchemaDrift, dto.DOI)
	}

	paper := research.Paper{
		Title:        title,
		VenueName:    collapseWS(firstString(dto.Container)),
		PubType:      mapPubType(dto.Type),
		Language:     "en",
		Abstract:     stripJATS(dto.Abstract),
		CitedByCount: dto.CitedByCount,
	}

	if d := firstDate(dto.Issued, dto.PublishedOnline, dto.PublishedPrint); d != nil {
		paper.PublishedOn = d
		paper.Year = d.Year()
	}

	paper.Identifiers = []research.Identifier{
		{Type: research.IDTypeDOI, Value: doi},
	}
	if landing := strings.TrimSpace(dto.URL); landing != "" {
		paper.Versions = append(paper.Versions, research.VersionRef{
			Kind: research.VersionPublisher, URL: landing,
		})
	}

	for pos, au := range dto.Authors {
		name := strings.TrimSpace(au.Name)
		if name == "" {
			name = strings.TrimSpace(strings.Trim(au.Given+" "+au.Family, " "))
		}
		if name == "" {
			continue
		}
		paper.Authors = append(paper.Authors, research.AuthorRef{
			DisplayName: name,
			Position:    pos + 1,
			ProviderIDs: map[research.IdentifierType]string{},
		})
	}

	addTopic := func(s string) {
		s = strings.TrimSpace(s)
		if s == "" || len(paper.Topics) >= 6 {
			return
		}
		paper.Topics = append(paper.Topics, research.TopicRef{
			Name: s, Slug: strings.ReplaceAll(research.NormalizeTitle(s), " ", "-"),
			Score: 1, IsPrimary: len(paper.Topics) == 0,
		})
	}
	for _, s := range dto.Subjects {
		addTopic(s)
	}

	sum := sha256.Sum256([]byte(fmt.Sprintf("%s|%s|%d|%s",
		doi, title, dto.CitedByCount, paper.Abstract)))
	paper.Provenance = research.Provenance{
		ProviderSlug:       Slug,
		NativeID:           doi,
		FetchedAt:          time.Now().UTC(),
		PayloadFingerprint: hex.EncodeToString(sum[:]),
	}

	research.DeriveIdentity(&paper)
	return paper, nil
}

func mapPubType(t string) research.PublicationType {
	switch strings.ToLower(strings.TrimSpace(t)) {
	case "journal-article":
		return research.PubTypeArticle
	case "proceedings-article":
		return research.PubTypeConferencePaper
	case "book-chapter":
		return research.PubTypeBookChapter
	case "peer-review":
		return research.PubTypeReview
	case "dataset":
		return research.PubTypeDataset
	case "posted-content":
		return research.PubTypePreprint
	default:
		return research.PubTypeOther
	}
}

// stripJATS removes the JATS/XML markup Crossref embeds in abstracts and
// collapses whitespace.
func stripJATS(s string) string {
	if s == "" {
		return ""
	}
	return collapseWS(jatsTags.ReplaceAllString(s, " "))
}

func firstDate(candidates ...dateDTO) *time.Time {
	for _, c := range candidates {
		if len(c.DateParts) == 0 || len(c.DateParts[0]) == 0 {
			continue
		}
		parts := c.DateParts[0]
		year, month, day := parts[0], 1, 1
		if len(parts) > 1 && parts[1] >= 1 && parts[1] <= 12 {
			month = parts[1]
		}
		if len(parts) > 2 && parts[2] >= 1 && parts[2] <= 31 {
			day = parts[2]
		}
		t := time.Date(year, time.Month(month), day, 0, 0, 0, 0, time.UTC)
		return &t
	}
	return nil
}

func firstString(vals []string) string {
	for _, v := range vals {
		if strings.TrimSpace(v) != "" {
			return v
		}
	}
	return ""
}

func collapseWS(s string) string {
	return strings.Join(strings.Fields(s), " ")
}
