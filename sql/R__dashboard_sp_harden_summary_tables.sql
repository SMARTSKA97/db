-- R: Dashboard Hardening Procedure
CREATE OR REPLACE PROCEDURE dashboard.sp_harden_summary_tables() 
LANGUAGE plpgsql 
AS $$
BEGIN
    INSERT INTO dashboard.fy_summary_admin (
        financial_year, 
        received_fto, 
        processed_fto, 
        generated_bills, 
        forwarded_to_treasury, 
        received_by_approver, 
        rejected_by_approver,
        bill_amount,
        forwarded_amount,
        fto_amount
    )
    SELECT 
        financial_year, 
        SUM(received_fto), 
        SUM(processed_fto), 
        SUM(generated_bills), 
        SUM(forwarded_to_treasury), 
        SUM(received_by_approver), 
        SUM(rejected_by_approver),
        SUM(bill_amount),
        SUM(forwarded_amount),
        SUM(fto_amount)
    FROM dashboard.daily_ledger_admin 
    WHERE ledger_date < CURRENT_DATE 
    GROUP BY financial_year
    ON CONFLICT (financial_year) DO UPDATE SET 
        received_fto = EXCLUDED.received_fto, 
        processed_fto = EXCLUDED.processed_fto, 
        generated_bills = EXCLUDED.generated_bills, 
        forwarded_to_treasury = EXCLUDED.forwarded_to_treasury, 
        received_by_approver = EXCLUDED.received_by_approver, 
        rejected_by_approver = EXCLUDED.rejected_by_approver,
        bill_amount = EXCLUDED.bill_amount,
        forwarded_amount = EXCLUDED.forwarded_amount,
        fto_amount = EXCLUDED.fto_amount;

    INSERT INTO dashboard.fy_summary_approver (
        financial_year, 
        ddo_code, 
        received_fto, 
        processed_fto, 
        generated_bills, 
        forwarded_to_treasury, 
        received_by_approver, 
        rejected_by_approver,
        bill_amount,
        forwarded_amount,
        fto_amount
    )
    SELECT 
        financial_year, 
        ddo_code, 
        SUM(received_fto), 
        SUM(processed_fto), 
        SUM(generated_bills), 
        SUM(forwarded_to_treasury), 
        SUM(received_by_approver), 
        SUM(rejected_by_approver),
        SUM(bill_amount),
        SUM(forwarded_amount),
        SUM(fto_amount)
    FROM dashboard.daily_ledger_approver 
    WHERE ledger_date < CURRENT_DATE 
    GROUP BY financial_year, ddo_code
    ON CONFLICT (financial_year, ddo_code) 
    DO UPDATE 
    SET 
        received_fto = EXCLUDED.received_fto, 
        processed_fto = EXCLUDED.processed_fto, 
        generated_bills = EXCLUDED.generated_bills, 
        forwarded_to_treasury = EXCLUDED.forwarded_to_treasury, 
        received_by_approver = EXCLUDED.received_by_approver, 
        rejected_by_approver = EXCLUDED.rejected_by_approver,
        bill_amount = EXCLUDED.bill_amount,
        forwarded_amount = EXCLUDED.forwarded_amount,
        fto_amount = EXCLUDED.fto_amount;

    INSERT INTO dashboard.fy_summary_operator (
        financial_year, 
        ddo_code, 
        userid, 
        received_fto, 
        processed_fto, 
        generated_bills, 
        forwarded_to_treasury, 
        received_by_approver, 
        rejected_by_approver,
        bill_amount,
        forwarded_amount,
        fto_amount
    )
    SELECT 
        financial_year, 
        ddo_code, 
        userid, 
        SUM(received_fto), 
        SUM(processed_fto), 
        SUM(generated_bills), 
        SUM(forwarded_to_treasury), 
        SUM(received_by_approver), 
        SUM(rejected_by_approver),
        SUM(bill_amount),
        SUM(forwarded_amount),
        SUM(fto_amount)
    FROM dashboard.daily_ledger_operator 
    WHERE ledger_date < CURRENT_DATE 
    GROUP BY financial_year, ddo_code, userid
    ON CONFLICT (financial_year, ddo_code, userid) 
    DO UPDATE 
    SET 
        received_fto = EXCLUDED.received_fto, 
        processed_fto = EXCLUDED.processed_fto, 
        generated_bills = EXCLUDED.generated_bills, 
        forwarded_to_treasury = EXCLUDED.forwarded_to_treasury, 
        received_by_approver = EXCLUDED.received_by_approver, 
        rejected_by_approver = EXCLUDED.rejected_by_approver,
        bill_amount = EXCLUDED.bill_amount,
        forwarded_amount = EXCLUDED.forwarded_amount,
        fto_amount = EXCLUDED.fto_amount;
    
    UPDATE dashboard.sync_metadata 
    SET 
        last_processed_date = CURRENT_DATE - 1 
    WHERE 
        sync_key = 'MIDNIGHT_HARDENING';
END; $$;
