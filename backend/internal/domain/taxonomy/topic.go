// Package taxonomy owns the field/topic hierarchy that classifies research
// papers (schema: topics + paper_topics). Search and feed filter through it;
// the public endpoints expose read-only views.
package taxonomy

import (
	"context"
	"errors"
)

// ErrNotFound means no topic matches the requested slug.
var ErrNotFound = errors.New("taxonomy: topic not found")

// ErrInvalidQuery rejects malformed listing parameters (bad cursor/limit).
var ErrInvalidQuery = errors.New("taxonomy: invalid query")

// Kind distinguishes top-level fields from nested topics.
type Kind string

const (
	KindField Kind = "field"
	KindTopic Kind = "topic"
)

// Summary is a node in the public topic tree with a rough paper count.
type Summary struct {
	Slug        string
	Name        string
	Description string
	Kind        Kind
	ParentSlug  string
	ParentName  string
	PaperCount  int64 // estimate; derived from paper_topics
}

// Detail is a single topic plus its direct children slugs.
type Detail struct {
	Summary
	Children []string
}

// ListQuery filters the topic listing. All fields optional.
type ListQuery struct {
	Kind       Kind   // "" = any
	Q          string // substring match on name/slug
	ParentSlug string // direct children of this slug
	Cursor     string
	Limit      int // default 50, max 200
}

// Reader is the query-side port for topics.
type Reader interface {
	List(ctx context.Context, q ListQuery) ([]Summary, string, error)
	GetBySlug(ctx context.Context, slug string) (Detail, error)
}
