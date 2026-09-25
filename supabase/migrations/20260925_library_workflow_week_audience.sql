-- Audit management batch 3 (25 Sept 2026), Tier 7 #1/#2/#3a/#4 — Library.
-- Rujuk: database/schema/13_library_faq.sql, database/schema/24_storage.sql

-- ═══ 1. Kolum baharu psy_library_items ═══
ALTER TABLE psy_library_items ADD COLUMN IF NOT EXISTS week_number INT;
ALTER TABLE psy_library_items ADD COLUMN IF NOT EXISTS staff_roles TEXT[];
ALTER TABLE psy_library_items ADD COLUMN IF NOT EXISTS publish_at TIMESTAMPTZ;

COMMENT ON COLUMN psy_library_items.status IS
  'draft | review | approved | published | archived. is_active = (status=published). Pesakit nampak published sahaja.';
COMMENT ON COLUMN psy_library_items.week_number IS
  'Minggu rawatan (dalam pakej yg dipilih di package_ids) kandungan ni relevan. NULL = semua minggu.';
COMMENT ON COLUMN psy_library_items.staff_roles IS
  'Kalau diisi, kandungan ni RUJUKAN STAF sahaja (bukan pesakit) — hanya staff dgn salah satu peranan ni nampak. NULL/kosong = kandungan pesakit biasa.';
COMMENT ON COLUMN psy_library_items.publish_at IS
  'Kalau diisi & di masa depan, kandungan tak nampak kpd pesakit walau status=published/is_active=true sehingga masa ni sampai (dikuatkuasa di RLS).';

-- ═══ 2. RLS: kuatkuasa sekatan pakej + role + jadual terbit di server ═══
DROP POLICY IF EXISTS "Anyone read library" ON psy_library_items;
DROP POLICY IF EXISTS "Patients read allowed library" ON psy_library_items;
CREATE POLICY "Patients read allowed library" ON psy_library_items FOR SELECT
  TO authenticated
  USING (
    is_active = true
    AND (staff_roles IS NULL OR array_length(staff_roles, 1) IS NULL)
    AND (publish_at IS NULL OR publish_at <= now())
    AND (
      package_ids IS NULL OR array_length(package_ids, 1) IS NULL
      OR EXISTS (
        SELECT 1 FROM psy_patients p
        LEFT JOIN psy_packages pk
          ON pk.id::text = p.active_package_id OR pk.package_id = p.active_package_id
        WHERE p.user_id = auth.uid()
          AND (p.active_package_id = ANY(package_ids) OR pk.package_id = ANY(package_ids))
      )
    )
  );

-- ═══ 3. Bucket library-media — had saiz/format (dulu tiada langsung) ═══
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
