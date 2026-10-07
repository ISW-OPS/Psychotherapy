-- Redesign Produk & Bahan: Seller/Platform jadi entiti MASTER berasingan
-- (senarai + detail tersendiri), bukan lagi teks platform/nama-seller bebas
-- berulang setiap baris dalam tiap produk. Lihat database/schema/39_recommended_directory.sql
-- untuk bentuk akhir skema. Idempotent — selamat dijalankan walaupun jadual
-- psy_recommended_products/_sellers/psy_package_recommended_products belum
-- pernah wujud (CREATE TABLE IF NOT EXISTS) ATAU dah wujud dlm bentuk lama
-- (ALTER ... ADD COLUMN IF NOT EXISTS).

-- 1) Seller master (baharu sepenuhnya)
CREATE TABLE IF NOT EXISTS psy_recommended_sellers (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name              TEXT NOT NULL,
  platform          TEXT,
  link              TEXT,
  seller_type       TEXT,
  logo_url          TEXT,
  contact_email     TEXT,
  contact_phone     TEXT,
  address           TEXT,
  notes             TEXT,
  status            TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active','inactive')),
  last_verified_at  TIMESTAMPTZ,
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

-- 2) psy_recommended_products — kalau belum wujud langsung, cipta penuh;
--    kalau dah wujud (bentuk lama), tambah updated_by sahaja.
CREATE TABLE IF NOT EXISTS psy_recommended_products (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name              TEXT NOT NULL,
  category          TEXT,
  purpose           TEXT,
  qty_note          TEXT,
  requirement_level TEXT NOT NULL DEFAULT 'cadangan'
                    CHECK (requirement_level IN ('wajib','cadangan','opsyenal')),
  price             NUMERIC(10,2),
  image_url         TEXT,
  notes             TEXT,
  is_active         BOOLEAN NOT NULL DEFAULT true,
  last_verified_at  TIMESTAMPTZ,
  created_by        UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  updated_by        UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  created_at        TIMESTAMPTZ DEFAULT now(),
  updated_at        TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE psy_recommended_products ADD COLUMN IF NOT EXISTS updated_by UUID REFERENCES psy_profiles(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS idx_rec_products_active ON psy_recommended_products(is_active);
ALTER TABLE psy_recommended_products ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Staff manage recommended products" ON psy_recommended_products;
CREATE POLICY "Staff manage recommended products" ON psy_recommended_products FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
  WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- 3) psy_recommended_product_sellers — restructure drpd platform/seller_name teks
--    bebas kepada seller_id rujukan psy_recommended_sellers. Kalau jadual bentuk
--    LAMA dah wujud (platform/seller_name/link/price/notes, tiada seller_id),
--    bina master seller drpd baris sedia ada secara automatik supaya pautan
--    produk↔seller tak hilang.
DO $$
DECLARE
  has_table boolean;
  has_seller_id boolean;
BEGIN
  SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'psy_recommended_product_sellers') INTO has_table;

  IF NOT has_table THEN
    CREATE TABLE psy_recommended_product_sellers (
      id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      product_id        UUID NOT NULL REFERENCES psy_recommended_products(id) ON DELETE CASCADE,
      seller_id         UUID NOT NULL REFERENCES psy_recommended_sellers(id) ON DELETE CASCADE,
      link              TEXT,
      price             NUMERIC(10,2),
      is_primary        BOOLEAN NOT NULL DEFAULT false,
      last_verified_at  TIMESTAMPTZ,
      notes             TEXT,
      sort_order        INT DEFAULT 0,
      created_at        TIMESTAMPTZ DEFAULT now()
    );
  ELSE
    SELECT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'psy_recommended_product_sellers' AND column_name = 'seller_id') INTO has_seller_id;

    IF NOT has_seller_id THEN
      ALTER TABLE psy_recommended_product_sellers ADD COLUMN seller_id UUID REFERENCES psy_recommended_sellers(id) ON DELETE CASCADE;
      ALTER TABLE psy_recommended_product_sellers ADD COLUMN IF NOT EXISTS is_primary BOOLEAN NOT NULL DEFAULT false;
      ALTER TABLE psy_recommended_product_sellers ADD COLUMN IF NOT EXISTS last_verified_at TIMESTAMPTZ;

      -- Bina seller master drpd kombinasi platform+nama-seller sedia ada.
      INSERT INTO psy_recommended_sellers (name, platform, link)
      SELECT DISTINCT
        COALESCE(NULLIF(s.seller_name, ''), NULLIF(s.platform, ''), 'Seller tanpa nama'),
        NULLIF(s.platform, ''),
        NULLIF(s.link, '')
      FROM psy_recommended_product_sellers s
      WHERE NOT EXISTS (
        SELECT 1 FROM psy_recommended_sellers x
        WHERE x.name = COALESCE(NULLIF(s.seller_name, ''), NULLIF(s.platform, ''), 'Seller tanpa nama')
          AND COALESCE(x.platform, '') = COALESCE(NULLIF(s.platform, ''), '')
      );

      -- Pautkan balik setiap baris produk-seller lama ke seller master baharu.
      UPDATE psy_recommended_product_sellers s
      SET seller_id = x.id
      FROM psy_recommended_sellers x
      WHERE s.seller_id IS NULL
        AND x.name = COALESCE(NULLIF(s.seller_name, ''), NULLIF(s.platform, ''), 'Seller tanpa nama')
        AND COALESCE(x.platform, '') = COALESCE(NULLIF(s.platform, ''), '');

      -- Buang baris yang gagal dipautkan (jarang berlaku, data kosong/rosak).
      DELETE FROM psy_recommended_product_sellers WHERE seller_id IS NULL;

      ALTER TABLE psy_recommended_product_sellers ALTER COLUMN seller_id SET NOT NULL;
    END IF;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_rec_prod_sellers_product ON psy_recommended_product_sellers(product_id);
CREATE INDEX IF NOT EXISTS idx_rec_prod_sellers_seller ON psy_recommended_product_sellers(seller_id);
CREATE UNIQUE INDEX IF NOT EXISTS uq_rec_product_seller ON psy_recommended_product_sellers(product_id, seller_id);
ALTER TABLE psy_recommended_product_sellers ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Staff manage recommended product sellers" ON psy_recommended_product_sellers;
CREATE POLICY "Staff manage recommended product sellers" ON psy_recommended_product_sellers FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
  WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- 4) psy_package_recommended_products — tambah qty + notes
CREATE TABLE IF NOT EXISTS psy_package_recommended_products (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  package_id  TEXT NOT NULL,
  product_id  UUID NOT NULL REFERENCES psy_recommended_products(id) ON DELETE CASCADE,
  week_number INT,
  qty         INT DEFAULT 1,
  notes       TEXT,
  created_at  TIMESTAMPTZ DEFAULT now(),
  UNIQUE (package_id, product_id, week_number)
);
ALTER TABLE psy_package_recommended_products ADD COLUMN IF NOT EXISTS qty INT DEFAULT 1;
ALTER TABLE psy_package_recommended_products ADD COLUMN IF NOT EXISTS notes TEXT;
CREATE INDEX IF NOT EXISTS idx_rec_pkg_map_package ON psy_package_recommended_products(package_id);
CREATE INDEX IF NOT EXISTS idx_rec_pkg_map_product ON psy_package_recommended_products(product_id);
ALTER TABLE psy_package_recommended_products ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Staff manage package recommended products" ON psy_package_recommended_products;
CREATE POLICY "Staff manage package recommended products" ON psy_package_recommended_products FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
  WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
