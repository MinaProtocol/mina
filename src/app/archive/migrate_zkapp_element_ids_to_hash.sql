-- =============================================================================
-- Standalone migration: move zkapp_field_array / zkapp_events from the raw
-- element_ids btree to a sha256 content-hash UNIQUE index, AND clean up the
-- full duplicate-row cascade that the "band-aid" (insert-only) build left behind.
--
-- For archive nodes ALREADY ON MESA running the band-aid build (element_ids
-- UNIQUE dropped, inserts not deduplicated). It does NOT re-run the
-- berkeley->mesa migration.
--
-- WHY THE CASCADE: with the leaf tables inserted without dedup, re-processing a
-- transaction minted fresh ids that propagated UP the zkApp insert chain, so
-- duplicates accumulated at every level that deduplicates on a tuple containing
-- those ids:
--   zkapp_field_array -> zkapp_events -> zkapp_account_update_body
--                     -> zkapp_account_update -> zkapp_commands.account_updates_ids[]
-- Deduping only the leaves and remapping events_id/actions_id collapses
-- account_update_body rows into EXACT duplicates, which then break the archive's
-- own SELECT-before-INSERT ("Received 2 tuples, expected at most one"). So all
-- four levels must be deduplicated, deepest first, each remapping the level above.
--
-- Order (mandatory, idempotent):
--   1. create the IMMUTABLE zkapp_element_ids_hash() function
--   2. drop the old raw-array UNIQUE/index (IF EXISTS)
--   3. dedup zkapp_field_array  -> remap zkapp_events.element_ids
--   4. dedup zkapp_events       -> remap zkapp_account_update_body.{events_id,actions_id}
--   5. dedup zkapp_account_update_body (full tuple) -> remap zkapp_account_update.body_id
--   6. dedup zkapp_account_update (body_id)         -> remap zkapp_commands.account_updates_ids[]
--   7. create the hash UNIQUE indexes (needs steps 3-4 done first)
-- zkapp_commands keeps its real hash UNIQUE constraint, so it has no row
-- duplicates -- only its account_updates_ids array is remapped.
--
-- Safe on any starting state (band-aid / partially-migrated / original /
-- already done). Single transaction; rolls back on any integrity failure.
--
-- USAGE
--   DRY RUN (default):  psql "<conn>" -f migrate_zkapp_element_ids_to_hash.sql
--   APPLY:              psql "<conn>" -v apply=true -f migrate_zkapp_element_ids_to_hash.sql
--
-- SAFETY: stop the archive node first, take a pg_dump backup, and test on a
-- restored dump to size downtime (dedup + non-concurrent CREATE UNIQUE INDEX
-- hold an exclusive lock).
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

DO $$
DECLARE fa_t bigint; fa_d bigint; ev_t bigint; ev_d bigint;
BEGIN
  SELECT count(*), count(DISTINCT element_ids) FROM zkapp_field_array INTO fa_t, fa_d;
  SELECT count(*), count(DISTINCT element_ids) FROM zkapp_events       INTO ev_t, ev_d;
  RAISE NOTICE 'BEFORE  zkapp_field_array: % rows, % distinct', fa_t, fa_d;
  RAISE NOTICE 'BEFORE  zkapp_events:      % rows, % distinct', ev_t, ev_d;
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

-- 3. zkapp_field_array (deepest), remapping zkapp_events.element_ids (order-preserving).
CREATE TEMP TABLE fa_remap ON COMMIT DROP AS
SELECT id AS dup_id, canon_id FROM (
  SELECT id, min(id) OVER (PARTITION BY element_ids) AS canon_id FROM zkapp_field_array
) s WHERE id <> canon_id;
CREATE INDEX fa_remap_idx ON fa_remap (dup_id);
WITH affected AS (
  SELECT e.id, array_agg(COALESCE(r.canon_id, u.elem) ORDER BY u.ord) AS new_ids
  FROM zkapp_events e
  CROSS JOIN LATERAL unnest(e.element_ids) WITH ORDINALITY AS u(elem, ord)
  LEFT JOIN fa_remap r ON r.dup_id = u.elem
  WHERE e.id IN (SELECT DISTINCT e2.id FROM zkapp_events e2
                 CROSS JOIN LATERAL unnest(e2.element_ids) AS x(elem)
                 JOIN fa_remap r2 ON r2.dup_id = x.elem)
  GROUP BY e.id)
UPDATE zkapp_events e SET element_ids = a.new_ids FROM affected a WHERE e.id = a.id;
DELETE FROM zkapp_field_array fa USING fa_remap r WHERE fa.id = r.dup_id;

-- 4. zkapp_events, remapping zkapp_account_update_body.{events_id,actions_id}.
CREATE TEMP TABLE ev_remap ON COMMIT DROP AS
SELECT id AS dup_id, canon_id FROM (
  SELECT id, min(id) OVER (PARTITION BY element_ids) AS canon_id FROM zkapp_events
) s WHERE id <> canon_id;
CREATE INDEX ev_remap_idx ON ev_remap (dup_id);
UPDATE zkapp_account_update_body b SET events_id  = r.canon_id FROM ev_remap r WHERE b.events_id  = r.dup_id;
UPDATE zkapp_account_update_body b SET actions_id = r.canon_id FROM ev_remap r WHERE b.actions_id = r.dup_id;
DELETE FROM zkapp_events e USING ev_remap r WHERE e.id = r.dup_id;

-- 5. zkapp_account_update_body (full tuple), remapping zkapp_account_update.body_id.
--    Only events_id/actions_id were volatile, so the tuple match collapses rows
--    that differed only by those ids.
CREATE TEMP TABLE aub_remap ON COMMIT DROP AS
SELECT id AS dup_id, canon_id FROM (
  SELECT id, min(id) OVER (PARTITION BY
    account_identifier_id, update_id, balance_change, increment_nonce, events_id, actions_id,
    call_data_id, call_depth, zkapp_network_precondition_id, zkapp_account_precondition_id,
    zkapp_valid_while_precondition_id, use_full_commitment, implicit_account_creation_fee,
    may_use_token, authorization_kind, verification_key_hash_id) AS canon_id
  FROM zkapp_account_update_body
) s WHERE id <> canon_id;
CREATE INDEX aub_remap_idx ON aub_remap (dup_id);
UPDATE zkapp_account_update au SET body_id = r.canon_id FROM aub_remap r WHERE au.body_id = r.dup_id;
DELETE FROM zkapp_account_update_body b USING aub_remap r WHERE b.id = r.dup_id;

-- 6. zkapp_account_update (body_id), remapping zkapp_commands.account_updates_ids[].
CREATE TEMP TABLE au_remap ON COMMIT DROP AS
SELECT id AS dup_id, canon_id FROM (
  SELECT id, min(id) OVER (PARTITION BY body_id) AS canon_id FROM zkapp_account_update
) s WHERE id <> canon_id;
CREATE INDEX au_remap_idx ON au_remap (dup_id);
WITH affected AS (
  SELECT c.id, array_agg(COALESCE(r.canon_id, u.elem) ORDER BY u.ord) AS new_ids
  FROM zkapp_commands c
  CROSS JOIN LATERAL unnest(c.zkapp_account_updates_ids) WITH ORDINALITY AS u(elem, ord)
  LEFT JOIN au_remap r ON r.dup_id = u.elem
  WHERE c.id IN (SELECT DISTINCT c2.id FROM zkapp_commands c2
                 CROSS JOIN LATERAL unnest(c2.zkapp_account_updates_ids) AS x(elem)
                 JOIN au_remap r2 ON r2.dup_id = x.elem)
  GROUP BY c.id)
UPDATE zkapp_commands c SET zkapp_account_updates_ids = a.new_ids FROM affected a WHERE c.id = a.id;
DELETE FROM zkapp_account_update au USING au_remap r WHERE au.id = r.dup_id;

-- Verify dedup + integrity across all levels; HARD-FAIL (rollback) on any problem.
DO $$
DECLARE
  fa_dup bigint; ev_dup bigint; aub_dup bigint; au_dup bigint;
  d_ev_fa bigint; d_aub_ev bigint; d_au_aub bigint; d_cmd_au bigint;
BEGIN
  SELECT count(*) FROM (SELECT 1 FROM zkapp_field_array GROUP BY element_ids HAVING count(*)>1) z INTO fa_dup;
  SELECT count(*) FROM (SELECT 1 FROM zkapp_events GROUP BY element_ids HAVING count(*)>1) z INTO ev_dup;
  SELECT count(*) FROM (SELECT 1 FROM zkapp_account_update_body GROUP BY
     account_identifier_id, update_id, balance_change, increment_nonce, events_id, actions_id,
     call_data_id, call_depth, zkapp_network_precondition_id, zkapp_account_precondition_id,
     zkapp_valid_while_precondition_id, use_full_commitment, implicit_account_creation_fee,
     may_use_token, authorization_kind, verification_key_hash_id HAVING count(*)>1) z INTO aub_dup;
  SELECT count(*) FROM (SELECT 1 FROM zkapp_account_update GROUP BY body_id HAVING count(*)>1) z INTO au_dup;

  SELECT count(*) FROM zkapp_events e CROSS JOIN LATERAL unnest(e.element_ids) x(elem)
   WHERE NOT EXISTS (SELECT 1 FROM zkapp_field_array fa WHERE fa.id=x.elem) INTO d_ev_fa;
  SELECT count(*) FROM zkapp_account_update_body b
   WHERE NOT EXISTS (SELECT 1 FROM zkapp_events e WHERE e.id=b.events_id)
      OR NOT EXISTS (SELECT 1 FROM zkapp_events e WHERE e.id=b.actions_id) INTO d_aub_ev;
  SELECT count(*) FROM zkapp_account_update au
   WHERE NOT EXISTS (SELECT 1 FROM zkapp_account_update_body b WHERE b.id=au.body_id) INTO d_au_aub;
  SELECT count(*) FROM zkapp_commands c CROSS JOIN LATERAL unnest(c.zkapp_account_updates_ids) x(elem)
   WHERE NOT EXISTS (SELECT 1 FROM zkapp_account_update au WHERE au.id=x.elem) INTO d_cmd_au;

  RAISE NOTICE 'AFTER duplicate groups -> field_array:% events:% account_update_body:% account_update:% (all must be 0)',
    fa_dup, ev_dup, aub_dup, au_dup;
  RAISE NOTICE 'AFTER dangling refs   -> ev->fa:% aub->ev:% au->aub:% cmd->au:% (all must be 0)',
    d_ev_fa, d_aub_ev, d_au_aub, d_cmd_au;

  IF fa_dup+ev_dup+aub_dup+au_dup <> 0 THEN
    RAISE EXCEPTION 'DEDUP INCOMPLETE: duplicate rows remain -- rolling back'; END IF;
  IF d_ev_fa+d_aub_ev+d_au_aub+d_cmd_au <> 0 THEN
    RAISE EXCEPTION 'INTEGRITY CHECK FAILED: dangling references -- rolling back'; END IF;
  RAISE NOTICE 'All dedup + integrity checks passed.';
END $$;

-- 7. Arrays are now unique: install the content-hash UNIQUE indexes.
CREATE UNIQUE INDEX IF NOT EXISTS zkapp_field_array_element_ids_hash_key
  ON zkapp_field_array (zkapp_element_ids_hash(element_ids));
CREATE UNIQUE INDEX IF NOT EXISTS zkapp_events_element_ids_hash_key
  ON zkapp_events (zkapp_element_ids_hash(element_ids));

\if :apply
  COMMIT;
  \echo '>>> APPLIED: cascade dedup + content-hash UNIQUE indexes committed.'
\else
  ROLLBACK;
  \echo '>>> DRY RUN complete: rolled back, no changes made. Re-run with -v apply=true to apply.'
\endif
