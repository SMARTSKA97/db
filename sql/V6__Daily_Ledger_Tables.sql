-- V2.1: Unified Admin Ledger (NON-PARTITIONED)
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
) PARTITION BY RANGE (ledger_date);

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
) PARTITION BY RANGE (ledger_date);

CREATE INDEX IF NOT EXISTS idx_dl_admin_date ON dashboard.daily_ledger_admin (financial_year, ledger_date);
CREATE INDEX IF NOT EXISTS idx_dl_approver_date ON dashboard.daily_ledger_approver (financial_year, ledger_date);
CREATE INDEX IF NOT EXISTS idx_dl_operator_date ON dashboard.daily_ledger_operator (financial_year, ledger_date);
