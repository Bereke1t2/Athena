-- Revert Migration 000014: Drop stance column and index from citations.

BEGIN;

DROP INDEX IF EXISTS citations_stance_idx;
ALTER TABLE citations DROP COLUMN IF EXISTS stance;

COMMIT;
