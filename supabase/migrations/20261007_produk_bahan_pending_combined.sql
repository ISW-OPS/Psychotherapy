-- Gabungan 3 migration tertunda modul Produk & Bahan (7 Okt 2026) — dijalankan
-- selepas 20261007_produk_bahan_seller_master.sql (yang dah run). Susunan
-- dalam fail ni penting (bahagian 3 bergantung pada jadual/kolum sebelumnya).
-- Idempoten — selamat dijalankan berulang kali.

-- ═══ 1) Gallery multi-gambar produk ═══
-- Sebelum ni hanya 1 image_url; sama corak dgn psy_products (image_url =
-- utama/image_urls[0], image_urls = gallery).
ALTER TABLE psy_recommended_products ADD COLUMN IF NOT EXISTS image_urls JSONB DEFAULT '[]';

-- Produk sedia ada yang dah ada image_url tunggal — isi image_urls supaya
-- gallery terus papar gambar lama tu sebagai gambar pertama (bukan kosong senyap).
UPDATE psy_recommended_products
SET image_urls = jsonb_build_array(image_url)
WHERE image_url IS NOT NULL AND (image_urls IS NULL OR image_urls = '[]'::jsonb);

-- ═══ 2) Medan tambahan Seller / Platform ═══
-- Deskripsi/Penerangan berasingan drpd Nota dalaman; Verified By = staff yang sahkan.
ALTER TABLE psy_recommended_sellers ADD COLUMN IF NOT EXISTS description TEXT;
ALTER TABLE psy_recommended_sellers ADD COLUMN IF NOT EXISTS verified_by UUID REFERENCES psy_profiles(id) ON DELETE SET NULL;

-- ═══ 3) Gabung Direktori Cadangan (Restoran/Tempat Makan) ke Produk & Bahan ═══
-- SATU jadual + SATU senarai + SATU borang (borang tukar medan ikut item_type
-- dipilih) — ganti sepenuhnya psy_recommended_restaurants + halaman
-- direktori-cadangan.html.

-- 3a) Kolum baharu pada psy_recommended_products
ALTER TABLE psy_recommended_products ADD COLUMN IF NOT EXISTS item_type TEXT NOT NULL DEFAULT 'barang';
ALTER TABLE psy_recommended_products ADD COLUMN IF NOT EXISTS address TEXT;
ALTER TABLE psy_recommended_products ADD COLUMN IF NOT EXISTS area TEXT;
ALTER TABLE psy_recommended_products ADD COLUMN IF NOT EXISTS maps_url TEXT;
ALTER TABLE psy_recommended_products ADD COLUMN IF NOT EXISTS contact_phone TEXT;
ALTER TABLE psy_recommended_products ADD COLUMN IF NOT EXISTS website TEXT;
ALTER TABLE psy_recommended_products ADD COLUMN IF NOT EXISTS operating_hours TEXT;
ALTER TABLE psy_recommended_products ADD COLUMN IF NOT EXISTS menu_items TEXT;
ALTER TABLE psy_recommended_products ADD COLUMN IF NOT EXISTS price_range TEXT;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'psy_recommended_products_item_type_check'
  ) THEN
    ALTER TABLE psy_recommended_products
      ADD CONSTRAINT psy_recommended_products_item_type_check
      CHECK (item_type IN ('barang','kedai_makan'));
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_rec_products_item_type ON psy_recommended_products(item_type);

-- 3b) Pindah data psy_recommended_restaurants (jika jadual tu masih wujud) ke
--     psy_recommended_products sbg item_type='kedai_makan'. Guard dgn NOT
--     EXISTS (padan nama) supaya selamat dijalankan berulang kali tanpa
--     duplicate baris. TIDAK buang jadual lama di sini — lihat fail
--     20261007_produk_bahan_drop_restaurants.sql (langkah berasingan,
--     elak deadlock bila DROP TABLE disatukan dgn ALTER/INSERT lain dalam
--     transaksi sama).
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'psy_recommended_restaurants') THEN
    INSERT INTO psy_recommended_products (
      item_type, name, category, address, maps_url, menu_items, price_range,
      notes, is_active, last_verified_at, created_by
    )
    SELECT
      'kedai_makan', r.name, r.category, r.location, r.maps_url, r.menu_notes, r.price_range,
      r.notes, (r.status = 'active'), r.last_verified_at, r.created_by
    FROM psy_recommended_restaurants r
    WHERE NOT EXISTS (
      SELECT 1 FROM psy_recommended_products p
      WHERE p.item_type = 'kedai_makan' AND p.name = r.name
    );
  END IF;
END $$;

-- 3c) Buang modul RBAC 'direktori_cadangan' (halaman direktori-cadangan.html
--     dipadam) — CASCADE buang baris psy_role_module_actions lama sekali.
DELETE FROM psy_modules WHERE code = 'direktori_cadangan';

DROP TABLE IF EXISTS psy_recommended_restaurants;
