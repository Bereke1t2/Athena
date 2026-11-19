-- Migration 000025: Seminal Paper Authority & Graph Scoring.
-- Adds authority_score and is_seminal columns to papers table for citation network analytics.

BEGIN;

ALTER TABLE papers
    ADD COLUMN IF NOT EXISTS authority_score double precision NOT NULL DEFAULT 0.0,
    ADD COLUMN IF NOT EXISTS is_seminal boolean NOT NULL DEFAULT false;

CREATE INDEX IF NOT EXISTS papers_authority_score_idx ON papers (authority_score DESC);
CREATE INDEX IF NOT EXISTS papers_is_seminal_idx ON papers (is_seminal) WHERE is_seminal = true;

COMMIT;
