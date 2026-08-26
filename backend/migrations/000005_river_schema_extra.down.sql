-- River job queue schema downgrade for part 2 of 2 (sections 007,006,005 down).
-- Applied after 000004; must roll back before it.

-- ==== 007_notification_outbox_sqlite_jsonb_and_sql_cleanup.down.sql ====
--
-- SQL cleanup rollback.
--

--
-- Add back unused tables `river_client` and `river_client_queue`.
--

CREATE UNLOGGED TABLE /* TEMPLATE: schema */river_client (
    id text PRIMARY KEY NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    metadata jsonb NOT NULL DEFAULT '{}',
    paused_at timestamptz,
    updated_at timestamptz NOT NULL,
    CONSTRAINT name_length CHECK (char_length(id) > 0 AND char_length(id) < 128)
);

CREATE UNLOGGED TABLE /* TEMPLATE: schema */river_client_queue (
    river_client_id text NOT NULL REFERENCES /* TEMPLATE: schema */river_client (id) ON DELETE CASCADE,
    name text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    max_workers bigint NOT NULL DEFAULT 0,
    metadata jsonb NOT NULL DEFAULT '{}',
    num_jobs_completed bigint NOT NULL DEFAULT 0,
    num_jobs_running bigint NOT NULL DEFAULT 0,
    updated_at timestamptz NOT NULL,
    PRIMARY KEY (river_client_id, name),
    CONSTRAINT name_length CHECK (char_length(name) > 0 AND char_length(name) < 128),
    CONSTRAINT num_jobs_completed_zero_or_positive CHECK (num_jobs_completed >= 0),
    CONSTRAINT num_jobs_running_zero_or_positive CHECK (num_jobs_running >= 0)
);

--
-- Revert addition of `DEFAULT 25` to `river_job.max_attempts`.
--

ALTER TABLE /* TEMPLATE: schema */river_job
    ALTER COLUMN max_attempts DROP DEFAULT;

--
-- Changes `river_queue.updated_at` to revert the default of `CURRENT_TIMESTAMP`.
--

ALTER TABLE /* TEMPLATE: schema */river_queue
    ALTER COLUMN updated_at DROP DEFAULT;

--
-- SQLite JSONB conversion rollback.
--
-- No-op. PostgreSQL already stores River JSON columns as jsonb.

--
-- Notification outbox rollback.
--

DROP TABLE /* TEMPLATE: schema */river_notification;

-- ==== 006_bulk_unique.down.sql ====

--
-- Drop `river_job.unique_states` and its index.
--

DROP INDEX /* TEMPLATE: schema */river_job_unique_idx;

ALTER TABLE /* TEMPLATE: schema */river_job
    DROP COLUMN unique_states;

CREATE UNIQUE INDEX IF NOT EXISTS river_job_kind_unique_key_idx ON /* TEMPLATE: schema */river_job (kind, unique_key) WHERE unique_key IS NOT NULL;

--
-- Drop `river_job_state_in_bitmask` function.
--
DROP FUNCTION /* TEMPLATE: schema */river_job_state_in_bitmask;

-- ==== 005_migration_unique_client.down.sql ====
--
-- Revert to migration table based only on `(version)`.
--
-- If any non-main migrations are present, 005 is considered irreversible.
--

DO
$body$
BEGIN
    -- Tolerate users who may be using their own migration system rather than
    -- River's. If they are, they will have skipped version 001 containing
    -- `CREATE TABLE river_migration`, so this table won't exist.
    IF (SELECT to_regclass('/* TEMPLATE: schema */river_migration') IS NOT NULL) THEN
        IF EXISTS (
            SELECT *
            FROM /* TEMPLATE: schema */river_migration
            WHERE line <> 'main'
        ) THEN
            RAISE EXCEPTION 'Found non-main migration lines in the database; version 005 migration is irreversible because it would result in loss of migration information.';
        END IF;

        ALTER TABLE /* TEMPLATE: schema */river_migration
            RENAME TO river_migration_old;

        CREATE TABLE /* TEMPLATE: schema */river_migration(
            id bigserial PRIMARY KEY,
            created_at timestamptz NOT NULL DEFAULT NOW(),
            version bigint NOT NULL,
            CONSTRAINT version CHECK (version >= 1)
        );

        CREATE UNIQUE INDEX ON /* TEMPLATE: schema */river_migration USING btree(version);

        INSERT INTO /* TEMPLATE: schema */river_migration
            (created_at, version)
        SELECT created_at, version
        FROM /* TEMPLATE: schema */river_migration_old;

        DROP TABLE /* TEMPLATE: schema */river_migration_old;
    END IF;
END;
$body$
LANGUAGE 'plpgsql'; 

--
-- Drop `river_job.unique_key`.
--

ALTER TABLE /* TEMPLATE: schema */river_job
    DROP COLUMN unique_key;

--
-- Drop `river_client` and derivative.
--

DROP TABLE /* TEMPLATE: schema */river_client_queue;
DROP TABLE /* TEMPLATE: schema */river_client;

