-- Purchase Requests jadi multi-item (macam Purchase Orders) — sebelum ni
-- item_id/item_name/qty_requested/unit_price terus di psy_inventory_requests
-- (1 request = 1 produk). Lihat database/schema/14_products_inventory.sql
-- (sumber kebenaran) utk versi penuh + nota.

-- 1) Jadual line items baharu
CREATE TABLE IF NOT EXISTS psy_inventory_request_items (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id     UUID NOT NULL REFERENCES psy_inventory_requests(id) ON DELETE CASCADE,
  item_id        UUID REFERENCES psy_inventory_items(id) ON DELETE SET NULL,
  item_name      TEXT NOT NULL,
  qty_requested  NUMERIC(10,2) NOT NULL,
  unit_price     NUMERIC(10,2) NOT NULL DEFAULT 0,
  subtotal       NUMERIC(12,2) NOT NULL DEFAULT 0,
  created_at     TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_inv_request_items_request ON psy_inventory_request_items(request_id);

ALTER TABLE psy_inventory_request_items ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Staff manage request items" ON psy_inventory_request_items;
CREATE POLICY "Staff manage request items" ON psy_inventory_request_items FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- 2) Header: tambah subtotal/tax_amount (total_amount dah wujud, tapi nullable —
-- baris lama (auto-generated / tiada harga) simpan NULL, kena backfill dulu
-- sebelum boleh set NOT NULL).
ALTER TABLE psy_inventory_requests ADD COLUMN IF NOT EXISTS subtotal NUMERIC(12,2) NOT NULL DEFAULT 0;
ALTER TABLE psy_inventory_requests ADD COLUMN IF NOT EXISTS tax_amount NUMERIC(12,2) NOT NULL DEFAULT 0;
UPDATE psy_inventory_requests SET total_amount = 0 WHERE total_amount IS NULL;
ALTER TABLE psy_inventory_requests ALTER COLUMN total_amount SET DEFAULT 0;
ALTER TABLE psy_inventory_requests ALTER COLUMN total_amount SET NOT NULL;

-- 3) Pindah data sedia ada (jika ada) ke jadual line items sebelum drop kolum lama.
-- Guarded — DB yang dibina terus dari schema/14_products_inventory.sql terkini
-- (yang dah tiada kolum single-item ni) takkan ada apa-apa nak dipindah.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'psy_inventory_requests' AND column_name = 'item_name'
  ) THEN
    INSERT INTO psy_inventory_request_items (request_id, item_id, item_name, qty_requested, unit_price, subtotal)
    SELECT id, item_id, item_name, qty_requested, COALESCE(unit_price, 0), COALESCE(total_amount, 0)
    FROM psy_inventory_requests
    WHERE item_name IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM psy_inventory_request_items WHERE request_id = psy_inventory_requests.id);
  END IF;
END $$;

UPDATE psy_inventory_requests SET subtotal = COALESCE(total_amount, 0) WHERE subtotal = 0;

-- 4) Buang kolum single-item lama dari header
ALTER TABLE psy_inventory_requests DROP COLUMN IF EXISTS item_id;
ALTER TABLE psy_inventory_requests DROP COLUMN IF EXISTS item_name;
ALTER TABLE psy_inventory_requests DROP COLUMN IF EXISTS qty_requested;
ALTER TABLE psy_inventory_requests DROP COLUMN IF EXISTS unit_price;
