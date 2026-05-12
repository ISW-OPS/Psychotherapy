-- Soft delete: add 'deleted' as valid status for psy_patients
ALTER TABLE psy_patients DROP CONSTRAINT IF EXISTS psy_patients_status_check;
ALTER TABLE psy_patients ADD CONSTRAINT psy_patients_status_check
  CHECK (status IN ('pending_kyc','active','inactive','rejected','deleted'));
