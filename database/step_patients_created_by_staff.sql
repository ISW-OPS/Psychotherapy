-- ============================================================
-- STEP — Add psy_patients.created_by_staff
-- Column ini digunakan dalam kod (patients.html) untuk flag pesakit
-- yang didaftarkan oleh staff (bypass KOB flow), tapi belum dicipta
-- dalam schema. Tambah sekarang.
-- ============================================================

ALTER TABLE psy_patients
  ADD COLUMN IF NOT EXISTS created_by_staff BOOLEAN DEFAULT false;

COMMENT ON COLUMN psy_patients.created_by_staff IS
  'TRUE = pesakit didaftarkan oleh staff (bukan self-signup). Akan bypass KOB flow (kob_status=na) dan tunggu auto-link bila pesakit signup sendiri guna IC sama.';

-- Backfill: existing patients dengan user_id (self-registered) → false
-- Tanpa user_id (likely staff-created) → true
UPDATE psy_patients
SET created_by_staff = (user_id IS NULL)
WHERE created_by_staff IS NULL OR created_by_staff = false;

-- Index untuk auto-link query (cari unlinked staff-created patients ikut IC)
CREATE INDEX IF NOT EXISTS idx_psy_patients_created_by_staff
  ON psy_patients(created_by_staff)
  WHERE created_by_staff = true AND user_id IS NULL;

-- Verifikasi
SELECT
  COUNT(*) FILTER (WHERE created_by_staff = true) AS staff_created,
  COUNT(*) FILTER (WHERE created_by_staff = false) AS self_registered,
  COUNT(*) AS total
FROM psy_patients;

SELECT 'OK — created_by_staff column ready' AS status;
