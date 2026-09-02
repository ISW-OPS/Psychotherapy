-- Multi-warehouse stock (P1-related) — lihat database/schema/34_inventory_locations.sql
-- (sumber kebenaran) utk versi penuh + nota. qty_in_stock pada psy_inventory_items
-- kekal kolum sedia ada, tapi kini jadi AGGREGATE dikawal trigger.

CREATE TABLE IF NOT EXISTS psy_inventory_locations (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name        TEXT NOT NULL UNIQUE,
  code        TEXT UNIQUE,
  is_default  BOOLEAN NOT NULL DEFAULT false,
  is_active   BOOLEAN NOT NULL DEFAULT true,
  created_at  TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS psy_inventory_stock_by_location (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  item_id       UUID NOT NULL REFERENCES psy_inventory_items(id) ON DELETE CASCADE,
  location_id   UUID NOT NULL REFERENCES psy_inventory_locations(id) ON DELETE RESTRICT,
  qty_in_stock  NUMERIC(10,2) NOT NULL DEFAULT 0,
  min_qty       NUMERIC(10,2),
  updated_at    TIMESTAMPTZ DEFAULT now(),
  UNIQUE (item_id, location_id)
);
CREATE INDEX IF NOT EXISTS idx_stock_by_location_item ON psy_inventory_stock_by_location(item_id);

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

INSERT INTO psy_inventory_locations (name, code, is_default) VALUES
  ('General Inventory',   'GEN',  true),
  ('Clinical Pharmacy',   'PHARM', false),
  ('Shop Warehouse',      'SHOP', false),
  ('Raw Material Store',  'RAW',  false),
  ('Equipment Store',     'EQUIP', false)
ON CONFLICT (name) DO NOTHING;

-- Pastikan source_type wujud dulu — testing kadang tertinggal patch ni
-- (lihat database/schema/14_products_inventory.sql baris 47).
ALTER TABLE psy_inventory_items ADD COLUMN IF NOT EXISTS source_type TEXT NOT NULL DEFAULT 'am'
  CHECK (source_type IN ('farmasi_klinikal','am'));

INSERT INTO psy_inventory_stock_by_location (item_id, location_id, qty_in_stock)
SELECT i.id,
       (SELECT id FROM psy_inventory_locations WHERE name = CASE WHEN i.source_type = 'farmasi_klinikal' THEN 'Clinical Pharmacy' ELSE 'General Inventory' END),
       COALESCE(i.qty_in_stock, 0)
FROM psy_inventory_items i
WHERE NOT EXISTS (SELECT 1 FROM psy_inventory_stock_by_location WHERE item_id = i.id);

ALTER TABLE psy_inventory_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE psy_inventory_stock_by_location ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff read locations" ON psy_inventory_locations;
CREATE POLICY "Staff read locations" ON psy_inventory_locations FOR SELECT
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "Staff manage stock by location" ON psy_inventory_stock_by_location;
CREATE POLICY "Staff manage stock by location" ON psy_inventory_stock_by_location FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
