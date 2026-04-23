-- ============================================================
-- STEP 2 — PSY_PATIENTS + PSY_KYC_SUBMISSIONS
-- Run selepas step1_profiles.sql
-- ============================================================

CREATE TABLE psy_patients (
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
CREATE POLICY "Staff manage patients" ON psy_patients FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
CREATE POLICY "Patients read own record" ON psy_patients FOR SELECT USING (user_id = auth.uid());
CREATE POLICY "Patients update own record" ON psy_patients FOR UPDATE USING (user_id = auth.uid());
CREATE POLICY "Patients insert own record" ON psy_patients FOR INSERT WITH CHECK (user_id = auth.uid());

-- ============================================================
-- PSY_KYC_SUBMISSIONS
-- ============================================================
CREATE TABLE psy_kyc_submissions (
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
CREATE POLICY "Staff manage KYC" ON psy_kyc_submissions FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
CREATE POLICY "Patients read own KYC" ON psy_kyc_submissions FOR SELECT
  USING (user_id = auth.uid());
CREATE POLICY "Patients insert own KYC" ON psy_kyc_submissions FOR INSERT
  WITH CHECK (user_id = auth.uid());
CREATE POLICY "Patients update own KYC" ON psy_kyc_submissions FOR UPDATE
  USING (user_id = auth.uid());

CREATE INDEX idx_psy_patients_user ON psy_patients(user_id);
CREATE INDEX idx_psy_patients_mrn ON psy_patients(mrn);

SELECT 'Step 2 OK — psy_patients + psy_kyc_submissions ready' AS status;
