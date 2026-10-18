package feed

import (
	"context"
	"errors"
	"testing"

	"github.com/google/uuid"

	"athena/backend/internal/domain/research"
)

func testPaperID() (id uuid.UUID) {
	return uuid.MustParse("00000000-0000-0000-0000-000000000001")
}

type fakeSource struct {
	research.PaperReader
	onList     func(q research.ListQuery) ([]research.PaperSummary, string, error)
	onTrend    func(slugs []string) ([]research.PaperSummary, error)
	listCalls  []research.ListQuery
	trendCalls [][]string
}

func (f *fakeSource) ListPapers(_ context.Context, q research.ListQuery) ([]research.PaperSummary, string, error) {
	f.listCalls = append(f.listCalls, q)
	return f.onList(q)
}

func (f *fakeSource) Trending(_ context.Context, slugs []string, _ string, _ int) ([]research.PaperSummary, error) {
	f.trendCalls = append(f.trendCalls, slugs)
	return f.onTrend(slugs)
}

func TestLatestTopicFallbackOnZeroResults(t *testing.T) {
	src := &fakeSource{
		onList: func(q research.ListQuery) ([]research.PaperSummary, string, error) {
			if len(q.TopicSlugs) > 0 {
				return nil, "", nil
			}
			p := research.PaperSummary{ID: testPaperID(), Title: "Fresh paper"}
			return []research.PaperSummary{p}, "continuation-token", nil
		},
	}
	svc := NewService(src)

	items, next, err := svc.Get(context.Background(), SectionLatest,
		[]string{"machine-learning"}, "", "", 20)
	if err != nil {
		t.Fatal(err)
	}
	if len(items) != 1 || items[0].Reason != fallbackReason {
		t.Fatalf("want fallback item with reason %q, got %+v", fallbackReason, items)
	}
	if next != fallbackCursorPrefix+"continuation-token" {
		t.Fatalf("fallback cursor not prefixed: %q", next)
	}
	if len(src.listCalls) != 2 || src.listCalls[0].TopicSlugs == nil || src.listCalls[1].TopicSlugs != nil {
		t.Fatalf("expected filtered call then unfiltered retry: %+v", src.listCalls)
	}
}

func TestLatestContinuationAfterFallbackSkipsTopics(t *testing.T) {
	var seen research.ListQuery
	src := &fakeSource{
		onList: func(q research.ListQuery) ([]research.PaperSummary, string, error) {
			seen = q
			return nil, "", nil
		},
	}
	svc := NewService(src)

	if _, _, err := svc.Get(context.Background(), SectionLatest,
		[]string{"machine-learning"}, "", "~tok", 20); err != nil {
		t.Fatal(err)
	}
	if seen.Cursor != "tok" || seen.TopicSlugs != nil {
		t.Fatalf("continuation must strip prefix and skip topics, got %+v", seen)
	}
}

func TestLatestNoFallbackMidPagination(t *testing.T) {
	src := &fakeSource{
		onList: func(q research.ListQuery) ([]research.PaperSummary, string, error) {
			return nil, "", nil // empty page two is a legitimate end
		},
	}
	svc := NewService(src)

	items, _, err := svc.Get(context.Background(), SectionLatest,
		[]string{"machine-learning"}, "", "real-cursor", 20)
	if err != nil {
		t.Fatal(err)
	}
	if len(items) != 0 {
		t.Fatalf("page two must stay empty, got %+v", items)
	}
	if len(src.listCalls) != 1 {
		t.Fatalf("no retry expected past page one, calls: %d", len(src.listCalls))
	}
}

func TestLatestUnfilteredNeverRetries(t *testing.T) {
	src := &fakeSource{
		onList: func(q research.ListQuery) ([]research.PaperSummary, string, error) {
			return nil, "", nil
		},
	}
	svc := NewService(src)

	if _, _, err := svc.Get(context.Background(), SectionLatest, nil, "", "", 20); err != nil {
		t.Fatal(err)
	}
	if len(src.listCalls) != 1 {
		t.Fatalf("unfiltered empty page must not retry, calls: %d", len(src.listCalls))
	}
}

func TestListErrorNotMasked(t *testing.T) {
	boom := errors.New("db down")
	src := &fakeSource{
		onList: func(research.ListQuery) ([]research.PaperSummary, string, error) {
			return nil, "", boom
		},
	}
	svc := NewService(src)
	if _, _, err := svc.Get(context.Background(), SectionLatest,
		[]string{"x"}, "", "", 20); !errors.Is(err, boom) {
		t.Fatalf("want original error, got %v", err)
	}
}

func TestTrendingTopicFallback(t *testing.T) {
	src := &fakeSource{
		onTrend: func(slugs []string) ([]research.PaperSummary, error) {
			if len(slugs) > 0 {
				return nil, nil
			}
			return []research.PaperSummary{{ID: testPaperID(), Title: "Hot"}}, nil
		},
	}
	svc := NewService(src)

	items, _, err := svc.Get(context.Background(), SectionTrending,
		[]string{"physics"}, "", "", 20)
	if err != nil {
		t.Fatal(err)
	}
	if len(items) != 1 || items[0].Section != SectionTrending ||
		items[0].Reason != fallbackReason {
		t.Fatalf("unexpected trending fallback items %+v", items)
	}
	if len(src.trendCalls) != 2 || src.trendCalls[0] == nil || src.trendCalls[1] != nil {
		t.Fatalf("expected filtered then unfiltered trending calls: %v", src.trendCalls)
	}
}

func TestRecommendedFeedRankingAndFallback(t *testing.T) {
	src := &fakeSource{
		onList: func(q research.ListQuery) ([]research.PaperSummary, string, error) {
			if len(q.TopicSlugs) > 0 {
				p := research.PaperSummary{
					ID:           testPaperID(),
					Title:        "Attention Is All You Need for Natural Language Processing",
					CitedByCount: 100,
				}
				return []research.PaperSummary{p}, "", nil
			}
			return nil, "", nil
		},
	}
	svc := NewService(src)

	items, _, err := svc.Get(context.Background(), SectionRecommended, []string{"natural-language-processing"}, "", "", 10)
	if err != nil {
		t.Fatalf("recommended feed failed: %v", err)
	}
	if len(items) != 1 || items[0].Section != SectionRecommended {
		t.Fatalf("expected 1 recommended item, got %+v", items)
	}
	if items[0].Reason != "matches your focus on natural language processing" {
		t.Fatalf("expected specific topic reason, got %q", items[0].Reason)
	}
}
