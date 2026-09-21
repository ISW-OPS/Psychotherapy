-- Kaedah bayaran manual (transfer/tunai/lain) — dipapar di resit. NULL utk bayaran lama & gateway.
ALTER TABLE psy_payments ADD COLUMN IF NOT EXISTS manual_method TEXT;
ALTER TABLE psy_payments DROP CONSTRAINT IF EXISTS psy_payments_manual_method_check;
ALTER TABLE psy_payments ADD CONSTRAINT psy_payments_manual_method_check
  CHECK (manual_method IS NULL OR manual_method IN ('transfer','cash','other'));
NOTIFY pgrst, 'reload schema';
