-- Migration 000025 down: Remove authority_score and is_seminal columns.

BEGIN;

DROP INDEX IF EXISTS papers_is_seminal_idx;
DROP INDEX IF EXISTS papers_authority_score_idx;

ALTER TABLE papers
    DROP COLUMN IF EXISTS is_seminal,
    DROP COLUMN IF EXISTS authority_score;

COMMIT;
