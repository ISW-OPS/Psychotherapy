-- Kolum baharu utk borang Add/Edit Product yang dikemas kini — lihat
-- database/schema/14_products_inventory.sql + 24_storage.sql (sumber
-- kebenaran) utk versi penuh + nota.

ALTER TABLE psy_inventory_items ADD COLUMN IF NOT EXISTS barcode TEXT;
ALTER TABLE psy_inventory_items ADD COLUMN IF NOT EXISTS shelf_life_days INT;
ALTER TABLE psy_inventory_items ADD COLUMN IF NOT EXISTS image_url TEXT;
ALTER TABLE psy_inventory_items ADD COLUMN IF NOT EXISTS internal_notes TEXT;

INSERT INTO storage.buckets (id, name, public) VALUES ('inventory-images', 'inventory-images', true)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "inventory_images_public_read" ON storage.objects;
CREATE POLICY "inventory_images_public_read" ON storage.objects
    FOR SELECT USING (bucket_id = 'inventory-images');

DROP POLICY IF EXISTS "inventory_images_staff_write" ON storage.objects;
CREATE POLICY "inventory_images_staff_write" ON storage.objects
    FOR ALL TO authenticated
    USING (bucket_id = 'inventory-images' AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
    WITH CHECK (bucket_id = 'inventory-images' AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
