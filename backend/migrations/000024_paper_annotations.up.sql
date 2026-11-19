CREATE TABLE IF NOT EXISTS paper_annotations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    paper_id UUID NOT NULL REFERENCES papers(id) ON DELETE CASCADE,
    page_number INT NOT NULL DEFAULT 1,
    section_index INT NOT NULL DEFAULT 0,
    selected_text TEXT NOT NULL,
    note TEXT NOT NULL DEFAULT '',
    color VARCHAR(32) NOT NULL DEFAULT 'yellow',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT valid_annotation_color CHECK (color IN ('yellow', 'coral', 'emerald', 'cyan', 'purple'))
);

CREATE INDEX IF NOT EXISTS idx_paper_annotations_user_paper
    ON paper_annotations (user_id, paper_id);

CREATE INDEX IF NOT EXISTS idx_paper_annotations_paper
    ON paper_annotations (paper_id);
