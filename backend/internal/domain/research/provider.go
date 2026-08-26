package research

import (
	"context"
	"time"
)

// Window describes an incremental fetch range handed to providers.
type Window struct {
	From   time.Time
	To     time.Time
	Cursor string // opaque continuation token; "" starts the window

	// Query optionally narrows the window (e.g. a seed topic for
	// query-driven APIs such as Semantic Scholar). Providers that support
	// full-window enumeration ignore it.
	Query string
}

// Page carries one provider result page plus a continuation cursor. An empty
// NextCursor terminates the window.
type Page struct {
	Papers     []Paper
	NextCursor string
}

// ResearchProvider abstracts one external scholarly source (ADR-0002).
// Implementations own transport concerns: rate limiting, retries, circuit
// breaking. They return fully normalized Papers or errors — never vendor DTOs.
type ResearchProvider interface {
	Slug() string
	FetchWindow(ctx context.Context, w Window) (Page, error)
}
