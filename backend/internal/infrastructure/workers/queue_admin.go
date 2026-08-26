package workers

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/riverqueue/river"
	"github.com/riverqueue/river/rivertype"

	"athena/backend/internal/application/ingestion"
	"athena/backend/internal/infrastructure/providers/arxiv"
	"athena/backend/internal/infrastructure/providers/openalex"
	"athena/backend/internal/infrastructure/providers/semanticscholar"
)

// ErrInvalidJobState is returned when a job-list filter names an unknown state.
var ErrInvalidJobState = errors.New("invalid job state")

// Compile-time checks that QueueAdmin satisfies the application ports.
var (
	_ ingestion.JobQueue = (*QueueAdmin)(nil)
	_ river.JobArgs      = SyncProviderWindowArgs{}
)

// QueueAdmin implements ingestion.JobQueue against the production River
// client. It lives beside the worker definitions so job args stay local.
type QueueAdmin struct {
	Client *river.Client[pgx.Tx]
}

// NewQueueAdmin builds the admin queue adapter.
func NewQueueAdmin(client *river.Client[pgx.Tx]) *QueueAdmin {
	return &QueueAdmin{Client: client}
}

// EnqueueWindowSync inserts a sync_provider_window job.
func (q *QueueAdmin) EnqueueWindowSync(ctx context.Context, req ingestion.EnqueueRequest) (*ingestion.JobInfo, error) {
	if !providerConfigured(req.Provider) {
		return nil, fmt.Errorf("%w: %s", ingestion.ErrUnknownProviderSlug, req.Provider)
	}
	res, err := q.Client.Insert(ctx, SyncProviderWindowArgs{
		ProviderSlug: req.Provider,
		From:         req.From.UTC(),
		To:           req.To.UTC(),
		Query:        req.Query,
		MaxPages:     req.MaxPages,
	}, &river.InsertOpts{
		Queue: "ingestion",
		// The API process registers no workers, so kind-level defaults
		// (MaxAttempts) don't apply here; pin them explicitly.
		MaxAttempts: MaxJobAttempts,
	})
	if err != nil {
		return nil, fmt.Errorf("insert job: %w", err)
	}
	return jobInfoFromRow(res.Job), nil
}

var knownStates = map[string]rivertype.JobState{
	string(rivertype.JobStateAvailable): rivertype.JobStateAvailable,
	string(rivertype.JobStateRunning):   rivertype.JobStateRunning,
	string(rivertype.JobStateRetryable): rivertype.JobStateRetryable,
	string(rivertype.JobStateScheduled): rivertype.JobStateScheduled,
	string(rivertype.JobStateCompleted): rivertype.JobStateCompleted,
	string(rivertype.JobStateCancelled): rivertype.JobStateCancelled,
	string(rivertype.JobStateDiscarded): rivertype.JobStateDiscarded,
}

// ValidJobState reports whether state names a real River job state.
func ValidJobState(state string) bool {
	_, ok := knownStates[state]
	return ok
}

// ListJobs returns recent jobs, optionally filtered by one state.
func (q *QueueAdmin) ListJobs(ctx context.Context, state string, limit int) ([]ingestion.JobInfo, error) {
	params := river.NewJobListParams().First(limit).OrderBy(
		river.JobListOrderByID, river.SortOrderDesc)
	if state != "" {
		if _, ok := knownStates[state]; !ok {
			return nil, fmt.Errorf("%w: %s", ErrInvalidJobState, state)
		}
		params = params.States(rivertype.JobState(state))
	}
	res, err := q.Client.JobList(ctx, params)
	if err != nil {
		return nil, fmt.Errorf("list jobs: %w", err)
	}
	out := make([]ingestion.JobInfo, 0, len(res.Jobs))
	for _, j := range res.Jobs {
		out = append(out, *jobInfoFromRow(j))
	}
	return out, nil
}

func jobInfoFromRow(j *rivertype.JobRow) *ingestion.JobInfo {
	info := &ingestion.JobInfo{
		ID:          j.ID,
		Kind:        j.Kind,
		State:       string(j.State),
		Attempt:     j.Attempt,
		MaxAttempts: j.MaxAttempts,
		Errors:      len(j.Errors),
		ScheduledAt: j.ScheduledAt,
	}
	if j.FinalizedAt != nil {
		t := j.FinalizedAt.UTC()
		info.FinalizedAt = &t
	}
	return info
}

// providerConfigured mirrors the slugs registered by the worker binary; the
// sources table remains the durable registry.
func providerConfigured(slug string) bool {
	switch slug {
	case openalex.Slug, arxiv.Slug, semanticscholar.Slug:
		return true
	default:
		return false
	}
}
