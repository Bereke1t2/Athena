-- Phase 7: Collaborative Research Collections & Reading Groups
DO $$ BEGIN
    CREATE TYPE collection_role AS ENUM ('viewer', 'editor', 'admin');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

CREATE TABLE IF NOT EXISTS collection_collaborators (
    collection_id uuid NOT NULL REFERENCES collections(id) ON DELETE CASCADE,
    user_id       uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role          collection_role NOT NULL DEFAULT 'viewer',
    invited_by    uuid REFERENCES users(id) ON DELETE SET NULL,
    created_at    timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (collection_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_collection_collaborators_user ON collection_collaborators (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_collection_collaborators_collection ON collection_collaborators (collection_id);

COMMENT ON TABLE collection_collaborators IS 'Collaborative members with role-based access to research collections';
