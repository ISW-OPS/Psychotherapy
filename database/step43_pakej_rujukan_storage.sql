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
