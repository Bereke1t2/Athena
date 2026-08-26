// Package ingestion orchestrates provider synchronization: fetch → upsert
// (dedup inside persistence) → citation-edge resolution → run ledger. It is
// transport-agnostic; workers and admin handlers drive it.
package ingestion

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"sort"
	"time"

	"github.com/google/uuid"

	"athena/backend/internal/domain/research"
)

// Providers indexes available adapters by slug.
type Providers map[string]research.ResearchProvider

// RunStats aggregates one sync window for the ledger and logs.
type RunStats struct {
	PagesFetched int
	ItemsSeen    int
	Created      int
	Updated      int
	Unchanged    int
	Conflicts    int
	EdgesLinked  int
	ItemErrors   int
	LastIssue    string

	// NextCursor is the provider continuation token when the window has more
	// pages beyond MaxPages; empty means exhausted.
	NextCursor string
}

// RunLedger records audit rows (ingestion_runs) and durable resumption state
// (sources.sync_cursor). Implemented by infrastructure/database.
type RunLedger interface {
	StartRun(ctx context.Context, sourceSlug, kind string, from, to *time.Time) (uuid.UUID, error)
	FinishRun(ctx context.Context, runID uuid.UUID, status string, stats RunStats) error
	SaveSyncCursor(ctx context.Context, sourceSlug string, cursor SyncCursor) error
	// LoadSyncCursor returns the stored resumption cursor for a provider, or
	// nil when none is saved.
	LoadSyncCursor(ctx context.Context, sourceSlug string) (*SyncCursor, error)
	// ClearSyncCursor drops the stored checkpoint (window fully consumed).
	ClearSyncCursor(ctx context.Context, sourceSlug string) error
}

// CacheInvalidator is notified when fresh data changes query results.
// Implemented by the Redis cache; nil means caching is disabled.
type CacheInvalidator interface {
	InvalidateSearch(ctx context.Context) error
}

// SyncCursor is the JSONB shape stored on sources.sync_cursor.
type SyncCursor struct {
	NextCursor string    `json:"next_cursor,omitempty"`
	From       time.Time `json:"from"`
	To         time.Time `json:"to"`
	SavedAt    time.Time `json:"saved_at"`
}

// SyncWindowArgs parameterize one bounded sync execution.
type SyncWindowArgs struct {
	ProviderSlug string
	From         time.Time
	To           time.Time
	Cursor       string // provider continuation token from a previous page/job
	Query        string // seed query for query-driven providers (S2)
	MaxPages     int    // 0 = until the window is exhausted
}

// Service wires providers to persistence.
type Service struct {
	providers Providers
	writer    research.PaperWriter
	ledger    RunLedger
	logger    *slog.Logger

	defaultMaxPages int

	// Cache optionally invalidates query caches after successful syncs.
	Cache CacheInvalidator
}

func NewService(p Providers, writer research.PaperWriter, ledger RunLedger, logger *slog.Logger) *Service {
	if logger == nil {
		logger = slog.Default()
	}
	return &Service{providers: p, writer: writer, ledger: ledger, logger: logger, defaultMaxPages: 50}
}

var ErrUnknownProvider = errors.New("ingestion: unknown provider slug")

// ProviderSlugs lists configured providers (sorted; for logs and readiness).
func (s *Service) ProviderSlugs() []string {
	out := make([]string, 0, len(s.providers))
	for slug := range s.providers {
		out = append(out, slug)
	}
	sort.Strings(out)
	return out
}

// SyncWindow ingests one window. It is safe to re-run: persistence dedups,
// unchanged payloads are no-ops, and citation edges resolve idempotently.
func (s *Service) SyncWindow(ctx context.Context, args SyncWindowArgs) (RunStats, error) {
	prov, ok := s.providers[args.ProviderSlug]
	if !ok {
		return RunStats{}, fmt.Errorf("%w: %q", ErrUnknownProvider, args.ProviderSlug)
	}
	maxPages := args.MaxPages
	if maxPages <= 0 {
		maxPages = s.defaultMaxPages
	}

	runID, err := s.ledger.StartRun(ctx, args.ProviderSlug, "window", &args.From, &args.To)
	if err != nil {
		return RunStats{}, fmt.Errorf("start run: %w", err)
	}

	// Resume support: when a retry re-runs the same window after a mid-window
	// failure, continue from the last per-page checkpoint instead of starting
	// over (already-processed pages are idempotent no-ops anyway).
	if args.Cursor == "" {
		if saved, err := s.ledger.LoadSyncCursor(ctx, args.ProviderSlug); err != nil {
			s.logger.Warn("load sync cursor failed", "provider", args.ProviderSlug, "error", err)
		} else if saved != nil && saved.From.Equal(args.From) && saved.To.Equal(args.To) &&
			saved.NextCursor != "" {
			args.Cursor = saved.NextCursor
			s.logger.Info("resuming window from checkpoint",
				"provider", args.ProviderSlug)
		}
	}

	stats, fatalErr := s.consume(ctx, prov, args, maxPages)

	// A page-level failure fails the whole run so the job scheduler retries
	// with backoff; item-level problems are tolerated and recorded.
	status := "succeeded"
	if fatalErr != nil {
		status = "failed"
	} else if stats.LastIssue != "" {
		status = "succeeded"
	}
	if finErr := s.ledger.FinishRun(ctx, runID, status, stats); finErr != nil {
		s.logger.Warn("finish run failed", "run_id", runID, "error", finErr)
	}

	if stats.NextCursor != "" && status == "succeeded" {
		cursor := SyncCursor{From: args.From, To: args.To, SavedAt: time.Now().UTC(), NextCursor: stats.NextCursor}
		if err := s.ledger.SaveSyncCursor(ctx, args.ProviderSlug, cursor); err != nil {
			s.logger.Warn("save sync cursor failed", "provider", args.ProviderSlug, "error", err)
		}
	}
	// A fully-consumed window clears its checkpoint so future deliberate
	// replays walk the entire window again.
	if status == "succeeded" && stats.NextCursor == "" && fatalErr == nil {
		if err := s.ledger.ClearSyncCursor(ctx, args.ProviderSlug); err != nil {
			s.logger.Warn("clear sync cursor failed", "provider", args.ProviderSlug, "error", err)
		}
	}
	if status == "succeeded" && s.Cache != nil && (stats.Created > 0 || stats.Updated > 0) {
		if err := s.Cache.InvalidateSearch(ctx); err != nil {
			s.logger.Warn("cache invalidation failed", "error", err)
		}
	}
	return stats, fatalErr
}

func (s *Service) consume(ctx context.Context, prov research.ResearchProvider, args SyncWindowArgs, maxPages int) (RunStats, error) {
	stats := RunStats{}
	window := research.Window{
		From:   args.From,
		To:     args.To,
		Cursor: args.Cursor,
		Query:  args.Query,
	}

	for stats.PagesFetched < maxPages {
		if err := ctx.Err(); err != nil {
			return stats, fmt.Errorf("sync canceled: %w", err)
		}
		page, err := prov.FetchWindow(ctx, window)
		stats.PagesFetched++
		if err != nil {
			s.logger.Warn("provider fetch failed",
				"provider", args.ProviderSlug, "page", stats.PagesFetched,
				"cursor", window.Cursor, "error", err)
			return stats, fmt.Errorf("fetch page %d (provider %s): %w",
				stats.PagesFetched, args.ProviderSlug, err)
		}

		for i := range page.Papers {
			p := &page.Papers[i]
			stats.ItemsSeen++
			res, err := s.writer.UpsertPaper(ctx, *p)
			switch {
			case errors.Is(err, research.ErrIdentityConflict):
				stats.Conflicts++
				stats.LastIssue = "identity conflict kept both/none"
				s.logger.Warn("identity conflict",
					"provider", args.ProviderSlug, "native_id", p.Provenance.NativeID,
					"title_normalized", p.TitleNormalized)
				continue
			case err != nil:
				stats.ItemErrors++
				stats.LastIssue = fmt.Sprintf("upsert %q: %v", p.Provenance.NativeID, err)
				s.logger.Error("paper upsert failed",
					"provider", args.ProviderSlug, "native_id", p.Provenance.NativeID, "error", err)
				continue
			}
			switch {
			case res.Created:
				stats.Created++
			case res.ContentChanged:
				stats.Updated++
			default:
				stats.Unchanged++
			}
			if len(p.ReferencedIDs) > 0 {
				n, err := s.writer.ResolveCitationEdges(ctx, res.PaperID, p.ReferencedIDs)
				if err != nil {
					s.logger.Warn("citation edge resolution failed",
						"paper_id", res.PaperID, "error", err)
					continue
				}
				stats.EdgesLinked += n
			}
		}

		if page.NextCursor == "" {
			stats.NextCursor = ""
			return stats, nil
		}
		window.Cursor = page.NextCursor
		stats.NextCursor = page.NextCursor
		// Per-page checkpoint: a failed/timed-out attempt resumes here.
		if cpErr := s.ledger.SaveSyncCursor(ctx, args.ProviderSlug, SyncCursor{
			From: args.From, To: args.To, SavedAt: time.Now().UTC(), NextCursor: page.NextCursor,
		}); cpErr != nil {
			s.logger.Warn("checkpoint save failed", "provider", args.ProviderSlug, "error", cpErr)
		}
	}
	stats.NextCursor = window.Cursor
	return stats, nil
}
