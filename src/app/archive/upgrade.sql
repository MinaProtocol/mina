-- =============================================================================
-- Mina migration: from protocol version 4.0.0 to 5.0.0
-- + record status in migration_history
--
-- Adds the tables the automatic hard fork hand-over keeps: hardfork_state and
-- genesis_accounts. Add further changes here as they land, and bump
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
            'Upgrade from protocol version 4.0.0 to 5.0.0. Adds hardfork_state and genesis_accounts.',
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

-- 2a. `hardfork_state`: what the archive knows about the fork it is passing
-- through. Created here as well as in create_schema.sql, because a database
-- upgraded from the pre-fork schema never ran the latter. At most one row can
-- ever exist: several archive processes may share one database and must not be
-- able to hold different opinions about the fork.

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'hardfork_source') THEN
        CREATE TYPE hardfork_source AS ENUM ('daemon_config', 'fork_genesis', 'operator');
    END IF;
END $$;

CREATE TABLE IF NOT EXISTS hardfork_state (
    id                      int              PRIMARY KEY DEFAULT 1 CHECK (id = 1),
    fork_state_hash         text             NOT NULL,
    fork_blockchain_length  bigint           NOT NULL,
    fork_global_slot        bigint           NOT NULL,
    config_json             text             NOT NULL,
    source                  hardfork_source  NOT NULL,
    announced_at            timestamptz      NOT NULL DEFAULT now(),
    finalized_at            timestamptz
);

-- 2b. `genesis_accounts`: the state every account was in when an era's genesis
-- ledger was established. Not block effects, so not in accounts_accessed.
-- Append only and keyed by the height the ledger takes effect at: a database
-- spans every era it has lived through, and a balance query at a pre-fork
-- height still needs the earlier era's genesis balance for an account that was
-- untouched throughout it.

CREATE TABLE IF NOT EXISTS genesis_accounts (
    genesis_height           bigint  NOT NULL,
    public_key               text    NOT NULL,
    token                    text    NOT NULL,
    balance                  text    NOT NULL,
    nonce                    bigint  NOT NULL,
    initial_minimum_balance  text,
    cliff_time               bigint,
    cliff_amount             text,
    vesting_period           bigint,
    vesting_increment        text,
    PRIMARY KEY (genesis_height, public_key, token)
);

CREATE INDEX IF NOT EXISTS idx_genesis_accounts_lookup
  ON genesis_accounts(public_key, token, genesis_height DESC);

-- 3. Update schema_history

DO $$
BEGIN
    PERFORM pg_temp.set_migration_status('applied'::migration_status);
EXCEPTION
    WHEN OTHERS THEN
        PERFORM pg_temp.set_migration_status('failed'::migration_status);
        RAISE;
END$$
