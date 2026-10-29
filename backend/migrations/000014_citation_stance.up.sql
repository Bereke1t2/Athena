-- Migration 000014: Add stance column to citations table for Phase 6 Research Intelligence.
-- Stance classifies citation edge as supports, contradicts, or mentions.

BEGIN;

ALTER TABLE citations
    ADD COLUMN IF NOT EXISTS stance text CHECK (stance IN ('supports', 'contradicts', 'mentions')) DEFAULT 'mentions';

CREATE INDEX IF NOT EXISTS citations_stance_idx ON citations (stance);

COMMIT;
