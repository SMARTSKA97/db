-- V1.5: Summary & Metadata
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
CREATE TABLE IF NOT EXISTS dashboard.sync_metadata ( 
    sync_key VARCHAR(50) PRIMARY KEY, 
    last_processed_date DATE NOT NULL 
);
INSERT INTO dashboard.sync_metadata 
(
    sync_key, 
    last_processed_date
) 
VALUES 
(
    'MIDNIGHT_HARDENING', 
    CURRENT_DATE - INTERVAL '1 day'
) 
ON CONFLICT DO NOTHING;
