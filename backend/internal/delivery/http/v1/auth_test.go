package v1

import (
	"context"
	"crypto/sha256"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"

	appauth "athena/backend/internal/application/auth"
	domainuser "athena/backend/internal/domain/user"
)

type fakeAuthResetRow struct {
	userID    uuid.UUID
	expiresAt time.Time
	used      bool
}

type fakeAuthUsers struct {
	mu     sync.Mutex
	mail   map[string]domainuser.Credential
	resets map[string]fakeAuthResetRow
	taken  bool
}

func (f *fakeAuthUsers) Create(_ context.Context, nu domainuser.NewUser) (domainuser.User, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	if f.taken {
		return domainuser.User{}, domainuser.ErrEmailTaken
	}
	if _, exists := f.mail[strings.ToLower(nu.User.Email)]; exists {
		return domainuser.User{}, domainuser.ErrEmailTaken
	}
	f.mail[strings.ToLower(nu.User.Email)] = domainuser.Credential{User: nu.User, PasswordHash: nu.PasswordHash}
	return nu.User, nil
}

func (f *fakeAuthUsers) ByEmail(_ context.Context, email string) (domainuser.Credential, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	c, ok := f.mail[strings.ToLower(email)]
	if !ok {
		return c, domainuser.ErrNotFound
	}
	return c, nil
}

func (f *fakeAuthUsers) ByID(_ context.Context, id uuid.UUID) (domainuser.User, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	for _, c := range f.mail {
		if c.User.ID == id {
			return c.User, nil
		}
	}
	return domainuser.User{}, domainuser.ErrNotFound
}

func (f *fakeAuthUsers) Delete(_ context.Context, id uuid.UUID) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	for email, c := range f.mail {
		if c.User.ID == id {
			delete(f.mail, email)
			return nil
		}
	}
	return domainuser.ErrNotFound
}

func (f *fakeAuthUsers) UpdatePassword(_ context.Context, id uuid.UUID, passwordHash string) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	for email, c := range f.mail {
		if c.User.ID == id {
			c.PasswordHash = passwordHash
			f.mail[email] = c
			return nil
		}
	}
	return domainuser.ErrNotFound
}

func (f *fakeAuthUsers) CreatePasswordReset(_ context.Context, userID uuid.UUID, tokenHash []byte, expiresAt time.Time) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	if f.resets == nil {
		f.resets = make(map[string]fakeAuthResetRow)
	}
	f.resets[string(tokenHash)] = fakeAuthResetRow{
		userID:    userID,
		expiresAt: expiresAt,
		used:      false,
	}
	return nil
}

func (f *fakeAuthUsers) ConsumePasswordReset(_ context.Context, tokenHash []byte) (uuid.UUID, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	row, ok := f.resets[string(tokenHash)]
	if !ok || row.used || time.Now().UTC().After(row.expiresAt) {
		return uuid.Nil, domainuser.ErrInvalidResetToken
	}
	row.used = true
	f.resets[string(tokenHash)] = row
	return row.userID, nil
}

func (f *fakeAuthUsers) UpdateExplanationLevel(_ context.Context, id uuid.UUID, level string) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	for email, c := range f.mail {
		if c.User.ID == id {
			u := c.User
			u.ExplanationLevel = level
			f.mail[email] = domainuser.Credential{User: u, PasswordHash: c.PasswordHash}
			return nil
		}
	}
	return domainuser.ErrNotFound
}

// adaID is the fixed account resolved for bearer token "tok-1".
var adaID = uuid.MustParse("0197c0de-0000-7000-8000-000000000001")

func sha256Hex(token string) string {
	sum := sha256.Sum256([]byte(token))
	return string(sum[:])
}

type fakeAuthSessions struct{ mu sync.Mutex }

func (f *fakeAuthSessions) Issue(context.Context, uuid.UUID, []byte, time.Time) error { return nil }
func (f *fakeAuthSessions) Revoke(context.Context, []byte) error                      { return nil }
func (f *fakeAuthSessions) UserByTokenHash(_ context.Context, tokenHash []byte) (domainuser.User, time.Time, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	if string(tokenHash) == sha256Hex("tok-1") {
		u := domainuser.User{ID: adaID, Email: "ada@x.io", DisplayName: "Ada"}
		return u, time.Now().Add(time.Hour), nil
	}
	return domainuser.User{}, time.Time{}, domainuser.ErrSessionUnknown
}

// passthroughHasher mirrors the fast hasher used by the service tests.
type passthroughHasher struct{}

func (passthroughHasher) Hash(p string) (string, error) { return "fast$" + p, nil }
func (passthroughHasher) Verify(hash, p string) bool    { return hash == "fast$"+p }

func newTestAuthHandlers(taken bool) (*AuthHandlers, *appauth.Service) {
	users := &fakeAuthUsers{mail: map[string]domainuser.Credential{}, taken: taken}
	sessions := &fakeAuthSessions{}
	svc := appauth.NewService(users, sessions, passthroughHasher{})
	return NewAuthHandlers(svc, testLogger()), svc
}

func postJSON(t *testing.T, h *AuthHandlers, path, body string) *httptest.ResponseRecorder {
	t.Helper()
	r := httptest.NewRequest(http.MethodPost, path, strings.NewReader(body))
	w := httptest.NewRecorder()
	switch path {
	case "/api/v1/auth/register":
		h.Register(w, r)
	case "/api/v1/auth/login":
		h.Login(w, r)
	default:
		t.Fatalf("unrouted path %q", path)
	}
	return w
}

func TestRegisterHandler201AndShape(t *testing.T) {
	h, _ := newTestAuthHandlers(false)
	w := postJSON(t, h, "/api/v1/auth/register",
		`{"email":"ada@x.io","password":"password123","display_name":"Ada"}`)
	if w.Code != http.StatusCreated {
		t.Fatalf("status %d: %s", w.Code, w.Body.String())
	}
	var out sessionResponseDTO
	if err := json.Unmarshal(w.Body.Bytes(), &out); err != nil {
		t.Fatal(err)
	}
	if out.Token == "" || out.User.Email != "ada@x.io" || out.ExpiresAt == "" {
		t.Fatalf("unexpected session body %+v", out)
	}
}

func TestRegisterHandlerValidationErrors(t *testing.T) {
	cases := map[string]struct {
		taken bool
		body  string
		want  int
	}{
		"bad json":    {false, "{oops", http.StatusBadRequest},
		"bad email":   {false, `{"email":"nope","password":"password123"}`, http.StatusBadRequest},
		"short pass":  {false, `{"email":"a@b.c","password":"x"}`, http.StatusBadRequest},
		"email taken": {true, `{"email":"taken@x.io","password":"password123"}`, http.StatusConflict},
	}
	for name, c := range cases {
		h, _ := newTestAuthHandlers(c.taken)
		w := postJSON(t, h, "/api/v1/auth/register", c.body)
		if w.Code != c.want {
			t.Errorf("%s: status %d, want %d (%s)", name, w.Code, c.want, w.Body.String())
		}
	}
}

func TestLoginHandlerUnauthorizedOnBadCredentials(t *testing.T) {
	h, _ := newTestAuthHandlers(false)
	w := postJSON(t, h, "/api/v1/auth/login", `{"email":"ghost@x.io","password":"password123"}`)
	if w.Code != http.StatusUnauthorized {
		t.Fatalf("status %d: %s", w.Code, w.Body.String())
	}
	var env errorEnvelope
	if err := json.Unmarshal(w.Body.Bytes(), &env); err != nil {
		t.Fatal(err)
	}
	if env.Error.Code != CodeUnauthorized {
		t.Fatalf("code %q", env.Error.Code)
	}
}

func TestMeHandlerRequiresAuth(t *testing.T) {
	h, _ := newTestAuthHandlers(false)

	r := httptest.NewRequest(http.MethodGet, "/api/v1/me", nil)
	w := httptest.NewRecorder()
	h.Me(w, r)
	if w.Code != http.StatusUnauthorized {
		t.Fatalf("anonymous /me: status %d", w.Code)
	}

	ctx := context.WithValue(r.Context(), userKey{},
		domainuser.User{ID: adaID, Email: "ada@x.io", DisplayName: "Ada"})
	r = r.WithContext(ctx)
	w = httptest.NewRecorder()
	h.Me(w, r)
	if w.Code != http.StatusOK {
		t.Fatalf("authenticated /me: status %d: %s", w.Code, w.Body.String())
	}
}

func TestWithAuthMiddlewareResolvesBearer(t *testing.T) {
	_, svc := newTestAuthHandlers(false)
	next := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		u, ok := UserFromContext(r.Context())
		if !ok {
			w.WriteHeader(http.StatusTeapot)
			return
		}
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte(u.Email))
	})
	handler := WithAuth(svc, testLogger(), next)

	r := httptest.NewRequest(http.MethodGet, "/api/v1/me", nil)
	r.Header.Set("Authorization", "Bearer tok-1")
	w := httptest.NewRecorder()
	handler.ServeHTTP(w, r)
	if w.Code != http.StatusOK || w.Body.String() != "ada@x.io" {
		t.Fatalf("bearer not resolved: %d %s", w.Code, w.Body.String())
	}

	// Stale token falls through as anonymous rather than failing the request.
	r2 := httptest.NewRequest(http.MethodGet, "/api/v1/me", nil)
	r2.Header.Set("Authorization", "Bearer stale")
	w2 := httptest.NewRecorder()
	handler.ServeHTTP(w2, r2)
	if w2.Code != http.StatusTeapot {
		t.Fatalf("stale token should be anonymous, got %d", w2.Code)
	}
}

func TestLogoutHandler204(t *testing.T) {
	h, _ := newTestAuthHandlers(false)
	r := httptest.NewRequest(http.MethodPost, "/api/v1/auth/logout", nil)
	r.Header.Set("Authorization", "Bearer tok-1")
	w := httptest.NewRecorder()
	h.Logout(w, r)
	if w.Code != http.StatusNoContent {
		t.Fatalf("status %d: %s", w.Code, w.Body.String())
	}

	// Missing token is a 401.
	w2 := httptest.NewRecorder()
	h.Logout(w2, httptest.NewRequest(http.MethodPost, "/api/v1/auth/logout", nil))
	if w2.Code != http.StatusUnauthorized {
		t.Fatalf("missing token logout: %d", w2.Code)
	}
}

func TestRefreshHandler(t *testing.T) {
	h, _ := newTestAuthHandlers(false)

	// Missing token -> 401
	wMissing := httptest.NewRecorder()
	h.Refresh(wMissing, httptest.NewRequest(http.MethodPost, "/api/v1/auth/refresh", nil))
	if wMissing.Code != http.StatusUnauthorized {
		t.Fatalf("missing token refresh: %d", wMissing.Code)
	}

	// Valid token -> 200 with new session
	r := httptest.NewRequest(http.MethodPost, "/api/v1/auth/refresh", nil)
	r.Header.Set("Authorization", "Bearer tok-1")
	w := httptest.NewRecorder()
	h.Refresh(w, r)
	if w.Code != http.StatusOK {
		t.Fatalf("refresh status %d: %s", w.Code, w.Body.String())
	}
	var res sessionResponseDTO
	if err := json.Unmarshal(w.Body.Bytes(), &res); err != nil {
		t.Fatal(err)
	}
	if res.Token == "" || res.User.ID != adaID.String() {
		t.Errorf("unexpected refresh response: %+v", res)
	}
}

func TestDeleteMeHandler(t *testing.T) {
	h, svc := newTestAuthHandlers(false)

	// Unauthenticated -> 401
	wUnauth := httptest.NewRecorder()
	h.DeleteMe(wUnauth, httptest.NewRequest(http.MethodDelete, "/api/v1/me", nil))
	if wUnauth.Code != http.StatusUnauthorized {
		t.Fatalf("unauth delete me: %d", wUnauth.Code)
	}

	// Register user
	sess, err := svc.Register(context.Background(), "delete@x.io", "password123", "Deleter")
	if err != nil {
		t.Fatal(err)
	}

	// Authenticated -> 204
	r := httptest.NewRequest(http.MethodDelete, "/api/v1/me", nil)
	ctx := context.WithValue(r.Context(), userKey{}, sess.User)
	w := httptest.NewRecorder()
	h.DeleteMe(w, r.WithContext(ctx))
	if w.Code != http.StatusNoContent {
		t.Fatalf("delete me status %d: %s", w.Code, w.Body.String())
	}
}

func TestUpdateExplanationLevelHandler(t *testing.T) {
	h, svc := newTestAuthHandlers(false)

	// Unauthenticated -> 401
	wUnauth := httptest.NewRecorder()
	h.UpdateExplanationLevel(wUnauth, httptest.NewRequest(http.MethodPut, "/api/v1/me/explanation-level", strings.NewReader(`{"level":"expert"}`)))
	if wUnauth.Code != http.StatusUnauthorized {
		t.Fatalf("unauth update level: %d", wUnauth.Code)
	}

	// Register user
	sess, err := svc.Register(context.Background(), "level@x.io", "password123", "LevelUser")
	if err != nil {
		t.Fatal(err)
	}

	// Invalid level -> 400
	rInv := httptest.NewRequest(http.MethodPut, "/api/v1/me/explanation-level", strings.NewReader(`{"level":"superhero"}`))
	ctx := context.WithValue(rInv.Context(), userKey{}, sess.User)
	wInv := httptest.NewRecorder()
	h.UpdateExplanationLevel(wInv, rInv.WithContext(ctx))
	if wInv.Code != http.StatusBadRequest {
		t.Fatalf("invalid level status %d: %s", wInv.Code, wInv.Body.String())
	}

	// Valid level -> 200
	r := httptest.NewRequest(http.MethodPut, "/api/v1/me/explanation-level", strings.NewReader(`{"level":"advanced"}`))
	w := httptest.NewRecorder()
	h.UpdateExplanationLevel(w, r.WithContext(ctx))
	if w.Code != http.StatusOK {
		t.Fatalf("valid level status %d: %s", w.Code, w.Body.String())
	}
	var res userDTO
	if err := json.Unmarshal(w.Body.Bytes(), &res); err != nil {
		t.Fatal(err)
	}
	if res.ExplanationLevel != "advanced" {
		t.Errorf("expected advanced, got %s", res.ExplanationLevel)
	}
}

func TestForgotPasswordAndResetPasswordHandlers(t *testing.T) {
	h, svc := newTestAuthHandlers(false)
	ctx := context.Background()

	// Register user
	_, err := svc.Register(ctx, "forgot@x.io", "initialpass123", "ForgotUser")
	if err != nil {
		t.Fatal(err)
	}

	// 1. ForgotPassword - invalid JSON
	wBadJSON := httptest.NewRecorder()
	h.ForgotPassword(wBadJSON, httptest.NewRequest(http.MethodPost, "/api/v1/auth/forgot-password", strings.NewReader(`invalid-json`)))
	if wBadJSON.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 for bad JSON, got %d", wBadJSON.Code)
	}

	// 2. ForgotPassword - success
	wForgot := httptest.NewRecorder()
	h.ForgotPassword(wForgot, httptest.NewRequest(http.MethodPost, "/api/v1/auth/forgot-password", strings.NewReader(`{"email":"forgot@x.io"}`)))
	if wForgot.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d: %s", wForgot.Code, wForgot.Body.String())
	}
	var forgotRes messageResponseDTO
	if err := json.Unmarshal(wForgot.Body.Bytes(), &forgotRes); err != nil {
		t.Fatal(err)
	}
	if forgotRes.Token == "" {
		t.Fatal("expected non-empty reset token")
	}

	// 3. ResetPassword - invalid token
	wInvalidToken := httptest.NewRecorder()
	h.ResetPassword(wInvalidToken, httptest.NewRequest(http.MethodPost, "/api/v1/auth/reset-password", strings.NewReader(`{"token":"bad-token","new_password":"newpassword123"}`)))
	if wInvalidToken.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 for bad token, got %d", wInvalidToken.Code)
	}

	// 4. ResetPassword - short password
	wShort := httptest.NewRecorder()
	h.ResetPassword(wShort, httptest.NewRequest(http.MethodPost, "/api/v1/auth/reset-password", strings.NewReader(`{"token":"`+forgotRes.Token+`","new_password":"short"}`)))
	if wShort.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 for short password, got %d", wShort.Code)
	}

	// 5. ResetPassword - success
	wSuccess := httptest.NewRecorder()
	h.ResetPassword(wSuccess, httptest.NewRequest(http.MethodPost, "/api/v1/auth/reset-password", strings.NewReader(`{"token":"`+forgotRes.Token+`","new_password":"updatedpass123"}`)))
	if wSuccess.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d: %s", wSuccess.Code, wSuccess.Body.String())
	}

	// 6. Login with new password
	wLogin := httptest.NewRecorder()
	h.Login(wLogin, httptest.NewRequest(http.MethodPost, "/api/v1/auth/login", strings.NewReader(`{"email":"forgot@x.io","password":"updatedpass123"}`)))
	if wLogin.Code != http.StatusOK {
		t.Fatalf("expected 200 login with new password, got %d: %s", wLogin.Code, wLogin.Body.String())
	}
}
