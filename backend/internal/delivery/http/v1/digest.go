package v1

import (
	"log/slog"
	"net/http"
	"strings"

	"github.com/google/uuid"

	appdigest "athena/backend/internal/application/digest"
	domaindigest "athena/backend/internal/domain/digest"
)

// DigestHandlers handle research digest delivery.
type DigestHandlers struct {
	Svc    *appdigest.Service
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

type generateDigestRequestDTO struct {
	Frequency string   `json:"frequency,omitempty"`
	Topics    []string `json:"topics,omitempty"`
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
