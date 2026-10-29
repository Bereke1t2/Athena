package v1

import (
	"io"
	"net/http"
	"net/http/httptest"
	"sync/atomic"
	"testing"
	"time"
)

func TestWithIdempotency(t *testing.T) {
	store := NewMemoryIdempotencyStore()
	var callCount int32

	handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		atomic.AddInt32(&callCount, 1)
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusCreated)
		_, _ = w.Write([]byte(`{"result":"created"}`))
	})

	stack := WithIdempotency(store, 1*time.Minute, handler)

	// 1. Without Idempotency-Key -> not cached, handler called each time
	req1 := httptest.NewRequest(http.MethodPost, "/api/v1/research/papers/export", nil)
	w1 := httptest.NewRecorder()
	stack.ServeHTTP(w1, req1)
	if w1.Code != http.StatusCreated || atomic.LoadInt32(&callCount) != 1 {
		t.Fatalf("first call: code=%d, count=%d", w1.Code, callCount)
	}

	req2 := httptest.NewRequest(http.MethodPost, "/api/v1/research/papers/export", nil)
	w2 := httptest.NewRecorder()
	stack.ServeHTTP(w2, req2)
	if w2.Code != http.StatusCreated || atomic.LoadInt32(&callCount) != 2 {
		t.Fatalf("second call without key: code=%d, count=%d", w2.Code, callCount)
	}

	// 2. With Idempotency-Key -> first call executes handler
	req3 := httptest.NewRequest(http.MethodPost, "/api/v1/research/papers/export", nil)
	req3.Header.Set("Idempotency-Key", "key-xyz-123")
	w3 := httptest.NewRecorder()
	stack.ServeHTTP(w3, req3)
	if w3.Code != http.StatusCreated || atomic.LoadInt32(&callCount) != 3 {
		t.Fatalf("third call with key: code=%d, count=%d", w3.Code, callCount)
	}
	body3, _ := io.ReadAll(w3.Body)

	// 3. Duplicate request with same Idempotency-Key -> replayed from cache without calling handler
	req4 := httptest.NewRequest(http.MethodPost, "/api/v1/research/papers/export", nil)
	req4.Header.Set("Idempotency-Key", "key-xyz-123")
	w4 := httptest.NewRecorder()
	stack.ServeHTTP(w4, req4)
	if w4.Code != http.StatusCreated {
		t.Fatalf("fourth call with same key: code=%d", w4.Code)
	}
	if atomic.LoadInt32(&callCount) != 3 {
		t.Fatalf("handler should not have been called on duplicate idempotency key, count=%d", callCount)
	}
	if w4.Header().Get("X-Cache-Lookup") != "HIT" {
		t.Fatalf("expected X-Cache-Lookup: HIT, got %s", w4.Header().Get("X-Cache-Lookup"))
	}
	body4, _ := io.ReadAll(w4.Body)
	if string(body3) != string(body4) {
		t.Fatalf("cached body mismatch: %q vs %q", string(body3), string(body4))
	}
}
