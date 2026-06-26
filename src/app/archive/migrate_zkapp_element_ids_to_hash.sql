-- =============================================================================
-- Standalone migration: move zkapp_field_array / zkapp_events from the raw
-- element_ids btree to a sha256 content-hash UNIQUE index.
--
-- For archive nodes ALREADY ON MESA running the "band-aid" build (element_ids
-- UNIQUE dropped, inserts not deduplicated). This is the focused element_ids
-- step only -- it does NOT re-run the berkeley->mesa migration. It is the same
-- change as step 3b of upgrade_to_mesa.sql, packaged with a dry-run and
-- integrity gates for operators applying it in place.
--
-- What it does, in the one mandatory order:
--   1. create the IMMUTABLE zkapp_element_ids_hash() function
--   2. drop the old raw-array UNIQUE constraint / index (IF EXISTS; no-op on the
--      band-aid, removes the overflow-prone btree on the original schema)
--   3. deduplicate existing rows (deepest table first; remaps the field_array
--      ids embedded in zkapp_events.element_ids and the scalar
--      events_id/actions_id) -- REQUIRED before the unique index can be built
--   4. create the hash UNIQUE indexes
--
-- Idempotent and safe on any starting state (band-aid / original / already
-- migrated). Single transaction; rolls back on any integrity failure.
--
-- USAGE
--   1. DRY RUN (default -- reads only, reports what it WOULD change):
--        psql "<conn>" -f migrate_zkapp_element_ids_to_hash.sql
--   2. APPLY:
--        psql "<conn>" -v apply=true -f migrate_zkapp_element_ids_to_hash.sql
--
-- SAFETY: stop the archive node first (do not run while it is reading/writing),
-- take a pg_dump backup, and test on a restored dump to size downtime -- the
-- dedup and the non-concurrent CREATE UNIQUE INDEX hold an exclusive lock.
-- =============================================================================

\set ON_ERROR_STOP on

\if :{?apply}
\else
  \set apply false
\endif

\echo ''
\if :apply
  \echo '>>> MODE: APPLY  (changes WILL be committed if all checks pass)'
\else
  \echo '>>> MODE: DRY RUN  (no changes committed; re-run with -v apply=true to apply)'
\endif
\echo ''

BEGIN;
SET LOCAL work_mem = '512MB';

-- Pre-flight: how much duplication exists now.
DO $$
DECLARE
  fa_total bigint; fa_distinct bigint; ev_total bigint; ev_distinct bigint;
BEGIN
  SELECT count(*), count(DISTINCT element_ids) FROM zkapp_field_array INTO fa_total, fa_distinct;
  SELECT count(*), count(DISTINCT element_ids) FROM zkapp_events       INTO ev_total, ev_distinct;
  RAISE NOTICE 'BEFORE  zkapp_field_array: % rows, % distinct (% duplicate rows)', fa_total, fa_distinct, fa_total - fa_distinct;
  RAISE NOTICE 'BEFORE  zkapp_events:      % rows, % distinct (% duplicate rows)', ev_total, ev_distinct, ev_total - ev_distinct;
END $$;

-- 1. IMMUTABLE content-hash function (integer text is locale-independent).
CREATE OR REPLACE FUNCTION zkapp_element_ids_hash(element_ids int[]) RETURNS bytea
  LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE
  AS $$ SELECT sha256(convert_to(array_to_string(element_ids, ',', 'NULL'), 'UTF8')) $$;

-- 2. Drop the old raw-array UNIQUE constraints / standalone indexes if present.
ALTER TABLE zkapp_field_array DROP CONSTRAINT IF EXISTS zkapp_field_array_element_ids_key;
DROP INDEX IF EXISTS idx_zkapp_field_array_element_ids;
ALTER TABLE zkapp_events DROP CONSTRAINT IF EXISTS zkapp_events_element_ids_key;
DROP INDEX IF EXISTS idx_zkapp_events_element_ids;

-- 3a. Deduplicate zkapp_field_array (deepest first), remapping the field_array
--     ids embedded in zkapp_events.element_ids (order-preserving).
CREATE TEMP TABLE fa_remap ON COMMIT DROP AS
SELECT id AS dup_id, canon_id FROM (
  SELECT id, min(id) OVER (PARTITION BY element_ids) AS canon_id FROM zkapp_field_array
) s WHERE id <> canon_id;
CREATE INDEX fa_remap_dup_idx ON fa_remap (dup_id);

WITH affected AS (
  SELECT e.id, array_agg(COALESCE(r.canon_id, u.elem) ORDER BY u.ord) AS new_ids
  FROM zkapp_events e
  CROSS JOIN LATERAL unnest(e.element_ids) WITH ORDINALITY AS u(elem, ord)
  LEFT JOIN fa_remap r ON r.dup_id = u.elem
  WHERE e.id IN (
    SELECT DISTINCT e2.id FROM zkapp_events e2
    CROSS JOIN LATERAL unnest(e2.element_ids) AS x(elem)
    JOIN fa_remap r2 ON r2.dup_id = x.elem)
  GROUP BY e.id)
UPDATE zkapp_events e SET element_ids = a.new_ids FROM affected a WHERE e.id = a.id;

DELETE FROM zkapp_field_array fa USING fa_remap r WHERE fa.id = r.dup_id;

-- 3b. Deduplicate zkapp_events (after the field_array remap may create new dups).
CREATE TEMP TABLE ev_remap ON COMMIT DROP AS
SELECT id AS dup_id, canon_id FROM (
  SELECT id, min(id) OVER (PARTITION BY element_ids) AS canon_id FROM zkapp_events
) s WHERE id <> canon_id;
CREATE INDEX ev_remap_dup_idx ON ev_remap (dup_id);

UPDATE zkapp_account_update_body b SET events_id  = r.canon_id FROM ev_remap r WHERE b.events_id  = r.dup_id;
UPDATE zkapp_account_update_body b SET actions_id = r.canon_id FROM ev_remap r WHERE b.actions_id = r.dup_id;
DELETE FROM zkapp_events e USING ev_remap r WHERE e.id = r.dup_id;

-- Verify dedup + integrity; HARD-FAIL (rollback) on any problem.
DO $$
DECLARE
  fa_removed bigint; ev_removed bigint;
  fa_total bigint; fa_distinct bigint; ev_total bigint; ev_distinct bigint;
  dangling_events bigint; dangling_field_arrays bigint;
BEGIN
  SELECT count(*) FROM fa_remap INTO fa_removed;
  SELECT count(*) FROM ev_remap INTO ev_removed;
  SELECT count(*), count(DISTINCT element_ids) FROM zkapp_field_array INTO fa_total, fa_distinct;
  SELECT count(*), count(DISTINCT element_ids) FROM zkapp_events       INTO ev_total, ev_distinct;
  SELECT count(*) FROM zkapp_account_update_body b
   WHERE NOT EXISTS (SELECT 1 FROM zkapp_events e WHERE e.id = b.events_id)
      OR NOT EXISTS (SELECT 1 FROM zkapp_events e WHERE e.id = b.actions_id) INTO dangling_events;
  SELECT count(*) FROM zkapp_events e CROSS JOIN LATERAL unnest(e.element_ids) AS x(elem)
   WHERE NOT EXISTS (SELECT 1 FROM zkapp_field_array fa WHERE fa.id = x.elem) INTO dangling_field_arrays;

  RAISE NOTICE 'AFTER   zkapp_field_array: % rows, % distinct (removed % duplicate rows)', fa_total, fa_distinct, fa_removed;
  RAISE NOTICE 'AFTER   zkapp_events:      % rows, % distinct (removed % duplicate rows)', ev_total, ev_distinct, ev_removed;
  RAISE NOTICE 'CHECK   dangling event refs: %  dangling field_array refs: %  (both must be 0)', dangling_events, dangling_field_arrays;

  IF dangling_events <> 0 OR dangling_field_arrays <> 0 THEN
    RAISE EXCEPTION 'INTEGRITY CHECK FAILED: % dangling event refs, % dangling field_array refs -- rolling back', dangling_events, dangling_field_arrays;
  END IF;
  IF fa_total <> fa_distinct OR ev_total <> ev_distinct THEN
    RAISE EXCEPTION 'DEDUP INCOMPLETE: duplicate arrays still present -- rolling back';
  END IF;
  RAISE NOTICE 'Dedup + integrity checks passed.';
END $$;

-- 4. Arrays are now unique: install the content-hash UNIQUE indexes.
CREATE UNIQUE INDEX IF NOT EXISTS zkapp_field_array_element_ids_hash_key
  ON zkapp_field_array (zkapp_element_ids_hash(element_ids));
CREATE UNIQUE INDEX IF NOT EXISTS zkapp_events_element_ids_hash_key
  ON zkapp_events (zkapp_element_ids_hash(element_ids));

\if :apply
  COMMIT;
  \echo '>>> APPLIED: dedup + content-hash UNIQUE indexes committed.'
\else
  ROLLBACK;
  \echo '>>> DRY RUN complete: rolled back, no changes made. Re-run with -v apply=true to apply.'
\endif
