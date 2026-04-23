-- ============================================================
-- FIX: Coach Assignment Columns
-- Run this in Supabase SQL Editor to enable "Assign to me"
-- ============================================================

-- 1. Add coach_id and assigned_at to psy_patients
ALTER TABLE psy_patients
  ADD COLUMN IF NOT EXISTS coach_id UUID REFERENCES psy_profiles(id),
  ADD COLUMN IF NOT EXISTS assigned_at TIMESTAMPTZ;

-- 2. Index for fast coach lookup
CREATE INDEX IF NOT EXISTS idx_psy_patients_coach ON psy_patients(coach_id);

-- 3. Make sure staff can update these columns (policy already covers FOR ALL)
-- No change needed — existing "Staff manage patients" policy covers UPDATE

SELECT 'Fix OK — coach_id + assigned_at columns are ready' AS status;
