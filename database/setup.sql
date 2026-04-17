-- ============================================================
-- ISW SHIFA HUB — DATABASE SETUP
-- Patient + Staff schema · run sekali dalam Supabase SQL Editor
-- ============================================================

-- ============================================================
-- PROFILES
-- ============================================================
CREATE TABLE profiles (
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

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Read all profiles authenticated" ON profiles FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "Update own profile" ON profiles FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Insert own profile" ON profiles FOR INSERT WITH CHECK (auth.uid() = id OR auth.role() = 'service_role');

CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, role, email)
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

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- ============================================================
-- PATIENTS
-- ============================================================
CREATE TABLE patients (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id),
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
  status TEXT DEFAULT 'active' CHECK (status IN ('pending_kyc','active','inactive','rejected')),
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE patients ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Staff manage patients" ON patients FOR ALL
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'staff'));
CREATE POLICY "Patients read own record" ON patients FOR SELECT USING (user_id = auth.uid());

-- ============================================================
-- APPOINTMENTS
-- ============================================================
CREATE TABLE appointments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id UUID REFERENCES patients(id),
  staff_id UUID REFERENCES profiles(id),
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

ALTER TABLE appointments ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Staff manage appointments" ON appointments FOR ALL
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'staff'));
CREATE POLICY "Patients read own appointments" ON appointments FOR SELECT
  USING (patient_id IN (SELECT id FROM patients WHERE user_id = auth.uid()));

-- ============================================================
-- VITALS
-- ============================================================
CREATE TABLE vitals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id UUID REFERENCES patients(id) NOT NULL,
  recorded_by UUID REFERENCES profiles(id),
  bp_systolic INT,
  bp_diastolic INT,
  heart_rate INT,
  spo2 NUMERIC(5,2),
  temperature NUMERIC(4,1),
  weight NUMERIC(5,1),
  height NUMERIC(5,1),
  bmi NUMERIC(4,1),
  waist_cm NUMERIC(5,1),
  rbs NUMERIC(4,1),
  phq2_score INT,
  gad2_score INT,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE vitals ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Staff manage vitals" ON vitals FOR ALL
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'staff'));
CREATE POLICY "Patients read own vitals" ON vitals FOR SELECT
  USING (patient_id IN (SELECT id FROM patients WHERE user_id = auth.uid()));

-- ============================================================
-- SOAP NOTES
-- ============================================================
CREATE TABLE soap_notes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  appointment_id UUID REFERENCES appointments(id),
  patient_id UUID REFERENCES patients(id) NOT NULL,
  doctor_id UUID REFERENCES profiles(id) NOT NULL,
  chief_complaint TEXT,
  hpi TEXT,
  ros_positives TEXT,
  meds_adherence TEXT,
  examination TEXT,
  diagnoses JSONB DEFAULT '[]',
  clinical_reasoning TEXT,
  plan_medications JSONB DEFAULT '[]',
  plan_labs JSONB DEFAULT '[]',
  plan_referrals JSONB DEFAULT '[]',
  follow_up TEXT,
  status TEXT DEFAULT 'draft' CHECK (status IN ('draft','signed','amended')),
  signed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE soap_notes ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Staff manage soap" ON soap_notes FOR ALL
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'staff'));
CREATE POLICY "Patients read own soap" ON soap_notes FOR SELECT
  USING (patient_id IN (SELECT id FROM patients WHERE user_id = auth.uid()));

-- ============================================================
-- TREATMENT PLANS
-- ============================================================
CREATE TABLE treatment_plans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id UUID REFERENCES patients(id) NOT NULL,
  doctor_id UUID REFERENCES profiles(id),
  name TEXT NOT NULL,
  template TEXT,
  duration_weeks INT DEFAULT 13,
  current_week INT DEFAULT 1,
  bio_goals JSONB DEFAULT '[]',
  psycho_goals JSONB DEFAULT '[]',
  social_goals JSONB DEFAULT '[]',
  spiritual_goals JSONB DEFAULT '[]',
  status TEXT DEFAULT 'active' CHECK (status IN ('draft','active','completed','paused')),
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE treatment_plans ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Staff manage plans" ON treatment_plans FOR ALL
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'staff'));
CREATE POLICY "Patients read own plans" ON treatment_plans FOR SELECT
  USING (patient_id IN (SELECT id FROM patients WHERE user_id = auth.uid()));

-- ============================================================
-- RISK ALERTS
-- ============================================================
CREATE TABLE risk_alerts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id UUID REFERENCES patients(id) NOT NULL,
  patient_name TEXT,
  created_by UUID REFERENCES profiles(id),
  created_by_name TEXT,
  severity TEXT NOT NULL CHECK (severity IN ('low','moderate','high','critical')),
  category TEXT,
  description TEXT NOT NULL,
  context JSONB DEFAULT '{}',
  status TEXT DEFAULT 'open' CHECK (status IN ('open','acknowledged','resolved','escalated')),
  acknowledged_by UUID REFERENCES profiles(id),
  resolved_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE risk_alerts ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Staff manage risks" ON risk_alerts FOR ALL
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'staff'));

-- ============================================================
-- KYC SUBMISSIONS
-- ============================================================
CREATE TABLE kyc_submissions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_name TEXT NOT NULL,
  ic_number TEXT,
  phone TEXT,
  email TEXT,
  address TEXT,
  emergency_contact TEXT,
  insurance_info JSONB,
  documents JSONB DEFAULT '{}',
  consent_data_processing BOOLEAN DEFAULT false,
  consent_health_records BOOLEAN DEFAULT false,
  consent_research BOOLEAN DEFAULT false,
  consent_marketing BOOLEAN DEFAULT false,
  referral_source TEXT,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected','needs_docs')),
  reviewed_by UUID REFERENCES profiles(id),
  review_notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE kyc_submissions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Staff manage KYC" ON kyc_submissions FOR ALL
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'staff'));

-- ============================================================
-- COACHING SESSIONS
-- ============================================================
CREATE TABLE coaching_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id UUID REFERENCES patients(id) NOT NULL,
  coach_id UUID REFERENCES profiles(id) NOT NULL,
  patient_name TEXT,
  session_type TEXT,
  pillar TEXT CHECK (pillar IN ('bio','psycho','social','spiritual')),
  session_date TIMESTAMPTZ NOT NULL,
  duration_min INT DEFAULT 45,
  mood_pre INT,
  mood_post INT,
  notes TEXT,
  goals_discussed JSONB DEFAULT '[]',
  homework JSONB DEFAULT '[]',
  status TEXT DEFAULT 'scheduled' CHECK (status IN ('scheduled','in_progress','completed','cancelled','no_show')),
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE coaching_sessions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Staff manage sessions" ON coaching_sessions FOR ALL
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'staff'));
CREATE POLICY "Patients read own sessions" ON coaching_sessions FOR SELECT
  USING (patient_id IN (SELECT id FROM patients WHERE user_id = auth.uid()));

-- ============================================================
-- PRESCRIPTIONS
-- ============================================================
CREATE TABLE prescriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id UUID REFERENCES patients(id) NOT NULL,
  doctor_id UUID REFERENCES profiles(id) NOT NULL,
  patient_name TEXT,
  medication TEXT NOT NULL,
  dosage TEXT,
  frequency TEXT,
  supply_days INT,
  status TEXT DEFAULT 'active' CHECK (status IN ('active','renewal_due','expired','discontinued')),
  prescribed_at TIMESTAMPTZ DEFAULT now(),
  expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE prescriptions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Staff manage rx" ON prescriptions FOR ALL
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'staff'));
CREATE POLICY "Patients read own rx" ON prescriptions FOR SELECT
  USING (patient_id IN (SELECT id FROM patients WHERE user_id = auth.uid()));

-- ============================================================
-- LAB ORDERS
-- ============================================================
CREATE TABLE lab_orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id UUID REFERENCES patients(id) NOT NULL,
  doctor_id UUID REFERENCES profiles(id),
  patient_name TEXT,
  panel TEXT NOT NULL,
  results JSONB,
  flags TEXT,
  status TEXT DEFAULT 'ordered' CHECK (status IN ('ordered','collected','resulted','reviewed')),
  ordered_at TIMESTAMPTZ DEFAULT now(),
  resulted_at TIMESTAMPTZ,
  reviewed_at TIMESTAMPTZ
);

ALTER TABLE lab_orders ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Staff manage labs" ON lab_orders FOR ALL
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'staff'));
CREATE POLICY "Patients read own labs" ON lab_orders FOR SELECT
  USING (patient_id IN (SELECT id FROM patients WHERE user_id = auth.uid()));

-- ============================================================
-- AUDIT LOG
-- ============================================================
CREATE TABLE audit_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_id UUID,
  actor_name TEXT,
  actor_role TEXT,
  action TEXT NOT NULL,
  target TEXT,
  meta JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE audit_log ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Staff read audit" ON audit_log FOR SELECT
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'staff'));
CREATE POLICY "All authenticated insert audit" ON audit_log FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');

-- ============================================================
-- PLAN CHECK-INS (patient checklist for treatment plan goals)
-- ============================================================
CREATE TABLE plan_check_ins (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id UUID REFERENCES treatment_plans(id) ON DELETE CASCADE NOT NULL,
  patient_id UUID REFERENCES patients(id) ON DELETE CASCADE NOT NULL,
  pillar TEXT NOT NULL CHECK (pillar IN ('bio','psycho','social','spiritual')),
  goal_index INT NOT NULL,
  goal_text TEXT,
  completed_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (plan_id, pillar, goal_index)
);

ALTER TABLE plan_check_ins ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Patients manage own check-ins" ON plan_check_ins FOR ALL
  USING (patient_id IN (SELECT id FROM patients WHERE user_id = auth.uid()))
  WITH CHECK (patient_id IN (SELECT id FROM patients WHERE user_id = auth.uid()));
CREATE POLICY "Staff read check-ins" ON plan_check_ins FOR SELECT
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'staff'));

-- ============================================================
-- DAILY CHECK-INS (mood, symptoms, activities)
-- ============================================================
CREATE TABLE daily_checkins (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id UUID REFERENCES patients(id) ON DELETE CASCADE NOT NULL,
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

ALTER TABLE daily_checkins ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Patients manage daily check-ins" ON daily_checkins FOR ALL
  USING (patient_id IN (SELECT id FROM patients WHERE user_id = auth.uid()))
  WITH CHECK (patient_id IN (SELECT id FROM patients WHERE user_id = auth.uid()));
CREATE POLICY "Staff read daily check-ins" ON daily_checkins FOR SELECT
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'staff'));

-- ============================================================
-- INDEXES
-- ============================================================
CREATE INDEX idx_profiles_role ON profiles(role);
CREATE INDEX idx_patients_user ON patients(user_id);
CREATE INDEX idx_patients_mrn ON patients(mrn);
CREATE INDEX idx_appointments_time ON appointments(appointment_time);
CREATE INDEX idx_appointments_patient ON appointments(patient_id);
CREATE INDEX idx_vitals_patient ON vitals(patient_id);
CREATE INDEX idx_soap_patient ON soap_notes(patient_id);
CREATE INDEX idx_risk_status ON risk_alerts(status);
CREATE INDEX idx_audit_created ON audit_log(created_at);
CREATE INDEX idx_checkins_patient ON daily_checkins(patient_id);
