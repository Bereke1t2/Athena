-- Phase 6: Research Collections & Reading Lists
CREATE TABLE collections (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name        varchar(120) NOT NULL,
    description text NOT NULL DEFAULT '',
    color       varchar(32) NOT NULL DEFAULT '#6366F1',
    is_public   boolean NOT NULL DEFAULT false,
    created_at  timestamptz NOT NULL DEFAULT now(),
    updated_at  timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_user_collection_name UNIQUE (user_id, name)
);

CREATE INDEX idx_collections_user_created ON collections (user_id, created_at DESC);

CREATE TABLE collection_papers (
    collection_id uuid NOT NULL REFERENCES collections(id) ON DELETE CASCADE,
    paper_id      uuid NOT NULL REFERENCES papers(id) ON DELETE CASCADE,
    note          text NOT NULL DEFAULT '',
    position      int NOT NULL DEFAULT 0,
    added_at      timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (collection_id, paper_id)
);

CREATE INDEX idx_collection_papers_order ON collection_papers (collection_id, position ASC, added_at DESC);
CREATE INDEX idx_collection_papers_paper ON collection_papers (paper_id);

COMMENT ON TABLE collections IS 'User-curated research paper collections and reading lists';
COMMENT ON TABLE collection_papers IS 'Junction table linking papers to user collections with notes and ordering';
