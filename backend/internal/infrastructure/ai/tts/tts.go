// Package tts implements text-to-speech audio synthesis adapters.
package tts

import (
	"context"
	"log/slog"
	"net/http"
	"time"

	domainaudio "athena/backend/internal/domain/audio"
)

// Config configures text-to-speech providers.
type Config struct {
	Provider string // "mock", "openai", "noop"
	BaseURL  string // Base URL override for OpenAI-compatible TTS endpoints
	APIKey   string
	Model    string // default: "tts-1"
}

// New constructs a domainaudio.Synthesizer based on configuration.
func New(cfg Config, logger *slog.Logger) domainaudio.Synthesizer {
	if logger == nil {
		logger = slog.Default()
	}

	switch cfg.Provider {
	case "openai":
		baseURL := cfg.BaseURL
		if baseURL == "" {
			baseURL = "https://api.openai.com/v1"
		}
		model := cfg.Model
		if model == "" {
			model = "tts-1"
		}
		return &OpenAISynthesizer{
			BaseURL:    baseURL,
			APIKey:     cfg.APIKey,
			Model:      model,
			HTTPClient: &http.Client{Timeout: 60 * time.Second},
			Logger:     logger,
		}
	case "noop":
		return &NopSynthesizer{}
	case "mock":
		fallthrough
	default:
		return NewMockSynthesizer()
	}
}

// NopSynthesizer returns empty audio bytes without error.
type NopSynthesizer struct{}

func (n *NopSynthesizer) SynthesizeSpeech(_ context.Context, _ string, _ string) ([]byte, error) {
	return []byte{}, nil
}

// MockSynthesizer generates deterministic, valid synthetic MP3 frames for tests and offline development.
type MockSynthesizer struct{}

func NewMockSynthesizer() *MockSynthesizer {
	return &MockSynthesizer{}
}

func (m *MockSynthesizer) SynthesizeSpeech(_ context.Context, text string, _ string) ([]byte, error) {
	// Generate valid MPEG-1 Audio Layer III frames so standard players (AVPlayer, ExoPlayer) decode successfully.
	// MPEG-1 Layer 3 frame header:
	// Sync: 0xFF 0xFB (MPEG-1, Layer 3, no CRC)
	// Bitrate/Freq: 0x90 (128 kbps, 44.1 kHz, padded)
	// Mode: 0x64 (Joint stereo)
	// Frame size for 128 kbps @ 44.1 kHz: 144 * 128000 / 44100 + 1 = 418 bytes.
	const frameLen = 418
	numFrames := 4
	if len(text) > 200 {
		numFrames = 10
	}

	buf := make([]byte, numFrames*frameLen)
	for i := 0; i < numFrames; i++ {
		offset := i * frameLen
		buf[offset] = 0xFF
		buf[offset+1] = 0xFB
		buf[offset+2] = 0x90
		buf[offset+3] = 0x64
		// Fill remaining frame payload with non-zero pseudo-audio data
		for j := 4; j < frameLen; j++ {
			buf[offset+j] = byte((i*j + 37) % 256)
		}
	}
	return buf, nil
}
