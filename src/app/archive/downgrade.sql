-- ============================================================================
-- Mina rollback: from protocol version 5.0.0 to 4.0.0
-- restores: 4.0.2
-- + drop the user_commands.{fee_payer_id,source_id,receiver_id} indexes
-- + token_symbols.value, zkapp_uris.value: bytea -> text
-- + drop genesis_accounts (4.0.2 does not have it)
-- + restore zkapp_permissions.set_verification_key_txn_version
-- + record status in migration_history
--
-- Reverse further steps of upgrade.sql here as they are added, and bump
-- archive.migration_version below.
-- ============================================================================

-- NOTE: When modifying this script, please keep TXNs small, and idempotent

-- Fail fast
\set ON_ERROR_STOP on
-- Keep locks short; abort instead of blocking production traffic.
SET lock_timeout = '10s';
SET statement_timeout = '10min';

-- See "src/lib/node_config/version/node_config_version.ml" for protocol version
SET archive.current_protocol_version = '5.0.0';
-- Protocol version that create_schema.sql describes, i.e. the latest released
-- one. Used to place a database that has no migration_history row yet.
SET archive.create_schema_protocol_version = '4.0.0';
-- Protocol version this script moves the database to.
SET archive.target_protocol_version = '4.0.0';
-- The version of this script. If you modify the script, please bump the version
SET archive.migration_version = '0.0.4';

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
    current_protocol_version    text := current_setting('archive.current_protocol_version');
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
            'Rollback from protocol version 5.0.0 to 4.0.0. Drop genesis_accounts and the user_commands account indexes; token_symbols/zkapp_uris value to text; restore zkapp_permissions.set_verification_key_txn_version.',
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
            'Rollback from protocol version 5.0.0 to 4.0.0. Drop genesis_accounts and the user_commands account indexes; token_symbols/zkapp_uris value to text; restore zkapp_permissions.set_verification_key_txn_version.',
            'starting'::migration_status
        );
    ELSIF
        latest_protocol_version = target_protocol_version AND
        latest_migration_version = target_migration_version
    THEN
        RAISE NOTICE
          'Previous migration in failed/progress/completed, reapplying';
    ELSE
        RAISE EXCEPTION
          'Could not apply Migration to current protocol & migration version: (%, %)',
          latest_protocol_version,
          latest_migration_version;
    END IF;
END$$;

-- 2. Drop genesis_accounts: release 4.0.2 does not have it. After the next
-- upgrade it is empty until the genesis ledgers are written to it again.

DROP TABLE IF EXISTS genesis_accounts;

-- 3. Drop the user_commands account indexes added by upgrade.sql
--
-- DROP INDEX takes an ACCESS EXCLUSIVE lock on user_commands. lock_timeout
-- above bounds how long it waits for that lock (it can queue behind running
-- reads until then), not how long it is held. On a live archive,
-- DROP INDEX CONCURRENTLY outside this script avoids the wait entirely.
DROP INDEX IF EXISTS idx_user_commands_fee_payer_id;
DROP INDEX IF EXISTS idx_user_commands_source_id;
DROP INDEX IF EXISTS idx_user_commands_receiver_id;

-- 4. token_symbols.value and zkapp_uris.value: bytea -> text
--
-- convert_from fails on a value that is not valid in the database encoding
-- (e.g. a 0xff token symbol in a UTF8 database). The script then stops, and
-- the column stays bytea: text cannot hold that value without loss.
DO $$
DECLARE
    tbl text;
BEGIN
    FOREACH tbl IN ARRAY ARRAY['token_symbols', 'zkapp_uris'] LOOP
        IF (SELECT data_type FROM information_schema.columns
            WHERE table_schema = 'public'
              AND table_name = tbl
              AND column_name = 'value') = 'bytea'
        THEN
            EXECUTE format(
              'ALTER TABLE public.%I ALTER COLUMN value TYPE text'
              ' USING convert_from(value, getdatabaseencoding())', tbl);
        END IF;
    END LOOP;
END $$;

-- 5. zkapp_permissions.set_verification_key_txn_version: release 4.0.2 reads
-- and writes it, between set_verification_key_auth and set_zkapp_uri.
-- PostgreSQL can only add a column at the end, so the table is rebuilt in
-- 4.0.2's column order, keeping its ids, sequence and constraint names. The
-- versions dropped by upgrade.sql are gone, so every row gets 4, the
-- transaction version of 4.0.2.
--
-- The table holds one row per distinct permissions, so copying it is quick.
-- The foreign keys to it are dropped while it is rebuilt and added back NOT
-- VALID, which takes brief locks on accounts_accessed and zkapp_updates; they
-- are validated in the next step without blocking writes.
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'zkapp_permissions'
          AND column_name = 'set_verification_key_txn_version'
    ) THEN
        ALTER TABLE accounts_accessed
            DROP CONSTRAINT IF EXISTS accounts_accessed_permissions_id_fkey;
        ALTER TABLE zkapp_updates
            DROP CONSTRAINT IF EXISTS zkapp_updates_permissions_id_fkey;

        CREATE TABLE zkapp_permissions_restored
        ( id                               int                         NOT NULL
        , edit_state                       zkapp_auth_required_type    NOT NULL
        , send                             zkapp_auth_required_type    NOT NULL
        , receive                          zkapp_auth_required_type    NOT NULL
        , access                           zkapp_auth_required_type    NOT NULL
        , set_delegate                     zkapp_auth_required_type    NOT NULL
        , set_permissions                  zkapp_auth_required_type    NOT NULL
        , set_verification_key_auth        zkapp_auth_required_type    NOT NULL
        , set_verification_key_txn_version int                         NOT NULL
        , set_zkapp_uri                    zkapp_auth_required_type    NOT NULL
        , edit_action_state                zkapp_auth_required_type    NOT NULL
        , set_token_symbol                 zkapp_auth_required_type    NOT NULL
        , increment_nonce                  zkapp_auth_required_type    NOT NULL
        , set_voting_for                   zkapp_auth_required_type    NOT NULL
        , set_timing                       zkapp_auth_required_type    NOT NULL
        );
        INSERT INTO zkapp_permissions_restored
        SELECT id, edit_state, send, receive, access, set_delegate,
               set_permissions, set_verification_key_auth, 4, set_zkapp_uri,
               edit_action_state, set_token_symbol, increment_nonce,
               set_voting_for, set_timing
        FROM zkapp_permissions;

        ALTER SEQUENCE zkapp_permissions_id_seq OWNED BY NONE;
        DROP TABLE zkapp_permissions;
        ALTER TABLE zkapp_permissions_restored RENAME TO zkapp_permissions;
        ALTER TABLE zkapp_permissions
            ALTER COLUMN id SET DEFAULT nextval('zkapp_permissions_id_seq');
        ALTER SEQUENCE zkapp_permissions_id_seq OWNED BY zkapp_permissions.id;
        ALTER TABLE zkapp_permissions
            ADD CONSTRAINT zkapp_permissions_pkey PRIMARY KEY (id);

        ALTER TABLE accounts_accessed
            ADD CONSTRAINT accounts_accessed_permissions_id_fkey
            FOREIGN KEY (permissions_id) REFERENCES zkapp_permissions(id) NOT VALID;
        ALTER TABLE zkapp_updates
            ADD CONSTRAINT zkapp_updates_permissions_id_fkey
            FOREIGN KEY (permissions_id) REFERENCES zkapp_permissions(id) NOT VALID;
    END IF;
END $$;

-- 5a. Validate the restored foreign keys. This scans accounts_accessed, but
-- takes only a SHARE UPDATE EXCLUSIVE lock, so writes continue. A run that
-- times out here can be repeated.
SET statement_timeout = 0;
ALTER TABLE accounts_accessed VALIDATE CONSTRAINT accounts_accessed_permissions_id_fkey;
ALTER TABLE zkapp_updates VALIDATE CONSTRAINT zkapp_updates_permissions_id_fkey;
SET statement_timeout = '10min';

-- 6. Update schema_history

DO $$
BEGIN
    PERFORM pg_temp.set_migration_status('applied'::migration_status);
EXCEPTION
    WHEN OTHERS THEN
        PERFORM pg_temp.set_migration_status('failed'::migration_status);
        RAISE;
END$$
