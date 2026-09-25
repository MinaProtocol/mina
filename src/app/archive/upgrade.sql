-- =============================================================================
-- Mina migration: from protocol version 4.0.0 to 5.0.0
-- + index user_commands.{fee_payer_id,source_id,receiver_id} for account lookups
-- + record status in migration_history
--
-- Add further 5.0.0 schema changes here as they land, and bump
-- archive.migration_version below.
-- =============================================================================

-- NOTE: When modifying this script, please keep TXNs small, and idempotent

-- Fail fast
\set ON_ERROR_STOP on
-- Keep locks short; abort instead of blocking production traffic.
SET lock_timeout = '10s';
SET statement_timeout = '10min';

-- See "src/lib/node_config/version/node_config_version.ml" for protocol version
SET archive.current_protocol_version = '4.0.0';
-- Protocol version that create_schema.sql describes, i.e. the latest released
-- one. Used to place a database that has no migration_history row yet.
SET archive.create_schema_protocol_version = '4.0.0';
-- Protocol version this script moves the database to.
SET archive.target_protocol_version = '5.0.0';
-- The version of this script. If you modify the script, please bump the version
SET archive.migration_version = '0.0.2';

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
    create_schema_protocol_version text :=
        current_setting('archive.create_schema_protocol_version');
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

    -- A database built straight from create_schema.sql carries no migration
    -- history. It is at the version create_schema.sql describes.
    latest_protocol_version :=
        COALESCE(latest_protocol_version, create_schema_protocol_version);

    IF latest_protocol_version = current_protocol_version THEN
        INSERT INTO migration_history(
            protocol_version, migration_version, description, status
        ) VALUES (
            target_protocol_version,
            target_migration_version,
            'Upgrade from protocol version 4.0.0 to 5.0.0. Index user_commands.{fee_payer_id,source_id,receiver_id}.',
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

-- 2. Index the user_commands account columns
--
-- Account lookups filter on fee_payer_id, source_id and receiver_id (e.g.
-- Rosetta's /search/transactions) and otherwise scan the whole table.
--
-- The catalog is checked first, so an index that is already present costs
-- nothing: CREATE INDEX IF NOT EXISTS would still take a SHARE lock on
-- user_commands before noticing it exists, which on a live archive waits for
-- and queues behind writers. An index left INVALID by an interrupted
-- CREATE INDEX CONCURRENTLY is rebuilt instead of being silently kept.
--
-- A build blocks inserts into user_commands (not reads) for its whole duration,
-- about ten seconds per index on a mainnet-sized archive. To avoid even that,
-- create them on the running archive first:
--   CREATE INDEX CONCURRENTLY idx_user_commands_fee_payer_id ON user_commands(fee_payer_id);
--   CREATE INDEX CONCURRENTLY idx_user_commands_source_id    ON user_commands(source_id);
--   CREATE INDEX CONCURRENTLY idx_user_commands_receiver_id  ON user_commands(receiver_id);
-- after which this step is only a catalog check.
CREATE FUNCTION pg_temp.ensure_user_commands_index(p_index TEXT, p_column TEXT)
RETURNS VOID AS $$
DECLARE
    is_valid BOOLEAN;
BEGIN
    SELECT i.indisvalid INTO is_valid
    FROM pg_index i
    JOIN pg_class c ON c.oid = i.indexrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public' AND c.relname = p_index;

    IF is_valid THEN
        RAISE DEBUG 'Index % already present and valid', p_index;
        RETURN;
    END IF;

    IF is_valid IS NOT NULL THEN
        RAISE NOTICE 'Rebuilding invalid index %', p_index;
        EXECUTE format('DROP INDEX public.%I', p_index);
    END IF;

    EXECUTE format('CREATE INDEX %I ON public.user_commands(%I)', p_index, p_column);

EXCEPTION
    WHEN OTHERS THEN
        PERFORM pg_temp.set_migration_status('failed'::migration_status);
        RAISE EXCEPTION 'An error occurred while creating index %: %', p_index, SQLERRM;
END
$$ LANGUAGE plpgsql;

SELECT pg_temp.ensure_user_commands_index('idx_user_commands_fee_payer_id', 'fee_payer_id');
SELECT pg_temp.ensure_user_commands_index('idx_user_commands_source_id', 'source_id');
SELECT pg_temp.ensure_user_commands_index('idx_user_commands_receiver_id', 'receiver_id');

-- 3. Update schema_history

DO $$
BEGIN
    PERFORM pg_temp.set_migration_status('applied'::migration_status);
EXCEPTION
    WHEN OTHERS THEN
        PERFORM pg_temp.set_migration_status('failed'::migration_status);
        RAISE;
END$$
