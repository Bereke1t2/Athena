package v1

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/google/uuid"

	domainuser "athena/backend/internal/domain/user"
)

func TestMemoryRateLimiterAllowAndDeny(t *testing.T) {
	limiter := NewMemoryRateLimiter()
	ctx := context.Background()
	key := "test:client:1"
	limit := 3
	window := time.Second

	for i := 1; i <= limit; i++ {
		allowed, rem, _, err := limiter.Allow(ctx, key, limit, window)
		if err != nil {
			t.Fatalf("allow error: %v", err)
		}
		if !allowed {
			t.Fatalf("request %d should be allowed", i)
		}
		if rem != limit-i {
			t.Errorf("request %d: remaining want %d, got %d", i, limit-i, rem)
		}
	}

	// 4th request should exceed limit
	allowed, rem, _, err := limiter.Allow(ctx, key, limit, window)
	if err != nil {
		t.Fatalf("allow error: %v", err)
	}
	if allowed {
		t.Errorf("4th request should be denied")
	}
	if rem != 0 {
		t.Errorf("remaining on denied should be 0, got %d", rem)
	}

	// Wait for window to expire
	time.Sleep(1100 * time.Millisecond)

	// Should be allowed again
	allowed, _, _, err = limiter.Allow(ctx, key, limit, window)
	if err != nil || !allowed {
		t.Errorf("request after window should be allowed")
	}
}

func TestWithRateLimitHeadersAndExemptions(t *testing.T) {
	limiter := NewMemoryRateLimiter()
	next := http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ok"))
	})
	handler := WithRateLimit(limiter, nil, next)

	// Platform probes exempt
	for _, path := range []string{"/healthz", "/readyz", "/metrics"} {
		rec := httptest.NewRecorder()
		req := httptest.NewRequest(http.MethodGet, path, nil)
		handler.ServeHTTP(rec, req)
		if rec.Code != http.StatusOK {
			t.Errorf("%s status: got %d", path, rec.Code)
		}
		if rec.Header().Get("X-RateLimit-Limit") != "" {
			t.Errorf("%s should not have rate limit headers", path)
		}
	}

	// Standard anonymous request receives 60 req/min limit headers
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/api/v1/research/papers", nil)
	req.RemoteAddr = "192.0.2.1:12345"
	handler.ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("status: %d", rec.Code)
	}
	if rec.Header().Get("X-RateLimit-Limit") != "60" {
		t.Errorf("want limit 60, got %s", rec.Header().Get("X-RateLimit-Limit"))
	}
	if rec.Header().Get("X-RateLimit-Remaining") != "59" {
		t.Errorf("want remaining 59, got %s", rec.Header().Get("X-RateLimit-Remaining"))
	}
	if rec.Header().Get("X-RateLimit-Reset") == "" {
		t.Errorf("missing X-RateLimit-Reset header")
	}

	// Live search uses 10 req/min limit
	recLive := httptest.NewRecorder()
	reqLive := httptest.NewRequest(http.MethodGet, "/api/v1/search/live", nil)
	reqLive.RemoteAddr = "192.0.2.1:12345"
	handler.ServeHTTP(recLive, reqLive)
	if recLive.Header().Get("X-RateLimit-Limit") != "10" {
		t.Errorf("want live search limit 10, got %s", recLive.Header().Get("X-RateLimit-Limit"))
	}

	// Authenticated request uses 300 req/min limit
	recAuth := httptest.NewRecorder()
	reqAuth := httptest.NewRequest(http.MethodGet, "/api/v1/feed", nil)
	ctx := context.WithValue(reqAuth.Context(), userKey{}, domainuser.User{ID: uuid.New()})
	reqAuth = reqAuth.WithContext(ctx)
	handler.ServeHTTP(recAuth, reqAuth)
	if recAuth.Header().Get("X-RateLimit-Limit") != "300" {
		t.Errorf("want auth limit 300, got %s", recAuth.Header().Get("X-RateLimit-Limit"))
	}
}

type staticLimiter struct {
	allowed   bool
	remaining int
	resetAt   time.Time
}

func (s staticLimiter) Allow(_ context.Context, _ string, _ int, _ time.Duration) (bool, int, time.Time, error) {
	return s.allowed, s.remaining, s.resetAt, nil
}

func TestWithRateLimit429WhenExceeded(t *testing.T) {
	reset := time.Now().Add(15 * time.Second)
	limiter := staticLimiter{allowed: false, remaining: 0, resetAt: reset}

	next := http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusOK)
	})
	handler := WithRateLimit(limiter, nil, next)

	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/api/v1/research/papers", nil)
	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusTooManyRequests {
		t.Fatalf("expected 429 Too Many Requests, got %d", rec.Code)
	}
	if rec.Header().Get("Retry-After") == "" {
		t.Errorf("missing Retry-After header")
	}

	var env errorEnvelope
	if err := json.Unmarshal(rec.Body.Bytes(), &env); err != nil {
		t.Fatal(err)
	}
	if env.Error.Code != CodeRateLimited {
		t.Errorf("want code %s, got %s", CodeRateLimited, env.Error.Code)
	}
}
