-- ============================================================
-- FIX: Staff & Patient delete FK constraints
-- Run dalam Supabase SQL Editor
-- ============================================================

-- ── STAFF REFERENCES → SET NULL ──────────────────────────────

ALTER TABLE psy_appointments
  DROP CONSTRAINT IF EXISTS psy_appointments_staff_id_fkey;
ALTER TABLE psy_appointments
  ADD CONSTRAINT psy_appointments_staff_id_fkey
  FOREIGN KEY (staff_id) REFERENCES psy_profiles(id) ON DELETE SET NULL;

ALTER TABLE psy_treatment_plans
  DROP CONSTRAINT IF EXISTS psy_treatment_plans_doctor_id_fkey;
ALTER TABLE psy_treatment_plans
  ADD CONSTRAINT psy_treatment_plans_doctor_id_fkey
  FOREIGN KEY (doctor_id) REFERENCES psy_profiles(id) ON DELETE SET NULL;

ALTER TABLE psy_kyc_submissions
  DROP CONSTRAINT IF EXISTS psy_kyc_submissions_reviewed_by_fkey;
ALTER TABLE psy_kyc_submissions
  ADD CONSTRAINT psy_kyc_submissions_reviewed_by_fkey
  FOREIGN KEY (reviewed_by) REFERENCES psy_profiles(id) ON DELETE SET NULL;

ALTER TABLE psy_plan_weekly_progress
  DROP CONSTRAINT IF EXISTS psy_plan_weekly_progress_updated_by_fkey;
ALTER TABLE psy_plan_weekly_progress
  ADD CONSTRAINT psy_plan_weekly_progress_updated_by_fkey
  FOREIGN KEY (updated_by) REFERENCES psy_profiles(id) ON DELETE SET NULL;

-- coach_id ditambah dalam step13
ALTER TABLE psy_patients
  DROP CONSTRAINT IF EXISTS psy_patients_coach_id_fkey;
ALTER TABLE psy_patients
  ADD CONSTRAINT psy_patients_coach_id_fkey
  FOREIGN KEY (coach_id) REFERENCES psy_profiles(id) ON DELETE SET NULL;

-- ── PATIENT REFERENCES → CASCADE ─────────────────────────────

ALTER TABLE psy_patients
  DROP CONSTRAINT IF EXISTS psy_patients_user_id_fkey;
ALTER TABLE psy_patients
  ADD CONSTRAINT psy_patients_user_id_fkey
  FOREIGN KEY (user_id) REFERENCES psy_profiles(id) ON DELETE CASCADE;

ALTER TABLE psy_kyc_submissions
  DROP CONSTRAINT IF EXISTS psy_kyc_submissions_user_id_fkey;
ALTER TABLE psy_kyc_submissions
  ADD CONSTRAINT psy_kyc_submissions_user_id_fkey
  FOREIGN KEY (user_id) REFERENCES psy_profiles(id) ON DELETE CASCADE;

ALTER TABLE psy_payments
  DROP CONSTRAINT IF EXISTS psy_payments_user_id_fkey;
ALTER TABLE psy_payments
  ADD CONSTRAINT psy_payments_user_id_fkey
  FOREIGN KEY (user_id) REFERENCES psy_profiles(id) ON DELETE CASCADE;

SELECT 'FK fix OK — delete staff/patient sekarang berfungsi' AS status;
