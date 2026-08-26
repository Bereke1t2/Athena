-- Rollback of 000004_river_schema.up.sql (River sections 004,003,002,001 down).
-- Sections 005-007 roll back in 000005_river_schema_extra.down.sql (applied later, rolled back first).

-- ==== 004_pending_and_more.down.sql ====
ALTER TABLE /* TEMPLATE: schema */river_job ALTER COLUMN args DROP NOT NULL;

ALTER TABLE /* TEMPLATE: schema */river_job ALTER COLUMN metadata DROP NOT NULL;
ALTER TABLE /* TEMPLATE: schema */river_job ALTER COLUMN metadata DROP DEFAULT;

-- It is not possible to safely remove 'pending' from the river_job_state enum,
-- so leave it in place.

ALTER TABLE /* TEMPLATE: schema */river_job DROP CONSTRAINT finalized_or_finalized_at_null;
ALTER TABLE /* TEMPLATE: schema */river_job ADD CONSTRAINT finalized_or_finalized_at_null CHECK (
  (state IN ('cancelled', 'completed', 'discarded') AND finalized_at IS NOT NULL) OR finalized_at IS NULL
);

CREATE OR REPLACE FUNCTION /* TEMPLATE: schema */river_job_notify()
  RETURNS TRIGGER
  AS $$
DECLARE
  payload json;
BEGIN
  IF NEW.state = 'available' THEN
    -- Notify will coalesce duplicate notifications within a transaction, so
    -- keep these payloads generalized:
    payload = json_build_object('queue', NEW.queue);
    PERFORM
      pg_notify('river_insert', payload::text);
  END IF;
  RETURN NULL;
END;
$$
LANGUAGE plpgsql;

CREATE TRIGGER river_notify
  AFTER INSERT ON /* TEMPLATE: schema */river_job
  FOR EACH ROW
  EXECUTE PROCEDURE /* TEMPLATE: schema */river_job_notify();

DROP TABLE /* TEMPLATE: schema */river_queue;

ALTER TABLE /* TEMPLATE: schema */river_leader
    ALTER COLUMN name DROP DEFAULT,
    DROP CONSTRAINT name_length,
    ADD CONSTRAINT name_length CHECK (char_length(name) > 0 AND char_length(name) < 128);
-- ==== 003_river_job_tags_non_null.down.sql ====
ALTER TABLE /* TEMPLATE: schema */river_job
    ALTER COLUMN tags DROP NOT NULL,
    ALTER COLUMN tags DROP DEFAULT;

-- ==== 002_initial_schema.down.sql ====
DROP TABLE /* TEMPLATE: schema */river_job;
DROP FUNCTION /* TEMPLATE: schema */river_job_notify;
DROP TYPE /* TEMPLATE: schema */river_job_state;

DROP TABLE /* TEMPLATE: schema */river_leader;
-- ==== 001_create_river_migration.down.sql ====
DROP TABLE /* TEMPLATE: schema */river_migration;