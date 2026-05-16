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
