-- STEP 13 — Coach assignment to patients
-- Run in Supabase SQL Editor

ALTER TABLE psy_patients
  ADD COLUMN IF NOT EXISTS coach_id UUID REFERENCES psy_profiles(id),
  ADD COLUMN IF NOT EXISTS assigned_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_psy_patients_coach ON psy_patients(coach_id);

SELECT 'Step 13 OK — coach_id + assigned_at added to psy_patients' AS status;
