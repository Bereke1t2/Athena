package research

import (
	"context"
	"fmt"
	"log/slog"
	"math"
	"sort"
	"time"

	"github.com/google/uuid"

	domainresearch "athena/backend/internal/domain/research"
)

// AuthorityConfig parameters for the citation graph PageRank algorithm.
type AuthorityConfig struct {
	DampingFactor        float64
	MaxIterations        int
	ConvergenceTolerance float64
	InfluentialWeight    float64
	SupportWeight        float64
	ContradictWeight     float64
	MentionWeight        float64
	SeminalTopPercentile float64 // e.g. 0.10 means top 10%
	SeminalMinScore      float64 // minimum normalized score (e.g. 40.0)
}

// DefaultAuthorityConfig returns production-tuned parameters for academic graphs.
func DefaultAuthorityConfig() AuthorityConfig {
	return AuthorityConfig{
		DampingFactor:        0.85,
		MaxIterations:        50,
		ConvergenceTolerance: 1e-6,
		InfluentialWeight:    1.5,
		SupportWeight:        1.25,
		ContradictWeight:     0.8,
		MentionWeight:        1.0,
		SeminalTopPercentile: 0.15, // top 15%
		SeminalMinScore:      30.0,
	}
}

// ComputeResult summarizes an authority scoring run.
type ComputeResult struct {
	PapersScored            int       `json:"papers_scored"`
	SeminalPapersIdentified int       `json:"seminal_papers_identified"`
	EdgesAnalyzed           int       `json:"edges_analyzed"`
	MaxAuthority            float64   `json:"max_authority"`
	MinAuthority            float64   `json:"min_authority"`
	DurationMs              int64     `json:"duration_ms"`
	ComputedAt              time.Time `json:"computed_at"`
}

// AuthorityService computes graph authority and foundational seminal papers.
type AuthorityService struct {
	store  domainresearch.AuthorityStore
	config AuthorityConfig
	logger *slog.Logger
}

// NewAuthorityService constructs an AuthorityService.
func NewAuthorityService(store domainresearch.AuthorityStore, cfg *AuthorityConfig, logger *slog.Logger) *AuthorityService {
	c := DefaultAuthorityConfig()
	if cfg != nil {
		c = *cfg
	}
	if logger == nil {
		logger = slog.Default()
	}
	return &AuthorityService{
		store:  store,
		config: c,
		logger: logger,
	}
}

// ComputeAndStore executes PageRank across the citation network and updates the store.
func (s *AuthorityService) ComputeAndStore(ctx context.Context) (ComputeResult, error) {
	start := time.Now()

	edges, paperIDs, err := s.store.GetCitationEdgesForScoring(ctx)
	if err != nil {
		return ComputeResult{}, fmt.Errorf("load citation graph: %w", err)
	}

	scores, seminalIDs, maxAuth, minAuth := s.ComputePageRank(paperIDs, edges)

	updated, err := s.store.UpdatePaperAuthorityScores(ctx, scores, seminalIDs)
	if err != nil {
		return ComputeResult{}, fmt.Errorf("update authority scores: %w", err)
	}

	seminalCount := 0
	for _, isSeminal := range seminalIDs {
		if isSeminal {
			seminalCount++
		}
	}

	res := ComputeResult{
		PapersScored:            updated,
		SeminalPapersIdentified: seminalCount,
		EdgesAnalyzed:           len(edges),
		MaxAuthority:            math.Round(maxAuth*100) / 100,
		MinAuthority:            math.Round(minAuth*100) / 100,
		DurationMs:              time.Since(start).Milliseconds(),
		ComputedAt:              time.Now().UTC(),
	}

	s.logger.Info("citation authority computation complete",
		"papers", res.PapersScored,
		"seminal", res.SeminalPapersIdentified,
		"edges", res.EdgesAnalyzed,
		"max_authority", res.MaxAuthority,
		"duration_ms", res.DurationMs,
	)

	return res, nil
}

// ComputePageRank runs weighted PageRank over in-memory nodes and edges.
func (s *AuthorityService) ComputePageRank(nodeIDs []uuid.UUID, edges []domainresearch.GraphEdge) (map[uuid.UUID]float64, map[uuid.UUID]bool, float64, float64) {
	scores := make(map[uuid.UUID]float64, len(nodeIDs))
	seminal := make(map[uuid.UUID]bool, len(nodeIDs))

	if len(nodeIDs) == 0 {
		return scores, seminal, 0, 0
	}

	// 1. Build adjacency and outgoing weights
	nodeSet := make(map[uuid.UUID]struct{}, len(nodeIDs))
	for _, id := range nodeIDs {
		nodeSet[id] = struct{}{}
		scores[id] = 0.0
		seminal[id] = false
	}

	type edgeTarget struct {
		target uuid.UUID
		weight float64
	}

	outEdges := make(map[uuid.UUID][]edgeTarget)
	outWeightSum := make(map[uuid.UUID]float64)
	inDegree := make(map[uuid.UUID]int)

	for _, e := range edges {
		// Verify both endpoints exist
		if _, ok := nodeSet[e.Source]; !ok {
			continue
		}
		if _, ok := nodeSet[e.Target]; !ok {
			continue
		}

		w := s.config.MentionWeight
		if e.IsInfluential {
			w *= s.config.InfluentialWeight
		}
		switch e.Stance {
		case domainresearch.StanceSupports:
			w *= s.config.SupportWeight
		case domainresearch.StanceContradicts:
			w *= s.config.ContradictWeight
		}

		outEdges[e.Source] = append(outEdges[e.Source], edgeTarget{target: e.Target, weight: w})
		outWeightSum[e.Source] += w
		inDegree[e.Target]++
	}

	n := float64(len(nodeIDs))
	d := s.config.DampingFactor

	// Initial uniform distribution
	ranks := make(map[uuid.UUID]float64, len(nodeIDs))
	for _, id := range nodeIDs {
		ranks[id] = 1.0 / n
	}

	// 2. Power iteration
	for iter := 0; iter < s.config.MaxIterations; iter++ {
		nextRanks := make(map[uuid.UUID]float64, len(nodeIDs))
		base := (1.0 - d) / n

		// Compute dangling mass (nodes with no valid outgoing citation edges)
		danglingSum := 0.0
		for _, id := range nodeIDs {
			if outWeightSum[id] == 0 {
				danglingSum += ranks[id]
			}
		}
		danglingContrib := d * (danglingSum / n)

		for _, id := range nodeIDs {
			nextRanks[id] = base + danglingContrib
		}

		// Distribute rank along directed edges: Source cites Target -> Target gains authority
		for src, targets := range outEdges {
			srcRank := ranks[src]
			totalW := outWeightSum[src]
			if totalW == 0 {
				continue
			}
			for _, t := range targets {
				nextRanks[t.target] += d * srcRank * (t.weight / totalW)
			}
		}

		// Check L1 convergence
		diff := 0.0
		for _, id := range nodeIDs {
			diff += math.Abs(nextRanks[id] - ranks[id])
		}

		ranks = nextRanks
		if diff < s.config.ConvergenceTolerance {
			break
		}
	}

	// 3. Normalization to [0.0, 100.0]
	minR, maxR := math.MaxFloat64, -math.MaxFloat64
	for _, id := range nodeIDs {
		r := ranks[id]
		if r < minR {
			minR = r
		}
		if r > maxR {
			maxR = r
		}
	}

	for _, id := range nodeIDs {
		if maxR > minR {
			// Linear scale to 100 with smooth logarithmic curve for distribution
			ratio := (ranks[id] - minR) / (maxR - minR)
			score := 100.0 * math.Pow(ratio, 0.65) // modest expansion of upper percentile
			scores[id] = math.Round(score*10) / 10
		} else {
			if inDegree[id] > 0 {
				scores[id] = 50.0
			} else {
				scores[id] = 10.0
			}
		}
	}

	// 4. Seminal Paper Classification
	// Papers in the top percentile with citation backing are flagged seminal
	type scoredID struct {
		id    uuid.UUID
		score float64
	}
	var scoredList []scoredID
	for _, id := range nodeIDs {
		if inDegree[id] > 0 {
			scoredList = append(scoredList, scoredID{id: id, score: scores[id]})
		}
	}

	sort.Slice(scoredList, func(i, j int) bool {
		return scoredList[i].score > scoredList[j].score
	})

	maxSeminalCount := int(math.Ceil(float64(len(scoredList)) * s.config.SeminalTopPercentile))
	if maxSeminalCount < 1 && len(scoredList) > 0 {
		maxSeminalCount = 1
	}

	for i := 0; i < len(scoredList) && i < maxSeminalCount; i++ {
		candidate := scoredList[i]
		if candidate.score >= s.config.SeminalMinScore || i == 0 {
			seminal[candidate.id] = true
		}
	}

	finalMin := 100.0
	finalMax := 0.0
	for _, sc := range scores {
		if sc < finalMin {
			finalMin = sc
		}
		if sc > finalMax {
			finalMax = sc
		}
	}

	return scores, seminal, finalMax, finalMin
}
