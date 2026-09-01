// Package recommendation defines domain models and ranking interfaces for personalized paper recommendations.
package recommendation

import (
	"math"
	"sort"
	"strings"
	"time"

	"github.com/google/uuid"

	"athena/backend/internal/domain/research"
)

// AffinityProfile captures a user's research topic and author preferences.
type AffinityProfile struct {
	UserID        uuid.UUID
	TopicWeights  map[string]float64
	AuthorWeights map[uuid.UUID]float64
	LastActiveAt  time.Time
}

// NewAffinityProfile creates an empty affinity profile.
func NewAffinityProfile(userID uuid.UUID) AffinityProfile {
	return AffinityProfile{
		UserID:        userID,
		TopicWeights:  make(map[string]float64),
		AuthorWeights: make(map[uuid.UUID]float64),
		LastActiveAt:  time.Now().UTC(),
	}
}

// ScoredPaper pairs a paper with its affinity score and justification.
type ScoredPaper struct {
	Paper       research.PaperSummary
	Score       float64
	MatchReason string
}

// RankPapers calculates affinity scores for candidate papers given an affinity profile,
// combining topic keyword overlap, recency decay, and citation gravity.
func RankPapers(papers []research.PaperSummary, profile AffinityProfile, now time.Time) []ScoredPaper {
	if len(papers) == 0 {
		return nil
	}
	scored := make([]ScoredPaper, 0, len(papers))

	for _, p := range papers {
		score := 0.0
		reason := "recommended for your research interests"

		// 1. Citation gravity log-scaled
		citations := float64(p.CitedByCount)
		gravityScore := math.Log1p(citations) * 0.15
		score += gravityScore

		// 2. Recency factor (decay half-life of 180 days)
		if p.PublishedOn != nil {
			daysOld := now.Sub(*p.PublishedOn).Hours() / 24.0
			if daysOld > 0 {
				recencyScore := math.Exp(-daysOld / 180.0)
				score += recencyScore * 0.4
			}
		}

		// 3. Topic keyword affinity in title / abstract
		titleLower := strings.ToLower(p.Title)
		var abstractLower string
		if p.Abstract != nil {
			abstractLower = strings.ToLower(*p.Abstract)
		}

		matchedTopicWeight := 0.0
		bestTopic := ""
		for slug, w := range profile.TopicWeights {
			cleanSlug := strings.ToLower(strings.ReplaceAll(slug, "-", " "))
			if (cleanSlug != "" && strings.Contains(titleLower, cleanSlug)) || (abstractLower != "" && strings.Contains(abstractLower, cleanSlug)) {
				if w > matchedTopicWeight {
					matchedTopicWeight = w
					bestTopic = cleanSlug
				}
			}
		}
		if matchedTopicWeight > 0 {
			score += matchedTopicWeight * 1.5
			if bestTopic != "" {
				reason = "matches your focus on " + bestTopic
			}
		}

		scored = append(scored, ScoredPaper{
			Paper:       p,
			Score:       score,
			MatchReason: reason,
		})
	}

	// Sort descending by score
	sort.Slice(scored, func(i, j int) bool {
		return scored[i].Score > scored[j].Score
	})

	return scored
}
