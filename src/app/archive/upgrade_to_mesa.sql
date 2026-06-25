-- =============================================================================
-- Mina migration: from berkeley to mesa
-- + extend zkapp_states_nullable with element8..element31 (int)
-- + extend zkapp_states with element8..element31 (int)
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
            'Upgrade from Berkeley to Mesa. Add {zkapp_states,zkapp_states_nullable}.element8..element31 (int)',
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

-- 3b. Replace the raw element_ids UNIQUE btree on zkapp_field_array and
--     zkapp_events with a UNIQUE index over a fixed-width content hash.
--
--     The raw int[] UNIQUE btree overflows Postgres' 2704-byte key limit on a
--     max-cost zkApp (~1030-element array). Hashing collapses any array to a
--     32-byte key, restoring dedup + indexed lookup without the overflow.
--
--     Idempotent and safe on any starting state:
--       * original schema (UNIQUE present, no duplicates),
--       * the relaxed "insert-only" band-aid (UNIQUE dropped, duplicates exist),
--       * already migrated (re-running is a no-op).
--     Order is mandatory: drop old constraint -> dedup -> create hash index,
--     because CREATE UNIQUE INDEX aborts while duplicate arrays remain.

-- IMMUTABLE content-hash function (integer text is locale-independent).
CREATE OR REPLACE FUNCTION zkapp_element_ids_hash(element_ids int[]) RETURNS bytea
  LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE
  AS $$ SELECT sha256(convert_to(array_to_string(element_ids, ',', 'NULL'), 'UTF8')) $$;

-- Drop the old raw-array UNIQUE constraints and standalone indexes if present.
ALTER TABLE zkapp_field_array DROP CONSTRAINT IF EXISTS zkapp_field_array_element_ids_key;
DROP INDEX IF EXISTS idx_zkapp_field_array_element_ids;
ALTER TABLE zkapp_events DROP CONSTRAINT IF EXISTS zkapp_events_element_ids_key;
DROP INDEX IF EXISTS idx_zkapp_events_element_ids;

-- Deduplicate existing rows, deepest table first. Collapsing zkapp_field_array
-- rows can make two zkapp_events arrays identical, so do field_array before
-- events. Repointing rewrites the field_array ids embedded in
-- zkapp_events.element_ids (order-preserving) and the scalar events_id/actions_id.
CREATE TEMP TABLE pg_temp_fa_remap AS
SELECT id AS dup_id, canon_id FROM (
  SELECT id, min(id) OVER (PARTITION BY element_ids) AS canon_id FROM zkapp_field_array
) s WHERE id <> canon_id;
CREATE INDEX ON pg_temp_fa_remap (dup_id);

WITH affected AS (
  SELECT e.id, array_agg(COALESCE(r.canon_id, u.elem) ORDER BY u.ord) AS new_ids
  FROM zkapp_events e
  CROSS JOIN LATERAL unnest(e.element_ids) WITH ORDINALITY AS u(elem, ord)
  LEFT JOIN pg_temp_fa_remap r ON r.dup_id = u.elem
  WHERE e.id IN (
    SELECT DISTINCT e2.id FROM zkapp_events e2
    CROSS JOIN LATERAL unnest(e2.element_ids) AS x(elem)
    JOIN pg_temp_fa_remap r2 ON r2.dup_id = x.elem)
  GROUP BY e.id)
UPDATE zkapp_events e SET element_ids = a.new_ids FROM affected a WHERE e.id = a.id;

DELETE FROM zkapp_field_array fa USING pg_temp_fa_remap r WHERE fa.id = r.dup_id;
DROP TABLE pg_temp_fa_remap;

CREATE TEMP TABLE pg_temp_ev_remap AS
SELECT id AS dup_id, canon_id FROM (
  SELECT id, min(id) OVER (PARTITION BY element_ids) AS canon_id FROM zkapp_events
) s WHERE id <> canon_id;
CREATE INDEX ON pg_temp_ev_remap (dup_id);

UPDATE zkapp_account_update_body b SET events_id  = r.canon_id FROM pg_temp_ev_remap r WHERE b.events_id  = r.dup_id;
UPDATE zkapp_account_update_body b SET actions_id = r.canon_id FROM pg_temp_ev_remap r WHERE b.actions_id = r.dup_id;
DELETE FROM zkapp_events e USING pg_temp_ev_remap r WHERE e.id = r.dup_id;
DROP TABLE pg_temp_ev_remap;

-- Now that arrays are unique, install the content-hash UNIQUE indexes.
CREATE UNIQUE INDEX IF NOT EXISTS zkapp_field_array_element_ids_hash_key
  ON zkapp_field_array (zkapp_element_ids_hash(element_ids));
CREATE UNIQUE INDEX IF NOT EXISTS zkapp_events_element_ids_hash_key
  ON zkapp_events (zkapp_element_ids_hash(element_ids));

-- 4. Update schema_history

DO $$
BEGIN
    PERFORM pg_temp.set_migration_status('applied'::migration_status);
EXCEPTION
    WHEN OTHERS THEN
        PERFORM pg_temp.set_migration_status('failed'::migration_status);
        RAISE;
END$$
