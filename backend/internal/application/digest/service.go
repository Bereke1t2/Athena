// Package digest implements personalized research digest generation and trend aggregation.
package digest

import (
	"context"
	"fmt"
	"log/slog"
	"time"

	"github.com/google/uuid"

	domaindigest "athena/backend/internal/domain/digest"
	domainfollow "athena/backend/internal/domain/follow"
	"athena/backend/internal/domain/research"
)

// PaperReader defines the subset of paper queries required for digest curation.
type PaperReader interface {
	ListPapers(ctx context.Context, q research.ListQuery) ([]research.PaperSummary, string, error)
}

// Service generates personalized research briefings and trend pulses.
type Service struct {
	papers      PaperReader
	followStore domainfollow.Store
	repo        domaindigest.DigestRepository
	log         *slog.Logger
	clock       func() time.Time
}

// NewService constructs a DigestService.
func NewService(papers PaperReader, followStore domainfollow.Store, repo domaindigest.DigestRepository, log *slog.Logger) *Service {
	if log == nil {
		log = slog.Default()
	}
	return &Service{
		papers:      papers,
		followStore: followStore,
		repo:        repo,
		log:         log,
		clock:       time.Now,
	}
}

// GenerateDigest builds a fresh periodic digest tailored to the user's research interests.
func (s *Service) GenerateDigest(ctx context.Context, userID uuid.UUID, freq domaindigest.Frequency) (domaindigest.UserDigest, error) {
	if userID == uuid.Nil {
		return domaindigest.UserDigest{}, domaindigest.ErrInvalidUserID
	}
	if freq != domaindigest.FrequencyDaily && freq != domaindigest.FrequencyWeekly {
		freq = domaindigest.FrequencyWeekly
	}

	var topics []string
	if s.followStore != nil {
		followed, err := s.followStore.ListFollowedTopics(ctx, userID)
		if err == nil {
			for _, tf := range followed {
				topics = append(topics, tf.TopicSlug)
			}
		}
	}

	now := s.clock()
	pulses := make([]domaindigest.TopicPulse, 0)
	sections := make([]domaindigest.DigestSection, 0)
	var allPapers []research.PaperSummary

	if len(topics) == 0 {
		// Fallback to general trending papers
		papers, _, err := s.papers.ListPapers(ctx, research.ListQuery{
			Limit: 10,
			Sort:  research.SortCitations,
		})
		if err == nil && len(papers) > 0 {
			allPapers = append(allPapers, papers...)
			sections = append(sections, domaindigest.DigestSection{
				Title:       "Trending Across Athena",
				Description: "High-impact discoveries across all scientific disciplines.",
				Papers:      papers,
			})
			pulses = append(pulses, domaindigest.TopicPulse{
				TopicSlug:  "all",
				TopicName:  "General Science",
				PaperCount: len(papers),
				Velocity:   1.0,
				KeyThemes:  []string{"Multidisciplinary Advances", "Foundational Models"},
			})
		}
	} else {
		for _, topic := range topics {
			papers, _, err := s.papers.ListPapers(ctx, research.ListQuery{
				TopicSlug: topic,
				Limit:     5,
				Sort:      research.SortCitations,
			})
			if err != nil || len(papers) == 0 {
				continue
			}
			allPapers = append(allPapers, papers...)
			sections = append(sections, domaindigest.DigestSection{
				Title:       fmt.Sprintf("Highlights in %s", topic),
				Description: fmt.Sprintf("Curated recent publications matching your follow preferences in %s.", topic),
				Papers:      papers,
			})
			pulses = append(pulses, domaindigest.TopicPulse{
				TopicSlug:  topic,
				TopicName:  topic,
				PaperCount: len(papers),
				Velocity:   float64(len(papers)) * 0.75,
				KeyThemes:  []string{fmt.Sprintf("%s methodology", topic), "Empirical validation"},
			})
		}
	}

	takeaways := []string{
		fmt.Sprintf("Compiled %d relevant papers across %d research themes.", len(allPapers), len(sections)),
		"Key breakthroughs focus on efficiency improvements and empirical validation.",
	}

	digest := domaindigest.UserDigest{
		ID:           uuid.New(),
		UserID:       userID,
		GeneratedAt:  now,
		Frequency:    freq,
		Pulses:       pulses,
		Sections:     sections,
		TopTakeaways: takeaways,
	}

	if s.repo != nil {
		if err := s.repo.SaveDigest(ctx, digest); err != nil {
			s.log.Warn("failed to persist user digest", "user_id", userID, "error", err)
		}
	}

	return digest, nil
}

// GetLatestDigest fetches the latest cached digest or dynamically generates a fresh one.
func (s *Service) GetLatestDigest(ctx context.Context, userID uuid.UUID) (domaindigest.UserDigest, error) {
	if userID == uuid.Nil {
		return domaindigest.UserDigest{}, domaindigest.ErrInvalidUserID
	}
	if s.repo != nil {
		d, err := s.repo.GetLatestDigest(ctx, userID)
		if err == nil {
			return d, nil
		}
	}
	return s.GenerateDigest(ctx, userID, domaindigest.FrequencyWeekly)
}
