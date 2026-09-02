-- ═══════════════════════════════════════════════════════════════
-- COMBINED MIGRATION — 2026-09-01
-- Gabungan 10 migration berasingan (29-31 Ogos 2026) jadi satu fail
-- untuk dijalankan sekali gus. Susunan asal DIKEKALKAN (penting —
-- 20260830 cipta Purchase Orders, 20260831 buang balik modul sama).
-- ═══════════════════════════════════════════════════════════════


-- ───────────────────────────────────────────────────────────────
-- 1) 20260829_drop_inventory_auto_po_trigger.sql
-- ───────────────────────────────────────────────────────────────
-- Buang trigger DB psy_inventory_auto_request — ia guna medan `max_qty` yang tak pernah
-- diisi di mana-mana borang/kod staff (sentiasa NULL), jadi trigger ni sentiasa fallback ke
-- min_qty untuk SEMUA item (tak kira consumption_type='package' ke tidak) — langsung tak
-- selaras dengan logik forecast (shared/inventoryForecast.js) yang kini jadi SATU-SATUNYA
-- sumber kebenaran utk Auto-PO (checkAutoPO() di inventory.html, dipanggil client-side
-- setiap kali page dibuka). Lihat database/schema/14_products_inventory.sql baris 174-283
-- utk versi asal (sumber kebenaran skema patut dikemaskini buang bahagian trigger ni juga).

DROP TRIGGER IF EXISTS trg_psy_inventory_auto_request ON psy_inventory_items;
DROP FUNCTION IF EXISTS psy_inventory_auto_request();


-- ───────────────────────────────────────────────────────────────
-- 2) 20260829b_inventory_request_no_priority.sql
-- ───────────────────────────────────────────────────────────────
-- Tambah request_no (auto-generate PR-00001, ...) + priority (tinggi/sederhana/rendah)
-- pada psy_inventory_requests. Lihat database/schema/14_products_inventory.sql utk
-- versi sumber kebenaran + nota lengkap.

ALTER TABLE psy_inventory_requests ADD COLUMN IF NOT EXISTS request_no TEXT UNIQUE;
ALTER TABLE psy_inventory_requests ADD COLUMN IF NOT EXISTS priority TEXT NOT NULL DEFAULT 'sederhana';
ALTER TABLE psy_inventory_requests DROP CONSTRAINT IF EXISTS psy_inventory_requests_priority_check;
ALTER TABLE psy_inventory_requests ADD CONSTRAINT psy_inventory_requests_priority_check
  CHECK (priority IN ('tinggi','sederhana','rendah'));

CREATE SEQUENCE IF NOT EXISTS psy_inventory_request_no_seq START 1;

CREATE OR REPLACE FUNCTION psy_inventory_set_request_no()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.request_no IS NULL THEN
    NEW.request_no := 'PR-' || LPAD(nextval('psy_inventory_request_no_seq')::text, 5, '0');
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_psy_inventory_set_request_no ON psy_inventory_requests;
CREATE TRIGGER trg_psy_inventory_set_request_no
BEFORE INSERT ON psy_inventory_requests
FOR EACH ROW EXECUTE FUNCTION psy_inventory_set_request_no();

-- Backfill request_no utk baris sedia ada.
DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN SELECT id FROM psy_inventory_requests WHERE request_no IS NULL ORDER BY created_at LOOP
    UPDATE psy_inventory_requests
      SET request_no = 'PR-' || LPAD(nextval('psy_inventory_request_no_seq')::text, 5, '0')
      WHERE id = r.id;
  END LOOP;
END $$;


-- ───────────────────────────────────────────────────────────────
-- 3) 20260829c_suppliers_module.sql
-- ───────────────────────────────────────────────────────────────
-- Modul Suppliers (P18-20) — supplier jadi entiti sendiri, bukan lagi teks
-- bebas dalam psy_inventory_items.supplier_info. Lihat
-- database/schema/32_suppliers.sql (sumber kebenaran) + 24_storage.sql
-- (bucket supplier-docs) utk versi penuh + nota.

CREATE TABLE IF NOT EXISTS psy_suppliers (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  supplier_code       TEXT UNIQUE,
  supplier_type       TEXT NOT NULL DEFAULT 'supplier'
                      CHECK (supplier_type IN ('supplier','manufacturer','distributor','service_provider')),
  name                TEXT NOT NULL,
  registration_no     TEXT,
  gst_no              TEXT,
  tax_type            TEXT,
  currency            TEXT NOT NULL DEFAULT 'MYR',
  category            TEXT,
  is_preferred        BOOLEAN NOT NULL DEFAULT false,
  status              TEXT NOT NULL DEFAULT 'active'
                      CHECK (status IN ('active','inactive','blacklisted')),
  phone               TEXT,
  mobile              TEXT,
  email               TEXT,
  fax                 TEXT,
  website             TEXT,
  address             TEXT,
  city                TEXT,
  state               TEXT,
  postcode            TEXT,
  country             TEXT DEFAULT 'Malaysia',
  business_nature     TEXT,
  payment_terms       TEXT,
  credit_limit        NUMERIC(12,2),
  min_order_amount    NUMERIC(12,2),
  lead_time_days      INT,
  bank_name           TEXT,
  bank_account_no     TEXT,
  bank_account_name   TEXT,
  notes               TEXT,
  created_by          UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_by_name     TEXT,
  updated_by          UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  updated_by_name     TEXT,
  created_at          TIMESTAMPTZ DEFAULT now(),
  updated_at          TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_suppliers_status ON psy_suppliers(status);
CREATE INDEX IF NOT EXISTS idx_suppliers_name   ON psy_suppliers(name);

CREATE SEQUENCE IF NOT EXISTS psy_supplier_code_seq START 1;

CREATE OR REPLACE FUNCTION psy_set_supplier_code()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.supplier_code IS NULL THEN
    NEW.supplier_code := 'SUP-' || LPAD(nextval('psy_supplier_code_seq')::text, 4, '0');
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_psy_set_supplier_code ON psy_suppliers;
CREATE TRIGGER trg_psy_set_supplier_code
BEFORE INSERT ON psy_suppliers
FOR EACH ROW EXECUTE FUNCTION psy_set_supplier_code();

CREATE TABLE IF NOT EXISTS psy_supplier_contacts (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  supplier_id   UUID NOT NULL REFERENCES psy_suppliers(id) ON DELETE CASCADE,
  name          TEXT NOT NULL,
  position      TEXT,
  phone         TEXT,
  email         TEXT,
  created_at    TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_supplier_contacts_supplier ON psy_supplier_contacts(supplier_id);

CREATE TABLE IF NOT EXISTS psy_supplier_documents (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  supplier_id       UUID NOT NULL REFERENCES psy_suppliers(id) ON DELETE CASCADE,
  file_name         TEXT NOT NULL,
  file_path         TEXT NOT NULL,
  file_size         INT,
  uploaded_by_name  TEXT,
  created_at        TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_supplier_documents_supplier ON psy_supplier_documents(supplier_id);

ALTER TABLE psy_inventory_items ADD COLUMN IF NOT EXISTS supplier_id UUID REFERENCES psy_suppliers(id) ON DELETE SET NULL;

ALTER TABLE psy_suppliers ENABLE ROW LEVEL SECURITY;
ALTER TABLE psy_supplier_contacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE psy_supplier_documents ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff manage suppliers" ON psy_suppliers;
CREATE POLICY "Staff manage suppliers" ON psy_suppliers FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "Staff manage supplier contacts" ON psy_supplier_contacts;
CREATE POLICY "Staff manage supplier contacts" ON psy_supplier_contacts FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "Staff manage supplier documents" ON psy_supplier_documents;
CREATE POLICY "Staff manage supplier documents" ON psy_supplier_documents FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- Storage bucket + policy
INSERT INTO storage.buckets (id, name, public) VALUES ('supplier-docs', 'supplier-docs', false)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "supplier_docs_staff_all" ON storage.objects;
CREATE POLICY "supplier_docs_staff_all" ON storage.objects
    FOR ALL TO authenticated
    USING (bucket_id = 'supplier-docs' AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
    WITH CHECK (bucket_id = 'supplier-docs' AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));


-- ───────────────────────────────────────────────────────────────
-- 4) 20260830_purchase_orders_module.sql
-- ───────────────────────────────────────────────────────────────
-- Modul Purchase Orders (P15-17) — PO rasmi ke supplier, banyak line item
-- setiap PO. Lihat database/schema/33_purchase_orders.sql (sumber kebenaran)
-- utk versi penuh + nota.
-- NOTA: modul ni DIBUANG balik di bahagian 6) di bawah — dikekalkan di sini
-- supaya susunan migration ikut sejarah sebenar (created lalu dropped).

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


-- ───────────────────────────────────────────────────────────────
-- 5) 20260830b_purchase_requests_multiitem.sql
-- ───────────────────────────────────────────────────────────────
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


-- ───────────────────────────────────────────────────────────────
-- 6) 20260831_drop_purchase_orders_module.sql
-- ───────────────────────────────────────────────────────────────
-- Modul Purchase Orders (P15-17) DIBUANG — proses sebenar syarikat tak hantar
-- PO rasmi ke supplier; staff beli terus lepas PR diluluskan ("Tandakan Dibeli"
-- di Purchase Requests dah cukup, terus update stok). Jadual ni cuma perlu
-- dibuang KALAU 20260830_purchase_orders_module.sql sempat di-run di
-- testing/prod sebelum keputusan ni — kalau belum, migration ni tiada kesan.

DROP TABLE IF EXISTS psy_purchase_order_items;
DROP TABLE IF EXISTS psy_purchase_orders;
DROP SEQUENCE IF EXISTS psy_po_number_seq;
DROP FUNCTION IF EXISTS psy_set_po_number();


-- ───────────────────────────────────────────────────────────────
-- 7) 20260831b_inventory_locations.sql
-- ───────────────────────────────────────────────────────────────
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


-- ───────────────────────────────────────────────────────────────
-- 8) 20260831c_product_form_fields.sql
-- ───────────────────────────────────────────────────────────────
-- Kolum baharu utk borang Add/Edit Product yang dikemas kini — lihat
-- database/schema/14_products_inventory.sql + 24_storage.sql (sumber
-- kebenaran) utk versi penuh + nota.

ALTER TABLE psy_inventory_items ADD COLUMN IF NOT EXISTS barcode TEXT;
ALTER TABLE psy_inventory_items ADD COLUMN IF NOT EXISTS shelf_life_days INT;
ALTER TABLE psy_inventory_items ADD COLUMN IF NOT EXISTS image_url TEXT;
ALTER TABLE psy_inventory_items ADD COLUMN IF NOT EXISTS internal_notes TEXT;

INSERT INTO storage.buckets (id, name, public) VALUES ('inventory-images', 'inventory-images', true)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "inventory_images_public_read" ON storage.objects;
CREATE POLICY "inventory_images_public_read" ON storage.objects
    FOR SELECT USING (bucket_id = 'inventory-images');

DROP POLICY IF EXISTS "inventory_images_staff_write" ON storage.objects;
CREATE POLICY "inventory_images_staff_write" ON storage.objects
    FOR ALL TO authenticated
    USING (bucket_id = 'inventory-images' AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
    WITH CHECK (bucket_id = 'inventory-images' AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));


-- ───────────────────────────────────────────────────────────────
-- 9) 20260831d_inventory_item_status.sql
-- ───────────────────────────────────────────────────────────────
-- Product Status peringkat halus (Active/Inactive/Discontinued) — lihat
-- database/schema/14_products_inventory.sql (sumber kebenaran) utk versi
-- penuh + nota. is_active DIKEKALKAN (banyak query lain guna
-- .eq('is_active', true)) — status='inactive' ATAU 'discontinued' kedua-dua
-- set is_active=false.

ALTER TABLE psy_inventory_items ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'active'
  CHECK (status IN ('active','inactive','discontinued'));

-- Pastikan is_active wujud dulu — testing kadang tertinggal patch ni
-- (lihat database/schema/14_products_inventory.sql baris 52).
ALTER TABLE psy_inventory_items ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT true;

UPDATE psy_inventory_items SET status = CASE WHEN is_active = false THEN 'inactive' ELSE 'active' END
  WHERE status = 'active' AND is_active = false;


-- ───────────────────────────────────────────────────────────────
-- 10) 20260831e_stock_in_module.sql
-- ───────────────────────────────────────────────────────────────
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
