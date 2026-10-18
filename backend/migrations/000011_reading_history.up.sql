-- Phase 5 reading history & progress tracking
CREATE TABLE reading_progress (
    user_id          uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    paper_id         uuid NOT NULL REFERENCES papers(id) ON DELETE CASCADE,
    progress_percent double precision NOT NULL DEFAULT 0.0 CHECK (progress_percent >= 0.0 AND progress_percent <= 100.0),
    completed        boolean NOT NULL DEFAULT false,
    last_read_at     timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, paper_id)
);

CREATE INDEX reading_progress_user_idx ON reading_progress (user_id, last_read_at DESC);
COMMENT ON TABLE reading_progress IS 'Tracks user reading position and completion status per research paper.';
