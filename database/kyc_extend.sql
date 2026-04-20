-- ============================================================
-- KYC SUBMISSIONS — extend schema for patient-side flow
-- Run once in Supabase SQL editor
-- ============================================================

ALTER TABLE kyc_submissions
  ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES profiles(id),
  ADD COLUMN IF NOT EXISTS date_of_birth DATE,
  ADD COLUMN IF NOT EXISTS gender TEXT,
  ADD COLUMN IF NOT EXISTS emergency_contact_name TEXT,
  ADD COLUMN IF NOT EXISTS emergency_contact_phone TEXT,
  ADD COLUMN IF NOT EXISTS medical_condition TEXT,
  ADD COLUMN IF NOT EXISTS condition_duration TEXT,
  ADD COLUMN IF NOT EXISTS medical_notes TEXT,
  ADD COLUMN IF NOT EXISTS reviewed_at TIMESTAMPTZ;

-- Mirror medical summary onto patients for clinician quick-view
ALTER TABLE patients
  ADD COLUMN IF NOT EXISTS medical_condition TEXT,
  ADD COLUMN IF NOT EXISTS condition_duration TEXT,
  ADD COLUMN IF NOT EXISTS medical_notes TEXT;

-- ============================================================
-- STORAGE BUCKET — medical reports (private)
-- ============================================================
INSERT INTO storage.buckets (id, name, public)
  VALUES ('medical-reports', 'medical-reports', false)
  ON CONFLICT (id) DO NOTHING;

-- Patients upload into a folder matching their user id
DROP POLICY IF EXISTS "Patients upload own reports" ON storage.objects;
CREATE POLICY "Patients upload own reports" ON storage.objects FOR INSERT
  WITH CHECK (bucket_id = 'medical-reports' AND (storage.foldername(name))[1] = auth.uid()::text);

DROP POLICY IF EXISTS "Patients read own reports" ON storage.objects;
CREATE POLICY "Patients read own reports" ON storage.objects FOR SELECT
  USING (bucket_id = 'medical-reports' AND (storage.foldername(name))[1] = auth.uid()::text);

DROP POLICY IF EXISTS "Staff read all reports" ON storage.objects;
CREATE POLICY "Staff read all reports" ON storage.objects FOR SELECT
  USING (bucket_id = 'medical-reports' AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'staff'));

-- Allow patients to read & insert/update their own submissions
DROP POLICY IF EXISTS "Patients read own KYC" ON kyc_submissions;
CREATE POLICY "Patients read own KYC" ON kyc_submissions FOR SELECT
  USING (user_id = auth.uid() OR email = (SELECT email FROM profiles WHERE id = auth.uid()));

DROP POLICY IF EXISTS "Patients insert own KYC" ON kyc_submissions;
CREATE POLICY "Patients insert own KYC" ON kyc_submissions FOR INSERT
  WITH CHECK (user_id = auth.uid() OR email = (SELECT email FROM profiles WHERE id = auth.uid()));

DROP POLICY IF EXISTS "Patients update own rejected KYC" ON kyc_submissions;
CREATE POLICY "Patients update own rejected KYC" ON kyc_submissions FOR UPDATE
  USING (user_id = auth.uid() OR email = (SELECT email FROM profiles WHERE id = auth.uid()));
