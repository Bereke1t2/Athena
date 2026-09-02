// Package analytics implements telemetry event recording and engagement score calculation.
package analytics

import (
	"context"
	"log/slog"
	"time"

	"github.com/google/uuid"

	domainanalytics "athena/backend/internal/domain/analytics"
)

// Service coordinates interaction event recording and paper engagement aggregation.
type Service struct {
	store domainanalytics.Store
	log   *slog.Logger
	clock func() time.Time
}

// NewService constructs an analytics Service.
func NewService(store domainanalytics.Store, log *slog.Logger) *Service {
	if log == nil {
		log = slog.Default()
	}
	return &Service{
		store: store,
		log:   log,
		clock: time.Now,
	}
}

// TrackEvent validates and persists a user interaction event.
func (s *Service) TrackEvent(ctx context.Context, evt domainanalytics.InteractionEvent) (domainanalytics.InteractionEvent, error) {
	if evt.PaperID == uuid.Nil {
		return domainanalytics.InteractionEvent{}, domainanalytics.ErrInvalidEvent
	}
	if evt.Type == "" {
		return domainanalytics.InteractionEvent{}, domainanalytics.ErrInvalidEvent
	}

	if evt.ID == uuid.Nil {
		evt.ID = uuid.New()
	}
	if evt.Timestamp.IsZero() {
		evt.Timestamp = s.clock().UTC()
	}

	if s.store != nil {
		if err := s.store.RecordEvent(ctx, evt); err != nil {
			s.log.Error("failed to record interaction event", "error", err, "paper_id", evt.PaperID)
			return domainanalytics.InteractionEvent{}, err
		}
	}

	return evt, nil
}

// AggregatePaperMetrics computes aggregated engagement metrics from a list of events.
func (s *Service) AggregatePaperMetrics(paperID uuid.UUID, events []domainanalytics.InteractionEvent) domainanalytics.PaperEngagementMetrics {
	metrics := domainanalytics.PaperEngagementMetrics{
		PaperID: paperID,
	}

	var totalDwellMs int
	var dwellCount int
	var maxScroll float64

	for _, evt := range events {
		if evt.PaperID != paperID {
			continue
		}
		switch evt.Type {
		case domainanalytics.EventView:
			metrics.ViewCount++
		case domainanalytics.EventDwell:
			totalDwellMs += evt.DurationMs
			dwellCount++
		case domainanalytics.EventScroll:
			if evt.ScrollPercent > maxScroll {
				maxScroll = evt.ScrollPercent
			}
		case domainanalytics.EventBookmark:
			metrics.BookmarkCount++
		case domainanalytics.EventExport:
			metrics.ExportCount++
		case domainanalytics.EventAISummary:
			metrics.AISummaryRequests++
		case domainanalytics.EventAIChat:
			metrics.AISummaryRequests++
		}
	}

	if dwellCount > 0 {
		metrics.AvgDwellSeconds = float64(totalDwellMs) / float64(dwellCount*1000)
	}
	metrics.CompletionRate = maxScroll
	metrics.CalculateEngagementScore()

	return metrics
}

// GetPaperMetrics fetches cached or aggregated metrics for a paper.
func (s *Service) GetPaperMetrics(ctx context.Context, paperID uuid.UUID) (domainanalytics.PaperEngagementMetrics, error) {
	if paperID == uuid.Nil {
		return domainanalytics.PaperEngagementMetrics{}, domainanalytics.ErrPaperNotFound
	}
	if s.store == nil {
		return domainanalytics.PaperEngagementMetrics{PaperID: paperID}, nil
	}
	return s.store.GetPaperMetrics(ctx, paperID)
}
