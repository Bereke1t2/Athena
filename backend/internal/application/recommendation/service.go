// Package recommendation implements personalized recommendation workflows.
package recommendation

import (
	"context"
	"time"

	"github.com/google/uuid"

	domainfollow "athena/backend/internal/domain/follow"
	domainrec "athena/backend/internal/domain/recommendation"
	"athena/backend/internal/domain/research"
)

// Service provides personalized paper recommendations.
type Service struct {
	followStore domainfollow.Store
	clock       func() time.Time
}

// NewService constructs a recommendation service.
func NewService(followStore domainfollow.Store) *Service {
	return &Service{
		followStore: followStore,
		clock:       time.Now,
	}
}

// BuildAffinityProfile builds an AffinityProfile for the given user.
func (s *Service) BuildAffinityProfile(ctx context.Context, userID uuid.UUID, explicitTopicSlugs []string) (domainrec.AffinityProfile, error) {
	profile := domainrec.NewAffinityProfile(userID)

	// Explicit topic slugs get base weight
	for _, slug := range explicitTopicSlugs {
		if slug != "" {
			profile.TopicWeights[slug] = 1.0
		}
	}

	// If user is authenticated, query followed topics
	if s.followStore != nil && userID != uuid.Nil {
		followed, err := s.followStore.ListFollowedTopics(ctx, userID)
		if err == nil {
			for _, tf := range followed {
				profile.TopicWeights[tf.TopicSlug] = 1.5 // Followed topics get higher weight
			}
		}
	}

	return profile, nil
}

// RecommendPapers scores and ranks a candidate list of papers for a user.
func (s *Service) RecommendPapers(ctx context.Context, userID uuid.UUID, candidates []research.PaperSummary, explicitTopicSlugs []string, limit int) []domainrec.ScoredPaper {
	profile, _ := s.BuildAffinityProfile(ctx, userID, explicitTopicSlugs)
	now := s.clock()
	scored := domainrec.RankPapers(candidates, profile, now)

	if limit > 0 && len(scored) > limit {
		scored = scored[:limit]
	}
	return scored
}
