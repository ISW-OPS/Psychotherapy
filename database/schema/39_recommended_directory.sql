-- ═══════════════════════════════════════════════════════════════════
-- 39 — MASTER PRODUK & BAHAN + DIREKTORI CADANGAN
-- Audit management 23 Sept 2026, Tier 5 batch 2 module VI & VII — 2 modul
-- BAHARU sepenuhnya (disahkan tiada langsung dlm sistem masa audit).
--
-- Jadual: psy_recommended_products, psy_recommended_product_sellers,
--         psy_package_recommended_products, psy_recommended_restaurants
--
-- BEZA drpd modul sedia ada (penting, jangan campur):
--   - psy_products (Produk Shop) = ISW SENDIRI jual & hantar. Jadual ni
--     SEBALIKNYA — barang yang ISW TAK jual, pesakit kena cari/beli sendiri
--     di luar (cth herba/suplemen tertentu utk minggu tertentu dlm pakej).
--   - psy_suppliers = vendor ISW beli DARI utk stok ISW sendiri (procurement
--     dalaman). Jadual ni pula cadangan tempat/seller utk PESAKIT beli.
-- ═══════════════════════════════════════════════════════════════════

-- ──── psy_recommended_products (Master Produk & Bahan) ────
CREATE TABLE IF NOT EXISTS psy_recommended_products (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name              TEXT NOT NULL,
  category          TEXT,
  purpose           TEXT,        -- tujuan/kegunaan
  qty_note          TEXT,        -- kuantiti disyorkan (teks bebas, cth "1 botol/bulan")
  requirement_level TEXT NOT NULL DEFAULT 'cadangan'
                    CHECK (requirement_level IN ('wajib','cadangan','opsyenal')),
  price             NUMERIC(10,2),  -- harga rujukan (opsyenal — setiap seller ada harga sendiri)
  image_url         TEXT,        -- gambar produk (bucket inventory-images dikongsi)
  notes             TEXT,
  is_active         BOOLEAN NOT NULL DEFAULT true,
  last_verified_at  TIMESTAMPTZ,
  created_by        UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  created_at        TIMESTAMPTZ DEFAULT now(),
  updated_at        TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_rec_products_active ON psy_recommended_products(is_active);

ALTER TABLE psy_recommended_products ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff manage recommended products" ON psy_recommended_products;
CREATE POLICY "Staff manage recommended products" ON psy_recommended_products FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
  WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- ──── psy_recommended_product_sellers (multi-seller per item) ────
CREATE TABLE IF NOT EXISTS psy_recommended_product_sellers (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id  UUID NOT NULL REFERENCES psy_recommended_products(id) ON DELETE CASCADE,
  platform    TEXT,   -- cth Shopee / Lazada / Laman Web / Kedai Fizikal
  seller_name TEXT,
  link        TEXT,
  price       NUMERIC(10,2),
  notes       TEXT,
  sort_order  INT DEFAULT 0,
  created_at  TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_rec_sellers_product ON psy_recommended_product_sellers(product_id);

ALTER TABLE psy_recommended_product_sellers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff manage recommended product sellers" ON psy_recommended_product_sellers;
CREATE POLICY "Staff manage recommended product sellers" ON psy_recommended_product_sellers FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
  WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- ──── psy_package_recommended_products (pautan item ↔ pakej ↔ minggu) ────
-- package_id ialah TEXT (psy_packages.package_id, kod perniagaan cth "OBDY1")
-- — SAMA konvensyen dgn psy_promo_codes.applies_to_values/psy_announcements.
-- package_ids (bukan psy_packages.id UUID) supaya konsisten dgn cara pakej
-- dirujuk merentas modul lain (rujuk memori project_active_package_id_gotcha).
CREATE TABLE IF NOT EXISTS psy_package_recommended_products (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  package_id  TEXT NOT NULL,
  product_id  UUID NOT NULL REFERENCES psy_recommended_products(id) ON DELETE CASCADE,
  week_number INT,   -- NULL = terpakai sepanjang pakej (bukan minggu tertentu)
  created_at  TIMESTAMPTZ DEFAULT now(),
  UNIQUE (package_id, product_id, week_number)
);

CREATE INDEX IF NOT EXISTS idx_rec_pkg_map_package ON psy_package_recommended_products(package_id);
CREATE INDEX IF NOT EXISTS idx_rec_pkg_map_product ON psy_package_recommended_products(product_id);

ALTER TABLE psy_package_recommended_products ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff manage package recommended products" ON psy_package_recommended_products;
CREATE POLICY "Staff manage package recommended products" ON psy_package_recommended_products FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
  WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- ──── psy_recommended_restaurants (Direktori Cadangan — tab Restoran) ────
-- Tab "Produk & Bahan" dlm Direktori Cadangan TIADA jadual sendiri — ia
-- papar TERUS psy_recommended_products di atas (elak duplikasi data/modul).
CREATE TABLE IF NOT EXISTS psy_recommended_restaurants (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name              TEXT NOT NULL,
  category          TEXT,        -- cth Halal, Vegetarian, Mesra Diet
  location          TEXT,
  maps_url          TEXT,
  menu_notes        TEXT,
  price_range       TEXT,        -- cth "RM10-20"
  status            TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active','inactive')),
  notes             TEXT,
  last_verified_at  TIMESTAMPTZ,
  created_by        UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  created_at        TIMESTAMPTZ DEFAULT now(),
  updated_at        TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_rec_restaurants_status ON psy_recommended_restaurants(status);

ALTER TABLE psy_recommended_restaurants ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff manage recommended restaurants" ON psy_recommended_restaurants;
CREATE POLICY "Staff manage recommended restaurants" ON psy_recommended_restaurants FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
  WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
