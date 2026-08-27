package database

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"strings"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"athena/backend/internal/domain/taxonomy"
)

// TopicReader implements taxonomy.Reader on the shared pool.
type TopicReader struct {
	pool *pgxpool.Pool
}

// NewTopicReader builds the topics query-side.
func NewTopicReader(p *pgxpool.Pool) *TopicReader { return &TopicReader{pool: p} }

var _ taxonomy.Reader = (*TopicReader)(nil)

type topicCursor struct {
	Count int64  `json:"c"`
	Slug  string `json:"s"`
}

func encodeTopicCursor(c topicCursor) string {
	raw, _ := json.Marshal(c)
	return base64.RawURLEncoding.EncodeToString(raw)
}

func decodeTopicCursor(raw string) (topicCursor, error) {
	var c topicCursor
	b, err := base64.RawURLEncoding.DecodeString(raw)
	if err != nil || json.Unmarshal(b, &c) != nil || c.Slug == "" {
		return c, fmt.Errorf("%w: malformed cursor", taxonomy.ErrInvalidQuery)
	}
	return c, nil
}

// List returns topic nodes ordered by paper count desc (popularity), with
// keyset pagination on (paper_count, slug).
func (r *TopicReader) List(ctx context.Context, q taxonomy.ListQuery) ([]taxonomy.Summary, string, error) {
	limit := q.Limit
	if limit == 0 {
		limit = 50
	}
	if limit > 200 || limit < 1 {
		return nil, "", fmt.Errorf("%w: limit must be between 1 and 200", taxonomy.ErrInvalidQuery)
	}

	var conds []string
	var args []any
	if q.Kind != "" {
		args = append(args, string(q.Kind))
		conds = append(conds, fmt.Sprintf("t.kind = $%d", len(args)))
	}
	if s := strings.TrimSpace(q.Q); s != "" {
		args = append(args, "%"+s+"%", "%"+s+"%")
		n := len(args)
		conds = append(conds, fmt.Sprintf("(t.name ILIKE $%d OR t.slug ILIKE $%d)", n-1, n))
	}
	if q.ParentSlug != "" {
		args = append(args, q.ParentSlug)
		conds = append(conds, fmt.Sprintf(
			`t.parent_id = (SELECT id FROM topics WHERE slug = $%d)`, len(args)))
	}

	cursorCond := ""
	if q.Cursor != "" {
		c, err := decodeTopicCursor(q.Cursor)
		if err != nil {
			return nil, "", err
		}
		args = append(args, c.Count, c.Slug)
		n := len(args)
		cursorCond = fmt.Sprintf(` AND (COALESCE(pc.count, 0), t.slug) < ($%d, $%d)`, n-1, n)
	}

	args = append(args, limit+1)
	limitN := len(args)

	where := ""
	if len(conds) > 0 {
		where = "WHERE " + strings.Join(conds, " AND ")
	}

	// Paper counts roll up one hierarchy level (field ▸ topic): a field's
	// estimate is the distinct papers filed under it or any child topic.
	rows, err := r.pool.Query(ctx, `
WITH pc AS (
	SELECT t.id AS topic_id, COUNT(DISTINCT pt.paper_id) AS count
	FROM topics t
	LEFT JOIN topics c ON c.id = t.id OR c.parent_id = t.id
	LEFT JOIN paper_topics pt ON pt.topic_id = c.id
	GROUP BY t.id
)
SELECT t.slug, t.name, COALESCE(t.description, ''), t.kind::text,
	COALESCE(p.slug, ''), COALESCE(p.name, ''), COALESCE(pc.count, 0)::bigint
FROM topics t
LEFT JOIN topics p ON p.id = t.parent_id
LEFT JOIN pc ON pc.topic_id = t.id
`+where+cursorCond+`
ORDER BY COALESCE(pc.count, 0) DESC, t.slug DESC
LIMIT $`+fmt.Sprint(limitN), args...)
	if err != nil {
		return nil, "", fmt.Errorf("topics list: %w", err)
	}
	defer rows.Close()

	out := make([]taxonomy.Summary, 0, limit)
	for rows.Next() {
		var s taxonomy.Summary
		var kind string
		if err := rows.Scan(&s.Slug, &s.Name, &s.Description, &kind,
			&s.ParentSlug, &s.ParentName, &s.PaperCount); err != nil {
			return nil, "", fmt.Errorf("topics scan: %w", err)
		}
		s.Kind = taxonomy.Kind(kind)
		out = append(out, s)
	}
	if err := rows.Err(); err != nil {
		return nil, "", fmt.Errorf("topics rows: %w", err)
	}

	next := ""
	if len(out) > limit {
		last := out[limit-1]
		out = out[:limit]
		next = encodeTopicCursor(topicCursor{Count: last.PaperCount, Slug: last.Slug})
	}
	return out, next, nil
}

// GetBySlug resolves one topic plus direct children slugs.
func (r *TopicReader) GetBySlug(ctx context.Context, slug string) (taxonomy.Detail, error) {
	var d taxonomy.Detail
	var kind string
	err := r.pool.QueryRow(ctx, `
SELECT t.slug, t.name, COALESCE(t.description, ''), t.kind::text,
	COALESCE(p.slug, ''), COALESCE(p.name, ''),
	COALESCE((SELECT COUNT(DISTINCT pt.paper_id)
		FROM topics c LEFT JOIN paper_topics pt ON pt.topic_id = c.id
		WHERE c.id = t.id OR c.parent_id = t.id), 0)::bigint
FROM topics t LEFT JOIN topics p ON p.id = t.parent_id
WHERE t.slug = $1`, slug).Scan(&d.Slug, &d.Name, &d.Description, &kind,
		&d.ParentSlug, &d.ParentName, &d.PaperCount)
	switch {
	case errors.Is(err, pgx.ErrNoRows):
		return d, taxonomy.ErrNotFound
	case err != nil:
		return d, fmt.Errorf("topic by slug: %w", err)
	}
	d.Kind = taxonomy.Kind(kind)

	kids, err := r.pool.Query(ctx, `
SELECT slug FROM topics WHERE parent_id = (SELECT id FROM topics WHERE slug = $1)
ORDER BY slug`, slug)
	if err != nil {
		return d, fmt.Errorf("topic children: %w", err)
	}
	defer kids.Close()
	d.Children = []string{}
	for kids.Next() {
		var s string
		if err := kids.Scan(&s); err != nil {
			return d, fmt.Errorf("topic children scan: %w", err)
		}
		d.Children = append(d.Children, s)
	}
	return d, kids.Err()
}
