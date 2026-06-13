-- Fix: pakej-rujukan storage bucket upload blocked due to missing WITH CHECK clause.
-- FOR ALL policies need WITH CHECK for INSERT (upload); USING alone does not cover it.

DO $$ BEGIN
  DROP POLICY IF EXISTS "Staff manage pakej rujukan" ON storage.objects;
EXCEPTION WHEN undefined_object THEN NULL; END $$;

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
    )
    WITH CHECK (
      bucket_id = 'pakej-rujukan'
      AND EXISTS (
        SELECT 1 FROM psy_profiles
        WHERE id = auth.uid()
        AND role = 'staff'
        AND staff_role IN ('admin','manager','doctor')
      )
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

SELECT 'Fix OK — pakej-rujukan upload policy corrected' AS status;
