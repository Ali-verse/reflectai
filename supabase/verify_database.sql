-- =============================================================================
-- ReflectAI — Database Setup Catalog Verification Script
-- Target Supabase Project: yfubwuwhlkicnbvjgbjg
-- Purely read-only inspection queries against PostgreSQL system catalogs
-- =============================================================================

WITH expected_tables(tablename) AS (
  VALUES
    ('profiles'),
    ('journal_entries'),
    ('mood_logs'),
    ('habits'),
    ('habit_logs'),
    ('goals'),
    ('coach_messages')
),

expected_columns(table_name, column_name, data_type, is_nullable) AS (
  VALUES
    ('profiles', 'id', 'uuid', 'NO'),
    ('profiles', 'display_name', 'text', 'YES'),
    ('profiles', 'avatar_url', 'text', 'YES'),
    ('profiles', 'created_at', 'timestamp with time zone', 'NO'),
    ('profiles', 'updated_at', 'timestamp with time zone', 'NO'),

    ('journal_entries', 'id', 'uuid', 'NO'),
    ('journal_entries', 'user_id', 'uuid', 'NO'),
    ('journal_entries', 'title', 'text', 'NO'),
    ('journal_entries', 'content', 'text', 'NO'),
    ('journal_entries', 'mood', 'text', 'YES'),
    ('journal_entries', 'tags', 'ARRAY', 'NO'),
    ('journal_entries', 'pinned', 'boolean', 'NO'),
    ('journal_entries', 'favorite', 'boolean', 'NO'),
    ('journal_entries', 'entry_date', 'timestamp with time zone', 'NO'),
    ('journal_entries', 'created_at', 'timestamp with time zone', 'NO'),
    ('journal_entries', 'updated_at', 'timestamp with time zone', 'NO'),

    ('mood_logs', 'id', 'uuid', 'NO'),
    ('mood_logs', 'user_id', 'uuid', 'NO'),
    ('mood_logs', 'mood', 'text', 'NO'),
    ('mood_logs', 'note', 'text', 'YES'),
    ('mood_logs', 'logged_at', 'timestamp with time zone', 'NO'),

    ('habits', 'id', 'uuid', 'NO'),
    ('habits', 'user_id', 'uuid', 'NO'),
    ('habits', 'name', 'text', 'NO'),
    ('habits', 'emoji', 'text', 'NO'),
    ('habits', 'color', 'text', 'NO'),
    ('habits', 'target_per_week', 'integer', 'NO'),
    ('habits', 'archived', 'boolean', 'NO'),
    ('habits', 'created_at', 'timestamp with time zone', 'NO'),

    ('habit_logs', 'id', 'uuid', 'NO'),
    ('habit_logs', 'user_id', 'uuid', 'NO'),
    ('habit_logs', 'habit_id', 'uuid', 'NO'),
    ('habit_logs', 'log_date', 'date', 'NO'),
    ('habit_logs', 'created_at', 'timestamp with time zone', 'NO'),

    ('goals', 'id', 'uuid', 'NO'),
    ('goals', 'user_id', 'uuid', 'NO'),
    ('goals', 'title', 'text', 'NO'),
    ('goals', 'description', 'text', 'NO'),
    ('goals', 'category', 'text', 'NO'),
    ('goals', 'progress', 'integer', 'NO'),
    ('goals', 'target_date', 'date', 'YES'),
    ('goals', 'created_at', 'timestamp with time zone', 'NO'),
    ('goals', 'updated_at', 'timestamp with time zone', 'NO'),

    ('coach_messages', 'id', 'uuid', 'NO'),
    ('coach_messages', 'user_id', 'uuid', 'NO'),
    ('coach_messages', 'role', 'text', 'NO'),
    ('coach_messages', 'content', 'text', 'NO'),
    ('coach_messages', 'created_at', 'timestamp with time zone', 'NO')
),

raw_checks AS (
  -- 1. Table existence checks (7 expected tables)
  SELECT
    'TABLES' AS category,
    'table_exists_' || tablename AS check_name,
    CASE WHEN EXISTS (
      SELECT 1 FROM information_schema.tables
      WHERE table_schema = 'public' AND table_name = tablename
    ) THEN 'PASS' ELSE 'FAIL' END AS status,
    'Table public.' || tablename || ' existence check' AS details
  FROM expected_tables

  UNION ALL

  -- 2. Unexpected tables check in public schema (Design Baseline Assumption)
  SELECT
    'ARCHITECTURE_BASELINE' AS category,
    'no_unexpected_public_tables' AS check_name,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'WARNING' END AS status,
    CASE
      WHEN COUNT(*) = 0 THEN 'No extraneous base tables in public schema'
      ELSE 'Design baseline warning: extraneous tables found in public schema: ' || COALESCE(string_agg(t.table_name::text, ', '), 'None')
    END AS details
  FROM information_schema.tables t
  WHERE t.table_schema = 'public'
    AND t.table_type = 'BASE TABLE'
    AND t.table_name NOT IN (SELECT tablename FROM expected_tables)

  UNION ALL

  -- 3. Column type, nullability, and UDT checks (48 columns)
  SELECT
    'COLUMNS' AS category,
    ec.table_name || '.' || ec.column_name AS check_name,
    CASE WHEN c.column_name IS NOT NULL
      AND (c.data_type = ec.data_type)
      AND (c.is_nullable = ec.is_nullable)
      AND (ec.data_type <> 'ARRAY' OR c.udt_name = '_text')
    THEN 'PASS' ELSE 'FAIL' END AS status,
    'Expected ' || ec.table_name || '.' || ec.column_name || ' (' || ec.data_type || ', nullable=' || ec.is_nullable || ') - Found: (' || COALESCE(c.data_type, 'MISSING') || ', nullable=' || COALESCE(c.is_nullable, 'N/A') || ')' AS details
  FROM expected_columns ec
  LEFT JOIN information_schema.columns c
    ON c.table_schema = 'public'
   AND c.table_name = ec.table_name
   AND c.column_name = ec.column_name

  UNION ALL

  -- 4. Primary Key Checks
  SELECT
    'PRIMARY_KEYS' AS category,
    'pk_' || tablename AS check_name,
    CASE
      WHEN to_regclass('public.' || tablename) IS NULL THEN 'FAIL'
      WHEN EXISTS (
        SELECT 1 FROM pg_constraint con
        JOIN pg_class rel ON rel.oid = con.conrelid
        JOIN pg_namespace nsp ON nsp.oid = rel.relnamespace
        WHERE nsp.nspname = 'public'
          AND rel.relname = tablename
          AND con.contype = 'p'
      ) THEN 'PASS'
      ELSE 'FAIL'
    END AS status,
    CASE
      WHEN to_regclass('public.' || tablename) IS NULL THEN 'Table public.' || tablename || ' does not exist'
      WHEN EXISTS (
        SELECT 1 FROM pg_constraint con
        JOIN pg_class rel ON rel.oid = con.conrelid
        JOIN pg_namespace nsp ON nsp.oid = rel.relnamespace
        WHERE nsp.nspname = 'public'
          AND rel.relname = tablename
          AND con.contype = 'p'
      ) THEN 'Primary key defined on public.' || tablename
      ELSE 'Missing primary key on public.' || tablename
    END AS details
  FROM expected_tables

  UNION ALL

  -- 5. Supporting Unique Constraint on habits(id, user_id)
  SELECT
    'CONSTRAINTS' AS category,
    'unique_habits_id_user_id' AS check_name,
    CASE
      WHEN to_regclass('public.habits') IS NULL THEN 'FAIL'
      WHEN EXISTS (
        SELECT 1 FROM pg_constraint con
        JOIN pg_class rel ON rel.oid = con.conrelid
        JOIN pg_namespace nsp ON nsp.oid = rel.relnamespace
        WHERE nsp.nspname = 'public'
          AND rel.relname = 'habits'
          AND con.contype = 'u'
          AND (
            SELECT array_agg(att.attname ORDER BY u.ord)
            FROM unnest(con.conkey) WITH ORDINALITY AS u(attnum, ord)
            JOIN pg_attribute att ON att.attrelid = con.conrelid AND att.attnum = u.attnum
          ) = ARRAY['id', 'user_id']::name[]
      ) THEN 'PASS'
      ELSE 'FAIL'
    END AS status,
    CASE
      WHEN to_regclass('public.habits') IS NULL THEN 'Table public.habits does not exist'
      ELSE 'habits(id, user_id) unique constraint check'
    END AS details

  UNION ALL

  -- 6. Unique Constraint on habit_logs(habit_id, log_date)
  SELECT
    'CONSTRAINTS' AS category,
    'unique_habit_logs_habit_id_log_date' AS check_name,
    CASE
      WHEN to_regclass('public.habit_logs') IS NULL THEN 'FAIL'
      WHEN EXISTS (
        SELECT 1 FROM pg_constraint con
        JOIN pg_class rel ON rel.oid = con.conrelid
        JOIN pg_namespace nsp ON nsp.oid = rel.relnamespace
        WHERE nsp.nspname = 'public'
          AND rel.relname = 'habit_logs'
          AND con.contype = 'u'
          AND (
            SELECT array_agg(att.attname ORDER BY u.ord)
            FROM unnest(con.conkey) WITH ORDINALITY AS u(attnum, ord)
            JOIN pg_attribute att ON att.attrelid = con.conrelid AND att.attnum = u.attnum
          ) = ARRAY['habit_id', 'log_date']::name[]
      ) THEN 'PASS'
      ELSE 'FAIL'
    END AS status,
    CASE
      WHEN to_regclass('public.habit_logs') IS NULL THEN 'Table public.habit_logs does not exist'
      ELSE 'habit_logs(habit_id, log_date) unique constraint check'
    END AS details

  UNION ALL

  -- 7. Check Constraint on coach_messages(role IN ('user','assistant','system'))
  SELECT
    'CONSTRAINTS' AS category,
    'check_coach_messages_role' AS check_name,
    CASE
      WHEN to_regclass('public.coach_messages') IS NULL THEN 'FAIL'
      WHEN EXISTS (
        SELECT 1 FROM pg_constraint con
        JOIN pg_class rel ON rel.oid = con.conrelid
        JOIN pg_namespace nsp ON nsp.oid = rel.relnamespace
        WHERE nsp.nspname = 'public'
          AND rel.relname = 'coach_messages'
          AND con.contype = 'c'
          AND lower(
            regexp_replace(
              regexp_replace(pg_get_constraintdef(con.oid), '::[a-zA-Z0-9_]+', '', 'g'),
              '[\s\(\)"''\[\]]',
              '',
              'g'
            )
          ) IN (
            'checkrole=anyarrayuser,assistant,system',
            'checkrole=anyarray[user,assistant,system]',
            'checkroleinuser,assistant,system',
            'checkrole=userorrole=assistantorrole=system'
          )
      ) THEN 'PASS'
      ELSE 'FAIL'
    END AS status,
    CASE
      WHEN to_regclass('public.coach_messages') IS NULL THEN 'Table public.coach_messages does not exist'
      ELSE 'coach_messages role check constraint (role IN (''user'', ''assistant'', ''system''))'
    END AS details

  UNION ALL

  -- 8. Composite Foreign Key on habit_logs(habit_id, user_id) -> habits(id, user_id) ON DELETE CASCADE
  SELECT
    'FOREIGN_KEYS' AS category,
    'composite_fk_habit_logs_habit_user' AS check_name,
    CASE
      WHEN to_regclass('public.habit_logs') IS NULL THEN 'FAIL'
      WHEN to_regclass('public.habits') IS NULL THEN 'FAIL'
      WHEN EXISTS (
        SELECT 1 FROM pg_constraint con
        JOIN pg_class src ON src.oid = con.conrelid
        JOIN pg_namespace src_nsp ON src_nsp.oid = src.relnamespace
        JOIN pg_class tgt ON tgt.oid = con.confrelid
        JOIN pg_namespace tgt_nsp ON tgt_nsp.oid = tgt.relnamespace
        WHERE con.conname = 'habit_logs_habit_user_fkey'
          AND con.contype = 'f'
          AND src_nsp.nspname = 'public' AND src.relname = 'habit_logs'
          AND tgt_nsp.nspname = 'public' AND tgt.relname = 'habits'
          AND con.confdeltype = 'c' -- 'c' = CASCADE
          AND (
            SELECT array_agg(att.attname ORDER BY u.ord)
            FROM unnest(con.conkey) WITH ORDINALITY AS u(attnum, ord)
            JOIN pg_attribute att ON att.attrelid = con.conrelid AND att.attnum = u.attnum
          ) = ARRAY['habit_id', 'user_id']::name[]
          AND (
            SELECT array_agg(att.attname ORDER BY u.ord)
            FROM unnest(con.confkey) WITH ORDINALITY AS u(attnum, ord)
            JOIN pg_attribute att ON att.attrelid = con.confrelid AND att.attnum = u.attnum
          ) = ARRAY['id', 'user_id']::name[]
      ) THEN 'PASS'
      ELSE 'FAIL'
    END AS status,
    'habit_logs(habit_id, user_id) -> habits(id, user_id) ON DELETE CASCADE foreign key mapping' AS details

  UNION ALL

  -- 9. Single column foreign keys to auth.users(id) ON DELETE CASCADE
  SELECT
    'FOREIGN_KEYS' AS category,
    'fk_auth_users_' || t.src_table || '_' || t.src_col AS check_name,
    CASE
      WHEN to_regclass('public.' || t.src_table) IS NULL THEN 'FAIL'
      WHEN to_regclass('auth.users') IS NULL THEN 'FAIL'
      WHEN EXISTS (
        SELECT 1 FROM pg_constraint con
        JOIN pg_class src ON src.oid = con.conrelid
        JOIN pg_namespace src_nsp ON src_nsp.oid = src.relnamespace
        JOIN pg_class tgt ON tgt.oid = con.confrelid
        JOIN pg_namespace tgt_nsp ON tgt_nsp.oid = tgt.relnamespace
        WHERE con.contype = 'f'
          AND src_nsp.nspname = 'public' AND src.relname = t.src_table
          AND tgt_nsp.nspname = 'auth' AND tgt.relname = 'users'
          AND con.confdeltype = 'c'
          AND (
            SELECT array_agg(att.attname ORDER BY u.ord)
            FROM unnest(con.conkey) WITH ORDINALITY AS u(attnum, ord)
            JOIN pg_attribute att ON att.attrelid = con.conrelid AND att.attnum = u.attnum
          ) = ARRAY[t.src_col]::name[]
          AND (
            SELECT array_agg(att.attname ORDER BY u.ord)
            FROM unnest(con.confkey) WITH ORDINALITY AS u(attnum, ord)
            JOIN pg_attribute att ON att.attrelid = con.confrelid AND att.attnum = u.attnum
          ) = ARRAY['id']::name[]
      ) THEN 'PASS'
      ELSE 'FAIL'
    END AS status,
    t.src_table || '(' || t.src_col || ') -> auth.users(id) ON DELETE CASCADE foreign key mapping' AS details
  FROM (VALUES
    ('profiles', 'id'),
    ('journal_entries', 'user_id'),
    ('mood_logs', 'user_id'),
    ('habits', 'user_id'),
    ('habit_logs', 'user_id'),
    ('goals', 'user_id'),
    ('coach_messages', 'user_id')
  ) AS t(src_table, src_col)

  UNION ALL

  -- 10. Secondary Performance Indexes
  SELECT
    'INDEXES' AS category,
    'index_' || t.idx_name AS check_name,
    CASE
      WHEN to_regclass('public.' || t.tbl_name) IS NULL THEN 'FAIL'
      WHEN EXISTS (
        SELECT 1 FROM pg_indexes
        WHERE schemaname = 'public'
          AND tablename = t.tbl_name
          AND indexname = t.idx_name
      ) THEN 'PASS'
      ELSE 'FAIL'
    END AS status,
    CASE
      WHEN to_regclass('public.' || t.tbl_name) IS NULL THEN 'Table public.' || t.tbl_name || ' does not exist'
      WHEN EXISTS (
        SELECT 1 FROM pg_indexes
        WHERE schemaname = 'public'
          AND tablename = t.tbl_name
          AND indexname = t.idx_name
      ) THEN 'Index public.' || t.idx_name || ' on ' || t.tbl_name
      ELSE 'Missing index public.' || t.idx_name || ' on ' || t.tbl_name
    END AS details
  FROM (VALUES
    ('journal_entries', 'je_user_date'),
    ('mood_logs', 'ml_user_date'),
    ('habit_logs', 'hl_user_date'),
    ('coach_messages', 'cm_user_date')
  ) AS t(tbl_name, idx_name)

  UNION ALL

  -- 11. Triggers Check (Exact Timing & Event Verification)
  -- BEFORE UPDATE FOR EACH ROW: tgtype = 19
  -- AFTER INSERT FOR EACH ROW: tgtype = 5
  SELECT
    'TRIGGERS' AS category,
    'trigger_' || t.trg_name AS check_name,
    CASE
      WHEN to_regclass(t.tbl_schema || '.' || t.tbl_name) IS NULL THEN 'FAIL'
      WHEN to_regprocedure('public.' || t.func_name || '()') IS NULL THEN 'FAIL'
      WHEN EXISTS (
        SELECT 1 FROM pg_trigger trg
        JOIN pg_class rel ON rel.oid = trg.tgrelid
        JOIN pg_namespace nsp ON nsp.oid = rel.relnamespace
        JOIN pg_proc p ON p.oid = trg.tgfoid
        JOIN pg_namespace p_nsp ON p_nsp.oid = p.pronamespace
        WHERE nsp.nspname = t.tbl_schema
          AND rel.relname = t.tbl_name
          AND trg.tgname = t.trg_name
          AND trg.tgtype = t.expected_tgtype
          AND p_nsp.nspname = 'public'
          AND p.proname = t.func_name
      ) THEN 'PASS'
      ELSE 'FAIL'
    END AS status,
    CASE
      WHEN to_regclass(t.tbl_schema || '.' || t.tbl_name) IS NULL THEN 'Target relation ' || t.tbl_schema || '.' || t.tbl_name || ' does not exist'
      WHEN to_regprocedure('public.' || t.func_name || '()') IS NULL THEN 'Trigger function public.' || t.func_name || '() does not exist'
      WHEN EXISTS (
        SELECT 1 FROM pg_trigger trg
        JOIN pg_class rel ON rel.oid = trg.tgrelid
        JOIN pg_namespace nsp ON nsp.oid = rel.relnamespace
        JOIN pg_proc p ON p.oid = trg.tgfoid
        JOIN pg_namespace p_nsp ON p_nsp.oid = p.pronamespace
        WHERE nsp.nspname = t.tbl_schema
          AND rel.relname = t.tbl_name
          AND trg.tgname = t.trg_name
          AND trg.tgtype = t.expected_tgtype
          AND p_nsp.nspname = 'public'
          AND p.proname = t.func_name
      ) THEN 'Trigger ' || t.trg_name || ' on ' || t.tbl_schema || '.' || t.tbl_name || ' (tgtype=' || t.expected_tgtype || ') calling public.' || t.func_name
      ELSE 'Missing or misconfigured trigger ' || t.trg_name || ' on ' || t.tbl_schema || '.' || t.tbl_name
    END AS details
  FROM (VALUES
    ('public', 'profiles', 'profiles_updated', 19, 'tg_set_updated_at'),
    ('public', 'journal_entries', 'je_updated', 19, 'tg_set_updated_at'),
    ('public', 'goals', 'g_updated', 19, 'tg_set_updated_at'),
    ('auth', 'users', 'on_auth_user_created', 5, 'handle_new_user')
  ) AS t(tbl_schema, tbl_name, trg_name, expected_tgtype, func_name)

  UNION ALL

  -- 12. Function Attributes Check (SECURITY DEFINER & Search Path)
  SELECT
    'FUNCTIONS' AS category,
    'func_' || t.func_name AS check_name,
    CASE
      WHEN to_regprocedure('public.' || t.func_name || '()') IS NULL THEN 'FAIL'
      WHEN EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace nsp ON nsp.oid = p.pronamespace
        WHERE nsp.nspname = 'public'
          AND p.proname = t.func_name
          AND p.prosecdef = t.expected_secdef
          AND 'search_path=public' = ANY(p.proconfig)
      ) THEN 'PASS'
      ELSE 'FAIL'
    END AS status,
    CASE
      WHEN to_regprocedure('public.' || t.func_name || '()') IS NULL THEN 'Function public.' || t.func_name || '() does not exist'
      WHEN EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace nsp ON nsp.oid = p.pronamespace
        WHERE nsp.nspname = 'public'
          AND p.proname = t.func_name
          AND p.prosecdef = t.expected_secdef
          AND 'search_path=public' = ANY(p.proconfig)
      ) THEN 'Function public.' || t.func_name || ' (secdef=' || t.expected_secdef || ', search_path=public)'
      ELSE 'Function public.' || t.func_name || ' missing search_path=public or incorrect prosecdef'
    END AS details
  FROM (VALUES
    ('handle_new_user', true),
    ('tg_set_updated_at', false)
  ) AS t(func_name, expected_secdef)

  UNION ALL

  -- 13. Function Execution Privileges Check: PUBLIC group (via aclexplode catalog check)
  SELECT
    'PRIVILEGES' AS category,
    'public_group_no_func_execute_' || f.func_name AS check_name,
    CASE
      WHEN to_regprocedure('public.' || f.func_name || '()') IS NULL THEN 'FAIL'
      WHEN EXISTS (
        SELECT 1
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        CROSS JOIN LATERAL aclexplode(COALESCE(p.proacl, acldefault('f', p.proowner))) acl
        WHERE n.nspname = 'public'
          AND p.proname = f.func_name
          AND acl.grantee = 0 -- OID 0 represents PUBLIC
      ) THEN 'FAIL'
      ELSE 'PASS'
    END AS status,
    CASE
      WHEN to_regprocedure('public.' || f.func_name || '()') IS NULL THEN 'Function public.' || f.func_name || '() does not exist'
      ELSE 'PUBLIC group has no execute privilege on public.' || f.func_name || '()'
    END AS details
  FROM (VALUES
    ('handle_new_user'),
    ('tg_set_updated_at')
  ) AS f(func_name)

  UNION ALL

  -- 14. Function Execution Privileges Check: anon and authenticated roles
  SELECT
    'PRIVILEGES' AS category,
    'func_perm_revoked_' || f.func_name || '_' || r.role_name AS check_name,
    CASE
      WHEN to_regprocedure('public.' || f.func_name || '()') IS NULL THEN 'FAIL'
      WHEN has_function_privilege(r.role_name, to_regprocedure('public.' || f.func_name || '()'), 'EXECUTE') = false
        THEN 'PASS'
      ELSE 'FAIL'
    END AS status,
    CASE
      WHEN to_regprocedure('public.' || f.func_name || '()') IS NULL THEN 'Function public.' || f.func_name || '() does not exist'
      ELSE 'Role ' || r.role_name || ' cannot execute public.' || f.func_name || '()'
    END AS details
  FROM (VALUES
    ('handle_new_user'),
    ('tg_set_updated_at')
  ) AS f(func_name)
  CROSS JOIN (VALUES
    ('anon'),
    ('authenticated')
  ) AS r(role_name)

  UNION ALL

  -- 15. Table Privileges Check: PUBLIC group (via aclexplode catalog check)
  SELECT
    'PRIVILEGES' AS category,
    'public_group_no_table_privileges_' || tablename AS check_name,
    CASE
      WHEN to_regclass('public.' || tablename) IS NULL THEN 'FAIL'
      WHEN EXISTS (
        SELECT 1
        FROM pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace
        CROSS JOIN LATERAL aclexplode(COALESCE(c.relacl, acldefault('r', c.relowner))) acl
        WHERE n.nspname = 'public'
          AND c.relname = tablename
          AND acl.grantee = 0 -- OID 0 represents PUBLIC
      ) THEN 'FAIL'
      ELSE 'PASS'
    END AS status,
    CASE
      WHEN to_regclass('public.' || tablename) IS NULL THEN 'Table public.' || tablename || ' does not exist'
      ELSE 'PUBLIC group has zero table privileges on public.' || tablename
    END AS details
  FROM expected_tables

  UNION ALL

  -- 16. Table Privileges Check: anon role effective permissions (Must have ZERO permissions)
  SELECT
    'PRIVILEGES' AS category,
    'anon_no_access_' || tablename AS check_name,
    CASE
      WHEN to_regclass('public.' || tablename) IS NULL THEN 'FAIL'
      WHEN
        has_table_privilege('anon', to_regclass('public.' || tablename), 'SELECT') = false AND
        has_table_privilege('anon', to_regclass('public.' || tablename), 'INSERT') = false AND
        has_table_privilege('anon', to_regclass('public.' || tablename), 'UPDATE') = false AND
        has_table_privilege('anon', to_regclass('public.' || tablename), 'DELETE') = false
      THEN 'PASS'
      ELSE 'FAIL'
    END AS status,
    CASE
      WHEN to_regclass('public.' || tablename) IS NULL THEN 'Table public.' || tablename || ' does not exist'
      ELSE 'Role anon has no effective table privileges on public.' || tablename
    END AS details
  FROM expected_tables

  UNION ALL

  -- 17. Table Privileges Check: authenticated role effective CRUD permissions
  SELECT
    'PRIVILEGES' AS category,
    'authenticated_crud_' || tablename AS check_name,
    CASE
      WHEN to_regclass('public.' || tablename) IS NULL THEN 'FAIL'
      WHEN
        has_table_privilege('authenticated', to_regclass('public.' || tablename), 'SELECT') = true AND
        has_table_privilege('authenticated', to_regclass('public.' || tablename), 'INSERT') = true AND
        has_table_privilege('authenticated', to_regclass('public.' || tablename), 'UPDATE') = true AND
        has_table_privilege('authenticated', to_regclass('public.' || tablename), 'DELETE') = true
      THEN 'PASS'
      ELSE 'FAIL'
    END AS status,
    CASE
      WHEN to_regclass('public.' || tablename) IS NULL THEN 'Table public.' || tablename || ' does not exist'
      ELSE 'Role authenticated has effective SELECT, INSERT, UPDATE, DELETE on public.' || tablename
    END AS details
  FROM expected_tables

  UNION ALL

  -- 18. Row Level Security Enabled Check
  SELECT
    'RLS' AS category,
    'rls_enabled_' || et.tablename AS check_name,
    CASE
      WHEN c.relname IS NOT NULL AND c.relrowsecurity = true THEN 'PASS'
      ELSE 'FAIL'
    END AS status,
    CASE
      WHEN c.relname IS NULL THEN 'Table public.' || et.tablename || ' does not exist'
      WHEN c.relrowsecurity = true THEN 'Row Level Security enabled on public.' || et.tablename
      ELSE 'Row Level Security is DISABLED on public.' || et.tablename
    END AS details
  FROM expected_tables et
  LEFT JOIN (
    pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace AND n.nspname = 'public'
  ) ON c.relname = et.tablename

  UNION ALL

  -- 19. Total RLS Policies Count (Design Baseline Assumption)
  SELECT
    'ARCHITECTURE_BASELINE' AS category,
    'exact_rls_policy_count' AS check_name,
    CASE
      WHEN count(*) = 9 THEN 'PASS'
      WHEN count(*) > 9 THEN 'WARNING'
      ELSE 'FAIL'
    END AS status,
    CASE
      WHEN count(*) = 9 THEN 'Found exactly 9 baseline RLS policies across application tables'
      WHEN count(*) > 9 THEN 'Design baseline warning: found ' || count(*) || ' policies (expected 9 baseline). Review additional policies to verify they do not widen access.'
      ELSE 'Missing required baseline RLS policies: found only ' || count(*) || ' of 9 expected policies.'
    END AS details
  FROM pg_policy pol
  JOIN pg_class rel ON rel.oid = pol.polrelid
  JOIN pg_namespace nsp ON nsp.oid = rel.relnamespace
  WHERE nsp.nspname = 'public'
    AND rel.relname IN (SELECT tablename FROM expected_tables)

  UNION ALL

  -- 20. Verification of Individual 9 RLS Policies and their exact expressions
  SELECT
    'RLS' AS category,
    'policy_' || p.pol_name AS check_name,
    CASE
      WHEN to_regclass('public.' || p.table_name) IS NULL THEN 'FAIL'
      WHEN EXISTS (
        SELECT 1 FROM pg_policy pol
        JOIN pg_class rel ON rel.oid = pol.polrelid
        JOIN pg_namespace nsp ON nsp.oid = rel.relnamespace
        WHERE nsp.nspname = 'public'
          AND rel.relname = p.table_name
          AND pol.polname = p.pol_name
          AND pol.polcmd = p.expected_cmd
          -- Robust role check: aggregates all roles, avoiding multi-row scalar subquery failures
          AND (
            SELECT array_agg(r.rolname ORDER BY r.rolname)
            FROM pg_roles r
            WHERE r.oid = ANY(pol.polroles)
          ) = ARRAY['authenticated']::name[]
          -- Strict USING ownership expression check
          AND (
            CASE
              WHEN p.expected_cmd IN ('r', 'w', '*') THEN
                pol.polqual IS NOT NULL AND
                lower(
                  regexp_replace(
                    regexp_replace(pg_get_expr(pol.polqual, pol.polrelid), '::[a-zA-Z0-9_]+', '', 'g'),
                    '[\s\(\)";]',
                    '',
                    'g'
                  )
                ) IN (
                  'auth.uid=' || p.expected_col,
                  p.expected_col || '=auth.uid',
                  'selectauth.uid=' || p.expected_col,
                  p.expected_col || '=selectauth.uid',
                  'selectauth.uidasuid=' || p.expected_col,
                  p.expected_col || '=selectauth.uidasuid'
                )
              WHEN p.expected_cmd = 'a' THEN
                pol.polqual IS NULL
              ELSE FALSE
            END
          )
          -- Strict WITH CHECK ownership expression check
          AND (
            CASE
              WHEN p.expected_cmd IN ('a', '*') THEN
                pol.polwithcheck IS NOT NULL AND
                lower(
                  regexp_replace(
                    regexp_replace(pg_get_expr(pol.polwithcheck, pol.polrelid), '::[a-zA-Z0-9_]+', '', 'g'),
                    '[\s\(\)";]',
                    '',
                    'g'
                  )
                ) IN (
                  'auth.uid=' || p.expected_col,
                  p.expected_col || '=auth.uid',
                  'selectauth.uid=' || p.expected_col,
                  p.expected_col || '=selectauth.uid',
                  'selectauth.uidasuid=' || p.expected_col,
                  p.expected_col || '=selectauth.uidasuid'
                )
              WHEN p.expected_cmd = 'r' THEN
                pol.polwithcheck IS NULL
              WHEN p.expected_cmd = 'w' THEN
                pol.polwithcheck IS NULL OR
                lower(
                  regexp_replace(
                    regexp_replace(pg_get_expr(pol.polwithcheck, pol.polrelid), '::[a-zA-Z0-9_]+', '', 'g'),
                    '[\s\(\)";]',
                    '',
                    'g'
                  )
                ) IN (
                  'auth.uid=' || p.expected_col,
                  p.expected_col || '=auth.uid',
                  'selectauth.uid=' || p.expected_col,
                  p.expected_col || '=selectauth.uid',
                  'selectauth.uidasuid=' || p.expected_col,
                  p.expected_col || '=selectauth.uidasuid'
                )
              ELSE FALSE
            END
          )
      ) THEN 'PASS'
      ELSE 'FAIL'
    END AS status,
    CASE
      WHEN to_regclass('public.' || p.table_name) IS NULL THEN 'Table public.' || p.table_name || ' does not exist'
      WHEN EXISTS (
        SELECT 1 FROM pg_policy pol
        JOIN pg_class rel ON rel.oid = pol.polrelid
        JOIN pg_namespace nsp ON nsp.oid = rel.relnamespace
        WHERE nsp.nspname = 'public'
          AND rel.relname = p.table_name
          AND pol.polname = p.pol_name
          AND pol.polcmd = p.expected_cmd
          AND (
            SELECT array_agg(r.rolname ORDER BY r.rolname)
            FROM pg_roles r
            WHERE r.oid = ANY(pol.polroles)
          ) = ARRAY['authenticated']::name[]
      ) THEN 'RLS policy "' || p.pol_name || '" on ' || p.table_name || ' (cmd=' || p.expected_cmd || ', role=authenticated, condition=auth.uid()=' || p.expected_col || ')'
      ELSE 'Missing or misconfigured RLS policy "' || p.pol_name || '" on ' || p.table_name
    END AS details
  FROM (VALUES
    ('profiles', 'own profile read', 'r', 'id'),
    ('profiles', 'own profile upsert', 'a', 'id'),
    ('profiles', 'own profile update', 'w', 'id'),
    ('journal_entries', 'own entries', '*', 'user_id'),
    ('mood_logs', 'own moods', '*', 'user_id'),
    ('habits', 'own habits', '*', 'user_id'),
    ('habit_logs', 'own habit logs', '*', 'user_id'),
    ('goals', 'own goals', '*', 'user_id'),
    ('coach_messages', 'own coach', '*', 'user_id')
  ) AS p(table_name, pol_name, expected_cmd, expected_col)

  UNION ALL

  -- 21. Profile Backfill Verification (Crash-proof check using dynamic query_to_xml)
  SELECT
    'BACKFILL' AS category,
    'all_auth_users_have_profiles' AS check_name,
    CASE
      WHEN to_regclass('public.profiles') IS NULL THEN 'FAIL'
      WHEN to_regclass('auth.users') IS NULL THEN 'FAIL'
      WHEN (
        xpath(
          '//*[local-name()="missing_count"]/text()',
          query_to_xml(
            'SELECT count(*) AS missing_count FROM auth.users u LEFT JOIN public.profiles p ON p.id = u.id WHERE p.id IS NULL',
            false,
            false,
            ''
          )
        )
      )[1]::text::integer = 0 THEN 'PASS'
      ELSE 'FAIL'
    END AS status,
    CASE
      WHEN to_regclass('public.profiles') IS NULL THEN 'Table public.profiles does not exist'
      WHEN to_regclass('auth.users') IS NULL THEN 'Table auth.users does not exist'
      ELSE 'Missing profile count: ' || COALESCE(
        (
          xpath(
            '//*[local-name()="missing_count"]/text()',
            query_to_xml(
              'SELECT count(*) AS missing_count FROM auth.users u LEFT JOIN public.profiles p ON p.id = u.id WHERE p.id IS NULL',
              false,
              false,
              ''
            )
          )
        )[1]::text,
        'unknown'
      )
    END AS details
)

-- Output all individual numbered checks, followed by summary totals
SELECT
  row_number() OVER (ORDER BY category, check_name) AS check_number,
  category,
  check_name,
  status,
  details
FROM raw_checks

UNION ALL

SELECT
  9990 AS check_number,
  'SUMMARY' AS category,
  'PASSED_CHECKS' AS check_name,
  'INFO' AS status,
  count(*)::text || ' passed' AS details
FROM raw_checks
WHERE status = 'PASS'

UNION ALL

SELECT
  9991 AS check_number,
  'SUMMARY' AS category,
  'FAILED_CHECKS' AS check_name,
  CASE WHEN count(*) = 0 THEN 'INFO' ELSE 'FAIL' END AS status,
  count(*)::text || ' failed' AS details
FROM raw_checks
WHERE status = 'FAIL'

UNION ALL

SELECT
  9992 AS check_number,
  'SUMMARY' AS category,
  'WARNING_CHECKS' AS check_name,
  CASE WHEN count(*) = 0 THEN 'INFO' ELSE 'WARNING' END AS status,
  count(*)::text || ' warnings' AS details
FROM raw_checks
WHERE status = 'WARNING'

UNION ALL

SELECT
  9999 AS check_number,
  'SUMMARY' AS category,
  'TOTAL_CHECKS' AS check_name,
  'INFO' AS status,
  count(*)::text || ' total checks' AS details
FROM raw_checks

ORDER BY check_number;
