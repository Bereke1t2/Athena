// Package arxiv adapts the arXiv Atom search API to Athena's normalized
// research model (ADR-0002). arXiv is metadata-only for citation counts and
// enforces a courtesy request interval, which the shared Fetcher honors.
package arxiv

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/xml"
	"fmt"
	"net/url"
	"strconv"
	"strings"
	"time"

	"athena/backend/internal/domain/research"
	"athena/backend/internal/infrastructure/providers"
)

const (
	defaultBaseURL = "https://export.arxiv.org"
	Slug           = "arxiv"
	pageSize       = 100

	atomNS    = "http://www.w3.org/2005/Atom"
	opensearchNS = "http://a9.com/-/spec/opensearch/1.1/"
	arxivNS   = "http://arxiv.org/schemas/atom"
)

// Options configures the adapter.
type Options struct {
	UserAgent   string             // required by arXiv etiquette
	MinInterval time.Duration      // default 3s between requests
	BaseURL     string             // override for tests
	Client      *providers.Fetcher // shared transport; constructed when nil
}

type Provider struct {
	fetch   *providers.Fetcher
	baseURL string
}

func New(opts Options) *Provider {
	if opts.BaseURL == "" {
		opts.BaseURL = defaultBaseURL
	}
	if opts.MinInterval <= 0 {
		opts.MinInterval = 3 * time.Second
	}
	fetch := opts.Client
	if fetch == nil {
		fetch = providers.NewFetcher(opts.UserAgent, nil,
			providers.NewLimiter(opts.MinInterval), providers.NewBreaker(4, time.Minute))
	}
	return &Provider{fetch: fetch, baseURL: strings.TrimRight(opts.BaseURL, "/")}
}

func (p *Provider) Slug() string { return Slug }

// Search runs a live relevance-ranked query against the arXiv Atom API.
// It is independent of window ingestion: callers get normalized papers
// directly, without persisting anything.
func (p *Provider) Search(ctx context.Context, query string, limit int) ([]research.Paper, error) {
	query = strings.TrimSpace(query)
	if query == "" {
		return nil, fmt.Errorf("%w: arxiv search needs a query", providers.ErrBadWindow)
	}
	if limit <= 0 {
		limit = 25
	}
	if limit > 100 {
		limit = 100
	}

	q := url.Values{}
	q.Set("search_query", `all:"`+strings.Join(strings.Fields(query), `" AND all:`)+`"`)
	q.Set("start", "0")
	q.Set("max_results", strconv.Itoa(limit))
	q.Set("sortBy", "relevance")
	q.Set("sortOrder", "descending")

	raw, err := p.fetch.Get(ctx, Slug, p.baseURL+"/api/query?"+q.Encode())
	if err != nil {
		return nil, err
	}
	feed, err := parseAtom(raw)
	if err != nil {
		return nil, err
	}

	papers := make([]research.Paper, 0, len(feed.Entries))
	for i := range feed.Entries {
		paper, perr := p.normalize(&feed.Entries[i])
		if perr != nil {
			continue // skip malformed entries
		}
		papers = append(papers, paper)
	}
	return papers, nil
}

// ---- wire format (Atom) ----------------------------------------------------

type feedDTO struct {
	XMLName  xml.Name    `xml:"http://www.w3.org/2005/Atom feed"`
	TotalRes int         `xml:"http://a9.com/-/spec/opensearch/1.1/ totalResults"`
	Entries  []entryDTO  `xml:"http://www.w3.org/2005/Atom entry"`
}

type entryDTO struct {
	ID        string     `xml:"id"`
	Updated   time.Time  `xml:"updated"`
	Published time.Time  `xml:"published"`
	Title     string     `xml:"title"`
	Summary   string     `xml:"summary"`
	Authors   []struct {
		Name string `xml:"name"`
	} `xml:"author"`
	Categories []categoryDTO `xml:"category"`
	Links      []linkDTO     `xml:"link"`
	Comment    *string       `xml:"http://arxiv.org/schemas/atom comment"`
	JournalRef *string       `xml:"http://arxiv.org/schemas/atom journal_ref"`
	DOI        *string       `xml:"http://arxiv.org/schemas/atom doi"`
	Primary    struct {
		Term string `xml:"term,attr"`
	} `xml:"http://arxiv.org/schemas/atom primary_category"`
}

type categoryDTO struct {
	Term string `xml:"term,attr"`
}

type linkDTO struct {
	Rel  string `xml:"rel,attr"`
	Href string `xml:"href,attr"`
	Type string `xml:"type,attr"`
}

// ---- port implementation ---------------------------------------------------

func (p *Provider) FetchWindow(ctx context.Context, w research.Window) (research.Page, error) {
	if w.From.IsZero() || w.To.IsZero() || w.To.Before(w.From) {
		return research.Page{}, fmt.Errorf("%w: arxiv sync needs from<=to", providers.ErrBadWindow)
	}

	start := 0
	if w.Cursor != "" {
		n, err := strconv.Atoi(w.Cursor)
		if err != nil || n < 0 {
			return research.Page{}, fmt.Errorf("%w: bad arxiv cursor %q", providers.ErrBadWindow, w.Cursor)
		}
		start = n
	}

	// submittedDate range uses minute precision: [YYYYMMDDHHMM TO YYYYMMDDHHMM].
	q := url.Values{}
	q.Set("search_query", fmt.Sprintf("submittedDate:[%s0000 TO %s2359]",
		w.From.Format("20060102"), w.To.Format("20060102")))
	if w.Query != "" {
		q.Set("search_query", fmt.Sprintf("all:%s AND submittedDate:[%s0000 TO %s2359]",
			w.Query, w.From.Format("20060102"), w.To.Format("20060102")))
	}
	q.Set("start", strconv.Itoa(start))
	q.Set("max_results", strconv.Itoa(pageSize))
	q.Set("sortBy", "submittedDate")
	q.Set("sortOrder", "ascending")

	raw, err := p.fetch.Get(ctx, Slug, p.baseURL+"/api/query?"+q.Encode())
	if err != nil {
		return research.Page{}, err
	}

	feed, err := parseAtom(raw)
	if err != nil {
		return research.Page{}, err
	}

	page := research.Page{Papers: make([]research.Paper, 0, len(feed.Entries))}
	for i := range feed.Entries {
		paper, perr := p.normalize(&feed.Entries[i])
		if perr != nil {
			continue // skip malformed entries; window continues
		}
		page.Papers = append(page.Papers, paper)
	}

	if next := start + len(feed.Entries); len(feed.Entries) > 0 && next < feed.TotalRes {
		page.NextCursor = strconv.Itoa(next)
	}
	return page, nil
}

// parseAtom decodes an Atom feed payload, mapping structural failures to
// ErrSchemaDrift.
func parseAtom(raw []byte) (feedDTO, error) {
	var feed feedDTO
	if err := xml.Unmarshal(raw, &feed); err != nil {
		return feedDTO{}, fmt.Errorf("%w: arxiv atom: %v", providers.ErrSchemaDrift, err)
	}
	return feed, nil
}

func (p *Provider) normalize(dto *entryDTO) (research.Paper, error) {
	title := collapseWS(dto.Title)
	rawID := strings.TrimSpace(dto.ID)
	if title == "" || rawID == "" {
		return research.Paper{}, fmt.Errorf("%w: arxiv entry %q lacks id/title", providers.ErrSchemaDrift, rawID)
	}

	arxivWithVersion := stripArxivPrefix(rawID) // e.g. 2401.12345v2
	baseID := research.CanonicalizeArxivID(arxivWithVersion)
	if baseID == "" {
		return research.Paper{}, fmt.Errorf("%w: unparseable arxiv id %q", providers.ErrSchemaDrift, rawID)
	}

	paper := research.Paper{
		Title:       title,
		PubType:     research.PubTypePreprint,
		VenueName:   "arXiv",
		VenueType:   "repository",
		Language:    "en",
		Abstract:    collapseWS(dto.Summary),
		PublishedOn: &dto.Published,
		Year:        dto.Published.Year(),
	}

	paper.Identifiers = []research.Identifier{
		{Type: research.IDTypeArxiv, Value: baseID},
	}
	if dto.DOI != nil && strings.TrimSpace(*dto.DOI) != "" {
		if v := research.CanonicalizeDOI(*dto.DOI); v != "" {
			paper.Identifiers = append(paper.Identifiers,
				research.Identifier{Type: research.IDTypeDOI, Value: v})
		}
	}

	paper.Versions = []research.VersionRef{{
		Kind: research.VersionPreprint,
		URL:  "https://arxiv.org/abs/" + baseID,
	}}
	for _, l := range dto.Links {
		if l.Type == "application/pdf" && strings.TrimSpace(l.Href) != "" {
			paper.Versions = append(paper.Versions, research.VersionRef{
				Kind: research.VersionPreprint, URL: strings.TrimSpace(l.Href),
			})
			paper.OA.URL = strings.TrimSpace(l.Href)
			break
		}
	}

	// arXiv distributes preprints under its own license terms; treat as green.
	paper.OA.Status = research.OAStatusGreen
	if paper.OA.URL == "" {
		paper.OA.URL = "https://arxiv.org/pdf/" + baseID
	}

	for pos, a := range dto.Authors {
		name := collapseWS(a.Name)
		if name == "" {
			continue
		}
		paper.Authors = append(paper.Authors, research.AuthorRef{
			DisplayName: name,
			Position:    len(paper.Authors) + 1,
			ProviderIDs: map[research.IdentifierType]string{},
		})
		_ = pos
	}

	addTopic := func(term string, primary bool) {
		term = strings.TrimSpace(term)
		if term == "" || len(paper.Topics) >= 6 {
			return
		}
		paper.Topics = append(paper.Topics, research.TopicRef{
			Name: term, Slug: topicSlug(term), Score: 1, IsPrimary: primary,
		})
	}
	addTopic(dto.Primary.Term, true)
	for _, c := range dto.Categories {
		addTopic(c.Term, false)
	}

	sum := sha256.Sum256([]byte(fmt.Sprintf("%s|%s|%s|%s",
		baseID, title, paper.Abstract, dto.Updated.Format(time.RFC3339))))
	paper.Provenance = research.Provenance{
		ProviderSlug:       Slug,
		NativeID:           baseID,
		FetchedAt:          time.Now().UTC(),
		PayloadFingerprint: hex.EncodeToString(sum[:]),
	}

	research.DeriveIdentity(&paper)
	return paper, nil
}

// stripArxivPrefix reduces "http://arxiv.org/abs/2401.12345v2" to "2401.12345v2".
func stripArxivPrefix(u string) string {
	u = strings.TrimSpace(u)
	if i := strings.LastIndex(u, "/"); i >= 0 {
		u = u[i+1:]
	}
	return u
}

func topicSlug(name string) string {
	s := research.NormalizeTitle(name)
	return strings.ReplaceAll(s, " ", "-")
}

// collapseWS flattens the newlines/indentation arXiv embeds in text fields.
func collapseWS(s string) string {
	return strings.Join(strings.Fields(s), " ")
}
