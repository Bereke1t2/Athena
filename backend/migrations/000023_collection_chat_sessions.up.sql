-- Migration 000023: Collection-grounded chat sessions
DO $$ BEGIN
    ALTER TABLE chat_sessions DROP CONSTRAINT IF EXISTS chat_sessions_session_type_check;
    ALTER TABLE chat_sessions DROP CONSTRAINT IF EXISTS chat_sessions_check;
    ALTER TABLE chat_sessions DROP CONSTRAINT IF EXISTS chat_sessions_check1;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

ALTER TABLE chat_sessions
    ADD COLUMN IF NOT EXISTS collection_id uuid REFERENCES collections(id) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS chat_sessions_collection_idx ON chat_sessions (collection_id);

ALTER TABLE chat_sessions
    ADD CONSTRAINT chat_sessions_session_type_check
    CHECK (session_type IN ('single_paper', 'comparison', 'collection'));

ALTER TABLE chat_sessions
    ADD CONSTRAINT chat_sessions_target_check
    CHECK (
        (session_type = 'single_paper' AND paper_id IS NOT NULL) OR
        (session_type = 'comparison' AND array_length(compare_paper_ids, 1) >= 2) OR
        (session_type = 'collection' AND collection_id IS NOT NULL)
    );
