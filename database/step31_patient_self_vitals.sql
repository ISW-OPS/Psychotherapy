-- ============================================================
-- step31_patient_self_vitals.sql
-- Allow patients to log own BP / HbA1c readings (e.g. taken at home).
-- Add hba1c column + source column to distinguish staff vs patient entries.
-- ============================================================

ALTER TABLE psy_vitals
  ADD COLUMN IF NOT EXISTS hba1c NUMERIC(4,2);

ALTER TABLE psy_vitals
  ADD COLUMN IF NOT EXISTS source TEXT NOT NULL DEFAULT 'staff'
  CHECK (source IN ('staff','patient_self'));

ALTER TABLE psy_vitals
  ADD COLUMN IF NOT EXISTS reading_date DATE;

COMMENT ON COLUMN psy_vitals.hba1c IS 'HbA1c % (e.g. 6.5 = 6.5%)';
COMMENT ON COLUMN psy_vitals.source IS 'Who entered the reading: staff at clinic, or patient self-reported';
COMMENT ON COLUMN psy_vitals.reading_date IS 'Date the reading was actually taken (may differ from created_at for back-dated entries)';

-- Allow patient to insert OWN readings (only with source = patient_self)
DO $$ BEGIN
  CREATE POLICY "Patients insert own vitals" ON psy_vitals FOR INSERT
    WITH CHECK (
      source = 'patient_self'
      AND patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid())
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
