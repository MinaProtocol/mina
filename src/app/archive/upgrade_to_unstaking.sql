-- =============================================================================
-- Mina migration: from mesa to unstaking
-- + add blocks.total_stake (text, NULL for blocks archived before this migration)
-- + add epoch_data.total_stake (text, NULL for epoch data archived before this migration)
-- + record status in migration_history
-- =============================================================================

-- NOTE: When modifying this script, please keep TXNs small, and idempotent

-- Fail fast
\set ON_ERROR_STOP on
-- Keep locks short; abort instead of blocking production traffic.
SET lock_timeout = '10s';
SET statement_timeout = '10min';

-- See "src/lib/node_config/version/node_config_version.ml" for protocol version
SET archive.current_protocol_version = '4.0.0';
-- Post-HF protocol version. This one corresponds to unstaking, specifically
SET archive.target_protocol_version = '5.0.0';
-- The version of this script. If you modify the script, please bump the version
SET archive.migration_version = '0.0.1';

-- TODO: put below in a common script

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'migration_status') THEN
        CREATE TYPE migration_status AS ENUM ('starting', 'applied', 'failed');
    END IF;
END $$;

CREATE FUNCTION pg_temp.set_migration_status(p_target_status migration_status)
RETURNS VOID AS $$
DECLARE
    target_protocol_version  text := current_setting('archive.target_protocol_version');
    target_migration_version text := current_setting('archive.migration_version');
BEGIN
    UPDATE migration_history mh
    SET status = p_target_status
    FROM (
        SELECT commit_start_at
        FROM migration_history
        WHERE protocol_version = target_protocol_version
          AND migration_version = target_migration_version
        ORDER BY commit_start_at DESC
        LIMIT 1
    ) latest
    WHERE mh.commit_start_at = latest.commit_start_at;
END
$$ LANGUAGE plpgsql STRICT;

-- 1. Ensure version table exists & has desired columns
CREATE TABLE IF NOT EXISTS migration_history (
    commit_start_at   timestamptz NOT NULL DEFAULT now() PRIMARY KEY,
    protocol_version  text NOT NULL,
    migration_version text NOT NULL,
    description       text NOT NULL,
    status            migration_status NOT NULL
);

-- TODO: put above in a common script

-- Upsert a row for this migration
DO $$
DECLARE
    target_protocol_version    text := current_setting('archive.target_protocol_version');
    current_protocol_version   text := current_setting('archive.current_protocol_version');
    target_migration_version   text := current_setting('archive.migration_version');
    latest_protocol_version    text;
    latest_migration_version   text;
    latest_migration_status    migration_status;
BEGIN
    -- Try to fetch the existing migration row
    SELECT
        protocol_version,
        migration_version,
        status
    INTO latest_protocol_version, latest_migration_version, latest_migration_status
    FROM migration_history
    ORDER BY commit_start_at DESC
    LIMIT 1;

    -- An archive created from the Mesa create_schema.sql has no migration
    -- history, hence setting to 4.0.0 if it's not present.
    latest_protocol_version := COALESCE(latest_protocol_version, '4.0.0');

    IF latest_protocol_version = current_protocol_version THEN
        INSERT INTO migration_history(
            protocol_version, migration_version, description, status
        ) VALUES (
            target_protocol_version,
            target_migration_version,
            'Upgrade from Mesa to unstaking. Add blocks.total_stake and epoch_data.total_stake (text, NULL for rows archived before this migration)',
            'starting'::migration_status
        );
    ELSIF
        latest_protocol_version = target_protocol_version AND
        latest_migration_version = target_migration_version
    THEN
        IF latest_migration_status = 'failed'::migration_status THEN
            RAISE EXCEPTION
              'Previous migration failed, please roll back before rerunning this script';
        ELSE
            RAISE NOTICE
              'Previous migration in progress/completed, reapplying';
        END IF;
    ELSE
        RAISE EXCEPTION
          'Could not apply migration to current protocol & migration version: (%, %)',
          latest_protocol_version,
          latest_migration_version;
    END IF;
END$$;

-- 2. Add the total_stake columns. Rows archived before this migration keep NULL:
-- the total stake of their ledgers was never recorded.
DO $$
BEGIN
    ALTER TABLE blocks ADD COLUMN IF NOT EXISTS total_stake text;
    ALTER TABLE epoch_data ADD COLUMN IF NOT EXISTS total_stake text;
EXCEPTION
    WHEN OTHERS THEN
        PERFORM pg_temp.set_migration_status('failed'::migration_status);
        RAISE EXCEPTION 'An error occurred while adding total_stake columns: %', SQLERRM;
END$$;

-- 3. Update schema_history

DO $$
BEGIN
    PERFORM pg_temp.set_migration_status('applied'::migration_status);
EXCEPTION
    WHEN OTHERS THEN
        PERFORM pg_temp.set_migration_status('failed'::migration_status);
        RAISE;
END$$
