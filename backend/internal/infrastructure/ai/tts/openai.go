package tts

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"strings"
)

// OpenAISynthesizer calls the OpenAI /v1/audio/speech endpoint (or compatible proxy).
type OpenAISynthesizer struct {
	BaseURL    string
	APIKey     string
	Model      string
	HTTPClient *http.Client
	Logger     *slog.Logger
}

type openAITTSRequest struct {
	Model          string `json:"model"`
	Input          string `json:"input"`
	Voice          string `json:"voice"`
	ResponseFormat string `json:"response_format,omitempty"`
}

func (s *OpenAISynthesizer) SynthesizeSpeech(ctx context.Context, text string, voice string) ([]byte, error) {
	if text == "" {
		return []byte{}, nil
	}

	url := strings.TrimSuffix(s.BaseURL, "/") + "/audio/speech"

	// Map known voices to valid OpenAI voices (alloy, echo, fable, onyx, nova, shimmer)
	selectedVoice := strings.ToLower(strings.TrimSpace(voice))
	switch selectedVoice {
	case "alloy", "echo", "fable", "onyx", "nova", "shimmer":
		// valid
	default:
		selectedVoice = "alloy"
	}

	payload := openAITTSRequest{
		Model:          s.Model,
		Input:          text,
		Voice:          selectedVoice,
		ResponseFormat: "mp3",
	}

	bodyBytes, err := json.Marshal(payload)
	if err != nil {
		return nil, fmt.Errorf("marshal tts request: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(bodyBytes))
	if err != nil {
		return nil, fmt.Errorf("create tts request: %w", err)
	}

	req.Header.Set("Content-Type", "application/json")
	if s.APIKey != "" {
		req.Header.Set("Authorization", "Bearer "+s.APIKey)
	}

	resp, err := s.HTTPClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("execute tts request: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		errBody, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("tts api error (status %d): %s", resp.StatusCode, string(errBody))
	}

	audioBytes, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("read tts audio stream: %w", err)
	}

	return audioBytes, nil
}
