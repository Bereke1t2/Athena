package v1

import (
	"bytes"
	"net/http"
	"strings"
	"sync"
	"time"
)

// IdempotencyStore caches responses keyed by Idempotency-Key.
type IdempotencyStore interface {
	Get(key string) (*CachedResponse, bool)
	Set(key string, resp CachedResponse, ttl time.Duration)
}

// CachedResponse captures response status, headers, and payload.
type CachedResponse struct {
	StatusCode int
	Header     http.Header
	Body       []byte
}

// MemoryIdempotencyStore provides an in-memory TTL cache for idempotency.
type MemoryIdempotencyStore struct {
	mu      sync.RWMutex
	entries map[string]idempotencyEntry
}

type idempotencyEntry struct {
	resp      CachedResponse
	expiresAt time.Time
}

// NewMemoryIdempotencyStore creates an in-memory idempotency cache with background sweeper.
func NewMemoryIdempotencyStore() *MemoryIdempotencyStore {
	store := &MemoryIdempotencyStore{
		entries: make(map[string]idempotencyEntry),
	}
	go store.cleanupLoop(5 * time.Minute)
	return store
}

func (s *MemoryIdempotencyStore) cleanupLoop(interval time.Duration) {
	ticker := time.NewTicker(interval)
	for range ticker.C {
		s.mu.Lock()
		now := time.Now()
		for k, v := range s.entries {
			if now.After(v.expiresAt) {
				delete(s.entries, k)
			}
		}
		s.mu.Unlock()
	}
}

func (s *MemoryIdempotencyStore) Get(key string) (*CachedResponse, bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	e, ok := s.entries[key]
	if !ok || time.Now().After(e.expiresAt) {
		return nil, false
	}
	return &e.resp, true
}

func (s *MemoryIdempotencyStore) Set(key string, resp CachedResponse, ttl time.Duration) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.entries[key] = idempotencyEntry{
		resp:      resp,
		expiresAt: time.Now().Add(ttl),
	}
}

// WithIdempotency intercepts mutating requests carrying the Idempotency-Key header.
// If a matching request key is found in cache, it replays the response without invoking next.
func WithIdempotency(store IdempotencyStore, ttl time.Duration, next http.Handler) http.Handler {
	if store == nil {
		return next
	}
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost && r.Method != http.MethodPut && r.Method != http.MethodPatch {
			next.ServeHTTP(w, r)
			return
		}
		key := strings.TrimSpace(r.Header.Get("Idempotency-Key"))
		if key == "" {
			next.ServeHTTP(w, r)
			return
		}

		if cached, ok := store.Get(key); ok {
			for k, values := range cached.Header {
				for _, v := range values {
					w.Header().Add(k, v)
				}
			}
			w.Header().Set("X-Cache-Lookup", "HIT")
			w.WriteHeader(cached.StatusCode)
			_, _ = w.Write(cached.Body)
			return
		}

		rec := &idempotencyRecorder{
			ResponseWriter: w,
			body:           &bytes.Buffer{},
			statusCode:     http.StatusOK,
			header:         make(http.Header),
		}

		next.ServeHTTP(rec, r)

		if rec.statusCode < 500 {
			store.Set(key, CachedResponse{
				StatusCode: rec.statusCode,
				Header:     rec.header.Clone(),
				Body:       rec.body.Bytes(),
			}, ttl)
		}
	})
}

type idempotencyRecorder struct {
	http.ResponseWriter
	body        *bytes.Buffer
	statusCode  int
	header      http.Header
	wroteHeader bool
}

func (r *idempotencyRecorder) Header() http.Header {
	return r.ResponseWriter.Header()
}

func (r *idempotencyRecorder) WriteHeader(code int) {
	if !r.wroteHeader {
		r.statusCode = code
		r.wroteHeader = true
		for k, v := range r.Header() {
			r.header[k] = v
		}
		r.ResponseWriter.WriteHeader(code)
	}
}

func (r *idempotencyRecorder) Write(b []byte) (int, error) {
	if !r.wroteHeader {
		r.WriteHeader(http.StatusOK)
	}
	r.body.Write(b)
	return r.ResponseWriter.Write(b)
}
