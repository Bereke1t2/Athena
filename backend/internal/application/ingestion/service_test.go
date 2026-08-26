package ingestion

import (
	"context"
	"errors"
	"fmt"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"

	"athena/backend/internal/domain/research"
)

// ---- fakes -----------------------------------------------------------------

type fakeProvider struct {
	slug  string
	pages []research.Page
	err   error
	calls int
}

func (f *fakeProvider) Slug() string { return f.slug }

func (f *fakeProvider) FetchWindow(_ context.Context, w research.Window) (research.Page, error) {
	f.calls++
	if f.err != nil {
		return research.Page{}, f.err
	}
	idx := 0
	if w.Cursor != "" {
		fmt.Sscanf(w.Cursor, "page-%d", &idx)
	}
	if idx >= len(f.pages) {
		return research.Page{}, nil
	}
	return f.pages[idx], nil
}

func mkPaper(native string, refs ...research.Identifier) research.Paper {
	p := research.Paper{
		Title:         "Paper " + native,
		Identifiers:   []research.Identifier{{Type: research.IDTypeOpenAlex, Value: native}},
		ReferencedIDs: refs,
		Provenance: research.Provenance{
			ProviderSlug: "test",
			NativeID:     native,
			FetchedAt:    time.Now().UTC(),
		},
	}
	research.DeriveIdentity(&p)
	return p
}

type fakeWriter struct {
	mu        sync.Mutex
	upserts   int
	conflicts int
	results   map[string]research.UpsertResult
}

func newFakeWriter() *fakeWriter {
	return &fakeWriter{results: map[string]research.UpsertResult{}}
}

func (f *fakeWriter) UpsertPaper(_ context.Context, p research.Paper) (research.UpsertResult, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.upserts++
	if p.Provenance.NativeID == "conflict-me" {
		f.conflicts++
		return research.UpsertResult{}, research.ErrIdentityConflict
	}
	res := research.UpsertResult{PaperID: uuid.New(), Created: true, ContentChanged: true}
	if prev, ok := f.results[p.Provenance.NativeID]; ok {
		res = research.UpsertResult{PaperID: prev.PaperID, Created: false, ContentChanged: false}
	}
	f.results[p.Provenance.NativeID] = res
	return res, nil
}

func (f *fakeWriter) ResolveCitationEdges(_ context.Context, _ uuid.UUID, refs []research.Identifier) (int, error) {
	return len(refs), nil
}

type fakeLedger struct {
	started   []string
	finished  map[uuid.UUID]string
	cursorFor string
	hasCursor bool
}

func newFakeLedger() *fakeLedger {
	return &fakeLedger{finished: map[uuid.UUID]string{}}
}

func (l *fakeLedger) StartRun(_ context.Context, sourceSlug, _ string, _, _ *time.Time) (uuid.UUID, error) {
	id := uuid.New()
	l.started = append(l.started, sourceSlug)
	return id, nil
}

func (l *fakeLedger) FinishRun(_ context.Context, runID uuid.UUID, status string, _ RunStats) error {
	l.finished[runID] = status
	return nil
}

func (l *fakeLedger) SaveSyncCursor(_ context.Context, slug string, _ SyncCursor) error {
	l.cursorFor = slug
	l.hasCursor = true
	return nil
}

func (l *fakeLedger) LoadSyncCursor(context.Context, string) (*SyncCursor, error) {
	if !l.hasCursor {
		return nil, nil
	}
	return &SyncCursor{NextCursor: "resumed"}, nil
}

func (l *fakeLedger) ClearSyncCursor(context.Context, string) error {
	l.hasCursor = false
	l.cursorFor = ""
	return nil
}

// ---- tests -------------------------------------------------------------------

func TestSyncWindowHappyPath(t *testing.T) {
	prov := &fakeProvider{
		slug: "test",
		pages: []research.Page{
			{Papers: []research.Paper{
				mkPaper("W1", research.Identifier{Type: research.IDTypeOpenAlex, Value: "R1"}),
				mkPaper("W2"),
			}, NextCursor: "page-1"},
			{Papers: []research.Paper{mkPaper("W3")}},
		},
	}
	writer := newFakeWriter()
	ledger := newFakeLedger()
	svc := NewService(Providers{"test": prov}, writer, ledger, nil)

	stats, err := svc.SyncWindow(context.Background(), SyncWindowArgs{
		ProviderSlug: "test",
		From:         time.Now(),
		To:           time.Now().Add(time.Hour),
	})
	if err != nil {
		t.Fatal(err)
	}
	if stats.PagesFetched != 2 || stats.ItemsSeen != 3 || stats.Created != 3 {
		t.Fatalf("stats wrong: %+v", stats)
	}
	if stats.EdgesLinked != 1 {
		t.Fatalf("citation edges not linked: %+v", stats)
	}
	if len(ledger.started) != 1 || ledger.finished == nil {
		t.Fatalf("ledger not driven: %+v", ledger)
	}
	for _, status := range ledger.finished {
		if status != "succeeded" {
			t.Fatalf("expected succeeded run, got %q", status)
		}
	}
	if prov.calls != 2 || stats.NextCursor != "" {
		t.Fatalf("pagination wrong: calls=%d next=%q", prov.calls, stats.NextCursor)
	}
}

func TestSyncWindowCountsConflicts(t *testing.T) {
	prov := &fakeProvider{slug: "test", pages: []research.Page{
		{Papers: []research.Paper{mkPaper("conflict-me"), mkPaper("ok")}},
	}}
	svc := NewService(Providers{"test": prov}, newFakeWriter(), newFakeLedger(), nil)

	stats, err := svc.SyncWindow(context.Background(), SyncWindowArgs{ProviderSlug: "test"})
	if err != nil {
		t.Fatal(err)
	}
	if stats.Conflicts != 1 || stats.Created != 1 || stats.ItemsSeen != 2 {
		t.Fatalf("conflict handling wrong: %+v", stats)
	}
}

func TestSyncWindowFetchFailureFailsRun(t *testing.T) {
	prov := &fakeProvider{slug: "test", err: errors.New("boom")}
	ledger := newFakeLedger()
	svc := NewService(Providers{"test": prov}, newFakeWriter(), ledger, nil)

	_, err := svc.SyncWindow(context.Background(), SyncWindowArgs{ProviderSlug: "test"})
	if err == nil {
		t.Fatal("expected fetch failure to propagate for job retry")
	}
	for _, status := range ledger.finished {
		if status != "failed" {
			t.Fatalf("run should be failed, got %q", status)
		}
	}
}

func TestSyncWindowUnknownProvider(t *testing.T) {
	svc := NewService(Providers{}, newFakeWriter(), newFakeLedger(), nil)
	if _, err := svc.SyncWindow(context.Background(), SyncWindowArgs{ProviderSlug: "nope"}); !errors.Is(err, ErrUnknownProvider) {
		t.Fatalf("want ErrUnknownProvider, got %v", err)
	}
}

func TestSyncWindowMaxPagesResumesWithCursor(t *testing.T) {
	prov := &fakeProvider{slug: "test", pages: []research.Page{
		{Papers: []research.Paper{mkPaper("W1")}, NextCursor: "page-1"},
		{Papers: []research.Paper{mkPaper("W2")}, NextCursor: "page-2"},
		{Papers: []research.Paper{mkPaper("W3")}},
	}}
	ledger := newFakeLedger()
	svc := NewService(Providers{"test": prov}, newFakeWriter(), ledger, nil)

	stats, err := svc.SyncWindow(context.Background(), SyncWindowArgs{
		ProviderSlug: "test", MaxPages: 2})
	if err != nil {
		t.Fatal(err)
	}
	if stats.PagesFetched != 2 || stats.NextCursor != "page-2" {
		t.Fatalf("bounded sync wrong: %+v", stats)
	}
	if !ledger.hasCursor || ledger.cursorFor != "test" {
		t.Fatalf("resumption cursor not persisted: %+v", ledger)
	}
}

// ---- cache invalidation --------------------------------------------------------

type fakeInvalidator struct {
	calls int
	err   error
}

func (f *fakeInvalidator) InvalidateSearch(context.Context) error {
	f.calls++
	return f.err
}

func newSyncSvc(prov *fakeProvider, writer *fakeWriter, ledger *fakeLedger, inv *fakeInvalidator) *Service {
	svc := NewService(Providers{"test": prov}, writer, ledger, nil)
	if inv != nil {
		svc.Cache = inv
	}
	return svc
}

func syncArgs() SyncWindowArgs {
	return SyncWindowArgs{ProviderSlug: "test", From: time.Now(), To: time.Now().Add(time.Hour)}
}

func TestCacheInvalidatedOnFreshData(t *testing.T) {
	prov := &fakeProvider{slug: "test", pages: []research.Page{
		{Papers: []research.Paper{mkPaper("fresh-1")}},
	}}
	inv := &fakeInvalidator{}
	svc := newSyncSvc(prov, newFakeWriter(), newFakeLedger(), inv)

	if _, err := svc.SyncWindow(context.Background(), syncArgs()); err != nil {
		t.Fatal(err)
	}
	if inv.calls != 1 {
		t.Fatalf("expected exactly one invalidation, got %d", inv.calls)
	}
}

func TestNoInvalidationWhenNothingChanged(t *testing.T) {
	prov := &fakeProvider{slug: "test", pages: []research.Page{{}}}
	inv := &fakeInvalidator{}
	svc := newSyncSvc(prov, newFakeWriter(), newFakeLedger(), inv)

	if _, err := svc.SyncWindow(context.Background(), syncArgs()); err != nil {
		t.Fatal(err)
	}
	if inv.calls != 0 {
		t.Fatalf("empty page must not invalidate; calls=%d", inv.calls)
	}
}

func TestNoInvalidationOnFailedRun(t *testing.T) {
	prov := &fakeProvider{slug: "test", err: fmt.Errorf("provider down")}
	inv := &fakeInvalidator{}
	svc := newSyncSvc(prov, newFakeWriter(), newFakeLedger(), inv)

	if _, err := svc.SyncWindow(context.Background(), syncArgs()); err == nil {
		t.Fatal("expected error from failed provider")
	}
	if inv.calls != 0 {
		t.Fatalf("failed run must not invalidate; calls=%d", inv.calls)
	}
}

func TestInvalidationErrorDoesNotFailRun(t *testing.T) {
	prov := &fakeProvider{slug: "test", pages: []research.Page{
		{Papers: []research.Paper{mkPaper("fresh-2")}},
	}}
	inv := &fakeInvalidator{err: errors.New("redis down")}
	svc := newSyncSvc(prov, newFakeWriter(), newFakeLedger(), inv)

	stats, err := svc.SyncWindow(context.Background(), syncArgs())
	if err != nil {
		t.Fatalf("cache failure must degrade to warn log, got %v", err)
	}
	if stats.Created != 1 || inv.calls != 1 {
		t.Fatalf("unexpected: %+v calls=%d", stats, inv.calls)
	}
}

func TestNilCacheIsFine(t *testing.T) {
	prov := &fakeProvider{slug: "test", pages: []research.Page{
		{Papers: []research.Paper{mkPaper("fresh-3")}},
	}}
	svc := newSyncSvc(prov, newFakeWriter(), newFakeLedger(), nil)
	if _, err := svc.SyncWindow(context.Background(), syncArgs()); err != nil {
		t.Fatal(err)
	}
}
