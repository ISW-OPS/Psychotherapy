-- ═══════════════════════════════════════════════════════════════════
-- 35 — STOCK IN / RECEIVE
-- Rekod penerimaan stok sebenar (bukan lagi 1 butang "Tandakan Dibeli"
-- je) — setiap penerimaan simpan batch no + expiry date PER PRODUK
-- (psy_stock_in_items), sebab 1 produk boleh ada banyak batch dengan
-- expiry berlainan (stok lama vs baru). "Expiring Soon" di Stock Alerts
-- dikira dari sini, BUKAN dari psy_inventory_items.expiry_date (medan
-- lama, single-value, dikekalkan tapi tak lagi sumber utama).
--
-- Reference: rujuk Purchase Request yang diluluskan (reference_type=
-- 'purchase_request'), ATAU 'manual' (restock terus tanpa PR). BUKAN
-- Purchase Order — modul PO dah dibuang (lihat 32_suppliers.sql nota).
-- Stock In yang dipautkan ke PR & di-post akan auto tanda PR tu
-- 'purchased' (sama kesan macam "Tandakan Dibeli" di PR, tapi dengan
-- rekod batch/expiry/kos sebenar).
-- ═══════════════════════════════════════════════════════════════════

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

-- ──── receive_no auto-generate (RCV-0001, ...) ────
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

-- ──── Line items (batch/expiry per produk per penerimaan) ────
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

-- ──── Attachments (delivery note, invoice, dll.) ────
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

-- ──── RLS ────
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

COMMENT ON TABLE psy_stock_in_records IS
  'Rekod penerimaan stok sebenar — post akan tambah stok ke psy_inventory_stock_by_location & tanda PR (jika ada rujukan) sebagai purchased.';
