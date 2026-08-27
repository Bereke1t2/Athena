package database

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"

	domainbookmark "athena/backend/internal/domain/bookmark"
	"athena/backend/internal/domain/research"
)

// BookmarkStore implements domain/bookmark.Store on Postgres.
type BookmarkStore struct {
	pool *pgxpool.Pool
}

func NewBookmarkStore(pool *pgxpool.Pool) *BookmarkStore {
	return &BookmarkStore{pool: pool}
}

// Add inserts the pair; unique-violation (already bookmarked) is a no-op.
// A foreign-key violation means the paper does not exist.
func (s *BookmarkStore) Add(ctx context.Context, b domainbookmark.Bookmark) (domainbookmark.Bookmark, error) {
	row := s.pool.QueryRow(ctx, `
		INSERT INTO bookmarks (id, user_id, paper_id, note)
		VALUES ($1, $2, $3, NULLIF($4,''))
		ON CONFLICT (user_id, paper_id) DO UPDATE SET note = COALESCE(NULLIF($4,''), bookmarks.note)
		RETURNING created_at`,
		uuid.New(), b.UserID, b.PaperID, b.Note)

	var created domainbookmark.Bookmark
	if err := row.Scan(&created.CreatedAt); err != nil {
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == "23503" { // foreign_key_violation
			return created, research.ErrNotFound
		}
		return created, fmt.Errorf("add bookmark: %w", err)
	}
	created.UserID, created.PaperID, created.Note = b.UserID, b.PaperID, b.Note
	return created, nil
}

// Remove deletes the pair; zero rows affected is not an error.
func (s *BookmarkStore) Remove(ctx context.Context, userID, paperID uuid.UUID) error {
	_, err := s.pool.Exec(ctx,
		`DELETE FROM bookmarks WHERE user_id = $1 AND paper_id = $2`, userID, paperID)
	if err != nil {
		return fmt.Errorf("remove bookmark: %w", err)
	}
	return nil
}

// bookmarkCursor is the keyset token: creation stamp + paper id of the last row.
type bookmarkCursor struct {
	V       int       `json:"v"`
	Created time.Time `json:"t"`
	PaperID uuid.UUID `json:"p"`
}

func encodeBookmarkCursor(c bookmarkCursor) string {
	raw, _ := json.Marshal(c)
	return base64.RawURLEncoding.EncodeToString(raw)
}

func decodeBookmarkCursor(tok string) (bookmarkCursor, error) {
	var c bookmarkCursor
	raw, err := base64.RawURLEncoding.DecodeString(tok)
	if err != nil || json.Unmarshal(raw, &c) != nil || c.V != 1 {
		return c, fmt.Errorf("%w: malformed cursor", research.ErrInvalidInput)
	}
	return c, nil
}

// List returns one keyset page of the user's bookmarked papers, newest first.
func (s *BookmarkStore) List(ctx context.Context, userID uuid.UUID, cursor string, limit int) ([]research.PaperSummary, string, error) {
	limit = min(max(limit, 1), 100)

	where := "b.user_id = $1"
	args := []any{userID}
	if cursor != "" {
		c, err := decodeBookmarkCursor(cursor)
		if err != nil {
			return nil, "", err
		}
		where += " AND (b.created_at, b.paper_id) < ($2, $3)"
		args = append(args, c.Created, c.PaperID)
	}
	limitArg := fmt.Sprintf("$%d", len(args)+1)

	rows, err := s.pool.Query(ctx, `
		SELECT p.id, p.title, p.abstract, p.publication_date, p.publication_year,
			COALESCE(p.venue_name,''), p.publication_type::text, p.oa_status::text,
			p.is_open_access, p.cited_by_count,
			b.created_at, b.paper_id
		FROM bookmarks b JOIN papers p ON p.id = b.paper_id AND p.deleted_at IS NULL
		WHERE `+where+`
		ORDER BY b.created_at DESC, b.paper_id DESC
		LIMIT `+limitArg, append(args, limit+1)...)
	if err != nil {
		return nil, "", fmt.Errorf("list bookmarks: %w", err)
	}
	defer rows.Close()

	out := make([]research.PaperSummary, 0, limit)
	var lastCreated time.Time
	var lastPaper uuid.UUID
	for rows.Next() {
		sum, created, paperID, err := scanBookmarkRow(rows)
		if err != nil {
			return nil, "", err
		}
		out = append(out, sum)
		lastCreated, lastPaper = created, paperID
	}
	if err := rows.Err(); err != nil {
		return nil, "", err
	}

	if len(out) > limit {
		out = out[:limit]
		next := encodeBookmarkCursor(bookmarkCursor{V: 1, Created: lastCreated, PaperID: lastPaper})
		return out, next, nil
	}
	return out, "", nil
}

func scanBookmarkRow(row pgx.Row) (research.PaperSummary, time.Time, uuid.UUID, error) {
	var s research.PaperSummary
	var pubType, oaStatus string
	var created time.Time
	var paperID uuid.UUID
	err := row.Scan(&s.ID, &s.Title, &s.Abstract, &s.PublishedOn, &s.Year,
		&s.VenueName, &pubType, &oaStatus, &s.IsOpenAccess, &s.CitedByCount,
		&created, &paperID)
	if err != nil {
		return s, time.Time{}, uuid.Nil, err
	}
	s.PublicationType = research.PublicationType(pubType)
	s.OAStatus = research.OAStatus(oaStatus)
	return s, created, paperID, nil
}
