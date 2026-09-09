-- =============================================================================
-- Mina migration: from berkeley to mesa
-- + extend zkapp_states_nullable with element8..element31 (int)
-- + extend zkapp_states with element8..element31 (int)
-- + drop UNIQUE/index on zkapp_{events,field_array}.element_ids (btree overflow
--   for max-cost zkApps); these rows are no longer content-deduplicated
-- + make zkapp_account_update_body.events_id/actions_id nullable (NULL = empty)
-- + deduplicate zkapp_{states,action_states} and add a UNIQUE constraint on
--   their element columns, so the content dedup becomes atomic
-- + record status in migration_history
-- =============================================================================

-- NOTE: When modifying this script, please keep TXNs small, and idempotent

-- Fail fast
\set ON_ERROR_STOP on
-- Keep locks short; abort instead of blocking production traffic.
SET lock_timeout = '10s';
SET statement_timeout = '10min';

-- See "src/lib/node_config/version/node_config_version.ml" for protocol version
SET archive.current_protocol_version = '3.0.0';
-- Post-HF protocol version. This one corresponds to Mesa, specifically
SET archive.target_protocol_version = '4.0.0';
-- The version of this script. If you modify the script, please bump the version
SET archive.migration_version = '0.0.6';

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

    -- HACK: We don't have a record in migration history in Berkeley, hence 
    -- setting to 3.0.0 if it's not present. 
    latest_protocol_version := COALESCE(latest_protocol_version, '3.0.0'); 

    IF latest_protocol_version = current_protocol_version THEN
        INSERT INTO migration_history(
            protocol_version, migration_version, description, status
        ) VALUES (
            target_protocol_version,
            target_migration_version,
            'Upgrade from Berkeley to Mesa. Add {zkapp_states,zkapp_states_nullable}.element8..element31 (int); drop zkapp_{events,field_array}.element_ids UNIQUE/index (no dedup); make zkapp_account_update_body.{events_id,actions_id} nullable (NULL=empty); dedup zkapp_{states,action_states} and add UNIQUE on their element columns',
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

-- 2. `zkapp_states_nullable`: Add nullable columns element8..element31

CREATE FUNCTION pg_temp.add_zkapp_states_nullable_element(p_element_num INT)
RETURNS VOID AS $$
DECLARE
    col_name TEXT := 'element' || p_element_num;
BEGIN

    RAISE DEBUG 'Adding column % for zkapp_states_nullable', col_name;

    EXECUTE format(
        'ALTER TABLE zkapp_states_nullable ADD COLUMN IF NOT EXISTS %I INT REFERENCES zkapp_field(id)',
        col_name
    );

    RAISE DEBUG 'Added column % for zkapp_states_nullable', col_name;

EXCEPTION
    WHEN OTHERS THEN
        PERFORM pg_temp.set_migration_status('failed'::migration_status);
        RAISE EXCEPTION 'An error occurred while adding column % to zkapp_states_nullable: %', col_name, SQLERRM;
END
$$ LANGUAGE plpgsql;

SELECT pg_temp.add_zkapp_states_nullable_element(8);
SELECT pg_temp.add_zkapp_states_nullable_element(9);
SELECT pg_temp.add_zkapp_states_nullable_element(10);
SELECT pg_temp.add_zkapp_states_nullable_element(11);
SELECT pg_temp.add_zkapp_states_nullable_element(12);
SELECT pg_temp.add_zkapp_states_nullable_element(13);
SELECT pg_temp.add_zkapp_states_nullable_element(14);
SELECT pg_temp.add_zkapp_states_nullable_element(15);
SELECT pg_temp.add_zkapp_states_nullable_element(16);
SELECT pg_temp.add_zkapp_states_nullable_element(17);
SELECT pg_temp.add_zkapp_states_nullable_element(18);
SELECT pg_temp.add_zkapp_states_nullable_element(19);
SELECT pg_temp.add_zkapp_states_nullable_element(20);
SELECT pg_temp.add_zkapp_states_nullable_element(21);
SELECT pg_temp.add_zkapp_states_nullable_element(22);
SELECT pg_temp.add_zkapp_states_nullable_element(23);
SELECT pg_temp.add_zkapp_states_nullable_element(24);
SELECT pg_temp.add_zkapp_states_nullable_element(25);
SELECT pg_temp.add_zkapp_states_nullable_element(26);
SELECT pg_temp.add_zkapp_states_nullable_element(27);
SELECT pg_temp.add_zkapp_states_nullable_element(28);
SELECT pg_temp.add_zkapp_states_nullable_element(29);
SELECT pg_temp.add_zkapp_states_nullable_element(30);
SELECT pg_temp.add_zkapp_states_nullable_element(31);

-- 3. `zkapp_states`: Add columns element8..element31

CREATE FUNCTION pg_temp.get_zero_field_id() RETURNS int AS $$
DECLARE
  result int;
  zero text := '0';
BEGIN
  -- Try to fetch existing id
  SELECT id INTO result FROM zkapp_field WHERE field = zero;

  -- If not found, insert and get the new id
  IF result IS NULL THEN
    INSERT INTO zkapp_field(field)
    VALUES (zero)
    RETURNING id INTO result;
  END IF;

  RETURN result;
END
$$ LANGUAGE plpgsql;

CREATE FUNCTION pg_temp.add_zkapp_states_element(p_element_num INT)
RETURNS VOID AS $$
DECLARE
    col_name TEXT := 'element' || p_element_num;
    default_id int := pg_temp.get_zero_field_id();
BEGIN

    RAISE DEBUG 'Adding column % for zkapp_states', col_name;

    EXECUTE format(
        'ALTER TABLE zkapp_states ADD COLUMN IF NOT EXISTS %I INT DEFAULT %s NOT NULL REFERENCES zkapp_field(id)',
        col_name,
        default_id
    );

    RAISE DEBUG 'Added column % for zkapp_states', col_name;

EXCEPTION
    WHEN OTHERS THEN
        PERFORM pg_temp.set_migration_status('failed'::migration_status);
        RAISE EXCEPTION 'An error occurred while adding column % to zkapp_states: %', col_name, SQLERRM;
END
$$ LANGUAGE plpgsql;

DO $$
DECLARE
    default_id int := pg_temp.get_zero_field_id();
BEGIN
    RAISE NOTICE 'Zero field in table zkapp_field is of id = %', default_id;
END
$$;

SELECT pg_temp.add_zkapp_states_element(8);
SELECT pg_temp.add_zkapp_states_element(9);
SELECT pg_temp.add_zkapp_states_element(10);
SELECT pg_temp.add_zkapp_states_element(11);
SELECT pg_temp.add_zkapp_states_element(12);
SELECT pg_temp.add_zkapp_states_element(13);
SELECT pg_temp.add_zkapp_states_element(14);
SELECT pg_temp.add_zkapp_states_element(15);
SELECT pg_temp.add_zkapp_states_element(16);
SELECT pg_temp.add_zkapp_states_element(17);
SELECT pg_temp.add_zkapp_states_element(18);
SELECT pg_temp.add_zkapp_states_element(19);
SELECT pg_temp.add_zkapp_states_element(20);
SELECT pg_temp.add_zkapp_states_element(21);
SELECT pg_temp.add_zkapp_states_element(22);
SELECT pg_temp.add_zkapp_states_element(23);
SELECT pg_temp.add_zkapp_states_element(24);
SELECT pg_temp.add_zkapp_states_element(25);
SELECT pg_temp.add_zkapp_states_element(26);
SELECT pg_temp.add_zkapp_states_element(27);
SELECT pg_temp.add_zkapp_states_element(28);
SELECT pg_temp.add_zkapp_states_element(29);
SELECT pg_temp.add_zkapp_states_element(30);
SELECT pg_temp.add_zkapp_states_element(31);

-- 3b. Drop the UNIQUE constraint + standalone btree index on the unbounded int[]
-- element_ids columns: a btree key over a ~1024-element array exceeds Postgres'
-- 2704-byte limit, failing inserts for max-cost zkApps. These rows are no longer
-- content-deduplicated. Also make events_id/actions_id nullable so an empty
-- events/actions list is stored as NULL (no zkapp_events row). All idempotent.
ALTER TABLE zkapp_field_array DROP CONSTRAINT IF EXISTS zkapp_field_array_element_ids_key;
DROP INDEX IF EXISTS idx_zkapp_field_array_element_ids;
ALTER TABLE zkapp_events DROP CONSTRAINT IF EXISTS zkapp_events_element_ids_key;
DROP INDEX IF EXISTS idx_zkapp_events_element_ids;
ALTER TABLE zkapp_account_update_body ALTER COLUMN events_id DROP NOT NULL;
ALTER TABLE zkapp_account_update_body ALTER COLUMN actions_id DROP NOT NULL;

-- 3c. Deduplicate zkapp_states / zkapp_action_states and constrain them.
-- Both tables were content-deduplicated by a non-atomic SELECT-then-INSERT and
-- had no UNIQUE constraint, so two concurrent writers could both miss and both
-- insert. Every later lookup of that content then failed permanently with
-- "Received 2 tuples, expected at most one". Merge the existing duplicates,
-- repoint the referencing rows, then add the UNIQUE constraint that makes the
-- dedup atomic. All idempotent: with no duplicates and the constraint already
-- present, this is a no-op.

-- 3c.i  zkapp_states: zkapp_accounts.app_state_id is the only reference.
CREATE TEMP TABLE zkapp_states_dups AS
SELECT (array_agg(id ORDER BY id))[1]          AS keep_id
     , unnest((array_agg(id ORDER BY id))[2:]) AS dup_id
FROM zkapp_states t
GROUP BY to_jsonb(t) - 'id'
HAVING count(*) > 1;

UPDATE zkapp_accounts a
SET    app_state_id = d.keep_id
FROM   zkapp_states_dups d
WHERE  a.app_state_id = d.dup_id;

DELETE FROM zkapp_states WHERE id IN (SELECT dup_id FROM zkapp_states_dups);

DROP TABLE zkapp_states_dups;

-- 3c.ii zkapp_action_states: zkapp_accounts.action_state_id is the only
--       reference.
CREATE TEMP TABLE zkapp_action_states_dups AS
SELECT (array_agg(id ORDER BY id))[1]          AS keep_id
     , unnest((array_agg(id ORDER BY id))[2:]) AS dup_id
FROM zkapp_action_states t
GROUP BY to_jsonb(t) - 'id'
HAVING count(*) > 1;

UPDATE zkapp_accounts a
SET    action_state_id = d.keep_id
FROM   zkapp_action_states_dups d
WHERE  a.action_state_id = d.dup_id;

DELETE FROM zkapp_action_states
WHERE id IN (SELECT dup_id FROM zkapp_action_states_dups);

DROP TABLE zkapp_action_states_dups;

-- 3c.iii Add the UNIQUE constraints. ALTER TABLE ADD CONSTRAINT is not
--        idempotent on its own, so guard on pg_constraint. Building the index
--        takes an ACCESS EXCLUSIVE lock; the statement_timeout above bounds it.
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'zkapp_states_elements_key'
    ) THEN
        ALTER TABLE zkapp_states
          ADD CONSTRAINT zkapp_states_elements_key UNIQUE (element0, element1, element2, element3, element4, element5, element6, element7, element8, element9, element10, element11, element12, element13, element14, element15, element16, element17, element18, element19, element20, element21, element22, element23, element24, element25, element26, element27, element28, element29, element30, element31);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'zkapp_action_states_elements_key'
    ) THEN
        ALTER TABLE zkapp_action_states
          ADD CONSTRAINT zkapp_action_states_elements_key UNIQUE (element0, element1, element2, element3, element4);
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        PERFORM pg_temp.set_migration_status('failed'::migration_status);
        RAISE EXCEPTION 'An error occurred while adding the zkapp state UNIQUE constraints: %', SQLERRM;
END
$$;

-- 4. Update schema_history

DO $$
BEGIN
    PERFORM pg_temp.set_migration_status('applied'::migration_status);
EXCEPTION
    WHEN OTHERS THEN
        PERFORM pg_temp.set_migration_status('failed'::migration_status);
        RAISE;
END$$
