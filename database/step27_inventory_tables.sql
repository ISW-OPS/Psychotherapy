-- Create psy_inventory_items and psy_inventory_requests tables
-- Run this if step17_inventory.sql was missing/corrupt

-- ── Inventory Items ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS psy_inventory_items (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name             TEXT NOT NULL,
  category         TEXT NOT NULL DEFAULT 'Bekalan Coaching',
  unit             TEXT NOT NULL DEFAULT 'unit',
  qty_in_stock     NUMERIC(10,2) NOT NULL DEFAULT 0,
  min_qty          NUMERIC(10,2) NOT NULL DEFAULT 5,
  requires_approval BOOLEAN NOT NULL DEFAULT false,
  notes            TEXT,
  created_at       TIMESTAMPTZ DEFAULT now(),
  updated_at       TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE psy_inventory_items ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "Staff read inventory items" ON psy_inventory_items
    FOR SELECT USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "Admin manage inventory items" ON psy_inventory_items
    FOR ALL USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff' AND staff_role IN ('admin','manager')));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ── Inventory Requests ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS psy_inventory_requests (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  item_id           UUID REFERENCES psy_inventory_items(id) ON DELETE SET NULL,
  item_name         TEXT NOT NULL,
  qty_requested     NUMERIC(10,2) NOT NULL,
  unit_price        NUMERIC(10,2),
  total_amount      NUMERIC(10,2),
  reason            TEXT,
  status            TEXT NOT NULL DEFAULT 'pending_approval'
                    CHECK (status IN ('pending_approval','approved','rejected','purchased')),
  requested_by      UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  requested_by_name TEXT NOT NULL DEFAULT '',
  approved_by       UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  approved_at       TIMESTAMPTZ,
  rejected_reason   TEXT,
  purchased_at      TIMESTAMPTZ,
  created_at        TIMESTAMPTZ DEFAULT now(),
  updated_at        TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE psy_inventory_requests ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "Staff read all requests" ON psy_inventory_requests
    FOR SELECT USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "Staff insert own requests" ON psy_inventory_requests
    FOR INSERT WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "Manager admin update requests" ON psy_inventory_requests
    FOR UPDATE USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff' AND staff_role IN ('admin','manager')));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;