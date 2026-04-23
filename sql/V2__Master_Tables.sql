-- V1.2: Master Registry
CREATE TABLE IF NOT EXISTS master.ddo ( 
    ddo_code VARCHAR(20) PRIMARY KEY, 
    ddo_name VARCHAR(100) NOT NULL 
);
CREATE TABLE IF NOT EXISTS master.users ( 
    userid VARCHAR(50) PRIMARY KEY, 
    password_hash VARCHAR(255) NOT NULL, 
    role VARCHAR(20) NOT NULL, 
    ddo_code VARCHAR(20) REFERENCES master.ddo(ddo_code) 
);
CREATE TABLE IF NOT EXISTS master.fto_status ( 
    status_id INT PRIMARY KEY, 
    status_name VARCHAR(50) NOT NULL 
);

CREATE TABLE IF NOT EXISTS master.bill_status ( 
    status_id INT PRIMARY KEY, 
    status_name VARCHAR(50) NOT NULL 
);