package v1

import (
	"log/slog"
	"net/http"

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
	Frequency string `json:"frequency,omitempty"`
}

// Latest: GET /api/v1/research/digest/latest
func (h *DigestHandlers) Latest(w http.ResponseWriter, r *http.Request) {
	if h.Svc == nil {
		WriteError(w, r, http.StatusServiceUnavailable, CodeInternal, "digest service unavailable")
		return
	}
	user, ok := UserFromContext(r.Context())
	if !ok {
		WriteError(w, r, http.StatusUnauthorized, CodeUnauthorized, "authentication required")
		return
	}

	d, err := h.Svc.GetLatestDigest(r.Context(), user.ID)
	if err != nil {
		h.Logger.Error("failed to get digest", "error", err, "user_id", user.ID)
		WriteError(w, r, http.StatusInternalServerError, CodeInternal, "failed to get research digest")
		return
	}

	WriteJSON(w, http.StatusOK, d)
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

	d, err := h.Svc.GenerateDigest(r.Context(), user.ID, freq)
	if err != nil {
		h.Logger.Error("failed to generate digest", "error", err, "user_id", user.ID)
		WriteError(w, r, http.StatusInternalServerError, CodeInternal, "failed to generate research digest")
		return
	}

	WriteJSON(w, http.StatusCreated, d)
}
