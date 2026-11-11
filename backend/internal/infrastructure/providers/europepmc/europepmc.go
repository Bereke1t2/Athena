package europepmc

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"html"
	"net/url"
	"regexp"
	"strconv"
	"strings"
	"time"

	"athena/backend/internal/domain/research"
	"athena/backend/internal/infrastructure/providers"
)

const (
	defaultBaseURL = "https://www.ebi.ac.uk/europepmc/webservices/rest"
	Slug           = "europepmc"
	pageSize       = 25
)

// Options configures the Europe PMC adapter.
type Options struct {
	Email   string             // polite-pool contact
	MaxRPS  float64            // default 5
	BaseURL string             // override for tests
	Client  *providers.Fetcher // shared transport; constructed when nil
}

type Provider struct {
	fetch   *providers.Fetcher
	baseURL string
	email   string
}

// New constructs an operational Europe PMC research provider.
func New(opts Options) *Provider {
	if opts.BaseURL == "" {
		opts.BaseURL = defaultBaseURL
	}
	if opts.MaxRPS <= 0 {
		opts.MaxRPS = 5
	}
	interval := time.Duration(float64(time.Second) / opts.MaxRPS)
	fetch := opts.Client
	if fetch == nil {
		hdrs := map[string]string{}
		if opts.Email != "" {
			hdrs["From"] = opts.Email
		}
		fetch = providers.NewFetcher(politeUA(opts.Email), hdrs,
			providers.NewLimiter(interval), providers.NewBreaker(5, time.Minute))
	}
	return &Provider{
		fetch:   fetch,
		baseURL: strings.TrimRight(opts.BaseURL, "/"),
		email:   opts.Email,
	}
}

func politeUA(email string) string {
	if email == "" {
		return "athena/0.1 (research aggregator)"
	}
	return fmt.Sprintf("athena/0.1 (research aggregator; mailto:%s)", email)
}

func (p *Provider) Slug() string { return Slug }

// ---- wire format (Europe PMC REST JSON) -----------------------------------

type authorDTO struct {
	FullName  string `json:"fullName"`
	FirstName string `json:"firstName"`
	LastName  string `json:"lastName"`
	Initials  string `json:"initials"`
	AuthorID  *struct {
		Type string `json:"@type"`
		Text string `json:"#text"`
	} `json:"authorId"`
}

type fullTextURLDTO struct {
	Availability     string `json:"availability"`
	AvailabilityCode string `json:"availabilityCode"`
	DocumentStyle    string `json:"documentStyle"`
	Site             string `json:"site"`
	URL              string `json:"url"`
}

type meshHeadingDTO struct {
	DescriptorName string `json:"descriptorName"`
}

type resultDTO struct {
	ID           string `json:"id"`
	Source       string `json:"source"`
	PMID         string `json:"pmid"`
	PMCID        string `json:"pmcid"`
	DOI          string `json:"doi"`
	Title        string `json:"title"`
	AuthorString string `json:"authorString"`
	AuthorList   *struct {
		Author []authorDTO `json:"author"`
	} `json:"authorList"`
	JournalInfo *struct {
		Journal *struct {
			Title string `json:"title"`
		} `json:"journal"`
		YearOfPublication int    `json:"yearOfPublication"`
		DateOfPublication string `json:"dateOfPublication"`
	} `json:"journalInfo"`
	PubYear              string `json:"pubYear"`
	FirstPublicationDate string `json:"firstPublicationDate"`
	AbstractText         string `json:"abstractText"`
	IsOpenAccess         string `json:"isOpenAccess"`
	InEPMC               string `json:"inEPMC"`
	InPMC                string `json:"inPMC"`
	HasPDF               string `json:"hasPDF"`
	CitedByCount         int    `json:"citedByCount"`
	FullTextURLList      *struct {
		FullTextURL []fullTextURLDTO `json:"fullTextUrl"`
	} `json:"fullTextUrlList"`
	KeywordList *struct {
		Keyword []string `json:"keyword"`
	} `json:"keywordList"`
	MeshHeadingList *struct {
		MeshHeading []meshHeadingDTO `json:"meshHeading"`
	} `json:"meshHeadingList"`
	PubTypeList *struct {
		PubType []string `json:"pubType"`
	} `json:"pubTypeList"`
}

type responseDTO struct {
	HitCount       int    `json:"hitCount"`
	NextCursorMark string `json:"nextCursorMark"`
	ResultList     struct {
		Result []resultDTO `json:"result"`
	} `json:"resultList"`
}

var htmlTagRe = regexp.MustCompile(`<[^>]*>`)

func stripHTML(s string) string {
	if s == "" {
		return ""
	}
	stripped := htmlTagRe.ReplaceAllString(s, " ")
	return collapseWS(html.UnescapeString(stripped))
}

func collapseWS(s string) string {
	return strings.Join(strings.Fields(s), " ")
}

func parsePublicationDate(dto *resultDTO) *time.Time {
	if dto.FirstPublicationDate != "" {
		if t, err := time.Parse("2006-01-02", strings.TrimSpace(dto.FirstPublicationDate)); err == nil {
			utc := t.UTC()
			return &utc
		}
	}
	if dto.PubYear != "" {
		if y, err := strconv.Atoi(strings.TrimSpace(dto.PubYear)); err == nil && y > 1800 && y < 2100 {
			t := time.Date(y, 1, 1, 0, 0, 0, 0, time.UTC)
			return &t
		}
	}
	if dto.JournalInfo != nil && dto.JournalInfo.YearOfPublication > 1800 {
		t := time.Date(dto.JournalInfo.YearOfPublication, 1, 1, 0, 0, 0, 0, time.UTC)
		return &t
	}
	return nil
}

func mapPubType(dto *resultDTO) research.PublicationType {
	if strings.EqualFold(dto.Source, "PPR") {
		return research.PubTypePreprint
	}
	if dto.PubTypeList != nil {
		for _, pt := range dto.PubTypeList.PubType {
			low := strings.ToLower(pt)
			if strings.Contains(low, "review") {
				return research.PubTypeReview
			}
			if strings.Contains(low, "conference") || strings.Contains(low, "proceedings") {
				return research.PubTypeConferencePaper
			}
			if strings.Contains(low, "dataset") {
				return research.PubTypeDataset
			}
			if strings.Contains(low, "preprint") {
				return research.PubTypePreprint
			}
		}
	}
	return research.PubTypeArticle
}

// normalize maps an EBI Europe PMC result to Athena's canonical domain model.
func (p *Provider) normalize(dto *resultDTO) (research.Paper, error) {
	title := collapseWS(html.UnescapeString(htmlTagRe.ReplaceAllString(dto.Title, " ")))
	doi := research.CanonicalizeDOI(dto.DOI)
	pmid := strings.TrimSpace(dto.PMID)
	nativeID := strings.TrimSpace(dto.ID)
	if nativeID == "" {
		nativeID = pmid
	}
	if nativeID == "" {
		nativeID = doi
	}

	if title == "" || (doi == "" && pmid == "" && nativeID == "") {
		return research.Paper{}, fmt.Errorf("%w: europepmc item %q lacks identifier or title",
			providers.ErrSchemaDrift, dto.ID)
	}

	paper := research.Paper{
		Title:        title,
		Language:     "en",
		Abstract:     stripHTML(dto.AbstractText),
		CitedByCount: dto.CitedByCount,
		PubType:      mapPubType(dto),
	}

	if dto.JournalInfo != nil && dto.JournalInfo.Journal != nil {
		paper.VenueName = collapseWS(dto.JournalInfo.Journal.Title)
		paper.VenueType = "journal"
	}

	if pubDate := parsePublicationDate(dto); pubDate != nil {
		paper.PublishedOn = pubDate
		paper.Year = pubDate.Year()
	}

	// Identifiers: DOI, PubMed, PMCID, Europe PMC native ID
	if doi != "" {
		paper.Identifiers = append(paper.Identifiers, research.Identifier{
			Type:  research.IDTypeDOI,
			Value: doi,
		})
	}
	if pmid != "" {
		paper.Identifiers = append(paper.Identifiers, research.Identifier{
			Type:  research.IDTypePubMed,
			Value: pmid,
		})
	}
	if pmcid := strings.TrimSpace(dto.PMCID); pmcid != "" {
		paper.Identifiers = append(paper.Identifiers, research.Identifier{
			Type:  research.IDTypeOther,
			Value: "pmc:" + strings.TrimPrefix(strings.ToLower(pmcid), "pmc"),
		})
	}
	if nativeID != "" && nativeID != pmid && nativeID != doi {
		paper.Identifiers = append(paper.Identifiers, research.Identifier{
			Type:  research.IDTypeOther,
			Value: "epmc:" + nativeID,
		})
	}

	// Authors
	if dto.AuthorList != nil && len(dto.AuthorList.Author) > 0 {
		for pos, au := range dto.AuthorList.Author {
			name := strings.TrimSpace(au.FullName)
			if name == "" {
				name = strings.TrimSpace(au.FirstName + " " + au.LastName)
			}
			if name == "" {
				continue
			}
			pids := map[research.IdentifierType]string{}
			if au.AuthorID != nil && strings.TrimSpace(au.AuthorID.Text) != "" {
				pids[research.IDTypeOther] = "orcid:" + strings.TrimSpace(au.AuthorID.Text)
			}
			paper.Authors = append(paper.Authors, research.AuthorRef{
				DisplayName: name,
				Position:    pos + 1,
				ProviderIDs: pids,
			})
		}
	} else if authorStr := strings.TrimSpace(dto.AuthorString); authorStr != "" {
		authors := strings.Split(authorStr, ",")
		for pos, a := range authors {
			name := strings.TrimSpace(strings.TrimSuffix(a, "."))
			if name == "" {
				continue
			}
			paper.Authors = append(paper.Authors, research.AuthorRef{
				DisplayName: name,
				Position:    pos + 1,
				ProviderIDs: map[research.IdentifierType]string{},
			})
		}
	}

	// Topics (Keywords and MeSH Headings)
	addTopic := func(name string) {
		name = strings.TrimSpace(name)
		if name == "" || len(paper.Topics) >= 6 {
			return
		}
		slug := strings.ReplaceAll(research.NormalizeTitle(name), " ", "-")
		for _, existing := range paper.Topics {
			if existing.Slug == slug {
				return
			}
		}
		paper.Topics = append(paper.Topics, research.TopicRef{
			Name:      name,
			Slug:      slug,
			Score:     1,
			IsPrimary: len(paper.Topics) == 0,
		})
	}

	if dto.KeywordList != nil {
		for _, kw := range dto.KeywordList.Keyword {
			addTopic(kw)
		}
	}
	if dto.MeshHeadingList != nil {
		for _, mh := range dto.MeshHeadingList.MeshHeading {
			addTopic(mh.DescriptorName)
		}
	}

	// Open Access & Full-Text URLs
	isOpen := strings.EqualFold(dto.IsOpenAccess, "Y") ||
		strings.EqualFold(dto.InEPMC, "Y") ||
		strings.EqualFold(dto.InPMC, "Y")

	if isOpen {
		if strings.EqualFold(dto.Source, "PPR") {
			paper.OA.Status = research.OAStatusGreen
		} else {
			paper.OA.Status = research.OAStatusGold
		}
	} else {
		paper.OA.Status = research.OAStatusClosed
	}

	var bestPDF, bestLanding string
	if dto.FullTextURLList != nil {
		for _, u := range dto.FullTextURLList.FullTextURL {
			urlStr := strings.TrimSpace(u.URL)
			if urlStr == "" {
				continue
			}
			if strings.EqualFold(u.DocumentStyle, "pdf") && bestPDF == "" {
				bestPDF = urlStr
			} else if bestLanding == "" {
				bestLanding = urlStr
			}
		}
	}

	if bestPDF != "" {
		paper.OA.URL = bestPDF
		paper.Versions = append(paper.Versions, research.VersionRef{
			Kind: research.VersionPublisher,
			URL:  bestPDF,
		})
	} else if bestLanding != "" {
		paper.OA.URL = bestLanding
		paper.Versions = append(paper.Versions, research.VersionRef{
			Kind: research.VersionPublisher,
			URL:  bestLanding,
		})
	} else if doi != "" {
		doiURL := "https://doi.org/" + doi
		paper.Versions = append(paper.Versions, research.VersionRef{
			Kind: research.VersionPublisher,
			URL:  doiURL,
		})
		if isOpen {
			paper.OA.URL = doiURL
		}
	}

	sum := sha256.Sum256([]byte(fmt.Sprintf("%s|%s|%d|%s",
		nativeID, title, dto.CitedByCount, paper.Abstract)))
	paper.Provenance = research.Provenance{
		ProviderSlug:       Slug,
		NativeID:           nativeID,
		FetchedAt:          time.Now().UTC(),
		PayloadFingerprint: hex.EncodeToString(sum[:]),
	}

	research.DeriveIdentity(&paper)
	return paper, nil
}

// Search performs a live query against Europe PMC for federated discovery.
func (p *Provider) Search(ctx context.Context, query string, limit int) ([]research.Paper, error) {
	query = strings.TrimSpace(query)
	if query == "" {
		return nil, fmt.Errorf("%w: europepmc search needs a query", providers.ErrBadWindow)
	}
	if limit <= 0 {
		limit = pageSize
	}
	if limit > 100 {
		limit = 100
	}

	q := url.Values{}
	q.Set("query", query)
	q.Set("format", "json")
	q.Set("pageSize", strconv.Itoa(limit))
	q.Set("resultType", "core")

	raw, err := p.fetch.Get(ctx, Slug, p.baseURL+"/search?"+q.Encode())
	if err != nil {
		return nil, err
	}

	var resp responseDTO
	if err := json.Unmarshal(raw, &resp); err != nil {
		return nil, fmt.Errorf("%w: europepmc search: %v", providers.ErrSchemaDrift, err)
	}

	papers := make([]research.Paper, 0, len(resp.ResultList.Result))
	for i := range resp.ResultList.Result {
		paper, perr := p.normalize(&resp.ResultList.Result[i])
		if perr != nil {
			continue // skip malformed records
		}
		papers = append(papers, paper)
	}
	return papers, nil
}
