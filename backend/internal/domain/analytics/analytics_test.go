package analytics_test

import (
	"testing"

	"github.com/google/uuid"

	domainanalytics "athena/backend/internal/domain/analytics"
)

func TestCalculateEngagementScore(t *testing.T) {
	metrics := domainanalytics.PaperEngagementMetrics{
		PaperID:           uuid.New(),
		ViewCount:         10,
		AvgDwellSeconds:   60.0,
		BookmarkCount:     2,
		ExportCount:       1,
		AISummaryRequests: 3,
	}

	// Calculation:
	// Views: 10 * 1.0 = 10.0
	// Dwell: (60.0 / 30.0) * 2.0 = 4.0
	// Bookmark: 2 * 5.0 = 10.0
	// Export: 1 * 4.0 = 4.0
	// AISummary: 3 * 3.0 = 9.0
	// Total expected: 37.0

	score := metrics.CalculateEngagementScore()
	if score != 37.0 {
		t.Errorf("expected engagement score 37.0, got %f", score)
	}
	if metrics.EngagementScore != 37.0 {
		t.Errorf("expected field EngagementScore to be updated to 37.0, got %f", metrics.EngagementScore)
	}
}
