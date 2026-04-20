-- ============================================================
-- PLAN WEEKLY PROGRESS v2 — replace 'pending' with 'booked'
-- Each week must have a booked session_date (no pending state).
-- ============================================================

-- Loosen the status check to include 'booked'
ALTER TABLE plan_weekly_progress DROP CONSTRAINT IF EXISTS plan_weekly_progress_status_check;
ALTER TABLE plan_weekly_progress
  ADD CONSTRAINT plan_weekly_progress_status_check
  CHECK (status IN ('booked','hadir','reschedule','cancel','pending'));

-- Patient self-service: may insert & update their own weeks
DROP POLICY IF EXISTS "Patients book own weeks" ON plan_weekly_progress;
CREATE POLICY "Patients book own weeks" ON plan_weekly_progress FOR INSERT
  WITH CHECK (patient_id IN (SELECT id FROM patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Patients update own weeks" ON plan_weekly_progress;
CREATE POLICY "Patients update own weeks" ON plan_weekly_progress FOR UPDATE
  USING (patient_id IN (SELECT id FROM patients WHERE user_id = auth.uid()));
