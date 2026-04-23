-- ============================================================
-- STEP 3 — PSY_AUDIT_LOG
-- Run selepas step2_patients.sql
-- ============================================================

CREATE TABLE psy_audit_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_id UUID,
  actor_name TEXT,
  actor_role TEXT,
  action TEXT NOT NULL,
  target TEXT,
  meta JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE psy_audit_log ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Staff read audit" ON psy_audit_log FOR SELECT
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
CREATE POLICY "All authenticated insert audit" ON psy_audit_log FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);

CREATE INDEX idx_psy_audit_created ON psy_audit_log(created_at);

SELECT 'Step 3 OK — psy_audit_log ready' AS status;
