-- ═══════════════════════════════════════════════════════════════════
-- 36 — STOCK MOVEMENTS (ledger)
-- Rekod SETIAP perubahan stok (IN/OUT/ADJUSTMENT) merentasi semua punca:
-- Stock In (posted), Quick "Tandakan Dibeli", Stock Adjustment (manual),
-- Opening Stock (produk baharu), auto-deduct sesi pesakit. Ditulis SECARA
-- BERPUSAT dalam shared/inventoryStock.js addStockToLocation() — jangan
-- insert terus dari page, sentiasa lalu fungsi tu supaya ledger konsisten
-- dgn psy_inventory_stock_by_location (sumber kebenaran qty_in_stock).
--
-- Dipakai oleh roles/staff/inventory-overview.html ("Recent Stock
-- Movements") — kalau kod baharu ubah stok tanpa lalu addStockToLocation(),
-- ia TIDAK akan muncul di sini (dan qty_in_stock aggregate boleh out-of-sync,
-- lihat nota 34_inventory_locations.sql).
-- ═══════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS psy_stock_movements (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  item_id          UUID REFERENCES psy_inventory_items(id) ON DELETE SET NULL,
  item_name        TEXT,
  location_id      UUID REFERENCES psy_inventory_locations(id) ON DELETE SET NULL,
  movement_type    TEXT NOT NULL CHECK (movement_type IN ('in','out','adjustment')),
  qty              NUMERIC(12,4) NOT NULL,  -- delta bertanda: +masuk, -keluar
  balance_after    NUMERIC(12,4),  -- baki stok di lokasi tu SELEPAS movement ni (utk kolum "Balance After")
  reference_type   TEXT,   -- 'stock_in' | 'purchase_request' | 'adjustment' | 'opening_stock' | 'patient_package' | 'transfer'
  reference_id     UUID,
  reference_label  TEXT,   -- KOD rujukan sahaja bila ada, cth: 'RCV-0001', 'PR-0004' (bukan free text)
  notes            TEXT,   -- penerangan bebas, cth: sebab adjustment, 'Sesi minggu 3', 'Pindah → Shop Warehouse'
  actor_id         UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  actor_name       TEXT,
  created_at       TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_stock_movements_item ON psy_stock_movements(item_id);
CREATE INDEX IF NOT EXISTS idx_stock_movements_created ON psy_stock_movements(created_at DESC);

-- 29 Okt 2026 — lebarkan ke 4dp (sama sebab di 34_inventory_locations.sql).
ALTER TABLE psy_stock_movements ALTER COLUMN qty TYPE NUMERIC(12,4);
ALTER TABLE psy_stock_movements ALTER COLUMN balance_after TYPE NUMERIC(12,4);

ALTER TABLE psy_stock_movements ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff manage stock movements" ON psy_stock_movements;
CREATE POLICY "Staff manage stock movements" ON psy_stock_movements FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

COMMENT ON TABLE psy_stock_movements IS
  'Ledger setiap perubahan stok — ditulis berpusat dalam addStockToLocation() (shared/inventoryStock.js). Sumber "Recent Stock Movements" di Inventory Overview.';
