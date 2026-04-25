-- R: Procedure to forward bill
CREATE OR REPLACE PROCEDURE bills.sp_forward_bill(p_bill_no UUID, p_user VARCHAR, p_role VARCHAR)
LANGUAGE plpgsql AS $$
DECLARE v_fy INT; 
        v_ddo VARCHAR; 
        v_status INT; 
        v_current_status INT;
        v_amount NUMERIC;
        v_today DATE := (CURRENT_TIMESTAMP AT TIME ZONE 'UTC')::date;
BEGIN
    SELECT 
        financial_year, 
        ddo_code,
        amount,
        bill_status
    INTO 
        v_fy, v_ddo, v_amount, v_current_status
    FROM bills.bill_list 
    WHERE bill_no = p_bill_no;
    
    v_status := CASE 
        WHEN p_role = 'Operator' THEN 2 
        ELSE 4 
    END;

    -- Guard: Only proceed if status is actually changing
    IF v_current_status = v_status THEN
        RETURN;
    END IF;
    
    UPDATE bills.bill_list 
    SET bill_status = v_status 
    WHERE bill_no = p_bill_no AND bill_status != v_status;

    -- If no rows updated (lost race), exit
    IF NOT FOUND THEN
        RETURN;
    END IF;
    
    IF v_status = 2 THEN
        INSERT INTO dashboard.daily_ledger_admin 
        (
            financial_year, 
            ledger_date, 
            received_by_approver
        ) 
        VALUES 
        (
            v_fy, 
            v_today, 
            1
        ) 
        ON CONFLICT (financial_year, ledger_date) 
        DO UPDATE 
        SET 
            received_by_approver = daily_ledger_admin.received_by_approver + 1;
        
        INSERT INTO dashboard.daily_ledger_approver 
        (
            financial_year, 
            ddo_code, 
            ledger_date, 
            received_by_approver
        ) 
        VALUES 
        (
            v_fy, 
            v_ddo, 
            v_today, 
            1
        ) 
        ON CONFLICT (financial_year, ddo_code, ledger_date) 
        DO UPDATE 
        SET 
            received_by_approver = daily_ledger_approver.received_by_approver + 1;
        
        PERFORM pg_notify('dash_updates', v_fy || ':Admin:' || v_ddo || ':Op:' || p_user || ':BILL_FWD_APP');
    ELSE
        INSERT INTO dashboard.daily_ledger_admin 
        (
            financial_year, 
            ledger_date, 
            forwarded_to_treasury,
            forwarded_amount
        ) 
        VALUES 
        (
            v_fy, 
            v_today, 
            1,
            v_amount
        ) 
        ON CONFLICT (financial_year, ledger_date) 
        DO UPDATE 
        SET 
            forwarded_to_treasury = daily_ledger_admin.forwarded_to_treasury + 1,
            forwarded_amount = daily_ledger_admin.forwarded_amount + EXCLUDED.forwarded_amount;

        INSERT INTO dashboard.daily_ledger_approver 
        (
            financial_year, 
            ddo_code, 
            ledger_date, 
            forwarded_to_treasury,
            forwarded_amount
        ) 
        VALUES 
        (
            v_fy, 
            v_ddo, 
            v_today, 
            1,
            v_amount
        ) 
        ON CONFLICT (financial_year, ddo_code, ledger_date) 
        DO UPDATE 
        SET 
            forwarded_to_treasury = daily_ledger_approver.forwarded_to_treasury + 1,
            forwarded_amount = daily_ledger_approver.forwarded_amount + EXCLUDED.forwarded_amount;

        PERFORM pg_notify('dash_updates', v_fy || ':Admin:' || v_ddo || ':Op:' || p_user || ':BILL_FWD_TRZ');
    END IF;
END; $$;
