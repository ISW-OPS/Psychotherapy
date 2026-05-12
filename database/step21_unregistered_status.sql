-- Step 21: New patient statuses — unregistered, archived, deceased
-- Run in Supabase SQL Editor after step20_soft_delete.sql

ALTER TABLE psy_patients DROP CONSTRAINT IF EXISTS psy_patients_status_check;
ALTER TABLE psy_patients ADD CONSTRAINT psy_patients_status_check
  CHECK (status IN ('pending_kyc','active','inactive','rejected','deleted','unregistered','archived','deceased'));

-- Add email index for fast auto-link lookup on patient signup
CREATE INDEX IF NOT EXISTS idx_psy_patients_email ON psy_patients(email);

-- Default status for new staff-created patients going forward is 'unregistered'
-- (no DB default change needed — handled in application layer)

SELECT 'Step 21 OK — unregistered / archived / deceased statuses added' AS status;
