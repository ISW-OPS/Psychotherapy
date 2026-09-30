-- DNA Test — tutup kebocoran akses laporan sebelum konsultasi selesai (audit
-- Tier 9 #14, 30 Sept 2026). Bucket storage dna-test sebelum ni tiada
-- file_size_limit/allowed_mime_types, dan polisi baca pesakit tiada gerbang
-- status — pesakit boleh muat turun laporan PDF sebaik staf upload di Step 4,
-- jauh sebelum sesi konsultasi (Step 5/6) yang sepatutnya jadi gerbang.
-- Rujuk: database/schema/24_storage.sql, roles/staff/dna-test.html,
-- roles/patient/rekod-perubatan.html.

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('dna-test', 'dna-test', false, 52428800,
        ARRAY['application/pdf','image/jpeg','image/png','image/jpg','image/webp'])
ON CONFLICT (id) DO UPDATE
  SET file_size_limit = EXCLUDED.file_size_limit,
      allowed_mime_types = EXCLUDED.allowed_mime_types;

DROP POLICY IF EXISTS "dna_test_patient_read_own" ON storage.objects;
CREATE POLICY "dna_test_patient_read_own" ON storage.objects
    FOR SELECT TO authenticated
    USING (
      bucket_id = 'dna-test'
      AND (storage.foldername(name))[1] IN (
        SELECT id::text FROM psy_patients WHERE user_id = auth.uid()
      )
      AND EXISTS (
        SELECT 1 FROM psy_dna_test_process p
        WHERE p.id::text = (storage.foldername(name))[2]
          AND p.status = 'completed'
      )
    );
