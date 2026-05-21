-- run_all_migrations.sql — GENERATED 2026-05-21T01:39:26Z

-- ── FILE: step1_profiles.sql ──
-- ============================================================
-- STEP 1 — PSY_PROFILES  (idempotent)
-- ============================================================

CREATE TABLE IF NOT EXISTS psy_profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name TEXT NOT NULL,
  role TEXT NOT NULL CHECK (role IN ('patient','staff')),
  phone TEXT,
  email TEXT,
  avatar_url TEXT,
  registration_no TEXT,
  specialization TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE psy_profiles ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN CREATE POLICY "Read all profiles authenticated" ON psy_profiles FOR SELECT USING (auth.role() = 'authenticated'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "Update own profile" ON psy_profiles FOR UPDATE USING (auth.uid() = id); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "Insert own profile" ON psy_profiles FOR INSERT WITH CHECK (auth.uid() = id OR auth.role() = 'service_role'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.psy_profiles (id, full_name, role, email)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', split_part(NEW.email, '@', 1)),
    COALESCE(NEW.raw_user_meta_data->>'role', 'patient'),
    NEW.email
  );
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE LOG 'Error creating profile: %', SQLERRM;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

CREATE INDEX IF NOT EXISTS idx_psy_profiles_role ON psy_profiles(role);

SELECT 'Step 1 OK — psy_profiles ready' AS status;


-- ── FILE: step2_patients.sql ──
-- ============================================================
-- STEP 2 — PSY_PATIENTS + PSY_KYC_SUBMISSIONS  (idempotent)
-- ============================================================

CREATE TABLE IF NOT EXISTS psy_patients (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES psy_profiles(id),
  mrn TEXT UNIQUE NOT NULL,
  ic_number TEXT,
  date_of_birth DATE,
  gender TEXT CHECK (gender IN ('M','F')),
  address TEXT,
  emergency_contact_name TEXT,
  emergency_contact_phone TEXT,
  insurance_provider TEXT,
  insurance_policy TEXT,
  referral_source TEXT,
  medical_condition TEXT,
  condition_duration TEXT,
  medical_notes TEXT,
  active_package_id TEXT,
  active_package_name TEXT,
  package_purchased_at TIMESTAMPTZ,
  package_expires_at TIMESTAMPTZ,
  status TEXT DEFAULT 'active' CHECK (status IN ('pending_kyc','active','inactive','rejected')),
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE psy_patients ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN CREATE POLICY "Staff manage patients" ON psy_patients FOR ALL USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff')); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "Patients read own record" ON psy_patients FOR SELECT USING (user_id = auth.uid()); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "Patients update own record" ON psy_patients FOR UPDATE USING (user_id = auth.uid()); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "Patients insert own record" ON psy_patients FOR INSERT WITH CHECK (user_id = auth.uid()); EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE TABLE IF NOT EXISTS psy_kyc_submissions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES psy_profiles(id),
  patient_name TEXT NOT NULL,
  ic_number TEXT,
  date_of_birth DATE,
  gender TEXT,
  phone TEXT,
  email TEXT,
  address TEXT,
  emergency_contact TEXT,
  emergency_contact_name TEXT,
  emergency_contact_phone TEXT,
  medical_condition TEXT,
  condition_duration TEXT,
  medical_notes TEXT,
  insurance_info JSONB,
  documents JSONB DEFAULT '{}',
  consent_data_processing BOOLEAN DEFAULT false,
  consent_health_records BOOLEAN DEFAULT false,
  consent_research BOOLEAN DEFAULT false,
  consent_marketing BOOLEAN DEFAULT false,
  referral_source TEXT,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected','needs_docs')),
  reviewed_by UUID REFERENCES psy_profiles(id),
  review_notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE psy_kyc_submissions ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN CREATE POLICY "Staff manage KYC" ON psy_kyc_submissions FOR ALL USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff')); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "Patients read own KYC" ON psy_kyc_submissions FOR SELECT USING (user_id = auth.uid()); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "Patients insert own KYC" ON psy_kyc_submissions FOR INSERT WITH CHECK (user_id = auth.uid()); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "Patients update own KYC" ON psy_kyc_submissions FOR UPDATE USING (user_id = auth.uid()); EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE INDEX IF NOT EXISTS idx_psy_patients_user ON psy_patients(user_id);
CREATE INDEX IF NOT EXISTS idx_psy_patients_mrn ON psy_patients(mrn);

SELECT 'Step 2 OK — psy_patients + psy_kyc_submissions ready' AS status;


-- ── FILE: step3_audit.sql ──
-- ============================================================
-- STEP 3 — PSY_AUDIT_LOG  (idempotent)
-- ============================================================

CREATE TABLE IF NOT EXISTS psy_audit_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_id UUID,
  actor_name TEXT,
  actor_role TEXT,
  action TEXT NOT NULL,
  target TEXT,
  meta JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE psy_audit_log ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN CREATE POLICY "Staff read audit" ON psy_audit_log FOR SELECT USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff')); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "All authenticated insert audit" ON psy_audit_log FOR INSERT WITH CHECK (auth.uid() IS NOT NULL); EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE INDEX IF NOT EXISTS idx_psy_audit_created ON psy_audit_log(created_at);

SELECT 'Step 3 OK — psy_audit_log ready' AS status;


-- ── FILE: step4_plans.sql ──
-- ============================================================
-- STEP 4 — TREATMENT PLANS + APPOINTMENTS + NOTIFICATIONS
-- Run selepas step3_audit.sql
-- ============================================================

CREATE TABLE IF NOT EXISTS psy_appointments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id UUID REFERENCES psy_patients(id),
  staff_id UUID REFERENCES psy_profiles(id),
  patient_name TEXT,
  staff_name TEXT,
  service TEXT NOT NULL,
  appointment_time TIMESTAMPTZ NOT NULL,
  duration_min INT DEFAULT 30,
  status TEXT DEFAULT 'scheduled' CHECK (status IN ('scheduled','checked_in','in_progress','completed','no_show','cancelled')),
  room TEXT,
  notes TEXT,
  ghl_booking_id TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE psy_appointments ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  CREATE POLICY "Staff manage appointments" ON psy_appointments FOR ALL USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "Patients read own appointments" ON psy_appointments FOR SELECT USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "Patients insert own appointments" ON psy_appointments FOR INSERT WITH CHECK (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "Patients update own appointments" ON psy_appointments FOR UPDATE USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE TABLE IF NOT EXISTS psy_treatment_plans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id UUID REFERENCES psy_patients(id) NOT NULL,
  doctor_id UUID REFERENCES psy_profiles(id),
  name TEXT NOT NULL,
  template TEXT,
  duration_unit TEXT DEFAULT 'week',
  duration_weeks INT DEFAULT 13,
  current_week INT DEFAULT 1,
  bio_goals JSONB DEFAULT '[]',
  psycho_goals JSONB DEFAULT '[]',
  social_goals JSONB DEFAULT '[]',
  spiritual_goals JSONB DEFAULT '[]',
  coaching_schedule JSONB DEFAULT '[]',
  status TEXT DEFAULT 'active' CHECK (status IN ('draft','active','completed','paused')),
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE psy_treatment_plans ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  CREATE POLICY "Staff manage plans" ON psy_treatment_plans FOR ALL USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "Patients read own plans" ON psy_treatment_plans FOR SELECT USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "Patients insert own plans" ON psy_treatment_plans FOR INSERT WITH CHECK (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE TABLE IF NOT EXISTS psy_plan_weekly_progress (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id UUID REFERENCES psy_treatment_plans(id) ON DELETE CASCADE NOT NULL,
  patient_id UUID REFERENCES psy_patients(id) ON DELETE CASCADE NOT NULL,
  week_number INT NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('booked','hadir','reschedule','cancel','pending')),
  score INT CHECK (score BETWEEN 0 AND 10),
  notes TEXT,
  coaching_checks JSONB DEFAULT '{}',
  appointment_id UUID REFERENCES psy_appointments(id) ON DELETE SET NULL,
  updated_by UUID REFERENCES psy_profiles(id),
  updated_by_name TEXT,
  session_date TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (plan_id, week_number)
);

ALTER TABLE psy_plan_weekly_progress ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  CREATE POLICY "Staff manage weekly progress" ON psy_plan_weekly_progress FOR ALL USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "Patients read own progress" ON psy_plan_weekly_progress FOR SELECT USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "Patients insert own progress" ON psy_plan_weekly_progress FOR INSERT WITH CHECK (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "Patients update own progress" ON psy_plan_weekly_progress FOR UPDATE USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE TABLE IF NOT EXISTS psy_plan_check_ins (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id UUID REFERENCES psy_treatment_plans(id) ON DELETE CASCADE NOT NULL,
  patient_id UUID REFERENCES psy_patients(id) ON DELETE CASCADE NOT NULL,
  pillar TEXT NOT NULL CHECK (pillar IN ('bio','psycho','social','spiritual')),
  goal_index INT NOT NULL,
  goal_text TEXT,
  completed_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (plan_id, pillar, goal_index)
);

ALTER TABLE psy_plan_check_ins ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  CREATE POLICY "Patients manage own check-ins" ON psy_plan_check_ins FOR ALL USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid())) WITH CHECK (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "Staff read check-ins" ON psy_plan_check_ins FOR SELECT USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE TABLE IF NOT EXISTS psy_plan_compliance (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id UUID REFERENCES psy_treatment_plans(id) ON DELETE CASCADE NOT NULL,
  patient_id UUID REFERENCES psy_patients(id) ON DELETE CASCADE NOT NULL,
  week_number INT NOT NULL,
  madu_sudu INT,
  nafas_kali INT,
  bumi_minit INT,
  berjemur BOOLEAN,
  pantang BOOLEAN,
  kelapa_kali INT,
  kolon_kali INT,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (plan_id, week_number)
);

ALTER TABLE psy_plan_compliance ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  CREATE POLICY "Staff manage compliance" ON psy_plan_compliance FOR ALL USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "Patients manage own compliance" ON psy_plan_compliance FOR ALL USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid())) WITH CHECK (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE TABLE IF NOT EXISTS psy_notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES psy_profiles(id) ON DELETE CASCADE NOT NULL,
  type TEXT DEFAULT 'system' CHECK (type IN ('appointment','order','plan','system')),
  title TEXT NOT NULL,
  body TEXT,
  link TEXT,
  is_read BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE psy_notifications ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  CREATE POLICY "Users read own notifications" ON psy_notifications FOR SELECT USING (user_id = auth.uid());
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "Users update own notifications" ON psy_notifications FOR UPDATE USING (user_id = auth.uid());
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "Anyone insert notifications" ON psy_notifications FOR INSERT WITH CHECK (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE INDEX IF NOT EXISTS idx_psy_appointments_time ON psy_appointments(appointment_time);
CREATE INDEX IF NOT EXISTS idx_psy_appointments_patient ON psy_appointments(patient_id);
CREATE INDEX IF NOT EXISTS idx_psy_weekly_plan ON psy_plan_weekly_progress(plan_id);
CREATE INDEX IF NOT EXISTS idx_psy_weekly_patient ON psy_plan_weekly_progress(patient_id);
CREATE INDEX IF NOT EXISTS idx_psy_compliance_plan ON psy_plan_compliance(plan_id, week_number);
CREATE INDEX IF NOT EXISTS idx_psy_notifications_user ON psy_notifications(user_id, is_read, created_at DESC);

SELECT 'Step 4 OK — plans + appointments + notifications ready' AS status;


-- ── FILE: step5_packages.sql ──
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


-- ── FILE: step6_payments.sql ──
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


-- ── FILE: step7_checkins.sql ──
-- ============================================================
-- STEP 7 — PSY_DAILY_CHECKINS
-- ============================================================

CREATE TABLE IF NOT EXISTS psy_daily_checkins (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id UUID REFERENCES psy_patients(id) ON DELETE CASCADE NOT NULL,
  checkin_date DATE DEFAULT CURRENT_DATE NOT NULL,
  mood_score INT CHECK (mood_score BETWEEN 1 AND 10),
  energy_score INT CHECK (energy_score BETWEEN 1 AND 10),
  sleep_quality INT CHECK (sleep_quality BETWEEN 1 AND 10),
  sleep_hours NUMERIC(3,1),
  symptoms JSONB DEFAULT '[]',
  activities JSONB DEFAULT '[]',
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (patient_id, checkin_date)
);

ALTER TABLE psy_daily_checkins ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN CREATE POLICY "Patients manage daily check-ins" ON psy_daily_checkins FOR ALL USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid())) WITH CHECK (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid())); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "Staff read daily check-ins" ON psy_daily_checkins FOR SELECT USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff')); EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE INDEX IF NOT EXISTS idx_psy_checkins_patient ON psy_daily_checkins(patient_id);

SELECT 'Step 7 OK — psy_daily_checkins ready' AS status;


-- ── FILE: step8_library.sql ──
-- ============================================================
-- STEP 8 — PSY_LIBRARY_ITEMS
-- ============================================================

CREATE TABLE IF NOT EXISTS psy_library_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  item_id TEXT UNIQUE,
  title TEXT NOT NULL,
  description TEXT,
  content_type TEXT,
  content_url TEXT,
  category TEXT,
  icon TEXT DEFAULT '📄',
  gradient TEXT DEFAULT 'from-navy to-teal',
  content_body TEXT,
  is_active BOOLEAN DEFAULT true,
  sort_order INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE psy_library_items ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN CREATE POLICY "Anyone read library" ON psy_library_items FOR SELECT USING (true); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "Staff manage library" ON psy_library_items FOR ALL USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff')); EXCEPTION WHEN duplicate_object THEN NULL; END $$;

INSERT INTO psy_library_items (item_id, title, description, content_type, category, icon, gradient, sort_order) VALUES
  ('bps-s-intro', 'Apa itu BPS-S model?', 'Dr. Hamzah menerangkan 4 pillar holistik Ibn Sina', 'Video · 8 min', 'navy', '🎥', 'from-navy to-teal', 1),
  ('santapan-panduan', 'Santapan Fitrah: Panduan Harian', 'Resipi + cara penyediaan untuk 7 hari pertama', 'Article · 5 min', 'green', '📝', 'from-green to-gold-dark', 2),
  ('zikir-syifa', 'Zikir Pagi Petang Syifa', 'Audio + transliterasi untuk amalan harian', 'Doa & Zikir', 'terracotta', '🕌', 'from-terracotta to-gold-dark', 3),
  ('breathing-muraqabah', 'Breathing & Muraqabah', 'Teknik pernafasan untuk ketenangan mental', 'Exercise · 15 min', 'gold', '🧘‍♀️', 'from-gold to-green', 4),
  ('faq-baru', '10 Soalan Lazim Pesakit Baru', 'Apa yang perlu anda tahu sebelum memulakan', 'FAQ', 'teal', '💬', 'from-teal to-navy', 5),
  ('mood-tracker', 'Mood & Progress Tracker', 'PDF printable untuk rekod harian', 'Worksheet', 'ink', '📊', 'from-navy to-terracotta', 6)
ON CONFLICT (item_id) DO NOTHING;

SELECT 'Step 8 OK — psy_library_items ready' AS status;


-- ── FILE: step9_products.sql ──
-- ============================================================
-- STEP 9 — PSY_PRODUCTS
-- ============================================================

CREATE TABLE IF NOT EXISTS psy_products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  description TEXT,
  category TEXT,
  price NUMERIC(10,2) DEFAULT 0,
  stock INT,
  icon TEXT DEFAULT '📦',
  bg_color TEXT DEFAULT 'bg-cream',
  is_active BOOLEAN DEFAULT true,
  sort_order INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE psy_products ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN CREATE POLICY "Anyone read products" ON psy_products FOR SELECT USING (true); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "Staff manage products" ON psy_products FOR ALL USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff')); EXCEPTION WHEN duplicate_object THEN NULL; END $$;

INSERT INTO psy_products (product_id, name, description, category, price, icon, bg_color, sort_order) VALUES
  ('madu-shifa-500g',  'Madu Shifa 500g',        'Pure raw honey · acacia',            'Madu',           85,  '🍯', 'bg-gold-light',       1),
  ('madu-kelulut',     'Madu Kelulut 400g',       'Stingless bee honey',                'Madu',          120,  '🍯', 'bg-gold-light',       2),
  ('jus-halia',        'Jus Halia Concentrate',   '250ml · 100% natural',               'Herba',          45,  '🌿', 'bg-green-light',      3),
  ('herba-zaitun',     'Minyak Zaitun Tulen',     '500ml · cold-pressed',               'Herba',          65,  '🫒', 'bg-green-light',      4),
  ('magnesium',        'Magnesium Glycinate',      '60 caps · 200mg',                    'Supplements',    55,  '💊', 'bg-navy-light',       5),
  ('vitamin-d',        'Vitamin D3 5000IU',        '90 softgels',                        'Supplements',    48,  '☀️', 'bg-gold-light',       6),
  ('santapan-fitrah',  'Santapan Fitrah Set',      '7-day starter pack',                 'Santapan Fitrah',220, '🌱', 'bg-terracotta-light', 7),
  ('rahsia-syifa',     'Rahsia Syifa Book',        'Ibn Sina & modern med',              'Books',          35,  '📖', 'bg-navy-light',       8),
  ('doa-syifa-book',   'Kitab Doa Syifa',          'Tafsir + transliterasi',             'Books',          28,  '📖', 'bg-terracotta-light', 9)
ON CONFLICT (product_id) DO NOTHING;

SELECT 'Step 9 OK — psy_products ready' AS status;


-- ── FILE: step10_announcements.sql ──
-- ============================================================
-- STEP 10 — PSY_ANNOUNCEMENTS
-- ============================================================

CREATE TABLE IF NOT EXISTS psy_announcements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  body TEXT,
  tag TEXT,
  bg TEXT DEFAULT 'from-navy to-green-dark',
  cta_label TEXT,
  cta_url TEXT,
  is_active BOOLEAN DEFAULT true,
  sort_order INT DEFAULT 0,
  starts_at TIMESTAMPTZ,
  ends_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE psy_announcements ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN CREATE POLICY "Anyone read active announcements" ON psy_announcements FOR SELECT USING (is_active = true); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "Staff manage announcements" ON psy_announcements FOR ALL USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff')); EXCEPTION WHEN duplicate_object THEN NULL; END $$;

INSERT INTO psy_announcements (title, body, tag, bg, cta_label, cta_url, sort_order) VALUES
  ('Kelas Mindfulness Percuma', 'Setiap Sabtu 9AM — Sertai sesi meditasi & pernafasan bersama Coach Izzah.', 'Kelas Minggu Ini', 'from-navy to-teal', 'Daftar Sekarang', 'https://wa.me/60123456789', 1),
  ('Program Detox Digital', 'Cabaran 7 hari kurangkan screen time untuk kesejahteraan mental anda.', 'Challenge Baru', 'from-green-dark to-teal', 'Sertai Cabaran', null, 2),
  ('Pakej Ramadan Khas', 'Rawatan holistik dengan fokus spiritual — promosi sehingga hujung bulan.', 'Promosi', 'from-navy to-green-dark', 'Lihat Pakej', 'pakej.html', 3)
ON CONFLICT DO NOTHING;

SELECT 'Step 10 OK — psy_announcements ready' AS status;


-- ── FILE: step11_staff_roles.sql ──
-- ============================================================
-- STEP 11 — STAFF SUB-ROLES
-- Tambah staff_role ke psy_profiles
-- Run ini di Supabase SQL Editor
-- ============================================================

-- 1. Tambah kolum staff_role
ALTER TABLE psy_profiles
  ADD COLUMN IF NOT EXISTS staff_role TEXT CHECK (staff_role IN ('admin', 'coach', 'manager'));

-- 2. Staff yang ada sekarang → set admin by default supaya tak kena lock out
UPDATE psy_profiles
  SET staff_role = 'admin'
  WHERE role = 'staff' AND staff_role IS NULL;

-- 3. Update trigger supaya staff baru boleh dapat staff_role dari metadata
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.psy_profiles (id, full_name, role, email, staff_role)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', split_part(NEW.email, '@', 1)),
    COALESCE(NEW.raw_user_meta_data->>'role', 'patient'),
    NEW.email,
    CASE
      WHEN COALESCE(NEW.raw_user_meta_data->>'role', 'patient') = 'staff'
      THEN COALESCE(NEW.raw_user_meta_data->>'staff_role', 'coach')
      ELSE NULL
    END
  );
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE LOG 'Error creating profile: %', SQLERRM;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

SELECT 'Step 11 OK — staff_role column added' AS status;


-- ── FILE: step12_library_media.sql ──
-- ============================================================
-- STEP 12 — Add thumbnail_url to psy_library_items
-- Run in Supabase SQL Editor
-- ============================================================

ALTER TABLE psy_library_items
  ADD COLUMN IF NOT EXISTS thumbnail_url TEXT;

-- Create storage bucket for library media (run once)
-- In Supabase Dashboard → Storage → New Bucket → "library-media" → Public
-- OR run via API. Manual step needed in dashboard.

SELECT 'Step 12 OK — library thumbnail_url column added' AS status;


-- ── FILE: step13_coach_assignment.sql ──
-- STEP 13 — Coach assignment to patients
-- Run in Supabase SQL Editor

ALTER TABLE psy_patients
  ADD COLUMN IF NOT EXISTS coach_id UUID REFERENCES psy_profiles(id),
  ADD COLUMN IF NOT EXISTS assigned_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_psy_patients_coach ON psy_patients(coach_id);

SELECT 'Step 13 OK — coach_id + assigned_at added to psy_patients' AS status;


-- ── FILE: step14_doctor_role.sql ──
-- ============================================================
-- STEP 14 — Doctor Staff Role
-- Run in Supabase SQL Editor
-- ============================================================

-- 1. Update CHECK constraint on staff_role to include 'doctor'
ALTER TABLE psy_profiles
  DROP CONSTRAINT IF EXISTS psy_profiles_staff_role_check;

ALTER TABLE psy_profiles
  ADD CONSTRAINT psy_profiles_staff_role_check
  CHECK (staff_role IN ('admin', 'doctor', 'coach', 'manager'));

-- 2. Verify
SELECT 'Step 14 OK — doctor role added to staff_role constraint' AS status;


-- ── FILE: step15_kyc_extra_fields.sql ──
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


-- ── FILE: step16_missing_tables.sql ──
-- ============================================================
-- STEP 16 — MISSING TABLES: vitals, coaching, risk, feedback
-- Run in Supabase SQL Editor
-- ============================================================

-- 1. PSY_VITALS
CREATE TABLE IF NOT EXISTS psy_vitals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id UUID REFERENCES psy_patients(id) ON DELETE CASCADE NOT NULL,
  recorded_by UUID REFERENCES psy_profiles(id),
  recorded_by_name TEXT,
  bp_systolic INT,
  bp_diastolic INT,
  heart_rate INT,
  spo2 NUMERIC(5,2),
  temperature NUMERIC(4,1),
  weight NUMERIC(5,2),
  height NUMERIC(5,1),
  bmi NUMERIC(4,1),
  waist_cm NUMERIC(5,1),
  rbs NUMERIC(6,2),
  phq2_score INT,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE psy_vitals ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  CREATE POLICY "Staff manage vitals" ON psy_vitals FOR ALL
    USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "Patients read own vitals" ON psy_vitals FOR SELECT
    USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE INDEX IF NOT EXISTS idx_psy_vitals_patient ON psy_vitals(patient_id, created_at DESC);

-- 2. PSY_COACHING_SESSIONS
CREATE TABLE IF NOT EXISTS psy_coaching_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id UUID REFERENCES psy_patients(id) ON DELETE CASCADE NOT NULL,
  coach_id UUID REFERENCES psy_profiles(id),
  patient_name TEXT,
  pillar TEXT CHECK (pillar IN ('bio','psycho','social','spiritual')),
  session_date TIMESTAMPTZ DEFAULT now(),
  duration_min INT DEFAULT 60,
  mood_pre INT CHECK (mood_pre BETWEEN 1 AND 10),
  mood_post INT CHECK (mood_post BETWEEN 1 AND 10),
  notes TEXT,
  goals_discussed JSONB DEFAULT '[]',
  homework JSONB DEFAULT '[]',
  status TEXT DEFAULT 'completed' CHECK (status IN ('completed','no_show','cancelled')),
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE psy_coaching_sessions ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  CREATE POLICY "Staff manage coaching sessions" ON psy_coaching_sessions FOR ALL
    USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "Patients read own coaching sessions" ON psy_coaching_sessions FOR SELECT
    USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE INDEX IF NOT EXISTS idx_psy_coaching_patient ON psy_coaching_sessions(patient_id, session_date DESC);

-- 3. PSY_RISK_ALERTS
CREATE TABLE IF NOT EXISTS psy_risk_alerts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id UUID REFERENCES psy_patients(id) ON DELETE CASCADE NOT NULL,
  patient_name TEXT,
  created_by UUID REFERENCES psy_profiles(id),
  created_by_name TEXT,
  severity TEXT DEFAULT 'medium' CHECK (severity IN ('low','medium','high','critical')),
  category TEXT,
  description TEXT,
  status TEXT DEFAULT 'open' CHECK (status IN ('open','acknowledged','resolved')),
  acknowledged_by UUID REFERENCES psy_profiles(id),
  resolved_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE psy_risk_alerts ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  CREATE POLICY "Staff manage risk alerts" ON psy_risk_alerts FOR ALL
    USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE INDEX IF NOT EXISTS idx_psy_risk_patient ON psy_risk_alerts(patient_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_psy_risk_status ON psy_risk_alerts(status, created_at DESC);

-- 4. PSY_WEEKLY_FEEDBACK
CREATE TABLE IF NOT EXISTS psy_weekly_feedback (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id UUID REFERENCES psy_treatment_plans(id) ON DELETE CASCADE NOT NULL,
  patient_id UUID REFERENCES psy_patients(id) ON DELETE CASCADE NOT NULL,
  week_number INT NOT NULL,
  rating INT CHECK (rating BETWEEN 1 AND 5),
  comment TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (plan_id, week_number)
);

ALTER TABLE psy_weekly_feedback ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  CREATE POLICY "Patients manage own weekly feedback" ON psy_weekly_feedback FOR ALL
    USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()))
    WITH CHECK (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "Staff read all weekly feedback" ON psy_weekly_feedback FOR SELECT
    USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE INDEX IF NOT EXISTS idx_psy_feedback_plan ON psy_weekly_feedback(plan_id, week_number);

SELECT 'Step 16 OK — psy_vitals, psy_coaching_sessions, psy_risk_alerts, psy_weekly_feedback ready' AS status;


-- ── FILE: step17_inventory.sql ──
-- step17_inventory.sql — placeholder (notes only, no DDL)
/*
Bimbingan Peminuman madu
Bimbingan Diet dan Nutrisi
Bimbingan Zikir bersanad
*/


-- ── FILE: step18_reference_code.sql ──
-- Add reference_code column to store old patient codes (e.g. OB'25-0710, NLC'25-0177)
ALTER TABLE psy_patients ADD COLUMN IF NOT EXISTS reference_code TEXT;


-- ── FILE: step19_kyc_patients_sync.sql ──
-- Add missing columns to psy_patients for full form sync (idempotent)
ALTER TABLE psy_patients ADD COLUMN IF NOT EXISTS company TEXT;
ALTER TABLE psy_patients ADD COLUMN IF NOT EXISTS referral_source TEXT;
ALTER TABLE psy_patients ADD COLUMN IF NOT EXISTS condition_duration TEXT;
ALTER TABLE psy_patients ADD COLUMN IF NOT EXISTS emergency_contact_ic TEXT;
ALTER TABLE psy_patients ADD COLUMN IF NOT EXISTS reference_code TEXT;
ALTER TABLE psy_patients ADD COLUMN IF NOT EXISTS documents JSONB DEFAULT '{}';
ALTER TABLE psy_kyc_submissions ADD COLUMN IF NOT EXISTS emergency_contact_ic TEXT;

INSERT INTO storage.buckets (id, name, public) VALUES ('medical-reports', 'medical-reports', false) ON CONFLICT DO NOTHING;

DO $$ BEGIN
  CREATE POLICY "Staff can upload medical reports" ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'medical-reports' AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "Staff can read all medical reports" ON storage.objects
    FOR SELECT TO authenticated
    USING (bucket_id = 'medical-reports' AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "Patients can upload own medical reports" ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'medical-reports' AND (storage.foldername(name))[1] = 'patient' AND EXISTS (SELECT 1 FROM psy_patients WHERE user_id = auth.uid()));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "Patients can read own medical reports" ON storage.objects
    FOR SELECT TO authenticated
    USING (bucket_id = 'medical-reports' AND EXISTS (SELECT 1 FROM psy_patients WHERE user_id = auth.uid() AND id::text = (storage.foldername(name))[2]));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;


-- ── FILE: step20_soft_delete.sql ──
-- Soft delete: add 'deleted' as valid status for psy_patients
ALTER TABLE psy_patients DROP CONSTRAINT IF EXISTS psy_patients_status_check;
ALTER TABLE psy_patients ADD CONSTRAINT psy_patients_status_check
  CHECK (status IN ('pending_kyc','active','inactive','rejected','deleted'));


-- ── FILE: step21_unregistered_status.sql ──
-- Step 21: New patient statuses — unregistered, archived, deceased
-- Run in Supabase SQL Editor after step20_soft_delete.sql

ALTER TABLE psy_patients DROP CONSTRAINT IF EXISTS psy_patients_status_check;
ALTER TABLE psy_patients ADD CONSTRAINT psy_patients_status_check
  CHECK (status IN ('pending_kyc','active','inactive','rejected','deleted','unregistered','archived','deceased'));

-- Add email column + index for fast auto-link lookup on patient signup
ALTER TABLE psy_patients ADD COLUMN IF NOT EXISTS email TEXT;
CREATE INDEX IF NOT EXISTS idx_psy_patients_email ON psy_patients(email);

-- Default status for new staff-created patients going forward is 'unregistered'
-- (no DB default change needed — handled in application layer)

SELECT 'Step 21 OK — unregistered / archived / deceased statuses added' AS status;


-- ── FILE: step22_session_type.sql ──
-- Add session_type and consultation_done status to psy_plan_weekly_progress

-- 1. Add session_type column (f2f / online)
ALTER TABLE psy_plan_weekly_progress
  ADD COLUMN IF NOT EXISTS session_type TEXT NOT NULL DEFAULT 'f2f'
  CHECK (session_type IN ('f2f', 'online'));

-- 2. Add consultation_done to status constraint
ALTER TABLE psy_plan_weekly_progress
  DROP CONSTRAINT IF EXISTS psy_plan_weekly_progress_status_check;

ALTER TABLE psy_plan_weekly_progress
  ADD CONSTRAINT psy_plan_weekly_progress_status_check
  CHECK (status IN ('pending', 'booked', 'hadir', 'consultation_done', 'reschedule', 'cancel', 'dna'));


-- ── FILE: step23_dna_reports.sql ──
-- DNA Reports table (idempotent)
CREATE TABLE IF NOT EXISTS psy_dna_reports (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id      UUID NOT NULL REFERENCES psy_patients(id) ON DELETE CASCADE,
  file_name       TEXT NOT NULL,
  file_path       TEXT NOT NULL,
  file_url        TEXT NOT NULL,
  notes           TEXT,
  uploaded_by     UUID REFERENCES auth.users(id),
  uploaded_by_name TEXT,
  uploaded_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE psy_dna_reports ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "staff_dna_all" ON psy_dna_reports FOR ALL
    USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "patient_dna_read" ON psy_dna_reports FOR SELECT
    USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;


-- ── FILE: step24_session_notes.sql ──
-- Merge coaching session notes into weekly progress (single source of truth)
ALTER TABLE psy_plan_weekly_progress
  ADD COLUMN IF NOT EXISTS notes           TEXT,
  ADD COLUMN IF NOT EXISTS mood_before     INT,
  ADD COLUMN IF NOT EXISTS mood_after      INT,
  ADD COLUMN IF NOT EXISTS goals_discussed TEXT[],
  ADD COLUMN IF NOT EXISTS homework_given  TEXT[],
  ADD COLUMN IF NOT EXISTS coach_id        UUID REFERENCES auth.users(id),
  ADD COLUMN IF NOT EXISTS coach_name      TEXT;


-- ── FILE: step25_inventory_items.sql ──
-- ISW Default Inventory Items
-- Run this after step17_inventory.sql
-- Clears existing items and inserts fresh ISW defaults

DELETE FROM psy_inventory_items;

INSERT INTO psy_inventory_items (name, category, unit, qty_in_stock, min_qty, requires_approval, notes)
VALUES

-- ── MADU & PRODUK ─────────────────────────────────────────
('Lebah Thoharah (LTH)',            'Madu & Produk', 'kg',     0, 5,  false, 'Program NLC / JS / JS+ / EOL'),
('LTH Plus Green (LTHPG)',          'Madu & Produk', 'kg',     0, 5,  false, 'Program NLC / JS / JS+ / EOL'),
('Ibu Bumi (IB)',                   'Madu & Produk', 'kg',     0, 5,  false, 'Program OBD / OBP'),
('Young & Healthy Plus Green (YHPG)','Madu & Produk','kg',     0, 5,  false, 'Program OBD / OBP'),
('Madu Kelulut',                    'Madu & Produk', 'botol',  0, 3,  false, NULL),
('Minyak Zaitun Tulen',             'Madu & Produk', 'botol',  0, 3,  false, NULL),

-- ── STARTER KIT ───────────────────────────────────────────
('SDS OB',                          'Starter Kit',   'unit',   0, 5,  false, 'Starter kit OBD / OBP'),
('GHF',                             'Starter Kit',   'unit',   0, 5,  false, 'Starter kit OBD / OBP'),
('BNP',                             'Starter Kit',   'unit',   0, 5,  false, 'Bekalan pantang NLC / JS'),
('NSS',                             'Starter Kit',   'unit',   0, 5,  false, 'Bekalan pantang NLC / JS'),
('Voucher Konsultasi',              'Starter Kit',   'unit',   0, 10, false, 'Diedarkan semasa onboarding'),

-- ── SUPLEMEN & RESEPI ─────────────────────────────────────
('Resepi Superimun',                'Suplemen & Resepi', 'unit', 0, 5, false, 'Diberi semasa onboarding'),
('Resepi Superenergi',              'Suplemen & Resepi', 'unit', 0, 5, false, 'Diberi semasa onboarding'),
('Barley Organik',                  'Suplemen & Resepi', 'kg',   0, 5, false, NULL),
('Spirulina',                       'Suplemen & Resepi', 'botol',0, 3, false, NULL),
('Probiotik Advanced',              'Suplemen & Resepi', 'botol',0, 3, false, NULL),
('Magnesium Glycinate',             'Suplemen & Resepi', 'botol',0, 3, false, NULL),
('Vitamin D3',                      'Suplemen & Resepi', 'botol',0, 3, false, NULL),
('Omega-3 Fish Oil',                'Suplemen & Resepi', 'botol',0, 3, false, NULL),

-- ── BUKU & BAHAN CETAK ────────────────────────────────────
('Buku P101',                       'Buku & Bahan Cetak', 'naskhah', 0, 10, false, '7 buku per set starter kit'),
('List Pantang',                    'Buku & Bahan Cetak', 'naskhah', 0, 10, false, 'Diedarkan semasa onboarding'),
('Peta OB',                         'Buku & Bahan Cetak', 'naskhah', 0, 10, false, 'Diedarkan semasa onboarding OBD / OBP'),
('Workbook Refleksi Harian',        'Buku & Bahan Cetak', 'naskhah', 0, 10, false, NULL),
('Jadual Terapi Mingguan',          'Buku & Bahan Cetak', 'naskhah', 0, 10, false, NULL),
('Mood Tracker',                    'Buku & Bahan Cetak', 'naskhah', 0, 10, false, NULL),
('Buku Gaya Hidup Fitrah',          'Buku & Bahan Cetak', 'naskhah', 0,  5, false, NULL),
('Kitab Doa Syifa',                 'Buku & Bahan Cetak', 'naskhah', 0,  5, false, NULL),

-- ── BROSUR & MARKETING ────────────────────────────────────
('Brochure Madu',                   'Brosur & Marketing', 'unit', 0, 20, false, NULL),
('Brochure ISW',                    'Brosur & Marketing', 'unit', 0, 20, false, NULL),
('Brochure OB',                     'Brosur & Marketing', 'unit', 0, 20, false, NULL),

-- ── BEKALAN COACHING ──────────────────────────────────────
('Air Afiyah',                      'Bekalan Coaching', 'botol', 0, 10, false, '1 botol = 1.5L'),
('Air Za''afaran',                  'Bekalan Coaching', 'botol', 0,  5, false, 'Untuk sesi Perubatan Rohani'),
('Herba Kolon',                     'Bekalan Coaching', 'set',   0,  3, false, '1 set = 1 kursus rawatan'),
('Kurma Ajwa',                      'Bekalan Coaching', 'biji',  0, 50, false, '49 biji per pesakit 777 VIP'),

-- ── PERALATAN KLINIK ──────────────────────────────────────
('DNA Test Kit',                    'Peralatan Klinik', 'set',  0, 2, true,  'Perlu kelulusan · hantar ke lab luar'),
('Enema Kit',                       'Peralatan Klinik', 'set',  0, 3, true,  'Perlu kelulusan'),
('Mesin Ozon',                      'Peralatan Klinik', 'unit', 0, 1, true,  'Rekod nombor siri setiap unit')

;


-- ── FILE: step26_meet_link.sql ──
-- Add meet_link column to psy_plan_weekly_progress for online sessions
ALTER TABLE psy_plan_weekly_progress
  ADD COLUMN IF NOT EXISTS meet_link TEXT;


-- ── FILE: step27_inventory_tables.sql ──
-- Create psy_inventory_items and psy_inventory_requests tables
-- Run this if step17_inventory.sql was missing/corrupt

-- ── Inventory Items ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS psy_inventory_items (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name             TEXT NOT NULL,
  category         TEXT NOT NULL DEFAULT 'Bekalan Coaching',
  unit             TEXT NOT NULL DEFAULT 'unit',
  qty_in_stock     NUMERIC(10,2) NOT NULL DEFAULT 0,
  min_qty          NUMERIC(10,2) NOT NULL DEFAULT 5,
  requires_approval BOOLEAN NOT NULL DEFAULT false,
  notes            TEXT,
  created_at       TIMESTAMPTZ DEFAULT now(),
  updated_at       TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE psy_inventory_items ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "Staff read inventory items" ON psy_inventory_items
    FOR SELECT USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "Admin manage inventory items" ON psy_inventory_items
    FOR ALL USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff' AND staff_role IN ('admin','manager')));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ── Inventory Requests ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS psy_inventory_requests (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  item_id           UUID REFERENCES psy_inventory_items(id) ON DELETE SET NULL,
  item_name         TEXT NOT NULL,
  qty_requested     NUMERIC(10,2) NOT NULL,
  unit_price        NUMERIC(10,2),
  total_amount      NUMERIC(10,2),
  reason            TEXT,
  status            TEXT NOT NULL DEFAULT 'pending_approval'
                    CHECK (status IN ('pending_approval','approved','rejected','purchased')),
  requested_by      UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  requested_by_name TEXT NOT NULL DEFAULT '',
  approved_by       UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  approved_at       TIMESTAMPTZ,
  rejected_reason   TEXT,
  purchased_at      TIMESTAMPTZ,
  created_at        TIMESTAMPTZ DEFAULT now(),
  updated_at        TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE psy_inventory_requests ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "Staff read all requests" ON psy_inventory_requests
    FOR SELECT USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "Staff insert own requests" ON psy_inventory_requests
    FOR INSERT WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "Manager admin update requests" ON psy_inventory_requests
    FOR UPDATE USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff' AND staff_role IN ('admin','manager')));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ── FILE: step28_clinic_closures.sql ──
-- ============================================================
-- step28_clinic_closures.sql
-- Calendar lock for public holidays, Hari Raya, and ad-hoc clinic closure days.
-- Booking flow checks this table to auto-block the date.
-- ============================================================

CREATE TABLE IF NOT EXISTS psy_clinic_closures (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  closure_date DATE NOT NULL,
  label       TEXT NOT NULL,
  category    TEXT NOT NULL DEFAULT 'public_holiday'
              CHECK (category IN ('public_holiday','hari_raya','clinic_closed','training','other')),
  is_recurring BOOLEAN NOT NULL DEFAULT false,  -- annual recurrence on same MM-DD
  notes       TEXT,
  created_by  UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at  TIMESTAMPTZ DEFAULT now(),
  updated_at  TIMESTAMPTZ DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS uniq_clinic_closure_date
  ON psy_clinic_closures (closure_date);

CREATE INDEX IF NOT EXISTS idx_clinic_closure_date
  ON psy_clinic_closures (closure_date);

ALTER TABLE psy_clinic_closures ENABLE ROW LEVEL SECURITY;

-- Everyone authenticated (staff + patient) can read — used by booking + patient dashboard
DO $$ BEGIN
  CREATE POLICY "Anyone read clinic closures" ON psy_clinic_closures
    FOR SELECT USING (auth.uid() IS NOT NULL);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Only admin/manager can mutate
DO $$ BEGIN
  CREATE POLICY "Admin manage clinic closures" ON psy_clinic_closures
    FOR ALL USING (
      EXISTS (SELECT 1 FROM psy_profiles
              WHERE id = auth.uid()
              AND role = 'staff'
              AND staff_role IN ('admin','manager'))
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;


-- ── FILE: step29_kyc_proxy.sql ──
-- ============================================================
-- step29_kyc_proxy.sql
-- Track whether KYC submission was filled by patient themselves
-- or by a representative (pewaris/keluarga) — for review attention.
-- ============================================================

ALTER TABLE psy_kyc_submissions
  ADD COLUMN IF NOT EXISTS submitted_by_proxy BOOLEAN NOT NULL DEFAULT false;

COMMENT ON COLUMN psy_kyc_submissions.submitted_by_proxy IS
  'true = wakil/keluarga isi borang ini (info mesti tepat & boleh disahkan dengan pesakit sebenar)';


-- ── FILE: step30_outcome_status.sql ──
-- ============================================================
-- step30_outcome_status.sql
-- Clinical outcome status for reporting & statistics.
-- Separate from system 'status' (active/inactive) — this is treatment outcome.
-- ============================================================

ALTER TABLE psy_patients
  ADD COLUMN IF NOT EXISTS outcome_status TEXT
  CHECK (outcome_status IN ('otw','berhenti','meninggal','completed'));

ALTER TABLE psy_patients
  ADD COLUMN IF NOT EXISTS outcome_status_at TIMESTAMPTZ;

ALTER TABLE psy_patients
  ADD COLUMN IF NOT EXISTS outcome_status_notes TEXT;

CREATE INDEX IF NOT EXISTS idx_psy_patients_outcome_status
  ON psy_patients (outcome_status) WHERE outcome_status IS NOT NULL;

COMMENT ON COLUMN psy_patients.outcome_status IS
  'Clinical outcome: otw=On-going Treatment, berhenti=stopped, meninggal=passed away, completed=selesai rawatan';


-- ── FILE: step31_patient_self_vitals.sql ──
-- ============================================================
-- step31_patient_self_vitals.sql
-- Allow patients to log own BP / HbA1c readings (e.g. taken at home).
-- Add hba1c column + source column to distinguish staff vs patient entries.
-- ============================================================

ALTER TABLE psy_vitals
  ADD COLUMN IF NOT EXISTS hba1c NUMERIC(4,2);

ALTER TABLE psy_vitals
  ADD COLUMN IF NOT EXISTS source TEXT NOT NULL DEFAULT 'staff'
  CHECK (source IN ('staff','patient_self'));

ALTER TABLE psy_vitals
  ADD COLUMN IF NOT EXISTS reading_date DATE;

COMMENT ON COLUMN psy_vitals.hba1c IS 'HbA1c % (e.g. 6.5 = 6.5%)';
COMMENT ON COLUMN psy_vitals.source IS 'Who entered the reading: staff at clinic, or patient self-reported';
COMMENT ON COLUMN psy_vitals.reading_date IS 'Date the reading was actually taken (may differ from created_at for back-dated entries)';

-- Allow patient to insert OWN readings (only with source = patient_self)
DO $$ BEGIN
  CREATE POLICY "Patients insert own vitals" ON psy_vitals FOR INSERT
    WITH CHECK (
      source = 'patient_self'
      AND patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid())
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;


-- ── FILE: step32_package_extensions.sql ──
-- ============================================================
-- step32_package_extensions.sql
-- Sprint 1: Package System Foundation
--
-- Extends psy_packages with fields needed for:
-- - Jadual peminuman madu auto (10x/8x/4x ikut pakej)
-- - Lock butang ONLINE dari minggu 3 (kecuali pakej OB direct: OBD1/OBDX1/OBDY1/OBP1/OBPX1/OBPY1)
-- - Bekalan per minggu (foundation untuk inventory auto-deduct)
-- - Content unlock rule per minggu
-- - WhatsApp message template per minggu
-- ============================================================

ALTER TABLE psy_packages
  ADD COLUMN IF NOT EXISTS madu_frequency_per_day INT,
  ADD COLUMN IF NOT EXISTS madu_schedule_label TEXT,
  ADD COLUMN IF NOT EXISTS allow_online_full_duration BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS online_lock_from_week INT NOT NULL DEFAULT 3,
  ADD COLUMN IF NOT EXISTS weekly_supplies JSONB DEFAULT '[]',
  ADD COLUMN IF NOT EXISTS weekly_content JSONB DEFAULT '[]',
  ADD COLUMN IF NOT EXISTS weekly_message JSONB DEFAULT '[]';

COMMENT ON COLUMN psy_packages.madu_frequency_per_day IS
  'Frekuensi peminuman madu sehari. Examples: 10 (12-minggu), 8 (3-bulan), 4 (3-bulan-sekali). NULL = no madu schedule.';
COMMENT ON COLUMN psy_packages.madu_schedule_label IS
  'Human-readable label for madu schedule, e.g. "10x sehari (12 minggu)"';
COMMENT ON COLUMN psy_packages.allow_online_full_duration IS
  'true = online sessions allowed throughout (OBD1/OBDX1/OBDY1/OBP1/OBPX1/OBPY1). false = lock to f2f after online_lock_from_week.';
COMMENT ON COLUMN psy_packages.online_lock_from_week IS
  'Week number from which online sessions are locked (must use f2f). Default 3.';
COMMENT ON COLUMN psy_packages.weekly_supplies IS
  'Array of {week, items: [{product_id, qty, name}]} — bekalan auto-deduct per week';
COMMENT ON COLUMN psy_packages.weekly_content IS
  'Array of {week, content_ids: []} — library content unlock per week';
COMMENT ON COLUMN psy_packages.weekly_message IS
  'Array of {week, message} — WhatsApp template per week';

-- Mark OB-direct packages as allowing online full duration
UPDATE psy_packages
  SET allow_online_full_duration = true
  WHERE LOWER(package_id) IN ('obd1','obdx1','obdy1','obp1','obpx1','obpy1');


-- ── FILE: step33_madu_tracking.sql ──
-- ============================================================
-- step33_madu_tracking.sql
-- Track madu intake count per day in daily check-in.
-- Target frequency comes from patient's active package (madu_frequency_per_day).
-- ============================================================

ALTER TABLE psy_daily_checkins
  ADD COLUMN IF NOT EXISTS madu_count INT NOT NULL DEFAULT 0;

COMMENT ON COLUMN psy_daily_checkins.madu_count IS
  'Bilangan kali pesakit minum madu hari ini. Target dari psy_packages.madu_frequency_per_day.';


-- ── FILE: step34_kob.sql ──
-- ============================================================
-- step34_kob.sql
-- Konsultasi Orang Baru (KOB) — mandatory paid entry-point.
--
-- Flow:
--   Register → Bayar RM199 → Isi KYC → Pilih tarikh KOB →
--   Doktor: Hadir → Patient sign agreement → Doktor isi notes + upload → Selesai →
--   Unlock pakej rawatan
-- ============================================================

-- ── 1. Extend psy_patients with KOB lifecycle status ──────
ALTER TABLE psy_patients
  ADD COLUMN IF NOT EXISTS kob_status TEXT NOT NULL DEFAULT 'pending_payment'
  CHECK (kob_status IN (
    'pending_payment',  -- Patient baru daftar, belum bayar RM199
    'paid',             -- Sudah bayar, KYC belum hantar
    'kyc_done',         -- KYC selesai, belum book slot KOB
    'booked',           -- Slot KOB ditempah
    'hadir',            -- Doktor tekan Hadir (sesi sedang berlangsung)
    'completed',        -- Doktor tekan Selesai → pakej unlocked
    'na'                -- Not applicable (patient staff-created, grandfathered)
  ));

COMMENT ON COLUMN psy_patients.kob_status IS
  'Lifecycle KOB. Self-registered patient mula pending_payment → completed sebelum boleh pilih pakej. Staff-created patient = na.';

-- Existing patients: bulk-categorize
-- Staff-created (created_by_staff=true) → na (bypass KOB)
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns
             WHERE table_name='psy_patients' AND column_name='created_by_staff') THEN
    EXECUTE $sql$
      UPDATE psy_patients SET kob_status = 'na'
      WHERE created_by_staff = true AND kob_status = 'pending_payment'
    $sql$;
  END IF;
END $$;

-- Existing patients with active package → grandfather as completed
UPDATE psy_patients SET kob_status = 'completed'
  WHERE active_package_id IS NOT NULL AND kob_status = 'pending_payment';

-- Patients with terminal outcome → na (skip if outcome_status column not yet present)
DO $$ BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name='psy_patients' AND column_name='outcome_status'
  ) THEN
    EXECUTE $sql$
      UPDATE psy_patients SET kob_status = 'na'
      WHERE outcome_status IN ('berhenti','meninggal') AND kob_status = 'pending_payment'
    $sql$;
  END IF;
END $$;

-- ── 2. psy_kob_sessions: booking, attendance, notes ───────
CREATE TABLE IF NOT EXISTS psy_kob_sessions (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id          UUID NOT NULL REFERENCES psy_patients(id) ON DELETE CASCADE,
  scheduled_at        TIMESTAMPTZ NOT NULL,
  mode                TEXT NOT NULL DEFAULT 'f2f' CHECK (mode IN ('f2f','online')),
  meet_link           TEXT,
  status              TEXT NOT NULL DEFAULT 'booked'
                      CHECK (status IN ('booked','hadir','completed','reschedule','cancelled')),

  -- Doctor who marked attendance (may differ from who completes)
  doctor_hadir_id     UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  doctor_hadir_name   TEXT,
  hadir_at            TIMESTAMPTZ,

  -- Doctor who marked completion
  doctor_selesai_id   UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  doctor_selesai_name TEXT,
  selesai_at          TIMESTAMPTZ,

  -- Clinical notes from doctor
  notes               TEXT,
  -- Uploaded reports / supporting docs for this KOB
  documents           JSONB DEFAULT '[]',

  reschedule_count    INT NOT NULL DEFAULT 0,
  reschedule_reason   TEXT,

  created_at          TIMESTAMPTZ DEFAULT now(),
  updated_at          TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_kob_patient ON psy_kob_sessions(patient_id);
CREATE INDEX IF NOT EXISTS idx_kob_scheduled ON psy_kob_sessions(scheduled_at);
CREATE INDEX IF NOT EXISTS idx_kob_status ON psy_kob_sessions(status);

ALTER TABLE psy_kob_sessions ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "Patient read own KOB" ON psy_kob_sessions FOR SELECT
    USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "Patient book own KOB" ON psy_kob_sessions FOR INSERT
    WITH CHECK (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "Patient reschedule own KOB" ON psy_kob_sessions FOR UPDATE
    USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "Staff manage KOB sessions" ON psy_kob_sessions FOR ALL
    USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ── 3. psy_kob_agreements: signed agreement record ────────
CREATE TABLE IF NOT EXISTS psy_kob_agreements (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id        UUID NOT NULL REFERENCES psy_patients(id) ON DELETE CASCADE,
  kob_session_id    UUID REFERENCES psy_kob_sessions(id) ON DELETE SET NULL,
  agreement_version TEXT NOT NULL DEFAULT 'ISW.SOP OB KOB FORM 03 CONTRACT 250711',
  patient_name      TEXT NOT NULL,
  patient_ic        TEXT NOT NULL,
  signature_url     TEXT NOT NULL,   -- raw PNG signature in storage
  signed_pdf_url    TEXT,            -- generated PDF with signature embedded
  signed_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
  ip_address        TEXT,
  user_agent        TEXT,
  created_at        TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_kob_agreements_patient ON psy_kob_agreements(patient_id);

ALTER TABLE psy_kob_agreements ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "Patient read own agreement" ON psy_kob_agreements FOR SELECT
    USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "Patient sign own agreement" ON psy_kob_agreements FOR INSERT
    WITH CHECK (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "Staff read all agreements" ON psy_kob_agreements FOR SELECT
    USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ── 4. Storage bucket for KOB documents + signatures ──────
-- Run separately in Supabase Storage UI or via:
--   INSERT INTO storage.buckets (id, name, public) VALUES ('kob-documents', 'kob-documents', false);
--   INSERT INTO storage.buckets (id, name, public) VALUES ('kob-signatures', 'kob-signatures', false);

SELECT 'Step 34 OK — KOB tables ready' AS status;


-- ── FILE: step35_kob_skip_payment.sql ──
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


-- ── FILE: step36_kob_slots.sql ──
-- ============================================================
-- step36_kob_slots.sql
-- KOB slot template configuration.
-- Slots are a fixed template — same 4 time slots for Wed-Sun.
-- Admin can toggle each slot on/off. No per-patient capacity (infinite per slot).
-- ============================================================

CREATE TABLE IF NOT EXISTS psy_kob_slot_config (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  day_of_week  INT NOT NULL CHECK (day_of_week IN (0, 3, 4, 5, 6)),  -- 0=Sun, 3=Wed, 4=Thu, 5=Fri, 6=Sat
  slot_start   TIME NOT NULL,
  slot_end     TIME NOT NULL,
  is_active    BOOLEAN NOT NULL DEFAULT true,
  label        TEXT NOT NULL,         -- human-readable e.g. "8.30 AM - 10.00 AM"
  sort_order   INT NOT NULL DEFAULT 0,
  created_at   TIMESTAMPTZ DEFAULT now(),
  updated_at   TIMESTAMPTZ DEFAULT now(),
  UNIQUE (day_of_week, slot_start)
);

CREATE INDEX IF NOT EXISTS idx_kob_slots_day ON psy_kob_slot_config(day_of_week, is_active);

ALTER TABLE psy_kob_slot_config ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "Anyone read kob slots" ON psy_kob_slot_config
    FOR SELECT USING (auth.uid() IS NOT NULL);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "Admin manage kob slots" ON psy_kob_slot_config FOR ALL
    USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff' AND staff_role IN ('admin','manager','doctor')));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ── Seed: 5 hari (Rabu-Ahad) × 4 slot ────────────────────
-- Slot 1: 8.30 AM - 10.00 AM
-- Slot 2: 10.30 AM - 12.00 PM
-- Slot 3: 2.00 PM - 3.30 PM
-- Slot 4: 3.30 PM - 5.00 PM
INSERT INTO psy_kob_slot_config (day_of_week, slot_start, slot_end, label, sort_order) VALUES
  (3, '08:30', '10:00', '8.30 AM - 10.00 AM', 1),
  (3, '10:30', '12:00', '10.30 AM - 12.00 PM', 2),
  (3, '14:00', '15:30', '2.00 PM - 3.30 PM', 3),
  (3, '15:30', '17:00', '3.30 PM - 5.00 PM', 4),
  (4, '08:30', '10:00', '8.30 AM - 10.00 AM', 1),
  (4, '10:30', '12:00', '10.30 AM - 12.00 PM', 2),
  (4, '14:00', '15:30', '2.00 PM - 3.30 PM', 3),
  (4, '15:30', '17:00', '3.30 PM - 5.00 PM', 4),
  (5, '08:30', '10:00', '8.30 AM - 10.00 AM', 1),
  (5, '10:30', '12:00', '10.30 AM - 12.00 PM', 2),
  (5, '14:00', '15:30', '2.00 PM - 3.30 PM', 3),
  (5, '15:30', '17:00', '3.30 PM - 5.00 PM', 4),
  (6, '08:30', '10:00', '8.30 AM - 10.00 AM', 1),
  (6, '10:30', '12:00', '10.30 AM - 12.00 PM', 2),
  (6, '14:00', '15:30', '2.00 PM - 3.30 PM', 3),
  (6, '15:30', '17:00', '3.30 PM - 5.00 PM', 4),
  (0, '08:30', '10:00', '8.30 AM - 10.00 AM', 1),
  (0, '10:30', '12:00', '10.30 AM - 12.00 PM', 2),
  (0, '14:00', '15:30', '2.00 PM - 3.30 PM', 3),
  (0, '15:30', '17:00', '3.30 PM - 5.00 PM', 4)
ON CONFLICT DO NOTHING;

SELECT 'Step 36 OK — KOB slot config ready' AS status;


-- ── FILE: step37_kob_questionnaire.sql ──
-- ============================================================
-- step37_kob_questionnaire.sql
-- Structured questionnaire for KOB session — doctor fills during consultation.
-- Stored as JSONB so we can evolve the question set without schema changes.
-- ============================================================

ALTER TABLE psy_kob_sessions
  ADD COLUMN IF NOT EXISTS questionnaire JSONB DEFAULT '{}';

COMMENT ON COLUMN psy_kob_sessions.questionnaire IS
  'Structured Q&A captured during KOB. Keys: anak[], tidur{}, gaya_hidup{}, masalah_kesihatan{} — see kob-detail.html for shape.';

SELECT 'Step 37 OK — KOB questionnaire column ready' AS status;


-- ── FILE: step38_kob_package_recommendation.sql ──
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


-- ── FILE: step39_package_agreement.sql ──
-- ============================================================
-- step39_package_agreement.sql
-- Each package has its own agreement PDF template.
-- Patient signs the agreement matching their recommended package.
-- Fallback to generic 'agreement.pdf' if not set.
-- ============================================================

ALTER TABLE psy_packages
  ADD COLUMN IF NOT EXISTS agreement_pdf TEXT;

COMMENT ON COLUMN psy_packages.agreement_pdf IS
  'Filename of agreement PDF in shared/documents/agreements/ (relative path). NULL = use default agreement.pdf';

-- Seed mapping for known packages (idempotent — only set if column currently null)
UPDATE psy_packages SET agreement_pdf = 'ELIXIR_EOL_CONTRACT_[TEMPLATE].pdf'
  WHERE LOWER(package_id) IN ('pkg-eol','eol') AND agreement_pdf IS NULL;

UPDATE psy_packages SET agreement_pdf = 'ELIXIR_EOL+_CONTRACT_[TEMPLATE].pdf'
  WHERE LOWER(package_id) IN ('pkg-eol-plus','pkg-eolplus','eol+','eol-plus') AND agreement_pdf IS NULL;

UPDATE psy_packages SET agreement_pdf = 'ELIXIR__JUMPSTART_CONTRACT_[TEMPLATE].pdf'
  WHERE LOWER(package_id) IN ('pkg-jumpstart','pkg-js','js','jumpstart') AND agreement_pdf IS NULL;

UPDATE psy_packages SET agreement_pdf = 'ELIXIR__JUMPSTART+_CONTRACT_[TEMPLATE].pdf'
  WHERE LOWER(package_id) IN ('pkg-jumpstart-plus','pkg-jsplus','js+','jumpstart+') AND agreement_pdf IS NULL;

UPDATE psy_packages SET agreement_pdf = 'OBD1_-_CONTRACT_[TEMPLATE].pdf'
  WHERE LOWER(package_id) IN ('pkg-obd1','obd1') AND agreement_pdf IS NULL;

UPDATE psy_packages SET agreement_pdf = 'OBDX1_-_CONTRACT_[TEMPLATE].pdf'
  WHERE LOWER(package_id) IN ('pkg-obdx1','obdx1') AND agreement_pdf IS NULL;

UPDATE psy_packages SET agreement_pdf = 'OBDY1_-_CONTRACT_[TEMPLATE].pdf'
  WHERE LOWER(package_id) IN ('pkg-obdy1','obdy1') AND agreement_pdf IS NULL;

UPDATE psy_packages SET agreement_pdf = 'OBG_(NLC)_-_CONTRACT_[TEMPLATE].pdf'
  WHERE LOWER(package_id) IN ('pkg-obg-nlc','pkg-obg','obg','obg-nlc') AND agreement_pdf IS NULL;

UPDATE psy_packages SET agreement_pdf = 'OBP1_-_CONTRACT_[TEMPLATE].pdf'
  WHERE LOWER(package_id) IN ('pkg-obp1','obp1') AND agreement_pdf IS NULL;

UPDATE psy_packages SET agreement_pdf = 'OBPX1_-_CONTRACT_[TEMPLATE].pdf'
  WHERE LOWER(package_id) IN ('pkg-obpx1','obpx1') AND agreement_pdf IS NULL;

UPDATE psy_packages SET agreement_pdf = 'OBPY1_-_CONTRACT_[TEMPLATE].pdf'
  WHERE LOWER(package_id) IN ('pkg-obpy1','obpy1') AND agreement_pdf IS NULL;

SELECT 'Step 39 OK — agreement_pdf mapping ready' AS status;


-- ── FILE: step40_agreement_storage.sql ──
-- ============================================================
-- step40_agreement_storage.sql
-- Storage bucket setup for package agreement PDFs.
-- Staff upload via pakej-edit.html → saved here → patient reads when signing.
-- ============================================================

-- Create the private bucket
INSERT INTO storage.buckets (id, name, public)
  VALUES ('agreement-templates', 'agreement-templates', false)
ON CONFLICT (id) DO NOTHING;

-- All authenticated users can READ (so patient can preview + load to sign)
DO $$ BEGIN
  CREATE POLICY "Authenticated read agreement templates"
    ON storage.objects FOR SELECT
    USING (bucket_id = 'agreement-templates' AND auth.uid() IS NOT NULL);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Only admin / manager / doctor can UPLOAD / UPDATE / DELETE
DO $$ BEGIN
  CREATE POLICY "Staff manage agreement templates"
    ON storage.objects FOR ALL
    USING (
      bucket_id = 'agreement-templates'
      AND EXISTS (
        SELECT 1 FROM psy_profiles
        WHERE id = auth.uid()
        AND role = 'staff'
        AND staff_role IN ('admin','manager','doctor')
      )
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

SELECT 'Step 40 OK — agreement-templates storage bucket ready' AS status;


-- ── FILE: step41_agreement_clauses.sql ──
-- ============================================================
-- step41_agreement_clauses.sql
-- Migrate from PDF upload to HTML text clauses approach.
-- Admin edit clauses → patient render as HTML → sign → auto-generate PDF.
--
-- agreement_clauses structure:
--   [{ "title": "1. Tanggungjawab", "body": "Saya bersetuju..." }, ...]
--
-- Supports variables: {{patient_name}}, {{patient_ic}}, {{package_name}}, {{today}}, {{price}}
-- ============================================================

ALTER TABLE psy_packages
  ADD COLUMN IF NOT EXISTS agreement_clauses JSONB DEFAULT '[]',
  ADD COLUMN IF NOT EXISTS agreement_version TEXT,
  ADD COLUMN IF NOT EXISTS agreement_title TEXT DEFAULT 'Kontrak Pelaburan Kesihatan';

COMMENT ON COLUMN psy_packages.agreement_clauses IS
  'Array of {title, body} clauses for the patient agreement. Supports variables like {{patient_name}}.';
COMMENT ON COLUMN psy_packages.agreement_version IS
  'Version label, e.g. ISW.SOP OB KOB FORM 03 CONTRACT 250711';
COMMENT ON COLUMN psy_packages.agreement_title IS
  'Title shown at top of agreement (default: Kontrak Pelaburan Kesihatan)';

-- Seed default clauses (matching the original PDF content) for all packages with empty clauses
UPDATE psy_packages
SET
  agreement_clauses = '[
    {"title": "1. Tanggungjawab Maklumat", "body": "Saya mengambil tanggungjawab sepenuhnya terhadap kesihatan saya dan telah mengisi borang ini dengan sukarela dengan memberikan maklumat kesihatan saya kepada Ibnu Sina Wellness."},
    {"title": "2. Khidmat Nasihat", "body": "Saya berpuas hati dengan khidmat nasihat kesihatan yang diberikan oleh perawat Ibnu Sina Wellness."},
    {"title": "3. Bukan Rawatan Medikal", "body": "Saya faham dengan sepenuhnya bahawa ia bukan diagnosis medikal atau rawatan medikal atau substitut untuk diagnosis medikal atau rawatan medikal."},
    {"title": "4. Penyakit Mental & Sihir", "body": "Saya faham bahawa sekiranya saya mempunyai masalah mental atau sihir dan saka, saya harus dirawat terlebih dahulu sebelum memulakan program {{package_name}} di Ibnu Sina Wellness."},
    {"title": "5. Rawatan Alternatif", "body": "Saya faham bahawa program {{package_name}} di Ibnu Sina Wellness adalah rawatan alternatif dan ia tidak menggantikan perubatan hospital maka saya akan meneruskan pengambilan ubat, perubatan dan pemeriksaan hospital."},
    {"title": "6. Komitmen Harian", "body": "Saya faham bagi mencapai hasil yang baik, saya perlu amalkan secara komited setiap hari segala tatacara yang disusun dan diajarkan oleh Ibnu Sina Wellness secara sepenuhnya."},
    {"title": "7. Gaya Pemikiran Fitrah", "body": "Saya komited untuk mengikuti program {{package_name}} bagi menukar kepada Gaya Pemikiran Follow Fitrah sebagai tahap asas untuk mencapai kesihatan yang sihat."},
    {"title": "8. Penyembuhan Di Tangan Allah", "body": "Saya faham penyembuhan penyakit adalah di tangan Allah SWT dan jangkamasa penyembuhan bergantung kepada keizinan Allah."},
    {"title": "9. Penerangan Pakej", "body": "Saya telah diberi penerangan penuh pakej program {{package_name}} dengan jelas oleh Ibnu Sina Wellness."},
    {"title": "10. Reaksi Pemulihan", "body": "Ibnu Sina Wellness telah memaklumkan tentang reaksi pemulihan dan gejala prosedur, yang boleh termasuk, tetapi tidak terhad kepada: pening atau loya, sakit-sakit badan, flu, lebam, perubahan warna kulit, dan kemungkinan risiko lain yang tidak dijangka. Dalam sesetengah kes, simptom saya mungkin bertambah buat sementara waktu sebelum ia mula beransur baik. Saya akan menanggung segala risiko yang terlibat dengan prosedur saya."},
    {"title": "11. Kecemasan Hospital", "body": "Saya faham saya perlu ke hospital untuk kecemasan. Saya juga akan segera ke hospital sekiranya saya sakit atau mengalami reaksi pemulihan yang teruk seperti yang tertera di buku Sains di Sebalik {{package_name}} atau seperti yang dinasihatkan oleh perawat dan coach Ibnu Sina Wellness."},
    {"title": "12. Tiada Jaminan Keputusan", "body": "Saya faham bahawa tiada jaminan keputusan untuk sebarang prosedur yang sedang dijalani. Prosedur kesihatan alternatif dan holistik selalunya tidak akan menunjukkan hasil rawatan dengan serta merta."},
    {"title": "13. Tempoh Hasil", "body": "Tempoh untuk mencapai hasil serta keputusan bergantung pada tahap kesihatan saya, disiplin serta komitmen saya mengamalkan kaedah program {{package_name}} di Ibnu Sina Wellness."},
    {"title": "14. Tiada Paksa Tanggungjawab", "body": "Saya tidak akan memaksa Ibnu Sina Wellness untuk bertanggungjawab ke atas sebarang kekurangan hasil program {{package_name}}."},
    {"title": "15. Kerosakan Peralatan", "body": "Saya faham bahawa sekiranya terdapat sebarang kerosakan terhadap peralatan rawatan Ibnu Sina Wellness disebabkan oleh kecuaian atau kegagalan untuk bertindak sewajarnya dari diri saya sendiri, saya akan membayar pampasan kepada pihak Ibnu Sina Wellness kos yang munasabah untuk membaiki kerosakan peralatan rawatan tersebut berdasarkan permintaan Ibnu Sina Wellness."},
    {"title": "16. Pilihan Sendiri", "body": "Dengan rela hati saya sendiri membuat keputusan untuk mengikuti program {{package_name}} Ibnu Sina Wellness dan telah dimaklumkan tentang risiko serta manfaatnya."},
    {"title": "17. Pembebasan Tanggungjawab", "body": "Saya membebaskan pihak Ibnu Sina Wellness, herba-herba yang digunakan, peralatan yang digunakan, fasiliti, perawat, strategist, pekerja Ibnu Sina Wellness, pesakit yang memberi testimoni serta kesemua produksi media Ibnu Sina Wellness dari sebarang tindakan dan kerugian selamanya."},
    {"title": "18. Barang Peribadi", "body": "Saya faham bahawa semua barang peribadi di dalam fasiliti Ibnu Sina Wellness adalah di bawah tanggungjawab saya sendiri dan pihak Ibnu Sina Wellness tidak akan bertanggungjawab pada sebarang kerosakan atau kecurian atau penyelewengan barang peribadi saya."},
    {"title": "19. Rakaman Laporan Progres", "body": "19.1 Saya dengan ini mengesahkan persetujuan yang diberikan kepada Ibnu Sina Wellness berkenaan dengan fotografi, rakaman video, penggambaran, atau rakaman audio bagi tujuan penyimpanan rekod pesakit, informasi, pembelajaran atau promosi.\n\n19.2 Saya sedia maklum bahawa maklumat yang diberikan kepada Ibnu Sina Wellness akan digunakan, diedarkan atau dikongsikan kepada mana-mana pihak ketiga berkenaan dengan fotografi, rakaman video, penggambaran, atau rakaman audio untuk siaran - langsung atau pre-rakaman."},
    {"title": "20. Pembatalan Program", "body": "Saya akan memberi notis bertulis tempoh 7 hari sekiranya saya ingin membatalkan program {{package_name}}."},
    {"title": "21. Pemulangan Wang", "body": "Saya faham tiada pemulangan wang secara tunai ke atas pembayaran yang dilakukan. Lebihan wang yang telah dibayar akan digantikan dengan mana-mana perkhidmatan dan/atau produk Ibnu Sina Wellness yang lain."},
    {"title": "22. Hari Rawatan", "body": "22.1 Hari rawatan ialah pada hari Jumaat, Sabtu dan Ahad.\n\n22.2 Saya faham bahawa jika rawatan di luar waktu dan hari yang dinyatakan, akan ada cas \"on-call\" RM50/sejam.\n\n22.3 Saya faham bahawa ISW berhak untuk menukar waktu dan hari rawatan atas apa-apa sebab dan tiada cas \"on-call\" akan dikenakan."},
    {"title": "23. Pembayaran Ansuran", "body": "Saya bertanggungjawab untuk melunaskan bayaran mengikut tarikh dan jumlah yang telah ditetapkan mengikut Pelan Pelaburan Ansuran."},
    {"title": "24. Kegagalan Ansuran", "body": "Saya faham jika saya gagal menunaikan pembayaran mengikut Pelan Pelaburan Ansuran, yuran pakej saya akan berbalik ke yuran asal."},
    {"title": "25. Tindakan Undang-undang", "body": "Saya juga sedar kegagalan mematuhi bayaran mengikut tarikh dan jumlah yang telah ditetapkan akan menyebabkan kes saya dirujuk untuk tindakan undang-undang."},
    {"title": "26. Persetujuan Hutang", "body": "Saya bersetuju untuk menjalani program {{package_name}} sepenuhnya di Ibnu Sina Wellness secara berhutang."},
    {"title": "27. Janji Pembayaran", "body": "Saya berjanji untuk melangsaikan semua bayaran mengikut Pelan Pelaburan Ansuran."},
    {"title": "28. Tiada Refund", "body": "Saya faham tiada pemulangan wang akan diberikan atas bayaran yang telah dibuat. Lebihan wang yang telah dibayar boleh digantikan dengan mana-mana perkhidmatan dan/atau produk Ibnu Sina Wellness yang lain, tertakluk pada pengurusan Ibnu Sina Wellness."},
    {"title": "29. Bayaran Online Transfer", "body": "Untuk bayaran online transfer, saya hanya akan buat bayaran ke akaun di bawah:\n\nIBNU SINA WELLNESS SDN BHD - CIMB BANK - 8605794539\nWA SCREENSHOT BAYARAN KE COACH DI 0389663702"}
  ]'::jsonb,
  agreement_version = 'ISW.SOP OB KOB FORM 03 CONTRACT 250711',
  agreement_title = 'Kontrak Pelaburan Kesihatan'
WHERE agreement_clauses = '[]' OR agreement_clauses IS NULL;

SELECT 'Step 41 OK — agreement clauses seeded for all packages' AS status;


-- ── FILE: step42_kob_storage_buckets.sql ──
-- ============================================================
-- step42_kob_storage_buckets.sql
-- Setup storage buckets for KOB signatures + documents.
-- Patient uploads signature PNG + generated signed PDF here.
-- Doctor uploads supporting documents here.
-- ============================================================

-- ── kob-signatures bucket (patient signature PNG + signed PDF) ──
INSERT INTO storage.buckets (id, name, public)
  VALUES ('kob-signatures', 'kob-signatures', false)
ON CONFLICT (id) DO NOTHING;

-- Patient can upload their own signature
DO $$ BEGIN
  CREATE POLICY "Patient upload own signature"
    ON storage.objects FOR INSERT
    WITH CHECK (
      bucket_id = 'kob-signatures'
      AND auth.uid() IS NOT NULL
      AND (storage.foldername(name))[1] IN (
        SELECT id::text FROM psy_patients WHERE user_id = auth.uid()
      )
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Patient can read own signature
DO $$ BEGIN
  CREATE POLICY "Patient read own signature"
    ON storage.objects FOR SELECT
    USING (
      bucket_id = 'kob-signatures'
      AND auth.uid() IS NOT NULL
      AND (storage.foldername(name))[1] IN (
        SELECT id::text FROM psy_patients WHERE user_id = auth.uid()
      )
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Staff can read all signatures
DO $$ BEGIN
  CREATE POLICY "Staff read all signatures"
    ON storage.objects FOR SELECT
    USING (
      bucket_id = 'kob-signatures'
      AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff')
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ── kob-documents bucket (doctor uploads docs during KOB session) ──
INSERT INTO storage.buckets (id, name, public)
  VALUES ('kob-documents', 'kob-documents', false)
ON CONFLICT (id) DO NOTHING;

DO $$ BEGIN
  CREATE POLICY "Staff manage kob documents"
    ON storage.objects FOR ALL
    USING (
      bucket_id = 'kob-documents'
      AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff')
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "Patient read own kob documents"
    ON storage.objects FOR SELECT
    USING (
      bucket_id = 'kob-documents'
      AND auth.uid() IS NOT NULL
      AND (storage.foldername(name))[1] IN (
        SELECT id::text FROM psy_patients WHERE user_id = auth.uid()
      )
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

SELECT 'Step 42 OK — kob-signatures + kob-documents buckets ready' AS status;


-- ── FILE: step43_pakej_rujukan_storage.sql ──
-- ============================================================
-- step43_pakej_rujukan_storage.sql
-- Storage bucket for package weekly rujukan files (SOPs, scripts, docs).
-- Staff-only read+write. Patient does NOT see rujukan.
-- ============================================================

-- Create private bucket
INSERT INTO storage.buckets (id, name, public)
  VALUES ('pakej-rujukan', 'pakej-rujukan', false)
ON CONFLICT (id) DO NOTHING;

-- Staff (any role) can read
DO $$ BEGIN
  CREATE POLICY "Staff read pakej rujukan"
    ON storage.objects FOR SELECT
    USING (
      bucket_id = 'pakej-rujukan'
      AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff')
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Only admin / manager / doctor can upload / update / delete
DO $$ BEGIN
  CREATE POLICY "Staff manage pakej rujukan"
    ON storage.objects FOR ALL
    USING (
      bucket_id = 'pakej-rujukan'
      AND EXISTS (
        SELECT 1 FROM psy_profiles
        WHERE id = auth.uid()
        AND role = 'staff'
        AND staff_role IN ('admin','manager','doctor')
      )
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

SELECT 'Step 43 OK — pakej-rujukan storage bucket ready' AS status;


-- ── FILE: step44_daily_schedule.sql ──
-- ============================================================
-- step44_daily_schedule.sql
-- Daily schedule template per package (staff defines)
-- + per-patient customized copy (patient can edit)
-- + in-app reminder fires when patient opens app at scheduled time
-- ============================================================

-- Template per package
ALTER TABLE psy_packages
  ADD COLUMN IF NOT EXISTS daily_schedule JSONB DEFAULT '[]'::jsonb;

COMMENT ON COLUMN psy_packages.daily_schedule IS
  'Array of {time:"HH:MM", activity:"text"} — default daily routine for patients on this package.';

-- Patient's customized copy (NULL = follow package template, [] or array = patient-customized)
ALTER TABLE psy_patients
  ADD COLUMN IF NOT EXISTS daily_schedule JSONB;

COMMENT ON COLUMN psy_patients.daily_schedule IS
  'Patient-customized daily schedule. NULL = inherit from active package template. Array = patient has overridden.';

SELECT 'Step 44 OK — daily_schedule columns ready' AS status;


-- ── FILE: step45_seed_daily_schedule.sql ──
-- ============================================================
-- step45_seed_daily_schedule.sql
-- Seed sample daily_schedule for demo. Single UPDATE with CASE
-- to avoid deadlock between multiple UPDATE statements.
-- ============================================================

UPDATE psy_packages
SET daily_schedule = CASE
  WHEN LOWER(package_id) IN (
    'obd1','obdx1','obdy1','obp1','obpx1','obpy1',
    'pkg-obd1','pkg-obdx1','pkg-obdy1','pkg-obp1','pkg-obpx1','pkg-obpy1'
  ) THEN '[
    {"time":"06:15","activity":"Zikir bersanad"},
    {"time":"06:30","activity":"Minum madu LTHPG"},
    {"time":"07:30","activity":"Minum madu LTH"},
    {"time":"07:45","activity":"Berjemur cahaya matahari pagi & terapi bumi & pernafasan fitrah (10 minit)"},
    {"time":"08:15","activity":"Makan breakfast (Yogurt dan buah)"},
    {"time":"09:15","activity":"Minum madu LTHPG"},
    {"time":"10:15","activity":"Minum madu LTH"},
    {"time":"11:15","activity":"Minum madu LTHPG"},
    {"time":"12:15","activity":"Minum madu LTH"},
    {"time":"12:30","activity":"Lunch & minum air kelapa"},
    {"time":"13:15","activity":"Solat Zohor & pernafasan fitrah (5 minit)"},
    {"time":"14:15","activity":"Minum madu LTHPG"},
    {"time":"15:15","activity":"Minum madu LTH"},
    {"time":"16:15","activity":"Minum madu LTHPG"},
    {"time":"16:40","activity":"Solat Asar & pernafasan fitrah (5 minit)"},
    {"time":"17:00","activity":"Berkebun @ Terapi bumi"},
    {"time":"18:30","activity":"Makan malam"},
    {"time":"19:30","activity":"Solat Maghrib & Zikir bersanad"},
    {"time":"20:30","activity":"Solat Isyak & Pernafasan Fitrah (5 minit)"},
    {"time":"21:00","activity":"Minum madu LTH"},
    {"time":"21:30","activity":"Pernafasan fitrah (5 minit) & Tidur"}
  ]'::jsonb
  WHEN LOWER(package_id) IN (
    'eol','pkg-eol','eol-plus','eol+','pkg-eol-plus','pkg-eolplus',
    'js','jumpstart','js+','jumpstart+','pkg-js','pkg-jumpstart','pkg-jumpstart-plus','pkg-jsplus'
  ) THEN '[
    {"time":"06:30","activity":"Zikir pagi & pernafasan fitrah"},
    {"time":"07:00","activity":"Minum air Afiyah"},
    {"time":"08:00","activity":"Sarapan ringan"},
    {"time":"10:00","activity":"Sesi bimbingan terapi (online/F2F)"},
    {"time":"13:00","activity":"Solat Zohor & rehat"},
    {"time":"14:00","activity":"Makan tengahari"},
    {"time":"17:00","activity":"Berkebun atau aktiviti luar"},
    {"time":"19:30","activity":"Solat Maghrib & Zikir bersanad"},
    {"time":"21:30","activity":"Tidur awal"}
  ]'::jsonb
  ELSE daily_schedule
END
WHERE LOWER(package_id) IN (
  'obd1','obdx1','obdy1','obp1','obpx1','obpy1',
  'pkg-obd1','pkg-obdx1','pkg-obdy1','pkg-obp1','pkg-obpx1','pkg-obpy1',
  'eol','pkg-eol','eol-plus','eol+','pkg-eol-plus','pkg-eolplus',
  'js','jumpstart','js+','jumpstart+','pkg-js','pkg-jumpstart','pkg-jumpstart-plus','pkg-jsplus'
)
AND (daily_schedule IS NULL OR daily_schedule = '[]'::jsonb);

SELECT
  package_id,
  name,
  jsonb_array_length(COALESCE(daily_schedule,'[]'::jsonb)) AS items
FROM psy_packages
WHERE jsonb_array_length(COALESCE(daily_schedule,'[]'::jsonb)) > 0
ORDER BY package_id;


-- ── FILE: step46_daily_completions.sql ──
-- ============================================================
-- step46_daily_completions.sql
-- Track patient's daily activity completion (checklist).
-- One row per checked item per day. Resets implicitly via log_date.
-- ============================================================

CREATE TABLE IF NOT EXISTS psy_daily_completions (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id   UUID NOT NULL REFERENCES psy_patients(id) ON DELETE CASCADE,
  log_date     DATE NOT NULL DEFAULT CURRENT_DATE,
  item_time    TEXT NOT NULL,      -- 'HH:MM' string from schedule
  activity     TEXT NOT NULL,      -- snapshot of activity name for reference
  completed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(patient_id, log_date, item_time)
);

CREATE INDEX IF NOT EXISTS idx_daily_completions_patient_date
  ON psy_daily_completions(patient_id, log_date);

ALTER TABLE psy_daily_completions ENABLE ROW LEVEL SECURITY;

-- Patient manages own
DO $$ BEGIN
  CREATE POLICY "Patient manage own completions"
    ON psy_daily_completions FOR ALL
    USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()))
    WITH CHECK (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Staff read all (for compliance views)
DO $$ BEGIN
  CREATE POLICY "Staff read completions"
    ON psy_daily_completions FOR SELECT
    USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

SELECT 'Step 46 OK — psy_daily_completions ready' AS status;


-- ── FILE: step47_slot_overhaul.sql ──
-- ============================================================
-- step47_slot_overhaul.sql
-- 1. Add slot_type column ('kob' | 'rawatan') to existing slot config
-- 2. Replace old 4 slots with new 5 slots
-- 3. Seed for both KOB + Rawatan × 5 days
-- 4. Add per-date override table (staff manual lock/unlock specific dates)
-- ============================================================

-- ── 1. Add slot_type column ──
ALTER TABLE psy_kob_slot_config
  ADD COLUMN IF NOT EXISTS slot_type TEXT NOT NULL DEFAULT 'kob'
  CHECK (slot_type IN ('kob','rawatan'));

-- Rebuild unique constraint to include slot_type
ALTER TABLE psy_kob_slot_config
  DROP CONSTRAINT IF EXISTS psy_kob_slot_config_day_of_week_slot_start_key;

ALTER TABLE psy_kob_slot_config DROP CONSTRAINT IF EXISTS psy_kob_slot_config_unique;
ALTER TABLE psy_kob_slot_config
  ADD CONSTRAINT psy_kob_slot_config_unique UNIQUE (slot_type, day_of_week, slot_start);

-- ── 2. Clear old slot definitions (template only, no FK to bookings) ──
DELETE FROM psy_kob_slot_config;

-- ── 3. Seed new 5 slots × 2 types × 5 days ──
-- Slots:
--   1: 07:00 - 09:00  "7-9 pg"
--   2: 09:30 - 11:30  "9.30-11.30 pg"
--   3: 14:00 - 16:00  "2-4 ptg"
--   4: 14:30 - 16:30  "2.30-4.30 ptg"
--   5: 16:30 - 18:30  "4.30-6.30 ptg"
-- Days: Rabu(3), Khamis(4), Jumaat(5), Sabtu(6), Ahad(0)

INSERT INTO psy_kob_slot_config (slot_type, day_of_week, slot_start, slot_end, label, sort_order, is_active)
SELECT
  t.slot_type,
  d.day_of_week,
  s.slot_start::time,
  s.slot_end::time,
  s.label,
  s.sort_order,
  true
FROM
  (VALUES ('kob'), ('rawatan')) AS t(slot_type),
  (VALUES (3), (4), (5), (6), (0)) AS d(day_of_week),
  (VALUES
    ('07:00', '09:00', '7-9 pg',          1),
    ('09:30', '11:30', '9.30-11.30 pg',   2),
    ('14:00', '16:00', '2-4 ptg',         3),
    ('14:30', '16:30', '2.30-4.30 ptg',   4),
    ('16:30', '18:30', '4.30-6.30 ptg',   5)
  ) AS s(slot_start, slot_end, label, sort_order);

-- ── 4. Per-date override (staff lock/offer specific slots per date) ──
CREATE TABLE IF NOT EXISTS psy_slot_date_overrides (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slot_date   DATE NOT NULL,
  slot_type   TEXT NOT NULL CHECK (slot_type IN ('kob','rawatan')),
  slot_start  TIME NOT NULL,
  is_offered  BOOLEAN NOT NULL DEFAULT true,
  note        TEXT,
  created_by  UUID,
  created_at  TIMESTAMPTZ DEFAULT now(),
  updated_at  TIMESTAMPTZ DEFAULT now(),
  UNIQUE (slot_date, slot_type, slot_start)
);

CREATE INDEX IF NOT EXISTS idx_slot_overrides_date
  ON psy_slot_date_overrides(slot_date, slot_type);

ALTER TABLE psy_slot_date_overrides ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "Anyone read slot overrides"
    ON psy_slot_date_overrides FOR SELECT
    USING (auth.uid() IS NOT NULL);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "Staff manage slot overrides"
    ON psy_slot_date_overrides FOR ALL
    USING (EXISTS (
      SELECT 1 FROM psy_profiles
      WHERE id = auth.uid() AND role = 'staff'
      AND staff_role IN ('admin','manager','doctor')
    ));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

SELECT 'Step 47 OK — 5 slot template × 2 types × 5 days + per-date override ready' AS status;


-- ── FILE: step48_feedback_weekly.sql ──
-- ============================================================
-- step48_feedback_weekly.sql
-- Extend psy_feedback to support weekly per-session feedback
-- + overall end-of-treatment feedback (existing behavior).
-- ============================================================

-- Create base table if not exists (was missing in earlier migrations)
CREATE TABLE IF NOT EXISTS psy_feedback (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id  UUID REFERENCES psy_patients(id) ON DELETE CASCADE,
  rating      INT CHECK (rating BETWEEN 1 AND 5),
  comment     TEXT,
  helpful_tags JSONB DEFAULT '[]',
  created_at  TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE psy_feedback ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "Patients manage own feedback" ON psy_feedback FOR ALL
    USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()))
    WITH CHECK (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "Staff read all feedback" ON psy_feedback FOR SELECT
    USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

ALTER TABLE psy_feedback
  ADD COLUMN IF NOT EXISTS feedback_type   TEXT NOT NULL DEFAULT 'overall'
    CHECK (feedback_type IN ('weekly','overall')),
  ADD COLUMN IF NOT EXISTS week_number     INT,
  ADD COLUMN IF NOT EXISTS plan_id         UUID REFERENCES psy_treatment_plans(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS coach_id        UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS coach_name      TEXT,
  ADD COLUMN IF NOT EXISTS coach_rating    INT CHECK (coach_rating BETWEEN 1 AND 5),
  ADD COLUMN IF NOT EXISTS supply_rating   INT CHECK (supply_rating BETWEEN 1 AND 5);

COMMENT ON COLUMN psy_feedback.feedback_type IS
  '"weekly" = per-session feedback (rates coach + supplies); "overall" = end-of-treatment review';

CREATE INDEX IF NOT EXISTS idx_feedback_type_patient
  ON psy_feedback(patient_id, feedback_type);

CREATE INDEX IF NOT EXISTS idx_feedback_coach
  ON psy_feedback(coach_id) WHERE coach_id IS NOT NULL;

SELECT 'Step 48 OK — feedback weekly + KPI tracking ready' AS status;


-- ── FILE: step49_library_package_filter.sql ──
-- ============================================================
-- step49_library_package_filter.sql
-- Library content can be tagged with package IDs to restrict visibility.
-- NULL or empty array = visible to everyone (default).
-- Array of package_ids = only patients on matching package see it.
-- ============================================================

ALTER TABLE psy_library_items
  ADD COLUMN IF NOT EXISTS package_ids TEXT[];

COMMENT ON COLUMN psy_library_items.package_ids IS
  'Package IDs (psy_packages.package_id) that can access this content. NULL/empty = public for all.';

CREATE INDEX IF NOT EXISTS idx_library_package_ids
  ON psy_library_items USING GIN (package_ids);

SELECT 'Step 49 OK — library package filter ready' AS status;


-- ── FILE: step50_package_categories.sql ──
-- ============================================================
-- step50_package_categories.sql
-- Dynamic categories for packages — admin boleh CRUD dari UI
-- ============================================================

CREATE TABLE IF NOT EXISTS psy_package_categories (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug        TEXT NOT NULL UNIQUE,
  label       TEXT NOT NULL,
  badge_color TEXT,
  sort_order  INTEGER NOT NULL DEFAULT 100,
  is_active   BOOLEAN NOT NULL DEFAULT true,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE psy_package_categories IS 'Senarai kategori pakej (dahulu hardcoded: standard/free/vip). Slug disimpan dalam psy_packages.tier.';
COMMENT ON COLUMN psy_package_categories.slug IS 'Stored value in psy_packages.tier (e.g. standard, free, vip, detox)';
COMMENT ON COLUMN psy_package_categories.badge_color IS 'Tailwind color suffix for badge (e.g. gold, green, navy) — null = no badge';

-- Seed kategori sedia ada
INSERT INTO psy_package_categories (slug, label, badge_color, sort_order)
VALUES
  ('standard', 'Program Intensif', NULL,    10),
  ('free',     'Pakej Percuma',    'green', 20),
  ('vip',      'VIP / Premium',    'gold',  30)
ON CONFLICT (slug) DO NOTHING;

-- RLS
ALTER TABLE psy_package_categories ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "Anyone read categories" ON psy_package_categories
    FOR SELECT USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "Staff manage categories" ON psy_package_categories
    FOR ALL USING (
      EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff')
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;


-- ── FILE: step51_treatment_completion.sql ──
-- ============================================================
-- step51_treatment_completion.sql
-- Auto-complete treatment when package expires + audit Google Review clicks
-- ============================================================

-- Add outcome_status column kalau belum ada
ALTER TABLE psy_patients
  ADD COLUMN IF NOT EXISTS outcome_status TEXT;

-- Function: complete expired treatments
CREATE OR REPLACE FUNCTION fn_complete_expired_treatments()
RETURNS TABLE (patient_id UUID, plan_id UUID, action TEXT) AS $$
BEGIN
  RETURN QUERY
  WITH expired_patients AS (
    SELECT p.id AS pat_id, p.user_id, p.active_package_name
    FROM psy_patients p
    WHERE p.active_package_id IS NOT NULL
      AND p.package_expires_at IS NOT NULL
      AND p.package_expires_at < now()
      AND (p.outcome_status IS NULL OR p.outcome_status <> 'completed')
  ),
  plan_updates AS (
    UPDATE psy_treatment_plans tp
       SET status = 'completed'
      FROM expired_patients ep
     WHERE tp.patient_id = ep.pat_id
       AND tp.status = 'active'
    RETURNING tp.id, tp.patient_id
  ),
  patient_updates AS (
    UPDATE psy_patients p
       SET outcome_status = 'completed'
      FROM expired_patients ep
     WHERE p.id = ep.pat_id
    RETURNING p.id
  ),
  notif_inserts AS (
    INSERT INTO psy_notifications (user_id, type, title, body, link, is_read)
    SELECT ep.user_id, 'plan',
           'Rawatan Anda Telah Tamat 🎉',
           'Tahniah atas penyelesaian rawatan ' || COALESCE(ep.active_package_name, 'anda') || '. Sila kongsi maklum balas anda.',
           'feedback.html',
           false
      FROM expired_patients ep
      WHERE NOT EXISTS (
        SELECT 1 FROM psy_notifications n
         WHERE n.user_id = ep.user_id
           AND n.type = 'plan'
           AND n.title LIKE 'Rawatan Anda Telah Tamat%'
      )
    RETURNING user_id
  )
  SELECT ep.pat_id, pu.id, 'completed'::TEXT
    FROM expired_patients ep
    LEFT JOIN plan_updates pu ON pu.patient_id = ep.pat_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION fn_complete_expired_treatments() IS
  'Auto-mark treatment plans + patient outcome_status sebagai completed bila pakej tamat. Insert notifikasi feedback. Boleh dipanggil manual atau via pg_cron.';

-- Optional: schedule daily (kalau pg_cron extension installed)
-- SELECT cron.schedule('complete-expired-treatments', '0 1 * * *', $$SELECT fn_complete_expired_treatments()$$);

-- Jalankan sekali sekarang untuk catch existing expired
SELECT * FROM fn_complete_expired_treatments();

-- ── AUDIT: Google Review click tracking ──
-- Audit log dah ada, tak perlu table baru. Action key: 'google_review.clicked'
COMMENT ON TABLE psy_audit_log IS
  'Audit trail. Untuk Google Review tracking guna action=''google_review.clicked'', meta={rating: N}';

SELECT 'Step 51 OK — treatment auto-completion + audit setup' AS status;


-- ── FILE: step_adherence_alerts.sql ──
-- ============================================================
-- step_adherence_alerts.sql
-- Track patient adherence alerts (madu, dll).
-- Coach dapat notif bila patient kurang madu 4+ hari berturut.
-- ============================================================

CREATE TABLE IF NOT EXISTS psy_adherence_alerts (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id    UUID REFERENCES psy_patients(id) ON DELETE CASCADE NOT NULL,
  alert_type    TEXT NOT NULL,             -- 'madu_low_5days' / 'madu_low_4days'
  trigger_date  DATE NOT NULL,             -- tarikh alert dikira
  details       JSONB DEFAULT '{}',        -- snapshot: { target, days_below: [...], counts: {} }
  notified_coach_id UUID REFERENCES psy_profiles(id),
  acknowledged_by   UUID REFERENCES psy_profiles(id),
  acknowledged_at   TIMESTAMPTZ,
  created_at    TIMESTAMPTZ DEFAULT now(),
  UNIQUE (patient_id, alert_type, trigger_date)  -- elak duplicate sehari
);

CREATE INDEX IF NOT EXISTS idx_adherence_patient ON psy_adherence_alerts(patient_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_adherence_unack   ON psy_adherence_alerts(acknowledged_at) WHERE acknowledged_at IS NULL;

ALTER TABLE psy_adherence_alerts ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "Patient read own adherence" ON psy_adherence_alerts
    FOR SELECT USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "Staff read all adherence" ON psy_adherence_alerts
    FOR SELECT USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "Staff manage adherence" ON psy_adherence_alerts
    FOR ALL USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
    WITH CHECK (auth.uid() IS NOT NULL);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Patient pun boleh insert (sebab patient dashboard akan trigger check)
DO $$ BEGIN
  CREATE POLICY "Patient insert own adherence" ON psy_adherence_alerts
    FOR INSERT WITH CHECK (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;


-- ── FILE: step_bottle_returns.sql ──
-- ============================================================
-- step_bottle_returns.sql
-- Sistem pulangan botol madu untuk patient.
-- ============================================================

CREATE TABLE IF NOT EXISTS psy_bottle_returns (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id           UUID REFERENCES psy_patients(id) ON DELETE CASCADE NOT NULL,
  patient_name         TEXT NOT NULL,
  qty                  INT NOT NULL CHECK (qty > 0),
  photo_urls           TEXT[] DEFAULT '{}',
  criteria_confirmed   JSONB NOT NULL DEFAULT '{}',
  notes                TEXT,
  status               TEXT NOT NULL DEFAULT 'pending'
                       CHECK (status IN ('pending','received','rejected')),
  reject_reason        TEXT,
  verified_by          UUID REFERENCES psy_profiles(id),
  verified_by_name     TEXT,
  verified_at          TIMESTAMPTZ,
  created_at           TIMESTAMPTZ DEFAULT now(),
  updated_at           TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_bottle_returns_patient ON psy_bottle_returns(patient_id);
CREATE INDEX IF NOT EXISTS idx_bottle_returns_status  ON psy_bottle_returns(status, created_at DESC);

ALTER TABLE psy_bottle_returns ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "Patient manage own returns" ON psy_bottle_returns
    FOR ALL USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()))
    WITH CHECK (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "Staff read all returns" ON psy_bottle_returns
    FOR SELECT USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "Staff update returns" ON psy_bottle_returns
    FOR UPDATE USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

COMMENT ON TABLE psy_bottle_returns IS
  'Permohonan pulangan botol madu patient. Chat thread guna psy_audit_log dengan meta.return_id.';
COMMENT ON COLUMN psy_bottle_returns.criteria_confirmed IS
  'JSONB: {tidak_berkarat, bersih, getah_ada, besi_kemas} - semua mesti true sebelum patient boleh submit.';
COMMENT ON COLUMN psy_bottle_returns.photo_urls IS
  'Array URL foto bukti botol (boleh upload multiple).';

-- Storage bucket untuk photos (manual setup di Supabase Dashboard atau via SQL kalau extension dah enable)
-- Bucket name: 'bottle-returns', public read, authenticated insert


-- ── FILE: step_coaching_catalog.sql ──
-- ============================================================
-- step_coaching_catalog.sql
-- Master catalog untuk Bimbingan/Calling & Aktiviti/Rawatan.
-- Admin CRUD via dedicated page. Pakej-edit pakai picker.
-- ============================================================

CREATE TABLE IF NOT EXISTS psy_coaching_catalog (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name          TEXT NOT NULL,
  type          TEXT NOT NULL CHECK (type IN ('bimbingan','aktiviti')),
  description   TEXT,
  category      TEXT,             -- optional grouping (cth: 'Bimbingan Reaksi', 'Herba', dll)
  is_active     BOOLEAN DEFAULT true,
  sort_order    INT DEFAULT 0,
  created_by    UUID REFERENCES psy_profiles(id),
  created_by_name TEXT,
  created_at    TIMESTAMPTZ DEFAULT now(),
  updated_at    TIMESTAMPTZ DEFAULT now(),
  UNIQUE (name, type)
);

CREATE INDEX IF NOT EXISTS idx_coaching_catalog_type ON psy_coaching_catalog(type, sort_order);
CREATE INDEX IF NOT EXISTS idx_coaching_catalog_active ON psy_coaching_catalog(is_active);

ALTER TABLE psy_coaching_catalog ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "Anyone read catalog" ON psy_coaching_catalog
    FOR SELECT USING (auth.uid() IS NOT NULL);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "Staff manage catalog" ON psy_coaching_catalog
    FOR ALL USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
    WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Seed beberapa default
INSERT INTO psy_coaching_catalog (name, type, category, sort_order) VALUES
  ('Bimbingan Reaksi',              'bimbingan', 'Reaksi',     10),
  ('Bimbingan Terapi Peminuman IB', 'bimbingan', 'Terapi',     20),
  ('Bimbingan Terapi Zikir Bersanad','bimbingan', 'Terapi',    30),
  ('Bimbingan Senaman Pernafasan',  'bimbingan', 'Senaman',    40),
  ('Bimbingan Pemakanan',           'bimbingan', 'Diet',       50),
  ('Herba Thoharah',                'aktiviti',  'Herba',      10),
  ('Terapi Madu LTHPG',             'aktiviti',  'Terapi',     20),
  ('Sesi Bekam',                    'aktiviti',  'Rawatan',    30),
  ('Senaman Pernafasan',            'aktiviti',  'Senaman',    40),
  ('Konsultasi Doktor',             'aktiviti',  'Konsultasi', 50),
  ('Berjemur Matahari',             'aktiviti',  'Amalan',     60)
ON CONFLICT (name, type) DO NOTHING;


-- ── FILE: step_inventory_auto_po.sql ──
-- ============================================================
-- step_inventory_auto_po.sql
-- Auto-trigger purchase invoice bila stok ≤ 30% dari max.
-- ============================================================

ALTER TABLE psy_inventory_items
  ADD COLUMN IF NOT EXISTS max_qty NUMERIC(10,2),
  ADD COLUMN IF NOT EXISTS auto_reorder_qty NUMERIC(10,2),
  ADD COLUMN IF NOT EXISTS auto_reorder_enabled BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS last_auto_po_at TIMESTAMPTZ;

COMMENT ON COLUMN psy_inventory_items.max_qty IS
  'Saiz stok penuh / target. Trigger auto-PO bila qty_in_stock <= 30% dari max_qty.';
COMMENT ON COLUMN psy_inventory_items.auto_reorder_qty IS
  'Kuantiti yang sistem cadang dalam auto-PO. Default: max_qty - qty_in_stock.';
COMMENT ON COLUMN psy_inventory_items.auto_reorder_enabled IS
  'true = auto-create purchase invoice bila stok rendah; false = manual sahaja.';
COMMENT ON COLUMN psy_inventory_items.last_auto_po_at IS
  'Tarikh auto-PO terakhir dijana — elak duplikat dalam tempoh pendek.';

-- Mark auto-generated requests
ALTER TABLE psy_inventory_requests
  ADD COLUMN IF NOT EXISTS is_auto_generated BOOLEAN DEFAULT false;

COMMENT ON COLUMN psy_inventory_requests.is_auto_generated IS
  'true = dijana automatik bila stok ≤ 30%, false = manual request oleh staff.';


-- ── FILE: step_inventory_consumption_type.sql ──
-- ============================================================
-- step_inventory_consumption_type.sql
-- Klasifikasi barang inventory ikut sifat consumption:
--   package  = pakai sebagai bekalan pakej (kira dynamic dari patient × pakej supplies)
--   service  = pakai untuk service one-off (cth: DNA test kit, swab, urine cup)
--   general  = consumable umum (sarung tangan, alcohol swab, tissue) — manual min sahaja
-- ============================================================

ALTER TABLE psy_inventory_items
  ADD COLUMN IF NOT EXISTS consumption_type TEXT DEFAULT 'package'
    CHECK (consumption_type IN ('package','service','general'));

COMMENT ON COLUMN psy_inventory_items.consumption_type IS
  'package = bekalan pakej (dynamic auto-calc); service = guna semasa service one-off; general = consumable umum (manual min sahaja).';

UPDATE psy_inventory_items SET consumption_type = 'package' WHERE consumption_type IS NULL;

-- ============================================================
-- psy_services — Senarai service (appointment types) yang clinic tawarkan.
-- Page services.html dan service-detail.html guna table ni.
-- ============================================================
CREATE TABLE IF NOT EXISTS psy_services (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  service_id    TEXT UNIQUE NOT NULL,
  name          TEXT NOT NULL,
  description   TEXT,
  icon          TEXT DEFAULT '⚕',
  price         NUMERIC(10,2) DEFAULT 0,
  duration_min  INT DEFAULT 30,
  sort_order    INT DEFAULT 100,
  is_active     BOOLEAN DEFAULT true,
  supplies      JSONB DEFAULT '[]'::jsonb,
  created_at    TIMESTAMPTZ DEFAULT now(),
  updated_at    TIMESTAMPTZ DEFAULT now()
);

COMMENT ON COLUMN psy_services.supplies IS
  'Senarai item inventory yang diguna per session service. Format: [{item_id, item_name, qty}].';

ALTER TABLE psy_services ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "Staff manage services" ON psy_services FOR ALL
    USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "All authenticated read services" ON psy_services FOR SELECT
    USING (auth.uid() IS NOT NULL);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Kalau table sudah pernah wujud tanpa column supplies (cth. di-create melalui jalan lain), tambah dia.
ALTER TABLE psy_services
  ADD COLUMN IF NOT EXISTS supplies JSONB DEFAULT '[]'::jsonb;

-- Seed beberapa service umum (idempotent — skip jika sudah ada)
INSERT INTO psy_services (service_id, name, description, icon, price, duration_min, sort_order)
VALUES
  ('consultation', 'Consultation with Doctor', 'Sesi konsultasi dengan doktor',           '🩺',  50.00, 30, 10),
  ('dna_test',     'DNA Test',                  'Ujian genetik untuk profil kesihatan',  '🧬', 350.00, 45, 20),
  ('blood_test',   'Blood Test',                'Pemeriksaan darah asas',                '🩸', 120.00, 20, 30),
  ('kob',          'Kursus Orientasi Bestari',  'Kursus orientasi pesakit baru',         '🎓',   0.00, 90, 40)
ON CONFLICT (service_id) DO NOTHING;


-- ── FILE: step_inventory_supplier_info.sql ──
-- ============================================================
-- step_inventory_supplier_info.sql
-- Tambah supplier_info JSONB pada psy_inventory_items
-- Format: { name, cost_per_unit, lead_days, po_min, po_max }
-- ============================================================

ALTER TABLE psy_inventory_items
  ADD COLUMN IF NOT EXISTS supplier_info JSONB DEFAULT '{}'::jsonb;

COMMENT ON COLUMN psy_inventory_items.supplier_info IS
  'Format: { name, cost_per_unit, lead_days, po_min, po_max }. Maklumat pembekal dan cadangan PO.';


-- ── FILE: step_letter_auto_fields.sql ──
-- ============================================================
-- step_letter_auto_fields.sql
-- Admin boleh tambah auto-field tambahan (selain yang hardcoded).
-- Cth: [BMI], [BERAT], [PEKERJAAN] — sistem ambil dari column DB.
-- ============================================================

CREATE TABLE IF NOT EXISTS psy_letter_auto_fields (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  key             TEXT UNIQUE NOT NULL,        -- "BMI" (akan jadi [BMI] dalam templat)
  label           TEXT NOT NULL,               -- "BMI Patient" (yang muncul dalam palette)
  source          TEXT NOT NULL CHECK (source IN ('patient','staff','system')),
  data_path       TEXT NOT NULL,               -- nama column dalam table (cth: 'bmi', 'address', 'phone')
  format_type     TEXT,                        -- optional: 'date' / 'currency' / null
  is_active       BOOLEAN DEFAULT true,
  is_default      BOOLEAN DEFAULT false,       -- true = pre-seeded; boleh delete tapi reset bawa balik
  sort_order      INT DEFAULT 0,
  created_by      UUID REFERENCES psy_profiles(id),
  created_by_name TEXT,
  created_at      TIMESTAMPTZ DEFAULT now(),
  updated_at      TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE psy_letter_auto_fields
  ADD COLUMN IF NOT EXISTS is_default BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS sort_order INT DEFAULT 0;

ALTER TABLE psy_letter_auto_fields ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "Anyone read auto fields" ON psy_letter_auto_fields
    FOR SELECT USING (auth.uid() IS NOT NULL);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "Staff manage auto fields" ON psy_letter_auto_fields
    FOR ALL USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
    WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

COMMENT ON TABLE psy_letter_auto_fields IS
  'Auto-fields untuk surat. Admin manage via UI. Sistem ambil value dari DB column yang ditentukan.';

-- ── Seed default auto-fields ────────────────────────────────
INSERT INTO psy_letter_auto_fields (key, label, source, data_path, format_type, is_default, sort_order) VALUES
  ('NAMA',                'Nama Patient',          'patient', 'full_name',             NULL,       true, 10),
  ('IC',                  'No. K/P',                'patient', 'ic_number',             NULL,       true, 20),
  ('PHONE',               'No. Telefon',            'patient', 'phone',                 NULL,       true, 30),
  ('ALAMAT',              'Alamat Patient',         'patient', 'address',               NULL,       true, 40),
  ('TARIKH_LAHIR',        'Tarikh Lahir',           'patient', 'dob',                   'date',     true, 50),
  ('JANTINA',             'Jantina',                'patient', 'gender',                NULL,       true, 60),
  ('BANGSA',              'Bangsa',                 'patient', 'race',                  NULL,       true, 70),
  ('AGAMA',               'Agama',                  'patient', 'religion',              NULL,       true, 80),
  ('PEKERJAAN',           'Pekerjaan',              'patient', 'occupation',            NULL,       true, 90),
  ('PAKEJ',               'Pakej Aktif',            'patient', 'active_package_name',   NULL,       true, 100),
  ('TARIKH_MULA_RAWATAN', 'Tarikh Mula Rawatan',    'patient', 'package_purchased_at',  'date',     true, 110),
  ('STAFF_NAMA',          'Nama Staff',             'staff',   'full_name',             NULL,       true, 200),
  ('STAFF_JAWATAN',       'Jawatan Staff',          'staff',   'staff_role',            NULL,       true, 210),
  ('STAFF_REG_NO',        'No. Pendaftaran Staff',  'staff',   'registration_no',       NULL,       true, 220),
  ('STAFF_SPECIALIZATION','Pengkhususan Staff',     'staff',   'specialization',        NULL,       true, 230),
  ('TARIKH',              'Tarikh Hari Ini',        'system',  '__today__',             NULL,       true, 300),
  ('RUJUKAN',             'Nombor Rujukan',         'system',  '__ref_number__',        NULL,       true, 310)
ON CONFLICT (key) DO NOTHING;


-- ── FILE: step_letter_base.sql ──
-- ============================================================
-- step_letters.sql
-- Sistem generate surat rasmi (KWSP, PERKESO, RELA, dll).
-- Patient request → Staff fill template → sign → patient download PDF.
-- ============================================================

-- Staff signature (upload sekali, reuse semua surat)
ALTER TABLE psy_profiles
  ADD COLUMN IF NOT EXISTS signature_url TEXT;

COMMENT ON COLUMN psy_profiles.signature_url IS
  'URL signature image staff. Embed dalam surat rasmi yang di-sign.';

-- Permintaan surat dari patient
CREATE TABLE IF NOT EXISTS psy_letter_requests (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id      UUID REFERENCES psy_patients(id) ON DELETE CASCADE NOT NULL,
  patient_name    TEXT NOT NULL,
  template_code   TEXT NOT NULL,
  template_name   TEXT NOT NULL,
  reason          TEXT,
  field_values    JSONB DEFAULT '{}',
  status          TEXT NOT NULL DEFAULT 'pending'
                  CHECK (status IN ('pending','issued','rejected','cancelled')),
  reject_reason   TEXT,
  created_at      TIMESTAMPTZ DEFAULT now(),
  updated_at      TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_letter_req_patient ON psy_letter_requests(patient_id);
CREATE INDEX IF NOT EXISTS idx_letter_req_status  ON psy_letter_requests(status, created_at DESC);

ALTER TABLE psy_letter_requests ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "Patient manage own letter requests" ON psy_letter_requests
    FOR ALL USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()))
    WITH CHECK (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "Staff read all letter requests" ON psy_letter_requests
    FOR SELECT USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "Staff update letter requests" ON psy_letter_requests
    FOR UPDATE USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;


-- Surat yang telah dikeluarkan & disign
CREATE TABLE IF NOT EXISTS psy_letter_issued (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id      UUID REFERENCES psy_letter_requests(id) ON DELETE SET NULL,
  patient_id      UUID REFERENCES psy_patients(id) ON DELETE CASCADE,  -- nullable: NULL = internal document
  patient_name    TEXT NOT NULL,
  template_code   TEXT NOT NULL,
  template_name   TEXT NOT NULL,
  field_values    JSONB NOT NULL DEFAULT '{}',
  ref_number      TEXT,  -- cth: ISW/RELA/2026/0001
  signed_by       UUID REFERENCES psy_profiles(id),
  signed_by_name  TEXT NOT NULL,
  signed_by_role  TEXT,
  signature_url   TEXT,  -- snapshot signature staff masa sign
  signed_at       TIMESTAMPTZ DEFAULT now(),
  created_at      TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_letter_issued_patient ON psy_letter_issued(patient_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_letter_issued_code    ON psy_letter_issued(template_code);

ALTER TABLE psy_letter_issued ENABLE ROW LEVEL SECURITY;

-- Untuk DB sedia ada — drop NOT NULL kalau ada
ALTER TABLE psy_letter_issued ALTER COLUMN patient_id DROP NOT NULL;

DO $$ BEGIN
  CREATE POLICY "Patient read own issued letters" ON psy_letter_issued
    FOR SELECT USING (patient_id IS NOT NULL AND patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "Staff manage issued letters" ON psy_letter_issued
    FOR ALL USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
    WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;


-- ── FILE: step_letter_files.sql ──
-- ============================================================
-- step_letter_files.sql
-- Refactor sistem surat ke document repository (Word/PDF upload).
-- Staff upload templates → download → fill dalam Word → save PDF →
-- upload PDF balik untuk patient.
-- ============================================================

-- ── Storage untuk uploaded template files ────────────────────
CREATE TABLE IF NOT EXISTS psy_letter_template_files (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name            TEXT NOT NULL,            -- cth: "Surat Permohonan KWSP"
  description     TEXT,
  file_url        TEXT NOT NULL,
  file_name       TEXT NOT NULL,            -- nama original file
  file_size       INT,                      -- bytes
  file_type       TEXT,                     -- 'docx', 'pdf', 'doc'
  uploaded_by     UUID REFERENCES psy_profiles(id),
  uploaded_by_name TEXT,
  created_at      TIMESTAMPTZ DEFAULT now()
);

-- Sokong dua jenis templat: 'file' (upload Word/PDF) atau 'inline' (cipta dalam sistem)
ALTER TABLE psy_letter_template_files
  ADD COLUMN IF NOT EXISTS template_type TEXT DEFAULT 'file'
    CHECK (template_type IN ('file','inline')),
  ADD COLUMN IF NOT EXISTS body_html TEXT;

-- Buat file_url nullable (inline tak ada file)
ALTER TABLE psy_letter_template_files ALTER COLUMN file_url DROP NOT NULL;
ALTER TABLE psy_letter_template_files ALTER COLUMN file_name DROP NOT NULL;

CREATE INDEX IF NOT EXISTS idx_letter_tpl_files_created ON psy_letter_template_files(created_at DESC);

ALTER TABLE psy_letter_template_files ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "Staff manage template files" ON psy_letter_template_files
    FOR ALL USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
    WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;


-- ── Issued letters: tambah file_url untuk uploaded PDF ───────
ALTER TABLE psy_letter_issued
  ADD COLUMN IF NOT EXISTS file_url     TEXT,
  ADD COLUMN IF NOT EXISTS file_name    TEXT,
  ADD COLUMN IF NOT EXISTS file_size    INT,
  ADD COLUMN IF NOT EXISTS template_file_id UUID REFERENCES psy_letter_template_files(id) ON DELETE SET NULL;

COMMENT ON COLUMN psy_letter_issued.file_url IS
  'URL PDF/Word file lengkap yang dah disign (upload oleh staff).';
COMMENT ON COLUMN psy_letter_issued.template_file_id IS
  'Refer template yang digunakan (untuk track sahaja).';

-- Field lama (field_values, signature_url, body_html) jadi optional/legacy
-- Tak perlu drop sebab old data mungkin ada.


-- ── FILE: step_letter_simple.sql ──
-- ============================================================
-- step_letter_simple.sql
-- Sistem surat: format tetap (letterhead auto), admin define
-- template body + fields, staff fill form → generate PDF.
-- ============================================================

CREATE TABLE IF NOT EXISTS psy_letter_templates (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name            TEXT NOT NULL,
  description     TEXT,
  category        TEXT NOT NULL DEFAULT 'patient'
                  CHECK (category IN ('patient','internal')),
  recipient       TEXT,                 -- "Pengurus Besar, KWSP, ..."
  title           TEXT,                 -- "PERMOHONAN PENGELUARAN AHLI KWSP"
  body            TEXT NOT NULL,        -- plain text + [PLACEHOLDER]
  fields          JSONB NOT NULL DEFAULT '[]',  -- [{key,label,type,autofill}]
  created_by      UUID REFERENCES psy_profiles(id),
  created_by_name TEXT,
  created_at      TIMESTAMPTZ DEFAULT now(),
  updated_at      TIMESTAMPTZ DEFAULT now()
);

-- Tambah kalau table dah wujud
ALTER TABLE psy_letter_templates
  ADD COLUMN IF NOT EXISTS category TEXT NOT NULL DEFAULT 'patient';

ALTER TABLE psy_letter_templates ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "Anyone read templates" ON psy_letter_templates
    FOR SELECT USING (auth.uid() IS NOT NULL);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "Staff manage templates" ON psy_letter_templates
    FOR ALL USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
    WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Cleanup old tables (jika ada, dari iterasi lepas)
DROP TABLE IF EXISTS psy_letter_template_overrides;

-- Drop column dalam psy_letter_issued yang refer psy_letter_template_files dulu
ALTER TABLE psy_letter_issued DROP COLUMN IF EXISTS template_file_id;
DROP TABLE IF EXISTS psy_letter_template_files;


-- ── FILE: step_letter_template_overrides.sql ──
-- ============================================================
-- step_letter_template_overrides.sql
-- Staff boleh override templates surat hardcoded.
-- Cara kerja: DB override → kalau tiada, fallback ke hardcoded JS templates.
-- ============================================================

CREATE TABLE IF NOT EXISTS psy_letter_template_overrides (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  template_code   TEXT UNIQUE NOT NULL,  -- 'rela', 'kwsp', etc.
  name            TEXT NOT NULL,
  description     TEXT,
  icon            TEXT,
  body_html       TEXT NOT NULL,
  fields          JSONB NOT NULL DEFAULT '[]',  -- [{key,label,type,required,autofill}]
  updated_by      UUID REFERENCES psy_profiles(id),
  updated_by_name TEXT,
  updated_at      TIMESTAMPTZ DEFAULT now(),
  created_at      TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE psy_letter_template_overrides ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "Staff read templates" ON psy_letter_template_overrides
    FOR SELECT USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "Staff manage templates" ON psy_letter_template_overrides
    FOR ALL USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
    WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Patient juga boleh read (untuk render surat masa download — sebab template_code dirujuk)
DO $$ BEGIN
  CREATE POLICY "Patient read templates" ON psy_letter_template_overrides
    FOR SELECT USING (auth.uid() IS NOT NULL);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

COMMENT ON TABLE psy_letter_template_overrides IS
  'Override templates surat hardcoded. Tiada row = guna hardcoded defaults.';


-- ── FILE: step_package_extension_price.sql ──
-- Phase 1: Harga tambah minggu rawatan (extension) — admin tetapkan per pakej.

ALTER TABLE psy_packages
  ADD COLUMN IF NOT EXISTS extension_price_per_week NUMERIC(10,2) DEFAULT 50;

COMMENT ON COLUMN psy_packages.extension_price_per_week IS
  'Harga (RM) untuk tambah satu minggu rawatan bila patient miss sesi. Default RM 50.';


-- ── FILE: step_package_meet_link.sql ──
-- Add single Gmeet link per package — used for all weeks with online/both mode.
ALTER TABLE psy_packages
  ADD COLUMN IF NOT EXISTS meet_link TEXT;

COMMENT ON COLUMN psy_packages.meet_link IS
  'Pautan Gmeet recurring untuk pakej. Dipaparkan kepada patient bila minggu semasa adalah online/both.';


-- ── FILE: step_patient_address_residence.sql ──
-- ============================================================
-- STEP — Patient Address: Residence + City/State columns
-- Tambah alamat kediaman (berasingan dari surat-menyurat) +
-- pecahkan bandar / negeri untuk filter & laporan.
-- ============================================================

ALTER TABLE psy_patients
  ADD COLUMN IF NOT EXISTS home_address TEXT,
  ADD COLUMN IF NOT EXISTS city         TEXT,
  ADD COLUMN IF NOT EXISTS state        TEXT;

COMMENT ON COLUMN psy_patients.home_address IS
  'Alamat kediaman pesakit (berbeza dari address yang digunakan untuk surat-menyurat / mailing).';
COMMENT ON COLUMN psy_patients.city  IS 'Bandar (sebahagian dari alamat kediaman).';
COMMENT ON COLUMN psy_patients.state IS 'Negeri (Selangor, Johor, dll.).';

CREATE INDEX IF NOT EXISTS idx_patients_state ON psy_patients(state);

SELECT 'Step Patient Address OK — home_address, city, state added' AS status;


-- ── FILE: step_patient_hub_v2.sql ──
-- ============================================================
-- STEP — Patient Hub v2 schema
-- 1. Rename psy_dna_reports → psy_medical_reports + expand
-- 2. NEW psy_patient_notes (Nota Coach / Sesi / General)
-- 3. NEW psy_patient_documents (KYC, IC, Persetujuan, Laporan, Gambar)
-- 4. Patient supplies = derived dari coaching_schedule + audit log (no new table)
-- ============================================================

-- ───────── 1. EXPAND DNA → Medical Reports (general purpose) ─────────
-- Rename only if old table exists with old name; otherwise skip
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'psy_dna_reports')
     AND NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'psy_medical_reports') THEN
    ALTER TABLE psy_dna_reports RENAME TO psy_medical_reports;
  END IF;
END $$;

-- If neither exists, create fresh
CREATE TABLE IF NOT EXISTS psy_medical_reports (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id      UUID NOT NULL REFERENCES psy_patients(id) ON DELETE CASCADE,
  file_name       TEXT NOT NULL,
  file_path       TEXT,
  file_url        TEXT,
  notes           TEXT,
  uploaded_by     UUID,
  uploaded_by_name TEXT,
  uploaded_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Add expanded columns
ALTER TABLE psy_medical_reports
  ADD COLUMN IF NOT EXISTS report_type    TEXT DEFAULT 'dna',
  ADD COLUMN IF NOT EXISTS title          TEXT,
  ADD COLUMN IF NOT EXISTS status         TEXT DEFAULT 'pending',
  ADD COLUMN IF NOT EXISTS sample_date    DATE,
  ADD COLUMN IF NOT EXISTS sample_type    TEXT,
  ADD COLUMN IF NOT EXISTS result_date    DATE,
  ADD COLUMN IF NOT EXISTS analysis_duration_days INT,
  ADD COLUMN IF NOT EXISTS categories     JSONB DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS summary        TEXT,
  ADD COLUMN IF NOT EXISTS doctor_id      UUID,
  ADD COLUMN IF NOT EXISTS doctor_name    TEXT,
  ADD COLUMN IF NOT EXISTS doctor_review  TEXT,
  ADD COLUMN IF NOT EXISTS review_status  TEXT DEFAULT 'pending',
  ADD COLUMN IF NOT EXISTS reviewed_at    TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS shared_with_patient BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS shared_at      TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS attached_files JSONB DEFAULT '[]';

COMMENT ON COLUMN psy_medical_reports.report_type IS
  'dna | xray | ct | mri | ultrasound | blood | colonoscopy | endoscopy | other';
COMMENT ON COLUMN psy_medical_reports.status IS
  'pending | sampling | lab | ready | reviewed';
COMMENT ON COLUMN psy_medical_reports.review_status IS
  'pending | diluluskan | ditolak';

CREATE INDEX IF NOT EXISTS idx_medical_reports_patient ON psy_medical_reports(patient_id, uploaded_at DESC);
CREATE INDEX IF NOT EXISTS idx_medical_reports_type    ON psy_medical_reports(report_type);

ALTER TABLE psy_medical_reports ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  CREATE POLICY "staff_medical_all" ON psy_medical_reports FOR ALL
    USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "patient_medical_read" ON psy_medical_reports FOR SELECT
    USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ───────── 2. NEW: Patient Notes ─────────
CREATE TABLE IF NOT EXISTS psy_patient_notes (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id   UUID NOT NULL REFERENCES psy_patients(id) ON DELETE CASCADE,
  note_type    TEXT NOT NULL DEFAULT 'general'
               CHECK (note_type IN ('general','coach','sesi','checkin','vitals','medical','dna','peringatan')),
  content      TEXT NOT NULL,
  related_session_id UUID,
  related_report_id  UUID,
  actor_id     UUID,
  actor_name   TEXT,
  actor_role   TEXT,
  is_pinned    BOOLEAN DEFAULT false,
  visibility   TEXT DEFAULT 'staff'
               CHECK (visibility IN ('staff','patient','both')),
  created_at   TIMESTAMPTZ DEFAULT now(),
  updated_at   TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_patient_notes_patient ON psy_patient_notes(patient_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_patient_notes_type    ON psy_patient_notes(note_type);

ALTER TABLE psy_patient_notes ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  CREATE POLICY "staff_notes_all" ON psy_patient_notes FOR ALL
    USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "patient_notes_read" ON psy_patient_notes FOR SELECT
    USING (visibility IN ('patient','both') AND
           patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ───────── 3. NEW: Patient Documents ─────────
CREATE TABLE IF NOT EXISTS psy_patient_documents (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id   UUID NOT NULL REFERENCES psy_patients(id) ON DELETE CASCADE,
  doc_type     TEXT NOT NULL DEFAULT 'other'
               CHECK (doc_type IN ('kyc','ic','passport','persetujuan','laporan_perubatan','gambar','surat_rasmi','resit','other')),
  doc_label    TEXT NOT NULL,
  description  TEXT,
  file_name    TEXT,
  file_path    TEXT,
  file_url     TEXT,
  file_size    INT,
  status       TEXT DEFAULT 'pending'
               CHECK (status IN ('pending','disahkan','disemak','tertunggak','ditolak')),
  uploaded_by  UUID,
  uploaded_by_name TEXT,
  uploaded_at  TIMESTAMPTZ DEFAULT now(),
  approved_by  UUID,
  approved_at  TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_patient_docs_patient ON psy_patient_documents(patient_id, uploaded_at DESC);
CREATE INDEX IF NOT EXISTS idx_patient_docs_type    ON psy_patient_documents(doc_type);

ALTER TABLE psy_patient_documents ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  CREATE POLICY "staff_docs_all" ON psy_patient_documents FOR ALL
    USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "patient_docs_read_own" ON psy_patient_documents FOR SELECT
    USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "patient_docs_insert_own" ON psy_patient_documents FOR INSERT
    WITH CHECK (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

SELECT 'Step Patient Hub v2 OK — medical_reports expanded, notes + documents created' AS status;


-- ── FILE: step_plan_schedule_setup.sql ──
-- Phase 1: Treatment plan schedule preferences
-- Patient pilih sekali masa onboarding: pasangan hari + jam untuk setiap hari.
-- Sistem auto-seed 24 sesi (12 minggu × 2 hari).

ALTER TABLE psy_treatment_plans
  ADD COLUMN IF NOT EXISTS preferred_pair TEXT CHECK (preferred_pair IN ('fri_sat','sat_sun')),
  ADD COLUMN IF NOT EXISTS preferred_time_day1 TIME,   -- jam hari pertama (Jum atau Sab)
  ADD COLUMN IF NOT EXISTS preferred_time_day2 TIME,   -- jam hari kedua (Sab atau Ahad)
  ADD COLUMN IF NOT EXISTS schedule_setup_at TIMESTAMPTZ;

COMMENT ON COLUMN psy_treatment_plans.preferred_pair IS
  'Pasangan hari pilihan patient: fri_sat (Jumaat+Sabtu) atau sat_sun (Sabtu+Ahad).';
COMMENT ON COLUMN psy_treatment_plans.preferred_time_day1 IS
  'Jam pilihan hari pertama dalam pair (Jumaat untuk fri_sat, Sabtu untuk sat_sun).';
COMMENT ON COLUMN psy_treatment_plans.preferred_time_day2 IS
  'Jam pilihan hari kedua dalam pair (Sabtu untuk fri_sat, Ahad untuk sat_sun).';
COMMENT ON COLUMN psy_treatment_plans.schedule_setup_at IS
  'Bila patient siap setup jadual. NULL = belum setup, tunjuk wizard.';


-- ── FILE: step_plan_session_day.sql ──
-- Phase 1: 2 sesi seminggu — tambah session_day untuk pisahkan sesi A vs B.
-- Existing rows tetap session_day=1 supaya plan lama tak terjejas.

ALTER TABLE psy_plan_weekly_progress
  ADD COLUMN IF NOT EXISTS session_day INT DEFAULT 1 CHECK (session_day IN (1,2)),
  ADD COLUMN IF NOT EXISTS is_extension BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS extension_for_week INT,
  ADD COLUMN IF NOT EXISTS extension_price NUMERIC(10,2),
  ADD COLUMN IF NOT EXISTS extension_paid_at TIMESTAMPTZ;

-- Drop old uniqueness yang assume 1 row per minggu
ALTER TABLE psy_plan_weekly_progress
  DROP CONSTRAINT IF EXISTS psy_plan_weekly_progress_plan_id_week_number_key;

-- Composite unique: 1 row per sesi (plan + minggu + day)
DO $$ BEGIN
  ALTER TABLE psy_plan_weekly_progress
    ADD CONSTRAINT psy_plan_weekly_progress_plan_week_day_key
    UNIQUE (plan_id, week_number, session_day);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Status tambahan untuk extension flow
ALTER TABLE psy_plan_weekly_progress
  DROP CONSTRAINT IF EXISTS psy_plan_weekly_progress_status_check;

ALTER TABLE psy_plan_weekly_progress
  ADD CONSTRAINT psy_plan_weekly_progress_status_check
  CHECK (status IN (
    'pending','booked','hadir','reschedule','cancel','consultation_done',
    'extension_pending_payment','extension_paid'
  ));

COMMENT ON COLUMN psy_plan_weekly_progress.session_day IS
  '1 = sesi pertama dalam minggu (Jum/Sab), 2 = sesi kedua (Sab/Ahad). Default 1 untuk backward compat.';
COMMENT ON COLUMN psy_plan_weekly_progress.is_extension IS
  'true = minggu tambahan (extension) selepas miss sesi. Perlu bayar sebelum tempah.';
COMMENT ON COLUMN psy_plan_weekly_progress.extension_for_week IS
  'Refer minggu asal yang miss, untuk audit trail.';


-- ── FILE: step_procedure_kits.sql ──
-- ============================================================
-- step_procedure_kits.sql
-- Kit prosedur — satu kit = set item inventory yang diguna
-- untuk satu prosedur (cth: IV Drip Setup, DNA Test Kit).
-- Bila pakej ada kit dalam supplies, demand auto-expand
-- kepada semua sub-items dalam kit.
-- ============================================================

CREATE TABLE IF NOT EXISTS psy_procedure_kits (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name         TEXT NOT NULL UNIQUE,
  description  TEXT,
  category     TEXT DEFAULT 'Umum',
  items        JSONB NOT NULL DEFAULT '[]'::jsonb,
  is_active    BOOLEAN DEFAULT true,
  created_by   UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  created_at   TIMESTAMPTZ DEFAULT now(),
  updated_at   TIMESTAMPTZ DEFAULT now()
);

COMMENT ON COLUMN psy_procedure_kits.items IS
  'Format: [{item_id, item_name, qty, unit}]. Senarai inventory item yang diperlukan per satu prosedur.';

ALTER TABLE psy_procedure_kits ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  CREATE POLICY "Staff manage kits" ON psy_procedure_kits FOR ALL
    USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Seed contoh kits
INSERT INTO psy_procedure_kits (name, description, category, items) VALUES
(
  'IV Drip Setup',
  'Set lengkap untuk satu sesi IV Saline Drip',
  'IV Therapy',
  '[
    {"item_id": null, "item_name": "IV Line",       "qty": 1, "unit": "unit"},
    {"item_id": null, "item_name": "Gloves",         "qty": 2, "unit": "pasang"},
    {"item_id": null, "item_name": "Alcohol Swab",   "qty": 3, "unit": "unit"},
    {"item_id": null, "item_name": "Cotton Ball",    "qty": 2, "unit": "unit"},
    {"item_id": null, "item_name": "Branula",        "qty": 1, "unit": "unit"},
    {"item_id": null, "item_name": "Plaster",        "qty": 2, "unit": "unit"},
    {"item_id": null, "item_name": "Scotch Tape",    "qty": 1, "unit": "unit"}
  ]'::jsonb
),
(
  'Blood Test Setup',
  'Set lengkap untuk pengambilan darah',
  'Diagnostik',
  '[
    {"item_id": null, "item_name": "Gloves",         "qty": 1, "unit": "pasang"},
    {"item_id": null, "item_name": "Alcohol Swab",   "qty": 2, "unit": "unit"},
    {"item_id": null, "item_name": "Cotton Ball",    "qty": 2, "unit": "unit"},
    {"item_id": null, "item_name": "Needle/Vacutainer","qty": 1, "unit": "unit"},
    {"item_id": null, "item_name": "Plaster",        "qty": 1, "unit": "unit"},
    {"item_id": null, "item_name": "Blood Tube",     "qty": 3, "unit": "tube"}
  ]'::jsonb
),
(
  'DNA Test Setup',
  'Set untuk pengambilan sampel DNA (buccal swab)',
  'Diagnostik',
  '[
    {"item_id": null, "item_name": "Gloves",         "qty": 1, "unit": "pasang"},
    {"item_id": null, "item_name": "DNA Swab",       "qty": 2, "unit": "unit"},
    {"item_id": null, "item_name": "DNA Collection Tube", "qty": 1, "unit": "unit"},
    {"item_id": null, "item_name": "Ziplock Bag",    "qty": 1, "unit": "unit"}
  ]'::jsonb
)
ON CONFLICT DO NOTHING;


-- ── FILE: step_product_inventory_link.sql ──
-- ============================================================
-- step_product_inventory_link.sql
-- Link psy_products → psy_inventory_items supaya stok shop
-- auto-deduct dari inventory bila order paid.
-- ============================================================

ALTER TABLE psy_products
  ADD COLUMN IF NOT EXISTS inventory_item_id UUID REFERENCES psy_inventory_items(id) ON DELETE SET NULL;

COMMENT ON COLUMN psy_products.inventory_item_id IS
  'Link ke inventory item. Bila order status=paid, qty_in_stock auto-deduct ikut quantity dibeli.';

-- ============================================================
-- Trigger: auto-deduct inventory bila order status tukar ke 'paid'.
-- Items JSONB format: [{product_id: "...", qty: N, ...}, ...]
-- ============================================================
CREATE OR REPLACE FUNCTION psy_order_deduct_inventory()
RETURNS TRIGGER AS $$
DECLARE
  v_item       JSONB;
  v_product    psy_products%ROWTYPE;
  v_qty        NUMERIC;
BEGIN
  IF NEW.status = 'paid' AND (OLD.status IS DISTINCT FROM 'paid') THEN
    FOR v_item IN SELECT * FROM jsonb_array_elements(COALESCE(NEW.items, '[]'::jsonb))
    LOOP
      -- Match by product_id (text id) atau id (UUID) — support kedua-dua format
      SELECT * INTO v_product FROM psy_products
        WHERE product_id = v_item->>'product_id'
           OR id::text   = v_item->>'product_id'
        LIMIT 1;

      IF v_product.inventory_item_id IS NOT NULL THEN
        v_qty := COALESCE((v_item->>'qty')::numeric, (v_item->>'quantity')::numeric, 1);
        UPDATE psy_inventory_items
          SET qty_in_stock = GREATEST(0, qty_in_stock - v_qty),
              updated_at   = now()
          WHERE id = v_product.inventory_item_id;
      END IF;
    END LOOP;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_psy_order_deduct_inventory ON psy_orders;
CREATE TRIGGER trg_psy_order_deduct_inventory
  AFTER UPDATE ON psy_orders
  FOR EACH ROW EXECUTE FUNCTION psy_order_deduct_inventory();


-- ── FILE: step_products_enhanced.sql ──
-- ============================================================
-- STEP — psy_products enhanced fields
-- Untuk sokong mockup baru: jenama, promo, stok lanjut, media, butiran, visibility
-- ============================================================

ALTER TABLE psy_products
  ADD COLUMN IF NOT EXISTS sku           TEXT,
  ADD COLUMN IF NOT EXISTS brand         TEXT,
  ADD COLUMN IF NOT EXISTS description_short TEXT,
  ADD COLUMN IF NOT EXISTS status        TEXT DEFAULT 'active',
  ADD COLUMN IF NOT EXISTS promo_price   NUMERIC(10,2),
  ADD COLUMN IF NOT EXISTS promo_until   DATE,
  ADD COLUMN IF NOT EXISTS min_stock     INT DEFAULT 5,
  ADD COLUMN IF NOT EXISTS unit          TEXT DEFAULT 'unit',
  ADD COLUMN IF NOT EXISTS track_inventory  BOOLEAN DEFAULT true,
  ADD COLUMN IF NOT EXISTS low_stock_alert  BOOLEAN DEFAULT true,
  ADD COLUMN IF NOT EXISTS image_urls    JSONB DEFAULT '[]',
  ADD COLUMN IF NOT EXISTS weight_size   TEXT,
  ADD COLUMN IF NOT EXISTS supplier      TEXT,
  ADD COLUMN IF NOT EXISTS tags          JSONB DEFAULT '[]',
  ADD COLUMN IF NOT EXISTS notes         TEXT,
  ADD COLUMN IF NOT EXISTS visible_in_shop  BOOLEAN DEFAULT true,
  ADD COLUMN IF NOT EXISTS featured      BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS online_purchase BOOLEAN DEFAULT true;

-- Backfill sku from product_id if null
UPDATE psy_products SET sku = product_id WHERE sku IS NULL;

-- Backfill status from is_active
UPDATE psy_products SET status = 'active'   WHERE status IS NULL AND is_active = true;
UPDATE psy_products SET status = 'inactive' WHERE status IS NULL AND is_active = false;

SELECT 'Step psy_products enhanced OK' AS status;

