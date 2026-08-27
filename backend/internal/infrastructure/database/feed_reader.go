package database

import (
	"context"
	"fmt"
	"strings"

	"athena/backend/internal/domain/research"
)

// Trending ranks papers from the last 90 days by citation gravity × recency
// decay — the same weights as search relevance, minus textual rank
// (search.md §3). Cursor-free by design: the window shifts every request.
func (s *PaperStore) Trending(ctx context.Context, topicSlugs []string, fieldSlug string, limit int) ([]research.PaperSummary, error) {
	if limit <= 0 || limit > 100 {
		limit = 25
	}

	papers, err := s.fetchTrending(ctx, topicSlugs, fieldSlug, limit, true)
	if err != nil {
		return nil, err
	}
	if len(papers) == 0 {
		// Fallback without 90-day filter if no papers fall within the window.
		return s.fetchTrending(ctx, topicSlugs, fieldSlug, limit, false)
	}
	return papers, nil
}

func (s *PaperStore) fetchTrending(ctx context.Context, topicSlugs []string, fieldSlug string, limit int, filter90Days bool) ([]research.PaperSummary, error) {
	where := []string{}
	if filter90Days {
		where = append(where, "p.publication_date >= now() - interval '90 days'")
	}
	args := []any{}
	arg := func(v any) string {
		args = append(args, v)
		return fmt.Sprintf("$%d", len(args))
	}

	slugs := make([]string, 0, len(topicSlugs))
	for _, s := range topicSlugs {
		if s = strings.TrimSpace(s); s != "" {
			slugs = append(slugs, s)
		}
	}
	if len(slugs) == 1 {
		t := arg(slugs[0])
		n := arg(topicNamePatterns(slugs))
		where = append(where, "EXISTS (SELECT 1 FROM paper_topics pt JOIN topics t ON t.id = pt.topic_id"+
			" WHERE pt.paper_id = p.id AND (t.slug = "+t+" OR t.name ILIKE ANY("+n+")))")
	} else if len(slugs) > 1 {
		ts := arg(slugs)
		ns := arg(topicNamePatterns(slugs))
		where = append(where, "EXISTS (SELECT 1 FROM paper_topics pt JOIN topics t ON t.id = pt.topic_id"+
			" WHERE pt.paper_id = p.id AND (t.slug = ANY("+ts+") OR t.name ILIKE ANY("+ns+")))")
	}
	if fieldSlug != "" {
		f := arg(fieldSlug)
		where = append(where, "EXISTS (SELECT 1 FROM paper_topics pt JOIN topics t ON t.id = pt.topic_id"+
			" WHERE pt.paper_id = p.id AND (t.slug = "+f+" OR t.parent_id = (SELECT id FROM topics WHERE slug = "+f+")))")
	}

	score := `(1 + ln(1 + p.cited_by_count))
		* power(0.5, EXTRACT(EPOCH FROM (now() - p.publication_date)) / (18.0 * 30.44 * 86400))`

	whereClause := ""
	if len(where) > 0 {
		whereClause = " WHERE " + strings.Join(where, " AND ")
	}

	query := `SELECT ` + summaryCols + ` FROM papers p` + whereClause + `
		ORDER BY ` + score + ` DESC, p.id DESC LIMIT ` + arg(limit)

	rows, err := s.pool.Query(ctx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("trending query: %w", err)
	}
	defer rows.Close()

	out := make([]research.PaperSummary, 0, limit)
	for rows.Next() {
		sum, scanErr := scanSummary(rows)
		if scanErr != nil {
			return nil, fmt.Errorf("trending scan: %w", scanErr)
		}
		out = append(out, sum)
	}
	return out, rows.Err()
}
