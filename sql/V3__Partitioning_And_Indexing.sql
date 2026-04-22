-- V3: Database Automation & Hardening (Partitioning & Indexing)
-- Author: Antigravity

-- 1. RENAME OLD TABLES
ALTER TABLE dashboard.daily_ledger_admin RENAME TO daily_ledger_admin_old;
ALTER TABLE dashboard.daily_ledger_approver RENAME TO daily_ledger_approver_old;
ALTER TABLE dashboard.daily_ledger_operator RENAME TO daily_ledger_operator_old;

-- 2. CREATE NEW PARTITIONED TABLES
CREATE TABLE dashboard.daily_ledger_admin ( 
    financial_year INT NOT NULL, 
    ledger_date DATE NOT NULL, 
    received_fto INT DEFAULT 0, 
    processed_fto INT DEFAULT 0, 
    generated_bills INT DEFAULT 0, 
    forwarded_to_treasury INT DEFAULT 0, 
    received_by_approver INT DEFAULT 0, 
    rejected_by_approver INT DEFAULT 0, 
    PRIMARY KEY (financial_year, ledger_date) 
) PARTITION BY RANGE (ledger_date);

CREATE TABLE dashboard.daily_ledger_approver ( 
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
) PARTITION BY RANGE (ledger_date);

CREATE TABLE dashboard.daily_ledger_operator ( 
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
) PARTITION BY RANGE (ledger_date);

-- 3. AUTO-PARTITIONING FUNCTION
CREATE OR REPLACE FUNCTION dashboard.fn_create_ledger_partitions(p_fy INT)
RETURNS VOID LANGUAGE plpgsql AS $$
DECLARE
    v_start_year INT := 2000 + (p_fy / 100);
    v_start_date DATE := MAKE_DATE(v_start_year, 4, 1);
    v_end_date DATE;
    v_part_name VARCHAR;
    v_table_name VARCHAR;
    v_schema VARCHAR := 'dashboard';
    v_tables VARCHAR[] := ARRAY['daily_ledger_admin', 'daily_ledger_approver', 'daily_ledger_operator'];
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

-- 4. BOOTSTRAP PARTITIONS FOR CURRENT & NEXT FY
SELECT dashboard.fn_create_ledger_partitions(2526);
SELECT dashboard.fn_create_ledger_partitions(2627);

-- 5. MIGRATE DATA
INSERT INTO dashboard.daily_ledger_admin SELECT * FROM dashboard.daily_ledger_admin_old ON CONFLICT DO NOTHING;
INSERT INTO dashboard.daily_ledger_approver SELECT * FROM dashboard.daily_ledger_approver_old ON CONFLICT DO NOTHING;
INSERT INTO dashboard.daily_ledger_operator SELECT * FROM dashboard.daily_ledger_operator_old ON CONFLICT DO NOTHING;

-- 6. DROP OLD TABLES
DROP TABLE dashboard.daily_ledger_admin_old;
DROP TABLE dashboard.daily_ledger_approver_old;
DROP TABLE dashboard.daily_ledger_operator_old;

-- 7. CREATE TARGETED COMPOSITE INDEXES
-- Optimized for reading specific financial years and dates across all DDOs/Users
CREATE INDEX idx_dl_admin_date ON dashboard.daily_ledger_admin (financial_year, ledger_date);
CREATE INDEX idx_dl_approver_date ON dashboard.daily_ledger_approver (financial_year, ledger_date);
CREATE INDEX idx_dl_operator_date ON dashboard.daily_ledger_operator (financial_year, ledger_date);
