-- Adds the per-source provenance anchor missing from the Phase 0 baseline:
-- one row per (paper, provider) recording the provider-native id and payload
-- fingerprint used for incremental sync and idempotent re-ingestion.
BEGIN;

CREATE TABLE paper_sources (
    id                  uuid PRIMARY KEY,
    paper_id            uuid NOT NULL REFERENCES papers(id) ON DELETE CASCADE,
    source_id           uuid NOT NULL REFERENCES sources(id),
    native_id           text NOT NULL,
    content_fingerprint text NOT NULL,
    first_seen_at       timestamptz NOT NULL DEFAULT now(),
    last_seen_at        timestamptz NOT NULL DEFAULT now(),
    UNIQUE (source_id, native_id)
);

CREATE INDEX paper_sources_paper_idx ON paper_sources (paper_id);

COMMIT;
