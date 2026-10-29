CREATE TABLE password_resets (
    id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id      uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash   bytea UNIQUE NOT NULL,
    expires_at   timestamptz NOT NULL,
    used_at      timestamptz,
    created_at   timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX password_resets_user_idx ON password_resets (user_id);
CREATE INDEX password_resets_token_idx ON password_resets (token_hash) WHERE used_at IS NULL;
COMMENT ON TABLE password_resets IS 'Single-use password recovery tokens with sha256 hashing and expiry.';
