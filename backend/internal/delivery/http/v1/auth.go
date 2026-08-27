package v1

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"log/slog"
	"net/http"
	"strings"

	appauth "athena/backend/internal/application/auth"
	domainuser "athena/backend/internal/domain/user"
)

// AuthHandlers serve /api/v1/auth/* and /api/v1/me.
type AuthHandlers struct {
	Svc    *appauth.Service
	Logger *slog.Logger
}

func NewAuthHandlers(svc *appauth.Service, log *slog.Logger) *AuthHandlers {
	return &AuthHandlers{Svc: svc, Logger: log}
}

// ---- DTOs -------------------------------------------------------------------

type registerRequestDTO struct {
	Email       string `json:"email"`
	Password    string `json:"password"`
	DisplayName string `json:"display_name"`
}

type loginRequestDTO struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

type userDTO struct {
	ID          string `json:"id"`
	Email       string `json:"email"`
	DisplayName string `json:"display_name"`
	AvatarURL   string `json:"avatar_url,omitempty"`
	CreatedAt   string `json:"created_at"`
}

type sessionResponseDTO struct {
	Token     string  `json:"token"`
	ExpiresAt string  `json:"expires_at"`
	User      userDTO `json:"user"`
}

func newUserDTO(u domainuser.User) userDTO {
	return userDTO{
		ID:          u.ID.String(),
		Email:       u.Email,
		DisplayName: u.DisplayName,
		AvatarURL:   u.AvatarURL,
		CreatedAt:   u.CreatedAt.Format(timeFormatRFC3339),
	}
}

// decodeJSON parses a bounded JSON request body.
func decodeJSON(r *http.Request, v any) error {
	return json.NewDecoder(io.LimitReader(r.Body, 1<<16)).Decode(v)
}

// ---- POST /api/v1/auth/register ---------------------------------------------

func (h *AuthHandlers) Register(w http.ResponseWriter, r *http.Request) {
	var req registerRequestDTO
	if err := decodeJSON(r, &req); err != nil {
		WriteError(w, r, http.StatusBadRequest, CodeInvalidRequest, "invalid JSON body")
		return
	}
	sess, err := h.Svc.Register(r.Context(), req.Email, req.Password, req.DisplayName)
	h.writeSession(w, r, http.StatusCreated, sess, err)
}

// ---- POST /api/v1/auth/login ------------------------------------------------

func (h *AuthHandlers) Login(w http.ResponseWriter, r *http.Request) {
	var req loginRequestDTO
	if err := decodeJSON(r, &req); err != nil {
		WriteError(w, r, http.StatusBadRequest, CodeInvalidRequest, "invalid JSON body")
		return
	}
	sess, err := h.Svc.Login(r.Context(), req.Email, req.Password)
	h.writeSession(w, r, http.StatusOK, sess, err)
}

func (h *AuthHandlers) writeSession(w http.ResponseWriter, r *http.Request, status int, sess domainuser.Session, err error) {
	switch {
	case errors.Is(err, appauth.ErrInvalidInput):
		WriteError(w, r, http.StatusBadRequest, CodeInvalidRequest, err.Error())
		return
	case errors.Is(err, domainuser.ErrEmailTaken):
		WriteErrorWithDetails(w, r, http.StatusConflict, CodeForbidden,
			"that email is already registered",
			[]errorDetail{{Field: "email", Issue: "already registered"}})
		return
	case errors.Is(err, domainuser.ErrInvalidCredentials):
		WriteError(w, r, http.StatusUnauthorized, CodeUnauthorized, "invalid email or password")
		return
	case err != nil:
		h.Logger.Error("auth failed", "error", err, "request_id", RequestIDFrom(r.Context()))
		WriteError(w, r, http.StatusInternalServerError, CodeInternal, "internal error")
		return
	}
	WriteJSON(w, status, sessionResponseDTO{
		Token:     sess.Token,
		ExpiresAt: sess.ExpiresAt.Format(timeFormatRFC3339),
		User:      newUserDTO(sess.User),
	})
}

// ---- GET /api/v1/me ---------------------------------------------------------

func (h *AuthHandlers) Me(w http.ResponseWriter, r *http.Request) {
	u, ok := UserFromContext(r.Context())
	if !ok {
		WriteError(w, r, http.StatusUnauthorized, CodeUnauthorized, "authentication required")
		return
	}
	WriteJSON(w, http.StatusOK, newUserDTO(u))
}

// ---- POST /api/v1/auth/logout -----------------------------------------------

func (h *AuthHandlers) Logout(w http.ResponseWriter, r *http.Request) {
	token := bearerToken(r)
	if token == "" {
		WriteError(w, r, http.StatusUnauthorized, CodeUnauthorized, "bearer token required")
		return
	}
	if err := h.Svc.Logout(r.Context(), token); err != nil {
		h.Logger.Error("logout failed", "error", err, "request_id", RequestIDFrom(r.Context()))
		WriteError(w, r, http.StatusInternalServerError, CodeInternal, "internal error")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// ---- context plumbing & Bearer middleware ------------------------------------

type userKey struct{}

// UserFromContext returns the authenticated account injected by WithAuth.
func UserFromContext(ctx context.Context) (domainuser.User, bool) {
	u, ok := ctx.Value(userKey{}).(domainuser.User)
	return u, ok
}

func bearerToken(r *http.Request) string {
	const prefix = "Bearer "
	authz := r.Header.Get("Authorization")
	if len(authz) <= len(prefix) || !strings.EqualFold(authz[:len(prefix)], prefix) {
		return ""
	}
	return strings.TrimSpace(authz[len(prefix):])
}

// WithAuth resolves the presented bearer token (when any) and stores the
// matching account in the request context. Routes decide for themselves
// whether an anonymous request is acceptable; protected endpoints respond 401.
func WithAuth(svc *appauth.Service, log *slog.Logger, next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if token := bearerToken(r); token != "" {
			u, err := svc.UserFromToken(r.Context(), token)
			switch {
			case err == nil:
				r = r.WithContext(context.WithValue(r.Context(), userKey{}, u))
			case errors.Is(err, domainuser.ErrSessionExpired),
				errors.Is(err, domainuser.ErrSessionUnknown):
				// Anonymous-with-stale-credentials: leave unauthenticated;
				// guarded routes will answer 401.
			default:
				log.Error("token resolution failed", "error", err,
					"request_id", RequestIDFrom(r.Context()))
			}
		}
		next.ServeHTTP(w, r)
	})
}

// RequireAuth answers 401 unless a valid token was resolved by WithAuth.
func RequireAuth(next func(http.ResponseWriter, *http.Request)) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if _, ok := UserFromContext(r.Context()); !ok {
			WriteError(w, r, http.StatusUnauthorized, CodeUnauthorized, "authentication required")
			return
		}
		next(w, r)
	}
}
