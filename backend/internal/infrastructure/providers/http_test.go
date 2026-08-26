package providers

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

func TestLimiterSpacesRequests(t *testing.T) {
	l := NewLimiter(20 * time.Millisecond)
	start := time.Now()
	for i := 0; i < 3; i++ {
		if err := l.Wait(context.Background()); err != nil {
			t.Fatal(err)
		}
	}
	if elapsed := time.Since(start); elapsed < 40*time.Millisecond {
		t.Fatalf("limiter did not space requests: %v", elapsed)
	}
}

func TestBreakerOpensAndRecovers(t *testing.T) {
	b := NewBreaker(3, 30*time.Millisecond)
	for i := 0; i < 3; i++ {
		if !b.Allow() {
			t.Fatalf("attempt %d: expected allow while closed", i)
		}
		b.Record(false)
	}
	if !b.Open() {
		t.Fatal("breaker should be open after 3 consecutive failures")
	}
	if b.Allow() {
		t.Fatal("open breaker must not admit requests")
	}
	time.Sleep(35 * time.Millisecond)
	if !b.Allow() {
		t.Fatal("breaker should admit a probe after cooldown")
	}
	b.Record(true)
	if b.Open() {
		t.Fatal("success should close the breaker")
	}
}

func TestFetcherRetriesThenSucceeds(t *testing.T) {
	calls := 0
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		calls++
		if calls < 3 {
			w.WriteHeader(http.StatusInternalServerError)
			return
		}
		_, _ = w.Write([]byte(`{"ok":true}`))
	}))
	defer srv.Close()

	f := NewFetcher("test", nil, NewLimiter(time.Millisecond), NewBreaker(10, time.Minute))
	f.BaseDelay = time.Millisecond

	body, err := f.Get(context.Background(), "test", srv.URL)
	if err != nil {
		t.Fatalf("expected success after retries: %v", err)
	}
	if string(body) != `{"ok":true}` {
		t.Fatalf("unexpected body %q", body)
	}
	if calls != 3 {
		t.Fatalf("expected 3 calls, got %d", calls)
	}
}

func TestFetcherMapsClientErrorWithoutRetry(t *testing.T) {
	calls := 0
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		calls++
		http.Error(w, "nope", http.StatusNotFound)
	}))
	defer srv.Close()

	f := NewFetcher("test", nil, NewLimiter(time.Millisecond), NewBreaker(10, time.Minute))
	if _, err := f.Get(context.Background(), "test", srv.URL+"/x?secret=1"); err == nil {
		t.Fatal("expected error on 404")
	}
	if calls != 1 {
		t.Fatalf("4xx must not be retried; got %d calls", calls)
	}
}

func TestFetcherBreakerOpensAfterFailures(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusBadGateway)
	}))
	defer srv.Close()

	b := NewBreaker(2, time.Minute)
	f := NewFetcher("test", nil, NewLimiter(time.Millisecond), b)
	f.MaxRetries = 1
	f.BaseDelay = time.Millisecond

	for i := 0; i < 2; i++ {
		if _, err := f.Get(context.Background(), "test", srv.URL); err == nil {
			t.Fatal("expected failure")
		}
	}
	err := func() error {
		_, err := f.Get(context.Background(), "test", srv.URL)
		return err
	}()
	if err != ErrBreakerOpen {
		t.Fatalf("want ErrBreakerOpen, got %v", err)
	}
}
