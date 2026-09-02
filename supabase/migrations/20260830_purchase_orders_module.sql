-- Modul Purchase Orders (P15-17) — PO rasmi ke supplier, banyak line item
-- setiap PO. Lihat database/schema/33_purchase_orders.sql (sumber kebenaran)
-- utk versi penuh + nota.

CREATE TABLE IF NOT EXISTS psy_purchase_orders (
  id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  po_number               TEXT UNIQUE,
  supplier_id             UUID NOT NULL REFERENCES psy_suppliers(id) ON DELETE RESTRICT,
  status                  TEXT NOT NULL DEFAULT 'draft'
                          CHECK (status IN ('draft','sent','partially_received','received','cancelled')),
  order_date              DATE DEFAULT CURRENT_DATE,
  expected_delivery_date  DATE,
  notes                   TEXT,
  subtotal                NUMERIC(12,2) NOT NULL DEFAULT 0,
  tax_amount              NUMERIC(12,2) NOT NULL DEFAULT 0,
  total_amount            NUMERIC(12,2) NOT NULL DEFAULT 0,

  created_by              UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_by_name         TEXT,
  updated_by              UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  updated_by_name         TEXT,
  created_at              TIMESTAMPTZ DEFAULT now(),
  updated_at              TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_po_status   ON psy_purchase_orders(status);
CREATE INDEX IF NOT EXISTS idx_po_supplier ON psy_purchase_orders(supplier_id);

CREATE SEQUENCE IF NOT EXISTS psy_po_number_seq START 1;

CREATE OR REPLACE FUNCTION psy_set_po_number()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.po_number IS NULL THEN
    NEW.po_number := 'PO-' || LPAD(nextval('psy_po_number_seq')::text, 4, '0');
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_psy_set_po_number ON psy_purchase_orders;
CREATE TRIGGER trg_psy_set_po_number
BEFORE INSERT ON psy_purchase_orders
FOR EACH ROW EXECUTE FUNCTION psy_set_po_number();

CREATE TABLE IF NOT EXISTS psy_purchase_order_items (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  po_id          UUID NOT NULL REFERENCES psy_purchase_orders(id) ON DELETE CASCADE,
  item_id        UUID REFERENCES psy_inventory_items(id) ON DELETE SET NULL,
  item_name      TEXT NOT NULL,
  qty_ordered    NUMERIC(10,2) NOT NULL,
  qty_received   NUMERIC(10,2) NOT NULL DEFAULT 0,
  unit_price     NUMERIC(10,2) NOT NULL DEFAULT 0,
  subtotal       NUMERIC(12,2) NOT NULL DEFAULT 0,
  created_at     TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_po_items_po ON psy_purchase_order_items(po_id);

ALTER TABLE psy_purchase_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE psy_purchase_order_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff manage purchase orders" ON psy_purchase_orders;
CREATE POLICY "Staff manage purchase orders" ON psy_purchase_orders FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "Staff manage purchase order items" ON psy_purchase_order_items;
CREATE POLICY "Staff manage purchase order items" ON psy_purchase_order_items FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
