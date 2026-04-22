-- V2: Precision Hardening & Simulation Recovery
-- Standardizes date logic to UTC and ensures daily ledger rows are initialized upon the first transaction.

-- 1. HARDEN FORWARD PROC
CREATE OR REPLACE PROCEDURE bills.sp_forward_bill(p_bill_no UUID, p_user VARCHAR, p_role VARCHAR)
LANGUAGE plpgsql AS $$
DECLARE v_fy INT; v_ddo VARCHAR; v_status INT; v_today DATE := (CURRENT_TIMESTAMP AT TIME ZONE 'UTC')::date;
BEGIN
    SELECT financial_year, ddo_code INTO v_fy, v_ddo FROM bills.bill_list WHERE bill_no = p_bill_no;
    v_status := CASE WHEN p_role = 'Operator' THEN 2 ELSE 4 END;
    
    UPDATE bills.bill_list SET bill_status = v_status WHERE bill_no = p_bill_no;
    
    IF v_status = 2 THEN
        -- Standard Admin Pulse
        INSERT INTO dashboard.daily_ledger_admin (financial_year, ledger_date, received_by_approver) 
        VALUES (v_fy, v_today, 1) ON CONFLICT (financial_year, ledger_date) 
        DO UPDATE SET received_by_approver = daily_ledger_admin.received_by_approver + 1;
        
        -- Standard Approver Pulse
        INSERT INTO dashboard.daily_ledger_approver (financial_year, ddo_code, ledger_date, received_by_approver) 
        VALUES (v_fy, v_ddo, v_today, 1) ON CONFLICT (financial_year, ddo_code, ledger_date) 
        DO UPDATE SET received_by_approver = daily_ledger_approver.received_by_approver + 1;
        
        PERFORM pg_notify('dash_updates', v_fy || ':Admin:' || v_ddo || ':Op:' || p_user || ':BILL_FWD_APP');
    ELSE
        INSERT INTO dashboard.daily_ledger_admin (financial_year, ledger_date, forwarded_to_treasury) 
        VALUES (v_fy, v_today, 1) ON CONFLICT (financial_year, ledger_date) 
        DO UPDATE SET forwarded_to_treasury = daily_ledger_admin.forwarded_to_treasury + 1;

        INSERT INTO dashboard.daily_ledger_approver (financial_year, ddo_code, ledger_date, forwarded_to_treasury) 
        VALUES (v_fy, v_ddo, v_today, 1) ON CONFLICT (financial_year, ddo_code, ledger_date) 
        DO UPDATE SET forwarded_to_treasury = daily_ledger_approver.forwarded_to_treasury + 1;

        PERFORM pg_notify('dash_updates', v_fy || ':Admin:' || v_ddo || ':Op:' || p_user || ':BILL_FWD_TRZ');
    END IF;
END; $$;

-- 2. HARDEN REJECT PROC
CREATE OR REPLACE PROCEDURE bills.sp_reject_bill(p_bill_no UUID, p_user VARCHAR)
LANGUAGE plpgsql AS $$
DECLARE v_fy INT; v_ddo VARCHAR; v_today DATE := (CURRENT_TIMESTAMP AT TIME ZONE 'UTC')::date;
BEGIN
    SELECT financial_year, ddo_code INTO v_fy, v_ddo FROM bills.bill_list WHERE bill_no = p_bill_no;
    UPDATE bills.bill_list SET bill_status = 3 WHERE bill_no = p_bill_no;
    
    INSERT INTO dashboard.daily_ledger_admin (financial_year, ledger_date, rejected_by_approver) 
    VALUES (v_fy, v_today, 1) ON CONFLICT (financial_year, ledger_date) 
    DO UPDATE SET rejected_by_approver = daily_ledger_admin.rejected_by_approver + 1;
    
    INSERT INTO dashboard.daily_ledger_approver (financial_year, ddo_code, ledger_date, rejected_by_approver) 
    VALUES (v_fy, v_ddo, v_today, 1) ON CONFLICT (financial_year, ddo_code, ledger_date) 
    DO UPDATE SET rejected_by_approver = daily_ledger_approver.rejected_by_approver + 1;
    
    PERFORM pg_notify('dash_updates', v_fy || ':Admin:' || v_ddo || ':Op:' || p_user || ':BILL_REJ');
END; $$;
