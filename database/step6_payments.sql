-- ============================================================
-- STEP 6 — PSY_PAYMENTS + PSY_ORDERS
-- ============================================================

CREATE TABLE IF NOT EXISTS psy_payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  receipt_ref TEXT UNIQUE NOT NULL,
  patient_id UUID REFERENCES psy_patients(id),
  user_id UUID REFERENCES psy_profiles(id),
  items JSONB DEFAULT '[]',
  subtotal NUMERIC(10,2) DEFAULT 0,
  service_charge NUMERIC(10,2) DEFAULT 0,
  sst NUMERIC(10,2) DEFAULT 0,
  total NUMERIC(10,2) NOT NULL,
  payment_method TEXT CHECK (payment_method IN ('fpx','card','transfer','ghl','manual')),
  status TEXT DEFAULT 'completed' CHECK (status IN ('pending','completed','refunded','failed')),
  ghl_transaction_id TEXT,
  notes TEXT,
  paid_at TIMESTAMPTZ DEFAULT now(),
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE psy_payments ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN CREATE POLICY "Patients read own payments" ON psy_payments FOR SELECT USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid())); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "Patients insert own payments" ON psy_payments FOR INSERT WITH CHECK (true); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "Staff manage all payments" ON psy_payments FOR ALL USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff')); EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE TABLE IF NOT EXISTS psy_orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_ref TEXT UNIQUE NOT NULL,
  patient_id UUID NOT NULL,
  items JSONB NOT NULL DEFAULT '[]',
  total NUMERIC(10,2) DEFAULT 0,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending','paid','packed','shipped','delivered','cancelled')),
  delivery_method TEXT DEFAULT 'pos' CHECK (delivery_method IN ('pickup','pos')),
  delivery_address TEXT,
  courier TEXT,
  tracking_number TEXT,
  tracking_photo_url TEXT,
  notes TEXT,
  paid_at TIMESTAMPTZ,
  packed_at TIMESTAMPTZ,
  shipped_at TIMESTAMPTZ,
  delivered_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE psy_orders ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN CREATE POLICY "Patient view own orders" ON psy_orders FOR SELECT USING (patient_id = auth.uid()); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "Patient insert own orders" ON psy_orders FOR INSERT WITH CHECK (patient_id = auth.uid()); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "Patient confirm delivery" ON psy_orders FOR UPDATE USING (patient_id = auth.uid() AND status = 'shipped') WITH CHECK (status = 'delivered'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "Staff manage orders" ON psy_orders FOR ALL USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff')); EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE INDEX IF NOT EXISTS idx_psy_payments_patient ON psy_payments(patient_id);
CREATE INDEX IF NOT EXISTS idx_psy_payments_receipt ON psy_payments(receipt_ref);

SELECT 'Step 6 OK — payments + orders ready' AS status;
