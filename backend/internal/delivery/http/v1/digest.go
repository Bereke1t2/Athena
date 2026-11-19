package v1

import (
	"bytes"
	"fmt"
	"log/slog"
	"net/http"
	"strings"
	"time"

	"github.com/google/uuid"

	appai "athena/backend/internal/application/ai"
	appdigest "athena/backend/internal/application/digest"
	domaindigest "athena/backend/internal/domain/digest"
)

// DigestHandlers handle research digest delivery.
type DigestHandlers struct {
	Svc    *appdigest.Service
	Audio  *appai.AudioService
	Logger *slog.Logger
}

// NewDigestHandlers constructs DigestHandlers.
func NewDigestHandlers(svc *appdigest.Service, log *slog.Logger) *DigestHandlers {
	if log == nil {
		log = slog.Default()
	}
	return &DigestHandlers{
		Svc:    svc,
		Logger: log,
	}
}

// WithAudio connects the research audio synthesis service.
func (h *DigestHandlers) WithAudio(audio *appai.AudioService) *DigestHandlers {
	h.Audio = audio
	return h
}

type generateDigestRequestDTO struct {
	Frequency string   `json:"frequency,omitempty"`
	Topics    []string `json:"topics,omitempty"`
}

type synthesizeDigestAudioRequestDTO struct {
	Voice  string   `json:"voice,omitempty"`
	Topics []string `json:"topics,omitempty"`
}

type digestSectionDTO struct {
	Title       string            `json:"title"`
	Description string            `json:"description"`
	Papers      []paperSummaryDTO `json:"papers"`
}

type userDigestDTO struct {
	ID           string                    `json:"id"`
	UserID       string                    `json:"user_id"`
	GeneratedAt  string                    `json:"generated_at"`
	Frequency    string                    `json:"frequency"`
	AISummary    string                    `json:"ai_summary"`
	Pulses       []domaindigest.TopicPulse `json:"pulses"`
	Sections     []digestSectionDTO        `json:"sections"`
	TopTakeaways []string                  `json:"top_takeaways"`
}

func newDigestDTO(d domaindigest.UserDigest) userDigestDTO {
	sections := make([]digestSectionDTO, len(d.Sections))
	for i, s := range d.Sections {
		papers := make([]paperSummaryDTO, len(s.Papers))
		for j, p := range s.Papers {
			papers[j] = newSummaryDTO(p)
		}
		sections[i] = digestSectionDTO{
			Title:       s.Title,
			Description: s.Description,
			Papers:      papers,
		}
	}
	return userDigestDTO{
		ID:           d.ID.String(),
		UserID:       d.UserID.String(),
		GeneratedAt:  d.GeneratedAt.UTC().Format(timeFormatRFC3339),
		Frequency:    string(d.Frequency),
		AISummary:    d.AISummary,
		Pulses:       d.Pulses,
		Sections:     sections,
		TopTakeaways: d.TopTakeaways,
	}
}

// Latest: GET /api/v1/research/digest/latest
// If the caller is authenticated, returns their personalized briefing.
// If unauthenticated (guest), returns a dynamic briefing tailored to optional ?topics=slug1,slug2 or trending science.
func (h *DigestHandlers) Latest(w http.ResponseWriter, r *http.Request) {
	if h.Svc == nil {
		WriteError(w, r, http.StatusServiceUnavailable, CodeInternal, "digest service unavailable")
		return
	}
	var userID uuid.UUID
	if user, ok := UserFromContext(r.Context()); ok {
		userID = user.ID
	}

	var customTopics []string
	if topicsParam := r.URL.Query().Get("topics"); topicsParam != "" {
		for _, t := range strings.Split(topicsParam, ",") {
			if trimmed := strings.TrimSpace(t); trimmed != "" {
				customTopics = append(customTopics, trimmed)
			}
		}
	}

	d, err := h.Svc.GetLatestDigest(r.Context(), userID, customTopics...)
	if err != nil {
		h.Logger.Error("failed to get digest", "error", err, "user_id", userID)
		WriteError(w, r, http.StatusInternalServerError, CodeInternal, "failed to get research digest")
		return
	}

	WriteJSON(w, http.StatusOK, newDigestDTO(d))
}

// Generate: POST /api/v1/research/digest/generate
func (h *DigestHandlers) Generate(w http.ResponseWriter, r *http.Request) {
	if h.Svc == nil {
		WriteError(w, r, http.StatusServiceUnavailable, CodeInternal, "digest service unavailable")
		return
	}
	user, ok := UserFromContext(r.Context())
	if !ok {
		WriteError(w, r, http.StatusUnauthorized, CodeUnauthorized, "authentication required")
		return
	}

	var req generateDigestRequestDTO
	// Optional body
	if r.Body != nil && r.ContentLength > 0 {
		_ = decodeJSON(r, &req)
	}

	freq := domaindigest.FrequencyWeekly
	if req.Frequency == string(domaindigest.FrequencyDaily) {
		freq = domaindigest.FrequencyDaily
	}

	d, err := h.Svc.GenerateDigest(r.Context(), user.ID, freq, req.Topics...)
	if err != nil {
		h.Logger.Error("failed to generate digest", "error", err, "user_id", user.ID)
		WriteError(w, r, http.StatusInternalServerError, CodeInternal, "failed to generate research digest")
		return
	}

	WriteJSON(w, http.StatusCreated, newDigestDTO(d))
}

// SynthesizeAudio: POST /api/v1/research/digest/audio
// Generates a continuous, speech-ready weekly narrative podcast episode with chapter markers.
func (h *DigestHandlers) SynthesizeAudio(w http.ResponseWriter, r *http.Request) {
	if h.Svc == nil || h.Audio == nil {
		WriteError(w, r, http.StatusServiceUnavailable, CodeNotImplemented, "audio synthesis not configured")
		return
	}

	var userID uuid.UUID
	if user, ok := UserFromContext(r.Context()); ok {
		userID = user.ID
	}

	var req synthesizeDigestAudioRequestDTO
	if r.Body != nil && r.ContentLength > 0 {
		_ = decodeJSON(r, &req)
	}

	topics := req.Topics
	if len(topics) == 0 {
		if topicsParam := r.URL.Query().Get("topics"); topicsParam != "" {
			for _, t := range strings.Split(topicsParam, ",") {
				if trimmed := strings.TrimSpace(t); trimmed != "" {
					topics = append(topics, trimmed)
				}
			}
		}
	}

	d, err := h.Svc.GetLatestDigest(r.Context(), userID, topics...)
	if err != nil {
		h.Logger.Error("failed to get digest for audio synthesis", "error", err, "user_id", userID)
		WriteError(w, r, http.StatusInternalServerError, CodeInternal, "failed to get research digest for audio")
		return
	}

	narration, err := h.Audio.SynthesizeDigestAudio(r.Context(), d, req.Voice)
	if err != nil {
		h.Logger.Error("failed to synthesize digest audio", "error", err, "digest_id", d.ID)
		WriteError(w, r, http.StatusInternalServerError, CodeInternal, "failed to synthesize weekly audio briefing")
		return
	}

	WriteJSON(w, http.StatusOK, narration)
}

// StreamAudio: GET /api/v1/research/digest/audio/stream
// Streams the latest generated weekly research podcast with RFC-7233 partial content range support.
func (h *DigestHandlers) StreamAudio(w http.ResponseWriter, r *http.Request) {
	if h.Audio == nil {
		WriteError(w, r, http.StatusServiceUnavailable, CodeNotImplemented, "audio synthesis not configured")
		return
	}

	audioBytes, err := h.Audio.GetDigestAudioStream(r.Context(), uuid.Nil)
	if err != nil {
		WriteError(w, r, http.StatusNotFound, CodeNotFound, "digest audio not found")
		return
	}

	w.Header().Set("Content-Type", "audio/mpeg")
	w.Header().Set("Accept-Ranges", "bytes")
	http.ServeContent(w, r, "weekly-digest.mp3", time.Time{}, bytes.NewReader(audioBytes))
}

// StreamAudioByID: GET /api/v1/research/digest/{id}/audio/stream
// Streams a specific weekly research podcast by digest UUID.
func (h *DigestHandlers) StreamAudioByID(w http.ResponseWriter, r *http.Request) {
	if h.Audio == nil {
		WriteError(w, r, http.StatusServiceUnavailable, CodeNotImplemented, "audio synthesis not configured")
		return
	}

	id, err := uuid.Parse(r.PathValue("id"))
	if err != nil {
		WriteError(w, r, http.StatusBadRequest, CodeInvalidRequest, "invalid digest id")
		return
	}

	audioBytes, err := h.Audio.GetDigestAudioStream(r.Context(), id)
	if err != nil {
		WriteError(w, r, http.StatusNotFound, CodeNotFound, "digest audio not found")
		return
	}

	w.Header().Set("Content-Type", "audio/mpeg")
	w.Header().Set("Accept-Ranges", "bytes")
	http.ServeContent(w, r, fmt.Sprintf("%s.mp3", id.String()), time.Time{}, bytes.NewReader(audioBytes))
}
