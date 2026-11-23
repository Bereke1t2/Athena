BEGIN;

DROP TABLE IF EXISTS paper_datasets;
DROP TABLE IF EXISTS paper_code_repositories;

DROP INDEX IF EXISTS papers_has_code_idx;
ALTER TABLE papers
    DROP COLUMN IF EXISTS primary_code_url,
    DROP COLUMN IF EXISTS has_code;

COMMIT;
