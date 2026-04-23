-- Allow patients to read their own issues, staff replies, and their own follow-ups
-- Run this in Supabase SQL Editor

-- Drop old policy first if exists
DROP POLICY IF EXISTS "Patients read own issues" ON psy_audit_log;

-- Recreate with followup included
CREATE POLICY "Patients read own issues" ON psy_audit_log FOR SELECT
  USING (
    (action IN ('issue.reported', 'issue.followup') AND actor_id = auth.uid())
    OR (action = 'issue.responded' AND target = auth.uid()::text)
  );

SELECT 'Fix OK — patients can read reported, responded, and followup entries' AS status;
