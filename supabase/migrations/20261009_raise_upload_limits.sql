-- Naikkan had saiz upload: gambar minimum 15MB, fail minimum 50MB di seluruh
-- sistem. Client-side (HTML) sudah dikemaskini; migration ni padankan had
-- keras peringkat bucket Supabase supaya tak reject sebelum sampai JS check.
-- Nota: had global projek Supabase (Dashboard → Storage → Settings) perlu
-- disemak/dinaikkan berasingan — tak boleh diubah via SQL.

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('avatars', 'avatars', true, 15728640, ARRAY['image/png','image/jpeg','image/jpg','image/webp','image/gif'])
ON CONFLICT (id) DO UPDATE
  SET file_size_limit = EXCLUDED.file_size_limit,
      allowed_mime_types = EXCLUDED.allowed_mime_types;

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('inventory-images', 'inventory-images', true, 15728640, ARRAY['image/png','image/jpeg','image/jpg','image/webp'])
ON CONFLICT (id) DO UPDATE
  SET file_size_limit = EXCLUDED.file_size_limit,
      allowed_mime_types = EXCLUDED.allowed_mime_types;

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('inventory-print-files', 'inventory-print-files', true, 52428800, ARRAY['application/pdf','image/png'])
ON CONFLICT (id) DO UPDATE
  SET file_size_limit = EXCLUDED.file_size_limit,
      allowed_mime_types = EXCLUDED.allowed_mime_types;
