-- R: Dashboard Partitioning Function (Excludes Admin Ledger)
CREATE OR REPLACE FUNCTION dashboard.fn_create_ledger_partitions(p_fy INT)
RETURNS VOID LANGUAGE plpgsql AS $$
DECLARE
    v_start_year INT := 2000 + (p_fy / 100);
    v_start_date DATE := MAKE_DATE(v_start_year, 4, 1);
    v_end_date DATE;
    v_part_name VARCHAR;
    v_table_name VARCHAR;
    v_schema VARCHAR := 'dashboard';
    -- daily_ledger_admin is now a regular table, not partitioned
    v_tables VARCHAR[] := ARRAY['daily_ledger_approver', 'daily_ledger_operator'];
BEGIN
    FOR i IN 0..11 LOOP
        v_end_date := v_start_date + INTERVAL '1 month';
        FOREACH v_table_name IN ARRAY v_tables LOOP
            v_part_name := v_table_name || '_' || TO_CHAR(v_start_date, 'YYYY_MM');
            IF NOT EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace WHERE n.nspname = v_schema AND c.relname = v_part_name) THEN
                EXECUTE format('CREATE TABLE %I.%I PARTITION OF %I.%I FOR VALUES FROM (%L) TO (%L)', 
                    v_schema, v_part_name, v_schema, v_table_name, v_start_date, v_end_date);
            END IF;
        END LOOP;
        v_start_date := v_end_date;
    END LOOP;
END; $$;
