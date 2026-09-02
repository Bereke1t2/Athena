package v1

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/google/uuid"

	appai "athena/backend/internal/application/ai"
	domaincomp "athena/backend/internal/domain/comparison"
	"athena/backend/internal/domain/research"
)

type fakePaperStoreForComp struct {
	papers map[uuid.UUID]research.PaperDetail
	err    error
}

func (f *fakePaperStoreForComp) GetDetailByID(_ context.Context, id uuid.UUID) (research.PaperDetail, error) {
	if f.err != nil {
		return research.PaperDetail{}, f.err
	}
	p, ok := f.papers[id]
	if !ok {
		return research.PaperDetail{}, research.ErrNotFound
	}
	return p, nil
}

func TestCompareEndpoint(t *testing.T) {
	p1ID := uuid.New()
	p2ID := uuid.New()
	p3ID := uuid.New()

	store := &fakePaperStoreForComp{
		papers: map[uuid.UUID]research.PaperDetail{
			p1ID: {
				Summary: research.PaperSummary{
					ID:              p1ID,
					Title:           "Attention is All You Need",
					PublicationType: research.PubTypeArticle,
					Year:            2017,
					VenueName:       "NeurIPS",
				},
				Authors: []research.AuthorLine{{Name: "Vaswani"}},
			},
			p2ID: {
				Summary: research.PaperSummary{
					ID:              p2ID,
					Title:           "BERT: Pre-training Deep Bidirectional Transformers",
					PublicationType: research.PubTypeArticle,
					Year:            2018,
					VenueName:       "NAACL",
				},
				Authors: []research.AuthorLine{{Name: "Devlin"}},
			},
		},
	}

	compSvc := appai.NewComparisonService(nil, store, nil, discardLogger())
	h := &AIHandlers{
		Comparison: compSvc,
		Logger:     discardLogger(),
	}

	mux := http.NewServeMux()
	mux.HandleFunc("POST /api/v1/research/compare", h.Compare)

	t.Run("success with 2 papers", func(t *testing.T) {
		body, _ := json.Marshal(map[string]any{
			"paper_ids": []string{p1ID.String(), p2ID.String()},
		})
		req := httptest.NewRequest(http.MethodPost, "/api/v1/research/compare", bytes.NewReader(body))
		rec := httptest.NewRecorder()
		mux.ServeHTTP(rec, req)

		if rec.Code != http.StatusOK {
			t.Fatalf("expected 200, got %d: %s", rec.Code, rec.Body.String())
		}
		var resp domaincomp.SynthesisReport
		if err := json.Unmarshal(rec.Body.Bytes(), &resp); err != nil {
			t.Fatalf("failed to decode response: %v", err)
		}
		if len(resp.Papers) != 2 {
			t.Errorf("expected 2 papers in matrix, got %d", len(resp.Papers))
		}
		if len(resp.ConsensusPoints) == 0 {
			t.Errorf("expected consensus points to be non-empty")
		}
	})

	t.Run("fails when less than 2 papers", func(t *testing.T) {
		body, _ := json.Marshal(map[string]any{
			"paper_ids": []string{p1ID.String()},
		})
		req := httptest.NewRequest(http.MethodPost, "/api/v1/research/compare", bytes.NewReader(body))
		rec := httptest.NewRecorder()
		mux.ServeHTTP(rec, req)

		if rec.Code != http.StatusBadRequest {
			t.Fatalf("expected 400, got %d", rec.Code)
		}
	})

	t.Run("fails when more than 5 papers", func(t *testing.T) {
		body, _ := json.Marshal(map[string]any{
			"paper_ids": []string{
				uuid.NewString(), uuid.NewString(), uuid.NewString(),
				uuid.NewString(), uuid.NewString(), uuid.NewString(),
			},
		})
		req := httptest.NewRequest(http.MethodPost, "/api/v1/research/compare", bytes.NewReader(body))
		rec := httptest.NewRecorder()
		mux.ServeHTTP(rec, req)

		if rec.Code != http.StatusBadRequest {
			t.Fatalf("expected 400, got %d", rec.Code)
		}
	})

	t.Run("fails on invalid uuid string", func(t *testing.T) {
		body, _ := json.Marshal(map[string]any{
			"paper_ids": []string{"not-a-uuid", p2ID.String()},
		})
		req := httptest.NewRequest(http.MethodPost, "/api/v1/research/compare", bytes.NewReader(body))
		rec := httptest.NewRecorder()
		mux.ServeHTTP(rec, req)

		if rec.Code != http.StatusBadRequest {
			t.Fatalf("expected 400, got %d", rec.Code)
		}
	})

	t.Run("service unavailable if comparison is nil", func(t *testing.T) {
		nilHandlers := &AIHandlers{Logger: discardLogger()}
		nilMux := http.NewServeMux()
		nilMux.HandleFunc("POST /api/v1/research/compare", nilHandlers.Compare)

		body, _ := json.Marshal(map[string]any{
			"paper_ids": []string{p1ID.String(), p2ID.String()},
		})
		req := httptest.NewRequest(http.MethodPost, "/api/v1/research/compare", bytes.NewReader(body))
		rec := httptest.NewRecorder()
		nilMux.ServeHTTP(rec, req)

		if rec.Code != http.StatusServiceUnavailable {
			t.Fatalf("expected 503, got %d", rec.Code)
		}
	})

	t.Run("internal error when paper not found", func(t *testing.T) {
		store.err = errors.New("db disconnect")
		defer func() { store.err = nil }()

		body, _ := json.Marshal(map[string]any{
			"paper_ids": []string{p1ID.String(), p3ID.String()},
		})
		req := httptest.NewRequest(http.MethodPost, "/api/v1/research/compare", bytes.NewReader(body))
		rec := httptest.NewRecorder()
		mux.ServeHTTP(rec, req)

		if rec.Code != http.StatusInternalServerError {
			t.Fatalf("expected 500, got %d", rec.Code)
		}
	})
}
