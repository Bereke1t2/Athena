// Package user
//
// Domain: user accounts, password credentials, and session ports.
package user

import (
	"context"
	"errors"
	"time"

	"github.com/google/uuid"
)

// Sentinel errors mapped to HTTP statuses by the delivery layer.
var (
	// ErrNotFound means no user exists for the requested identifier.
	ErrNotFound = errors.New("user: not found")
	// ErrEmailTaken rejects registration with an already-registered email.
	ErrEmailTaken = errors.New("user: email already registered")
	// ErrInvalidCredentials covers both unknown email and wrong password so
	// the response cannot be used to enumerate accounts.
	ErrInvalidCredentials = errors.New("user: invalid credentials")
	// ErrSessionExpired / ErrSessionUnknown both mean "present no user".
	ErrSessionExpired = errors.New("user: session expired")
	ErrSessionUnknown = errors.New("user: session unknown")
)

// User is the public projection of an account — never carries credentials.
type User struct {
	ID          uuid.UUID `json:"id"`
	Email       string    `json:"email"`
	DisplayName string    `json:"display_name"`
	AvatarURL   string    `json:"avatar_url,omitempty"`
	CreatedAt   time.Time `json:"created_at"`
}

// NewUser is a registration request after application-level validation; the
// store persists PasswordHash alongside the public fields in one insert.
type NewUser struct {
	User         User
	PasswordHash string
}

// Store persists and retrieves accounts by email/ID.
type Store interface {
	Create(ctx context.Context, nu NewUser) (User, error)
	ByEmail(ctx context.Context, email string) (Credential, error)
	ByID(ctx context.Context, id uuid.UUID) (User, error)
}

// Credential pairs an account with its stored password hash for login checks.
type Credential struct {
	User         User
	PasswordHash string // empty for OAuth-only accounts (no password login)
}

// Session is an issued bearer token. Token appears exactly once, at issuance;
// only its sha256 hash is persisted.
type Session struct {
	Token     string
	ExpiresAt time.Time
	User      User
}

// SessionStore manages opaque bearer sessions.
type SessionStore interface {
	Issue(ctx context.Context, userID uuid.UUID, tokenHash []byte, expiresAt time.Time) error
	Revoke(ctx context.Context, tokenHash []byte) error
	UserByTokenHash(ctx context.Context, tokenHash []byte) (User, time.Time, error)
}
