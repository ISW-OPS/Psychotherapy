-- ============================================================
-- step44_daily_schedule.sql
-- Daily schedule template per package (staff defines)
-- + per-patient customized copy (patient can edit)
-- + in-app reminder fires when patient opens app at scheduled time
-- ============================================================

-- Template per package
ALTER TABLE psy_packages
  ADD COLUMN IF NOT EXISTS daily_schedule JSONB DEFAULT '[]'::jsonb;

COMMENT ON COLUMN psy_packages.daily_schedule IS
  'Array of {time:"HH:MM", activity:"text"} — default daily routine for patients on this package.';

-- Patient's customized copy (NULL = follow package template, [] or array = patient-customized)
ALTER TABLE psy_patients
  ADD COLUMN IF NOT EXISTS daily_schedule JSONB;

COMMENT ON COLUMN psy_patients.daily_schedule IS
  'Patient-customized daily schedule. NULL = inherit from active package template. Array = patient has overridden.';

SELECT 'Step 44 OK — daily_schedule columns ready' AS status;
