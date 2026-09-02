// Package analytics defines telemetry and interaction tracking models for reading sessions and paper engagement.
package analytics

import (
	"context"
	"errors"
	"time"

	"github.com/google/uuid"
)

var (
	ErrInvalidEvent = errors.New("analytics: invalid event payload")
	ErrPaperNotFound = errors.New("analytics: paper not found")
)

// EventType categorizes user interactions with research papers and features.
type EventType string

const (
	EventView         EventType = "view"
	EventDwell        EventType = "dwell"
	EventScroll       EventType = "scroll"
	EventBookmark     EventType = "bookmark"
	EventExport       EventType = "export"
	EventCitationCopy EventType = "citation_copy"
	EventAISummary    EventType = "ai_summary"
	EventAIChat       EventType = "ai_chat"
)

// InteractionEvent is a granular telemetry data point captured during reading sessions.
type InteractionEvent struct {
	ID            uuid.UUID         `json:"id"`
	UserID        uuid.UUID         `json:"user_id,omitempty"`
	PaperID       uuid.UUID         `json:"paper_id"`
	Type          EventType         `json:"type"`
	DurationMs    int               `json:"duration_ms,omitempty"`
	ScrollPercent float64           `json:"scroll_percent,omitempty"`
	Timestamp     time.Time         `json:"timestamp"`
	Metadata      map[string]string `json:"metadata,omitempty"`
}

// PaperEngagementMetrics aggregates interaction signals to quantify reader engagement.
type PaperEngagementMetrics struct {
	PaperID           uuid.UUID `json:"paper_id"`
	ViewCount         int       `json:"view_count"`
	AvgDwellSeconds   float64   `json:"avg_dwell_seconds"`
	CompletionRate    float64   `json:"completion_rate"`
	BookmarkCount     int       `json:"bookmark_count"`
	ExportCount       int       `json:"export_count"`
	AISummaryRequests int       `json:"ai_summary_requests"`
	EngagementScore   float64   `json:"engagement_score"`
}

// CalculateEngagementScore combines views, dwell time, exports, and AI interactions.
func (m *PaperEngagementMetrics) CalculateEngagementScore() float64 {
	score := float64(m.ViewCount)*1.0 +
		(m.AvgDwellSeconds/30.0)*2.0 +
		float64(m.BookmarkCount)*5.0 +
		float64(m.ExportCount)*4.0 +
		float64(m.AISummaryRequests)*3.0
	m.EngagementScore = score
	return score
}

// Store defines persistence operations for interaction telemetry and metrics aggregation.
type Store interface {
	RecordEvent(ctx context.Context, evt InteractionEvent) error
	GetPaperMetrics(ctx context.Context, paperID uuid.UUID) (PaperEngagementMetrics, error)
	ListRecentEvents(ctx context.Context, paperID uuid.UUID, limit int) ([]InteractionEvent, error)
}
