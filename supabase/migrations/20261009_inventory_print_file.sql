-- Fail print-ready (PDF) dilampir terus pada item inventori (cth reka bentuk
-- Brochure BNP) — staff buka inventory-detail.html item tu untuk cetak semula
-- bila nak restock. Lihat schema/14_products_inventory.sql.
ALTER TABLE psy_inventory_items ADD COLUMN IF NOT EXISTS print_file_url TEXT;
ALTER TABLE psy_inventory_items ADD COLUMN IF NOT EXISTS print_file_size BIGINT;

COMMENT ON COLUMN psy_inventory_items.print_file_url IS
  'Fail PDF print-ready (cth reka bentuk brochure) — dicetak terus dari inventory-detail.html bila restock.';

-- Bucket storan fail print item inventori (lihat schema/24_storage.sql)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('inventory-print-files', 'inventory-print-files', true, 10485760, ARRAY['application/pdf','image/png'])
ON CONFLICT (id) DO UPDATE
  SET public = EXCLUDED.public,
      file_size_limit = EXCLUDED.file_size_limit,
      allowed_mime_types = EXCLUDED.allowed_mime_types;

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
