package auth

import (
	"context"
	"errors"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"

	domainuser "athena/backend/internal/domain/user"
)

// fastHasher is a deterministic, dependency-free hasher for tests: the
// "hash" is just a prefixed copy of the password.
type fastHasher struct{}

func (fastHasher) Hash(p string) (string, error) { return "fast$" + p, nil }
func (fastHasher) Verify(hash, p string) bool    { return hash == "fast$"+p }

type resetRow struct {
	userID    uuid.UUID
	expiresAt time.Time
	used      bool
}

type memUsers struct {
	mu     sync.Mutex
	byID   map[uuid.UUID]domainuser.NewUser
	byMail map[string]uuid.UUID
	resets map[string]resetRow
}

func newMemUsers() *memUsers {
	return &memUsers{
		byID:   map[uuid.UUID]domainuser.NewUser{},
		byMail: map[string]uuid.UUID{},
		resets: map[string]resetRow{},
	}
}

func (m *memUsers) Create(_ context.Context, nu domainuser.NewUser) (domainuser.User, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	if _, taken := m.byMail[strings.ToLower(nu.User.Email)]; taken {
		return domainuser.User{}, domainuser.ErrEmailTaken
	}
	m.byID[nu.User.ID] = nu
	m.byMail[strings.ToLower(nu.User.Email)] = nu.User.ID
	return nu.User, nil
}

func (m *memUsers) ByEmail(_ context.Context, email string) (domainuser.Credential, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	id, ok := m.byMail[strings.ToLower(email)]
	if !ok {
		return domainuser.Credential{}, domainuser.ErrNotFound
	}
	nu := m.byID[id]
	return domainuser.Credential{User: nu.User, PasswordHash: nu.PasswordHash}, nil
}

func (m *memUsers) ByID(_ context.Context, id uuid.UUID) (domainuser.User, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	nu, ok := m.byID[id]
	if !ok {
		return domainuser.User{}, domainuser.ErrNotFound
	}
	return nu.User, nil
}

func (m *memUsers) Delete(_ context.Context, id uuid.UUID) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	nu, ok := m.byID[id]
	if !ok {
		return domainuser.ErrNotFound
	}
	delete(m.byID, id)
	delete(m.byMail, strings.ToLower(nu.User.Email))
	return nil
}

func (m *memUsers) UpdateExplanationLevel(_ context.Context, id uuid.UUID, level string) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	nu, ok := m.byID[id]
	if !ok {
		return domainuser.ErrNotFound
	}
	nu.User.ExplanationLevel = level
	m.byID[id] = nu
	return nil
}

func (m *memUsers) UpdatePassword(_ context.Context, id uuid.UUID, passwordHash string) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	nu, ok := m.byID[id]
	if !ok {
		return domainuser.ErrNotFound
	}
	nu.PasswordHash = passwordHash
	m.byID[id] = nu
	return nil
}

func (m *memUsers) CreatePasswordReset(_ context.Context, userID uuid.UUID, tokenHash []byte, expiresAt time.Time) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.resets[string(tokenHash)] = resetRow{
		userID:    userID,
		expiresAt: expiresAt,
		used:      false,
	}
	return nil
}

func (m *memUsers) ConsumePasswordReset(_ context.Context, tokenHash []byte) (uuid.UUID, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	row, ok := m.resets[string(tokenHash)]
	if !ok || row.used || time.Now().UTC().After(row.expiresAt) {
		return uuid.Nil, domainuser.ErrInvalidResetToken
	}
	row.used = true
	m.resets[string(tokenHash)] = row
	return row.userID, nil
}

type memSessions struct {
	mu      sync.Mutex
	rows    map[string]sessionRow // token hash -> row
	revoked []string
}

type sessionRow struct {
	userID    uuid.UUID
	expiresAt time.Time
}

func newMemSessions() *memSessions { return &memSessions{rows: map[string]sessionRow{}} }

func (s *memSessions) Issue(_ context.Context, userID uuid.UUID, tokenHash []byte, expiresAt time.Time) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.rows[string(tokenHash)] = sessionRow{userID: userID, expiresAt: expiresAt}
	return nil
}

func (s *memSessions) Revoke(_ context.Context, tokenHash []byte) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	delete(s.rows, string(tokenHash))
	s.revoked = append(s.revoked, string(tokenHash))
	return nil
}

func (s *memSessions) UserByTokenHash(_ context.Context, tokenHash []byte) (domainuser.User, time.Time, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	row, ok := s.rows[string(tokenHash)]
	if !ok {
		return domainuser.User{}, time.Time{}, domainuser.ErrSessionUnknown
	}
	if time.Now().UTC().After(row.expiresAt) {
		return domainuser.User{}, time.Time{}, domainuser.ErrSessionExpired
	}
	return domainuser.User{ID: row.userID}, row.expiresAt, nil
}

func newTestService() (*Service, *memUsers, *memSessions) {
	users, sessions := newMemUsers(), newMemSessions()
	return NewService(users, sessions, fastHasher{}), users, sessions
}

func TestRegisterIssuesUsableSession(t *testing.T) {
	svc, users, _ := newTestService()
	sess, err := svc.Register(context.Background(), "Ada@Example.COM ", "hunter2secret", "Ada")
	if err != nil {
		t.Fatalf("register: %v", err)
	}
	if sess.Token == "" || sess.ExpiresAt.Before(time.Now().UTC()) {
		t.Fatalf("bad session %+v", sess)
	}
	if sess.User.Email != "ada@example.com" {
		t.Fatalf("session user email not lowercased/trimmed: %q", sess.User.Email)
	}
	u, err := svc.UserFromToken(context.Background(), sess.Token)
	if err != nil {
		t.Fatalf("token after register: %v", err)
	}
	if u.ID != sess.User.ID {
		t.Fatalf("token resolved to wrong account %s", u.ID)
	}
	if _, err := users.ByID(context.Background(), sess.User.ID); err != nil {
		t.Fatalf("account not persisted: %v", err)
	}
}

func TestRegisterValidation(t *testing.T) {
	cases := []struct {
		email, password string
	}{
		{"not-an-email", "longenough1"},
		{"a@b.c", "short"},
		{"", "longenough1"},
	}
	for _, c := range cases {
		svc, _, _ := newTestService()
		if _, err := svc.Register(context.Background(), c.email, c.password, ""); !errors.Is(err, ErrInvalidInput) {
			t.Errorf("Register(%q,%q): want ErrInvalidInput, got %v", c.email, c.password, err)
		}
	}
}

func TestRegisterDuplicateEmail(t *testing.T) {
	svc, _, _ := newTestService()
	ctx := context.Background()
	if _, err := svc.Register(ctx, "dupe@x.io", "password123", ""); err != nil {
		t.Fatal(err)
	}
	if _, err := svc.Register(ctx, "DUPE@x.io", "password123", ""); !errors.Is(err, domainuser.ErrEmailTaken) {
		t.Fatalf("want ErrEmailTaken, got %v", err)
	}
}

func TestLoginSuccessAndFailures(t *testing.T) {
	svc, _, _ := newTestService()
	ctx := context.Background()
	if _, err := svc.Register(ctx, "grace@x.io", "password123", "Grace"); err != nil {
		t.Fatal(err)
	}

	if _, err := svc.Login(ctx, "grace@x.io", "wrong-password"); !errors.Is(err, domainuser.ErrInvalidCredentials) {
		t.Errorf("wrong password: want ErrInvalidCredentials, got %v", err)
	}
	if _, err := svc.Login(ctx, "nobody@x.io", "password123"); !errors.Is(err, domainuser.ErrInvalidCredentials) {
		t.Errorf("unknown email: want ErrInvalidCredentials, got %v", err)
	}
	sess, err := svc.Login(ctx, "GRACE@x.io ", "password123")
	if err != nil {
		t.Fatalf("login: %v", err)
	}
	if _, err := svc.UserFromToken(ctx, sess.Token); err != nil {
		t.Fatalf("token after login: %v", err)
	}
}

func TestLogoutRevokesToken(t *testing.T) {
	svc, _, _ := newTestService()
	ctx := context.Background()
	sess, err := svc.Register(ctx, "out@x.io", "password123", "")
	if err != nil {
		t.Fatal(err)
	}
	if err := svc.Logout(ctx, sess.Token); err != nil {
		t.Fatalf("logout: %v", err)
	}
	if _, err := svc.UserFromToken(ctx, sess.Token); !errors.Is(err, domainuser.ErrSessionUnknown) {
		t.Fatalf("want ErrSessionUnknown after logout, got %v", err)
	}
	// Logout is idempotent.
	if err := svc.Logout(ctx, sess.Token); err != nil {
		t.Fatalf("second logout: %v", err)
	}
}

func TestEmptyTokenRejected(t *testing.T) {
	svc, _, _ := newTestService()
	if _, err := svc.UserFromToken(context.Background(), ""); err == nil {
		t.Fatal("empty token must not resolve")
	}
}

func TestRefreshSession(t *testing.T) {
	svc, _, _ := newTestService()
	ctx := context.Background()
	sess, err := svc.Register(ctx, "refresh@x.io", "password123", "Refresher")
	if err != nil {
		t.Fatal(err)
	}

	newSess, err := svc.Refresh(ctx, sess.Token)
	if err != nil {
		t.Fatalf("refresh: %v", err)
	}
	if newSess.Token == sess.Token {
		t.Errorf("refreshed token should be new")
	}

	// Old token should be revoked
	if _, err := svc.UserFromToken(ctx, sess.Token); !errors.Is(err, domainuser.ErrSessionUnknown) {
		t.Errorf("old token should be unknown, got %v", err)
	}
	// New token works
	u, err := svc.UserFromToken(ctx, newSess.Token)
	if err != nil || u.ID != sess.User.ID {
		t.Fatalf("new token failed: %v", err)
	}
}

func TestDeleteAccount(t *testing.T) {
	svc, users, _ := newTestService()
	ctx := context.Background()
	sess, err := svc.Register(ctx, "delete@x.io", "password123", "Deleter")
	if err != nil {
		t.Fatal(err)
	}

	if err := svc.DeleteAccount(ctx, sess.User.ID); err != nil {
		t.Fatalf("delete account: %v", err)
	}

	if _, err := users.ByID(ctx, sess.User.ID); !errors.Is(err, domainuser.ErrNotFound) {
		t.Errorf("user should not be found after delete, got %v", err)
	}
}

func TestUpdateExplanationLevel(t *testing.T) {
	svc, users, _ := newTestService()
	ctx := context.Background()
	sess, err := svc.Register(ctx, "level@x.io", "password123", "LevelUser")
	if err != nil {
		t.Fatal(err)
	}

	if err := svc.UpdateExplanationLevel(ctx, sess.User.ID, "expert"); err != nil {
		t.Fatalf("update explanation level: %v", err)
	}

	u, err := users.ByID(ctx, sess.User.ID)
	if err != nil {
		t.Fatal(err)
	}
	if u.ExplanationLevel != "expert" {
		t.Errorf("expected expert, got %s", u.ExplanationLevel)
	}

	if err := svc.UpdateExplanationLevel(ctx, sess.User.ID, "invalid"); !errors.Is(err, ErrInvalidInput) {
		t.Errorf("expected ErrInvalidInput, got %v", err)
	}
}

func TestPasswordResetFlow(t *testing.T) {
	svc, _, _ := newTestService()
	ctx := context.Background()

	// 1. Unknown email returns empty token, no error
	token, err := svc.RequestPasswordReset(ctx, "nonexistent@x.io")
	if err != nil {
		t.Fatalf("request reset for unknown email error: %v", err)
	}
	if token != "" {
		t.Errorf("expected empty token for unknown email, got %q", token)
	}

	// 2. Register real user
	_, err = svc.Register(ctx, "reset@x.io", "oldpassword123", "ResetUser")
	if err != nil {
		t.Fatal(err)
	}

	// 3. Request reset for real user
	token, err = svc.RequestPasswordReset(ctx, "reset@x.io")
	if err != nil {
		t.Fatalf("request reset: %v", err)
	}
	if token == "" {
		t.Fatal("expected non-empty reset token")
	}

	// 4. Reset password with invalid token fails
	if err := svc.ResetPassword(ctx, "bogus-token", "newpassword123"); !errors.Is(err, domainuser.ErrInvalidResetToken) {
		t.Fatalf("expected ErrInvalidResetToken for bogus token, got %v", err)
	}

	// 5. Reset password with short password fails
	if err := svc.ResetPassword(ctx, token, "short"); !errors.Is(err, ErrInvalidInput) {
		t.Fatalf("expected ErrInvalidInput for short password, got %v", err)
	}

	// 6. Reset password succeeds
	if err := svc.ResetPassword(ctx, token, "newpassword123"); err != nil {
		t.Fatalf("reset password failed: %v", err)
	}

	// 7. Token cannot be reused
	if err := svc.ResetPassword(ctx, token, "anotherpassword123"); !errors.Is(err, domainuser.ErrInvalidResetToken) {
		t.Fatalf("expected ErrInvalidResetToken on reuse, got %v", err)
	}

	// 8. Old password no longer works
	if _, err := svc.Login(ctx, "reset@x.io", "oldpassword123"); !errors.Is(err, domainuser.ErrInvalidCredentials) {
		t.Fatalf("expected login failure with old password, got %v", err)
	}

	// 9. New password works
	if _, err := svc.Login(ctx, "reset@x.io", "newpassword123"); err != nil {
		t.Fatalf("login with new password failed: %v", err)
	}
}
