// Package providers hosts external research-source adapters. Each subpackage
// implements research.ResearchProvider for one API; this file carries the
// transport plumbing they share: rate limiting, a circuit breaker, retrying
// HTTP fetches with backoff, and Prometheus instrumentation.
package providers

import (
	"context"
	"errors"
	"fmt"
	"io"
	"math/rand/v2"
	"net/http"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/prometheus/client_golang/prometheus"
)

// Sentinel errors adapters return so the application layer can classify
// retries without knowing vendor specifics.
var (
	ErrRateLimited = errors.New("providers: rate limited by upstream")
	ErrUnavailable = errors.New("providers: upstream unavailable")
	ErrBreakerOpen = errors.New("providers: circuit breaker open")
	ErrSchemaDrift = errors.New("providers: unexpected payload shape")
	ErrBadWindow   = errors.New("providers: invalid window")
	ErrRejected    = errors.New("providers: request rejected") // non-retryable 4xx
)

var (
	requestsTotal = prometheus.NewCounterVec(prometheus.CounterOpts{
		Name: "providers_requests_total",
		Help: "Outbound provider requests.",
	}, []string{"provider"})

	errorsTotal = prometheus.NewCounterVec(prometheus.CounterOpts{
		Name: "providers_errors_total",
		Help: "Provider request failures by kind (http_4xx|rate_limited|server|network|breaker|parse).",
	}, []string{"provider", "kind"})

	retriesTotal = prometheus.NewCounterVec(prometheus.CounterOpts{
		Name: "providers_retries_total",
		Help: "Retried provider requests after backoff.",
	}, []string{"provider"})

	breakerState = prometheus.NewGaugeVec(prometheus.GaugeOpts{
		Name: "providers_breaker_state",
		Help: "Circuit breaker state: 0 closed, 1 open.",
	}, []string{"provider"})
)

func init() {
	prometheus.MustRegister(requestsTotal, errorsTotal, retriesTotal, breakerState)
}

func countError(provider, kind string) {
	if kind != "" {
		errorsTotal.WithLabelValues(provider, kind).Inc()
	}
}

// Limiter serializes requests at a fixed minimum interval — the simplest
// correct throttle for the low per-provider budgets Athena runs at.
type Limiter struct {
	interval time.Duration
	mu       sync.Mutex
	next     time.Time
}

func NewLimiter(minInterval time.Duration) *Limiter {
	if minInterval <= 0 {
		minInterval = time.Nanosecond
	}
	return &Limiter{interval: minInterval}
}

// Wait blocks until the next slot, or ctx is done.
func (l *Limiter) Wait(ctx context.Context) error {
	l.mu.Lock()
	now := time.Now()
	if l.next.Before(now) {
		l.next = now
	}
	slot := l.next
	l.next = slot.Add(l.interval)
	l.mu.Unlock()

	wait := time.Until(slot)
	if wait <= 0 {
		return nil
	}
	t := time.NewTimer(wait)
	defer t.Stop()
	select {
	case <-ctx.Done():
		return ctx.Err()
	case <-t.C:
		return nil
	}
}

// Breaker trips open after `threshold` consecutive failures and cools down
// before admitting one probe request (half-open).
type Breaker struct {
	threshold int
	cooldown  time.Duration

	mu           sync.Mutex
	consecutive  int
	openedUntil  time.Time
	probePending bool
}

func NewBreaker(threshold int, cooldown time.Duration) *Breaker {
	if threshold <= 0 {
		threshold = 5
	}
	if cooldown <= 0 {
		cooldown = time.Minute
	}
	return &Breaker{threshold: threshold, cooldown: cooldown}
}

func (b *Breaker) Allow() bool {
	b.mu.Lock()
	defer b.mu.Unlock()
	if b.openedUntil.After(time.Now()) {
		return false
	}
	if !b.openedUntil.IsZero() && b.probePending {
		// Half-open window: exactly one probe in flight.
		if time.Now().Before(b.openedUntil.Add(time.Second)) {
			return false
		}
	}
	b.probePending = true
	return true
}

// Record reports a completed attempt; success closes the breaker.
func (b *Breaker) Record(success bool) {
	b.mu.Lock()
	defer b.mu.Unlock()
	b.probePending = false
	if success {
		b.consecutive = 0
		if !b.openedUntil.IsZero() {
			b.openedUntil = time.Time{}
		}
		return
	}
	b.consecutive++
	if b.consecutive >= b.threshold {
		b.openedUntil = time.Now().Add(b.cooldown)
		b.probePending = false
	}
}

// State reports whether the breaker is currently open.
func (b *Breaker) Open() bool {
	b.mu.Lock()
	defer b.mu.Unlock()
	return b.openedUntil.After(time.Now())
}

// Fetcher issues instrumented, rate-limited, breaker-guarded GETs with
// exponential-backoff retries on 429/5xx/network errors.
type Fetcher struct {
	HTTP       *http.Client
	UserAgent  string
	Headers    map[string]string // applied to every request (e.g. api key)
	Limiter    *Limiter
	Breaker    *Breaker
	MaxRetries int
	BaseDelay  time.Duration
}

func NewFetcher(userAgent string, headers map[string]string, limit *Limiter, breaker *Breaker) *Fetcher {
	return &Fetcher{
		HTTP:       &http.Client{Timeout: 45 * time.Second},
		UserAgent:  userAgent,
		Headers:    headers,
		Limiter:    limit,
		Breaker:    breaker,
		MaxRetries: 3,
		BaseDelay:  800 * time.Millisecond,
	}
}

// Get fetches url and returns the body bytes. Errors are classified into the
// sentinel errors above.
func (f *Fetcher) Get(ctx context.Context, providerSlug, url string) ([]byte, error) {
	var lastErr error
	for attempt := 0; ; attempt++ {
		if err := ctx.Err(); err != nil {
			return nil, err
		}
		if f.Breaker != nil && !f.Breaker.Allow() {
			countError(providerSlug, "breaker")
			breakerState.WithLabelValues(providerSlug).Set(1)
			return nil, ErrBreakerOpen
		}
		if err := f.Limiter.Wait(ctx); err != nil {
			return nil, err
		}

		body, status, retryAfter, err := f.do(ctx, url)
		// Breaker treats rate limits and server errors as upstream failure;
		// 4xx means our request was wrong, which says nothing about provider
		// health.
		breakerSuccess := err == nil && status != http.StatusTooManyRequests && status < 500
		if f.Breaker != nil {
			f.Breaker.Record(breakerSuccess)
			gauge := float64(0)
			if f.Breaker.Open() {
				gauge = 1
			}
			breakerState.WithLabelValues(providerSlug).Set(gauge)
		}

		switch {
		case err != nil: // network / timeout
			lastErr = fmt.Errorf("%w: %v", ErrUnavailable, err)
			countError(providerSlug, "network")
		case status == http.StatusTooManyRequests:
			countError(providerSlug, "rate_limited")
			drain(body)
			lastErr = ErrRateLimited
		case status >= 500:
			countError(providerSlug, "server")
			drain(body)
			lastErr = fmt.Errorf("%w: http %d", ErrUnavailable, status)
		case status >= 400:
			countError(providerSlug, "http_4xx")
			drain(body)
			return nil, fmt.Errorf("%w: http %d for %s", ErrRejected, status, redact(url))
		default:
			requestsTotal.WithLabelValues(providerSlug).Inc()
			return io.ReadAll(io.LimitReader(body, 64<<20)) // 64 MiB cap
		}

		if attempt >= f.MaxRetries {
			return nil, lastErr
		}
		retriesTotal.WithLabelValues(providerSlug).Inc()

		delay := f.BaseDelay * time.Duration(1<<attempt)
		delay += time.Duration(rand.Int64N(int64(delay / 4))) // jitter
		if retryAfter > delay {
			delay = retryAfter
		}
		t := time.NewTimer(delay)
		select {
		case <-ctx.Done():
			t.Stop()
			return nil, ctx.Err()
		case <-t.C:
		}
	}
}

func (f *Fetcher) do(ctx context.Context, url string) (io.ReadCloser, int, time.Duration, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return nil, 0, 0, err
	}
	req.Header.Set("Accept", "application/json")
	if f.UserAgent != "" {
		req.Header.Set("User-Agent", f.UserAgent)
	}
	for k, v := range f.Headers {
		req.Header.Set(k, v)
	}
	resp, err := f.HTTP.Do(req)
	if err != nil {
		return nil, 0, 0, err
	}
	retryAfter := time.Duration(0)
	if ra := resp.Header.Get("Retry-After"); ra != "" {
		if secs, perr := strconv.Atoi(ra); perr == nil && secs > 0 {
			retryAfter = time.Duration(secs) * time.Second
		}
	}
	if resp.StatusCode >= 400 {
		// Status classification happens in Get; no transport error here.
		return resp.Body, resp.StatusCode, retryAfter, nil
	}
	return resp.Body, resp.StatusCode, retryAfter, nil
}

func drain(r io.Reader) {
	_, _ = io.Copy(io.Discard, io.LimitReader(r, 1<<20))
}

// redact strips query strings from URLs before logging them: provider keys
// sometimes ride in query parameters.
func redact(url string) string {
	if i := strings.IndexByte(url, '?'); i >= 0 {
		return url[:i]
	}
	return url
}
