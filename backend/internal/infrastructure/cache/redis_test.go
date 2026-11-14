package cache

import (
	"context"
	"testing"
	"time"

	"github.com/alicebob/miniredis/v2"

	v1 "athena/backend/internal/delivery/http/v1"
)

func newTestCache(t *testing.T) (*Cache, *miniredis.Miniredis) {
	t.Helper()
	mr := miniredis.RunT(t)
	return New(mr.Addr()), mr
}

func TestSetGetRoundTrip(t *testing.T) {
	c, _ := newTestCache(t)
	ctx := context.Background()

	if err := c.SetJSON(ctx, "search", "k1", map[string]any{"v": 1}); err != nil {
		t.Fatalf("set: %v", err)
	}
	got, err := c.GetJSON(ctx, "search", "k1")
	if err != nil || got == nil {
		t.Fatalf("get: %v %s", err, got)
	}
	if string(got) == "" {
		t.Fatal("empty payload")
	}
}

func TestMissReturnsNil(t *testing.T) {
	c, _ := newTestCache(t)
	got, err := c.GetJSON(context.Background(), "search", "missing")
	if err != nil || got != nil {
		t.Fatalf("expected nil,nil; got %v,%v", got, err)
	}
}

func TestInvalidateOrphansEntries(t *testing.T) {
	c, mr := newTestCache(t)
	ctx := context.Background()

	if err := c.SetJSON(ctx, "search", "k", "payload"); err != nil {
		t.Fatalf("set: %v", err)
	}
	if b, _ := c.GetJSON(ctx, "search", "k"); b == nil {
		t.Fatal("precondition: entry should be readable")
	}

	if err := c.InvalidateSearch(ctx); err != nil {
		t.Fatalf("invalidate: %v", err)
	}
	if b, _ := c.GetJSON(ctx, "search", "k"); b != nil {
		t.Fatal("entry should be orphaned after generation bump")
	}

	// Old entries still exist under the previous generation key (harmless,
	// they age out via TTL).
	if !mr.Exists("athena:cache:0:search:k") && !mr.Exists("athena:cache:1:search:k") {
		t.Log("note: raw key layout changed; informational only")
	}
}

func TestTTLIsBoundedAt60s(t *testing.T) {
	c, mr := newTestCache(t)
	ctx := context.Background()
	_ = c.SetJSON(ctx, "search", "k", "v")
	ttl := mr.TTL("athena:cache:0:search:k")
	if ttl <= 0 || ttl > TTL+time.Second {
		t.Fatalf("unexpected ttl %v (want <= %v)", ttl, TTL)
	}
}

func TestRedisDownDegradesToMiss(t *testing.T) {
	// A dead Redis must read as a cache miss, never a hard failure.
	c := New("127.0.0.1:1") // nothing listens here
	b, err := c.GetJSON(context.Background(), "search", "k")
	if b != nil {
		t.Fatalf("expected nil on down redis, got %s", b)
	}
	_ = err // callers may inspect but must not depend on it
}

func TestRedisRateLimiter(t *testing.T) {
	c, _ := newTestCache(t)
	limiter := c.RateLimiter()
	if limiter == nil {
		t.Fatal("expected non-nil limiter")
	}

	ctx := context.Background()
	key := "test-user-rate-limit"
	limit := 3
	window := time.Minute

	// Attempts 1, 2, 3 should be allowed
	for i := 1; i <= limit; i++ {
		allowed, remaining, _, err := limiter.Allow(ctx, key, limit, window)
		if err != nil {
			t.Fatalf("unexpected error on attempt %d: %v", i, err)
		}
		if !allowed {
			t.Fatalf("attempt %d should be allowed", i)
		}
		if remaining != limit-i {
			t.Fatalf("expected %d remaining, got %d", limit-i, remaining)
		}
	}

	// Attempt 4 should be rejected
	allowed, remaining, resetAt, err := limiter.Allow(ctx, key, limit, window)
	if err != nil {
		t.Fatalf("unexpected error on limit exceeded: %v", err)
	}
	if allowed {
		t.Fatal("attempt 4 should NOT be allowed")
	}
	if remaining != 0 {
		t.Fatalf("expected 0 remaining, got %d", remaining)
	}
	if resetAt.Before(time.Now()) {
		t.Fatalf("resetAt should be in the future, got %v", resetAt)
	}
}
