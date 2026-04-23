-- R: Dashboard Refresh Status Function
CREATE OR REPLACE FUNCTION dashboard.fn_get_refresh_status() 
RETURNS jsonb 
AS $$
BEGIN 
    RETURN jsonb_build_object(
        'message', 
        'Dashboard Engine Active', 
        'is_allowed', 
        true, 
        'remaining_seconds', 
        0
    ); 
END; 
$$ LANGUAGE plpgsql;
