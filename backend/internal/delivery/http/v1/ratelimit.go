package v1

import (
	"context"
	"log/slog"
	"math"
	"net"
	"net/http"
	"strconv"
	"strings"
	"sync"
	"time"
)

// RateLimiter decides whether a request with a given key is permitted within the window.
type RateLimiter interface {
	Allow(ctx context.Context, key string, limit int, window time.Duration) (allowed bool, remaining int, resetAt time.Time, err error)
}

// MemoryRateLimiter implements an in-memory sliding-window rate limiter.
type MemoryRateLimiter struct {
	mu      sync.Mutex
	entries map[string]*windowEntry
}

type windowEntry struct {
	timestamps []time.Time
	lastSeen   time.Time
}

// NewMemoryRateLimiter creates an in-memory sliding-window limiter.
func NewMemoryRateLimiter() *MemoryRateLimiter {
	limiter := &MemoryRateLimiter{
		entries: make(map[string]*windowEntry),
	}
	go limiter.cleanupLoop(5 * time.Minute)
	return limiter
}

func (m *MemoryRateLimiter) cleanupLoop(interval time.Duration) {
	ticker := time.NewTicker(interval)
	for range ticker.C {
		m.mu.Lock()
		cutoff := time.Now().Add(-10 * time.Minute)
		for k, e := range m.entries {
			if e.lastSeen.Before(cutoff) {
				delete(m.entries, k)
			}
		}
		m.mu.Unlock()
	}
}

// Allow records an attempt under key and answers whether it is within limit.
func (m *MemoryRateLimiter) Allow(_ context.Context, key string, limit int, window time.Duration) (bool, int, time.Time, error) {
	m.mu.Lock()
	defer m.mu.Unlock()

	now := time.Now()
	entry, ok := m.entries[key]
	if !ok {
		entry = &windowEntry{}
		m.entries[key] = entry
	}
	entry.lastSeen = now

	// Prune timestamps older than window
	windowStart := now.Add(-window)
	valid := entry.timestamps[:0]
	for _, ts := range entry.timestamps {
		if ts.After(windowStart) {
			valid = append(valid, ts)
		}
	}
	entry.timestamps = valid

	resetAt := now.Add(window)
	if len(entry.timestamps) > 0 {
		resetAt = entry.timestamps[0].Add(window)
	}

	if len(entry.timestamps) >= limit {
		return false, 0, resetAt, nil
	}

	entry.timestamps = append(entry.timestamps, now)
	remaining := limit - len(entry.timestamps)
	return true, remaining, resetAt, nil
}

// ClientIP extracts client IP address prioritizing X-Forwarded-For before RemoteAddr.
func ClientIP(r *http.Request) string {
	xff := r.Header.Get("X-Forwarded-For")
	if xff != "" {
		parts := strings.Split(xff, ",")
		ip := strings.TrimSpace(parts[0])
		if ip != "" {
			return ip
		}
	}
	host, _, err := net.SplitHostPort(r.RemoteAddr)
	if err == nil && host != "" {
		return host
	}
	return r.RemoteAddr
}

// WithRateLimit wraps handler with sliding-window rate limiting per API spec §1.
func WithRateLimit(limiter RateLimiter, log *slog.Logger, next http.Handler) http.Handler {
	if limiter == nil {
		return next
	}

	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Exempt CORS preflights and platform probes
		if r.Method == http.MethodOptions ||
			r.URL.Path == "/healthz" ||
			r.URL.Path == "/readyz" ||
			r.URL.Path == "/metrics" ||
			strings.HasPrefix(r.URL.Path, "/api/v1/admin/") {
			next.ServeHTTP(w, r)
			return
		}

		user, isAuth := UserFromContext(r.Context())
		var keyPrefix string
		var limit int
		window := time.Minute

		if isAuth {
			keyPrefix = "u:" + user.ID.String()
			limit = 300 // 300 req/min authenticated
		} else {
			keyPrefix = "ip:" + ClientIP(r)
			limit = 60 // 60 req/min anonymous
		}

		// Specialized endpoint limits
		path := r.URL.Path
		switch {
		case path == "/api/v1/search/live":
			keyPrefix += ":search_live"
			limit = 10 // live federated search limit
		case path == "/api/v1/research/compare" ||
			strings.HasPrefix(path, "/api/v1/chat/") ||
			(strings.HasPrefix(path, "/api/v1/research/papers/") && strings.HasSuffix(path, "/summary")):
			keyPrefix += ":ai"
			limit = 20 // generative AI endpoints limit
		default:
			keyPrefix += ":general"
		}

		allowed, remaining, resetAt, err := limiter.Allow(r.Context(), keyPrefix, limit, window)
		if err != nil {
			if log != nil {
				log.Error("rate limit evaluation error", "error", err, "key", keyPrefix)
			}
			// Degrade open on internal rate limit error
			next.ServeHTTP(w, r)
			return
		}

		w.Header().Set("X-RateLimit-Limit", strconv.Itoa(limit))
		w.Header().Set("X-RateLimit-Remaining", strconv.Itoa(remaining))
		w.Header().Set("X-RateLimit-Reset", strconv.FormatInt(resetAt.Unix(), 10))

		if !allowed {
			seconds := int(math.Ceil(time.Until(resetAt).Seconds()))
			if seconds < 1 {
				seconds = 1
			}
			w.Header().Set("Retry-After", strconv.Itoa(seconds))
			WriteError(w, r, http.StatusTooManyRequests, CodeRateLimited, "rate limit exceeded, please retry later")
			return
		}

		next.ServeHTTP(w, r)
	})
}
