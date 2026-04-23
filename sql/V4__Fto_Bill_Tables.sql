-- V1.4: Core Transaction Tables
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
