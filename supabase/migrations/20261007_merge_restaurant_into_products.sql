-- Gabung Direktori Cadangan (Restoran/Tempat Makan) TERUS ke
-- psy_recommended_products lewat kolum item_type ('barang' | 'kedai_makan').
-- SATU jadual + SATU senarai + SATU borang (borang tukar medan ikut
-- item_type dipilih) — ganti sepenuhnya psy_recommended_restaurants +
-- halaman direktori-cadangan.html. Idempoten.

-- 1) Kolum baharu pada psy_recommended_products
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

-- 2) Pindah data psy_recommended_restaurants (jika jadual tu masih wujud)
--    ke psy_recommended_products sebagai item_type='kedai_makan', lepas tu
--    buang jadual lama. Guard dgn NOT EXISTS (padan nama) supaya selamat
--    dijalankan berulang kali tanpa duplicate baris.
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

    DROP TABLE psy_recommended_restaurants;
  END IF;
END $$;

-- 3) Buang modul RBAC 'direktori_cadangan' (halaman direktori-cadangan.html
--    dipadam) — CASCADE buang baris psy_role_module_actions lama sekali.
--    Pastikan tiada rujukan modul_code='direktori_cadangan' tertinggal dalam
--    seed role_module_actions (03_rbac_security.sql) sebelum run ni semula.
DELETE FROM psy_modules WHERE code = 'direktori_cadangan';
