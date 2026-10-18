package analytics

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"

	domainanalytics "athena/backend/internal/domain/analytics"
)

type fakeAnalyticsStore struct {
	events  map[uuid.UUID][]domainanalytics.InteractionEvent
	metrics map[uuid.UUID]domainanalytics.PaperEngagementMetrics
}

func (f *fakeAnalyticsStore) RecordEvent(_ context.Context, evt domainanalytics.InteractionEvent) error {
	f.events[evt.PaperID] = append(f.events[evt.PaperID], evt)
	return nil
}

func (f *fakeAnalyticsStore) GetPaperMetrics(_ context.Context, paperID uuid.UUID) (domainanalytics.PaperEngagementMetrics, error) {
	if m, ok := f.metrics[paperID]; ok {
		return m, nil
	}
	return domainanalytics.PaperEngagementMetrics{PaperID: paperID}, nil
}

func (f *fakeAnalyticsStore) ListRecentEvents(_ context.Context, paperID uuid.UUID, _ int) ([]domainanalytics.InteractionEvent, error) {
	return f.events[paperID], nil
}

func TestAnalyticsService(t *testing.T) {
	store := &fakeAnalyticsStore{
		events:  make(map[uuid.UUID][]domainanalytics.InteractionEvent),
		metrics: make(map[uuid.UUID]domainanalytics.PaperEngagementMetrics),
	}

	fixedTime := time.Date(2026, 9, 2, 12, 0, 0, 0, time.UTC)
	svc := NewService(store, nil)
	svc.clock = func() time.Time { return fixedTime }

	paperID := uuid.New()
	userID := uuid.New()

	t.Run("tracks valid event and sets defaults", func(t *testing.T) {
		evt, err := svc.TrackEvent(context.Background(), domainanalytics.InteractionEvent{
			UserID:  userID,
			PaperID: paperID,
			Type:    domainanalytics.EventView,
		})
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}
		if evt.ID == uuid.Nil {
			t.Errorf("expected generated event ID")
		}
		if !evt.Timestamp.Equal(fixedTime) {
			t.Errorf("expected timestamp %v, got %v", fixedTime, evt.Timestamp)
		}
		if len(store.events[paperID]) != 1 {
			t.Errorf("expected 1 event stored, got %d", len(store.events[paperID]))
		}
	})

	t.Run("rejects invalid events", func(t *testing.T) {
		_, err := svc.TrackEvent(context.Background(), domainanalytics.InteractionEvent{
			PaperID: uuid.Nil,
			Type:    domainanalytics.EventView,
		})
		if err != domainanalytics.ErrInvalidEvent {
			t.Errorf("expected ErrInvalidEvent on nil paperID, got %v", err)
		}

		_, err = svc.TrackEvent(context.Background(), domainanalytics.InteractionEvent{
			PaperID: paperID,
			Type:    "",
		})
		if err != domainanalytics.ErrInvalidEvent {
			t.Errorf("expected ErrInvalidEvent on empty type, got %v", err)
		}
	})

	t.Run("aggregates paper metrics accurately", func(t *testing.T) {
		events := []domainanalytics.InteractionEvent{
			{PaperID: paperID, Type: domainanalytics.EventView},
			{PaperID: paperID, Type: domainanalytics.EventView},
			{PaperID: paperID, Type: domainanalytics.EventDwell, DurationMs: 30000},
			{PaperID: paperID, Type: domainanalytics.EventDwell, DurationMs: 60000},
			{PaperID: paperID, Type: domainanalytics.EventScroll, ScrollPercent: 0.85},
			{PaperID: paperID, Type: domainanalytics.EventBookmark},
			{PaperID: paperID, Type: domainanalytics.EventExport},
			{PaperID: paperID, Type: domainanalytics.EventAISummary},
		}

		metrics := svc.AggregatePaperMetrics(paperID, events)

		if metrics.ViewCount != 2 {
			t.Errorf("expected 2 views, got %d", metrics.ViewCount)
		}
		if metrics.AvgDwellSeconds != 45.0 {
			t.Errorf("expected 45.0s avg dwell, got %f", metrics.AvgDwellSeconds)
		}
		if metrics.CompletionRate != 0.85 {
			t.Errorf("expected 0.85 completion, got %f", metrics.CompletionRate)
		}
		if metrics.BookmarkCount != 1 {
			t.Errorf("expected 1 bookmark, got %d", metrics.BookmarkCount)
		}
		if metrics.ExportCount != 1 {
			t.Errorf("expected 1 export, got %d", metrics.ExportCount)
		}
		if metrics.AISummaryRequests != 1 {
			t.Errorf("expected 1 AI summary request, got %d", metrics.AISummaryRequests)
		}
		if metrics.EngagementScore <= 0 {
			t.Errorf("expected positive engagement score, got %f", metrics.EngagementScore)
		}
	})

	t.Run("get paper metrics from store", func(t *testing.T) {
		customID := uuid.New()
		store.metrics[customID] = domainanalytics.PaperEngagementMetrics{
			PaperID:         customID,
			ViewCount:       42,
			EngagementScore: 100.5,
		}

		m, err := svc.GetPaperMetrics(context.Background(), customID)
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}
		if m.ViewCount != 42 {
			t.Errorf("expected 42 views, got %d", m.ViewCount)
		}

		_, err = svc.GetPaperMetrics(context.Background(), uuid.Nil)
		if err != domainanalytics.ErrPaperNotFound {
			t.Errorf("expected ErrPaperNotFound on nil UUID, got %v", err)
		}
	})
}
