package workers

import (
	"context"
	"fmt"
	"log/slog"
	"time"

	"github.com/riverqueue/river"

	appresearch "athena/backend/internal/application/research"
)

// GraphAuthorityKind is the River job type for periodic PageRank citation authority computation.
const GraphAuthorityKind = "compute_citation_authority"

// GraphAuthorityArgs holds arguments for the citation graph authority computation job.
type GraphAuthorityArgs struct{}

func (GraphAuthorityArgs) Kind() string { return GraphAuthorityKind }

// GraphAuthorityWorker runs the citation network PageRank authority computation.
type GraphAuthorityWorker struct {
	river.WorkerDefaults[GraphAuthorityArgs]

	AuthorityService *appresearch.AuthorityService
	Logger           *slog.Logger
}

func (w *GraphAuthorityWorker) Work(ctx context.Context, job *river.Job[GraphAuthorityArgs]) error {
	if w.AuthorityService == nil {
		return fmt.Errorf("authority service is nil")
	}

	res, err := w.AuthorityService.ComputeAndStore(ctx)
	if err != nil {
		w.Logger.Error("failed computing citation authority", "error", err)
		return err
	}

	w.Logger.Info("citation authority job completed",
		"papers", res.PapersScored,
		"seminal", res.SeminalPapersIdentified,
		"edges", res.EdgesAnalyzed,
		"max_authority", res.MaxAuthority,
		"duration_ms", res.DurationMs,
	)

	return nil
}

// AddGraphAuthority registers the graph authority worker with River.
func AddGraphAuthority(riverWorkers *river.Workers, authSvc *appresearch.AuthorityService, logger *slog.Logger) {
	if authSvc == nil {
		return
	}
	river.AddWorker(riverWorkers, &GraphAuthorityWorker{
		AuthorityService: authSvc,
		Logger:           logger,
	})
}

// PeriodicGraphAuthority schedules periodic citation network authority scoring.
func PeriodicGraphAuthority(every time.Duration) *river.PeriodicJob {
	return river.NewPeriodicJob(
		river.PeriodicInterval(every),
		func() (river.JobArgs, *river.InsertOpts) {
			return GraphAuthorityArgs{}, &river.InsertOpts{
				Queue: river.QueueDefault,
			}
		},
		&river.PeriodicJobOpts{RunOnStart: false},
	)
}
