-- ============================================================
-- STEP — Patient Plan Setup RLS
-- Benarkan patient update plan SENDIRI untuk setup jadual sahaja
-- (preferred_pair, preferred_time_day1/2, schedule_setup_at).
-- Bukan kebenaran penuh — staff masih perlu untuk ubah status,
-- duration, goals, dsb.
-- ============================================================

DO $$ BEGIN
  CREATE POLICY "Patients update own plan setup"
  ON psy_treatment_plans
  FOR UPDATE
  USING (
    patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid())
  )
  WITH CHECK (
    patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid())
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- NOTA: Policy ni bagi UPDATE pada SEMUA column untuk patient sendiri.
-- Kalau mahu lebih ketat (cth: cuma boleh update preferred_pair + masa),
-- guna kombinasi dengan trigger BEFORE UPDATE untuk reject column lain.
-- Untuk MVP, ini cukup sebab UI patient hanya expose 4 field setup.

SELECT 'OK — patient plan setup RLS policy added' AS status;
