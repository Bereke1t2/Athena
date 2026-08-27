// Package auth implements account registration and password login backed by
// opaque bearer sessions. Tokens are random 32-byte values; the service only
// ever persists their sha256 hash, so a database leak cannot be replayed.
package auth

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"errors"
	"fmt"
	"regexp"
	"strings"
	"time"

	"github.com/google/uuid"

	domainuser "athena/backend/internal/domain/user"
)

const (
	defaultSessionTTL = 30 * 24 * time.Hour
	minPasswordLength = 8
	maxPasswordLength = 200
)

// ErrInvalidInput marks validation failures (bad email, short password).
var ErrInvalidInput = errors.New("auth: invalid input")

var emailPattern = regexp.MustCompile(`^[^@\s]+@[^@\s]+\.[^@\s]+$`)

// PasswordHasher derives and verifies salted password hashes.
type PasswordHasher interface {
	Hash(password string) (string, error)
	Verify(hash, password string) bool
}

// Service wires the user and session stores with a hasher.
type Service struct {
	users      domainuser.Store
	sessions   domainuser.SessionStore
	hasher     PasswordHasher
	sessionTTL time.Duration
}

func NewService(users domainuser.Store, sessions domainuser.SessionStore, hasher PasswordHasher) *Service {
	return &Service{
		users:      users,
		sessions:   sessions,
		hasher:     hasher,
		sessionTTL: defaultSessionTTL,
	}
}

// Register validates the request, creates the account, and issues a session.
func (s *Service) Register(ctx context.Context, email, password, displayName string) (domainuser.Session, error) {
	email = strings.ToLower(strings.TrimSpace(email))
	displayName = strings.TrimSpace(displayName)
	if !emailPattern.MatchString(email) || len(email) > 254 {
		return domainuser.Session{}, fmt.Errorf("%w: invalid email", ErrInvalidInput)
	}
	if len(password) < minPasswordLength || len(password) > maxPasswordLength {
		return domainuser.Session{}, fmt.Errorf("%w: password must be %d-%d characters",
			ErrInvalidInput, minPasswordLength, maxPasswordLength)
	}
	hash, err := s.hasher.Hash(password)
	if err != nil {
		return domainuser.Session{}, fmt.Errorf("hash password: %w", err)
	}

	created, err := s.users.Create(ctx, domainuser.NewUser{
		User: domainuser.User{
			ID:          uuid.New(),
			Email:       email,
			DisplayName: displayName,
			CreatedAt:   time.Now().UTC(),
		},
		PasswordHash: hash,
	})
	if err != nil {
		return domainuser.Session{}, err // ErrEmailTaken passes through
	}
	return s.issueSession(ctx, created)
}

// Login checks credentials and issues a session. Unknown email and wrong
// password produce the same error to prevent account enumeration; a real
// KDF run still happens in the unknown-email case so response timing does
// not reveal which check failed.
func (s *Service) Login(ctx context.Context, email, password string) (domainuser.Session, error) {
	cred, err := s.users.ByEmail(ctx, strings.ToLower(strings.TrimSpace(email)))
	if errors.Is(err, domainuser.ErrNotFound) {
		_, _ = s.hasher.Hash(password)
		return domainuser.Session{}, domainuser.ErrInvalidCredentials
	}
	if err != nil {
		return domainuser.Session{}, err
	}
	if cred.PasswordHash == "" || !s.hasher.Verify(cred.PasswordHash, password) {
		return domainuser.Session{}, domainuser.ErrInvalidCredentials
	}
	return s.issueSession(ctx, cred.User)
}

// Logout revokes the presented session (idempotent).
func (s *Service) Logout(ctx context.Context, token string) error {
	return s.sessions.Revoke(ctx, tokenHash(token))
}

// UserFromToken resolves a bearer token to its account.
func (s *Service) UserFromToken(ctx context.Context, token string) (domainuser.User, error) {
	if token == "" {
		return domainuser.User{}, domainuser.ErrSessionUnknown
	}
	u, expiresAt, err := s.sessions.UserByTokenHash(ctx, tokenHash(token))
	if err != nil {
		return domainuser.User{}, err
	}
	if time.Now().UTC().After(expiresAt) {
		return domainuser.User{}, domainuser.ErrSessionExpired
	}
	return u, nil
}

// Token returns the bearer value for an existing session row (used by tests
// and future token rotation); not part of the HTTP surface.
func (s *Service) issueSession(ctx context.Context, u domainuser.User) (domainuser.Session, error) {
	raw := make([]byte, 32)
	if _, err := rand.Read(raw); err != nil {
		return domainuser.Session{}, fmt.Errorf("session entropy: %w", err)
	}
	token := base64.RawURLEncoding.EncodeToString(raw)
	expiresAt := time.Now().UTC().Add(s.sessionTTL)
	if err := s.sessions.Issue(ctx, u.ID, tokenHash(token), expiresAt); err != nil {
		return domainuser.Session{}, err
	}
	return domainuser.Session{Token: token, ExpiresAt: expiresAt, User: u}, nil
}

func tokenHash(token string) []byte {
	sum := sha256.Sum256([]byte(token))
	return sum[:]
}
