-- Audit management 23 Sept 2026, Tier 5 batch 2 module VI & VII — 2 modul
-- BAHARU: Master Produk & Bahan + Direktori Cadangan.
-- Rujuk: database/schema/39_recommended_directory.sql, database/schema/03_rbac_security.sql

-- ═══ 1. Jadual baharu ═══

CREATE TABLE IF NOT EXISTS psy_recommended_products (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name              TEXT NOT NULL,
  category          TEXT,
  purpose           TEXT,
  qty_note          TEXT,
  requirement_level TEXT NOT NULL DEFAULT 'cadangan'
                    CHECK (requirement_level IN ('wajib','cadangan','opsyenal')),
  price             NUMERIC(10,2),
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

CREATE TABLE IF NOT EXISTS psy_recommended_product_sellers (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id  UUID NOT NULL REFERENCES psy_recommended_products(id) ON DELETE CASCADE,
  platform    TEXT,
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

CREATE TABLE IF NOT EXISTS psy_package_recommended_products (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  package_id  TEXT NOT NULL,
  product_id  UUID NOT NULL REFERENCES psy_recommended_products(id) ON DELETE CASCADE,
  week_number INT,
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

CREATE TABLE IF NOT EXISTS psy_recommended_restaurants (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name              TEXT NOT NULL,
  category          TEXT,
  location          TEXT,
  maps_url          TEXT,
  menu_notes        TEXT,
  price_range       TEXT,
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

-- ═══ 2. Pendaftaran RBAC (2 modul baharu) ═══

INSERT INTO psy_modules (code, label, icon, scope, sort_order) VALUES
  ('produk_bahan',      'Produk & Bahan Luar',  '🧴', 'staff', 101),
  ('direktori_cadangan','Direktori Cadangan',   '📇', 'staff', 102)
ON CONFLICT (code) DO UPDATE SET
  label = EXCLUDED.label, icon = EXCLUDED.icon, scope = EXCLUDED.scope, sort_order = EXCLUDED.sort_order;

-- Module × Action — semua action utk 2 modul baharu
INSERT INTO psy_module_actions (module_code, action_code)
SELECT m.code, a.code FROM psy_modules m CROSS JOIN psy_actions a
WHERE m.code IN ('produk_bahan','direktori_cadangan')
ON CONFLICT DO NOTHING;

-- super_admin / manager / admin dapat automatik (grant sedia ada guna
-- "WHERE scope='staff'" blanket query — cuma perlu ULANG langkah 3 di bawah
-- utk 2 modul baharu ni kembang ke create/edit/delete/export).
INSERT INTO psy_role_module_actions (role_code, module_code, action_code)
SELECT 'super_admin', code, 'view' FROM psy_modules WHERE code IN ('produk_bahan','direktori_cadangan')
ON CONFLICT DO NOTHING;
INSERT INTO psy_role_module_actions (role_code, module_code, action_code)
SELECT 'manager', code, 'view' FROM psy_modules WHERE code IN ('produk_bahan','direktori_cadangan')
ON CONFLICT DO NOTHING;
INSERT INTO psy_role_module_actions (role_code, module_code, action_code)
SELECT 'admin', code, 'view' FROM psy_modules WHERE code IN ('produk_bahan','direktori_cadangan')
ON CONFLICT DO NOTHING;
-- Doctor & Coach — paling relevan (beri cadangan kpd pesakit)
INSERT INTO psy_role_module_actions (role_code, module_code, action_code)
SELECT r.role, m.code, 'view'
FROM (VALUES ('doctor'),('coach')) AS r(role)
CROSS JOIN (VALUES ('produk_bahan'),('direktori_cadangan')) AS m(code)
ON CONFLICT DO NOTHING;

-- Kembangkan 'view' → create/edit/delete/export utk role yg baru diberi view di atas
INSERT INTO psy_role_module_actions (role_code, module_code, action_code)
SELECT rma.role_code, rma.module_code, a.code
FROM psy_role_module_actions rma
CROSS JOIN psy_actions a
WHERE rma.module_code IN ('produk_bahan','direktori_cadangan')
  AND rma.action_code = 'view'
  AND a.code IN ('create','edit','delete','export')
ON CONFLICT DO NOTHING;
