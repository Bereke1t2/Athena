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
	expectedAudioURL := "/api/v1/research/papers/" + paperID.String() + "/audio/stream"
	if res.AudioURL != expectedAudioURL {
		t.Errorf("expected audio_url %s, got %s", expectedAudioURL, res.AudioURL)
	}
}

func TestStreamAudioEndpoint(t *testing.T) {
	paperID := uuid.New()
	abstract := "Audio streaming verification abstract."
	store := &fakePaperStoreForComp{
		papers: map[uuid.UUID]research.PaperDetail{
			paperID: {
				Summary: research.PaperSummary{
					ID:        paperID,
					Title:     "Streaming Audio Validation",
					Abstract:  &abstract,
					Year:      2025,
					VenueName: "NeurIPS",
				},
			},
		},
	}

	audioSvc := appai.NewAudioService(nil, store, discardLogger())
	h := &AIHandlers{
		Audio:  audioSvc,
		Logger: discardLogger(),
	}

	mux := http.NewServeMux()
	mux.HandleFunc("GET /api/v1/research/papers/{id}/audio/stream", h.StreamAudio)

	// 1. Full stream request
	req := httptest.NewRequest(http.MethodGet, "/api/v1/research/papers/"+paperID.String()+"/audio/stream", nil)
	rec := httptest.NewRecorder()
	mux.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("stream status = %d, want 200, body: %s", rec.Code, rec.Body.String())
	}
	if ct := rec.Header().Get("Content-Type"); ct != "audio/mpeg" {
		t.Errorf("expected Content-Type audio/mpeg, got %s", ct)
	}
	if ar := rec.Header().Get("Accept-Ranges"); ar != "bytes" {
		t.Errorf("expected Accept-Ranges bytes, got %s", ar)
	}

	// 2. HTTP Range request (seeking)
	rangeReq := httptest.NewRequest(http.MethodGet, "/api/v1/research/papers/"+paperID.String()+"/audio/stream", nil)
	rangeReq.Header.Set("Range", "bytes=0-3")
	rangeRec := httptest.NewRecorder()
	mux.ServeHTTP(rangeRec, rangeReq)

	if rangeRec.Code != http.StatusPartialContent {
		t.Fatalf("range request status = %d, want 206", rangeRec.Code)
	}
	if rangeRec.Body.Len() != 4 {
		t.Errorf("expected 4 bytes for range 0-3, got %d", rangeRec.Body.Len())
	}
}
