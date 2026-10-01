-- Produk & Bahan Luar: tambah gambar produk (staf minta) + kekalkan had saiz
-- bucket inventory-images yang dikongsi (dulu tiada file_size_limit/
-- allowed_mime_types langsung).
-- Rujuk: database/schema/39_recommended_directory.sql, database/schema/24_storage.sql
-- roles/staff/produk-bahan.html

ALTER TABLE psy_recommended_products
  ADD COLUMN IF NOT EXISTS image_url TEXT;

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('inventory-images', 'inventory-images', true, 2097152, ARRAY['image/png','image/jpeg','image/jpg','image/webp'])
ON CONFLICT (id) DO UPDATE
  SET file_size_limit = EXCLUDED.file_size_limit,
      allowed_mime_types = EXCLUDED.allowed_mime_types;
