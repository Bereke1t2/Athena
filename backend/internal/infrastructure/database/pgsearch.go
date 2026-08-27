package database

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"strings"
	"time"
	"unicode"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"

	"athena/backend/internal/domain/research"
	"athena/backend/internal/domain/search"
)

// PgSearcher implements search.Searcher with Postgres full-text search
// (search_vector tsvector + GIN) and the Phase 2 ranking baseline of
// search.md §3: textual relevance × recency decay × citation gravity.
type PgSearcher struct {
	pool *pgxpool.Pool
}

// NewPgSearcher builds the Phase 2 engine.
func NewPgSearcher(pool *pgxpool.Pool) *PgSearcher {
	return &PgSearcher{pool: pool}
}

// Compile-time port check.
var _ search.Searcher = (*PgSearcher)(nil)

// recencyDecaySQL halves the score every ~18 months (search.md §3). nowRef
// lets pagination pin the reference time so scores stay stable across pages.
func recencyDecaySQL(nowRef string) string {
	return `power(0.5,
	EXTRACT(EPOCH FROM (` + nowRef + ` - COALESCE(papers.publication_date, papers.created_at::date)))
	/ (18.0 * 30.44 * 86400))`
}

const citationGravitySQL = `(1 + ln(1 + papers.cited_by_count))`

type scoreCursor struct {
	Score float64 `json:"s,omitempty"`
	Date  string  `json:"d,omitempty"` // newest watermark (ISO date or "infinity")
	Cits  int     `json:"c,omitempty"`
	ID    string  `json:"id"`
	At    string  `json:"at,omitempty"` // ranking instant, frozen at page 1
	B     bool    `json:"b,omitempty"` // page-1 chose bounded candidate ranking
}

func encodeScoreCursor(c scoreCursor) string {
	raw, _ := json.Marshal(c)
	return base64.RawURLEncoding.EncodeToString(raw)
}

func decodeScoreCursor(raw string) (scoreCursor, error) {
	var c scoreCursor
	b, err := base64.RawURLEncoding.DecodeString(raw)
	if err != nil || json.Unmarshal(b, &c) != nil || c.ID == "" {
		return c, fmt.Errorf("%w: malformed cursor", search.ErrInvalidQuery)
	}
	return c, nil
}

const searchSummaryCols = `papers.id, papers.title, papers.abstract,
	COALESCE(papers.publication_date, papers.created_at::date) AS published_on,
	papers.publication_year, COALESCE(papers.venue_name, ''),
	papers.publication_type::text, papers.oa_status::text,
	papers.is_open_access, papers.cited_by_count`

const (
	// rankCandidateLimit is the bounded ranking slice size: relevance queries
	// over huge match sets rank only the most-cited candidates (search.md §1
	// latency budget; gravity dominates so tops stay near-identical). Kept
	// small deliberately — ts_rank_cd must decompress each row's tsvector,
	// which dominates bounded-query cost.
	rankCandidateLimit = 200
	// rankCandidateThreshold switches exact AND-ranking to bounded mode when
	// the match set exceeds this size.
	rankCandidateThreshold = 500
)

// countRows runs a bare COUNT query; failures degrade to -1 (unknown).
func (s *PgSearcher) countRows(ctx context.Context, sqlStr string, args []any) int64 {
	var n int64
	if err := s.pool.QueryRow(ctx, sqlStr, args...).Scan(&n); err != nil {
		return -1
	}
	return n
}

// Search executes one keyword-mode query. Semantic/hybrid modes degrade to
// keyword until embeddings exist; mode_used always reports what ran.
//
// Long natural-language queries rarely satisfy strict AND semantics, so an
// empty first pass retries with OR-combined terms (search.md §1: long
// natural-language queries are first-class).
func (s *PgSearcher) Search(ctx context.Context, q search.Query) (search.ResultPage, error) {
	page, err := s.searchOnce(ctx, q, false)
	if err != nil || len(page.Items) > 0 || q.Cursor != "" {
		return page, err
	}
	tokens := sanitizeTokens(q.Q)
	if len(tokens) < 2 {
		return page, nil // single term: AND pass was already exhaustive
	}
	return s.searchOnce(ctx, q, true)
}

// sanitizeTokens strips punctuation and keeps alphabetic tokens for
// to_tsquery's OR syntax ("tok1 | tok2").
func sanitizeTokens(raw string) []string {
	fields := strings.FieldsFunc(raw, func(r rune) bool {
		return !unicode.IsLetter(r) && !unicode.IsDigit(r)
	})
	out := make([]string, 0, len(fields))
	for _, f := range fields {
		f = strings.TrimSpace(f)
		if f != "" {
			out = append(out, f)
		}
	}
	return out
}

func (s *PgSearcher) searchOnce(ctx context.Context, q search.Query, orTerms bool) (search.ResultPage, error) {
	start := time.Now()

	var args []any
	var conds []string
	hasQuery := strings.TrimSpace(q.Q) != ""
	matchExpr := ""

	if hasQuery {
		ftsArg := q.Q
		tsFunc := "websearch_to_tsquery"
		if orTerms {
			ftsArg = strings.Join(sanitizeTokens(q.Q), " | ")
			tsFunc = "to_tsquery"
		}
		args = append(args, ftsArg)
		qN := len(args)
		matchExpr = fmt.Sprintf("%s('english', $%d)", tsFunc, qN)
	}
	if cond, n := topicCond(q, &args); cond != "" {
		conds = append(conds, fmt.Sprintf(cond, n))
	}
	if cond, n := fieldCond(q, &args); cond != "" {
		conds = append(conds, fmt.Sprintf(cond, n, n))
	}
	if cond, n := sourceCond(q, &args); cond != "" {
		conds = append(conds, fmt.Sprintf(cond, n))
	}
	if q.PublishedAfter != nil {
		args = append(args, q.PublishedAfter.Format(time.DateOnly))
		conds = append(conds, fmt.Sprintf("papers.publication_date >= $%d", len(args)))
	}
	if q.PublishedBefore != nil {
		args = append(args, q.PublishedBefore.Format(time.DateOnly))
		conds = append(conds, fmt.Sprintf("papers.publication_date < $%d", len(args)))
	}
	if q.OpenAccess != nil {
		args = append(args, *q.OpenAccess)
		conds = append(conds, fmt.Sprintf("papers.is_open_access = $%d", len(args)))
	}
	if q.MinCitations > 0 {
		args = append(args, q.MinCitations)
		conds = append(conds, fmt.Sprintf("papers.cited_by_count >= $%d", len(args)))
	}

	// Snapshot the pure-filter args for standalone count queries; cursor and
	// ranking parameters appended below must not leak into them.
	filterArgs := append([]any{}, args...)

	// Relevance sort with a cursor pins the ranking instant to page 1's so
	// time-decayed scores cannot shift between pages (keyset correctness).
	var cur *scoreCursor
	if q.Cursor != "" {
		c, err := decodeScoreCursor(q.Cursor)
		if err != nil {
			return search.ResultPage{}, err
		}
		cur = &c
	}

	relevanceSort := q.Sort == "" || q.Sort == search.SortRelevance
	ftsCond := ""
	if hasQuery {
		ftsCond = fmt.Sprintf("papers.search_vector @@ %s", matchExpr)
	}

	// Adaptive bounding: exact ranking scores every matched row, so broad
	// relevance queries are ranked over a citation-ordered candidate slice
	// instead (search.md §1 latency budget; gravity dominates the score so
	// tops stay near-identical). Pages ≥2 follow page 1's mode via the cursor.
	var bounded bool
	switch {
	case cur != nil:
		bounded = cur.B
	case !relevanceSort:
		// newest/citations orders stop early on indexes; no bounding needed.
	case !hasQuery || orTerms:
		bounded = true
	default:
		matchConds := conds
		if ftsCond != "" {
			matchConds = append(append([]string{}, conds...), ftsCond)
		}
		est := s.countRows(ctx, strings.Join(matchConds, " AND "), args)
		bounded = est > rankCandidateThreshold
	}

	nowRef := "now()"
	if q.Sort == search.SortRelevance || q.Sort == "" {
		if cur != nil && cur.At != "" {
			args = append(args, cur.At)
			nowRef = fmt.Sprintf("$%d::timestamptz", len(args))
		}
	}

	// Score: FTS relevance when querying, pure recency×gravity otherwise.
	// Ranking reuses the exact tsquery expression the WHERE clause matched.
	scoreExpr := recencyDecaySQL(nowRef) + " * " + citationGravitySQL
	if hasQuery {
		scoreExpr = fmt.Sprintf("(ts_rank_cd(papers.search_vector, %s) * %s * %s)",
			matchExpr, recencyDecaySQL(nowRef), citationGravitySQL)
	}

	where := strings.Join(conds, " AND ")
	if hasQuery && !bounded {
		// Exact AND-mode: the tsquery filters rows directly.
		if where == "" {
			where = ftsCond
		} else {
			where = ftsCond + " AND " + where
		}
	}

	var orderSQL string
	switch q.Sort {
	case "", search.SortRelevance:
		orderSQL = "score DESC, papers.id DESC"
	case search.SortNewest:
		orderSQL = "COALESCE(papers.publication_date, 'infinity'::date) DESC, papers.id DESC"
	case search.SortCitations:
		orderSQL = "papers.cited_by_count DESC, papers.id DESC"
	}

	cursorCond := ""
	if cur != nil {
		args = append(args, cur.ID)
		idN := len(args)
		switch q.Sort {
		case "", search.SortRelevance:
			args = append(args, cur.Score)
			sN := len(args)
			// WHERE cannot see the "score" alias; repeat the expression.
			cursorCond = fmt.Sprintf(" AND (%s, papers.id) < ($%d::float8, $%d::uuid)", scoreExpr, sN, idN)
		case search.SortNewest:
			args = append(args, cur.Date)
			dN := len(args)
			cursorCond = fmt.Sprintf(
				" AND (COALESCE(papers.publication_date, 'infinity'::date), papers.id) < ($%d::date, $%d::uuid)", dN, idN)
		case search.SortCitations:
			args = append(args, cur.Cits)
			cN := len(args)
			cursorCond = fmt.Sprintf(" AND (papers.cited_by_count, papers.id) < ($%d, $%d::uuid)", cN, idN)
		}
	}

	args = append(args, q.Limit+1)
	limitN := len(args)

	fromClause := "FROM papers"
	if bounded {
		// Bounded candidate set (search.md §1 latency budget).
		match := ""
		if hasQuery {
			match = "WHERE papers.search_vector @@ " + matchExpr
		}
		fromClause = fmt.Sprintf(`
FROM (
	SELECT papers.id FROM papers
	`+match+`
	ORDER BY papers.cited_by_count DESC, papers.id DESC
	LIMIT $%d
) cand JOIN papers ON papers.id = cand.id`, len(args)+1)
		args = append(args, rankCandidateLimit)
	}

	tail := cursorCond
	switch {
	case where != "":
		tail = "\nWHERE " + where + cursorCond
	case cursorCond != "":
		// OR-fallback page N with no other filters.
		tail = "\nWHERE" + strings.TrimPrefix(cursorCond, " AND")
	}

	// No COUNT(*) OVER () in the main query: the window forces a full read of
	// the matched set before LIMIT. First pages run a dedicated cheap count.
	sqlStr := `
SELECT ` + searchSummaryCols + `, ` + scoreExpr + ` AS score, -1::bigint AS total_estimate
` + fromClause + tail + `
ORDER BY ` + orderSQL + `
LIMIT $` + fmt.Sprint(limitN)

	rows, err := s.pool.Query(ctx, sqlStr, args...)
	if err != nil {
		return search.ResultPage{}, fmt.Errorf("search query: %w", err)
	}
	defer rows.Close()

	page := search.ResultPage{
		Items:         make([]search.ScoredPaper, 0, q.Limit+1),
		ModeUsed:      search.ModeKeyword,
		TotalEstimate: -1,
	}
	for rows.Next() {
		var sp search.ScoredPaper
		var pubType, oaStatus string
		var total int64
		dest := []any{&sp.Paper.ID, &sp.Paper.Title, &sp.Paper.Abstract, &sp.Paper.PublishedOn,
			&sp.Paper.Year, &sp.Paper.VenueName, &pubType, &oaStatus,
			&sp.Paper.IsOpenAccess, &sp.Paper.CitedByCount, &sp.Score, &total}
		if err := rows.Scan(dest...); err != nil {
			return page, fmt.Errorf("search scan: %w", err)
		}
		sp.Paper.PublicationType = research.PublicationType(pubType)
		sp.Paper.OAStatus = research.OAStatus(oaStatus)
		if q.Cursor == "" && page.TotalEstimate == -1 {
			page.TotalEstimate = total
		}
		page.Items = append(page.Items, sp)
	}
	if err := rows.Err(); err != nil {
		return page, fmt.Errorf("search rows: %w", err)
	}

	if q.Cursor == "" && hasQuery {
		// Dedicated estimate for text queries only: pure-filter listings would
		// pay a full-table count on every cold request for a number the UI
		// barely needs — report unknown (-1) there instead. Bounded queries
		// count their candidate slice; exact AND-mode counts matches.
		var est int64
		switch {
		case bounded && hasQuery:
			candSQL := `SELECT count(*) FROM (
				SELECT 1 FROM papers
				WHERE papers.search_vector @@ ` + matchExpr + `
				ORDER BY papers.cited_by_count DESC, papers.id DESC
				LIMIT $2) cand`
			est = s.countRows(ctx, candSQL, []any{filterArgs[0], rankCandidateLimit})
		case bounded:
			est = s.countRows(ctx, `SELECT count(*) FROM (
				SELECT 1 FROM papers
				ORDER BY papers.cited_by_count DESC, papers.id DESC
				LIMIT $1) cand`, []any{rankCandidateLimit})
		default:
			matchConds := conds
			if hasQuery && !orTerms && ftsCond != "" {
				matchConds = append(append([]string{}, conds...), ftsCond)
			}
			sqlStr := "SELECT count(*) FROM papers"
			countArgs := []any{}
			if j := strings.Join(matchConds, " AND "); j != "" {
				sqlStr += " WHERE " + j
				countArgs = filterArgs
			}
			est = s.countRows(ctx, sqlStr, countArgs)
		}
		page.TotalEstimate = est
	}

	if len(page.Items) > q.Limit {
		last := page.Items[q.Limit-1]
		page.Items = page.Items[:q.Limit]
		c := scoreCursor{ID: last.Paper.ID.String(), B: bounded}
		switch q.Sort {
		case "", search.SortRelevance:
			c.Score = last.Score
			// Freeze this request's ranking clock for subsequent pages.
			if nowRef != "now()" {
				c.At = cur.At
			} else {
				c.At = start.UTC().Format(time.RFC3339Nano)
			}
		case search.SortNewest:
			c.Date = "infinity"
			if last.Paper.PublishedOn != nil {
				c.Date = last.Paper.PublishedOn.Format(time.DateOnly)
			}
		case search.SortCitations:
			c.Cits = last.Paper.CitedByCount
		}
		page.NextCursor = encodeScoreCursor(c)
	}

	page.TookMS = time.Since(start).Milliseconds()
	return page, nil
}

func topicCond(q search.Query, args *[]any) (string, int) {
	if q.TopicSlug == "" {
		return "", 0
	}
	*args = append(*args, q.TopicSlug)
	return `EXISTS (SELECT 1 FROM paper_topics pt JOIN topics t ON t.id = pt.topic_id
		WHERE pt.paper_id = papers.id AND t.slug = $%d)`, len(*args)
}

func fieldCond(q search.Query, args *[]any) (string, int) {
	if q.FieldSlug == "" {
		return "", 0
	}
	*args = append(*args, q.FieldSlug)
	n := len(*args)
	return `EXISTS (SELECT 1 FROM paper_topics pt JOIN topics t ON t.id = pt.topic_id
		WHERE pt.paper_id = papers.id AND (t.slug = $%[1]d OR t.parent_id =
		  (SELECT id FROM topics WHERE slug = $%[1]d)))`, n
}

func sourceCond(q search.Query, args *[]any) (string, int) {
	if q.SourceSlug == "" {
		return "", 0
	}
	*args = append(*args, q.SourceSlug)
	return `EXISTS (SELECT 1 FROM paper_sources ps JOIN sources s ON s.id = ps.source_id
		WHERE ps.paper_id = papers.id AND s.slug = $%d)`, len(*args)
}

// Related returns papers connected to the target via shared topics, scored by
// topic overlap × recency decay × citation gravity. This is the MVP signal
// from search.md §7; embedding similarity joins in Phase 4.
func (s *PgSearcher) Related(ctx context.Context, paperID uuid.UUID, limit int) ([]search.ScoredPaper, error) {
	rows, err := s.pool.Query(ctx, `
WITH mine AS (
	SELECT pt.topic_id FROM paper_topics pt WHERE pt.paper_id = $1
)
SELECT `+searchSummaryCols+`,
	COUNT(DISTINCT pt.topic_id)::float8 * `+recencyDecaySQL("now()")+` * `+citationGravitySQL+` AS score
FROM papers
JOIN paper_topics pt ON pt.paper_id = papers.id AND pt.topic_id IN (SELECT topic_id FROM mine)
WHERE papers.id <> $1
GROUP BY papers.id
ORDER BY score DESC, papers.id DESC
LIMIT $2`, paperID, limit)
	if err != nil {
		return nil, fmt.Errorf("related query: %w", err)
	}
	defer rows.Close()

	out := make([]search.ScoredPaper, 0, limit)
	for rows.Next() {
		var sp search.ScoredPaper
		var pubType, oaStatus string
		if err := rows.Scan(&sp.Paper.ID, &sp.Paper.Title, &sp.Paper.Abstract, &sp.Paper.PublishedOn,
			&sp.Paper.Year, &sp.Paper.VenueName, &pubType, &oaStatus,
			&sp.Paper.IsOpenAccess, &sp.Paper.CitedByCount, &sp.Score); err != nil {
			return nil, fmt.Errorf("related scan: %w", err)
		}
		sp.Paper.PublicationType = research.PublicationType(pubType)
		sp.Paper.OAStatus = research.OAStatus(oaStatus)
		out = append(out, sp)
	}
	return out, rows.Err()
}
