-- Audit management 23 Sept 2026, Tier 3 (#B1-27): status penghantaran resit/invois.
-- Rujuk: database/schema/06_payments.sql

ALTER TABLE psy_payments ADD COLUMN IF NOT EXISTS receipt_last_sent_at TIMESTAMPTZ;
ALTER TABLE psy_payments ADD COLUMN IF NOT EXISTS receipt_last_sent_status TEXT;
ALTER TABLE psy_payments DROP CONSTRAINT IF EXISTS psy_payments_receipt_last_sent_status_check;
ALTER TABLE psy_payments ADD CONSTRAINT psy_payments_receipt_last_sent_status_check
  CHECK (receipt_last_sent_status IS NULL OR receipt_last_sent_status IN ('sent','failed'));
