-- Add reference_code column to store old patient codes (e.g. OB'25-0710, NLC'25-0177)
ALTER TABLE psy_patients ADD COLUMN IF NOT EXISTS reference_code TEXT;
