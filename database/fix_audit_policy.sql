-- Fix RLS policy for psy_audit_log — allow any authenticated user to insert
DROP POLICY IF EXISTS "All authenticated insert audit" ON psy_audit_log;
CREATE POLICY "All authenticated insert audit" ON psy_audit_log FOR INSERT
  WITH CHECK (true);

SELECT 'Fix OK — audit_log insert policy updated' AS status;
