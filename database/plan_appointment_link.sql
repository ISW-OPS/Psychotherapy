-- ============================================================
-- Link plan_weekly_progress → appointments (single source of truth)
-- Run once in Supabase SQL Editor
-- ============================================================

ALTER TABLE plan_weekly_progress
  ADD COLUMN IF NOT EXISTS appointment_id UUID REFERENCES appointments(id) ON DELETE SET NULL;

-- Allow patients to insert their own appointments (self-booking from plan.html)
CREATE POLICY "Patients insert own appointments" ON appointments FOR INSERT
  WITH CHECK (patient_id IN (SELECT id FROM patients WHERE user_id = auth.uid()));

-- Allow patients to update their own scheduled appointments (for reschedule)
CREATE POLICY "Patients update own scheduled appointments" ON appointments FOR UPDATE
  USING (
    patient_id IN (SELECT id FROM patients WHERE user_id = auth.uid())
    AND status = 'scheduled'
  )
  WITH CHECK (status = 'scheduled');
