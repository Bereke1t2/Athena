DROP INDEX IF EXISTS chunk_embeddings_model_idx;
DROP INDEX IF EXISTS chunk_embeddings_hnsw_idx;
DROP TABLE IF EXISTS chunk_embeddings;
DROP EXTENSION IF EXISTS vector;
