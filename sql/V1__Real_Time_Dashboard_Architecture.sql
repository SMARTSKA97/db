-- V1: Elite Universal Enterprise Baseline (INFRASTRUCTURE TITAN)
-- Author: Antigravity
-- Date: 2026-04-21
-- Full-Lifecycle Transaction & Real-Time Analytics Engine (85 Lakh Scale)

-- 1. SCHEMAS
CREATE SCHEMA IF NOT EXISTS master;
CREATE SCHEMA IF NOT EXISTS fto;
CREATE SCHEMA IF NOT EXISTS bills;
CREATE SCHEMA IF NOT EXISTS dashboard;

-- 2. MASTER DATA
CREATE TABLE IF NOT EXISTS master.ddo ( 
    ddo_code VARCHAR(20) PRIMARY KEY, 
    ddo_name VARCHAR(100) NOT NULL 
);
CREATE TABLE IF NOT EXISTS master.users ( 
    userid VARCHAR(50) PRIMARY KEY, 
    password_hash VARCHAR(255) NOT NULL, 
    role VARCHAR(20) NOT NULL, 
    ddo_code VARCHAR(20) REFERENCES master.ddo(ddo_code) 
);
CREATE TABLE IF NOT EXISTS master.fto_status ( 
    status_id INT PRIMARY KEY, 
    status_name VARCHAR(50) NOT NULL 
);
INSERT INTO master.fto_status (status_id, status_name) VALUES (0, 'Received'), (1, 'Processed') ON CONFLICT DO NOTHING;
CREATE TABLE IF NOT EXISTS master.bill_status ( 
    status_id INT PRIMARY KEY, 
    status_name VARCHAR(50) NOT NULL 
);
INSERT INTO master.bill_status (status_id, status_name) VALUES (0, 'Created by Approver'), (1, 'Created by Operator'), (2, 'Forwarded (Approver)'), (3, 'Rejected (Approver)'), (4, 'Forwarded (Treasury)') ON CONFLICT DO NOTHING;

-- 3. TRANSACTION DATA (Partitioned)
CREATE TABLE IF NOT EXISTS fto.fto_list (
    fto_no VARCHAR(50) NOT NULL, 
    amount NUMERIC(15, 2) NOT NULL, 
    userid VARCHAR(50) NOT NULL, 
    ddo_code VARCHAR(20) NOT NULL,
    fto_status INT DEFAULT 0 REFERENCES master.fto_status(status_id), 
    financial_year INT NOT NULL, 
    fto_creation_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fto_processed_date TIMESTAMP NULL, 
    bill_no UUID NULL, 
    PRIMARY KEY (fto_no, financial_year)
) PARTITION BY RANGE (financial_year);

CREATE TABLE IF NOT EXISTS bills.bill_list (
    bill_no UUID PRIMARY KEY, 
    ref_no VARCHAR(100) NOT NULL, 
    amount NUMERIC(15, 2) NOT NULL, 
    bill_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    bill_status INT DEFAULT 0 REFERENCES master.bill_status(status_id), 
    userid VARCHAR(50) NOT NULL, 
    ddo_code VARCHAR(20) NOT NULL, 
    financial_year INT NOT NULL
);

-- 4. DASHBOARD LEDGERS (Triple-Ledger Storage)
CREATE TABLE IF NOT EXISTS dashboard.daily_ledger_admin ( 
    financial_year INT NOT NULL, 
    ledger_date DATE NOT NULL, 
    received_fto INT DEFAULT 0, 
    processed_fto INT DEFAULT 0, 
    generated_bills INT DEFAULT 0, 
    forwarded_to_treasury INT DEFAULT 0, 
    received_by_approver INT DEFAULT 0, 
    rejected_by_approver INT DEFAULT 0, 
    PRIMARY KEY (financial_year, ledger_date) 
);
CREATE TABLE IF NOT EXISTS dashboard.daily_ledger_approver ( 
    financial_year INT NOT NULL, 
    ddo_code VARCHAR(20) NOT NULL, 
    ledger_date DATE NOT NULL, 
    received_fto INT DEFAULT 0, 
    processed_fto INT DEFAULT 0, 
    generated_bills INT DEFAULT 0, 
    forwarded_to_treasury INT DEFAULT 0, 
    received_by_approver INT DEFAULT 0, 
    rejected_by_approver INT DEFAULT 0, 
    PRIMARY KEY (financial_year, ddo_code, ledger_date) 
);
CREATE TABLE IF NOT EXISTS dashboard.daily_ledger_operator ( 
    financial_year INT NOT NULL, 
    ddo_code VARCHAR(20) NOT NULL, 
    userid VARCHAR(50) NOT NULL, 
    ledger_date DATE NOT NULL, 
    received_fto INT DEFAULT 0, 
    processed_fto INT DEFAULT 0, 
    generated_bills INT DEFAULT 0, 
    forwarded_to_treasury INT DEFAULT 0, 
    received_by_approver INT DEFAULT 0, 
    rejected_by_approver INT DEFAULT 0, 
    PRIMARY KEY (financial_year, ddo_code, userid, ledger_date) 
);

-- 5. SUMMARY TABLES (Hardening)
CREATE TABLE IF NOT EXISTS dashboard.fy_summary_admin ( 
    financial_year INT PRIMARY KEY, 
    received_fto INT DEFAULT 0, 
    processed_fto INT DEFAULT 0, 
    generated_bills INT DEFAULT 0, 
    forwarded_to_treasury INT DEFAULT 0, 
    received_by_approver INT DEFAULT 0, 
    rejected_by_approver INT DEFAULT 0 
);
CREATE TABLE IF NOT EXISTS dashboard.fy_summary_approver ( 
    financial_year INT NOT NULL, 
    ddo_code VARCHAR(20) NOT NULL, 
    received_fto INT DEFAULT 0, 
    processed_fto INT DEFAULT 0, 
    generated_bills INT DEFAULT 0, 
    forwarded_to_treasury INT DEFAULT 0, 
    received_by_approver INT DEFAULT 0, 
    rejected_by_approver INT DEFAULT 0, 
    PRIMARY KEY (financial_year, ddo_code) 
);
CREATE TABLE IF NOT EXISTS dashboard.fy_summary_operator ( 
    financial_year INT NOT NULL, 
    ddo_code VARCHAR(20) NOT NULL, 
    userid VARCHAR(50) NOT NULL, 
    received_fto INT DEFAULT 0, 
    processed_fto INT DEFAULT 0, 
    generated_bills INT DEFAULT 0, 
    forwarded_to_treasury INT DEFAULT 0, 
    received_by_approver INT DEFAULT 0, 
    rejected_by_approver INT DEFAULT 0, 
    PRIMARY KEY (financial_year, ddo_code, userid) 
);

-- 6. MAINTENANCE
CREATE TABLE IF NOT EXISTS dashboard.sync_metadata ( 
    sync_key VARCHAR(50) PRIMARY KEY, 
    last_processed_date DATE NOT NULL 
);
INSERT INTO dashboard.sync_metadata (sync_key, last_processed_date) 
VALUES ('MIDNIGHT_HARDENING', CURRENT_DATE - INTERVAL '1 day') ON CONFLICT DO NOTHING;

-- 7. SIMULATION ENGINE (Triple-Update Fortress)
CREATE OR REPLACE PROCEDURE fto.sp_create_fto(p_no VARCHAR, p_amt NUMERIC, p_user VARCHAR, p_ddo VARCHAR, p_fy INT)
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO fto.fto_list (fto_no, amount, userid, ddo_code, fto_status, financial_year) 
    VALUES (p_no, p_amt, p_user, p_ddo, 0, p_fy);
    
    INSERT INTO dashboard.daily_ledger_admin (financial_year, ledger_date, received_fto) 
    VALUES (p_fy, CURRENT_DATE, 1) ON CONFLICT (financial_year, ledger_date) 
    DO UPDATE SET received_fto = daily_ledger_admin.received_fto + 1;
    
    INSERT INTO dashboard.daily_ledger_approver (financial_year, ddo_code, ledger_date, received_fto) 
    VALUES (p_fy, p_ddo, CURRENT_DATE, 1) ON CONFLICT (financial_year, ddo_code, ledger_date) 
    DO UPDATE SET received_fto = daily_ledger_approver.received_fto + 1;
    
    INSERT INTO dashboard.daily_ledger_operator (financial_year, ddo_code, userid, ledger_date, received_fto) 
    VALUES (p_fy, p_ddo, p_user, CURRENT_DATE, 1) ON CONFLICT (financial_year, ddo_code, userid, ledger_date) 
    DO UPDATE SET received_fto = daily_ledger_operator.received_fto + 1;
    
    PERFORM pg_notify('dash_updates', p_fy || ':Admin:' || p_ddo || ':Op:' || p_user || ':FTO_RCVD');
END; $$;

CREATE OR REPLACE PROCEDURE bills.sp_generate_bill(p_fto_nos VARCHAR[], p_user VARCHAR, p_ddo VARCHAR, p_role VARCHAR, p_fy INT)
LANGUAGE plpgsql AS $$
DECLARE v_bill_no UUID := gen_random_uuid();
BEGIN
    INSERT INTO bills.bill_list (bill_no, ref_no, amount, bill_status, userid, ddo_code, financial_year) 
    VALUES (v_bill_no, 'REF-' || v_bill_no, 1000.00, CASE WHEN p_role = 'Approver' THEN 0 ELSE 1 END, p_user, p_ddo, p_fy);
    
    UPDATE fto.fto_list 
    SET 
        fto_status = 1, 
        fto_processed_date = CURRENT_TIMESTAMP, 
        bill_no = v_bill_no 
    WHERE fto_no = ANY(p_fto_nos) AND financial_year = p_fy;
    
    INSERT INTO dashboard.daily_ledger_admin (financial_year, ledger_date, processed_fto, generated_bills) 
    VALUES (p_fy, CURRENT_DATE, array_length(p_fto_nos, 1), 1) 
    ON CONFLICT (financial_year, ledger_date) 
    DO UPDATE SET processed_fto = daily_ledger_admin.processed_fto + EXCLUDED.processed_fto, generated_bills = daily_ledger_admin.generated_bills + 1;
    
    INSERT INTO dashboard.daily_ledger_approver (financial_year, ddo_code, ledger_date, processed_fto, generated_bills) 
    VALUES (p_fy, p_ddo, CURRENT_DATE, array_length(p_fto_nos, 1), 1) 
    ON CONFLICT (financial_year, ddo_code, ledger_date) 
    DO UPDATE SET processed_fto = daily_ledger_approver.processed_fto + EXCLUDED.processed_fto, generated_bills = daily_ledger_approver.generated_bills + 1;
    
    INSERT INTO dashboard.daily_ledger_operator (financial_year, ddo_code, userid, ledger_date, processed_fto, generated_bills) 
    VALUES (p_fy, p_ddo, p_user, CURRENT_DATE, array_length(p_fto_nos, 1), 1) 
    ON CONFLICT (financial_year, ddo_code, userid, ledger_date) 
    DO UPDATE SET processed_fto = daily_ledger_operator.processed_fto + EXCLUDED.processed_fto, generated_bills = daily_ledger_operator.generated_bills + 1;
    
    PERFORM pg_notify('dash_updates', p_fy || ':Admin:' || p_ddo || ':Op:' || p_user || ':BILL_GEN');
END; $$;

CREATE OR REPLACE PROCEDURE bills.sp_forward_bill(p_bill_no UUID, p_user VARCHAR, p_role VARCHAR)
LANGUAGE plpgsql AS $$
DECLARE v_fy INT; v_ddo VARCHAR; v_status INT;
BEGIN
    SELECT financial_year, ddo_code INTO v_fy, v_ddo FROM bills.bill_list WHERE bill_no = p_bill_no;
    v_status := CASE WHEN p_role = 'Operator' THEN 2 ELSE 4 END;
    UPDATE bills.bill_list 
    SET bill_status = v_status 
    WHERE bill_no = p_bill_no;
    
    IF v_status = 2 THEN
        UPDATE dashboard.daily_ledger_admin 
        SET received_by_approver = received_by_approver + 1 
        WHERE financial_year = v_fy AND ledger_date = CURRENT_DATE;
        
        UPDATE dashboard.daily_ledger_approver 
        SET received_by_approver = received_by_approver + 1 
        WHERE financial_year = v_fy AND ddo_code = v_ddo AND ledger_date = CURRENT_DATE;
        
        PERFORM pg_notify('dash_updates', v_fy || ':Admin:' || v_ddo || ':Op:' || p_user || ':BILL_FWD_APP');
    ELSE
        UPDATE dashboard.daily_ledger_admin 
        SET forwarded_to_treasury = forwarded_to_treasury + 1 
        WHERE financial_year = v_fy AND ledger_date = CURRENT_DATE;

        UPDATE dashboard.daily_ledger_approver 
        SET forwarded_to_treasury = forwarded_to_treasury + 1 
        WHERE financial_year = v_fy AND ddo_code = v_ddo AND ledger_date = CURRENT_DATE;

        PERFORM pg_notify('dash_updates', v_fy || ':Admin:' || v_ddo || ':Op:' || p_user || ':BILL_FWD_TRZ');
    END IF;
END; $$;

CREATE OR REPLACE PROCEDURE bills.sp_reject_bill(p_bill_no UUID, p_user VARCHAR)
LANGUAGE plpgsql AS $$
DECLARE v_fy INT; v_ddo VARCHAR;
BEGIN
    SELECT financial_year, ddo_code INTO v_fy, v_ddo 
    FROM bills.bill_list 
    WHERE bill_no = p_bill_no;
    
    UPDATE bills.bill_list 
    SET bill_status = 3 
    WHERE bill_no = p_bill_no;
    
    UPDATE dashboard.daily_ledger_admin 
    SET rejected_by_approver = rejected_by_approver + 1 
    WHERE financial_year = v_fy AND ledger_date = CURRENT_DATE;
    
    UPDATE dashboard.daily_ledger_approver 
    SET rejected_by_approver = rejected_by_approver + 1 
    WHERE financial_year = v_fy AND ddo_code = v_ddo AND ledger_date = CURRENT_DATE;
    
    PERFORM pg_notify('dash_updates', v_fy || ':Admin:' || v_ddo || ':Op:' || p_user || ':BILL_REJ');
END; $$;

-- 8. MAINTENANCE & INITIALIZATION
CREATE OR REPLACE PROCEDURE dashboard.sp_harden_summary_tables() LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO dashboard.fy_summary_admin (financial_year, received_fto, processed_fto, generated_bills, forwarded_to_treasury, received_by_approver, rejected_by_approver)
    SELECT 
        financial_year, 
        SUM(received_fto), 
        SUM(processed_fto), 
        SUM(generated_bills), 
        SUM(forwarded_to_treasury), 
        SUM(received_by_approver), 
        SUM(rejected_by_approver)
    FROM dashboard.daily_ledger_admin 
    WHERE ledger_date < CURRENT_DATE 
    GROUP BY financial_year
    ON CONFLICT (financial_year) DO UPDATE SET 
        received_fto = EXCLUDED.received_fto, 
        processed_fto = EXCLUDED.processed_fto, 
        generated_bills = EXCLUDED.generated_bills, 
        forwarded_to_treasury = EXCLUDED.forwarded_to_treasury,
        received_by_approver = EXCLUDED.received_by_approver, 
        rejected_by_approver = EXCLUDED.rejected_by_approver;

    -- 2. APPROVER HARDENING (8 Lakh Scale)
    INSERT INTO dashboard.fy_summary_approver (financial_year, ddo_code, received_fto, processed_fto, generated_bills, forwarded_to_treasury, received_by_approver, rejected_by_approver)
    SELECT 
        financial_year, 
        ddo_code, 
        SUM(received_fto), 
        SUM(processed_fto), 
        SUM(generated_bills), 
        SUM(forwarded_to_treasury), 
        SUM(received_by_approver), 
        SUM(rejected_by_approver)
    FROM dashboard.daily_ledger_approver 
    WHERE ledger_date < CURRENT_DATE 
    GROUP BY financial_year, ddo_code
    ON CONFLICT (financial_year, ddo_code) DO UPDATE SET 
        received_fto = EXCLUDED.received_fto, 
        processed_fto = EXCLUDED.processed_fto, 
        generated_bills = EXCLUDED.generated_bills, 
        forwarded_to_treasury = EXCLUDED.forwarded_to_treasury,
        received_by_approver = EXCLUDED.received_by_approver, 
        rejected_by_approver = EXCLUDED.rejected_by_approver;

    -- 3. OPERATOR HARDENING (85 Lakh Scale)
    INSERT INTO dashboard.fy_summary_operator (financial_year, ddo_code, userid, received_fto, processed_fto, generated_bills, forwarded_to_treasury, received_by_approver, rejected_by_approver)
    SELECT 
        financial_year, 
        ddo_code, 
        userid, 
        SUM(received_fto), 
        SUM(processed_fto), 
        SUM(generated_bills), 
        SUM(forwarded_to_treasury), 
        SUM(received_by_approver), 
        SUM(rejected_by_approver)
    FROM dashboard.daily_ledger_operator 
    WHERE ledger_date < CURRENT_DATE 
    GROUP BY financial_year, ddo_code, userid
    ON CONFLICT (financial_year, ddo_code, userid) DO UPDATE SET 
        received_fto = EXCLUDED.received_fto, 
        processed_fto = EXCLUDED.processed_fto, 
        generated_bills = EXCLUDED.generated_bills, 
        forwarded_to_treasury = EXCLUDED.forwarded_to_treasury,
        received_by_approver = EXCLUDED.received_by_approver, 
        rejected_by_approver = EXCLUDED.rejected_by_approver;
    
    UPDATE dashboard.sync_metadata SET last_processed_date = CURRENT_DATE - 1 WHERE sync_key = 'MIDNIGHT_HARDENING';
END; $$;

CREATE OR REPLACE FUNCTION dashboard.fn_get_refresh_status() RETURNS jsonb AS $$
BEGIN RETURN jsonb_build_object('message', 'Dashboard Engine Active', 'is_allowed', true, 'remaining_seconds', 0); END; $$ LANGUAGE plpgsql;

-- 9. BOOTSTRAP FORTRESS (Initial Transaction Data)
CREATE OR REPLACE PROCEDURE master.seed_data() LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO master.ddo (ddo_code, ddo_name) VALUES ('DDO001', 'Primary Treasury Office') ON CONFLICT DO NOTHING;
    INSERT INTO master.users (userid, password_hash, role, ddo_code) VALUES ('Admin', 'pass', 'Admin', 'DDO001'), ('DDO001_APPROVER', 'pass', 'Approver', 'DDO001'), ('DDO001_OP1', 'pass', 'Operator', 'DDO001') ON CONFLICT DO NOTHING;
    IF NOT EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace WHERE n.nspname = 'fto' AND c.relname = 'fto_list_fy2526') THEN CREATE TABLE fto.fto_list_fy2526 PARTITION OF fto.fto_list FOR VALUES FROM (2526) TO (2527); END IF;
    FOR i IN 1..10 LOOP INSERT INTO fto.fto_list (fto_no, amount, userid, ddo_code, fto_status, financial_year) VALUES ('FTO-BOOT-' || i, 1500.00, 'DDO001_OP1', 'DDO001', 0, 2526) ON CONFLICT DO NOTHING; END LOOP;
    INSERT INTO dashboard.daily_ledger_admin (financial_year, ledger_date, received_fto) VALUES (2526, CURRENT_DATE, 10) ON CONFLICT (financial_year, ledger_date) DO UPDATE SET received_fto = 10;
    INSERT INTO dashboard.daily_ledger_approver (financial_year, ddo_code, ledger_date, received_fto) VALUES (2526, 'DDO001', CURRENT_DATE, 10) ON CONFLICT (financial_year, ddo_code, ledger_date) DO UPDATE SET received_fto = 10;
    INSERT INTO dashboard.daily_ledger_operator (financial_year, ddo_code, userid, ledger_date, received_fto) VALUES (2526, 'DDO001', 'DDO001_OP1', CURRENT_DATE, 10) ON CONFLICT (financial_year, ddo_code, userid, ledger_date) DO UPDATE SET received_fto = 10;
END; $$;

CALL master.seed_data();
CALL dashboard.sp_harden_summary_tables();
