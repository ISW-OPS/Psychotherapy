-- ============================================================
-- step38_kob_package_recommendation.sql
-- Doctor recommends a treatment package during KOB session.
-- Patient pays for it → signs agreement → doctor marks Selesai → activates everything.
-- ============================================================

ALTER TABLE psy_kob_sessions
  ADD COLUMN IF NOT EXISTS recommended_package_id   TEXT,
  ADD COLUMN IF NOT EXISTS recommended_package_name TEXT,
  ADD COLUMN IF NOT EXISTS recommended_package_price NUMERIC(10,2),
  ADD COLUMN IF NOT EXISTS recommended_at           TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS recommended_by           UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS recommended_by_name      TEXT,
  ADD COLUMN IF NOT EXISTS package_payment_status   TEXT DEFAULT 'pending'
    CHECK (package_payment_status IN ('pending','paid','skipped','na')),
  ADD COLUMN IF NOT EXISTS package_paid_at          TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS package_receipt_ref      TEXT;

COMMENT ON COLUMN psy_kob_sessions.recommended_package_id IS
  'Package recommended by doctor during KOB. Patient must pay before agreement signing.';

-- Extend patient kob_status enum with new transitional states
ALTER TABLE psy_patients DROP CONSTRAINT IF EXISTS psy_patients_kob_status_check;
ALTER TABLE psy_patients ADD CONSTRAINT psy_patients_kob_status_check
  CHECK (kob_status IN (
    'pending_payment',
    'paid',
    'kyc_done',
    'booked',
    'hadir',
    'package_recommended',  -- Doctor picked a package, patient needs to pay
    'package_paid',         -- Patient paid for the package
    'completed',
    'na'
  ));

SELECT 'Step 38 OK — KOB package recommendation ready' AS status;
