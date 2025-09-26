-- ============================================================================
-- Mina rollback: remove zkapp_states_nullable.element8..element31 + FKs
-- Idempotent, online-safe, and updates schema_version.status -> 'rolled_back'
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

-- Ensure a row for this version exists (so we can mark rolled_back)
DO $$
DECLARE v text := '3.2.0';
BEGIN
    IF NOT EXISTS (SELECT 1 FROM public.schema_version WHERE version = v) THEN
        INSERT INTO public.schema_version(version, description, status)
        VALUES (v, 'Rollback placeholder for elements 8..31 + FKs', 'starting');
    END IF;
END$$;

-- --- 1) Pre-check: will rollback drop data? ---------------------------------
-- By default we abort if any new columns contain data.
-- To force a destructive rollback, run in this session first:
--   SET mina.allow_destructive_rollback = on;
DO $$
DECLARE
    non_null_rows bigint;
    allow_rollback boolean := lower(coalesce(current_setting('mina.allow_destructive_rollback', true),'off')) IN ('on','true','1');
BEGIN
    SELECT count(*) INTO non_null_rows
    FROM public.zkapp_states_nullable
    WHERE
        element8  IS NOT NULL OR element9  IS NOT NULL OR element10 IS NOT NULL OR element11 IS NOT NULL OR
        element12 IS NOT NULL OR element13 IS NOT NULL OR element14 IS NOT NULL OR element15 IS NOT NULL OR
        element16 IS NOT NULL OR element17 IS NOT NULL OR element18 IS NOT NULL OR element19 IS NOT NULL OR
        element20 IS NOT NULL OR element21 IS NOT NULL OR element22 IS NOT NULL OR element23 IS NOT NULL OR
        element24 IS NOT NULL OR element25 IS NOT NULL OR element26 IS NOT NULL OR element27 IS NOT NULL OR
        element28 IS NOT NULL OR element29 IS NOT NULL OR element30 IS NOT NULL OR element31 IS NOT NULL;

    IF non_null_rows > 0 AND NOT allow_rollback THEN
        RAISE EXCEPTION
            'Rollback would drop data: % row(s) have non-NULL in element8..element31. Set mina.allow_destructive_rollback=on to force.',
            non_null_rows
            USING HINT = 'Run: SET mina.allow_destructive_rollback = on; then re-run.';
    ELSE
        RAISE NOTICE 'Rollback pre-check: % non-NULL row(s) across element8..element31. Proceeding (forced=%).',
                                 non_null_rows, allow_rollback;
    END IF;
END$$;

-- --- 2) Drop FKs (reverse order), if present --------------------------------
DO $$
DECLARE
    fk_record RECORD;
    drop_count int := 0;
    error_count int := 0;
BEGIN
    RAISE NOTICE 'DEBUG: Starting FK removal process...';
    
    -- Get all FK constraints for elements 8-31 in reverse order
    FOR fk_record IN
        SELECT conname
        FROM pg_constraint
        WHERE conrelid = 'public.zkapp_states_nullable'::regclass
          AND contype = 'f'
          AND conname LIKE 'zkapp_states_nullable_element%_fk'
          AND substring(conname FROM 'element(\d+)_fk')::int BETWEEN 8 AND 31
        ORDER BY conname DESC
    LOOP
        RAISE NOTICE 'DEBUG: Found FK constraint %, attempting to drop...', fk_record.conname;
        BEGIN
            EXECUTE format('ALTER TABLE public.zkapp_states_nullable DROP CONSTRAINT %I', fk_record.conname);
            RAISE NOTICE 'DEBUG: Successfully dropped constraint %', fk_record.conname;
            drop_count := drop_count + 1;
        EXCEPTION
            WHEN lock_not_available THEN
                RAISE NOTICE 'DEBUG: Could not drop %, lock timeout; will remain for now. Re-run later.', fk_record.conname;
                error_count := error_count + 1;
            WHEN OTHERS THEN
                RAISE NOTICE 'DEBUG: Error dropping constraint %: % %', fk_record.conname, SQLSTATE, SQLERRM;
                error_count := error_count + 1;
        END;
    END LOOP;
    
    RAISE NOTICE 'DEBUG: FK removal process completed. Dropped: %, Errors: %', drop_count, error_count;
END$$;

-- --- 3) Drop columns (reverse order), if present ----------------------------
DO $$
DECLARE
    col_record RECORD;
    drop_count int := 0;
    error_count int := 0;
BEGIN
    RAISE NOTICE 'DEBUG: Starting column removal process...';
    
    -- Get all columns for elements 8-31 in reverse order  
    FOR col_record IN
        SELECT column_name
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'zkapp_states_nullable'
          AND column_name LIKE 'element%'
          AND substring(column_name FROM 'element(\d+)')::int BETWEEN 8 AND 31
        ORDER BY column_name DESC
    LOOP
        RAISE NOTICE 'DEBUG: Found column %, attempting to drop...', col_record.column_name;
        BEGIN
            EXECUTE format('ALTER TABLE public.zkapp_states_nullable DROP COLUMN %I', col_record.column_name);
            RAISE NOTICE 'DEBUG: Successfully dropped column %', col_record.column_name;
            drop_count := drop_count + 1;
        EXCEPTION
            WHEN lock_not_available THEN
                RAISE NOTICE 'DEBUG: Could not drop %, lock timeout; re-run later.', col_record.column_name;
                error_count := error_count + 1;
            WHEN OTHERS THEN
                RAISE NOTICE 'DEBUG: Error dropping column %: % %', col_record.column_name, SQLSTATE, SQLERRM;
                error_count := error_count + 1;
        END;
    END LOOP;
    
    RAISE NOTICE 'DEBUG: Column removal process completed. Dropped: %, Errors: %', drop_count, error_count;
END$$;

-- --- 4) Post-check & version table update -----------------------------------
DO $$
DECLARE
    v text := '3.2.0';
    remaining_cols int;
    remaining_fks  int;
    nowtxt text := to_char(now(),'YYYY-MM-DD HH24:MI:SS TZ');
    col_list text := '';
    fk_list text := '';
    rec record;
BEGIN
    RAISE NOTICE 'DEBUG: Starting post-check analysis...';
    
    SELECT count(*)
        INTO remaining_cols
        FROM generate_series(8,31) g(n)
        JOIN information_schema.columns c
            ON c.table_schema='public'
         AND c.table_name='zkapp_states_nullable'
         AND c.column_name='element'||g.n;

    SELECT count(*)
        INTO remaining_fks
        FROM pg_constraint c
     WHERE c.conrelid='public.zkapp_states_nullable'::regclass
         AND c.contype='f'
         AND c.conname LIKE 'zkapp_states_nullable_element%_fk'
         AND substring(c.conname FROM 'element(\d+)_fk')::int BETWEEN 8 AND 31;

    RAISE NOTICE 'DEBUG: Found % remaining columns and % remaining FKs', remaining_cols, remaining_fks;

    -- List remaining columns
    IF remaining_cols > 0 THEN
        FOR rec IN 
            SELECT 'element'||g.n as col_name
            FROM generate_series(8,31) g(n)
            JOIN information_schema.columns c
                ON c.table_schema='public'
             AND c.table_name='zkapp_states_nullable'
             AND c.column_name='element'||g.n
            ORDER BY g.n
        LOOP
            col_list := col_list || rec.col_name || ', ';
        END LOOP;
        col_list := rtrim(col_list, ', ');
        RAISE NOTICE 'DEBUG: Remaining columns: %', col_list;
    END IF;

    -- List remaining FKs
    IF remaining_fks > 0 THEN
        FOR rec IN 
            SELECT c.conname as fk_name
            FROM pg_constraint c
            WHERE c.conrelid='public.zkapp_states_nullable'::regclass
              AND c.contype='f'
              AND c.conname LIKE 'zkapp_states_nullable_element%_fk'
              AND substring(c.conname FROM 'element(\d+)_fk')::int BETWEEN 8 AND 31
            ORDER BY c.conname
        LOOP
            fk_list := fk_list || rec.fk_name || ', ';
        END LOOP;
        fk_list := rtrim(fk_list, ', ');
        RAISE NOTICE 'DEBUG: Remaining FKs: %', fk_list;
    END IF;

    IF remaining_cols = 0 AND remaining_fks = 0 THEN
        UPDATE public.schema_version
             SET status = 'rolled_back',
                     description = CASE
                         WHEN position('ROLLED BACK' in coalesce(description,'')) > 0
                             THEN description
                         ELSE coalesce(description,'') || ' [ROLLED BACK ' || nowtxt || ']'
                     END,
                     validated_at = NULL
         WHERE version = v;
        RAISE NOTICE 'DEBUG: Rollback complete: all target columns and FKs removed. Version marked rolled_back.';
    ELSE
        UPDATE public.schema_version
             SET status = 'rollback_partial',
                     description = CASE
                         WHEN position('ROLLBACK PARTIAL' in coalesce(description,'')) > 0
                             THEN description
                         ELSE coalesce(description,'') || ' [ROLLBACK PARTIAL ' || nowtxt || ']'
                     END
         WHERE version = v;
        RAISE NOTICE 'DEBUG: Rollback partial: % column(s) and % FK(s) remain. Re-run to finish.',
                                 remaining_cols, remaining_fks;
    END IF;
END$$;
