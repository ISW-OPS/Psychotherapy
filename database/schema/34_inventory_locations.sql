-- ═══════════════════════════════════════════════════════════════════
-- 34 — INVENTORY LOCATIONS (multi-warehouse stock)
-- Sebelum ni psy_inventory_items.qty_in_stock ialah SATU angka keseluruhan
-- (tiada pecahan ikut gudang). Kini setiap item boleh ada stok berasingan
-- di banyak lokasi (psy_inventory_stock_by_location); qty_in_stock pada
-- psy_inventory_items menjadi AGGREGATE (jumlah semua lokasi), dikekalkan
-- automatik oleh trigger psy_sync_item_stock_total — JANGAN update
-- qty_in_stock terus dari kod aplikasi, sentiasa upsert ke
-- psy_inventory_stock_by_location dan biar trigger kira semula jumlah.
-- ═══════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS psy_inventory_locations (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name        TEXT NOT NULL UNIQUE,
  code        TEXT UNIQUE,
  is_default  BOOLEAN NOT NULL DEFAULT false,
  is_active   BOOLEAN NOT NULL DEFAULT true,
  created_at  TIMESTAMPTZ DEFAULT now()
);

-- Permohonan belian simpan lokasi (rujukan kpd psy_inventory_locations) — ALTER di sini
-- sebab jadual lokasi ditakrif selepas psy_inventory_requests (14_products_inventory.sql).
ALTER TABLE psy_inventory_requests
  ADD COLUMN IF NOT EXISTS location_id UUID REFERENCES psy_inventory_locations(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS idx_inventory_requests_location ON psy_inventory_requests (location_id);

CREATE TABLE IF NOT EXISTS psy_inventory_stock_by_location (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  item_id       UUID NOT NULL REFERENCES psy_inventory_items(id) ON DELETE CASCADE,
  location_id   UUID NOT NULL REFERENCES psy_inventory_locations(id) ON DELETE RESTRICT,
  qty_in_stock  NUMERIC(12,4) NOT NULL DEFAULT 0,
  min_qty       NUMERIC(10,2),
  updated_at    TIMESTAMPTZ DEFAULT now(),
  UNIQUE (item_id, location_id)
);
CREATE INDEX IF NOT EXISTS idx_stock_by_location_item ON psy_inventory_stock_by_location(item_id);

-- 29 Okt 2026 — lebarkan ke 4dp supaya deduct pecahan unit (issue_unit, lihat
-- 14_products_inventory.sql) tak hilang ketepatan (cth 1/30 Gulung = 0.0333).
ALTER TABLE psy_inventory_stock_by_location ALTER COLUMN qty_in_stock TYPE NUMERIC(12,4);

-- ──── Trigger: kekalkan psy_inventory_items.qty_in_stock = SUM semua lokasi ────
CREATE OR REPLACE FUNCTION psy_sync_item_stock_total()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE target_item UUID := COALESCE(NEW.item_id, OLD.item_id);
BEGIN
  UPDATE psy_inventory_items
  SET qty_in_stock = (SELECT COALESCE(SUM(qty_in_stock), 0) FROM psy_inventory_stock_by_location WHERE item_id = target_item)
  WHERE id = target_item;
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_item_stock_total ON psy_inventory_stock_by_location;
CREATE TRIGGER trg_sync_item_stock_total
AFTER INSERT OR UPDATE OR DELETE ON psy_inventory_stock_by_location
FOR EACH ROW EXECUTE FUNCTION psy_sync_item_stock_total();

-- ──── Seed lokasi standard ────
INSERT INTO psy_inventory_locations (name, code, is_default) VALUES
  ('General Inventory',   'GEN',  true),
  ('Clinical Pharmacy',   'PHARM', false),
  ('Shop Warehouse',      'SHOP', false),
  ('Raw Material Store',  'RAW',  false),
  ('Equipment Store',     'EQUIP', false),
  ('Printing',            'PRINT', false)
ON CONFLICT (name) DO NOTHING;

-- ──── Backfill: pindah qty_in_stock sedia ada ke SATU lokasi (ikut source_type) ────
INSERT INTO psy_inventory_stock_by_location (item_id, location_id, qty_in_stock)
SELECT i.id,
       (SELECT id FROM psy_inventory_locations WHERE name = CASE WHEN i.source_type = 'farmasi_klinikal' THEN 'Clinical Pharmacy' ELSE 'General Inventory' END),
       COALESCE(i.qty_in_stock, 0)
FROM psy_inventory_items i
WHERE NOT EXISTS (SELECT 1 FROM psy_inventory_stock_by_location WHERE item_id = i.id);

-- ──── RLS ────
ALTER TABLE psy_inventory_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE psy_inventory_stock_by_location ENABLE ROW LEVEL SECURITY;

-- 29 Okt 2026 — SELECT-sahaja digantikan FOR ALL, supaya staff boleh tambah
-- lokasi baharu terus dari item-form.html ("+ Tambah Lokasi Baharu", cth
-- "Printing") tanpa kena insert manual via SQL/migration setiap kali.
DROP POLICY IF EXISTS "Staff read locations" ON psy_inventory_locations;
DROP POLICY IF EXISTS "Staff manage locations" ON psy_inventory_locations;
CREATE POLICY "Staff manage locations" ON psy_inventory_locations FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "Staff manage stock by location" ON psy_inventory_stock_by_location;
CREATE POLICY "Staff manage stock by location" ON psy_inventory_stock_by_location FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

COMMENT ON TABLE psy_inventory_stock_by_location IS
  'Stok sebenar per (item, lokasi). psy_inventory_items.qty_in_stock ialah jumlah automatik (trigger) — jangan tulis terus, upsert sini.';
