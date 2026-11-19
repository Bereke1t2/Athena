package research_test

import (
	"context"
	"testing"

	"github.com/google/uuid"

	appresearch "athena/backend/internal/application/research"
	domainresearch "athena/backend/internal/domain/research"
)

type fakeAuthorityStore struct {
	nodes   []uuid.UUID
	edges   []domainresearch.GraphEdge
	updated map[uuid.UUID]float64
	seminal map[uuid.UUID]bool
}

func (f *fakeAuthorityStore) GetCitationEdgesForScoring(ctx context.Context) ([]domainresearch.GraphEdge, []uuid.UUID, error) {
	return f.edges, f.nodes, nil
}

func (f *fakeAuthorityStore) UpdatePaperAuthorityScores(ctx context.Context, scores map[uuid.UUID]float64, seminalIDs map[uuid.UUID]bool) (int, error) {
	f.updated = scores
	f.seminal = seminalIDs
	return len(scores), nil
}

func TestAuthorityService_EmptyGraph(t *testing.T) {
	store := &fakeAuthorityStore{}
	svc := appresearch.NewAuthorityService(store, nil, nil)

	res, err := svc.ComputeAndStore(context.Background())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if res.PapersScored != 0 {
		t.Errorf("expected 0 papers scored, got %d", res.PapersScored)
	}
	if res.SeminalPapersIdentified != 0 {
		t.Errorf("expected 0 seminal papers, got %d", res.SeminalPapersIdentified)
	}
}

func TestAuthorityService_StarNetwork_SeminalPaperIdentified(t *testing.T) {
	// Paper A is cited by B, C, D, E
	idA := uuid.New()
	idB := uuid.New()
	idC := uuid.New()
	idD := uuid.New()
	idE := uuid.New()

	nodes := []uuid.UUID{idA, idB, idC, idD, idE}
	edges := []domainresearch.GraphEdge{
		{Source: idB, Target: idA, IsInfluential: true, Stance: domainresearch.StanceSupports},
		{Source: idC, Target: idA, IsInfluential: false, Stance: domainresearch.StanceSupports},
		{Source: idD, Target: idA, IsInfluential: true, Stance: domainresearch.StanceMentions},
		{Source: idE, Target: idA, IsInfluential: false, Stance: domainresearch.StanceMentions},
	}

	store := &fakeAuthorityStore{nodes: nodes, edges: edges}
	svc := appresearch.NewAuthorityService(store, nil, nil)

	res, err := svc.ComputeAndStore(context.Background())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if res.PapersScored != 5 {
		t.Errorf("expected 5 scored, got %d", res.PapersScored)
	}
	if res.SeminalPapersIdentified != 1 {
		t.Errorf("expected 1 seminal paper, got %d", res.SeminalPapersIdentified)
	}

	if !store.seminal[idA] {
		t.Errorf("expected Paper A to be identified as seminal")
	}
	if store.seminal[idB] || store.seminal[idC] {
		t.Errorf("expected citing papers not to be seminal")
	}

	if store.updated[idA] <= store.updated[idB] {
		t.Errorf("expected Paper A authority (%f) > Paper B (%f)", store.updated[idA], store.updated[idB])
	}
}

func TestAuthorityService_ChainNetwork_TransitiveAuthority(t *testing.T) {
	// A cites B, and B cites C
	// C should receive cumulative transitive authority and have highest rank
	idA := uuid.New()
	idB := uuid.New()
	idC := uuid.New()

	nodes := []uuid.UUID{idA, idB, idC}
	edges := []domainresearch.GraphEdge{
		{Source: idA, Target: idB, IsInfluential: false, Stance: domainresearch.StanceMentions},
		{Source: idB, Target: idC, IsInfluential: true, Stance: domainresearch.StanceSupports},
	}

	store := &fakeAuthorityStore{nodes: nodes, edges: edges}
	svc := appresearch.NewAuthorityService(store, nil, nil)

	res, err := svc.ComputeAndStore(context.Background())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if res.PapersScored != 3 {
		t.Fatalf("expected 3 scored, got %d", res.PapersScored)
	}

	scoreC := store.updated[idC]
	scoreB := store.updated[idB]
	scoreA := store.updated[idA]

	if scoreC <= scoreB {
		t.Errorf("expected score C (%f) > score B (%f)", scoreC, scoreB)
	}
	if scoreB <= scoreA {
		t.Errorf("expected score B (%f) > score A (%f)", scoreB, scoreA)
	}
	if !store.seminal[idC] {
		t.Errorf("expected target paper C to be marked seminal")
	}
}

func TestAuthorityService_InfluentialAndSupportWeighting(t *testing.T) {
	// Source paper cites both Target1 and Target2
	// Source cites Target1 with influential=true and stance=supports
	// Source cites Target2 with influential=false and stance=mentions
	target1 := uuid.New()
	target2 := uuid.New()
	source := uuid.New()

	nodes := []uuid.UUID{target1, target2, source}
	edges := []domainresearch.GraphEdge{
		{Source: source, Target: target1, IsInfluential: true, Stance: domainresearch.StanceSupports},
		{Source: source, Target: target2, IsInfluential: false, Stance: domainresearch.StanceMentions},
	}

	store := &fakeAuthorityStore{nodes: nodes, edges: edges}
	svc := appresearch.NewAuthorityService(store, nil, nil)

	_, err := svc.ComputeAndStore(context.Background())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	score1 := store.updated[target1]
	score2 := store.updated[target2]

	if score1 <= score2 {
		t.Errorf("expected influential+supported target1 (%f) to have higher score than target2 (%f)", score1, score2)
	}
}
