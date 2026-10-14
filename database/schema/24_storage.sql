-- ═══════════════════════════════════════════════════════════════════
-- 24 — STORAGE (Supabase Storage)
-- Semua bucket + polisi storage.objects sistem dalam satu fail.
-- Bucket: medical-reports, kob-documents, kob-signatures, agreement-templates,
--         pakej-rujukan, wa-outbox, avatars, referral-docs, kb-media
-- Nota: polisi merujuk jadual/fungsi domain lain (psy_profiles, psy_patients,
--       kb_is_staff) — fail ini mesti dijalankan paling akhir.
-- ═══════════════════════════════════════════════════════════════════

-- ---- Buckets ----

INSERT INTO storage.buckets (id, name, public)
  VALUES ('medical-reports', 'medical-reports', false)
  ON CONFLICT (id) DO NOTHING;

INSERT INTO storage.buckets (id, name, public)
  VALUES ('kob-documents', 'kob-documents', false)
ON CONFLICT (id) DO NOTHING;

INSERT INTO storage.buckets (id, name, public)
  VALUES ('kob-signatures', 'kob-signatures', false)
ON CONFLICT (id) DO NOTHING;

INSERT INTO storage.buckets (id, name, public)
  VALUES ('agreement-templates', 'agreement-templates', false)
ON CONFLICT (id) DO NOTHING;

INSERT INTO storage.buckets (id, name, public)
  VALUES ('pakej-rujukan', 'pakej-rujukan', false)
ON CONFLICT (id) DO NOTHING;

INSERT INTO storage.buckets (id, name, public)
VALUES ('wa-outbox', 'wa-outbox', true)
ON CONFLICT (id) DO UPDATE SET public = true;

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('avatars', 'avatars', true, 15728640, ARRAY['image/png','image/jpeg','image/jpg','image/webp','image/gif'])
ON CONFLICT (id) DO UPDATE
  SET public = EXCLUDED.public,
      file_size_limit = EXCLUDED.file_size_limit,
      allowed_mime_types = EXCLUDED.allowed_mime_types;

INSERT INTO storage.buckets (id, name, public) VALUES ('referral-docs', 'referral-docs', false) ON CONFLICT DO NOTHING;

INSERT INTO storage.buckets (id, name, public) VALUES ('kb-media', 'kb-media', true)
ON CONFLICT (id) DO NOTHING;

-- Peristiwa Pesakit (lampiran dokumen/gambar) — staff sahaja
INSERT INTO storage.buckets (id, name, public) VALUES ('event-docs', 'event-docs', false)
ON CONFLICT (id) DO NOTHING;

-- DNA Test (gambar sample/barcode + 3 laporan PDF ATGC) — staff sahaja
-- Audit management (30 Sept 2026): bucket ni dulu tiada had saiz/format
-- langsung (unaudited, sama corak dgn library-media sebelum dibaiki).
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('dna-test', 'dna-test', false, 52428800, ARRAY['application/pdf','image/jpeg','image/png','image/jpg','image/webp'])
ON CONFLICT (id) DO UPDATE
  SET file_size_limit = EXCLUDED.file_size_limit,
      allowed_mime_types = EXCLUDED.allowed_mime_types;

-- Library (video/audio/thumbnail/dokumen kandungan pesakit) — audit management
-- batch 3 (25 Sept 2026) Tier 7 #4: bucket ni wujud sebelum ni tapi TIADA had
-- saiz/format langsung (unaudited, ad hoc). Tambah had 500MB + whitelist format.
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('library-media', 'library-media', true, 524288000, ARRAY[
  'video/mp4','video/quicktime','video/webm',
  'audio/mpeg','audio/mp4','audio/x-m4a','audio/wav',
  'image/png','image/jpeg','image/jpg','image/webp',
  'application/pdf','application/msword',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'application/vnd.ms-powerpoint',
  'application/vnd.openxmlformats-officedocument.presentationml.presentation'
])
ON CONFLICT (id) DO UPDATE
  SET public = EXCLUDED.public,
      file_size_limit = EXCLUDED.file_size_limit,
      allowed_mime_types = EXCLUDED.allowed_mime_types;

-- Supplier documents (SSM cert, agreement, dll.) — staff sahaja
INSERT INTO storage.buckets (id, name, public) VALUES ('supplier-docs', 'supplier-docs', false)
ON CONFLICT (id) DO NOTHING;

-- Gambar produk inventori — public (dipaparkan terus di senarai/detail produk).
-- Turut dikongsi oleh Produk & Bahan Luar (psy_recommended_products.image_url).
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('inventory-images', 'inventory-images', true, 15728640, ARRAY['image/png','image/jpeg','image/jpg','image/webp'])
ON CONFLICT (id) DO UPDATE
  SET file_size_limit = EXCLUDED.file_size_limit,
      allowed_mime_types = EXCLUDED.allowed_mime_types;

-- Gambar produk shop (gallery multi-gambar) — public (dipaparkan di shop & senarai produk)
INSERT INTO storage.buckets (id, name, public) VALUES ('product-images', 'product-images', true)
ON CONFLICT (id) DO NOTHING;

-- Dokumen Stock In (delivery note, invois, dll.) — staff sahaja
INSERT INTO storage.buckets (id, name, public) VALUES ('stock-in-docs', 'stock-in-docs', false)
ON CONFLICT (id) DO NOTHING;

-- Lampiran permohonan Surat Rasmi (salinan IC, surat tawaran, dll.) — requester + staff
INSERT INTO storage.buckets (id, name, public) VALUES ('letter-attachments', 'letter-attachments', false)
ON CONFLICT (id) DO NOTHING;

-- Media mesej automasi (imej/video dilampirkan pada mesej sequence) — public (GHL fetch terus URL)
INSERT INTO storage.buckets (id, name, public) VALUES ('automation-media', 'automation-media', true)
ON CONFLICT (id) DO NOTHING;

-- Fail print-ready item inventori (cth reka bentuk Brochure BNP) — dilampir pada
-- psy_inventory_items.print_file_url (14_products_inventory.sql), staff cetak terus
-- dari inventory-detail.html bila perlu restock.
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('inventory-print-files', 'inventory-print-files', true, 52428800, ARRAY['application/pdf','image/png'])
ON CONFLICT (id) DO UPDATE
  SET public = EXCLUDED.public,
      file_size_limit = EXCLUDED.file_size_limit,
      allowed_mime_types = EXCLUDED.allowed_mime_types;


-- ---- Polisi storage.objects ----

DROP POLICY IF EXISTS "Staff can upload medical reports" ON storage.objects;
CREATE POLICY "Staff can upload medical reports" ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'medical-reports' AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "Staff can read all medical reports" ON storage.objects;
CREATE POLICY "Staff can read all medical reports" ON storage.objects
    FOR SELECT TO authenticated
    USING (bucket_id = 'medical-reports' AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "Patients can upload own medical reports" ON storage.objects;
CREATE POLICY "Patients can upload own medical reports" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'medical-reports'
    AND (storage.foldername(name))[1] = 'patient'
    AND EXISTS (
      SELECT 1 FROM psy_patients
      WHERE user_id = auth.uid() AND id::text = (storage.foldername(name))[2]
    )
  );

DROP POLICY IF EXISTS "Patients can read own medical reports" ON storage.objects;
CREATE POLICY "Patients can read own medical reports" ON storage.objects
    FOR SELECT TO authenticated
    USING (bucket_id = 'medical-reports' AND EXISTS (SELECT 1 FROM psy_patients WHERE user_id = auth.uid() AND id::text = (storage.foldername(name))[2]));

DROP POLICY IF EXISTS "Authenticated read agreement templates" ON storage.objects;
CREATE POLICY "Authenticated read agreement templates"
    ON storage.objects FOR SELECT
    USING (bucket_id = 'agreement-templates' AND auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "Staff manage agreement templates" ON storage.objects;
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

DROP POLICY IF EXISTS "Patient upload own signature" ON storage.objects;
CREATE POLICY "Patient upload own signature"
    ON storage.objects FOR INSERT
    WITH CHECK (
      bucket_id = 'kob-signatures'
      AND auth.uid() IS NOT NULL
      AND (storage.foldername(name))[1] IN (
        SELECT id::text FROM psy_patients WHERE user_id = auth.uid()
      )
    );

DROP POLICY IF EXISTS "Patient read own signature" ON storage.objects;
CREATE POLICY "Patient read own signature"
    ON storage.objects FOR SELECT
    USING (
      bucket_id = 'kob-signatures'
      AND auth.uid() IS NOT NULL
      AND (storage.foldername(name))[1] IN (
        SELECT id::text FROM psy_patients WHERE user_id = auth.uid()
      )
    );

DROP POLICY IF EXISTS "Staff read all signatures" ON storage.objects;
CREATE POLICY "Staff read all signatures"
    ON storage.objects FOR SELECT
    USING (
      bucket_id = 'kob-signatures'
      AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff')
    );

DROP POLICY IF EXISTS "Staff manage kob documents" ON storage.objects;
CREATE POLICY "Staff manage kob documents"
    ON storage.objects FOR ALL
    USING (
      bucket_id = 'kob-documents'
      AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff')
    );

DROP POLICY IF EXISTS "Patient read own kob documents" ON storage.objects;
CREATE POLICY "Patient read own kob documents"
    ON storage.objects FOR SELECT
    USING (
      bucket_id = 'kob-documents'
      AND auth.uid() IS NOT NULL
      AND (storage.foldername(name))[1] IN (
        SELECT id::text FROM psy_patients WHERE user_id = auth.uid()
      )
    );

DROP POLICY IF EXISTS "Staff read pakej rujukan" ON storage.objects;
CREATE POLICY "Staff read pakej rujukan"
    ON storage.objects FOR SELECT
    USING (
      bucket_id = 'pakej-rujukan'
      AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff')
    );

DROP POLICY IF EXISTS "Staff manage pakej rujukan" ON storage.objects;
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

-- Pesakit perlu baca fail Rujukan pakej di This Week Coaching (plan-week.html)
-- supaya butang buka fail/link tak mati senyap bila signed URL tersimpan dah luput
-- (audit management Okt 2026 — box "Rujukan" nampak tak boleh tekan).
DROP POLICY IF EXISTS "Patients read pakej rujukan" ON storage.objects;
CREATE POLICY "Patients read pakej rujukan"
    ON storage.objects FOR SELECT
    USING (
      bucket_id = 'pakej-rujukan'
      AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'patient')
    );

DROP POLICY IF EXISTS "medical_upload" ON storage.objects;
CREATE POLICY "medical_upload" ON storage.objects FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'medical-reports');

DROP POLICY IF EXISTS "medical_read_own" ON storage.objects;
CREATE POLICY "medical_read_own" ON storage.objects FOR SELECT TO authenticated
    USING (bucket_id = 'medical-reports' AND owner = auth.uid());

DROP POLICY IF EXISTS "medical_read_staff" ON storage.objects;
CREATE POLICY "medical_read_staff" ON storage.objects FOR SELECT TO authenticated
    USING (bucket_id = 'medical-reports'
           AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "medical_delete_own" ON storage.objects;
CREATE POLICY "medical_delete_own" ON storage.objects FOR DELETE TO authenticated
    USING (bucket_id = 'medical-reports' AND owner = auth.uid());

DROP POLICY IF EXISTS "wa_outbox_staff_insert" ON storage.objects;
CREATE POLICY "wa_outbox_staff_insert" ON storage.objects FOR INSERT
    WITH CHECK (
      bucket_id = 'wa-outbox'
      AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff')
    );

DROP POLICY IF EXISTS "wa_outbox_public_read" ON storage.objects;
CREATE POLICY "wa_outbox_public_read" ON storage.objects FOR SELECT
    USING (bucket_id = 'wa-outbox');

DROP POLICY IF EXISTS "wa_outbox_staff_delete" ON storage.objects;
CREATE POLICY "wa_outbox_staff_delete" ON storage.objects FOR DELETE
    USING (
      bucket_id = 'wa-outbox'
      AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff')
    );

DROP POLICY IF EXISTS "avatars_public_read" ON storage.objects;
CREATE POLICY "avatars_public_read" ON storage.objects FOR SELECT
    USING (bucket_id = 'avatars');

DROP POLICY IF EXISTS "avatars_authenticated_upload" ON storage.objects;
CREATE POLICY "avatars_authenticated_upload" ON storage.objects FOR INSERT
    WITH CHECK (bucket_id = 'avatars' AND auth.role() = 'authenticated');

DROP POLICY IF EXISTS "avatars_owner_update" ON storage.objects;
CREATE POLICY "avatars_owner_update" ON storage.objects FOR UPDATE
    USING (bucket_id = 'avatars' AND auth.uid()::text = (storage.foldername(name))[1])
    WITH CHECK (bucket_id = 'avatars' AND auth.uid()::text = (storage.foldername(name))[1]);

DROP POLICY IF EXISTS "avatars_owner_delete" ON storage.objects;
CREATE POLICY "avatars_owner_delete" ON storage.objects FOR DELETE
    USING (bucket_id = 'avatars' AND auth.uid()::text = (storage.foldername(name))[1]);

DROP POLICY IF EXISTS "Staff upload referral docs" ON storage.objects;
CREATE POLICY "Staff upload referral docs" ON storage.objects FOR INSERT
    WITH CHECK (bucket_id = 'referral-docs' AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "Staff read referral docs" ON storage.objects;
CREATE POLICY "Staff read referral docs" ON storage.objects FOR SELECT
    USING (bucket_id = 'referral-docs' AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "Staff delete referral docs" ON storage.objects;
CREATE POLICY "Staff delete referral docs" ON storage.objects FOR DELETE
    USING (bucket_id = 'referral-docs' AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "kb_media_staff_write" ON storage.objects;
CREATE POLICY "kb_media_staff_write" ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'kb-media' AND kb_is_staff());

DROP POLICY IF EXISTS "kb_media_staff_update" ON storage.objects;
CREATE POLICY "kb_media_staff_update" ON storage.objects
    FOR UPDATE TO authenticated
    USING (bucket_id = 'kb-media' AND kb_is_staff());

DROP POLICY IF EXISTS "kb_media_staff_delete" ON storage.objects;
CREATE POLICY "kb_media_staff_delete" ON storage.objects
    FOR DELETE TO authenticated
    USING (bucket_id = 'kb-media' AND kb_is_staff());

DROP POLICY IF EXISTS "kb_media_public_read" ON storage.objects;
CREATE POLICY "kb_media_public_read" ON storage.objects
    FOR SELECT USING (bucket_id = 'kb-media');

DROP POLICY IF EXISTS "library_media_staff_write" ON storage.objects;
CREATE POLICY "library_media_staff_write" ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'library-media' AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "library_media_staff_update" ON storage.objects;
CREATE POLICY "library_media_staff_update" ON storage.objects
    FOR UPDATE TO authenticated
    USING (bucket_id = 'library-media' AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "library_media_staff_delete" ON storage.objects;
CREATE POLICY "library_media_staff_delete" ON storage.objects
    FOR DELETE TO authenticated
    USING (bucket_id = 'library-media' AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "library_media_public_read" ON storage.objects;
CREATE POLICY "library_media_public_read" ON storage.objects
    FOR SELECT USING (bucket_id = 'library-media');

DROP POLICY IF EXISTS "event_docs_staff_all" ON storage.objects;
CREATE POLICY "event_docs_staff_all" ON storage.objects
    FOR ALL TO authenticated
    USING (bucket_id = 'event-docs' AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
    WITH CHECK (bucket_id = 'event-docs' AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "dna_test_staff_all" ON storage.objects;
CREATE POLICY "dna_test_staff_all" ON storage.objects
    FOR ALL TO authenticated
    USING (bucket_id = 'dna-test' AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
    WITH CHECK (bucket_id = 'dna-test' AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- Audit management (30 Sept 2026): dulu pesakit boleh baca SEMUA fail dalam
-- folder mereka sendiri tanpa kira status proses — bermakna laporan DNA boleh
-- dimuat turun terus sebaik staf upload (Step 4), SEBELUM konsultasi/hadir
-- disahkan (Step 5-6). Kini kuatkuasa gate status='completed' di server —
-- path fail berbentuk <patient_id>/<process_id>/nama-fail.
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

DROP POLICY IF EXISTS "supplier_docs_staff_all" ON storage.objects;
CREATE POLICY "supplier_docs_staff_all" ON storage.objects
    FOR ALL TO authenticated
    USING (bucket_id = 'supplier-docs' AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
    WITH CHECK (bucket_id = 'supplier-docs' AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "inventory_images_public_read" ON storage.objects;
CREATE POLICY "inventory_images_public_read" ON storage.objects
    FOR SELECT USING (bucket_id = 'inventory-images');

DROP POLICY IF EXISTS "inventory_images_staff_write" ON storage.objects;
CREATE POLICY "inventory_images_staff_write" ON storage.objects
    FOR ALL TO authenticated
    USING (bucket_id = 'inventory-images' AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
    WITH CHECK (bucket_id = 'inventory-images' AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "product_images_public_read" ON storage.objects;
CREATE POLICY "product_images_public_read" ON storage.objects
    FOR SELECT USING (bucket_id = 'product-images');

DROP POLICY IF EXISTS "product_images_staff_write" ON storage.objects;
CREATE POLICY "product_images_staff_write" ON storage.objects
    FOR ALL TO authenticated
    USING (bucket_id = 'product-images' AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
    WITH CHECK (bucket_id = 'product-images' AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "automation_media_public_read" ON storage.objects;
CREATE POLICY "automation_media_public_read" ON storage.objects
    FOR SELECT USING (bucket_id = 'automation-media');

DROP POLICY IF EXISTS "automation_media_staff_write" ON storage.objects;
CREATE POLICY "automation_media_staff_write" ON storage.objects
    FOR ALL TO authenticated
    USING (bucket_id = 'automation-media' AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
    WITH CHECK (bucket_id = 'automation-media' AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "stock_in_docs_staff_all" ON storage.objects;
CREATE POLICY "stock_in_docs_staff_all" ON storage.objects
    FOR ALL TO authenticated
    USING (bucket_id = 'stock-in-docs' AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
    WITH CHECK (bucket_id = 'stock-in-docs' AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "inventory_print_staff_write" ON storage.objects;
CREATE POLICY "inventory_print_staff_write" ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'inventory-print-files' AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "inventory_print_staff_update" ON storage.objects;
CREATE POLICY "inventory_print_staff_update" ON storage.objects
    FOR UPDATE TO authenticated
    USING (bucket_id = 'inventory-print-files' AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "inventory_print_staff_delete" ON storage.objects;
CREATE POLICY "inventory_print_staff_delete" ON storage.objects
    FOR DELETE TO authenticated
    USING (bucket_id = 'inventory-print-files' AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "inventory_print_public_read" ON storage.objects;
CREATE POLICY "inventory_print_public_read" ON storage.objects
    FOR SELECT USING (bucket_id = 'inventory-print-files');

-- Lampiran permohonan surat: staff (proses) + requester sendiri (laluan {request_id}/... —
-- (storage.foldername(name))[1] mesti request_id kepunyaan pesakit/staff yang login).
DROP POLICY IF EXISTS "letter_attachments_staff_all" ON storage.objects;
CREATE POLICY "letter_attachments_staff_all" ON storage.objects
    FOR ALL TO authenticated
    USING (bucket_id = 'letter-attachments' AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
    WITH CHECK (bucket_id = 'letter-attachments' AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "letter_attachments_self_all" ON storage.objects;
CREATE POLICY "letter_attachments_self_all" ON storage.objects
    FOR ALL TO authenticated
    USING (
      bucket_id = 'letter-attachments'
      AND (storage.foldername(name))[1] IN (
        SELECT id::text FROM psy_letter_requests
        WHERE (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()))
           OR (requested_by_staff_id = auth.uid())
      )
    )
    WITH CHECK (
      bucket_id = 'letter-attachments'
      AND (storage.foldername(name))[1] IN (
        SELECT id::text FROM psy_letter_requests
        WHERE (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()))
           OR (requested_by_staff_id = auth.uid())
      )
    );

DROP POLICY IF EXISTS "Patients can upload own medical reports" ON storage.objects;
CREATE POLICY "Patients can upload own medical reports" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'medical-reports'
    AND (storage.foldername(name))[1] = 'patient'
    AND EXISTS (
      SELECT 1 FROM psy_patients
      WHERE user_id = auth.uid() AND id::text = (storage.foldername(name))[2]
    )
  );

