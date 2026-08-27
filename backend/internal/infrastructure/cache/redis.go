// Package cache provides the Redis-backed response cache for search and feed
// endpoints (api-specification.md: cached ≤60s) plus the generation counter
// used to invalidate entries as soon as new data lands.
package cache

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/redis/go-redis/v9"
)

// TTL bounds staleness even without explicit invalidation (spec ceiling 60s).
const TTL = 60 * time.Second

// genKey holds the monotonically increasing generation; entry keys embed it,
// so bumping the generation orphans every cached response at once.
const genKey = "athena:search:gen"

// Cache wraps a Redis client with JSON helpers and generation-scoped keys.
type Cache struct {
	rdb    *redis.Client
	prefix string
}

func New(addr string) *Cache {
	return &Cache{
		rdb:    redis.NewClient(&redis.Options{Addr: addr}),
		prefix: "athena:cache",
	}
}

// Ping verifies connectivity (readiness probes).
func (c *Cache) Ping(ctx context.Context) error {
	return c.rdb.Ping(ctx).Err()
}

// Close releases the underlying connection pool.
func (c *Cache) Close() error { return c.rdb.Close() }

func (c *Cache) key(ctx context.Context, namespace, raw string) (string, error) {
	gen, err := c.rdb.Get(ctx, genKey).Result()
	if err == redis.Nil {
		gen = "0"
	} else if err != nil {
		return "", fmt.Errorf("cache gen read: %w", err)
	}
	return fmt.Sprintf("%s:%s:%s:%s", c.prefix, gen, namespace, raw), nil
}

// GetJSON returns the cached payload for namespaced raw key; miss = nil,nil.
func (c *Cache) GetJSON(ctx context.Context, namespace, raw string) ([]byte, error) {
	k, err := c.key(ctx, namespace, raw)
	if err != nil {
		return nil, err
	}
	b, err := c.rdb.Get(ctx, k).Bytes()
	if err == redis.Nil {
		return nil, nil
	}
	return b, err
}

// SetJSON stores the payload under the current generation.
func (c *Cache) SetJSON(ctx context.Context, namespace, raw string, v any) error {
	b, err := json.Marshal(v)
	if err != nil {
		return fmt.Errorf("cache marshal: %w", err)
	}
	k, err := c.key(ctx, namespace, raw)
	if err != nil {
		return err
	}
	return c.rdb.Set(ctx, k, b, TTL).Err()
}

// InvalidateSearch bumps the generation, instantly orphaning all cached
// search/feed responses. Called after successful ingestion runs.
func (c *Cache) InvalidateSearch(ctx context.Context) error {
	return c.rdb.Incr(ctx, genKey).Err()
}
