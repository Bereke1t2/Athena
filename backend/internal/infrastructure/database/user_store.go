package database

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	domainuser "athena/backend/internal/domain/user"
)

// UserStore implements domain/user ports on Postgres.
type UserStore struct {
	pool *pgxpool.Pool
}

func NewUserStore(pool *pgxpool.Pool) *UserStore { return &UserStore{pool: pool} }

const userCols = `id, email, display_name, COALESCE(avatar_url,''), created_at`

func scanUser(row pgx.Row) (domainuser.User, error) {
	var u domainuser.User
	var email string
	err := row.Scan(&u.ID, &email, &u.DisplayName, &u.AvatarURL, &u.CreatedAt)
	u.Email = email
	return u, err
}

// Create inserts a new account. The citext UNIQUE constraint on email maps
// to ErrEmailTaken.
func (s *UserStore) Create(ctx context.Context, nu domainuser.NewUser) (domainuser.User, error) {
	row := s.pool.QueryRow(ctx, `
		INSERT INTO users (id, email, display_name, password_hash, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, now())
		ON CONFLICT (email) DO NOTHING
		RETURNING `+userCols,
		nu.User.ID, nu.User.Email, nu.User.DisplayName, nu.PasswordHash, nu.User.CreatedAt)

	u, err := scanUser(row)
	if errors.Is(err, pgx.ErrNoRows) {
		return domainuser.User{}, domainuser.ErrEmailTaken
	}
	if err != nil {
		return domainuser.User{}, fmt.Errorf("create user: %w", err)
	}
	return u, nil
}

// ByEmail returns the account with its stored password hash for login.
func (s *UserStore) ByEmail(ctx context.Context, email string) (domainuser.Credential, error) {
	var c domainuser.Credential
	var emailOut string
	err := s.pool.QueryRow(ctx, `
		SELECT id, email::text, display_name, COALESCE(avatar_url,''), created_at,
		       COALESCE(password_hash,'')
		FROM users WHERE lower(email::text) = $1 AND deleted_at IS NULL`, email).
		Scan(&c.User.ID, &emailOut, &c.User.DisplayName, &c.User.AvatarURL,
			&c.User.CreatedAt, &c.PasswordHash)
	c.User.Email = emailOut
	if errors.Is(err, pgx.ErrNoRows) {
		return c, domainuser.ErrNotFound
	}
	if err != nil {
		return c, fmt.Errorf("user by email: %w", err)
	}
	return c, nil
}

// ByID returns one account by primary key.
func (s *UserStore) ByID(ctx context.Context, id uuid.UUID) (domainuser.User, error) {
	u, err := scanUser(s.pool.QueryRow(ctx,
		`SELECT id, email::text, display_name, COALESCE(avatar_url,''), created_at
		 FROM users WHERE id = $1 AND deleted_at IS NULL`, id))
	if errors.Is(err, pgx.ErrNoRows) {
		return u, domainuser.ErrNotFound
	}
	if err != nil {
		return u, fmt.Errorf("user by id: %w", err)
	}
	return u, nil
}

// Issue persists a new session row keyed by token hash.
func (s *UserStore) Issue(ctx context.Context, userID uuid.UUID, tokenHash []byte, expiresAt time.Time) error {
	_, err := s.pool.Exec(ctx, `
		INSERT INTO sessions (id, user_id, token_hash, expires_at)
		VALUES ($1, $2, $3, $4)`, uuid.New(), userID, tokenHash, expiresAt)
	if err != nil {
		return fmt.Errorf("issue session: %w", err)
	}
	return nil
}

// Revoke removes a session row; deleting an absent hash is not an error.
func (s *UserStore) Revoke(ctx context.Context, tokenHash []byte) error {
	_, err := s.pool.Exec(ctx, `DELETE FROM sessions WHERE token_hash = $1`, tokenHash)
	if err != nil {
		return fmt.Errorf("revoke session: %w", err)
	}
	return nil
}

// UserByTokenHash resolves a session to its account and expiry. Expired rows
// are treated as unknown and pruned opportunistically.
func (s *UserStore) UserByTokenHash(ctx context.Context, tokenHash []byte) (domainuser.User, time.Time, error) {
	var u domainuser.User
	var expiresAt time.Time
	err := s.pool.QueryRow(ctx, `
		SELECT us.id, us.email::text, us.display_name, COALESCE(us.avatar_url,''),
		       us.created_at, sn.expires_at
		FROM sessions sn JOIN users us ON us.id = sn.user_id AND us.deleted_at IS NULL
		WHERE sn.token_hash = $1 AND sn.expires_at > now()`, tokenHash).
		Scan(&u.ID, &u.Email, &u.DisplayName, &u.AvatarURL, &u.CreatedAt, &expiresAt)
	switch {
	case errors.Is(err, pgx.ErrNoRows):
		// Distinguish expired from unknown so callers can log out stale clients.
		var count int
		qerr := s.pool.QueryRow(ctx,
			`SELECT 1 FROM sessions sn JOIN users us ON us.id = sn.user_id
			 WHERE sn.token_hash = $1 AND sn.expires_at <= now()`, tokenHash).Scan(&count)
		if qerr == nil {
			return u, time.Time{}, domainuser.ErrSessionExpired
		}
		return u, time.Time{}, domainuser.ErrSessionUnknown
	case err != nil:
		return u, time.Time{}, fmt.Errorf("session lookup: %w", err)
	}
	return u, expiresAt, nil
}
