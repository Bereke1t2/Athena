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

	domainhistory "athena/backend/internal/domain/history"
	"athena/backend/internal/domain/research"
)

// HistoryStore implements domain/history.Store on PostgreSQL.
type HistoryStore struct {
	pool *pgxpool.Pool
}

func NewHistoryStore(pool *pgxpool.Pool) *HistoryStore {
	return &HistoryStore{pool: pool}
}

// RecordProgress creates or updates progress for a paper.
func (s *HistoryStore) RecordProgress(ctx context.Context, p domainhistory.ReadingProgress) (domainhistory.ReadingProgress, error) {
	if p.UserID == uuid.Nil || p.PaperID == uuid.Nil {
		return p, domainhistory.ErrInvalidInput
	}
	if p.ProgressPercent < 0.0 || p.ProgressPercent > 100.0 {
		return p, domainhistory.ErrInvalidInput
	}
	if p.ProgressPercent >= 90.0 {
		p.Completed = true
	}
	now := time.Now().UTC()

	row := s.pool.QueryRow(ctx, `
		INSERT INTO reading_progress (user_id, paper_id, progress_percent, completed, last_read_at)
		VALUES ($1, $2, $3, $4, $5)
		ON CONFLICT (user_id, paper_id) DO UPDATE SET
			progress_percent = EXCLUDED.progress_percent,
			completed = reading_progress.completed OR EXCLUDED.completed,
			last_read_at = EXCLUDED.last_read_at
		RETURNING last_read_at, completed`,
		p.UserID, p.PaperID, p.ProgressPercent, p.Completed, now)

	var lastReadAt time.Time
	var completed bool
	if err := row.Scan(&lastReadAt, &completed); err != nil {
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == "23503" { // foreign_key_violation
			return p, domainhistory.ErrNotFound
		}
		return p, fmt.Errorf("record progress: %w", err)
	}
	p.LastReadAt = lastReadAt
	p.Completed = completed
	return p, nil
}

// GetProgress retrieves the progress for a specific paper.
func (s *HistoryStore) GetProgress(ctx context.Context, userID, paperID uuid.UUID) (domainhistory.ReadingProgress, error) {
	if userID == uuid.Nil || paperID == uuid.Nil {
		return domainhistory.ReadingProgress{}, domainhistory.ErrInvalidInput
	}
	var p domainhistory.ReadingProgress
	p.UserID = userID
	p.PaperID = paperID

	err := s.pool.QueryRow(ctx, `
		SELECT progress_percent, completed, last_read_at
		FROM reading_progress
		WHERE user_id = $1 AND paper_id = $2`,
		userID, paperID).Scan(&p.ProgressPercent, &p.Completed, &p.LastReadAt)

	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return p, domainhistory.ErrNotFound
		}
		return p, fmt.Errorf("get progress: %w", err)
	}
	return p, nil
}

type historyCursor struct {
	V        int       `json:"v"`
	LastRead time.Time `json:"t"`
	PaperID  uuid.UUID `json:"p"`
}

func encodeHistoryCursor(c historyCursor) string {
	raw, _ := json.Marshal(c)
	return base64.RawURLEncoding.EncodeToString(raw)
}

func decodeHistoryCursor(tok string) (historyCursor, error) {
	var c historyCursor
	raw, err := base64.RawURLEncoding.DecodeString(tok)
	if err != nil || json.Unmarshal(raw, &c) != nil || c.V != 1 {
		return c, fmt.Errorf("%w: malformed cursor", research.ErrInvalidInput)
	}
	return c, nil
}

// ListHistory lists reading history for a user, newest first.
func (s *HistoryStore) ListHistory(ctx context.Context, userID uuid.UUID, cursor string, limit int) ([]domainhistory.HistoryEntry, string, error) {
	limit = min(max(limit, 1), 100)

	where := "rp.user_id = $1"
	args := []any{userID}
	if cursor != "" {
		c, err := decodeHistoryCursor(cursor)
		if err != nil {
			return nil, "", err
		}
		where += " AND (rp.last_read_at, rp.paper_id) < ($2, $3)"
		args = append(args, c.LastRead, c.PaperID)
	}
	limitArg := fmt.Sprintf("$%d", len(args)+1)

	rows, err := s.pool.Query(ctx, `
		SELECT p.id, p.title, p.abstract, p.publication_date, p.publication_year,
			COALESCE(p.venue_name,''), p.publication_type::text, p.oa_status::text,
			p.is_open_access, p.cited_by_count,
			rp.progress_percent, rp.completed, rp.last_read_at, rp.paper_id
		FROM reading_progress rp
		JOIN papers p ON p.id = rp.paper_id AND p.deleted_at IS NULL
		WHERE `+where+`
		ORDER BY rp.last_read_at DESC, rp.paper_id DESC
		LIMIT `+limitArg, append(args, limit+1)...)
	if err != nil {
		return nil, "", fmt.Errorf("list history: %w", err)
	}
	defer rows.Close()

	out := make([]domainhistory.HistoryEntry, 0, limit)
	var lastRead time.Time
	var lastPaper uuid.UUID

	for rows.Next() {
		var sum research.PaperSummary
		var pubType, oaStatus string
		var entry domainhistory.HistoryEntry
		var paperID uuid.UUID

		err := rows.Scan(
			&sum.ID, &sum.Title, &sum.Abstract, &sum.PublishedOn, &sum.Year,
			&sum.VenueName, &pubType, &oaStatus, &sum.IsOpenAccess, &sum.CitedByCount,
			&entry.ProgressPercent, &entry.Completed, &entry.LastReadAt, &paperID,
		)
		if err != nil {
			return nil, "", fmt.Errorf("scan history row: %w", err)
		}
		sum.PublicationType = research.PublicationType(pubType)
		sum.OAStatus = research.OAStatus(oaStatus)
		entry.Paper = sum
		out = append(out, entry)
		lastRead, lastPaper = entry.LastReadAt, paperID
	}
	if err := rows.Err(); err != nil {
		return nil, "", err
	}

	if len(out) > limit {
		out = out[:limit]
		next := encodeHistoryCursor(historyCursor{V: 1, LastRead: lastRead, PaperID: lastPaper})
		return out, next, nil
	}
	return out, "", nil
}

// ClearHistory removes reading history for a user.
func (s *HistoryStore) ClearHistory(ctx context.Context, userID uuid.UUID) error {
	_, err := s.pool.Exec(ctx, `DELETE FROM reading_progress WHERE user_id = $1`, userID)
	if err != nil {
		return fmt.Errorf("clear history: %w", err)
	}
	return nil
}
