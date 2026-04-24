-- R: Seed Data System (Dynamic FY & Partitioning)
CREATE OR REPLACE PROCEDURE master.seed_data() LANGUAGE plpgsql AS $$
DECLARE 
    v_year INT := EXTRACT(YEAR FROM CURRENT_DATE);
    v_month INT := EXTRACT(MONTH FROM CURRENT_DATE);
    v_fy INT;
    v_part_name TEXT;
    v_today DATE := (CURRENT_TIMESTAMP AT TIME ZONE 'UTC')::date;
BEGIN
    -- April 2026 -> FY 2627
    IF v_month >= 4 THEN
        v_fy := (v_year % 100) * 100 + ((v_year % 100) + 1);
    ELSE
        v_fy := ((v_year - 1) % 100) * 100 + (v_year % 100);
    END IF;

    INSERT INTO master.ddo 
    (
        ddo_code, 
        ddo_name
    ) 
    VALUES 
    (   
        'DDO001', 
        'Primary Treasury Office'
    ) 
    ON CONFLICT DO NOTHING;

    INSERT INTO master.users 
    (
        userid, 
        password_hash, 
        role, 
        ddo_code
    ) 
    VALUES 
    (
        'Admin', 
        'pass', 
        'Admin', 
        'DDO001' 
    ), 
    (
        'DDO001_APPROVER', 
        'pass', 
        'Approver', 
        'DDO001' 
    ), 
    (
        'DDO001_OP1', 
        'pass', 
        'Operator', 
        'DDO001'
    ),
    (
        'DDO001_OP2', 
        'pass', 
        'Operator', 
        'DDO001'
    ),
    (
        'DDO001_OP3', 
        'pass', 
        'Operator', 
        'DDO001'
    ) 
    ON CONFLICT DO NOTHING;

    -- Dynamic FTO Partitioning
    v_part_name := 'fto_list_fy' || v_fy;
    IF NOT EXISTS (SELECT 1 
                    FROM pg_class c 
                    JOIN pg_namespace n ON n.oid = c.relnamespace 
                    WHERE n.nspname = 'fto' AND c.relname = v_part_name) 
    THEN
        EXECUTE format(
            'CREATE TABLE fto.%I PARTITION OF fto.fto_list FOR VALUES FROM (%L) TO (%L)', 
            v_part_name, 
            v_fy, 
            v_fy + 1
        );
    END IF;

    -- Dynamic Ledger Partitioning (Skips Admin)
    PERFORM dashboard.fn_create_ledger_partitions(v_fy);

    -- Seed Data Initialization
    FOR i IN 1..10 LOOP 
        INSERT INTO fto.fto_list 
        (
            fto_no, 
            amount, 
            userid, 
            ddo_code, 
            fto_status, 
            financial_year
        ) 
        VALUES 
        (
            'FTO-SEED-' || v_fy || '-' || i, 
            1500.00, 
            'DDO001_OP1', 
            'DDO001', 
            0, 
            v_fy
        ) 
        ON CONFLICT (fto_no, financial_year) DO NOTHING; 
    END LOOP;

    INSERT INTO dashboard.daily_ledger_admin 
    (
        financial_year, 
        ledger_date, 
        received_fto
    ) 
    VALUES 
    (
        v_fy, 
        v_today, 
        10
    ) 
    ON CONFLICT (financial_year, ledger_date) 
    DO UPDATE 
    SET 
        received_fto = daily_ledger_admin.received_fto + 1;
    
    INSERT INTO dashboard.daily_ledger_approver 
    (
        financial_year, 
        ddo_code, 
        ledger_date, 
        received_fto
    ) 
    VALUES 
    (v_fy, 'DDO001', v_today, 10) 
    ON CONFLICT (financial_year, ddo_code, ledger_date) 
    DO UPDATE 
    SET 
        received_fto = daily_ledger_approver.received_fto + 1;
    
    INSERT INTO dashboard.daily_ledger_operator 
    (
        financial_year, 
        ddo_code, 
        userid, 
        ledger_date, 
        received_fto
    ) 
    VALUES 
    (
        v_fy, 
        'DDO001', 
        'DDO001_OP1', 
        v_today, 
        10
    ) 
    ON CONFLICT (financial_year, ddo_code, userid, ledger_date) 
    DO UPDATE 
    SET 
        received_fto = daily_ledger_operator.received_fto + 1;

    RAISE NOTICE 'Seed Data initialized for Financial Year %', v_fy;
END; $$;

CALL master.seed_data();
CALL dashboard.sp_harden_summary_tables();
