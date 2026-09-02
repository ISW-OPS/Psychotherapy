-- Stock In / Receive module — lihat database/schema/35_stock_in.sql +
-- 24_storage.sql (sumber kebenaran) utk versi penuh + nota.

CREATE TABLE IF NOT EXISTS psy_stock_in_records (
  id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  receive_no         TEXT UNIQUE,
  receive_date       DATE DEFAULT CURRENT_DATE,
  reference_type     TEXT NOT NULL DEFAULT 'manual'
                     CHECK (reference_type IN ('purchase_request','manual')),
  reference_id       UUID REFERENCES psy_inventory_requests(id) ON DELETE SET NULL,
  location_id        UUID NOT NULL REFERENCES psy_inventory_locations(id) ON DELETE RESTRICT,
  status             TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','posted')),
  delivery_note_no   TEXT,
  invoice_no         TEXT,
  transporter        TEXT,
  received_condition TEXT,
  remarks            TEXT,
  subtotal           NUMERIC(12,2) NOT NULL DEFAULT 0,
  tax_amount         NUMERIC(12,2) NOT NULL DEFAULT 0,
  total_cost         NUMERIC(12,2) NOT NULL DEFAULT 0,
  received_by        UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  received_by_name   TEXT,
  posted_at          TIMESTAMPTZ,
  created_at         TIMESTAMPTZ DEFAULT now(),
  updated_at         TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_stock_in_reference ON psy_stock_in_records(reference_id);

CREATE SEQUENCE IF NOT EXISTS psy_stock_in_no_seq START 1;

CREATE OR REPLACE FUNCTION psy_set_stock_in_no()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.receive_no IS NULL THEN
    NEW.receive_no := 'RCV-' || LPAD(nextval('psy_stock_in_no_seq')::text, 4, '0');
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_psy_set_stock_in_no ON psy_stock_in_records;
CREATE TRIGGER trg_psy_set_stock_in_no
BEFORE INSERT ON psy_stock_in_records
FOR EACH ROW EXECUTE FUNCTION psy_set_stock_in_no();

CREATE TABLE IF NOT EXISTS psy_stock_in_items (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  stock_in_id    UUID NOT NULL REFERENCES psy_stock_in_records(id) ON DELETE CASCADE,
  item_id        UUID REFERENCES psy_inventory_items(id) ON DELETE SET NULL,
  item_name      TEXT NOT NULL,
  batch_no       TEXT,
  expiry_date    DATE,
  qty_received   NUMERIC(10,2) NOT NULL,
  unit_cost      NUMERIC(10,2) NOT NULL DEFAULT 0,
  subtotal       NUMERIC(12,2) NOT NULL DEFAULT 0,
  created_at     TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_stock_in_items_record ON psy_stock_in_items(stock_in_id);
CREATE INDEX IF NOT EXISTS idx_stock_in_items_item ON psy_stock_in_items(item_id);
CREATE INDEX IF NOT EXISTS idx_stock_in_items_expiry ON psy_stock_in_items(expiry_date) WHERE expiry_date IS NOT NULL;

CREATE TABLE IF NOT EXISTS psy_stock_in_documents (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  stock_in_id       UUID NOT NULL REFERENCES psy_stock_in_records(id) ON DELETE CASCADE,
  file_name         TEXT NOT NULL,
  file_path         TEXT NOT NULL,
  file_size         INT,
  uploaded_by_name  TEXT,
  created_at        TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_stock_in_documents_record ON psy_stock_in_documents(stock_in_id);

ALTER TABLE psy_stock_in_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE psy_stock_in_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE psy_stock_in_documents ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff manage stock in records" ON psy_stock_in_records;
CREATE POLICY "Staff manage stock in records" ON psy_stock_in_records FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "Staff manage stock in items" ON psy_stock_in_items;
CREATE POLICY "Staff manage stock in items" ON psy_stock_in_items FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "Staff manage stock in documents" ON psy_stock_in_documents;
CREATE POLICY "Staff manage stock in documents" ON psy_stock_in_documents FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

INSERT INTO storage.buckets (id, name, public) VALUES ('stock-in-docs', 'stock-in-docs', false)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "stock_in_docs_staff_all" ON storage.objects;
CREATE POLICY "stock_in_docs_staff_all" ON storage.objects
    FOR ALL TO authenticated
    USING (bucket_id = 'stock-in-docs' AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
    WITH CHECK (bucket_id = 'stock-in-docs' AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
