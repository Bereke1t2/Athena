DROP INDEX IF EXISTS chunk_embeddings_hnsw_idx;

DELETE FROM chunk_embeddings WHERE dim != 1536;

ALTER TABLE chunk_embeddings
    ALTER COLUMN dim SET DEFAULT 1536,
    ALTER COLUMN embedding TYPE vector(1536);

CREATE INDEX chunk_embeddings_hnsw_idx
    ON chunk_embeddings USING hnsw (embedding vector_cosine_ops);
