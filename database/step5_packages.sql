-- ============================================================
-- STEP 5 — PSY_PACKAGES + PSY_PACKAGE_PURCHASES
-- ============================================================

CREATE TABLE IF NOT EXISTS psy_packages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  package_id TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  description TEXT,
  price NUMERIC(10,2) DEFAULT 0,
  duration TEXT,
  duration_unit TEXT DEFAULT 'week',
  duration_weeks INT DEFAULT 12,
  icon TEXT DEFAULT '📦',
  bg_color TEXT DEFAULT 'bg-cream',
  tier TEXT,
  is_active BOOLEAN DEFAULT true,
  products JSONB DEFAULT '[]',
  bimbingan JSONB DEFAULT '[]',
  inclusions JSONB DEFAULT '[]',
  coaching_schedule JSONB DEFAULT '[]',
  bio_goals JSONB DEFAULT '[]',
  psycho_goals JSONB DEFAULT '[]',
  social_goals JSONB DEFAULT '[]',
  spiritual_goals JSONB DEFAULT '[]',
  phases JSONB,
  sort_order INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE psy_packages ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN CREATE POLICY "Anyone read active packages" ON psy_packages FOR SELECT USING (true); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "Staff manage packages" ON psy_packages FOR ALL USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff')); EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE TABLE IF NOT EXISTS psy_package_purchases (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id UUID REFERENCES psy_patients(id) ON DELETE CASCADE NOT NULL,
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

ALTER TABLE psy_package_purchases ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN CREATE POLICY "Patients manage own purchases" ON psy_package_purchases FOR ALL USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid())) WITH CHECK (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid())); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "Staff read all purchases" ON psy_package_purchases FOR SELECT USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff')); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "Staff update purchases" ON psy_package_purchases FOR UPDATE USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff')); EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE INDEX IF NOT EXISTS idx_psy_packages_active ON psy_packages(is_active);
CREATE INDEX IF NOT EXISTS idx_psy_packages_sort ON psy_packages(sort_order);
CREATE INDEX IF NOT EXISTS idx_psy_purchases_patient ON psy_package_purchases(patient_id);

SELECT 'Step 5 OK — packages ready' AS status;
