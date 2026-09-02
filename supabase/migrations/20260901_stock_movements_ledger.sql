-- Stock Movements ledger — rujuk database/schema/36_stock_movements.sql untuk nota penuh.

CREATE TABLE IF NOT EXISTS psy_stock_movements (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  item_id          UUID REFERENCES psy_inventory_items(id) ON DELETE SET NULL,
  item_name        TEXT,
  location_id      UUID REFERENCES psy_inventory_locations(id) ON DELETE SET NULL,
  movement_type    TEXT NOT NULL CHECK (movement_type IN ('in','out','adjustment')),
  qty              NUMERIC(10,2) NOT NULL,
  balance_after    NUMERIC(10,2),
  reference_type   TEXT,
  reference_id     UUID,
  reference_label  TEXT,
  notes            TEXT,
  actor_id         UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  actor_name       TEXT,
  created_at       TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_stock_movements_item ON psy_stock_movements(item_id);
CREATE INDEX IF NOT EXISTS idx_stock_movements_created ON psy_stock_movements(created_at DESC);

ALTER TABLE psy_stock_movements ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff manage stock movements" ON psy_stock_movements;
CREATE POLICY "Staff manage stock movements" ON psy_stock_movements FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
