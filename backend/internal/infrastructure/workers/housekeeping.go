package workers

import (
	"context"
	"fmt"
	"log/slog"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/riverqueue/river"
)

// HousekeepingKind is the River job type for periodic database cleanup.
const HousekeepingKind = "housekeeping_cleanup"

type HousekeepingArgs struct{}

func (HousekeepingArgs) Kind() string { return HousekeepingKind }

type HousekeepingWorker struct {
	river.WorkerDefaults[HousekeepingArgs]

	Pool   *pgxpool.Pool
	Logger *slog.Logger
}

func (w *HousekeepingWorker) Work(ctx context.Context, job *river.Job[HousekeepingArgs]) error {
	if w.Pool == nil {
		return fmt.Errorf("database pool is required for housekeeping")
	}

	// 1. Prune expired user sessions (expired > 7 days ago)
	sessionTag, err := w.Pool.Exec(ctx, `
		DELETE FROM sessions
		WHERE expires_at < now() - INTERVAL '7 days'`)
	if err != nil {
		return fmt.Errorf("prune expired sessions: %w", err)
	}

	// 2. Prune expired or consumed password reset tokens
	resetTag, err := w.Pool.Exec(ctx, `
		DELETE FROM password_resets
		WHERE expires_at < now() - INTERVAL '1 day'
		   OR (used_at IS NOT NULL AND used_at < now() - INTERVAL '1 day')`)
	if err != nil {
		return fmt.Errorf("prune password resets: %w", err)
	}

	w.Logger.Info("database housekeeping completed",
		"expired_sessions_deleted", sessionTag.RowsAffected(),
		"password_resets_deleted", resetTag.RowsAffected(),
	)

	return nil
}
