-- Phase 2 search tuning: expression index matches the keyset/sort shape used
-- by /research and /feed latest (COALESCE keeps NULL-dated papers last), and
-- the composite citation index lets citations-sort queries stop early.
CREATE INDEX IF NOT EXISTS papers_pub_date_sort_idx
    ON papers (COALESCE(publication_date, 'infinity'::date) DESC, id DESC);

CREATE INDEX IF NOT EXISTS papers_cited_by_sort_idx
    ON papers (cited_by_count DESC, id DESC);
