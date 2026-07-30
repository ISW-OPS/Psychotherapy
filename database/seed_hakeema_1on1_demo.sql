-- SEED DEMO — Sesi 1:1 Hakeema (psy_clinical_referrals, source='plan_1on1')
-- Tujuan: isi kad "Sesi 1:1 Hakeema" dashboard coach dgn data sebenar utk uji
-- navigasi tarikh (‹ ›) + isi masa + tandakan selesai, tanpa perlu tanda checkbox
-- hakeema_1on1 di pakej-edit satu-satu.
-- Guna pesakit SEDIA ADA (yg ada pelan rawatan aktif + coach di-assign) — tiada
-- UUID hardcode. Idempotent (ON CONFLICT DO NOTHING ikut unique index sedia ada
-- plan_id+week_number WHERE source='plan_1on1'). Boleh run di TESTING.
-- Padam demo: DELETE FROM psy_clinical_referrals WHERE referred_by_name = 'SEED DEMO';
-- ─────────────────────────────────────────────────────────────────────────

DO $$
DECLARE
  mgr_id   UUID;
  mgr_name TEXT;
  r        RECORD;
  i        INT := 0;
BEGIN
  SELECT id, full_name INTO mgr_id, mgr_name
  FROM psy_profiles WHERE role = 'staff' AND staff_role = 'manager' LIMIT 1;

  FOR r IN (
    SELECT p.id AS patient_id, t.id AS plan_id, COALESCE(t.current_week, 1) AS week_number
    FROM psy_patients p
    JOIN psy_treatment_plans t ON t.patient_id = p.id AND t.status = 'active'
    WHERE p.status = 'active' AND p.coach_id IS NOT NULL
    ORDER BY p.created_at DESC
    LIMIT 3
  ) LOOP
    i := i + 1;
    INSERT INTO psy_clinical_referrals (
      patient_id, plan_id, week_number, source,
      referred_by_name, target_role, target_id, target_name,
      reason, meet_date, priority, status
    ) VALUES (
      r.patient_id, r.plan_id, r.week_number, 'plan_1on1',
      'SEED DEMO', 'manager', mgr_id, COALESCE(mgr_name, 'Hakeema'),
      'Sesi 1:1 Hakeema — Minggu ' || r.week_number, CURRENT_DATE, 'sederhana',
      CASE WHEN i = 1 THEN 'accepted' ELSE 'pending' END
    )
    ON CONFLICT (plan_id, week_number) WHERE source = 'plan_1on1' DO NOTHING;
  END LOOP;
END $$;
