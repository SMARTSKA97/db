-- R: Procedure to generate bill
CREATE OR REPLACE PROCEDURE bills.sp_generate_bill(p_fto_nos VARCHAR[], p_user VARCHAR, p_ddo VARCHAR, p_role VARCHAR, p_fy INT)
LANGUAGE plpgsql AS $$
DECLARE v_bill_no UUID := gen_random_uuid();
        v_count INT;
        v_total_amount NUMERIC;
        v_today DATE := (CURRENT_TIMESTAMP AT TIME ZONE 'UTC')::date;
BEGIN
    WITH processed_rows AS (
        UPDATE 
            fto.fto_list 
        SET 
            fto_status = 1, 
            fto_processed_date = CURRENT_TIMESTAMP, 
            bill_no = v_bill_no 
        WHERE 
            fto_no = ANY(p_fto_nos) 
            AND financial_year = p_fy 
            AND fto_status = 0
        RETURNING 
            amount
    )
    SELECT 
        COUNT(*), 
        SUM(amount) 
    INTO 
        v_count, 
        v_total_amount 
    FROM processed_rows;

    IF v_count IS NULL OR v_count = 0 THEN
        IF EXISTS (SELECT 1 FROM fto.fto_list WHERE fto_no = ANY(p_fto_nos) AND financial_year = p_fy) THEN
            RAISE EXCEPTION 'Process Aborted: Selected FTOs are already processed or linked to another bill.';
        ELSE
            RAISE EXCEPTION 'Process Aborted: No matching FTOs found for the provided FTO numbers and Financial Year (%)', p_fy;
        END IF;
    END IF;

    INSERT INTO 
        bills.bill_list 
        (bill_no, ref_no, amount, bill_status, userid, ddo_code, financial_year) 
    VALUES 
        (
            v_bill_no, 
            'REF-' || v_bill_no, 
            v_total_amount, 
            CASE WHEN p_role = 'Approver' THEN 0 ELSE 1 END, 
            p_user, 
            p_ddo, 
            p_fy
        );

    INSERT INTO dashboard.daily_ledger_admin 
        (
            financial_year, 
            ledger_date, 
            processed_fto, 
            generated_bills
        ) 
    VALUES 
        (
            p_fy, 
            v_today, 
            v_count, 
            1
        ) 
    ON CONFLICT (financial_year, ledger_date) 
    DO UPDATE 
    SET 
        processed_fto = daily_ledger_admin.processed_fto + EXCLUDED.processed_fto, 
        generated_bills = daily_ledger_admin.generated_bills + 1;
    
    INSERT INTO dashboard.daily_ledger_approver 
        (
            financial_year, 
            ddo_code, 
            ledger_date, 
            processed_fto, 
            generated_bills
        ) 
    VALUES 
        (
            p_fy, 
            p_ddo, 
            v_today, 
            v_count, 
            1
        ) 
    ON CONFLICT (financial_year, ddo_code, ledger_date) 
    DO UPDATE 
    SET 
        processed_fto = daily_ledger_approver.processed_fto + EXCLUDED.processed_fto, 
        generated_bills = daily_ledger_approver.generated_bills + 1;
    
    INSERT INTO dashboard.daily_ledger_operator 
        (
            financial_year, 
            ddo_code, 
            userid, 
            ledger_date, 
            processed_fto, 
            generated_bills
        ) 
    VALUES 
        (
            p_fy, 
            p_ddo, 
            p_user, 
            v_today, 
            v_count, 
            1
        ) 
    ON CONFLICT (financial_year, ddo_code, userid, ledger_date) 
    DO UPDATE 
    SET 
        processed_fto = daily_ledger_operator.processed_fto + EXCLUDED.processed_fto, 
        generated_bills = daily_ledger_operator.generated_bills + 1;
    
    PERFORM pg_notify('dash_updates', p_fy || ':Admin:' || p_ddo || ':Op:' || p_user || ':BILL_GEN');
END; $$;
