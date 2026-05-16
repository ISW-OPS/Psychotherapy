-- ============================================================
-- step35_kob_skip_payment.sql
-- Simplification: payment is handled externally (GHL), not in this system.
-- New patients land directly at KYC step.
-- When GHL integration ready, can revert default to 'pending_payment'
-- and re-introduce pay-banner.
-- ============================================================

-- Change default for new patients: skip payment, start at 'paid' (assumed paid externally)
ALTER TABLE psy_patients ALTER COLUMN kob_status SET DEFAULT 'paid';

-- Bulk-update existing patients stuck at 'pending_payment' → 'paid'
UPDATE psy_patients SET kob_status = 'paid' WHERE kob_status = 'pending_payment';

COMMENT ON COLUMN psy_patients.kob_status IS
  'KOB lifecycle. Payment external (GHL). New self-registered patient starts at paid → kyc_done → booked → hadir → completed. Staff-created can be na (grandfathered).';

SELECT 'Step 35 OK — payment step skipped, KYC is now first step' AS status;
