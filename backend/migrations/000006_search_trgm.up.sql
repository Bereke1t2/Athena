-- Phase 2 search: trigram index for fuzzy title matching (search.md §1).
CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE INDEX IF NOT EXISTS papers_title_trgm_idx
    ON papers USING gin (title_normalized gin_trgm_ops);
