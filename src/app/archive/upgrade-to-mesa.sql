-- =============================================================================
-- Mina migration: from berkeley to mesa
-- + extend zkapp_states_nullable with element8..element31 (int)
-- + add FKs to zkapp_field(id), validate one-by-one
-- + record status in public.schema_version
-- =============================================================================

-- Version number for this migration
DO $mig$
DECLARE
    migration_version text := '4.0.0';
BEGIN
    PERFORM 1;  -- no-op; just a block anchor
END
$mig$;
-- We'll use this constant in the script:
--   3.2.0 = version 3.2.0
-- If you copy this pattern, bump the version.
-- ============================================================================

-- Keep locks short; abort instead of blocking production traffic.
SET lock_timeout = '10s';
SET statement_timeout = '10min';

-- --- 0) Ensure version table exists & has desired columns --------------------
CREATE TABLE IF NOT EXISTS public.schema_version (
    version      text PRIMARY KEY,
    description  text,
    applied_at   timestamptz NOT NULL DEFAULT now()
);

-- Add optional columns if missing (idempotent upgrades)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
         WHERE table_schema='public' AND table_name='schema_version'
             AND column_name='status'
    ) THEN
        ALTER TABLE public.schema_version
            ADD COLUMN status text;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
         WHERE table_schema='public' AND table_name='schema_version'
             AND column_name='validated_at'
    ) THEN
        ALTER TABLE public.schema_version
            ADD COLUMN validated_at timestamptz;
    END IF;
END$$;

-- Upsert a row for this migration version
DO $$
DECLARE v text := '3.2.0';
BEGIN
    IF NOT EXISTS (SELECT 1 FROM public.schema_version WHERE version = v) THEN
        INSERT INTO public.schema_version(version, description, status)
        VALUES (v,
                        'Add zkapp_states_nullable.element8..element31 (int) + FKs to zkapp_field(id)',
                        'starting');
    ELSE
        -- keep description but note re-run
        UPDATE public.schema_version
             SET status = COALESCE(status,'starting')
         WHERE version = v;
    END IF;
END$$;

-- --- 1) Add nullable columns element8..element31 (idempotent) ---------------
DO $$
DECLARE
    missing_col_record RECORD;
    added_count int := 0;
BEGIN
    RAISE NOTICE 'DEBUG: Starting column addition process...';
    
    -- Find missing columns in range 8-31
    FOR missing_col_record IN
        SELECT 'element' || g.n as col_name, g.n as col_num
        FROM generate_series(8, 31) g(n)
        LEFT JOIN information_schema.columns c
            ON c.table_schema = 'public'
           AND c.table_name = 'zkapp_states_nullable'
           AND c.column_name = 'element' || g.n
        WHERE c.column_name IS NULL
        ORDER BY g.n
    LOOP
        RAISE NOTICE 'DEBUG: Adding missing column %...', missing_col_record.col_name;
        EXECUTE format(
            'ALTER TABLE public.zkapp_states_nullable ADD COLUMN %I integer',
            missing_col_record.col_name
        );
        added_count := added_count + 1;
    END LOOP;
    
    RAISE NOTICE 'DEBUG: Column addition completed. Added: % columns', added_count;
END$$;

-- --- 2) Add NOT VALID foreign keys (idempotent) -----------------------------
DO $$
DECLARE
    missing_fk_record RECORD;
    added_count int := 0;
BEGIN
    RAISE NOTICE 'DEBUG: Starting FK addition process...';
    
    -- Find missing FK constraints for columns in range 8-31
    FOR missing_fk_record IN
        SELECT 'zkapp_states_nullable_element' || g.n || '_fk' as fk_name,
               'element' || g.n as col_name,
               g.n as col_num
        FROM generate_series(8, 31) g(n)
        LEFT JOIN pg_constraint c
            ON c.conname = 'zkapp_states_nullable_element' || g.n || '_fk'
           AND c.conrelid = 'public.zkapp_states_nullable'::regclass
        WHERE c.conname IS NULL
        ORDER BY g.n
    LOOP
        RAISE NOTICE 'DEBUG: Adding missing FK constraint %...', missing_fk_record.fk_name;
        EXECUTE format(
            'ALTER TABLE public.zkapp_states_nullable
                 ADD CONSTRAINT %I
                 FOREIGN KEY (%I) REFERENCES public.zkapp_field(id)
                 NOT VALID',
            missing_fk_record.fk_name, missing_fk_record.col_name
        );
        added_count := added_count + 1;
    END LOOP;
    
    RAISE NOTICE 'DEBUG: FK addition completed. Added: % constraints', added_count;
END$$;

-- --- 3) Validate FKs one-by-one (short locks; skip on timeout) --------------
DO $$
DECLARE
    invalid_fk_record RECORD;
    validated_now int := 0;
    skipped_now int := 0;
BEGIN
    RAISE NOTICE 'DEBUG: Starting FK validation process...';
    
    -- Find invalid FK constraints for elements 8-31
    FOR invalid_fk_record IN
        SELECT c.conname
        FROM pg_constraint c
        WHERE c.conrelid = 'public.zkapp_states_nullable'::regclass
          AND c.contype = 'f'
          AND c.conname LIKE 'zkapp_states_nullable_element%_fk'
          AND substring(c.conname FROM 'element(\d+)_fk')::int BETWEEN 8 AND 31
          AND NOT c.convalidated
        ORDER BY c.conname
    LOOP
        RAISE NOTICE 'DEBUG: Validating constraint %...', invalid_fk_record.conname;
        BEGIN
            EXECUTE format(
                'ALTER TABLE public.zkapp_states_nullable VALIDATE CONSTRAINT %I',
                invalid_fk_record.conname
            );
            validated_now := validated_now + 1;
            RAISE NOTICE 'DEBUG: Successfully validated %', invalid_fk_record.conname;
        EXCEPTION
            WHEN lock_not_available THEN
                RAISE NOTICE 'DEBUG: Skipped validation of % due to lock timeout; will try next run.', invalid_fk_record.conname;
                skipped_now := skipped_now + 1;
        END;
    END LOOP;

    RAISE NOTICE 'DEBUG: FK validation completed. Validated: %, Skipped: %', validated_now, skipped_now;
END$$;

-- --- 4) Post-checks & version status update --------------------------------
DO $$
DECLARE
    v text := '3.2.0';
    missing_cols int;
    total_fks    int;
    valid_fks    int;
    all_valid    boolean;
BEGIN
    -- all columns present?
    SELECT count(*)
        INTO missing_cols
        FROM generate_series(8,31) g(n)
        LEFT JOIN information_schema.columns c
                     ON c.table_schema='public'
                    AND c.table_name='zkapp_states_nullable'
                    AND c.column_name='element'||g.n
     WHERE c.column_name IS NULL;

    IF missing_cols > 0 THEN
        RAISE EXCEPTION 'Post-check failed: % columns missing in zkapp_states_nullable.', missing_cols;
    END IF;

    -- FK counts
    SELECT count(*)
        INTO total_fks
        FROM pg_constraint c
     WHERE c.conrelid='public.zkapp_states_nullable'::regclass
         AND c.contype='f'
         AND c.conname LIKE 'zkapp_states_nullable_element%_fk'
         AND substring(c.conname FROM 'element(\d+)_fk')::int BETWEEN 8 AND 31;

    SELECT count(*)
        INTO valid_fks
        FROM pg_constraint c
     WHERE c.conrelid='public.zkapp_states_nullable'::regclass
         AND c.contype='f'
         AND c.convalidated
         AND c.conname LIKE 'zkapp_states_nullable_element%_fk'
         AND substring(c.conname FROM 'element(\d+)_fk')::int BETWEEN 8 AND 31;

    all_valid := (valid_fks = 24);  -- 8..31 inclusive = 24 constraints

    IF total_fks <> 24 THEN
        RAISE NOTICE 'Expected 24 FKs, found % (validated %).', total_fks, valid_fks;
    ELSE
        RAISE NOTICE 'FKs present: %, validated: %.', total_fks, valid_fks;
    END IF;

    UPDATE public.schema_version
         SET status = CASE WHEN all_valid THEN 'applied_validated' ELSE 'applied_pending_validation' END,
                 validated_at = CASE WHEN all_valid THEN now() ELSE validated_at END
     WHERE version = v;
END$$;

-- =============================================================================
-- Re-run this script any time; it will:
--  * create any missing columns/FKs
--  * attempt to validate remaining NOT VALID FKs (skipping if it can't get a lock)
--  * update version status to 'applied_validated' once all are validated
-- =============================================================================
