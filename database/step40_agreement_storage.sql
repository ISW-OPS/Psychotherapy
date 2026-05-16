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
