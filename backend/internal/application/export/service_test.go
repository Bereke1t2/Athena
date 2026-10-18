package export_test

import (
	"context"
	"strings"
	"testing"

	"github.com/google/uuid"

	appexport "athena/backend/internal/application/export"
	domainexport "athena/backend/internal/domain/export"
	"athena/backend/internal/domain/research"
)

type mockReader struct {
	research.PaperReader
	paper research.PaperDetail
}

func (m *mockReader) GetDetailByID(ctx context.Context, id uuid.UUID) (research.PaperDetail, error) {
	if id == m.paper.Summary.ID {
		return m.paper, nil
	}
	return research.PaperDetail{}, research.ErrNotFound
}

func TestExportService(t *testing.T) {
	paperID := uuid.MustParse("00000000-0000-0000-0000-000000000001")
	reader := &mockReader{
		paper: research.PaperDetail{
			Summary: research.PaperSummary{
				ID:        paperID,
				Title:     "Scaling Laws for Neural Language Models",
				Year:      2020,
				VenueName: "arXiv",
			},
			Authors: []research.AuthorLine{
				{Name: "Jared Kaplan"},
			},
		},
	}
	svc := appexport.NewService(reader)

	// Export single
	content, contentType, err := svc.ExportPaper(context.Background(), paperID, domainexport.FormatBibTeX)
	if err != nil {
		t.Fatalf("ExportPaper failed: %v", err)
	}
	if contentType != "application/x-bibtex; charset=utf-8" || !strings.Contains(content, "@article") {
		t.Fatalf("unexpected export: %s (type: %s)", content, contentType)
	}

	// Export bulk
	bulk, _, err := svc.ExportPapersBulk(context.Background(), []uuid.UUID{paperID}, domainexport.FormatAPA)
	if err != nil {
		t.Fatalf("ExportPapersBulk failed: %v", err)
	}
	if !strings.Contains(bulk, "Jared Kaplan (2020)") {
		t.Fatalf("unexpected bulk APA: %s", bulk)
	}
}
