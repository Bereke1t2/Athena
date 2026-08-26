package database

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"athena/backend/internal/domain/research"
)

const summaryCols = `p.id, p.title, p.abstract, p.publication_date, p.publication_year,
	COALESCE(p.venue_name, ''), p.publication_type::text, p.oa_status::text, p.is_open_access,
	p.cited_by_count`

func scanSummary(row pgx.Row) (research.PaperSummary, error) {
	var s research.PaperSummary
	var pubType, oaStatus string
	err := row.Scan(&s.ID, &s.Title, &s.Abstract, &s.PublishedOn, &s.Year,
		&s.VenueName, &pubType, &oaStatus, &s.IsOpenAccess, &s.CitedByCount)
	if err != nil {
		return s, err
	}
	s.PublicationType = research.PublicationType(pubType)
	s.OAStatus = research.OAStatus(oaStatus)
	return s, nil
}

// GetDetailByID returns the full public projection of one stored paper.
func (s *PaperStore) GetDetailByID(ctx context.Context, id uuid.UUID) (research.PaperDetail, error) {
	var d research.PaperDetail
	row := s.pool.QueryRow(ctx, `
		SELECT `+summaryCols+`, COALESCE(p.language,''), COALESCE(p.license,''),
			COALESCE(p.best_oa_url,''), COALESCE(p.doi::text,''), COALESCE(p.arxiv_id,''),
			p.reference_count, p.created_at, p.updated_at
		FROM papers p WHERE p.id = $1 AND p.deleted_at IS NULL`, id)

	var pubType, oaStatus string
	err := row.Scan(&d.Summary.ID, &d.Summary.Title, &d.Summary.Abstract,
		&d.Summary.PublishedOn, &d.Summary.Year, &d.Summary.VenueName,
		&pubType, &oaStatus, &d.Summary.IsOpenAccess, &d.Summary.CitedByCount,
		&d.Language, &d.License, &d.BestOAURL, &d.DOI, &d.ArxivID,
		&d.ReferenceCount, &d.CreatedAt, &d.UpdatedAt)
	switch {
	case errors.Is(err, pgx.ErrNoRows):
		return d, research.ErrNotFound
	case err != nil:
		return d, fmt.Errorf("paper detail: %w", err)
	}
	d.Summary.PublicationType = research.PublicationType(pubType)
	d.Summary.OAStatus = research.OAStatus(oaStatus)

	rows, err := s.pool.Query(ctx, `
		SELECT COALESCE(a.id::text,''), COALESCE(a.display_name, pa.raw_name),
			COALESCE(a.orcid,''), pa.affiliation
		FROM paper_authors pa
		LEFT JOIN authors a ON a.id = pa.author_id
		WHERE pa.paper_id = $1 ORDER BY pa.position`, id)
	if err != nil {
		return d, fmt.Errorf("paper authors: %w", err)
	}
	defer rows.Close()
	for rows.Next() {
		var line research.AuthorLine
		var rawID string
		if err := rows.Scan(&rawID, &line.Name, &line.ORCID, &line.Affiliation); err != nil {
			return d, err
		}
		line.ID, _ = uuid.Parse(rawID)
		d.Authors = append(d.Authors, line)
	}
	if err := rows.Err(); err != nil {
		return d, err
	}

	rows, err = s.pool.Query(ctx, `
		SELECT t.slug, t.name, COALESCE(pt.score, 0)::float8, pt.is_primary
		FROM paper_topics pt JOIN topics t ON t.id = pt.topic_id
		WHERE pt.paper_id = $1
		ORDER BY pt.is_primary DESC, pt.score DESC NULLS LAST`, id)
	if err != nil {
		return d, fmt.Errorf("paper topics: %w", err)
	}
	defer rows.Close()
	for rows.Next() {
		var line research.TopicLine
		if err := rows.Scan(&line.Slug, &line.Name, &line.Score, &line.IsPrimary); err != nil {
			return d, err
		}
		d.Topics = append(d.Topics, line)
	}
	if err := rows.Err(); err != nil {
		return d, err
	}

	rows, err = s.pool.Query(ctx, `
		SELECT version_kind, url, is_primary FROM paper_versions
		WHERE paper_id = $1 ORDER BY is_primary DESC, created_at`, id)
	if err != nil {
		return d, fmt.Errorf("paper versions: %w", err)
	}
	defer rows.Close()
	for rows.Next() {
		var line research.VersionLine
		var kind string
		if err := rows.Scan(&kind, &line.URL, &line.IsPreprint); err != nil {
			return d, err
		}
		line.Kind = research.VersionKind(kind)
		d.Versions = append(d.Versions, line)
	}
	if err := rows.Err(); err != nil {
		return d, err
	}

	rows, err = s.pool.Query(ctx, `
		SELECT DISTINCT src.slug FROM paper_sources ps
		JOIN sources src ON src.id = ps.source_id
		WHERE ps.paper_id = $1 ORDER BY 1`, id)
	if err != nil {
		return d, fmt.Errorf("paper sources: %w", err)
	}
	defer rows.Close()
	for rows.Next() {
		var slug string
		if err := rows.Scan(&slug); err != nil {
			return d, err
		}
		d.SourceSlugs = append(d.SourceSlugs, slug)
	}
	err = rows.Err()
	return d, err
}

// FindIDByIdentifier resolves an external identifier to a stored paper ID.
func (s *PaperStore) FindIDByIdentifier(ctx context.Context, t research.IdentifierType, value string) (uuid.UUID, error) {
	var id uuid.UUID
	err := s.pool.QueryRow(ctx,
		`SELECT paper_id FROM paper_identifiers WHERE id_type = $1 AND id_value = $2`,
		string(t), value).Scan(&id)
	switch {
	case errors.Is(err, pgx.ErrNoRows):
		return uuid.Nil, research.ErrNotFound
	case err != nil:
		return uuid.Nil, fmt.Errorf("identifier lookup: %w", err)
	}
	return id, nil
}

// listCursor is the opaque continuation token for ListPapers. It embeds the
// sort key values of the last emitted row (keyset pagination).
type listCursor struct {
	V         int       `json:"v"`
	Sort      string    `json:"sort"`
	Date      time.Time `json:"date,omitempty"` // coalesced publication_date for newest sort
	ID        uuid.UUID `json:"id"`
	Citations int       `json:"citations,omitempty"` // cited_by_count for citations sort
}

func encodeCursor(c listCursor) string {
	raw, _ := json.Marshal(c)
	return base64.RawURLEncoding.EncodeToString(raw)
}

func decodeCursor(tok string) (listCursor, error) {
	var c listCursor
	raw, err := base64.RawURLEncoding.DecodeString(tok)
	if err != nil {
		return c, fmt.Errorf("%w: malformed cursor", research.ErrInvalidInput)
	}
	if err := json.Unmarshal(raw, &c); err != nil || c.V != 1 {
		return c, fmt.Errorf("%w: malformed cursor", research.ErrInvalidInput)
	}
	return c, nil
}

// topicNamePatterns maps topic slugs to case-insensitive name wildcards so
// broad interests ("machine-learning") also match provider topic names like
// "Machine Learning in Healthcare". Dashes (and other separators) become
// wildcard separators; LIKE metacharacters are stripped defensively.
func topicNamePatterns(slugs []string) []string {
	out := make([]string, 0, len(slugs))
	for _, s := range slugs {
		var b strings.Builder
		b.WriteByte('%')
		for _, r := range strings.ToLower(s) {
			switch {
			case r == '-' || r == ' ' || r == '_':
				b.WriteByte('%')
			case r == '%' || r == '\\':
				// drop LIKE metacharacters
			default:
				b.WriteRune(r)
			}
		}
		b.WriteByte('%')
		if b.Len() > 2 { // skip degenerate all-separator patterns ("%")
			out = append(out, b.String())
		}
	}
	return out
}

// ListPapers returns one keyset page for the requested ordering and filters.
// The returned token continues the page; "" means end of results.
func (s *PaperStore) ListPapers(ctx context.Context, q research.ListQuery) ([]research.PaperSummary, string, error) {
	limit := q.Limit
	if limit <= 0 {
		limit = 25
	}
	if limit > 100 {
		limit = 100
	}

	where := []string{"p.deleted_at IS NULL"}
	args := []any{}
	arg := func(v any) string {
		args = append(args, v)
		return fmt.Sprintf("$%d", len(args))
	}

	orderExpr := ""
	sort := q.Sort
	if sort == "" {
		sort = research.SortNewest
	}

	switch sort {
	case research.SortNewest:
		dateCol := fmt.Sprintf("COALESCE(p.publication_date, 'infinity'::date)")
		orderExpr = dateCol + " DESC, p.id DESC"
		if q.Cursor != "" {
			c, err := decodeCursor(q.Cursor)
			if err != nil || c.Sort != string(sort) {
				return nil, "", fmt.Errorf("%w: cursor does not match sort", research.ErrInvalidInput)
			}
			where = append(where, "("+dateCol+", p.id) < ("+arg(c.Date)+"::date, "+arg(c.ID)+")")
		}
	case research.SortCitations:
		orderExpr = "p.cited_by_count DESC, p.id DESC"
		if q.Cursor != "" {
			c, err := decodeCursor(q.Cursor)
			if err != nil || c.Sort != string(sort) {
				return nil, "", fmt.Errorf("%w: cursor does not match sort", research.ErrInvalidInput)
			}
			where = append(where, "(p.cited_by_count, p.id) < ("+arg(c.Citations)+", "+arg(c.ID)+")")
		}
	default:
		return nil, "", fmt.Errorf("%w: unsupported sort %q", research.ErrInvalidInput, q.Sort)
	}

	if q.TopicSlug != "" {
		where = append(where, "EXISTS (SELECT 1 FROM paper_topics pt JOIN topics t ON t.id = pt.topic_id"+
			" WHERE pt.paper_id = p.id AND t.slug = "+arg(q.TopicSlug)+")")
	}
	if len(q.TopicSlugs) > 0 {
		slugs := make([]string, 0, len(q.TopicSlugs))
		for _, s := range q.TopicSlugs {
			if s = strings.TrimSpace(s); s != "" {
				slugs = append(slugs, s)
			}
		}
		if len(slugs) > 0 {
			t := arg(slugs)
			n := arg(topicNamePatterns(slugs))
			where = append(where, "EXISTS (SELECT 1 FROM paper_topics pt JOIN topics t ON t.id = pt.topic_id"+
				" WHERE pt.paper_id = p.id AND (t.slug = ANY("+t+") OR t.name ILIKE ANY("+n+")))")
		}
	}
	if q.FieldSlug != "" {
		f := arg(q.FieldSlug)
		where = append(where, "EXISTS (SELECT 1 FROM paper_topics pt JOIN topics t ON t.id = pt.topic_id"+
			" WHERE pt.paper_id = p.id AND (t.slug = "+f+" OR t.parent_id = (SELECT id FROM topics WHERE slug = "+f+")))")
	}
	if q.SourceSlug != "" {
		where = append(where, "EXISTS (SELECT 1 FROM paper_sources ps JOIN sources src ON src.id = ps.source_id"+
			" WHERE ps.paper_id = p.id AND src.slug = "+arg(q.SourceSlug)+")")
	}
	if q.OpenAccess != nil && *q.OpenAccess {
		where = append(where, "p.is_open_access = TRUE")
	} else if q.OpenAccess != nil && !*q.OpenAccess {
		where = append(where, "p.is_open_access = FALSE")
	}
	if q.PublishedAfter != nil {
		where = append(where, "p.publication_date >= "+arg(*q.PublishedAfter))
	}
	if q.PublishedBefore != nil {
		where = append(where, "p.publication_date < "+arg(*q.PublishedBefore))
	}

	query := `SELECT ` + summaryCols + ` FROM papers p WHERE ` +
		strings.Join(where, " AND ") + ` ORDER BY ` + orderExpr + ` LIMIT ` + arg(limit+1)

	rows, err := s.pool.Query(ctx, query, args...)
	if err != nil {
		return nil, "", fmt.Errorf("list papers: %w", err)
	}
	defer rows.Close()

	out := make([]research.PaperSummary, 0, limit)
	for rows.Next() {
		sum, err := scanSummary(rows)
		if err != nil {
			return nil, "", err
		}
		out = append(out, sum)
	}
	if err := rows.Err(); err != nil {
		return nil, "", err
	}

	var next string
	if len(out) > limit {
		out = out[:limit]
		last := out[len(out)-1]
		c := listCursor{V: 1, Sort: string(sort), ID: last.ID}
		if last.PublishedOn != nil {
			c.Date = *last.PublishedOn
		} else {
			c.Date = time.Date(9999, 12, 31, 0, 0, 0, 0, time.UTC)
		}
		c.Citations = last.CitedByCount
		next = encodeCursor(c)
	}
	return out, next, nil
}

// ListCitations traverses stored citation edges in one direction.
func (s *PaperStore) ListCitations(ctx context.Context, paperID uuid.UUID, dir research.CitationDirection, limit int) ([]research.PaperSummary, error) {
	if limit <= 0 {
		limit = 25
	}
	if limit > 100 {
		limit = 100
	}
	join, filter := "", ""
	switch dir {
	case research.CitedBy:
		join, filter = "JOIN citations c ON c.citing_paper_id = p.id", "c.cited_paper_id = $1"
	case research.References:
		join, filter = "JOIN citations c ON c.cited_paper_id = p.id", "c.citing_paper_id = $1"
	default:
		return nil, fmt.Errorf("%w: unknown citation direction %q", research.ErrInvalidInput, dir)
	}

	rows, err := s.pool.Query(ctx, `SELECT `+summaryCols+` FROM papers p `+join+
		` WHERE `+filter+` AND p.deleted_at IS NULL
		  ORDER BY p.cited_by_count DESC, p.id DESC LIMIT $2`, paperID, limit)
	if err != nil {
		return nil, fmt.Errorf("list citations: %w", err)
	}
	defer rows.Close()

	out := make([]research.PaperSummary, 0, limit)
	for rows.Next() {
		sum, err := scanSummary(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, sum)
	}
	return out, rows.Err()
}

// RelatedBySharedTopics ranks other papers by overlap on this paper's topics.
func (s *PaperStore) RelatedBySharedTopics(ctx context.Context, paperID uuid.UUID, limit int) ([]research.PaperSummary, error) {
	if limit <= 0 {
		limit = 10
	}
	if limit > 50 {
		limit = 50
	}
	rows, err := s.pool.Query(ctx, `SELECT `+summaryCols+`
		FROM papers p
		JOIN paper_topics pt ON pt.paper_id = p.id
		WHERE pt.topic_id IN (SELECT topic_id FROM paper_topics WHERE paper_id = $1)
		  AND p.id <> $1 AND p.deleted_at IS NULL
		GROUP BY p.id
		ORDER BY COUNT(DISTINCT pt.topic_id) DESC, p.cited_by_count DESC, p.id DESC
		LIMIT $2`, paperID, limit)
	if err != nil {
		return nil, fmt.Errorf("related papers: %w", err)
	}
	defer rows.Close()

	out := make([]research.PaperSummary, 0, limit)
	for rows.Next() {
		sum, err := scanSummary(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, sum)
	}
	return out, rows.Err()
}
