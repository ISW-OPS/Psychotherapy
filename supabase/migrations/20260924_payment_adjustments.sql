-- Audit management 23 Sept 2026, Tier 3 (#B1-24 Void/Refund/Correction, #B1-23 test flag).
-- Rujuk: database/schema/06_payments.sql

ALTER TABLE psy_payments DROP CONSTRAINT IF EXISTS psy_payments_status_check;
ALTER TABLE psy_payments ADD CONSTRAINT psy_payments_status_check
  CHECK (status IN ('pending','completed','refunded','failed','voided'));

ALTER TABLE psy_payments ADD COLUMN IF NOT EXISTS is_test BOOLEAN NOT NULL DEFAULT false;

CREATE TABLE IF NOT EXISTS psy_payment_adjustments (
  id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  payment_id         UUID NOT NULL REFERENCES psy_payments(id) ON DELETE CASCADE,
  type               TEXT NOT NULL CHECK (type IN ('void','refund','correction')),
  reason             TEXT NOT NULL,
  amount             NUMERIC(10,2),
  requested_by       UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  requested_by_name  TEXT,
  requested_at       TIMESTAMPTZ DEFAULT now(),
  approved_by        UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  approved_by_name   TEXT,
  approved_at        TIMESTAMPTZ,
  status             TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected')),
  notes              TEXT,
  created_at         TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_payment_adj_payment ON psy_payment_adjustments(payment_id);
CREATE INDEX IF NOT EXISTS idx_payment_adj_status  ON psy_payment_adjustments(status, requested_at);

ALTER TABLE psy_payment_adjustments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff manage payment adjustments" ON psy_payment_adjustments;
CREATE POLICY "Staff manage payment adjustments" ON psy_payment_adjustments FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
