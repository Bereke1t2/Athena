package v1

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/google/uuid"

	appexport "athena/backend/internal/application/export"
	"athena/backend/internal/domain/research"
)

type fakeExportReader struct {
	research.PaperReader
	paper research.PaperDetail
}

func (f *fakeExportReader) GetDetailByID(ctx context.Context, id uuid.UUID) (research.PaperDetail, error) {
	if id == f.paper.Summary.ID {
		return f.paper, nil
	}
	return research.PaperDetail{}, research.ErrNotFound
}

func exportTestHandler() (*ExportHandlers, *fakeExportReader) {
	paperID := uuid.MustParse("00000000-0000-0000-0000-000000000001")
	reader := &fakeExportReader{
		paper: research.PaperDetail{
			Summary: research.PaperSummary{
				ID:        paperID,
				Title:     "Deep Residual Learning for Image Recognition",
				Year:      2016,
				VenueName: "CVPR",
			},
			Authors: []research.AuthorLine{
				{Name: "Kaiming He"},
			},
		},
	}
	return NewExportHandlers(appexport.NewService(reader), testLogger()), reader
}

func TestExportHTTP(t *testing.T) {
	h, reader := exportTestHandler()
	paperID := reader.paper.Summary.ID

	// Single export (JSON)
	r1 := httptest.NewRequest(http.MethodGet, "/api/v1/research/papers/"+paperID.String()+"/export?format=apa", nil)
	r1.SetPathValue("id", paperID.String())
	w1 := httptest.NewRecorder()
	h.ExportPaper(w1, r1)
	if w1.Code != http.StatusOK {
		t.Fatalf("export paper status: %d: %s", w1.Code, w1.Body.String())
	}
	var resp exportResponseDTO
	if err := json.Unmarshal(w1.Body.Bytes(), &resp); err != nil || !strings.Contains(resp.Content, "Kaiming He (2016)") {
		t.Fatalf("unexpected export response: %+v", resp)
	}

	// Single export (raw plain text)
	r2 := httptest.NewRequest(http.MethodGet, "/api/v1/research/papers/"+paperID.String()+"/export?format=bibtex&raw=true", nil)
	r2.SetPathValue("id", paperID.String())
	w2 := httptest.NewRecorder()
	h.ExportPaper(w2, r2)
	if w2.Code != http.StatusOK {
		t.Fatalf("raw export status: %d", w2.Code)
	}
	if !strings.Contains(w2.Body.String(), "@article") {
		t.Fatalf("expected bibtex raw body, got: %s", w2.Body.String())
	}

	// Bulk export
	body := `{"paper_ids":["` + paperID.String() + `"],"format":"markdown"}`
	r3 := httptest.NewRequest(http.MethodPost, "/api/v1/research/papers/export", strings.NewReader(body))
	w3 := httptest.NewRecorder()
	h.BulkExport(w3, r3)
	if w3.Code != http.StatusOK {
		t.Fatalf("bulk export status: %d: %s", w3.Code, w3.Body.String())
	}
}
