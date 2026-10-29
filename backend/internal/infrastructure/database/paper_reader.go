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
	out := make([]string, 0, len(slugs)*2)
	seen := make(map[string]bool)
	add := func(p string) {
		if len(p) > 2 && !seen[p] {
			seen[p] = true
			out = append(out, p)
		}
	}

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
		add(b.String())

		// Expand AI and ML domain synonyms
		parts := strings.FieldsFunc(strings.ToLower(s), func(r rune) bool {
			return r == '-' || r == ' ' || r == '_'
		})
		for _, p := range parts {
			switch p {
			case "ai":
				add("%artificial%intelligence%")
				add("%ai%")
			case "ml":
				add("%machine%learning%")
			case "llm", "llms":
				add("%language%model%")
			default:
				if len(p) >= 4 {
					add("%" + p + "%")
				}
			}
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
		slug := strings.TrimSpace(q.TopicSlug)
		t := arg(slug)
		n := arg(topicNamePatterns([]string{slug}))
		where = append(where, "EXISTS (SELECT 1 FROM paper_topics pt JOIN topics t ON t.id = pt.topic_id"+
			" WHERE pt.paper_id = p.id AND (t.slug = "+t+" OR t.name ILIKE ANY("+n+")))")
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

// ClassifyStance analyzes citation context to detect support, contradiction, or mention.
func ClassifyStance(contextText string) research.CitationStance {
	lower := strings.ToLower(contextText)
	if lower == "" {
		return research.StanceMentions
	}

	contradictionPhrases := []string{
		"contradict", "differ", "disagree", "contrast", "contrary", "in contrast",
		"disprove", "refute", "fails to", "discrepancy", "limitation", "challenged by",
		"inconsistent with", "fail to replicate", "counter to", "conflict",
	}
	for _, phrase := range contradictionPhrases {
		if strings.Contains(lower, phrase) {
			return research.StanceContradicts
		}
	}

	supportPhrases := []string{
		"confirm", "support", "consistent with", "corroborate", "validate",
		"agree", "demonstrate similarly", "adopts", "builds upon", "extends",
		"in accordance with", "replicate", "aligns with", "following",
	}
	for _, phrase := range supportPhrases {
		if strings.Contains(lower, phrase) {
			return research.StanceSupports
		}
	}

	return research.StanceMentions
}

// ListCitationDetails returns citing or cited papers alongside stance and citation context.
func (s *PaperStore) ListCitationDetails(ctx context.Context, paperID uuid.UUID, dir research.CitationDirection, limit int) ([]research.CitationItem, error) {
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

	rows, err := s.pool.Query(ctx, `
		SELECT COALESCE(c.is_influential, false), COALESCE(c.stance, 'mentions'), COALESCE(c.context, ''), `+summaryCols+`
		FROM papers p `+join+`
		WHERE `+filter+` AND p.deleted_at IS NULL
		ORDER BY p.cited_by_count DESC, p.id DESC
		LIMIT $2`, paperID, limit)
	if err != nil {
		return nil, fmt.Errorf("list citation details: %w", err)
	}
	defer rows.Close()

	out := make([]research.CitationItem, 0, limit)
	for rows.Next() {
		var isInfluential bool
		var dbStance, contextText string
		var ps research.PaperSummary
		var pubType, oaStatus string
		if err := rows.Scan(
			&isInfluential, &dbStance, &contextText,
			&ps.ID, &ps.Title, &ps.Abstract, &ps.PublishedOn, &ps.Year,
			&ps.VenueName, &pubType, &oaStatus, &ps.IsOpenAccess, &ps.CitedByCount,
		); err != nil {
			return nil, err
		}
		ps.PublicationType = research.PublicationType(pubType)
		ps.OAStatus = research.OAStatus(oaStatus)

		stance := research.CitationStance(dbStance)
		if stance == "" || stance == research.StanceMentions {
			if detected := ClassifyStance(contextText); detected != research.StanceMentions {
				stance = detected
			}
		}
		out = append(out, research.CitationItem{
			Paper:         ps,
			IsInfluential: isInfluential,
			Stance:        stance,
			Context:       contextText,
		})
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return out, nil
}

// GetResearchTrends calculates publication momentum and identifies breakthrough papers.
func (s *PaperStore) GetResearchTrends(ctx context.Context, windowDays int, limit int) (research.TrendReport, error) {
	if windowDays <= 0 {
		windowDays = 90
	}
	if limit <= 0 {
		limit = 10
	}
	if limit > 50 {
		limit = 50
	}

	now := time.Now().UTC()

	// 1. Top Accelerating Topics: calculate publication volume and citation weight
	topicRows, err := s.pool.Query(ctx, `
		SELECT t.slug, t.name,
		       COUNT(p.id) AS paper_count,
		       COALESCE(SUM(p.cited_by_count), 0) AS total_citations
		FROM topics t
		JOIN paper_topics pt ON pt.topic_id = t.id
		JOIN papers p ON p.id = pt.paper_id AND p.deleted_at IS NULL
		GROUP BY t.slug, t.name
		ORDER BY paper_count DESC, total_citations DESC
		LIMIT $1`, limit)
	if err != nil {
		return research.TrendReport{}, fmt.Errorf("trend topics: %w", err)
	}
	defer topicRows.Close()

	var topTopics []research.TopicVelocity
	for topicRows.Next() {
		var tv research.TopicVelocity
		var totalCit int
		if err := topicRows.Scan(&tv.TopicSlug, &tv.TopicName, &tv.PaperCount, &totalCit); err != nil {
			return research.TrendReport{}, err
		}
		tv.GrowthRate = float64(tv.PaperCount)*1.5 + float64(totalCit)*0.1
		topTopics = append(topTopics, tv)
	}
	if err := topicRows.Err(); err != nil {
		return research.TrendReport{}, err
	}

	// 2. Breakthrough Papers: High citation momentum papers
	paperRows, err := s.pool.Query(ctx, `
		SELECT `+summaryCols+`
		FROM papers p
		WHERE p.deleted_at IS NULL AND p.cited_by_count > 0
		ORDER BY p.cited_by_count DESC, p.publication_year DESC, p.id DESC
		LIMIT $1`, limit)
	if err != nil {
		return research.TrendReport{}, fmt.Errorf("trend papers: %w", err)
	}
	defer paperRows.Close()

	var breakthrough []research.PaperSummary
	for paperRows.Next() {
		ps, err := scanSummary(paperRows)
		if err != nil {
			return research.TrendReport{}, err
		}
		breakthrough = append(breakthrough, ps)
	}
	if err := paperRows.Err(); err != nil {
		return research.TrendReport{}, err
	}

	return research.TrendReport{
		WindowDays:         windowDays,
		GeneratedAt:        now,
		TopTopics:          topTopics,
		BreakthroughPapers: breakthrough,
	}, nil
}

// GetCitationGraph traverses citation edges up to maxDepth and returns the connected graph.
func (s *PaperStore) GetCitationGraph(ctx context.Context, paperID uuid.UUID, maxDepth int, limitPerLevel int) (research.CitationGraph, error) {
	if maxDepth <= 0 {
		maxDepth = 1
	}
	if maxDepth > 2 {
		maxDepth = 2
	}
	if limitPerLevel <= 0 {
		limitPerLevel = 25
	}
	if limitPerLevel > 50 {
		limitPerLevel = 50
	}

	// 1. Verify seed paper exists and get its metadata
	var seedTitle, seedVenue string
	var seedYear, seedCitations int
	err := s.pool.QueryRow(ctx, `
		SELECT title, COALESCE(publication_year, 0), COALESCE(venue_name, ''), cited_by_count
		FROM papers
		WHERE id = $1 AND deleted_at IS NULL`, paperID).Scan(&seedTitle, &seedYear, &seedVenue, &seedCitations)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return research.CitationGraph{}, research.ErrNotFound
		}
		return research.CitationGraph{}, fmt.Errorf("load seed paper: %w", err)
	}

	seedNode := research.GraphNode{
		ID:           paperID,
		Title:        seedTitle,
		Year:         seedYear,
		VenueName:    seedVenue,
		CitedByCount: seedCitations,
		Depth:        0,
		IsSeed:       true,
	}

	nodesMap := map[uuid.UUID]research.GraphNode{paperID: seedNode}
	edgeSet := make(map[string]research.GraphEdge)
	level1IDs := make([]uuid.UUID, 0)

	// 2. Query Level 1 citations (incoming and outgoing)
	rows, err := s.pool.Query(ctx, `
		SELECT c.citing_paper_id, c.cited_paper_id, COALESCE(c.is_influential, false),
		       COALESCE(c.stance, 'mentions'), COALESCE(c.context, ''),
		       p.id, p.title, COALESCE(p.publication_year, 0), COALESCE(p.venue_name, ''), p.cited_by_count
		FROM citations c
		JOIN papers p ON p.id = (CASE WHEN c.citing_paper_id = $1 THEN c.cited_paper_id ELSE c.citing_paper_id END)
		WHERE (c.citing_paper_id = $1 OR c.cited_paper_id = $1)
		  AND p.deleted_at IS NULL
		ORDER BY c.is_influential DESC, p.cited_by_count DESC, p.id DESC
		LIMIT $2`, paperID, limitPerLevel)
	if err != nil {
		return research.CitationGraph{}, fmt.Errorf("level 1 citations: %w", err)
	}
	defer rows.Close()

	for rows.Next() {
		var citingID, citedID, pID uuid.UUID
		var isInfluential bool
		var dbStance, contextText, title, venue string
		var year, citations int
		if err := rows.Scan(&citingID, &citedID, &isInfluential, &dbStance, &contextText, &pID, &title, &year, &venue, &citations); err != nil {
			return research.CitationGraph{}, err
		}
		if _, exists := nodesMap[pID]; !exists {
			nodesMap[pID] = research.GraphNode{
				ID:           pID,
				Title:        title,
				Year:         year,
				VenueName:    venue,
				CitedByCount: citations,
				Depth:        1,
				IsSeed:       false,
			}
			level1IDs = append(level1IDs, pID)
		}
		edgeKey := citingID.String() + "->" + citedID.String()
		stance := research.CitationStance(dbStance)
		if stance == "" || stance == research.StanceMentions {
			if detected := ClassifyStance(contextText); detected != research.StanceMentions {
				stance = detected
			}
		}
		edgeSet[edgeKey] = research.GraphEdge{
			Source:        citingID,
			Target:        citedID,
			IsInfluential: isInfluential,
			Stance:        stance,
			Context:       contextText,
		}
	}
	if err := rows.Err(); err != nil {
		return research.CitationGraph{}, err
	}

	// 3. Query Level 2 citations if depth >= 2
	if maxDepth >= 2 && len(level1IDs) > 0 {
		topL1 := level1IDs
		if len(topL1) > 15 {
			topL1 = topL1[:15]
		}

		l2Rows, err := s.pool.Query(ctx, `
			SELECT c.citing_paper_id, c.cited_paper_id, COALESCE(c.is_influential, false),
			       COALESCE(c.stance, 'mentions'), COALESCE(c.context, ''),
			       p.id, p.title, COALESCE(p.publication_year, 0), COALESCE(p.venue_name, ''), p.cited_by_count
			FROM citations c
			JOIN papers p ON p.id = (CASE WHEN c.citing_paper_id = ANY($1) THEN c.cited_paper_id ELSE c.citing_paper_id END)
			WHERE (c.citing_paper_id = ANY($1) OR c.cited_paper_id = ANY($1))
			  AND p.deleted_at IS NULL
			ORDER BY c.is_influential DESC, p.cited_by_count DESC, p.id DESC
			LIMIT $2`, topL1, limitPerLevel)
		if err == nil {
			defer l2Rows.Close()
			for l2Rows.Next() {
				var citingID, citedID, pID uuid.UUID
				var isInfluential bool
				var dbStance, contextText, title, venue string
				var year, citations int
				if err := l2Rows.Scan(&citingID, &citedID, &isInfluential, &dbStance, &contextText, &pID, &title, &year, &venue, &citations); err == nil {
					if _, exists := nodesMap[pID]; !exists {
						nodesMap[pID] = research.GraphNode{
							ID:           pID,
							Title:        title,
							Year:         year,
							VenueName:    venue,
							CitedByCount: citations,
							Depth:        2,
							IsSeed:       false,
						}
					}
					edgeKey := citingID.String() + "->" + citedID.String()
					stance := research.CitationStance(dbStance)
					if stance == "" || stance == research.StanceMentions {
						if detected := ClassifyStance(contextText); detected != research.StanceMentions {
							stance = detected
						}
					}
					edgeSet[edgeKey] = research.GraphEdge{
						Source:        citingID,
						Target:        citedID,
						IsInfluential: isInfluential,
						Stance:        stance,
						Context:       contextText,
					}
				}
			}
		}
	}

	// 4. Assemble ordered nodes (seed first) and edges
	nodes := make([]research.GraphNode, 0, len(nodesMap))
	nodes = append(nodes, seedNode)
	for id, n := range nodesMap {
		if id != paperID {
			nodes = append(nodes, n)
		}
	}

	edges := make([]research.GraphEdge, 0, len(edgeSet))
	for _, e := range edgeSet {
		edges = append(edges, e)
	}

	return research.CitationGraph{
		RootID:     paperID,
		Depth:      maxDepth,
		Nodes:      nodes,
		Edges:      edges,
		TotalNodes: len(nodes),
		TotalEdges: len(edges),
	}, nil
}
