-- ============================================================
-- STEP — Link psy_vitals ke minggu rawatan
-- Vitals patut "duduk dalam minggu" supaya boleh paparkan dalam
-- plan-week.html sebagai sebahagian dari rekod sesi minggu tu.
-- ============================================================

ALTER TABLE psy_vitals
  ADD COLUMN IF NOT EXISTS plan_id     UUID REFERENCES psy_treatment_plans(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS week_number INT;

COMMENT ON COLUMN psy_vitals.plan_id IS
  'Refer treatment plan masa vitals direkod. NULL kalau direkod luar konteks plan.';
COMMENT ON COLUMN psy_vitals.week_number IS
  'Minggu rawatan ke berapa bila vitals direkod. NULL kalau tiada plan aktif.';

-- Backfill: cuba match vitals lama dengan plan aktif patient + minggu ikut tarikh
UPDATE psy_vitals v
SET plan_id     = tp.id,
    week_number = tp.current_week
FROM psy_treatment_plans tp
WHERE v.patient_id = tp.patient_id
  AND tp.status = 'active'
  AND v.plan_id IS NULL;

-- Index untuk query "vitals minggu X plan Y"
CREATE INDEX IF NOT EXISTS idx_vitals_plan_week
  ON psy_vitals(plan_id, week_number) WHERE plan_id IS NOT NULL;

-- Verifikasi
SELECT
  COUNT(*) FILTER (WHERE plan_id IS NOT NULL) AS linked_to_plan,
  COUNT(*) FILTER (WHERE plan_id IS NULL)     AS no_plan,
  COUNT(*) AS total
FROM psy_vitals;

SELECT 'OK — psy_vitals linked to plan + week_number' AS status;
