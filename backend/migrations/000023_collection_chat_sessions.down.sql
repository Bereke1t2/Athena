-- Migration 000023 Down
ALTER TABLE chat_sessions DROP CONSTRAINT IF EXISTS chat_sessions_target_check;
ALTER TABLE chat_sessions DROP CONSTRAINT IF EXISTS chat_sessions_session_type_check;
DROP INDEX IF EXISTS chat_sessions_collection_idx;
ALTER TABLE chat_sessions DROP COLUMN IF EXISTS collection_id;
ALTER TABLE chat_sessions ADD CONSTRAINT chat_sessions_session_type_check CHECK (session_type IN ('single_paper', 'comparison'));
ALTER TABLE chat_sessions ADD CONSTRAINT chat_sessions_check CHECK (
    (session_type = 'single_paper' AND paper_id IS NOT NULL) OR
    (session_type = 'comparison' AND array_length(compare_paper_ids, 1) >= 2)
);
