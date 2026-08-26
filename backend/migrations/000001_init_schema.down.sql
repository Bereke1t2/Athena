-- Athena — rollback of 000001_init_schema
BEGIN;

DROP TABLE IF EXISTS ingestion_runs;
DROP TABLE IF EXISTS paper_chunks;
DROP TABLE IF EXISTS chat_messages;
DROP TABLE IF EXISTS chat_sessions;
DROP TABLE IF EXISTS ai_summaries;
DROP INDEX IF EXISTS notifications_unread_idx;
DROP TABLE IF EXISTS notifications;
DROP TYPE IF EXISTS notification_type;
DROP TABLE IF EXISTS user_authors;
DROP TABLE IF EXISTS user_topics;
DROP TABLE IF EXISTS bookmarks;
DROP TABLE IF EXISTS citations;
DROP TABLE IF EXISTS paper_topics;
DROP TABLE IF EXISTS topics;
DROP TABLE IF EXISTS paper_authors;
DROP TABLE IF EXISTS author_identifiers;
DROP TABLE IF EXISTS authors;
DROP TABLE IF EXISTS paper_identifiers;
ALTER TABLE papers DROP CONSTRAINT IF EXISTS papers_primary_version_fk;
DROP TABLE IF EXISTS paper_versions;
DROP INDEX IF EXISTS papers_title_trgm_idx;
DROP INDEX IF EXISTS papers_search_vector_idx;
DROP INDEX IF EXISTS papers_cited_by_count_idx;
DROP INDEX IF EXISTS papers_publication_date_idx;
DROP INDEX IF EXISTS papers_updated_at_idx;
DROP TABLE IF EXISTS papers;
DROP TABLE IF EXISTS sources;
DROP TABLE IF EXISTS users;
DROP TYPE IF EXISTS publication_type;
DROP TYPE IF EXISTS oa_status;
DROP TYPE IF EXISTS explanation_level;

-- Extensions are shared infra; drop only if this migration introduced them.
-- Kept idempotent-safe: leave citext/pg_trgm installed.

COMMIT;
