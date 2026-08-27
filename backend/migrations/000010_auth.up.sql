-- Phase 5 auth: password credentials + opaque session tokens.
ALTER TABLE users ADD COLUMN password_hash text;

CREATE TABLE sessions (
    id           uuid PRIMARY KEY,
    user_id      uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash   bytea UNIQUE NOT NULL,          -- sha256 of the opaque bearer token
    expires_at   timestamptz NOT NULL,
    created_at   timestamptz NOT NULL DEFAULT now(),
    last_used_at timestamptz
);
CREATE INDEX sessions_user_idx ON sessions (user_id, created_at DESC);
COMMENT ON TABLE sessions IS 'Opaque bearer sessions; only sha256 token hashes are stored.';
