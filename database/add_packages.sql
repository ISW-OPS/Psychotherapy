-- ============================================================
-- ADD PACKAGE TRACKING ke patients table
-- Run sekali dalam Supabase SQL Editor
-- ============================================================

ALTER TABLE patients ADD COLUMN IF NOT EXISTS active_package_id TEXT;
ALTER TABLE patients ADD COLUMN IF NOT EXISTS active_package_name TEXT;
ALTER TABLE patients ADD COLUMN IF NOT EXISTS package_purchased_at TIMESTAMPTZ;
ALTER TABLE patients ADD COLUMN IF NOT EXISTS package_expires_at TIMESTAMPTZ;

-- Track package purchase history
CREATE TABLE IF NOT EXISTS package_purchases (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id UUID REFERENCES patients(id) ON DELETE CASCADE NOT NULL,
  package_id TEXT NOT NULL,
  package_name TEXT NOT NULL,
  price NUMERIC(10,2) NOT NULL,
  purchased_at TIMESTAMPTZ DEFAULT now(),
  expires_at TIMESTAMPTZ,
  status TEXT DEFAULT 'pending_payment' CHECK (status IN ('pending_payment','paid','active','expired','cancelled')),
  payment_method TEXT,
  ghl_order_id TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE package_purchases ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Patients manage own purchases" ON package_purchases FOR ALL
  USING (patient_id IN (SELECT id FROM patients WHERE user_id = auth.uid()))
  WITH CHECK (patient_id IN (SELECT id FROM patients WHERE user_id = auth.uid()));

CREATE POLICY "Staff read all purchases" ON package_purchases FOR SELECT
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'staff'));

CREATE POLICY "Staff update purchases" ON package_purchases FOR UPDATE
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'staff'));

CREATE INDEX IF NOT EXISTS idx_purchases_patient ON package_purchases(patient_id);
CREATE INDEX IF NOT EXISTS idx_purchases_status ON package_purchases(status);
