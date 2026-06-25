-- =============================================================================
-- Deduplicate zkapp_field_array / zkapp_events rows that share an identical
-- element_ids array.  (Archive node operators: read the USAGE block below.)
-- =============================================================================
--
-- WHY THIS EXISTS
--   The "insert-only" mesa archive binary dropped content-deduplication on these
--   two tables to avoid the int[] UNIQUE btree key overflowing Postgres'
--   2704-byte limit on a max-cost zkApp. As a side effect, identical element_ids
--   arrays pile up as distinct rows -- harmless for correctness (rows are
--   referenced only by id), but storage bloat, dominated by the empty array '{}'
--   (one row per event-less / action-less account update).
--
--   This script collapses each set of identical-array rows to a single canonical
--   row (smallest id) and repoints every reference, DEEPEST TABLE FIRST:
--       zkapp_field_array.element_ids  -> int[] of zkapp_field.id
--       zkapp_events.element_ids       -> int[] of zkapp_field_array.id  (remapped)
--       zkapp_account_update_body.{events_id,actions_id} -> zkapp_events.id (remapped)
--   Order matters: deduping zkapp_field_array can make two previously-distinct
--   zkapp_events arrays become identical, which the zkapp_events pass then also
--   collapses.
--
-- USAGE
--   1. DRY RUN (default -- reads only, makes NO changes, prints what it WOULD do):
--        psql "<conn>" -f dedup_zkapp_element_ids.sql
--   2. APPLY (performs the dedup, in one transaction, with integrity gates):
--        psql "<conn>" -v apply=true -f dedup_zkapp_element_ids.sql
--
-- SAFETY
--   * Runs in a single transaction; aborts (rolls back) if ANY integrity check
--     fails -- it never commits a partially-deduped or dangling-reference state.
--   * Idempotent: running it again on a clean DB removes 0 rows.
--   * Take the archive node OFFLINE (or run on a copy) first -- do NOT run while a
--     live archive node or a replayer is reading/writing these tables.
--   * Recommended: take a backup (pg_dump) before APPLY.
-- =============================================================================

\set ON_ERROR_STOP on

-- Default to a dry run unless the caller passed -v apply=true.
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

-- Large transient hash/sort joins below; bounded to this transaction only.
SET LOCAL work_mem = '512MB';

-- ---------------------------------------------------------------------------
-- Pre-flight report: how much duplication exists right now.
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  fa_total bigint; fa_distinct bigint;
  ev_total bigint; ev_distinct bigint;
BEGIN
  SELECT count(*), count(DISTINCT element_ids) FROM zkapp_field_array INTO fa_total, fa_distinct;
  SELECT count(*), count(DISTINCT element_ids) FROM zkapp_events       INTO ev_total, ev_distinct;
  RAISE NOTICE 'BEFORE  zkapp_field_array: % rows, % distinct (% duplicate rows)',
    fa_total, fa_distinct, fa_total - fa_distinct;
  RAISE NOTICE 'BEFORE  zkapp_events:      % rows, % distinct (% duplicate rows)',
    ev_total, ev_distinct, ev_total - ev_distinct;
END $$;

-- ===========================================================================
-- Stage 1: zkapp_field_array
-- ===========================================================================

-- dup_id -> canonical (smallest) id, only for non-canonical rows.
CREATE TEMP TABLE fa_remap ON COMMIT DROP AS
SELECT id AS dup_id, canon_id
FROM (
  SELECT id, min(id) OVER (PARTITION BY element_ids) AS canon_id
  FROM zkapp_field_array
) s
WHERE id <> canon_id;
CREATE INDEX fa_remap_dup_idx ON fa_remap (dup_id);

-- Rewrite the field_array ids embedded in zkapp_events.element_ids, preserving
-- array order, only for events that actually reference a duplicate.
WITH affected AS (
  SELECT e.id,
         array_agg(COALESCE(r.canon_id, u.elem) ORDER BY u.ord) AS new_ids
  FROM zkapp_events e
  CROSS JOIN LATERAL unnest(e.element_ids) WITH ORDINALITY AS u(elem, ord)
  LEFT JOIN fa_remap r ON r.dup_id = u.elem
  WHERE e.id IN (
    SELECT DISTINCT e2.id
    FROM zkapp_events e2
    CROSS JOIN LATERAL unnest(e2.element_ids) AS x(elem)
    JOIN fa_remap r2 ON r2.dup_id = x.elem
  )
  GROUP BY e.id
)
UPDATE zkapp_events e
SET element_ids = a.new_ids
FROM affected a
WHERE e.id = a.id;

DELETE FROM zkapp_field_array fa
USING fa_remap r
WHERE fa.id = r.dup_id;

-- ===========================================================================
-- Stage 2: zkapp_events  (AFTER field_array remap, which may create new dups)
-- ===========================================================================

CREATE TEMP TABLE ev_remap ON COMMIT DROP AS
SELECT id AS dup_id, canon_id
FROM (
  SELECT id, min(id) OVER (PARTITION BY element_ids) AS canon_id
  FROM zkapp_events
) s
WHERE id <> canon_id;
CREATE INDEX ev_remap_dup_idx ON ev_remap (dup_id);

UPDATE zkapp_account_update_body b
SET events_id = r.canon_id
FROM ev_remap r
WHERE b.events_id = r.dup_id;

UPDATE zkapp_account_update_body b
SET actions_id = r.canon_id
FROM ev_remap r
WHERE b.actions_id = r.dup_id;

DELETE FROM zkapp_events e
USING ev_remap r
WHERE e.id = r.dup_id;

-- ===========================================================================
-- Verification: report results and HARD-FAIL (rollback) on any problem.
-- ===========================================================================
DO $$
DECLARE
  fa_removed  bigint; ev_removed  bigint;
  fa_total    bigint; fa_distinct bigint;
  ev_total    bigint; ev_distinct bigint;
  dangling_events       bigint;
  dangling_field_arrays bigint;
BEGIN
  SELECT count(*) FROM fa_remap INTO fa_removed;
  SELECT count(*) FROM ev_remap INTO ev_removed;
  SELECT count(*), count(DISTINCT element_ids) FROM zkapp_field_array INTO fa_total, fa_distinct;
  SELECT count(*), count(DISTINCT element_ids) FROM zkapp_events       INTO ev_total, ev_distinct;

  -- (1) every account_update_body still points at a live event row
  SELECT count(*) FROM zkapp_account_update_body b
   WHERE NOT EXISTS (SELECT 1 FROM zkapp_events e WHERE e.id = b.events_id)
      OR NOT EXISTS (SELECT 1 FROM zkapp_events e WHERE e.id = b.actions_id)
   INTO dangling_events;

  -- (2) every field_array id inside an event's element_ids still resolves
  SELECT count(*) FROM zkapp_events e
   CROSS JOIN LATERAL unnest(e.element_ids) AS x(elem)
   WHERE NOT EXISTS (SELECT 1 FROM zkapp_field_array fa WHERE fa.id = x.elem)
   INTO dangling_field_arrays;

  RAISE NOTICE 'AFTER   zkapp_field_array: % rows, % distinct  (removed % duplicate rows)',
    fa_total, fa_distinct, fa_removed;
  RAISE NOTICE 'AFTER   zkapp_events:      % rows, % distinct  (removed % duplicate rows)',
    ev_total, ev_distinct, ev_removed;
  RAISE NOTICE 'CHECK   dangling event refs: %   dangling field_array refs: %  (both must be 0)',
    dangling_events, dangling_field_arrays;

  IF dangling_events <> 0 OR dangling_field_arrays <> 0 THEN
    RAISE EXCEPTION 'INTEGRITY CHECK FAILED: % dangling event refs, % dangling field_array refs -- rolling back',
      dangling_events, dangling_field_arrays;
  END IF;
  IF fa_total <> fa_distinct OR ev_total <> ev_distinct THEN
    RAISE EXCEPTION 'DEDUP INCOMPLETE: duplicate arrays still present (fa %/%, ev %/%) -- rolling back',
      fa_total, fa_distinct, ev_total, ev_distinct;
  END IF;

  RAISE NOTICE 'All integrity checks passed.';
END $$;

-- ---------------------------------------------------------------------------
-- Commit only on APPLY; otherwise roll the whole thing back.
-- ---------------------------------------------------------------------------
\if :apply
  COMMIT;
  \echo '>>> APPLIED: dedup committed.'
\else
  ROLLBACK;
  \echo '>>> DRY RUN complete: rolled back, no changes made. Re-run with -v apply=true to apply.'
\endif
