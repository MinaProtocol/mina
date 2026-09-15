-- =============================================================================
-- Add the user_commands account-lookup indexes to a LIVE archive database
-- + idx_user_commands_fee_payer_id, idx_user_commands_source_id,
--   idx_user_commands_receiver_id (also in create_schema.sql / upgrade_to_mesa.sql)
--
-- For archives that are already on the Mesa schema and serving traffic.
-- Everything here runs CONCURRENTLY, so reads and archive inserts are not
-- blocked. On mainnet each index is ~74 MB and builds in about 10 seconds.
--
-- Usage: psql -f add_user_commands_account_indexes.sql <archive-uri>
-- Must NOT be run inside a transaction (CONCURRENTLY is not allowed there).
-- Idempotent: re-running is a no-op once the indexes are valid.
-- =============================================================================

\set ON_ERROR_STOP on
-- Concurrent builds wait for transactions already running (e.g. long Rosetta
-- reads) rather than locking them out, so do not cap lock waits; bound each
-- statement instead.
SET lock_timeout = 0;
SET statement_timeout = '30min';

-- An interrupted build (cancelled, timed out, server restart) leaves an INVALID
-- index behind, which IF NOT EXISTS would then silently keep. Drop leftovers
-- first; \gexec runs each generated DROP as its own top-level statement.
SELECT format('DROP INDEX CONCURRENTLY IF EXISTS public.%I', c.relname)
FROM pg_index i
JOIN pg_class c ON c.oid = i.indexrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relname IN ('idx_user_commands_fee_payer_id',
                    'idx_user_commands_source_id',
                    'idx_user_commands_receiver_id')
  AND NOT i.indisvalid
\gexec

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_user_commands_fee_payer_id ON user_commands(fee_payer_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_user_commands_source_id    ON user_commands(source_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_user_commands_receiver_id  ON user_commands(receiver_id);

-- Fail loudly if any of them did not end up valid.
DO $$
DECLARE
    missing text;
BEGIN
    SELECT string_agg(name, ', ') INTO missing
    FROM unnest(ARRAY[
        'idx_user_commands_fee_payer_id',
        'idx_user_commands_source_id',
        'idx_user_commands_receiver_id'
    ]) AS name
    WHERE NOT EXISTS (
        SELECT 1
        FROM pg_index i
        JOIN pg_class c ON c.oid = i.indexrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'public' AND c.relname = name AND i.indisvalid
    );
    IF missing IS NOT NULL THEN
        RAISE EXCEPTION 'indexes missing or invalid after build: %', missing;
    END IF;
    RAISE NOTICE 'user_commands account indexes present and valid';
END $$;
