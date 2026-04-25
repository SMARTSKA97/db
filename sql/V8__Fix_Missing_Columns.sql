-- V8: Fix missing financial columns (Insurance for V7 mismatch)

-- 1. Add columns to Ledger Tables
ALTER TABLE dashboard.daily_ledger_admin ADD COLUMN IF NOT EXISTS bill_amount NUMERIC(15,2) DEFAULT 0;
ALTER TABLE dashboard.daily_ledger_admin ADD COLUMN IF NOT EXISTS forwarded_amount NUMERIC(15,2) DEFAULT 0;
ALTER TABLE dashboard.daily_ledger_admin ADD COLUMN IF NOT EXISTS fto_amount NUMERIC(15,2) DEFAULT 0;

ALTER TABLE dashboard.daily_ledger_approver ADD COLUMN IF NOT EXISTS bill_amount NUMERIC(15,2) DEFAULT 0;
ALTER TABLE dashboard.daily_ledger_approver ADD COLUMN IF NOT EXISTS forwarded_amount NUMERIC(15,2) DEFAULT 0;
ALTER TABLE dashboard.daily_ledger_approver ADD COLUMN IF NOT EXISTS fto_amount NUMERIC(15,2) DEFAULT 0;

ALTER TABLE dashboard.daily_ledger_operator ADD COLUMN IF NOT EXISTS bill_amount NUMERIC(15,2) DEFAULT 0;
ALTER TABLE dashboard.daily_ledger_operator ADD COLUMN IF NOT EXISTS forwarded_amount NUMERIC(15,2) DEFAULT 0;
ALTER TABLE dashboard.daily_ledger_operator ADD COLUMN IF NOT EXISTS fto_amount NUMERIC(15,2) DEFAULT 0;

-- 2. Add columns to Summary Tables
ALTER TABLE dashboard.fy_summary_admin ADD COLUMN IF NOT EXISTS bill_amount NUMERIC(15,2) DEFAULT 0;
ALTER TABLE dashboard.fy_summary_admin ADD COLUMN IF NOT EXISTS forwarded_amount NUMERIC(15,2) DEFAULT 0;
ALTER TABLE dashboard.fy_summary_admin ADD COLUMN IF NOT EXISTS fto_amount NUMERIC(15,2) DEFAULT 0;

ALTER TABLE dashboard.fy_summary_approver ADD COLUMN IF NOT EXISTS bill_amount NUMERIC(15,2) DEFAULT 0;
ALTER TABLE dashboard.fy_summary_approver ADD COLUMN IF NOT EXISTS forwarded_amount NUMERIC(15,2) DEFAULT 0;
ALTER TABLE dashboard.fy_summary_approver ADD COLUMN IF NOT EXISTS fto_amount NUMERIC(15,2) DEFAULT 0;

ALTER TABLE dashboard.fy_summary_operator ADD COLUMN IF NOT EXISTS bill_amount NUMERIC(15,2) DEFAULT 0;
ALTER TABLE dashboard.fy_summary_operator ADD COLUMN IF NOT EXISTS forwarded_amount NUMERIC(15,2) DEFAULT 0;
ALTER TABLE dashboard.fy_summary_operator ADD COLUMN IF NOT EXISTS fto_amount NUMERIC(15,2) DEFAULT 0;

-- 3. Run Data Sync (Just in case V7 sync didn't run)
WITH fto_daily AS (
    SELECT financial_year, ddo_code, userid, (fto_creation_date AT TIME ZONE 'UTC')::date as ledger_date, SUM(amount) as amt FROM fto.fto_list GROUP BY 1, 2, 3, 4
)
UPDATE dashboard.daily_ledger_operator dl SET fto_amount = fd.amt FROM fto_daily fd 
WHERE dl.financial_year = fd.financial_year AND dl.ddo_code = fd.ddo_code AND dl.userid = fd.userid AND dl.ledger_date = fd.ledger_date;

WITH bill_daily AS (
    SELECT financial_year, ddo_code, userid, (bill_date AT TIME ZONE 'UTC')::date as ledger_date, SUM(amount) as amt FROM bills.bill_list GROUP BY 1, 2, 3, 4
)
UPDATE dashboard.daily_ledger_operator dl SET bill_amount = bd.amt FROM bill_daily bd 
WHERE dl.financial_year = bd.financial_year AND dl.ddo_code = bd.ddo_code AND dl.userid = bd.userid AND dl.ledger_date = bd.ledger_date;

WITH forward_daily AS (
    SELECT financial_year, ddo_code, (bill_date AT TIME ZONE 'UTC')::date as ledger_date, SUM(amount) as amt FROM bills.bill_list WHERE bill_status >= 4 GROUP BY 1, 2, 3
)
UPDATE dashboard.daily_ledger_approver dl SET forwarded_amount = fd.amt FROM forward_daily fd 
WHERE dl.financial_year = fd.financial_year AND dl.ddo_code = fd.ddo_code AND dl.ledger_date = fd.ledger_date;

UPDATE dashboard.daily_ledger_admin dl SET 
    fto_amount = COALESCE((SELECT SUM(fto_amount) FROM dashboard.daily_ledger_operator o WHERE o.financial_year = dl.financial_year AND o.ledger_date = dl.ledger_date), 0),
    bill_amount = COALESCE((SELECT SUM(bill_amount) FROM dashboard.daily_ledger_operator o WHERE o.financial_year = dl.financial_year AND o.ledger_date = dl.ledger_date), 0),
    forwarded_amount = COALESCE((SELECT SUM(forwarded_amount) FROM dashboard.daily_ledger_approver a WHERE a.financial_year = dl.financial_year AND a.ledger_date = dl.ledger_date), 0);

UPDATE dashboard.daily_ledger_approver dl SET 
    fto_amount = COALESCE((SELECT SUM(fto_amount) FROM dashboard.daily_ledger_operator o WHERE o.financial_year = dl.financial_year AND o.ddo_code = dl.ddo_code AND o.ledger_date = dl.ledger_date), 0),
    bill_amount = COALESCE((SELECT SUM(bill_amount) FROM dashboard.daily_ledger_operator o WHERE o.financial_year = dl.financial_year AND o.ddo_code = dl.ddo_code AND o.ledger_date = dl.ledger_date), 0);

CALL dashboard.sp_harden_summary_tables();
