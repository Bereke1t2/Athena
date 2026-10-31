-- Revert crossref seeding.
BEGIN;

DELETE FROM sources WHERE slug = 'crossref';

COMMIT;
