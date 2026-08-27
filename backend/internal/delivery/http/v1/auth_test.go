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

type fakeAuthUsers struct {
	mu    sync.Mutex
	mail  map[string]domainuser.Credential
	taken bool
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
