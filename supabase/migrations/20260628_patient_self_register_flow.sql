-- ============================================================
-- 20260628_patient_self_register_flow.sql
-- Auto-create psy_patients stub for self-registered patients.
-- Flow: signup → email confirm → login → KYC → KOB → ...
-- ============================================================

-- ── 0. Remove duplicate user_id rows safely ──────────────────
DELETE FROM psy_patients p
WHERE p.user_id IS NOT NULL
  AND EXISTS (
    SELECT 1 FROM psy_patients p2
    WHERE p2.user_id = p.user_id AND p2.id != p.id
  )
  AND NOT EXISTS (SELECT 1 FROM psy_treatment_plans     WHERE patient_id = p.id)
  AND NOT EXISTS (SELECT 1 FROM psy_appointments         WHERE patient_id = p.id)
  AND NOT EXISTS (SELECT 1 FROM psy_kob_sessions         WHERE patient_id = p.id)
  AND NOT EXISTS (SELECT 1 FROM psy_plan_weekly_progress WHERE patient_id = p.id)
  AND NOT EXISTS (SELECT 1 FROM psy_vitals               WHERE patient_id = p.id)
  AND NOT EXISTS (SELECT 1 FROM psy_payments             WHERE patient_id = p.id);

-- ── 1. Add UNIQUE constraint (best-effort) ────────────────────
DO $$ BEGIN
  ALTER TABLE psy_patients DROP CONSTRAINT IF EXISTS psy_patients_user_id_unique;
  ALTER TABLE psy_patients ADD CONSTRAINT psy_patients_user_id_unique UNIQUE (user_id);
EXCEPTION WHEN OTHERS THEN
  RAISE LOG 'psy_patients_user_id_unique skip: %', SQLERRM;
END $$;

-- ── 2. Trigger function: auto-create patient stub ────────────
CREATE OR REPLACE FUNCTION handle_new_patient_profile()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NEW.role = 'patient' THEN
    IF NOT EXISTS (SELECT 1 FROM psy_patients WHERE user_id = NEW.id) THEN
      INSERT INTO psy_patients (user_id, full_name, status, kob_status, created_by_staff)
      VALUES (NEW.id, NEW.full_name, 'pending_kyc', 'paid', false);
    END IF;
  END IF;
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE LOG 'handle_new_patient_profile error: %', SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_new_patient_profile ON psy_profiles;
CREATE TRIGGER trg_new_patient_profile
  AFTER INSERT ON psy_profiles
  FOR EACH ROW
  EXECUTE FUNCTION handle_new_patient_profile();

-- ── 3. Backfill: patient profiles with no psy_patients row ───
INSERT INTO psy_patients (user_id, full_name, status, kob_status, created_by_staff)
SELECT p.id, p.full_name, 'pending_kyc', 'paid', false
FROM psy_profiles p
WHERE p.role = 'patient'
  AND NOT EXISTS (SELECT 1 FROM psy_patients pt WHERE pt.user_id = p.id);

SELECT 'OK — patient self-register flow ready (auto stub on signup)' AS status;
