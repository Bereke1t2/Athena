package ingestion

import (
	"context"
	"errors"
	"time"
)

// ErrUnknownProviderSlug is returned when an enqueue request names a provider
// that is not configured.
var ErrUnknownProviderSlug = errors.New("ingestion: unknown provider slug")

// EnqueueRequest parameterizes one manual sync job (admin trigger).
type EnqueueRequest struct {
	Provider string
	From     time.Time
	To       time.Time
	Query    string
	MaxPages int
}

// JobInfo is a transport-agnostic projection of a queued/processed job.
type JobInfo struct {
	ID          int64      `json:"id"`
	Kind        string     `json:"kind"`
	State       string     `json:"state"`
	Attempt     int        `json:"attempt"`
	MaxAttempts int        `json:"max_attempts"`
	Errors      int        `json:"errors_count"`
	ScheduledAt time.Time  `json:"scheduled_at"`
	FinalizedAt *time.Time `json:"finalized_at,omitempty"`
}

// JobQueue abstracts the background-queue boundary (implemented by the River
// adapter in infrastructure/workers). State filters use plain strings; ""
// means all states.
type JobQueue interface {
	EnqueueWindowSync(ctx context.Context, req EnqueueRequest) (*JobInfo, error)
	ListJobs(ctx context.Context, state string, limit int) ([]JobInfo, error)
}
