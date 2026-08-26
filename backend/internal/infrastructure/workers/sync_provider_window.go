// Package workers defines River job args and handlers for the ingestion
// pipeline (ADR-0006). Handlers are thin adapters over application services:
// they deserialize args, delegate, and enqueue continuations.
package workers

import (
	"context"
	"fmt"
	"log/slog"
	"time"

	"github.com/riverqueue/river"
	"github.com/jackc/pgx/v5"

	"athena/backend/internal/application/ingestion"
)

// SyncProviderWindowKind is the River job type name.
const SyncProviderWindowKind = "sync_provider_window"

// SyncProviderWindowArgs carries one bounded provider sync. Args hold
// parameters only — never payloads (see ingestion-pipeline.md §3).
type SyncProviderWindowArgs struct {
	ProviderSlug string    `json:"provider_slug"`
	From         time.Time `json:"from"`
	To           time.Time `json:"to"`
	Cursor       string    `json:"cursor,omitempty"` // resumption token when continuing a window across jobs
	Query        string    `json:"query,omitempty"`
	MaxPages     int       `json:"max_pages,omitempty"`
}

func (SyncProviderWindowArgs) Kind() string { return SyncProviderWindowKind }

// MaxJobAttempts bounds the continuation chain per window: each attempt
// processes up to MaxPages pages, so long windows walk across attempts.
const MaxJobAttempts = 8

// SyncProviderWindowWorker consumes one page-bounded chunk of a sync window.
// When the provider still has pages left it enqueues itself with the next
// cursor, keeping individual jobs short-lived and retryable.
type SyncProviderWindowWorker struct {
	river.WorkerDefaults[SyncProviderWindowArgs]

	Service *ingestion.Service
	Logger  *slog.Logger
}

func (w *SyncProviderWindowWorker) MaxAttempts() int { return MaxJobAttempts }

func (w *SyncProviderWindowWorker) Work(ctx context.Context, job *river.Job[SyncProviderWindowArgs]) error {
	args := job.Args
	stats, err := w.Service.SyncWindow(ctx, ingestion.SyncWindowArgs{
		ProviderSlug: args.ProviderSlug,
		From:         args.From,
		To:           args.To,
		Cursor:       args.Cursor,
		Query:        args.Query,
		MaxPages:     args.MaxPages,
	})
	if err != nil {
		return fmt.Errorf("sync window %s[%s..%s]: %w", args.ProviderSlug,
			args.From.Format(time.DateOnly), args.To.Format(time.DateOnly), err)
	}

	w.Logger.Info("sync window processed",
		"provider", args.ProviderSlug,
		"pages", stats.PagesFetched,
		"seen", stats.ItemsSeen,
		"created", stats.Created,
		"updated", stats.Updated,
		"unchanged", stats.Unchanged,
		"conflicts", stats.Conflicts,
		"item_errors", stats.ItemErrors,
		"edges_linked", stats.EdgesLinked,
	)

	if stats.NextCursor == "" || job.Attempt >= MaxJobAttempts {
		return nil
	}
	client := river.ClientFromContext[pgx.Tx](ctx)
	if client == nil {
		return fmt.Errorf("no river client in context; cannot enqueue continuation")
	}
	cont := args
	cont.Cursor = stats.NextCursor
	if _, err := client.Insert(ctx, cont, nil); err != nil {
		return fmt.Errorf("enqueue continuation: %w", err)
	}
	return nil
}

// AddAll registers the Phase 1 job workers.
func AddAll(riverWorkers *river.Workers, service *ingestion.Service, logger *slog.Logger) {
	river.AddWorker(riverWorkers, &SyncProviderWindowWorker{
		Service: service,
		Logger:  logger,
	})
}

// PeriodicSyncWindow returns a periodic job that enqueues incremental syncs
// for providers supporting full-window enumeration (OpenAlex, arXiv).
// Semantic Scholar is query-driven and only runs on explicit admin triggers.
func PeriodicSyncWindow(providerSlug string, every time.Duration) *river.PeriodicJob {
	return river.NewPeriodicJob(
		river.PeriodicInterval(every),
		func() (river.JobArgs, *river.InsertOpts) {
			// Overlap the previous window by one hour so nothing published
			// mid-sync slips through.
			to := time.Now().UTC()
			from := to.Add(-25 * time.Hour)
			return SyncProviderWindowArgs{
				ProviderSlug: providerSlug,
				From:         from,
				To:           to,
				MaxPages:     50,
			}, nil
		},
		&river.PeriodicJobOpts{RunOnStart: false},
	)
}
