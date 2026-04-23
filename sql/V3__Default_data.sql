INSERT INTO master.fto_status 
(
    status_id, 
    status_name
)
VALUES 
(
    0, 
    'Received' 
),
(
    1, 
    'Processed'
) 
ON CONFLICT DO NOTHING;

INSERT INTO master.bill_status 
(
    status_id, 
    status_name
) 
VALUES 
(
    0, 
    'Created by Approver' 
),
(
    1, 
    'Created by Operator' 
),
(
    2, 
    'Forwarded (Approver)'
),
(
    3, 
    'Rejected (Approver)'
),
(
    4, 
    'Forwarded (Treasury)'
) 
ON CONFLICT DO NOTHING;
