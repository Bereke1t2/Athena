// Package audio defines domain representations for structured research paper audio syntheses.
package audio

import (
	"context"
	"errors"
	"time"

	"github.com/google/uuid"
)

var (
	ErrPaperNotFound = errors.New("audio: paper not found")
	ErrInvalidVoice  = errors.New("audio: invalid voice selected")
	ErrAudioNotFound = errors.New("audio: narration or audio track not found")
)

// Synthesizer converts text scripts into playable speech audio bytes.
type Synthesizer interface {
	SynthesizeSpeech(ctx context.Context, text string, voice string) ([]byte, error)
}

// MediaStore stores and retrieves binary audio tracks.
type MediaStore interface {
	SaveAudio(ctx context.Context, key string, data []byte) error
	GetAudio(ctx context.Context, key string) ([]byte, error)
}

// AudioChapter represents one section of the synthesized audio episode.
type AudioChapter struct {
	Index              int    `json:"index"`
	Title              string `json:"title"`
	StartOffsetSeconds int    `json:"start_offset_seconds"`
	DurationSeconds    int    `json:"duration_seconds"`
	Script             string `json:"script,omitempty"`
}

// AudioQuote represents a highlighted pull quote with audio timestamp.
type AudioQuote struct {
	Quote            string `json:"quote"`
	Context          string `json:"context"`
	TimestampSeconds int    `json:"timestamp_seconds"`
}

// AudioNarration is a complete structured audio episode generated for a paper.
type AudioNarration struct {
	ID                   string         `json:"id"`
	PaperID              uuid.UUID      `json:"paper_id"`
	Title                string         `json:"title"`
	AuthorVenue          string         `json:"author_venue"`
	TotalDurationSeconds int            `json:"total_duration_seconds"`
	Voice                string         `json:"voice"`
	Chapters             []AudioChapter `json:"chapters"`
	Takeaways            []string       `json:"takeaways"`
	PullQuote            AudioQuote     `json:"pull_quote"`
	Tags                 []string       `json:"tags"`
	AudioURL             string         `json:"audio_url,omitempty"`
	CreatedAt            time.Time      `json:"created_at"`
}
