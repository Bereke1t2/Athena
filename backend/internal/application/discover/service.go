// Package discover implements live federated search across every configured
// research provider (arXiv, Semantic Scholar, OpenAlex, Crossref). Unlike the
// corpus search engine (ADR-0005), this queries providers directly at request
// time: results are deduplicated across sources, ranked by a blend of textual
// relevance, citation gravity and recency, then persisted so papers get stable
// UUIDs and full detail pages.
package discover

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"math"
	"sort"
	"strings"
	"sync"
	"time"

	"athena/backend/internal/domain/research"
	domainsearch "athena/backend/internal/domain/search"
)

// ProviderSearcher is the live-search capability each provider adapter
// exposes alongside its ingestion FetchWindow port.
type ProviderSearcher interface {
	Slug() string
	Search(ctx context.Context, query string, limit int) ([]research.Paper, error)
}

// Store persists federated hits so they receive stable identities.
type Store interface {
	UpsertPaper(ctx context.Context, p research.Paper) (research.UpsertResult, error)
}

// Cache is the optional Redis response cache (same contract as app/search).
type Cache interface {
	GetJSON(ctx context.Context, namespace, raw string) ([]byte, error)
	SetJSON(ctx context.Context, namespace, raw string, v any) error
}

// SourceStatus reports one provider's contribution to a query, surfaced to
// clients so partial failures are transparent.
type SourceStatus struct {
	Slug   string `json:"slug"`
	OK     bool   `json:"ok"`
	Papers int    `json:"papers"`
	Error  string `json:"error,omitempty"`
}

// Result is a federated search page plus per-source telemetry.
type Result struct {
	Items   []domainsearch.ScoredPaper
	Sources []SourceStatus
	TookMS  int64
}

// Service orchestrates the fan-out.
type Service struct {
	Providers   []ProviderSearcher
	Store       Store
	Cache       Cache // nil disables caching
	Logger      *slog.Logger
	PerTimeout  time.Duration // per-provider budget; default 8s
	PerProvider int           // records requested from each provider; default 25
}

func NewService(providers []ProviderSearcher, store Store, c Cache, log *slog.Logger) *Service {
	if log == nil {
		log = slog.Default()
	}
	return &Service{
		Providers:   providers,
		Store:       store,
		Cache:       c,
		Logger:      log,
		PerTimeout:  8 * time.Second,
		PerProvider: 25,
	}
}

// Search fans the query out to every provider concurrently, merges and ranks
// the union, then persists the top page. Individual provider failures never
// fail the whole request while at least one source answers.
func (s *Service) Search(ctx context.Context, q domainsearch.Query) (Result, error) {
	start := time.Now()

	if s.Cache != nil {
		if b, err := s.Cache.GetJSON(ctx, "discover", cacheKey(q)); err == nil && b != nil {
			var res Result
			if json.Unmarshal(b, &res) == nil {
				res.TookMS = time.Since(start).Milliseconds()
				return res, nil
			}
		}
	}

	fetched, statuses := s.fanOut(ctx, q.Q)

	items, err := s.mergeAndPersist(ctx, q, fetched)
	if err != nil {
		return Result{}, err
	}

	res := Result{Items: items, Sources: statuses, TookMS: time.Since(start).Milliseconds()}
	if s.Cache != nil {
		_ = s.Cache.SetJSON(ctx, "discover", cacheKey(q), res)
	}
	return res, nil
}

func (s *Service) fanOut(ctx context.Context, query string) ([]research.Paper, []SourceStatus) {
	type outcome struct {
		slug   string
		papers []research.Paper
		err    error
	}

	outcomes := make([]outcome, len(s.Providers))
	var wg sync.WaitGroup
	for i, prov := range s.Providers {
		wg.Add(1)
		go func(i int, prov ProviderSearcher) {
			defer wg.Done()
			pctx, cancel := context.WithTimeout(ctx, s.PerTimeout)
			defer cancel()
			papers, err := prov.Search(pctx, query, s.PerProvider)
			outcomes[i] = outcome{slug: prov.Slug(), papers: papers, err: err}
		}(i, prov)
	}
	wg.Wait()

	var all []research.Paper
	statuses := make([]SourceStatus, 0, len(outcomes))
	for _, oc := range outcomes {
		st := SourceStatus{Slug: oc.slug, Papers: len(oc.papers)}
		if oc.err != nil {
			st.Error = oc.err.Error()
			s.Logger.Warn("live search provider failed",
				"provider", oc.slug, "error", oc.err)
		} else {
			st.OK = true
			all = append(all, oc.papers...)
		}
		statuses = append(statuses, st)
	}
	return all, statuses
}

// merged accumulates duplicate records for the same work found via multiple
// providers — agreement across independent sources is itself a quality signal.
type merged struct {
	paper   research.Paper
	sources []string
}

func (s *Service) mergeAndPersist(ctx context.Context, q domainsearch.Query, fetched []research.Paper) ([]domainsearch.ScoredPaper, error) {
	byKey := map[string]*merged{}
	keyOrder := []string{}

	for _, p := range fetched {
		key := identityKey(p)
		if key == "" {
			continue
		}
		existing, ok := byKey[key]
		if !ok {
			cp := p
			byKey[key] = &merged{paper: cp, sources: []string{cp.Provenance.ProviderSlug}}
			keyOrder = append(keyOrder, key)
			continue
		}
		existing.paper = richer(existing.paper, p)
		existing.sources = appendDistinct(existing.sources, p.Provenance.ProviderSlug)
	}

	tokens, phrase := tokenize(q.Q)

	type scored struct {
		m     *merged
		score float64
	}
	candidates := make([]scored, 0, len(keyOrder))
	for _, k := range keyOrder {
		m := byKey[k]
		if q.OpenAccess != nil && *q.OpenAccess && !m.paper.OA.IsOpen() {
			continue
		}
		if q.MinCitations > 0 && m.paper.CitedByCount < q.MinCitations {
			continue
		}
		candidates = append(candidates, scored{m: m,
			score: relevance(tokens, phrase, m)})
	}

	switch q.Sort {
	case domainsearch.SortNewest:
		sort.SliceStable(candidates, func(i, j int) bool {
			a, b := candidates[i].m.paper, candidates[j].m.paper
			ad, bd := a.PublishedOn, b.PublishedOn
			switch {
			case ad == nil && bd == nil:
				return false
			case ad == nil:
				return false
			case bd == nil:
				return true
			default:
				return ad.After(*bd)
			}
		})
	case domainsearch.SortCitations:
		sort.SliceStable(candidates, func(i, j int) bool {
			return candidates[i].m.paper.CitedByCount > candidates[j].m.paper.CitedByCount
		})
	default: // relevance
		sort.SliceStable(candidates, func(i, j int) bool {
			return candidates[i].score > candidates[j].score
		})
	}

	limit := q.Limit
	if limit <= 0 {
		limit = 20
	}
	if len(candidates) > limit {
		candidates = candidates[:limit]
	}

	items := make([]domainsearch.ScoredPaper, 0, len(candidates))
	for _, c := range candidates {
		id, err := s.persist(ctx, c.m.paper)
		if err != nil {
			s.Logger.Warn("live search persist failed",
				"title", c.m.paper.Title, "error", err)
			continue
		}
		items = append(items, domainsearch.ScoredPaper{
			Score: round3(c.score),
			Paper: summary(id, c.m),
		})
	}
	return items, nil
}

func (s *Service) persist(ctx context.Context, p research.Paper) (research.UpsertResult, error) {
	pctx, cancel := context.WithTimeout(ctx, 10*time.Second)
	defer cancel()
	return s.Store.UpsertPaper(pctx, p)
}

// identityKey picks the strongest cross-provider identity available.
func identityKey(p research.Paper) string {
	if doi := p.DOI(); doi != "" {
		return "doi:" + strings.ToLower(doi)
	}
	if ax := p.ArxivID(); ax != "" {
		return "arxiv:" + strings.ToLower(ax)
	}
	if p.Fingerprint != "" {
		return "fp:" + p.Fingerprint
	}
	return ""
}

// richer merges two records for the same work, keeping whichever carries more
// usable metadata field-by-field.
func richer(a, b research.Paper) research.Paper {
	out := a
	if len(out.Abstract) < len(b.Abstract) {
		out.Abstract = b.Abstract
	}
	if out.VenueName == "" {
		out.VenueName = b.VenueName
	}
	if out.VenueType == "" {
		out.VenueType = b.VenueType
	}
	if out.Language == "" {
		out.Language = b.Language
	}
	if b.CitedByCount > out.CitedByCount {
		out.CitedByCount = b.CitedByCount
	}
	if b.ReferenceCount > out.ReferenceCount {
		out.ReferenceCount = b.ReferenceCount
	}
	if len(b.Authors) > len(out.Authors) {
		out.Authors = b.Authors
	}
	if len(b.Topics) > len(out.Topics) {
		out.Topics = b.Topics
	}
	if len(b.Identifiers) > len(out.Identifiers) {
		out.Identifiers = append(out.Identifiers, diffIdentifiers(out.Identifiers, b.Identifiers)...)
	}
	if out.PublishedOn == nil && b.PublishedOn != nil {
		out.PublishedOn = b.PublishedOn
		out.Year = b.Year
	}
	if len(b.Versions) > len(out.Versions) {
		out.Versions = append(out.Versions, b.Versions...)
	}
	if out.OA.URL == "" && b.OA.URL != "" {
		out.OA = b.OA
	}
	return out
}

func diffIdentifiers(base, extra []research.Identifier) []research.Identifier {
	seen := map[string]bool{}
	for _, id := range base {
		seen[string(id.Type)+"|"+id.Value] = true
	}
	var out []research.Identifier
	for _, id := range extra {
		if !seen[string(id.Type)+"|"+id.Value] {
			out = append(out, id)
		}
	}
	return out
}

// relevance blends textual match quality, citation gravity, recency and
// cross-source agreement into one comparable score.
func relevance(tokens []string, phrase string, m *merged) float64 {
	title := strings.ToLower(m.paper.TitleNormalized)
	if title == "" {
		title = strings.ToLower(m.paper.Title)
	}
	abs := strings.ToLower(m.paper.Abstract)

	text := 0.0
	if len(tokens) > 0 {
		hitsTitle, hitsAbs := 0, 0
		for _, t := range tokens {
			if strings.Contains(title, t) {
				hitsTitle++
			}
			if strings.Contains(abs, t) {
				hitsAbs++
			}
		}
		text = 2.0*float64(hitsTitle)/float64(len(tokens)) +
			float64(hitsAbs)/float64(len(tokens))
		if phrase != "" && strings.Contains(title, phrase) {
			text += 0.5
		}
	} else {
		text = 0.5 // degenerate single-symbol queries still rank somehow
	}

	recency := 0.0
	if m.paper.PublishedOn != nil {
		ageYears := time.Since(*m.paper.PublishedOn).Hours() / (24 * 365.25)
		if ageYears < 0 {
			ageYears = 0
		}
		recency = math.Pow(0.5, ageYears/1.5) // 18-month half-life, as pgsearch
	}

	gravity := math.Log1p(float64(m.paper.CitedByCount)) / 3.0
	agreement := 0.75 * float64(len(m.sources)-1)

	return 3.0*text + 1.5*recency + gravity + agreement
}

// tokenize lowercases and splits the query; tokens shorter than three runes
// are dropped except when everything is short.
func tokenize(q string) ([]string, string) {
	fields := strings.FieldsFunc(strings.ToLower(q), func(r rune) bool {
		return !unicodeIsLetterOrDigit(r)
	})
	tokens := make([]string, 0, len(fields))
	for _, f := range fields {
		if len([]rune(f)) >= 2 {
			tokens = append(tokens, f)
		}
	}
	if len(tokens) == 0 && len(fields) > 0 {
		tokens = fields
	}
	phrase := ""
	if len(fields) > 1 {
		phrase = strings.Join(fields, " ")
	}
	return tokens, phrase
}

func unicodeIsLetterOrDigit(r rune) bool {
	return (r >= 'a' && r <= 'z') || (r >= '0' && r <= '9') || r > 127
}

func summary(id research.UpsertResult, m *merged) research.PaperSummary {
	p := m.paper
	sum := research.PaperSummary{
		ID:              id.PaperID,
		Title:           p.Title,
		PublishedOn:     p.PublishedOn,
		Year:            p.Year,
		VenueName:       p.VenueName,
		PublicationType: p.PubType,
		OAStatus:        p.OA.Status,
		IsOpenAccess:    p.OA.IsOpen(),
		CitedByCount:    p.CitedByCount,
	}
	if p.Abstract != "" {
		ab := p.Abstract
		sum.Abstract = &ab
	}
	return sum
}

func appendDistinct(list []string, v string) []string {
	for _, s := range list {
		if s == v {
			return list
		}
	}
	return append(list, v)
}

func round3(f float64) float64 { return math.Round(f*1000) / 1000 }

func cacheKey(q domainsearch.Query) string {
	return fmt.Sprintf(`{"q":%q,"sort":%q,"oa":%v,"min_cits":%d,"limit":%d}`,
		strings.ToLower(strings.TrimSpace(q.Q)), q.Sort,
		q.OpenAccess != nil && *q.OpenAccess, q.MinCitations, q.Limit)
}
