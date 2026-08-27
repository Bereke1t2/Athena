// Package search orchestrates query execution with response caching
// (api-specification.md: search/feed cached ≤60s). The cache is an optional
// decorator — without Redis every request hits the engine directly.
package search

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	domainsearch "athena/backend/internal/domain/search"
)

// Cache abstracts the Redis adapter (infrastructure/cache) so unit tests can
// stub it.
type Cache interface {
	GetJSON(ctx context.Context, namespace, raw string) ([]byte, error)
	SetJSON(ctx context.Context, namespace, raw string, v any) error
}

// Service is the cached search entry point used by HTTP handlers.
type Service struct {
	Engine domainsearch.Searcher
	Cache  Cache // nil disables caching
}

func NewService(engine domainsearch.Searcher, c Cache) *Service {
	return &Service{Engine: engine, Cache: c}
}

// Search executes the query through the cache-aside pattern. Canonical key =
// deterministic JSON of the full Query; any field change misses naturally,
// and ingestion bumps the shared generation to invalidate everything.
func (s *Service) Search(ctx context.Context, q domainsearch.Query) (domainsearch.ResultPage, error) {
	start := time.Now()
	if s.Cache == nil {
		return s.Engine.Search(ctx, q)
	}

	key, err := canonicalKey(q)
	if err == nil {
		if b, cerr := s.Cache.GetJSON(ctx, "search", key); cerr == nil && b != nil {
			var page domainsearch.ResultPage
			if json.Unmarshal(b, &page) == nil {
				// Report the cache-served latency, not the frozen
				// execution time from when the entry was written.
				page.TookMS = time.Since(start).Milliseconds()
				return page, nil
			}
			// Corrupt entry: fall through to a fresh execution.
		}
	}

	page, err := s.Engine.Search(ctx, q)
	if err != nil {
		return page, err
	}
	if key != "" {
		_ = s.Cache.SetJSON(ctx, "search", key, page)
	}
	return page, nil
}

// Related bypasses the cache: single-paper lookups are cheap and freshness
// matters more than latency here.
func (s *Service) Related(ctx context.Context, paperID domainsearch.UUID, limit int) ([]domainsearch.ScoredPaper, error) {
	return s.Engine.Related(ctx, paperID, limit)
}

func canonicalKey(q domainsearch.Query) (string, error) {
	b, err := json.Marshal(q)
	if err != nil {
		return "", fmt.Errorf("search cache key: %w", err)
	}
	return string(b), nil
}
