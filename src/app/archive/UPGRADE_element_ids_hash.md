# Archive upgrade: `element_ids` content-hash index (from the band-aid build)

For archive node operators currently running the **band-aid** build — the
insert-only one that dropped the `element_ids` `UNIQUE` constraints on
`zkapp_events` / `zkapp_field_array` to stop the btree-key overflow. Under that
build, identical arrays accumulate as **duplicate rows** (storage bloat,
dominated by the empty `{}` array).

This upgrade moves you to the proper fix: a fixed-width **sha256 content-hash**
`UNIQUE` index that restores deduplication and indexed lookup **without** the
overflow, and removes the accumulated duplicates in the same step.

## Read this first — binary and schema move together

The new binary inserts via the hash index (`ON CONFLICT
(zkapp_element_ids_hash(element_ids))` and SELECT-by-hash). **It will not work
against a DB that hasn't been migrated** — those inserts fail with *"no unique or
exclusion constraint matching the ON CONFLICT specification"*. So: migrate the
DB **first**, with the node **stopped**, then deploy the binary.

## Procedure

1. **Back up the DB:**
   ```
   pg_dump "<conn>" > archive_backup.sql
   ```

2. **(Recommended) Preview the duplicate volume** — dry run, changes nothing,
   reports BEFORE/AFTER counts so you can size the maintenance window:
   ```
   psql "<conn>" -f dedup_zkapp_element_ids.sql
   ```

3. **Stop the archive node** (do not migrate while it is writing).

4. **Migrate the schema** — idempotent; dedups existing rows, creates the
   `zkapp_element_ids_hash` function, and adds the hash `UNIQUE` indexes:
   ```
   psql "<conn>" -f upgrade_to_mesa.sql
   ```
   (On a band-aided DB the old-constraint drops are no-ops; the new step 3b does
   the dedup + hash index.)

5. **Deploy the new archive binary** (`mina-archive`, `mina-archive-blocks`)
   built from the content-hash fix.

6. **Restart the archive node.**

## Timing / downtime

The migration holds an **exclusive lock** while it deduplicates and builds the
`UNIQUE` index (non-concurrent). On a large bloated DB — a max-cost-zkApp archive
can reach millions of `zkapp_field_array` rows — this can take **several
minutes**. **Test the full migration on a restored dump first** to size your
window. The dry run in step 2 tells you how many duplicate rows will be removed.

## Verify after migrating

All three must hold:
```sql
-- 1. no duplicate arrays remain (total == distinct)
SELECT count(*) AS total, count(DISTINCT element_ids) AS distinct_arrays FROM zkapp_events;
SELECT count(*) AS total, count(DISTINCT element_ids) AS distinct_arrays FROM zkapp_field_array;

-- 2. both hash indexes exist
SELECT indexname FROM pg_indexes
 WHERE indexname IN ('zkapp_events_element_ids_hash_key',
                     'zkapp_field_array_element_ids_hash_key');

-- 3. a known max-cost block re-ingests cleanly with the new binary (no overflow,
--    no duplicate rows added on re-insert).
```
