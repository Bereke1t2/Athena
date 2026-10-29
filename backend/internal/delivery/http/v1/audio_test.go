package v1

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/google/uuid"

	appai "athena/backend/internal/application/ai"
	domainaudio "athena/backend/internal/domain/audio"
	"athena/backend/internal/domain/research"
)

func TestSynthesizeAudioEndpoint(t *testing.T) {
	paperID := uuid.New()
	abstract := "Neural models struggle with long-context memory retention. We propose continuous state compression."
	store := &fakePaperStoreForComp{
		papers: map[uuid.UUID]research.PaperDetail{
			paperID: {
				Summary: research.PaperSummary{
					ID:              paperID,
					Title:           "Continuous State Compression in Deep Networks",
					Abstract:        &abstract,
					PublicationType: research.PubTypeArticle,
					Year:            2025,
					VenueName:       "ICLR",
				},
				Authors: []research.AuthorLine{{Name: "Bengio"}},
			},
		},
	}

	audioSvc := appai.NewAudioService(nil, store, discardLogger())
	h := &AIHandlers{
		Audio:  audioSvc,
		Logger: discardLogger(),
	}

	mux := http.NewServeMux()
	mux.HandleFunc("POST /api/v1/research/papers/{id}/audio", h.SynthesizeAudio)

	body := []byte(`{"voice":"Echo","length":"standard","focus":"methodology"}`)
	req := httptest.NewRequest(http.MethodPost, "/api/v1/research/papers/"+paperID.String()+"/audio", bytes.NewReader(body))
	rec := httptest.NewRecorder()
	mux.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200, body: %s", rec.Code, rec.Body.String())
	}

	var res domainaudio.AudioNarration
	if err := json.Unmarshal(rec.Body.Bytes(), &res); err != nil {
		t.Fatalf("unmarshal error: %v", err)
	}

	if res.Title != "Continuous State Compression in Deep Networks" {
		t.Errorf("unexpected title: %s", res.Title)
	}
	if len(res.Chapters) != 3 {
		t.Errorf("expected 3 chapters, got %d", len(res.Chapters))
	}
	if res.Voice != "Echo" {
		t.Errorf("expected voice Echo, got %s", res.Voice)
	}
}
