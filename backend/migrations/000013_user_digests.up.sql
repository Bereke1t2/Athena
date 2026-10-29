-- Phase 6: User personalized research digests persistence.
CREATE TABLE user_digests (
    id            uuid PRIMARY KEY,
    user_id       uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    frequency     text NOT NULL DEFAULT 'weekly',
    pulses        jsonb NOT NULL DEFAULT '[]'::jsonb,
    sections      jsonb NOT NULL DEFAULT '[]'::jsonb,
    top_takeaways jsonb NOT NULL DEFAULT '[]'::jsonb,
    generated_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX user_digests_user_idx ON user_digests (user_id, generated_at DESC);
COMMENT ON TABLE user_digests IS 'Personalized research briefings generated for users on daily/weekly schedules.';
