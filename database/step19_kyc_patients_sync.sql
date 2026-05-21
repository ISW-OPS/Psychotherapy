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
