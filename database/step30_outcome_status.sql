-- ============================================================
-- step30_outcome_status.sql
-- Clinical outcome status for reporting & statistics.
-- Separate from system 'status' (active/inactive) — this is treatment outcome.
-- ============================================================

ALTER TABLE psy_patients
  ADD COLUMN IF NOT EXISTS outcome_status TEXT
  CHECK (outcome_status IN ('otw','berhenti','meninggal','completed'));

ALTER TABLE psy_patients
  ADD COLUMN IF NOT EXISTS outcome_status_at TIMESTAMPTZ;

ALTER TABLE psy_patients
  ADD COLUMN IF NOT EXISTS outcome_status_notes TEXT;

CREATE INDEX IF NOT EXISTS idx_psy_patients_outcome_status
  ON psy_patients (outcome_status) WHERE outcome_status IS NOT NULL;

COMMENT ON COLUMN psy_patients.outcome_status IS
  'Clinical outcome: otw=On-going Treatment, berhenti=stopped, meninggal=passed away, completed=selesai rawatan';
