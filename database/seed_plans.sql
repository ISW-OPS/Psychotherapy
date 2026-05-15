-- ============================================================
-- SEED DATA: Treatment Plans + Weekly Progress
-- Untuk test halaman Weekly Plan (plans.html)
--
-- Jalankan dalam Supabase SQL Editor
-- NOTA: Require patients & staff sudah wujud dalam DB
-- ============================================================


-- ── STEP 1: Kemaskini current_week pada plan yang ada ────────
-- Bagi plan yang ada, set current_week supaya progress bar nampak

UPDATE psy_treatment_plans SET current_week = 5
WHERE name ILIKE '%OBP1%' AND status = 'active';

UPDATE psy_treatment_plans SET current_week = 3
WHERE name ILIKE '%EOL+%' AND status = 'active';

UPDATE psy_treatment_plans SET current_week = 2
WHERE name ILIKE '%EOL %' AND status = 'active';

UPDATE psy_treatment_plans SET current_week = 7
WHERE name ILIKE '%777 VIP%' AND status = 'active';

UPDATE psy_treatment_plans SET current_week = 1
WHERE name ILIKE '%777 FREE%' AND status = 'active';


-- ── STEP 2: Assign coach kepada patients (pakai coach Aqilah) ─
-- Guna staff yang ada role = 'coach'
-- Update semua patient active dengan coach pertama yang jumpa

UPDATE psy_patients
SET coach_id = (
  SELECT id FROM psy_profiles
  WHERE role = 'staff' AND staff_role = 'coach'
  ORDER BY created_at
  LIMIT 1
)
WHERE status IN ('active', 'unregistered')
  AND coach_id IS NULL;


-- ── STEP 3: Insert weekly progress untuk plan OBP1 ───────────
-- Masukkan rekod progress minggu 1-5 (4 hadir, 1 semasa)

DO $$
DECLARE
  v_plan_id UUID;
  v_patient_id UUID;
  v_staff_id UUID;
BEGIN
  -- Ambil plan OBP1 yang ada
  SELECT id, patient_id INTO v_plan_id, v_patient_id
  FROM psy_treatment_plans
  WHERE name ILIKE '%OBP1%' AND status = 'active'
  ORDER BY created_at LIMIT 1;

  -- Ambil staff untuk updated_by
  SELECT id INTO v_staff_id FROM psy_profiles
  WHERE role = 'staff' ORDER BY created_at LIMIT 1;

  IF v_plan_id IS NULL THEN
    RAISE NOTICE 'Tiada plan OBP1 — skip';
    RETURN;
  END IF;

  -- Minggu 1-4: hadir
  INSERT INTO psy_plan_weekly_progress
    (plan_id, patient_id, week_number, status, score, notes, session_date, updated_by_name, updated_at)
  VALUES
    (v_plan_id, v_patient_id, 1, 'hadir', 8, 'Pesakit positif, mula peminuman IB dengan baik.',
      now() - interval '4 weeks', 'Aqilah (Coach)', now()),
    (v_plan_id, v_patient_id, 2, 'hadir', 7, 'Sedikit reaksi pemulihan — explain normal.',
      now() - interval '3 weeks', 'Aqilah (Coach)', now()),
    (v_plan_id, v_patient_id, 3, 'hadir', 9, 'Mood meningkat, berat turun 1.2kg.',
      now() - interval '2 weeks', 'Aqilah (Coach)', now()),
    (v_plan_id, v_patient_id, 4, 'hadir', 8, 'Konsisten dengan jadual minum.',
      now() - interval '1 week', 'Aqilah (Coach)', now())
  ON CONFLICT (plan_id, week_number) DO UPDATE SET
    status = EXCLUDED.status,
    score = EXCLUDED.score,
    notes = EXCLUDED.notes,
    session_date = EXCLUDED.session_date;

END $$;


-- ── STEP 4: Insert weekly progress untuk plan EOL+ ──────────

DO $$
DECLARE
  v_plan_id UUID;
  v_patient_id UUID;
BEGIN
  SELECT id, patient_id INTO v_plan_id, v_patient_id
  FROM psy_treatment_plans
  WHERE name ILIKE '%EOL+%' AND status = 'active'
  ORDER BY created_at LIMIT 1;

  IF v_plan_id IS NULL THEN RAISE NOTICE 'Tiada plan EOL+ — skip'; RETURN; END IF;

  INSERT INTO psy_plan_weekly_progress
    (plan_id, patient_id, week_number, status, score, notes, session_date, updated_by_name, updated_at)
  VALUES
    (v_plan_id, v_patient_id, 1, 'hadir', 7, 'Sesi pertama berjalan lancar.',
      now() - interval '2 weeks', 'Aqilah (Coach)', now()),
    (v_plan_id, v_patient_id, 2, 'reschedule', NULL, 'Pesakit minta tangguh — ada urusan keluarga.',
      now() - interval '1 week', 'Aqilah (Coach)', now())
  ON CONFLICT (plan_id, week_number) DO UPDATE SET
    status = EXCLUDED.status,
    score = EXCLUDED.score,
    notes = EXCLUDED.notes,
    session_date = EXCLUDED.session_date;

END $$;


-- ── STEP 5: Insert weekly progress untuk plan 777 VIP ────────

DO $$
DECLARE
  v_plan_id UUID;
  v_patient_id UUID;
BEGIN
  SELECT id, patient_id INTO v_plan_id, v_patient_id
  FROM psy_treatment_plans
  WHERE name ILIKE '%777 VIP%' AND status = 'active'
  ORDER BY created_at LIMIT 1;

  IF v_plan_id IS NULL THEN RAISE NOTICE 'Tiada plan 777 VIP — skip'; RETURN; END IF;

  INSERT INTO psy_plan_weekly_progress
    (plan_id, patient_id, week_number, status, score, notes, session_date, updated_by_name, updated_at)
  VALUES
    (v_plan_id, v_patient_id, 1, 'hadir',     9, 'Semangat tinggi, target jelas.',   now() - interval '7 weeks', 'Aqilah (Coach)', now()),
    (v_plan_id, v_patient_id, 2, 'hadir',     8, 'Konsisten dengan gaya hidup.',     now() - interval '6 weeks', 'Aqilah (Coach)', now()),
    (v_plan_id, v_patient_id, 3, 'hadir',     8, 'Berat turun 2kg.',                 now() - interval '5 weeks', 'Aqilah (Coach)', now()),
    (v_plan_id, v_patient_id, 4, 'cancel',  NULL, 'Pesakit sakit — dibatalkan.',     now() - interval '4 weeks', 'Aqilah (Coach)', now()),
    (v_plan_id, v_patient_id, 5, 'hadir',     9, 'Pulih sepenuhnya, mood baik.',     now() - interval '3 weeks', 'Aqilah (Coach)', now()),
    (v_plan_id, v_patient_id, 6, 'hadir',     7, 'Terapi zikir berjalan bagus.',     now() - interval '2 weeks', 'Aqilah (Coach)', now())
  ON CONFLICT (plan_id, week_number) DO UPDATE SET
    status = EXCLUDED.status,
    score = EXCLUDED.score,
    notes = EXCLUDED.notes,
    session_date = EXCLUDED.session_date;

END $$;


-- ── SEMAK KEPUTUSAN ──────────────────────────────────────────

SELECT
  tp.name AS plan_name,
  pp.full_name AS patient_name,
  tp.current_week,
  tp.duration_weeks,
  tp.status,
  COUNT(pw.id) AS minggu_direkod
FROM psy_treatment_plans tp
LEFT JOIN psy_patients pat ON pat.id = tp.patient_id
LEFT JOIN psy_profiles pp ON pp.id = pat.user_id
LEFT JOIN psy_plan_weekly_progress pw ON pw.plan_id = tp.id
GROUP BY tp.id, tp.name, pp.full_name, tp.current_week, tp.duration_weeks, tp.status
ORDER BY tp.created_at;
