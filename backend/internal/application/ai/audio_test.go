package ai

import (
	"context"
	"fmt"
	"testing"

	"github.com/google/uuid"

	domainai "athena/backend/internal/domain/ai"
	domainaudio "athena/backend/internal/domain/audio"
	"athena/backend/internal/domain/research"
)

type mockAudioPaperSource struct {
	detail research.PaperDetail
	err    error
}

func (m *mockAudioPaperSource) GetDetailByID(_ context.Context, _ uuid.UUID) (research.PaperDetail, error) {
	return m.detail, m.err
}

func TestAudioServiceFallbackSynthesize(t *testing.T) {
	paperID := uuid.New()
	abstract := "The dominant sequence transduction models are based on complex recurrent or convolutional neural networks. We propose the Transformer."
	paperSource := &mockAudioPaperSource{
		detail: research.PaperDetail{
			Summary: research.PaperSummary{
				ID:        paperID,
				Title:     "Attention Is All You Need",
				Abstract:  &abstract,
				VenueName: "NeurIPS",
				Year:      2017,
			},
		},
	}

	// AudioService without LLM uses structured fallback
	svc := NewAudioService(nil, paperSource, nil)
	narration, err := svc.Synthesize(context.Background(), paperID, "Alloy", "standard", "general")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if narration.Title != "Attention Is All You Need" {
		t.Errorf("expected title Attention Is All You Need, got %s", narration.Title)
	}
	if len(narration.Chapters) != 3 {
		t.Fatalf("expected 3 chapters, got %d", len(narration.Chapters))
	}
	if narration.Chapters[0].StartOffsetSeconds != 0 {
		t.Errorf("first chapter offset should be 0, got %d", narration.Chapters[0].StartOffsetSeconds)
	}
	if len(narration.Takeaways) != 3 {
		t.Errorf("expected 3 takeaways, got %d", len(narration.Takeaways))
	}
	if narration.PullQuote.Quote == "" {
		t.Errorf("expected non-empty pull quote")
	}
}

type mockAudioLLM struct {
	response string
	err      error
}

func (m *mockAudioLLM) Generate(_ context.Context, _ domainai.GenerateRequest) (domainai.GenerateResponse, error) {
	return domainai.GenerateResponse{
		Text: m.response,
	}, m.err
}

func (m *mockAudioLLM) GenerateStream(_ context.Context, _ domainai.GenerateRequest) (domainai.StreamReader, error) {
	return nil, nil
}

func (m *mockAudioLLM) Model() string {
	return "mock-audio-llm"
}

func TestAudioServiceLLMSynthesize(t *testing.T) {
	paperID := uuid.New()
	abstract := "Deeper neural networks are more difficult to train. We present a residual learning framework."
	paperSource := &mockAudioPaperSource{
		detail: research.PaperDetail{
			Summary: research.PaperSummary{
				ID:        paperID,
				Title:     "Deep Residual Learning",
				Abstract:  &abstract,
				VenueName: "CVPR",
				Year:      2016,
			},
		},
	}

	llmJSON := `{
		"chapters": [
			{"index": 1, "title": "The Vanishing Gradient Bottleneck", "duration_seconds": 150, "script": "Intro script"},
			{"index": 2, "title": "Identity Shortcuts & ResNet Architecture", "duration_seconds": 350, "script": "Tech script"},
			{"index": 3, "title": "ImageNet Breakthrough & Lasting Impact", "duration_seconds": 220, "script": "Conclusion script"}
		],
		"takeaways": [
			"Residual connections allow training models with unprecedented 152 layers.",
			"Empirical degradation problem is solved without parameter explosion."
		],
		"pull_quote": {
			"quote": "Residual learning simplifies optimization of deep representations.",
			"context": "Chapter 2",
			"timestamp_seconds": 200
		}
	}`

	mockLLM := &mockAudioLLM{response: "```json\n" + llmJSON + "\n```"}
	svc := NewAudioService(mockLLM, paperSource, nil)

	narration, err := svc.Synthesize(context.Background(), paperID, "Echo", "brief", "methodology")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if len(narration.Chapters) != 3 {
		t.Fatalf("expected 3 chapters, got %d", len(narration.Chapters))
	}
	if narration.Chapters[1].Title != "Identity Shortcuts & ResNet Architecture" {
		t.Errorf("unexpected chapter title: %s", narration.Chapters[1].Title)
	}
	if len(narration.Takeaways) != 2 {
		t.Errorf("expected 2 takeaways, got %d", len(narration.Takeaways))
	}
	if narration.PullQuote.TimestampSeconds != 200 {
		t.Errorf("expected timestamp 200, got %d", narration.PullQuote.TimestampSeconds)
	}
}

type mockSynth struct {
	calledWithText string
}

func (m *mockSynth) SynthesizeSpeech(_ context.Context, text, _ string) ([]byte, error) {
	m.calledWithText = text
	return []byte{0xFF, 0xFB, 0x90, 0x64, 0x01, 0x02}, nil
}

type mockMedia struct {
	data map[string][]byte
}

func (m *mockMedia) SaveAudio(_ context.Context, key string, data []byte) error {
	if m.data == nil {
		m.data = make(map[string][]byte)
	}
	m.data[key] = data
	return nil
}

func (m *mockMedia) GetAudio(_ context.Context, key string) ([]byte, error) {
	if d, ok := m.data[key]; ok {
		return d, nil
	}
	return nil, domainaudio.ErrAudioNotFound
}

func TestAudioService_WithTTSAndStreaming(t *testing.T) {
	paperID := uuid.New()
	paperSource := &mockAudioPaperSource{
		detail: research.PaperDetail{
			Summary: research.PaperSummary{
				ID:        paperID,
				Title:     "Quantum Teleportation Protocols",
				VenueName: "Nature Physics",
				Year:      2024,
			},
		},
	}

	synth := &mockSynth{}
	media := &mockMedia{}

	svc := NewAudioService(nil, paperSource, nil).WithTTS(synth, media)

	ctx := context.Background()
	narration, err := svc.Synthesize(ctx, paperID, "Alloy", "brief", "general")
	if err != nil {
		t.Fatalf("Synthesize failed: %v", err)
	}

	expectedURL := fmt.Sprintf("/api/v1/research/papers/%s/audio/stream", paperID.String())
	if narration.AudioURL != expectedURL {
		t.Errorf("expected AudioURL %s, got %s", expectedURL, narration.AudioURL)
	}

	if synth.calledWithText == "" {
		t.Error("expected synthesizer to be called with script text")
	}

	// Verify stream retrieval
	streamBytes, err := svc.GetAudioStream(ctx, paperID)
	if err != nil {
		t.Fatalf("GetAudioStream failed: %v", err)
	}
	if len(streamBytes) != 6 || streamBytes[0] != 0xFF {
		t.Errorf("unexpected stream audio bytes: %v", streamBytes)
	}
}
