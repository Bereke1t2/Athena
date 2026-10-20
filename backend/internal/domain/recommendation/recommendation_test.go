package recommendation_test

import (
	"testing"
	"time"

	"github.com/google/uuid"

	domainrec "athena/backend/internal/domain/recommendation"
	"athena/backend/internal/domain/research"
)

func TestRankPapers_Empty(t *testing.T) {
	profile := domainrec.NewAffinityProfile(uuid.New())
	results := domainrec.RankPapers(nil, profile, time.Now())
	if results != nil {
		t.Fatalf("expected nil results for empty input, got %v", results)
	}
}

func TestRankPapers_ScoringAndOrdering(t *testing.T) {
	now := time.Date(2026, 10, 20, 12, 0, 0, 0, time.UTC)
	pubRecent := now.Add(-24 * time.Hour)
	pubOld := now.Add(-365 * 24 * time.Hour)

	absQuantum := "A breakthrough in quantum computing algorithms and fault tolerance."
	absBio := "Advances in CRISPR genetic sequencing and cellular biology."

	p1 := research.PaperSummary{
		ID:           uuid.New(),
		Title:        "Quantum Computing Architectures",
		Abstract:     &absQuantum,
		CitedByCount: 100,
		PublishedOn:  &pubRecent,
	}

	p2 := research.PaperSummary{
		ID:           uuid.New(),
		Title:        "Ancient History Overview",
		Abstract:     &absBio,
		CitedByCount: 5,
		PublishedOn:  &pubOld,
	}

	profile := domainrec.NewAffinityProfile(uuid.New())
	profile.TopicWeights["quantum-computing"] = 2.0

	ranked := domainrec.RankPapers([]research.PaperSummary{p2, p1}, profile, now)
	if len(ranked) != 2 {
		t.Fatalf("expected 2 ranked papers, got %d", len(ranked))
	}

	if ranked[0].Paper.ID != p1.ID {
		t.Errorf("expected p1 (quantum) to rank first, got %s", ranked[0].Paper.Title)
	}

	if ranked[0].Score <= ranked[1].Score {
		t.Errorf("expected score %f > %f", ranked[0].Score, ranked[1].Score)
	}

	if ranked[0].MatchReason == "" {
		t.Errorf("expected non-empty MatchReason for matched topic")
	}
}
