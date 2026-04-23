-- ============================================================
-- Fix RLS: Allow staff to read patient profiles & plans
-- Run AFTER step16_missing_tables.sql
-- Run in Supabase SQL Editor
-- ============================================================

-- NOTE: psy_profiles already has "Read all profiles authenticated" policy (step1)
-- Adding another SELECT policy with a self-referencing subquery causes recursion
-- No change needed for psy_profiles

-- 1. Staff can read all treatment plans
DROP POLICY IF EXISTS "Staff can read all treatment plans" ON psy_treatment_plans;
CREATE POLICY "Staff can read all treatment plans"
  ON psy_treatment_plans FOR SELECT
  USING (
    auth.uid() IN (
      SELECT id FROM psy_profiles WHERE role = 'staff'
    )
    OR auth.uid() IN (
      SELECT user_id FROM psy_patients WHERE id = patient_id
    )
  );

-- 3. Staff can read all weekly progress
DROP POLICY IF EXISTS "Staff can read all weekly progress" ON psy_plan_weekly_progress;
CREATE POLICY "Staff can read all weekly progress"
  ON psy_plan_weekly_progress FOR SELECT
  USING (
    auth.uid() IN (SELECT id FROM psy_profiles WHERE role = 'staff')
    OR auth.uid() IN (SELECT user_id FROM psy_patients WHERE id = patient_id)
  );

-- 4. Staff can read all compliance records
DROP POLICY IF EXISTS "Staff can read all compliance" ON psy_plan_compliance;
CREATE POLICY "Staff can read all compliance"
  ON psy_plan_compliance FOR SELECT
  USING (
    auth.uid() IN (SELECT id FROM psy_profiles WHERE role = 'staff')
    OR auth.uid() IN (SELECT user_id FROM psy_patients WHERE id = patient_id)
  );

-- 5. Staff can read all daily checkins
DROP POLICY IF EXISTS "Staff can read all checkins" ON psy_daily_checkins;
CREATE POLICY "Staff can read all checkins"
  ON psy_daily_checkins FOR SELECT
  USING (
    auth.uid() IN (SELECT id FROM psy_profiles WHERE role = 'staff')
    OR auth.uid() IN (SELECT user_id FROM psy_patients WHERE id = patient_id)
  );

-- 6. Staff can read all KYC submissions
DROP POLICY IF EXISTS "Staff can read all kyc" ON psy_kyc_submissions;
CREATE POLICY "Staff can read all kyc"
  ON psy_kyc_submissions FOR SELECT
  USING (
    auth.uid() IN (SELECT id FROM psy_profiles WHERE role = 'staff')
    OR auth.uid() = user_id
  );

SELECT 'RLS fix OK — staff can now read all patient data' AS status;
