-- ============================================================
-- STEP 15 — Extra KYC fields (marital status, occupation, etc.)
-- Run in Supabase SQL Editor
-- ============================================================

-- 1. Add new columns to psy_kyc_submissions
ALTER TABLE psy_kyc_submissions
  ADD COLUMN IF NOT EXISTS marital_status TEXT,
  ADD COLUMN IF NOT EXISTS occupation TEXT,
  ADD COLUMN IF NOT EXISTS company TEXT,
  ADD COLUMN IF NOT EXISTS emergency_contact_relationship TEXT,
  ADD COLUMN IF NOT EXISTS emergency_contact_email TEXT;

-- 2. Add matching columns to psy_patients (for quick access without joining KYC)
ALTER TABLE psy_patients
  ADD COLUMN IF NOT EXISTS marital_status TEXT,
  ADD COLUMN IF NOT EXISTS occupation TEXT,
  ADD COLUMN IF NOT EXISTS company TEXT;

SELECT 'Step 15 OK — extra KYC fields added' AS status;
