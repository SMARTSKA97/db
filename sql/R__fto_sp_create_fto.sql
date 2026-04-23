-- R: Procedure to create FTO
CREATE OR REPLACE PROCEDURE fto.sp_create_fto(
    p_no VARCHAR, 
    p_amt NUMERIC, 
    p_user VARCHAR, 
    p_ddo VARCHAR, 
    p_fy INT
)
LANGUAGE plpgsql
AS $$
DECLARE 
    v_today DATE := (CURRENT_TIMESTAMP AT TIME ZONE 'UTC')::date;
BEGIN
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
        p_no, 
        p_amt, 
        p_user, 
        p_ddo, 
        0, 
        p_fy
    );
    
    INSERT INTO dashboard.daily_ledger_admin 
    (
        financial_year, 
        ledger_date, 
        received_fto
    ) 
    VALUES 
    (
        p_fy, 
        v_today, 
        1
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
    (
        p_fy, 
        p_ddo, 
        v_today, 
        1
    ) 
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
        p_fy, 
        p_ddo, 
        p_user, 
        v_today, 
        1
    ) 
    ON CONFLICT (financial_year, ddo_code, userid, ledger_date) 
    DO UPDATE 
    SET 
        received_fto = daily_ledger_operator.received_fto + 1;
    
    PERFORM pg_notify(
        'dash_updates', 
        p_fy || ':Admin:' || p_ddo || ':Op:' || p_user || ':FTO_RCVD'
    );
END; $$;
