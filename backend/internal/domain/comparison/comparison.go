// Package comparison defines domain models for multi-paper synthesis and matrix comparison.
package comparison

import (
	"errors"

	"github.com/google/uuid"
)

var (
	// ErrInsufficientPapers is returned when fewer than 2 papers are supplied for comparison.
	ErrInsufficientPapers = errors.New("comparison: at least 2 papers are required for comparison")
	// ErrTooManyPapers is returned when the paper limit is exceeded.
	ErrTooManyPapers = errors.New("comparison: maximum 5 papers can be compared simultaneously")
)

// Facet represents a comparative dimension.
type Facet string

const (
	FacetMethodology Facet = "methodology"
	FacetFindings    Facet = "findings"
	FacetLimitations Facet = "limitations"
	FacetDatasets    Facet = "datasets"
)

// PaperMatrixEntry captures comparative dimensions for one paper.
type PaperMatrixEntry struct {
	PaperID     uuid.UUID `json:"paper_id"`
	Title       string    `json:"title"`
	Authors     []string  `json:"authors"`
	Year        int       `json:"year"`
	Venue       string    `json:"venue"`
	KeyTakeaway string    `json:"key_takeaway"`
	Methodology string    `json:"methodology"`
	Strengths   []string  `json:"strengths"`
	Limitations []string  `json:"limitations"`
}

// SynthesisReport is the structured comparative analysis across multiple research papers.
type SynthesisReport struct {
	Papers             []PaperMatrixEntry `json:"papers"`
	ConsensusPoints    []string           `json:"consensus_points"`
	DivergencePoints   []string           `json:"divergence_points"`
	ComparativeSummary string             `json:"comparative_summary"`
	Grounding          string             `json:"grounding"`
	ModelID            string             `json:"model_id"`
}
