// Package feed assembles the discovery feeds (api-specification.md §2):
// latest (newest papers), trending (citation gravity × recency over a 90-day
// window), and recommended (Phase 5 — auth + personalization).
package feed

import (
	"context"
	"errors"
	"strings"

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

// Service produces feed pages.
type Service struct {
	source Source
}

func NewService(s Source) *Service { return &Service{source: s} }

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

// Get returns one page of the requested section. topicSlugs OR-match the
// user's followed topics (empty means unfiltered). Cursor applies to
// latest (keyset on publication date) and is ignored for trending.
//
// Zero-result guard: when a topic-filtered first page comes back empty but
// the corpus has content, the query is retried without the topic filter so
// the feed never starves. Its continuation cursor is prefixed with
// fallbackCursorPrefix; later pages then continue unfiltered.
func (s *Service) Get(ctx context.Context, section Section, topicSlugs []string, fieldSlug, cursor string, limit int) ([]Item, string, error) {
	switch section {
	case "", SectionLatest:
	case SectionTrending:
	case SectionRecommended:
		return nil, "", ErrNotImplemented
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
