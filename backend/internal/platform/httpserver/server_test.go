package httpserver

import (
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	v1 "athena/backend/internal/delivery/http/v1"
)

func TestPlatformEndpoints(t *testing.T) {
	deps := Deps{Ping: func() error { return nil }}
	srv := New(deps)

	t.Run("healthz", func(t *testing.T) {
		rec := httptest.NewRecorder()
		srv.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/healthz", nil))
		if rec.Code != http.StatusOK || !strings.Contains(rec.Body.String(), "ok") {
			t.Fatalf("healthz = %d %s", rec.Code, rec.Body.String())
		}
	})

	t.Run("readyz ok", func(t *testing.T) {
		rec := httptest.NewRecorder()
		srv.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/readyz", nil))
		if rec.Code != http.StatusOK || !strings.Contains(rec.Body.String(), "ready") {
			t.Fatalf("readyz = %d %s", rec.Code, rec.Body.String())
		}
	})

	t.Run("metrics", func(t *testing.T) {
		rec := httptest.NewRecorder()
		srv.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/metrics", nil))
		if rec.Code != http.StatusOK {
			t.Fatalf("metrics = %d", rec.Code)
		}
	})
}

func TestReadyzFailsWhenDBDown(t *testing.T) {
	deps := Deps{Ping: func() error { return errors.New("boom") }}
	srv := New(deps)
	rec := httptest.NewRecorder()
	srv.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/readyz", nil))
	if rec.Code != http.StatusServiceUnavailable {
		t.Fatalf("readyz = %d, want 503", rec.Code)
	}
}

func TestResearchRoutesMounted(t *testing.T) {
	h := v1.NewResearchHandlers(nil, nil) // reader unused: validation rejects first
	deps := Deps{
		Research: h,
		Ping:     func() error { return nil },
	}
	srv := New(deps)

	rec := httptest.NewRecorder()
	srv.ServeHTTP(rec, httptest.NewRequest(http.MethodGet,
		"/api/v1/research/papers?sort=bogus", nil))
	if rec.Code != http.StatusBadRequest {
		t.Fatalf("list = %d %s", rec.Code, rec.Body.String())
	}

	// Unknown routes must not fall through to other methods.
	rec = httptest.NewRecorder()
	srv.ServeHTTP(rec, httptest.NewRequest(http.MethodDelete,
		"/api/v1/research/papers/123", nil))
	if rec.Code != http.StatusMethodNotAllowed {
		t.Fatalf("delete = %d, want 405", rec.Code)
	}
}

func TestRequestIDEchoed(t *testing.T) {
	deps := Deps{Ping: func() error { return nil }}
	srv := New(deps)
	req := httptest.NewRequest(http.MethodGet, "/healthz", nil)
	req.Header.Set("X-Request-ID", "test-req-1")
	rec := httptest.NewRecorder()
	srv.ServeHTTP(rec, req)
	if got := rec.Header().Get("X-Request-ID"); got != "test-req-1" {
		t.Fatalf("X-Request-ID = %q, want echo", got)
	}
}
