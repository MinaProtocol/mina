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
        latest_migration_version < target_migration_version
    THEN
        -- An earlier revision of this script already ran. Its steps are
        -- idempotent, so record a new attempt and apply them again.
        RAISE NOTICE
          'Advancing migration version % -> % for protocol version %',
          latest_migration_version, target_migration_version, target_protocol_version;
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
-- Each part below is its own statement, so no lock is carried across them.
-- An index that is already valid is skipped entirely: CREATE INDEX IF NOT
-- EXISTS would still take a SHARE lock on user_commands before noticing that
-- the index exists, which on a live archive waits for, and queues behind,
-- writers.
--
-- Building an index takes a SHARE lock: reads continue, inserts into
-- user_commands wait until the build finishes (order of ten seconds on an
-- archive with ~10M user commands, and it grows with the table). To avoid
-- blocking writers at all, create them on the running archive first:
--   CREATE INDEX CONCURRENTLY idx_user_commands_fee_payer_id ON user_commands(fee_payer_id);
--   CREATE INDEX CONCURRENTLY idx_user_commands_source_id    ON user_commands(source_id);
--   CREATE INDEX CONCURRENTLY idx_user_commands_receiver_id  ON user_commands(receiver_id);
-- after which this step only reads the catalog.

-- 2a. Stop if one of the names is taken by a different index, rather than
-- silently accepting it as ours.
DO $$
DECLARE
    mismatched text;
BEGIN
    SELECT string_agg(c.relname, ', ')
    INTO mismatched
    FROM (VALUES
        ('idx_user_commands_fee_payer_id', 'fee_payer_id'),
        ('idx_user_commands_source_id', 'source_id'),
        ('idx_user_commands_receiver_id', 'receiver_id')
    ) AS wanted(index_name, column_name)
    JOIN pg_class c ON c.relname = wanted.index_name
    JOIN pg_namespace n ON n.oid = c.relnamespace AND n.nspname = 'public'
    JOIN pg_index i ON i.indexrelid = c.oid
    WHERE i.indrelid <> 'public.user_commands'::regclass
       OR i.indpred IS NOT NULL
       OR i.indexprs IS NOT NULL
       OR c.relam <> (SELECT oid FROM pg_am WHERE amname = 'btree')
       OR i.indnatts <> 1
       OR i.indkey[0] <> (SELECT attnum FROM pg_attribute
                          WHERE attrelid = 'public.user_commands'::regclass
                            AND attname = wanted.column_name);

    IF mismatched IS NOT NULL THEN
        RAISE EXCEPTION
          'index name(s) % already used by a different index; drop them before migrating',
          mismatched;
    END IF;
END $$;

-- 2b. Drop leftovers of an interrupted CREATE INDEX CONCURRENTLY: PostgreSQL
-- keeps those as INVALID and never uses them for reads. This takes a brief
-- ACCESS EXCLUSIVE lock on user_commands (lock_timeout above bounds the wait
-- for it) and commits here, so the build below does not hold it.
DO $$
DECLARE
    invalid_index text;
BEGIN
    FOR invalid_index IN
        SELECT c.relname
        FROM pg_index i
        JOIN pg_class c ON c.oid = i.indexrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace AND n.nspname = 'public'
        WHERE NOT i.indisvalid
          AND c.relname IN ('idx_user_commands_fee_payer_id',
                            'idx_user_commands_source_id',
                            'idx_user_commands_receiver_id')
    LOOP
        RAISE NOTICE 'Dropping invalid index %', invalid_index;
        EXECUTE format('DROP INDEX public.%I', invalid_index);
    END LOOP;
END $$;

-- 2c. Create whatever is still missing. \gexec runs each generated statement on
-- its own, so nothing is issued (and no lock taken) when all three are present.
SELECT format('CREATE INDEX %I ON public.user_commands(%I)', wanted.index_name, wanted.column_name)
FROM (VALUES
    ('idx_user_commands_fee_payer_id', 'fee_payer_id'),
    ('idx_user_commands_source_id', 'source_id'),
    ('idx_user_commands_receiver_id', 'receiver_id')
) AS wanted(index_name, column_name)
WHERE NOT EXISTS (
    SELECT 1
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace AND n.nspname = 'public'
    WHERE c.relname = wanted.index_name
)
\gexec

-- 3. Update schema_history

DO $$
BEGIN
    PERFORM pg_temp.set_migration_status('applied'::migration_status);
EXCEPTION
    WHEN OTHERS THEN
        PERFORM pg_temp.set_migration_status('failed'::migration_status);
        RAISE;
END$$
