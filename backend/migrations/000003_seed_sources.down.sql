BEGIN;
DELETE FROM sources WHERE slug IN ('semanticscholar', 'openalex', 'arxiv');
COMMIT;
