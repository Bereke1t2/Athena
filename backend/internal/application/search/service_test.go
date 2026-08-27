package search

import (
	"context"
	"encoding/json"
	"errors"
	"sync"
	"testing"

	domainsearch "athena/backend/internal/domain/search"
)

func jsonMarshal(v any) ([]byte, error) { return json.Marshal(v) }

type stubCache struct {
	mu     sync.Mutex
	store  map[string][]byte
	getErr error
}

func newStubCache() *stubCache { return &stubCache{store: map[string][]byte{}} }

func (s *stubCache) GetJSON(_ context.Context, _, key string) ([]byte, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.getErr != nil {
		return nil, s.getErr
	}
	return s.store[key], nil
}

func (s *stubCache) SetJSON(_ context.Context, _, key string, v any) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	b, _ := jsonMarshal(v)
	s.store[key] = b
	return nil
}

type countingEngine struct {
	calls int
	page  domainsearch.ResultPage
}

func (e *countingEngine) Search(context.Context, domainsearch.Query) (domainsearch.ResultPage, error) {
	e.calls++
	return e.page, nil
}
func (*countingEngine) Related(context.Context, domainsearch.UUID, int) ([]domainsearch.ScoredPaper, error) {
	return nil, nil
}

func TestSearchCachesSecondCall(t *testing.T) {
	engine := &countingEngine{page: domainsearch.ResultPage{ModeUsed: domainsearch.ModeKeyword}}
	svc := NewService(engine, newStubCache())
	ctx := context.Background()

	q, err := domainsearch.NewQuery("transformers", "", "", 0)
	if err != nil {
		t.Fatal(err)
	}

	for i := 0; i < 3; i++ {
		if _, err := svc.Search(ctx, q); err != nil {
			t.Fatalf("call %d: %v", i, err)
		}
	}
	if engine.calls != 1 {
		t.Fatalf("engine hit %d times; want 1 (cache should absorb repeats)", engine.calls)
	}
}

func TestDifferentQueriesMissSeparately(t *testing.T) {
	engine := &countingEngine{}
	svc := NewService(engine, newStubCache())
	ctx := context.Background()

	q1, _ := domainsearch.NewQuery("a", "", "", 0)
	q2, _ := domainsearch.NewQuery("b", "", "", 0)
	_, _ = svc.Search(ctx, q1)
	_, _ = svc.Search(ctx, q2)

	if engine.calls != 2 {
		t.Fatalf("want 2 distinct engine calls, got %d", engine.calls)
	}
}

func TestNilCacheBypasses(t *testing.T) {
	engine := &countingEngine{}
	svc := NewService(engine, nil)

	q, _ := domainsearch.NewQuery("q", "", "", 0)
	for i := 0; i < 2; i++ {
		_, _ = svc.Search(context.Background(), q)
	}
	if engine.calls != 2 {
		t.Fatalf("nil cache must not dedupe; calls=%d", engine.calls)
	}
}

func TestEngineErrorNotCachedAndPropagates(t *testing.T) {
	want := errors.New("boom")
	svc := NewService(failingEngine{want}, newStubCache())

	q, _ := domainsearch.NewQuery("q", "", "", 0)
	if _, err := svc.Search(context.Background(), q); !errors.Is(err, want) {
		t.Fatalf("expected engine error, got %v", err)
	}
}

type failingEngine struct{ err error }

func (f failingEngine) Search(context.Context, domainsearch.Query) (domainsearch.ResultPage, error) {
	return domainsearch.ResultPage{}, f.err
}
func (failingEngine) Related(context.Context, domainsearch.UUID, int) ([]domainsearch.ScoredPaper, error) {
	return nil, nil
}
