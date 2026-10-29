// Package feed assembles the discovery feeds (api-specification.md §2):
// latest (newest papers), trending (citation gravity × recency over a 90-day
// window), and recommended (Phase 5 — auth + personalization).
package feed

import (
	"context"
	"errors"
	"strings"
	"time"

	"github.com/google/uuid"

	domainrec "athena/backend/internal/domain/recommendation"
	"athena/backend/internal/domain/research"
)

// ErrNotImplemented marks sections deferred to later phases.
var ErrNotImplemented = errors.New("feed: section not implemented yet")

// ErrInvalidSection rejects unknown section values.
var ErrInvalidSection = errors.New("feed: invalid section")

// Section enumerates feed variants.
type Section string

const (
	SectionLatest      Section = "latest"
	SectionTrending    Section = "trending"
	SectionRecommended Section = "recommended"
)

// Item is one feed entry: the paper plus why it appears.
type Item struct {
	Paper   research.PaperSummary
	Section Section
	Reason  string
}

// Source abstracts the two backing stores: latest reuses the research
// PaperReader; trending has dedicated ranking SQL.
type Source interface {
	research.PaperReader
	Trending(ctx context.Context, topicSlugs []string, fieldSlug string, limit int) ([]research.PaperSummary, error)
}

// Recommender abstracts personalized paper ranking.
type Recommender interface {
	RecommendPapers(ctx context.Context, userID uuid.UUID, candidates []research.PaperSummary, explicitTopicSlugs []string, limit int) []domainrec.ScoredPaper
}

// Service produces feed pages.
type Service struct {
	source      Source
	recommender Recommender
}

func NewService(s Source) *Service { return &Service{source: s} }

func (s *Service) WithRecommender(r Recommender) *Service {
	s.recommender = r
	return s
}

const defaultReason = "fresh from the sources you follow"

// fallbackReason marks items served by the zero-result fallback: the
// requested topics matched nothing (e.g. onboarding slugs that predate the
// provider taxonomy), so the page is widened to the whole corpus rather than
// showing an empty feed.
const fallbackReason = "nothing new under your topics yet — showing the freshest across all of Athena"

// fallbackCursorPrefix marks a continuation token produced by an unfiltered
// fallback page ('~' cannot appear in encodeCursor's base64url output, so a
// plain prefix check is unambiguous). Continuations carrying it skip topic
// filtering, keeping keyset semantics valid.
const fallbackCursorPrefix = "~"

func hasFallbackCursor(cursor string) bool { return strings.HasPrefix(cursor, fallbackCursorPrefix) }

// Get returns one page of the requested section.
func (s *Service) Get(ctx context.Context, section Section, topicSlugs []string, fieldSlug, cursor string, limit int) ([]Item, string, error) {
	return s.GetForUser(ctx, uuid.Nil, section, topicSlugs, fieldSlug, cursor, limit)
}

// GetForUser returns one page of the requested section, incorporating authenticated user affinities when available.
func (s *Service) GetForUser(ctx context.Context, userID uuid.UUID, section Section, topicSlugs []string, fieldSlug, cursor string, limit int) ([]Item, string, error) {
	switch section {
	case "", SectionLatest:
	case SectionTrending:
	case SectionRecommended:
	default:
		return nil, "", ErrInvalidSection
	}

	unfiltered := false
	if hasFallbackCursor(cursor) {
		unfiltered = true
		cursor = strings.TrimPrefix(cursor, fallbackCursorPrefix)
	}
	topics := topicSlugs
	if unfiltered {
		topics = nil
	}

	if section == SectionTrending {
		papers, err := s.source.Trending(ctx, topics, fieldSlug, limit)
		fellBack := false
		if err == nil && len(papers) == 0 && len(topics) > 0 {
			papers, err = s.source.Trending(ctx, nil, fieldSlug, limit)
			fellBack = true
		}
		if err != nil {
			return nil, "", err
		}
		return trendingItems(papers, fellBack), "", nil
	}

	if section == SectionRecommended {
		candidateLimit := limit * 2
		if candidateLimit < 30 {
			candidateLimit = 30
		}
		if candidateLimit > 100 {
			candidateLimit = 100
		}
		lq := research.ListQuery{
			Sort:       research.SortNewest,
			Limit:      candidateLimit,
			FieldSlug:  fieldSlug,
			TopicSlugs: topics,
		}
		papers, _, err := s.source.ListPapers(ctx, lq)
		fellBack := false
		if err == nil && len(papers) == 0 && len(topics) > 0 {
			lq.TopicSlugs = nil
			papers, _, err = s.source.ListPapers(ctx, lq)
			fellBack = true
		}
		if err != nil {
			return nil, "", err
		}

		var scored []domainrec.ScoredPaper
		if s.recommender != nil {
			scored = s.recommender.RecommendPapers(ctx, userID, papers, topics, limit)
		} else {
			profile := domainrec.NewAffinityProfile(userID)
			for _, t := range topics {
				profile.TopicWeights[t] = 1.0
			}
			scored = domainrec.RankPapers(papers, profile, time.Now().UTC())
			if len(scored) > limit {
				scored = scored[:limit]
			}
		}

		items := make([]Item, 0, len(scored))
		for _, sp := range scored {
			reason := sp.MatchReason
			if fellBack {
				reason = fallbackReason
			}
			items = append(items, Item{
				Paper:   sp.Paper,
				Section: SectionRecommended,
				Reason:  reason,
			})
		}
		return items, "", nil
	}

	lq := research.ListQuery{
		Sort:       research.SortNewest,
		Limit:      limit,
		Cursor:     cursor,
		FieldSlug:  fieldSlug,
		TopicSlugs: topics,
	}
	papers, next, err := s.source.ListPapers(ctx, lq)
	fellBack := false
	if err == nil && len(papers) == 0 && len(topics) > 0 && !unfiltered && cursor == "" {
		// Zero-result guard: widen query to corpus-wide discovery so user feed never starves
		lq.TopicSlugs = nil
		papers, next, err = s.source.ListPapers(ctx, lq)
		fellBack = true
		if next != "" {
			next = fallbackCursorPrefix + next
		}
	}
	if err != nil {
		return nil, "", err
	}
	reason := defaultReason
	if fellBack {
		reason = fallbackReason
	}
	items := make([]Item, 0, len(papers))
	for _, p := range papers {
		items = append(items, Item{Paper: p, Section: SectionLatest, Reason: reason})
	}
	return items, next, nil
}

func trendingItems(papers []research.PaperSummary, fellBack bool) []Item {
	reason := "gaining citations fast"
	if fellBack {
		reason = fallbackReason
	}
	items := make([]Item, 0, len(papers))
	for _, p := range papers {
		items = append(items, Item{Paper: p, Section: SectionTrending, Reason: reason})
	}
	return items
}
