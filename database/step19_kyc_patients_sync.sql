-- Add missing columns to psy_patients for full form sync
ALTER TABLE psy_patients ADD COLUMN IF NOT EXISTS company TEXT;
ALTER TABLE psy_patients ADD COLUMN IF NOT EXISTS referral_source TEXT;
ALTER TABLE psy_patients ADD COLUMN IF NOT EXISTS condition_duration TEXT;
ALTER TABLE psy_patients ADD COLUMN IF NOT EXISTS emergency_contact_ic TEXT;
ALTER TABLE psy_patients ADD COLUMN IF NOT EXISTS reference_code TEXT;

-- Add documents JSONB for medical report uploads
ALTER TABLE psy_patients ADD COLUMN IF NOT EXISTS documents JSONB DEFAULT '{}';

-- Add emergency_contact_ic to KYC submissions
ALTER TABLE psy_kyc_submissions ADD COLUMN IF NOT EXISTS emergency_contact_ic TEXT;

-- Allow staff to upload/read medical reports in storage
INSERT INTO storage.buckets (id, name, public) VALUES ('medical-reports', 'medical-reports', false) ON CONFLICT DO NOTHING;

CREATE POLICY "Staff can upload medical reports" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'medical-reports' AND
    EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff')
  );

CREATE POLICY "Staff can read all medical reports" ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id = 'medical-reports' AND
    EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff')
  );

CREATE POLICY "Patients can upload own medical reports" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'medical-reports' AND
    (storage.foldername(name))[1] = 'patient' AND
    EXISTS (SELECT 1 FROM psy_patients WHERE user_id = auth.uid())
  );

CREATE POLICY "Patients can read own medical reports" ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id = 'medical-reports' AND
    EXISTS (SELECT 1 FROM psy_patients WHERE user_id = auth.uid() AND id::text = (storage.foldername(name))[2])
  );
