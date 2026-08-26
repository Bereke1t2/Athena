-- =============================================================================
-- Athena — baseline schema (Phase 0 design; applied from Phase 1 onward)
-- PostgreSQL 16 · extensions: citext, pg_trgm
-- pgvector arrives in migration 000002 (Phase 4) by design.
-- =============================================================================

BEGIN;

CREATE EXTENSION IF NOT EXISTS citext;
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- ---------------------------------------------------------------- enums ------
CREATE TYPE explanation_level AS ENUM ('beginner', 'intermediate', 'advanced', 'expert');
CREATE TYPE oa_status         AS ENUM ('gold', 'green', 'hybrid', 'bronze', 'closed', 'unknown');
CREATE TYPE publication_type  AS ENUM ('article', 'review', 'preprint', 'conference_paper',
                                       'book_chapter', 'dataset', 'other');

-- ---------------------------------------------------------------- users ------
CREATE TABLE users (
    id                          uuid PRIMARY KEY,
    email                       citext UNIQUE,
    display_name                text        NOT NULL DEFAULT '',
    avatar_url                  text,
    preferred_explanation_level explanation_level NOT NULL DEFAULT 'intermediate',
    settings                    jsonb       NOT NULL DEFAULT '{}',
    created_at                  timestamptz NOT NULL DEFAULT now(),
    updated_at                  timestamptz NOT NULL DEFAULT now(),
    deleted_at                  timestamptz
);
COMMENT ON TABLE users IS 'Application accounts. Auth fields arrive with Phase 5 migration.';

-- -------------------------------------------------------------- sources ------
CREATE TABLE sources (
    id              uuid PRIMARY KEY,
    slug            text UNIQUE NOT NULL,             -- semanticscholar | openalex | arxiv | ...
    name            text NOT NULL,
    base_url        text,
    terms_of_use_url text,
    enabled         boolean     NOT NULL DEFAULT true,
    sync_cursor     jsonb       NOT NULL DEFAULT '{}', -- incremental watermark state
    last_synced_at  timestamptz,
    created_at      timestamptz NOT NULL DEFAULT now()
);

-- --------------------------------------------------------------- papers ------
CREATE TABLE papers (
    id               uuid PRIMARY KEY,
    title            text NOT NULL,
    title_normalized text NOT NULL,
    fingerprint      text NOT NULL,                    -- sha256(norm_title|lead_surname|year)
    abstract         text,
    publication_date date,
    publication_year smallint,
    venue_name       text,
    venue_type       text,
    publication_type publication_type NOT NULL DEFAULT 'article',
    language         text,                             -- ISO 639-1 when known
    doi              citext UNIQUE,                    -- normalized lowercase; nullable
    arxiv_id         text UNIQUE,                      -- canonical modern form; nullable
    oa_status        oa_status   NOT NULL DEFAULT 'unknown',
    is_open_access   boolean     NOT NULL DEFAULT false,
    best_oa_url      text,
    license          text,                             -- e.g. cc-by, arXiv license id
    cited_by_count   integer     NOT NULL DEFAULT 0,
    reference_count  integer     NOT NULL DEFAULT 0,
    tldr_short       text,                              -- denormalized cache of latest AI TL;DR
    search_vector    tsvector GENERATED ALWAYS AS (
                         setweight(to_tsvector('english', coalesce(title, '')), 'A') ||
                         setweight(to_tsvector('english', coalesce(abstract, '')), 'B')
                     ) STORED,
    primary_version_id uuid,                           -- FK added after paper_versions exists
    created_at       timestamptz NOT NULL DEFAULT now(),
    updated_at       timestamptz NOT NULL DEFAULT now(),
    deleted_at       timestamptz
);

CREATE INDEX papers_publication_date_idx   ON papers (publication_date DESC NULLS LAST)
    WHERE deleted_at IS NULL;
CREATE INDEX papers_cited_by_count_idx     ON papers (cited_by_count DESC) WHERE deleted_at IS NULL;
CREATE INDEX papers_search_vector_idx      ON papers USING gin (search_vector);
CREATE INDEX papers_title_trgm_idx         ON papers USING gin (title_normalized gin_trgm_ops);
CREATE INDEX papers_updated_at_idx         ON papers (updated_at DESC);

-- ------------------------------------------------------- paper_versions ------
CREATE TABLE paper_versions (
    id           uuid PRIMARY KEY,
    paper_id     uuid NOT NULL REFERENCES papers(id) ON DELETE CASCADE,
    version_kind text NOT NULL CHECK (version_kind IN ('preprint', 'publisher', 'other')),
    doi          citext,
    arxiv_id     text,
    url          text NOT NULL,
    published_on date,
    is_primary   boolean NOT NULL DEFAULT false,
    created_at   timestamptz NOT NULL DEFAULT now(),
    UNIQUE (paper_id, version_kind, url)
);
CREATE INDEX paper_versions_paper_idx ON paper_versions (paper_id);

ALTER TABLE papers
    ADD CONSTRAINT papers_primary_version_fk
    FOREIGN KEY (primary_version_id) REFERENCES paper_versions(id) ON DELETE SET NULL;

-- --------------------------------------------------- paper_identifiers -------
CREATE TABLE paper_identifiers (
    id_type  text   NOT NULL CHECK (id_type IN ('doi', 'arxiv', 'semantic_scholar',
                                               'openalex', 'pubmed', 'corpus_id', 'other')),
    id_value text   NOT NULL,
    paper_id uuid   NOT NULL REFERENCES papers(id) ON DELETE CASCADE,
    created_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (id_type, id_value)
);
CREATE INDEX paper_identifiers_paper_idx ON paper_identifiers (paper_id);
COMMENT ON TABLE paper_identifiers IS 'Dedup spine: one paper per known external identifier.';

-- --------------------------------------------------------------- authors -----
CREATE TABLE authors (
    id              uuid PRIMARY KEY,
    display_name    text NOT NULL,
    name_normalized text NOT NULL,
    orcid           text UNIQUE,
    h_index         integer,
    metadata        jsonb NOT NULL DEFAULT '{}',
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX authors_name_norm_idx ON authors (name_normalized);
CREATE INDEX authors_name_trgm_idx ON authors USING gin (name_normalized gin_trgm_ops);

CREATE TABLE author_identifiers (
    id_type  text NOT NULL CHECK (id_type IN ('orcid', 'semantic_scholar', 'openalex')),
    id_value text NOT NULL,
    author_id uuid NOT NULL REFERENCES authors(id) ON DELETE CASCADE,
    PRIMARY KEY (id_type, id_value)
);
CREATE INDEX author_identifiers_author_idx ON author_identifiers (author_id);

CREATE TABLE paper_authors (
    paper_id    uuid NOT NULL REFERENCES papers(id) ON DELETE CASCADE,
    author_id   uuid REFERENCES authors(id) ON DELETE CASCADE,  -- nullable until resolved
    raw_name    text,                                            -- unresolved author names
    position    integer NOT NULL,
    affiliation text[] NOT NULL DEFAULT '{}',
    PRIMARY KEY (paper_id, position),
    UNIQUE (paper_id, author_id)
);
CREATE INDEX paper_authors_author_idx ON paper_authors (author_id);

-- --------------------------------------------------------------- topics ------
CREATE TABLE topics (
    id          uuid PRIMARY KEY,
    parent_id   uuid REFERENCES topics(id) ON DELETE SET NULL,
    slug        text UNIQUE NOT NULL,
    name        text NOT NULL,
    description text,
    kind        text NOT NULL DEFAULT 'topic' CHECK (kind IN ('field', 'topic')),
    provider_key text,                                   -- e.g. OpenAlex topic id at seed time
    created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX topics_parent_idx ON topics (parent_id);

CREATE TABLE paper_topics (
    paper_id    uuid NOT NULL REFERENCES papers(id) ON DELETE CASCADE,
    topic_id    uuid NOT NULL REFERENCES topics(id) ON DELETE CASCADE,
    score       numeric(5,4) CHECK (score >= 0 AND score <= 1),
    is_primary  boolean NOT NULL DEFAULT false,
    assigned_by text NOT NULL DEFAULT 'provider' CHECK (assigned_by IN ('provider', 'curated', 'classifier')),
    PRIMARY KEY (paper_id, topic_id)
);
CREATE INDEX paper_topics_topic_idx ON paper_topics (topic_id);

-- ------------------------------------------------------------ citations ------
CREATE TABLE citations (
    citing_paper_id uuid NOT NULL REFERENCES papers(id) ON DELETE CASCADE,
    cited_paper_id  uuid NOT NULL REFERENCES papers(id) ON DELETE CASCADE,
    is_influential  boolean,
    context         text,
    first_seen_at   timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (citing_paper_id, cited_paper_id)
);
CREATE INDEX citations_cited_idx ON citations (cited_paper_id);

-- ------------------------------------------------------ personalization ------
CREATE TABLE bookmarks (
    id         uuid PRIMARY KEY,
    user_id    uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    paper_id   uuid NOT NULL REFERENCES papers(id) ON DELETE CASCADE,
    note       text,
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (user_id, paper_id)
);
CREATE INDEX bookmarks_user_created_idx ON bookmarks (user_id, created_at DESC);

CREATE TABLE user_topics (
    user_id    uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    topic_id   uuid NOT NULL REFERENCES topics(id) ON DELETE CASCADE,
    notify     boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, topic_id)
);

CREATE TABLE user_authors (
    user_id    uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    author_id  uuid NOT NULL REFERENCES authors(id) ON DELETE CASCADE,
    created_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, author_id)
);

-- -------------------------------------------------------- notifications ------
CREATE TYPE notification_type AS ENUM ('new_papers_topic', 'new_papers_author', 'digest', 'system');

CREATE TABLE notifications (
    id            uuid PRIMARY KEY,
    user_id       uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    type          notification_type NOT NULL,
    title         text NOT NULL,
    body          text,
    data          jsonb NOT NULL DEFAULT '{}',   -- e.g. {"topic_slug":"ai","paper_ids":[...]}
    read_at       timestamptz,
    delivered_via text[] NOT NULL DEFAULT '{}',
    created_at    timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX notifications_user_created_idx ON notifications (user_id, created_at DESC);
CREATE INDEX notifications_unread_idx ON notifications (user_id, created_at DESC)
    WHERE read_at IS NULL;

-- --------------------------------------------------------- ai artifacts ------
CREATE TABLE ai_summaries (
    id                      uuid PRIMARY KEY,
    paper_id                uuid NOT NULL REFERENCES papers(id) ON DELETE CASCADE,
    explanation_level       explanation_level NOT NULL,
    model_id                text NOT NULL,
    prompt_template_version text NOT NULL,
    input_content_hash      text NOT NULL,      -- invalidation key over source content
    tldr                    text,
    sections                jsonb NOT NULL DEFAULT '{}', -- simple/academic/key_findings/methodology/results/limitations/why_it_matters
    token_usage             jsonb NOT NULL DEFAULT '{}',
    created_at              timestamptz NOT NULL DEFAULT now(),
    UNIQUE (paper_id, explanation_level)
);
CREATE INDEX ai_summaries_content_hash_idx ON ai_summaries (input_content_hash);

CREATE TABLE chat_sessions (
    id               uuid PRIMARY KEY,
    user_id          uuid REFERENCES users(id) ON DELETE CASCADE,
    session_type     text NOT NULL DEFAULT 'single_paper'
                     CHECK (session_type IN ('single_paper', 'comparison')),
    paper_id         uuid REFERENCES papers(id) ON DELETE CASCADE,
    compare_paper_ids uuid[] NOT NULL DEFAULT '{}',   -- Phase 6 comparison sessions
    title            text,
    message_count    integer NOT NULL DEFAULT 0,
    last_message_at  timestamptz,
    created_at       timestamptz NOT NULL DEFAULT now(),
    CHECK ( (session_type = 'single_paper' AND paper_id IS NOT NULL)
         OR (session_type = 'comparison' AND array_length(compare_paper_ids, 1) >= 2) )
);
CREATE INDEX chat_sessions_user_idx    ON chat_sessions (user_id, last_message_at DESC);
CREATE INDEX chat_sessions_paper_idx   ON chat_sessions (paper_id);

CREATE TABLE chat_messages (
    id          uuid PRIMARY KEY,
    session_id  uuid NOT NULL REFERENCES chat_sessions(id) ON DELETE CASCADE,
    role        text NOT NULL CHECK (role IN ('user', 'assistant', 'system')),
    content     text NOT NULL,
    citations   jsonb NOT NULL DEFAULT '[]',  -- [{chunk_id, section_path, quote}]
    model_id    text,
    token_usage jsonb NOT NULL DEFAULT '{}',
    created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX chat_messages_session_idx ON chat_messages (session_id, created_at);

CREATE TABLE paper_chunks (
    id            uuid PRIMARY KEY,
    paper_id      uuid NOT NULL REFERENCES papers(id) ON DELETE CASCADE,
    seq           integer NOT NULL,                 -- ordinal within the paper
    section_path  text,                             -- "3. Methods > 3.2 Dataset"
    heading       text,
    content       text NOT NULL,
    token_count   integer NOT NULL,
    page_start    integer,
    page_end      integer,
    content_hash  text NOT NULL,
    created_at    timestamptz NOT NULL DEFAULT now(),
    UNIQUE (paper_id, content_hash),
    UNIQUE (paper_id, seq)
);
COMMENT ON TABLE paper_chunks IS 'RAG units. Embeddings land in chunk_embeddings (migration 000002).';

-- ---------------------------------------------------------- ingestion --------
CREATE TABLE ingestion_runs (
    id                  uuid PRIMARY KEY,
    source_id           uuid NOT NULL REFERENCES sources(id),
    run_kind            text NOT NULL DEFAULT 'window'
                        CHECK (run_kind IN ('window', 'backfill', 'manual')),
    window_from         timestamptz,
    window_to           timestamptz,
    status              text NOT NULL DEFAULT 'running'
                        CHECK (status IN ('running', 'succeeded', 'failed', 'dead')),
    items_seen          bigint NOT NULL DEFAULT 0,
    papers_created      bigint NOT NULL DEFAULT 0,
    papers_updated      bigint NOT NULL DEFAULT 0,
    duplicates_detected bigint NOT NULL DEFAULT 0,
    errors_count        bigint NOT NULL DEFAULT 0,
    last_error          text,
    cursor_after        jsonb,
    started_at          timestamptz NOT NULL DEFAULT now(),
    finished_at         timestamptz
);
CREATE INDEX ingestion_runs_source_started_idx ON ingestion_runs (source_id, started_at DESC);
COMMENT ON TABLE ingestion_runs IS 'Audit ledger for provider syncs. Operational queue = river_job (ADR-0006).';

COMMIT;
