package database

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"athena/backend/internal/application/ingestion"
)

// RunLedger implements ingestion.RunLedger: audit rows in ingestion_runs plus
// durable resumption state on sources.sync_cursor.
type RunLedger struct {
	pool *pgxpool.Pool
}

func NewRunLedger(pool *pgxpool.Pool) *RunLedger {
	return &RunLedger{pool: pool}
}

func (l *RunLedger) StartRun(ctx context.Context, sourceSlug, kind string, from, to *time.Time) (uuid.UUID, error) {
	var runID uuid.UUID
	err := l.pool.QueryRow(ctx, `
		INSERT INTO ingestion_runs (id, source_id, run_kind, window_from, window_to, status)
		SELECT $1, s.id, $2, $3, $4, 'running'
		FROM sources s WHERE s.slug = $5
		RETURNING id`,
		uuid.New(), kind, from, to, sourceSlug).Scan(&runID)
	switch {
	case errors.Is(err, pgx.ErrNoRows):
		return uuid.Nil, fmt.Errorf("%w: unknown source %q", ingestion.ErrUnknownProvider, sourceSlug)
	case err != nil:
		return uuid.Nil, fmt.Errorf("start ingestion run: %w", err)
	}
	return runID, nil
}

func (l *RunLedger) FinishRun(ctx context.Context, runID uuid.UUID, status string, stats ingestion.RunStats) error {
	lastErr := stats.LastIssue
	if len(lastErr) > 2000 {
		lastErr = lastErr[:2000]
	}
	tag, err := l.pool.Exec(ctx, `
		UPDATE ingestion_runs SET
			status = $2,
			items_seen = $3,
			papers_created = $4,
			papers_updated = $5,
			duplicates_detected = $6,
			errors_count = $7,
			last_error = NULLIF($8,''),
			cursor_after = $9::jsonb,
			finished_at = now()
		WHERE id = $1`,
		runID, status, stats.ItemsSeen, stats.Created, stats.Updated,
		stats.Conflicts+stats.Unchanged, stats.ItemErrors, lastErr, cursorJSON(stats))
	if err != nil {
		return fmt.Errorf("finish ingestion run: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return fmt.Errorf("ingestion run %s not found", runID)
	}
	return nil
}

func cursorJSON(stats ingestion.RunStats) []byte {
	if stats.NextCursor == "" {
		return nil
	}
	raw, _ := json.Marshal(map[string]string{"next_cursor": stats.NextCursor})
	return raw
}

func (l *RunLedger) SaveSyncCursor(ctx context.Context, sourceSlug string, cursor ingestion.SyncCursor) error {
	raw, err := json.Marshal(cursor)
	if err != nil {
		return fmt.Errorf("marshal sync cursor: %w", err)
	}
	tag, err := l.pool.Exec(ctx, `
		UPDATE sources SET sync_cursor = $2::jsonb WHERE slug = $1`, sourceSlug, raw)
	if err != nil {
		return fmt.Errorf("save sync cursor: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return fmt.Errorf("%w: unknown source %q", ingestion.ErrUnknownProvider, sourceSlug)
	}
	return nil
}

func (l *RunLedger) LoadSyncCursor(ctx context.Context, sourceSlug string) (*ingestion.SyncCursor, error) {
	var raw []byte
	err := l.pool.QueryRow(ctx, `
		SELECT sync_cursor FROM sources WHERE slug = $1 AND sync_cursor IS NOT NULL`,
		sourceSlug).Scan(&raw)
	switch {
	case errors.Is(err, pgx.ErrNoRows):
		return nil, nil
	case err != nil:
		return nil, fmt.Errorf("load sync cursor: %w", err)
	}
	var cursor ingestion.SyncCursor
	if err := json.Unmarshal(raw, &cursor); err != nil {
		return nil, fmt.Errorf("unmarshal sync cursor: %w", err)
	}
	return &cursor, nil
}

func (l *RunLedger) ClearSyncCursor(ctx context.Context, sourceSlug string) error {
	_, err := l.pool.Exec(ctx, `
		UPDATE sources SET sync_cursor = NULL WHERE slug = $1`, sourceSlug)
	if err != nil {
		return fmt.Errorf("clear sync cursor: %w", err)
	}
	return nil
}

var _ ingestion.RunLedger = (*RunLedger)(nil)
