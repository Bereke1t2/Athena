-- Phase 4 & Gemini Alignment: Migrate chunk_embeddings to 768 dimensions (text-embedding-004 / Gemini).
-- Purge any rows with dim != 768 before altering column type to avoid dimension mismatch errors.
DROP INDEX IF EXISTS chunk_embeddings_hnsw_idx;

DELETE FROM chunk_embeddings WHERE dim != 768;

ALTER TABLE chunk_embeddings
    ALTER COLUMN dim SET DEFAULT 768,
    ALTER COLUMN embedding TYPE vector(768);

CREATE INDEX chunk_embeddings_hnsw_idx
    ON chunk_embeddings USING hnsw (embedding vector_cosine_ops);
