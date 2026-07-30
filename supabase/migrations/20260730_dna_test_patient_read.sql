-- ═══════════════════════════════════════════════════════════════════
-- MIGRASI: Pesakit boleh baca fail laporan DNA Test sendiri sahaja
-- Run SEKALI di Supabase SQL Editor (testing & prod).
-- Path fail: {patient_id}/{process_id}/nama-fail.pdf — segmen 1 mesti
-- padan psy_patients.id milik pesakit yang log masuk.
-- ═══════════════════════════════════════════════════════════════════

DROP POLICY IF EXISTS "dna_test_patient_read_own" ON storage.objects;
CREATE POLICY "dna_test_patient_read_own" ON storage.objects
    FOR SELECT TO authenticated
    USING (
      bucket_id = 'dna-test'
      AND (storage.foldername(name))[1] IN (
        SELECT id::text FROM psy_patients WHERE user_id = auth.uid()
      )
    );
