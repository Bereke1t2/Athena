package search

import (
	"context"
	"errors"
	"testing"

	"github.com/google/uuid"
)

func TestNewQueryDefaults(t *testing.T) {
	q, err := NewQuery("attention", "", "", 0)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if q.Mode != ModeAuto || q.Sort != SortRelevance || q.Limit != 20 {
		t.Fatalf("defaults not applied: %+v", q)
	}
}

func TestNewQueryValidation(t *testing.T) {
	cases := []struct {
		name   string
		mode   Mode
		sort   Sort
		limit  int
		wantOK bool
	}{
		{"valid keyword", ModeKeyword, SortNewest, 50, true},
		{"semantic accepted (degrades later)", ModeSemantic, SortRelevance, 0, true},
		{"hybrid accepted", ModeHybrid, "", 0, true},
		{"bad mode", Mode("vector"), "", 0, false},
		{"bad sort", "", Sort("hot"), 0, false},
		{"limit too high", "", "", 101, false},
		{"limit zero uses default", "", "", 0, true},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			_, err := NewQuery("q", tc.mode, tc.sort, tc.limit)
			if tc.wantOK != (err == nil) {
				t.Fatalf("wantOK=%v, err=%v", tc.wantOK, err)
			}
			if !tc.wantOK && !errors.Is(err, ErrInvalidQuery) {
				t.Fatalf("expected ErrInvalidQuery, got %v", err)
			}
		})
	}
}

func TestSearcherInterfaceShape(t *testing.T) {
	// Compile-time assurance the port stays engine-agnostic.
	var _ interface {
		Search(context.Context, Query) (ResultPage, error)
		Related(context.Context, uuid.UUID, int) ([]ScoredPaper, error)
	} = fakeEngine{}
}

type fakeEngine struct{}

func (fakeEngine) Search(context.Context, Query) (ResultPage, error) { return ResultPage{}, nil }
func (fakeEngine) Related(context.Context, uuid.UUID, int) ([]ScoredPaper, error) {
	return nil, nil
}
