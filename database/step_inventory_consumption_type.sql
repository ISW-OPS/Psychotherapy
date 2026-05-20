-- ============================================================
-- step_inventory_consumption_type.sql
-- Klasifikasi barang inventory ikut sifat consumption:
--   package  = pakai sebagai bekalan pakej (kira dynamic dari patient × pakej supplies)
--   service  = pakai untuk service one-off (cth: DNA test kit, swab, urine cup)
--   general  = consumable umum (sarung tangan, alcohol swab, tissue) — manual min sahaja
-- ============================================================

ALTER TABLE psy_inventory_items
  ADD COLUMN IF NOT EXISTS consumption_type TEXT DEFAULT 'package'
    CHECK (consumption_type IN ('package','service','general'));

COMMENT ON COLUMN psy_inventory_items.consumption_type IS
  'package = bekalan pakej (dynamic auto-calc); service = guna semasa service one-off; general = consumable umum (manual min sahaja).';

UPDATE psy_inventory_items SET consumption_type = 'package' WHERE consumption_type IS NULL;

-- ============================================================
-- psy_services — Senarai service (appointment types) yang clinic tawarkan.
-- Page services.html dan service-detail.html guna table ni.
-- ============================================================
CREATE TABLE IF NOT EXISTS psy_services (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  service_id    TEXT UNIQUE NOT NULL,
  name          TEXT NOT NULL,
  description   TEXT,
  icon          TEXT DEFAULT '⚕',
  price         NUMERIC(10,2) DEFAULT 0,
  duration_min  INT DEFAULT 30,
  sort_order    INT DEFAULT 100,
  is_active     BOOLEAN DEFAULT true,
  supplies      JSONB DEFAULT '[]'::jsonb,
  created_at    TIMESTAMPTZ DEFAULT now(),
  updated_at    TIMESTAMPTZ DEFAULT now()
);

COMMENT ON COLUMN psy_services.supplies IS
  'Senarai item inventory yang diguna per session service. Format: [{item_id, item_name, qty}].';

ALTER TABLE psy_services ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "Staff manage services" ON psy_services FOR ALL
    USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "All authenticated read services" ON psy_services FOR SELECT
    USING (auth.uid() IS NOT NULL);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Kalau table sudah pernah wujud tanpa column supplies (cth. di-create melalui jalan lain), tambah dia.
ALTER TABLE psy_services
  ADD COLUMN IF NOT EXISTS supplies JSONB DEFAULT '[]'::jsonb;

-- Seed beberapa service umum (idempotent — skip jika sudah ada)
INSERT INTO psy_services (service_id, name, description, icon, price, duration_min, sort_order)
VALUES
  ('consultation', 'Consultation with Doctor', 'Sesi konsultasi dengan doktor',           '🩺',  50.00, 30, 10),
  ('dna_test',     'DNA Test',                  'Ujian genetik untuk profil kesihatan',  '🧬', 350.00, 45, 20),
  ('blood_test',   'Blood Test',                'Pemeriksaan darah asas',                '🩸', 120.00, 20, 30),
  ('kob',          'Kursus Orientasi Bestari',  'Kursus orientasi pesakit baru',         '🎓',   0.00, 90, 40)
ON CONFLICT (service_id) DO NOTHING;
