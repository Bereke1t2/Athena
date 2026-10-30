package tts_test

import (
	"context"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	domainaudio "athena/backend/internal/domain/audio"
	"athena/backend/internal/infrastructure/ai/tts"
)

func TestMockSynthesizer(t *testing.T) {
	ctx := context.Background()
	synth := tts.NewMockSynthesizer()

	audio, err := synth.SynthesizeSpeech(ctx, "Hello world, this is research podcast narration.", "Alloy")
	require.NoError(t, err)
	require.NotEmpty(t, audio)

	// Verify MPEG-1 Layer 3 frame sync header: 0xFF 0xFB
	assert.Equal(t, byte(0xFF), audio[0])
	assert.Equal(t, byte(0xFB), audio[1])
}

func TestOpenAISynthesizer_Success(t *testing.T) {
	var capturedReq map[string]any
	var authHeader string

	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		authHeader = r.Header.Get("Authorization")
		body, _ := io.ReadAll(r.Body)
		_ = json.Unmarshal(body, &capturedReq)

		w.Header().Set("Content-Type", "audio/mpeg")
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte{0xFF, 0xFB, 0x90, 0x64, 0xAA, 0xBB})
	}))
	defer srv.Close()

	synth := tts.New(tts.Config{
		Provider: "openai",
		BaseURL:  srv.URL,
		APIKey:   "test-key",
		Model:    "tts-1",
	}, nil)

	audio, err := synth.SynthesizeSpeech(context.Background(), "Introduction to neural scaling laws.", "Nova")
	require.NoError(t, err)
	assert.Equal(t, "Bearer test-key", authHeader)
	assert.Equal(t, "Introduction to neural scaling laws.", capturedReq["input"])
	assert.Equal(t, "nova", capturedReq["voice"])
	assert.Equal(t, "tts-1", capturedReq["model"])
	assert.Equal(t, []byte{0xFF, 0xFB, 0x90, 0x64, 0xAA, 0xBB}, audio)
}

func TestMemoryMediaStore(t *testing.T) {
	ctx := context.Background()
	store := tts.NewMemoryMediaStore()

	key := "test-audio-1"
	sampleData := []byte{0x01, 0x02, 0x03}

	// Not found initially
	_, err := store.GetAudio(ctx, key)
	assert.ErrorIs(t, err, domainaudio.ErrAudioNotFound)

	// Save and retrieve
	require.NoError(t, store.SaveAudio(ctx, key, sampleData))
	retrieved, err := store.GetAudio(ctx, key)
	require.NoError(t, err)
	assert.Equal(t, sampleData, retrieved)
}
