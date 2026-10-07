-- ═══════════════════════════════════════════════════════════════════
-- 39 — MASTER PRODUK & BAHAN (Barang + Kedai Makan)
-- Audit management 23 Sept 2026, Tier 5 batch 2 module VI & VII — 2 modul
-- BAHARU sepenuhnya (disahkan tiada langsung dlm sistem masa audit).
-- REDESIGN 7 Okt 2026 #1: Seller/Platform jadi entiti MASTER berasingan
-- (senarai + detail tersendiri, dikongsi merentas produk) — bukan lagi
-- teks platform/nama-seller bebas diulang setiap baris dalam tiap produk.
-- REDESIGN 7 Okt 2026 #2: Direktori Cadangan (Restoran/Tempat Makan)
-- DIGABUNG terus ke psy_recommended_products lewat kolum `item_type`
-- ('barang' | 'kedai_makan') — SATU jadual + SATU senarai + SATU borang
-- (borang tukar medan ikut kategori dipilih). Jadual psy_recommended_restaurants
-- + halaman direktori-cadangan.html DIBUANG (data dipindah masuk — lihat
-- migration 20261007_merge_restaurant_into_products.sql).
--
-- Jadual: psy_recommended_sellers, psy_recommended_products,
--         psy_recommended_product_sellers, psy_package_recommended_products
--
-- BEZA drpd modul sedia ada (penting, jangan campur):
--   - psy_products (Produk Shop) = ISW SENDIRI jual & hantar. Jadual ni
--     SEBALIKNYA — barang yang ISW TAK jual, pesakit kena cari/beli sendiri
--     di luar (cth herba/suplemen tertentu utk minggu tertentu dlm pakej),
--     ATAU cadangan kedai makan luar (item_type='kedai_makan').
--   - psy_suppliers = vendor ISW beli DARI utk stok ISW sendiri (procurement
--     dalaman). psy_recommended_sellers pula cadangan tempat/seller PESAKIT
--     beli (Shopee/Lazada/kedai fizikal dll) — entiti berasingan sepenuhnya,
--     tiada kaitan stok/procurement ISW. Seller/Platform HANYA relevan utk
--     item_type='barang' — kedai makan tiada konsep "beli dari seller".
-- ═══════════════════════════════════════════════════════════════════

-- ──── psy_recommended_sellers (Master Seller / Platform) ────
CREATE TABLE IF NOT EXISTS psy_recommended_sellers (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name              TEXT NOT NULL,        -- nama seller/kedai, cth "ABC Fitness Store"
  platform          TEXT,                 -- cth Shopee / Lazada / Website / Kedai Fizikal
  link              TEXT,                 -- pautan kedai/storefront umum seller
  seller_type       TEXT,                 -- cth "Kedai rasmi / Authorised reseller"
  description       TEXT,                 -- deskripsi/penerangan seller (dipaparkan di Ringkasan)
  logo_url          TEXT,
  contact_email     TEXT,
  contact_phone     TEXT,
  address           TEXT,
  notes             TEXT,                 -- nota dalaman (berasingan drpd description)
  status            TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active','inactive')),
  last_verified_at  TIMESTAMPTZ,
  verified_by       UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  created_by        UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  updated_by        UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  created_at        TIMESTAMPTZ DEFAULT now(),
  updated_at        TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_rec_sellers_status ON psy_recommended_sellers(status);
CREATE INDEX IF NOT EXISTS idx_rec_sellers_platform ON psy_recommended_sellers(platform);

ALTER TABLE psy_recommended_sellers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff manage recommended sellers" ON psy_recommended_sellers;
CREATE POLICY "Staff manage recommended sellers" ON psy_recommended_sellers FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
  WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- ──── psy_recommended_products (Master Produk & Bahan — Barang + Kedai Makan) ────
CREATE TABLE IF NOT EXISTS psy_recommended_products (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  item_type         TEXT NOT NULL DEFAULT 'barang'
                    CHECK (item_type IN ('barang','kedai_makan')),
  name              TEXT NOT NULL,         -- nama produk ATAU nama restoran/tempat makan
  category          TEXT,                  -- barang: tak dipaparkan dlm UI semasa. kedai_makan: cth Halal/Vegetarian/Healthy Food
  purpose           TEXT,                  -- barang: "Tujuan/Kegunaan". kedai_makan: "Nota/Tujuan Cadangan"
  qty_note          TEXT,                  -- "Kuantiti Asas" (barang sahaja, teks bebas cth "1 unit")
  requirement_level TEXT NOT NULL DEFAULT 'cadangan'
                    CHECK (requirement_level IN ('wajib','cadangan','opsyenal')),  -- barang sahaja
  price             NUMERIC(10,2),  -- LEGACY, dibuang drpd UI (commit 29f11820) — harga kini per-seller (psy_recommended_product_sellers.price)
  image_url         TEXT,        -- gambar utama (= image_urls[0]), sama corak dgn psy_products
  image_urls        JSONB DEFAULT '[]',  -- gallery multi-gambar (7 Okt 2026)
  notes             TEXT,
  is_active         BOOLEAN NOT NULL DEFAULT true,
  last_verified_at  TIMESTAMPTZ,
  -- medan khusus kedai_makan (null utk barang) — digabung dari psy_recommended_restaurants 7 Okt 2026
  address           TEXT,        -- Alamat / Lokasi
  area              TEXT,        -- Kawasan / Bandar
  maps_url          TEXT,        -- pautan Google Maps / Waze
  contact_phone     TEXT,        -- No. Telefon
  website           TEXT,        -- Website (jika ada)
  operating_hours   TEXT,        -- Waktu Operasi (cth "9:00 AM - 10:00 PM (Setiap Hari)")
  menu_items        TEXT,        -- Menu / Hidangan Cadangan (satu baris satu item)
  price_range       TEXT,        -- Julat Harga (opsyenal, cth "RM10-20") — legacy drpd psy_recommended_restaurants
  created_by        UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  updated_by        UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  created_at        TIMESTAMPTZ DEFAULT now(),
  updated_at        TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_rec_products_active ON psy_recommended_products(is_active);
CREATE INDEX IF NOT EXISTS idx_rec_products_item_type ON psy_recommended_products(item_type);

ALTER TABLE psy_recommended_products ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff manage recommended products" ON psy_recommended_products;
CREATE POLICY "Staff manage recommended products" ON psy_recommended_products FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
  WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- ──── psy_recommended_product_sellers (pautan produk ↔ seller master, multi per produk) ────
CREATE TABLE IF NOT EXISTS psy_recommended_product_sellers (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id        UUID NOT NULL REFERENCES psy_recommended_products(id) ON DELETE CASCADE,
  seller_id         UUID NOT NULL REFERENCES psy_recommended_sellers(id) ON DELETE CASCADE,
  link              TEXT,   -- pautan beli KHUSUS produk ni (boleh beza drpd storefront umum seller)
  price             NUMERIC(10,2),
  is_primary        BOOLEAN NOT NULL DEFAULT false,  -- seller utama/disyorkan utk produk ni
  last_verified_at  TIMESTAMPTZ,
  notes             TEXT,
  sort_order        INT DEFAULT 0,
  created_at        TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_rec_prod_sellers_product ON psy_recommended_product_sellers(product_id);
CREATE INDEX IF NOT EXISTS idx_rec_prod_sellers_seller ON psy_recommended_product_sellers(seller_id);
CREATE UNIQUE INDEX IF NOT EXISTS uq_rec_product_seller ON psy_recommended_product_sellers(product_id, seller_id);

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
  qty         INT DEFAULT 1,   -- kuantiti diperlukan pada minggu/pakej ni
  notes       TEXT,            -- nota pemetaan (cth "Digunakan untuk aktiviti asas.")
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

-- psy_recommended_restaurants DIBUANG 7 Okt 2026 — digabung ke
-- psy_recommended_products (item_type='kedai_makan'). Lihat migration
-- 20261007_merge_restaurant_into_products.sql untuk pemindahan data.
