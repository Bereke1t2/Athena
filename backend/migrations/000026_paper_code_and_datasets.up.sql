-- Migration 000026: Paper Code Repositories & Open Datasets
-- Adds has_code and primary_code_url to papers, and introduces paper_code_repositories and paper_datasets.

BEGIN;

ALTER TABLE papers
    ADD COLUMN IF NOT EXISTS has_code boolean NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS primary_code_url text NOT NULL DEFAULT '';

CREATE INDEX IF NOT EXISTS papers_has_code_idx ON papers (has_code) WHERE has_code = true;

CREATE TABLE IF NOT EXISTS paper_code_repositories (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    paper_id uuid NOT NULL REFERENCES papers(id) ON DELETE CASCADE,
    url text NOT NULL,
    platform text NOT NULL, -- 'github', 'gitlab', 'huggingface', 'paperswithcode', 'other'
    owner text NOT NULL DEFAULT '',
    repo_name text NOT NULL DEFAULT '',
    description text NOT NULL DEFAULT '',
    is_official boolean NOT NULL DEFAULT true,
    stars_count integer NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT paper_code_repositories_paper_url_uniq UNIQUE (paper_id, url)
);

CREATE INDEX IF NOT EXISTS paper_code_repositories_paper_id_idx ON paper_code_repositories (paper_id);
CREATE INDEX IF NOT EXISTS paper_code_repositories_platform_idx ON paper_code_repositories (platform);

CREATE TABLE IF NOT EXISTS paper_datasets (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    paper_id uuid NOT NULL REFERENCES papers(id) ON DELETE CASCADE,
    url text NOT NULL,
    platform text NOT NULL, -- 'huggingface', 'zenodo', 'kaggle', 'paperswithcode', 'github', 'other'
    name text NOT NULL DEFAULT '',
    description text NOT NULL DEFAULT '',
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT paper_datasets_paper_url_uniq UNIQUE (paper_id, url)
);

CREATE INDEX IF NOT EXISTS paper_datasets_paper_id_idx ON paper_datasets (paper_id);

COMMIT;
