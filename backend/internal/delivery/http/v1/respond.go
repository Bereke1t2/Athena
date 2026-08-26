// Package v1 implements the REST API contract of docs/api/api-specification.md:
// thin handlers that parse requests, invoke application/domain ports, and map
// results to snake_case DTOs with cursor pagination and RFC-7807-style errors.
package v1

import (
	"context"
	"encoding/json"
	"net/http"
	"strings"
	"unicode"

	"github.com/google/uuid"
)

// Error codes are stable machine identifiers (API spec §error-envelope).
const (
	CodeInvalidRequest      = "invalid_request"
	CodeUnauthorized        = "unauthorized"
	CodeForbidden           = "forbidden"
	CodeNotFound            = "not_found"
	CodeNotImplemented      = "not_implemented"
	CodeInternal            = "internal"
	CodeUpstreamUnavailable = "upstream_unavailable"
)

type errorDetail struct {
	Field string `json:"field"`
	Issue string `json:"issue"`
}

type errorEnvelope struct {
	Error errorBody `json:"error"`
}

type errorBody struct {
	Code      string        `json:"code"`
	Message   string        `json:"message"`
	RequestID string        `json:"request_id"`
	Details   []errorDetail `json:"details,omitempty"`
}

// WriteJSON renders v as a JSON response with the given status.
func WriteJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}

// WriteError renders the standard error envelope.
func WriteError(w http.ResponseWriter, r *http.Request, status int, code, message string) {
	WriteErrorWithDetails(w, r, status, code, message, nil)
}

// WriteErrorWithDetails renders the standard error envelope with field-level
// validation details.
func WriteErrorWithDetails(w http.ResponseWriter, r *http.Request, status int, code, message string, details []errorDetail) {
	WriteJSON(w, status, errorEnvelope{Error: errorBody{
		Code:      code,
		Message:   message,
		RequestID: RequestIDFrom(r.Context()),
		Details:   details,
	}})
}

type requestIDKey struct{}

// RequestIDFrom extracts the correlation ID injected by the middleware.
func RequestIDFrom(ctx context.Context) string {
	id, _ := ctx.Value(requestIDKey{}).(string)
	return id
}

// normalizeRequestID falls back to a fresh identifier when the supplied one
// is unusable.
func normalizeRequestID(id string) string {
	id = strings.TrimSpace(id)
	if len(id) < 8 || len(id) > 128 {
		return uuid.NewString()
	}
	for _, r := range id {
		if !unicode.IsPrint(r) {
			return uuid.NewString()
		}
	}
	return id
}
