-- Migration 000017: Bidirectional paper references store for citation graph resolution.
CREATE TABLE IF NOT EXISTS paper_references (
    citing_paper_id UUID NOT NULL REFERENCES papers(id) ON DELETE CASCADE,
    id_type         TEXT NOT NULL,
    id_value        TEXT NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (citing_paper_id, id_type, id_value)
);

CREATE INDEX IF NOT EXISTS paper_references_lookup_idx ON paper_references (id_type, id_value);
