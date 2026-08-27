-- Phase 4: RAG embedding storage (docs/architecture/ai-rag.md §5).
-- pgvector with HNSW cosine; model_id keyed so model swaps add rows instead
-- of migrating dimensions mid-flight. Dimension pinned to EMBEDDING_DIM's
-- documented default (1536); a different dim means a new migration.
CREATE EXTENSION IF NOT EXISTS vector;

CREATE TABLE chunk_embeddings (
    chunk_id   uuid NOT NULL REFERENCES paper_chunks(id) ON DELETE CASCADE,
    model_id   text NOT NULL,
    dim        integer NOT NULL DEFAULT 1536,
    embedding  vector(1536) NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (chunk_id, model_id)
);

CREATE INDEX chunk_embeddings_hnsw_idx
    ON chunk_embeddings USING hnsw (embedding vector_cosine_ops);
CREATE INDEX chunk_embeddings_model_idx ON chunk_embeddings (model_id);
