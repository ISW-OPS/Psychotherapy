-- ════════════════════════════════════════════════════════════════
-- RLS fix — 27 Jun 2026
-- Tambah UPDATE policy untuk pesakit pada psy_vitals.
-- Tanpa ini patient edit vitals gagal senyap (INSERT ada, UPDATE tiada).
-- Idempotent: DO $$ BEGIN ... EXCEPTION WHEN duplicate_object THEN NULL; END $$
-- ════════════════════════════════════════════════════════════════

DO $$ BEGIN
  CREATE POLICY "Patients update own vitals" ON psy_vitals FOR UPDATE
    USING (
      source = 'patient_self'
      AND patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid())
    )
    WITH CHECK (
      source = 'patient_self'
      AND patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid())
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

SELECT 'Vitals RLS UPDATE policy OK' AS status;
