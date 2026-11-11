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
