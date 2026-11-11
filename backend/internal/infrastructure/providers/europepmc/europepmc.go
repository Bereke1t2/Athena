package europepmc

import (
	"fmt"
	"strings"
	"time"

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
