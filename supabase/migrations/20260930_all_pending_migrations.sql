-- ═══════════════════════════════════════════════════════════════════
-- SEMUA MIGRATION TERTUNGGAK — digabung jadi SATU fail (30 Sept 2026)
-- Gabungan akhir drpd 5 fail/bundle berasingan (senarai di bawah).
-- Semua idempotent (selamat run berulang, termasuk bahagian yang
-- mungkin dah pernah run sebelum ni — akan no-op je).
--
-- Cara run: Supabase Studio -> SQL Editor -> paste SELURUH fail ni -> Run.
-- Buat kat TESTING dulu, confirm tiada error, baru PROD.
--
-- ⚠️ Fitur auto-caj HitPay (dalam bahagian installment_autocharge) —
-- skema SELAMAT run, tapi JANGAN aktifkan ciri tu (deploy edge function/
-- templat WA) sebelum diuji sandbox HitPay sebenar (risiko duit pesakit).
-- ═══════════════════════════════════════════════════════════════════

-- ═════════════════════════════════════════════════════════════════
-- BUNDLE: 20260901_combined_migrations.sql
-- ═════════════════════════════════════════════════════════════════
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


-- ═════════════════════════════════════════════════════════════════
-- BUNDLE: 20260925_combined_pending.sql
-- ═════════════════════════════════════════════════════════════════
-- ═══════════════════════════════════════════════════════════════════
-- GABUNGAN MIGRATION TERTUNGGAK — audit management Sept 2026
-- Digabung 2026-09-25 drpd 7 fail berasingan (senarai di bawah).
-- Semua idempotent (selamat run berulang). Susunan tiada kebergantungan
-- antara satu sama lain (jadual berlainan), tapi dikekalkan ikut tier.
-- ═══════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────────
-- FAIL: 20260923_reaksi_conflict_contraindication.sql
-- ─────────────────────────────────────────────────────────────────
-- Audit management 23 Sept 2026, Tier 1 (#B2-2 conflict-check, #B2-3 contraindication).
-- Rujuk: database/schema/12_reaksi.sql

-- #B2-2 — status 'needs_review' utk saranan yang tergantung sbb >1 reaksi
-- triggered serentak (conflict-check). Cron reaksi-advice-send cuma proses
-- status='draft', jadi 'needs_review' auto tak terhantar sehingga staf Lulus/Skip.
ALTER TABLE psy_reaksi_advice_log DROP CONSTRAINT IF EXISTS psy_reaksi_advice_log_status_check;
ALTER TABLE psy_reaksi_advice_log ADD CONSTRAINT psy_reaksi_advice_log_status_check
  CHECK (status IN ('draft','sent','skipped','needs_review'));

-- #B2-3 — kata kunci contraindication (padan drpd psy_patients.medical_condition)
ALTER TABLE psy_reaksi_actions ADD COLUMN IF NOT EXISTS contraindication_keywords TEXT;

-- #B2-39/#B2-45 — status semakan (Draft/Reviewed/Approved/Active). DEFAULT 'active'
-- supaya rekod sedia ada tak terjejas; kod baharu (import/drawer) set 'draft' eksplisit.
ALTER TABLE psy_reaksi_actions ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'active';
ALTER TABLE psy_reaksi_actions DROP CONSTRAINT IF EXISTS psy_reaksi_actions_status_check;
ALTER TABLE psy_reaksi_actions ADD CONSTRAINT psy_reaksi_actions_status_check
  CHECK (status IN ('draft','reviewed','approved','active'));

-- #B2-2 — notify coach bila baris 'needs_review' dicipta (patient client tak boleh
-- INSERT terus ke psy_notifications, RLS staff-only)
CREATE OR REPLACE FUNCTION trg_reaksi_advice_notify_review()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_coach_id     UUID;
  v_patient_name TEXT;
BEGIN
  IF NEW.status <> 'needs_review' THEN RETURN NEW; END IF;
  IF NOT (NEW.send_after IS NULL OR NEW.send_after <= NEW.created_at + interval '2 minutes') THEN RETURN NEW; END IF;

  SELECT pt.coach_id, COALESCE(pr.full_name, pt.full_name, 'Pesakit')
    INTO v_coach_id, v_patient_name
  FROM psy_patients pt
  LEFT JOIN psy_profiles pr ON pr.id = pt.user_id
  WHERE pt.id = NEW.patient_id;
  IF v_coach_id IS NULL THEN RETURN NEW; END IF;

  INSERT INTO psy_notifications (user_id, type, title, body, link)
  VALUES (
    v_coach_id, 'reaksi',
    '⚠️ Cadangan Perlu Disemak: ' || v_patient_name,
    v_patient_name || ' alami beberapa reaksi serentak — cadangan digenerate TAPI belum dihantar sehingga disemak. Sila semak di reaksi-laporan.html.',
    'reaksi-laporan.html'
  );

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE LOG 'trg_reaksi_advice_notify_review: %', SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_reaksi_advice_notify_review ON psy_reaksi_advice_log;
CREATE TRIGGER trg_reaksi_advice_notify_review
  AFTER INSERT ON psy_reaksi_advice_log
  FOR EACH ROW EXECUTE FUNCTION trg_reaksi_advice_notify_review();


-- ─────────────────────────────────────────────────────────────────
-- FAIL: 20260924_referral_next_action.sql
-- ─────────────────────────────────────────────────────────────────
-- Audit management 23 Sept 2026, Tier 2 (#B2-4): saranan Sesi 1:1 perlu Next Action +
-- PIC + Due Date boleh dijejak sehingga selesai, bukan berhenti sebagai nota bebas.
-- Rujuk: database/schema/20_referrals.sql

ALTER TABLE psy_clinical_referrals ADD COLUMN IF NOT EXISTS next_action TEXT;
ALTER TABLE psy_clinical_referrals ADD COLUMN IF NOT EXISTS next_action_pic UUID REFERENCES psy_profiles(id) ON DELETE SET NULL;
ALTER TABLE psy_clinical_referrals ADD COLUMN IF NOT EXISTS next_action_due DATE;
ALTER TABLE psy_clinical_referrals ADD COLUMN IF NOT EXISTS next_action_done_at TIMESTAMPTZ;


-- ─────────────────────────────────────────────────────────────────
-- FAIL: 20260924_points_manual_adjust_voucher_expiry.sql
-- ─────────────────────────────────────────────────────────────────
-- Audit management 23 Sept 2026, Tier 5 (#C-13) — pelarasan mata manual (staf,
-- sebab wajib, audit trail) + tempoh sah 90 hari utk baucar tukar mata.
-- Rujuk: database/schema/31_points.sql

CREATE OR REPLACE FUNCTION redeem_point_reward(p_reward_id UUID)
RETURNS psy_vouchers
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_patient_id UUID;
  v_reward     psy_point_rewards%ROWTYPE;
  v_balance    INT;
  v_redeemed   INT;
  v_voucher    psy_vouchers%ROWTYPE;
BEGIN
  SELECT id INTO v_patient_id FROM psy_patients WHERE user_id = auth.uid() LIMIT 1;
  IF v_patient_id IS NULL THEN
    RAISE EXCEPTION 'Rekod pesakit tidak dijumpai.';
  END IF;

  SELECT * INTO v_reward FROM psy_point_rewards WHERE id = p_reward_id;
  IF v_reward.id IS NULL OR NOT v_reward.is_active THEN
    RAISE EXCEPTION 'Ganjaran ini tidak sah atau tidak lagi ditawarkan.';
  END IF;

  IF v_reward.max_redemptions_per_patient IS NOT NULL THEN
    SELECT COUNT(*) INTO v_redeemed FROM psy_points_ledger
      WHERE patient_id = v_patient_id AND source_type = 'reward_redeem' AND source_ref = v_reward.id;
    IF v_redeemed >= v_reward.max_redemptions_per_patient THEN
      RAISE EXCEPTION 'Anda telah mencapai had tukaran untuk ganjaran ini.';
    END IF;
  END IF;

  SELECT COALESCE(SUM(points), 0) INTO v_balance FROM psy_points_ledger WHERE patient_id = v_patient_id;
  IF v_balance < v_reward.points_cost THEN
    RAISE EXCEPTION 'Mata tidak mencukupi.';
  END IF;

  INSERT INTO psy_points_ledger (patient_id, source_type, source_ref, points, note)
  VALUES (v_patient_id, 'reward_redeem', v_reward.id, -v_reward.points_cost, 'Tukar: ' || v_reward.name);

  INSERT INTO psy_vouchers (patient_id, source_type, source_ref, amount, note, expires_at)
  VALUES (v_patient_id, 'point_redeem', v_reward.id, v_reward.voucher_amount, 'Ditukar dari mata: ' || v_reward.name, now() + interval '90 days')
  RETURNING * INTO v_voucher;

  RETURN v_voucher;
END;
$$;

GRANT EXECUTE ON FUNCTION redeem_point_reward(UUID) TO authenticated;

CREATE OR REPLACE FUNCTION adjust_points_manual(p_patient_id UUID, p_points INT, p_reason TEXT)
RETURNS psy_points_ledger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_is_staff BOOLEAN;
  v_row      psy_points_ledger%ROWTYPE;
BEGIN
  SELECT EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff') INTO v_is_staff;
  IF NOT v_is_staff THEN
    RAISE EXCEPTION 'Hanya staf boleh laras mata pesakit.';
  END IF;
  IF p_points = 0 THEN
    RAISE EXCEPTION 'Bilangan mata mesti bukan sifar.';
  END IF;
  IF p_reason IS NULL OR btrim(p_reason) = '' THEN
    RAISE EXCEPTION 'Sebab pelarasan diperlukan.';
  END IF;

  INSERT INTO psy_points_ledger (patient_id, source_type, points, note)
  VALUES (p_patient_id, 'manual_adjustment', p_points, btrim(p_reason))
  RETURNING * INTO v_row;

  RETURN v_row;
END;
$$;

GRANT EXECUTE ON FUNCTION adjust_points_manual(UUID, INT, TEXT) TO authenticated;


-- ─────────────────────────────────────────────────────────────────
-- FAIL: 20260924_promo_scope_stack_eligibility.sql
-- ─────────────────────────────────────────────────────────────────
-- Audit management 23 Sept 2026, Tier 5 (#D-15, #D-16, #D-17) — skop
-- "Terpakai Untuk" (Produk/Kategori/Pakej), gabung baucar (stackable),
-- eligibility pelanggan baharu, label kempen.
-- Rujuk: database/schema/29_promo_codes.sql

ALTER TABLE psy_promo_codes ADD COLUMN IF NOT EXISTS applies_to TEXT NOT NULL DEFAULT 'all'
  CHECK (applies_to IN ('all','product','category','package'));
ALTER TABLE psy_promo_codes ADD COLUMN IF NOT EXISTS applies_to_values TEXT[];
ALTER TABLE psy_promo_codes ADD COLUMN IF NOT EXISTS stackable BOOLEAN NOT NULL DEFAULT true;
ALTER TABLE psy_promo_codes ADD COLUMN IF NOT EXISTS new_customer_only BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE psy_promo_codes ADD COLUMN IF NOT EXISTS campaign TEXT;


-- ─────────────────────────────────────────────────────────────────
-- FAIL: 20260924_announcement_reads.sql
-- ─────────────────────────────────────────────────────────────────
-- Audit management 23 Sept 2026, Tier 5 (#G-33, #G-34) — penjejakan "dibaca"
-- pengumuman (impression-based, bila muncul di dashboard/senarai pesakit).
-- Rujuk: database/schema/19_events_announcements.sql

CREATE TABLE IF NOT EXISTS psy_announcement_reads (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  announcement_id UUID NOT NULL REFERENCES psy_announcements(id) ON DELETE CASCADE,
  patient_id      UUID NOT NULL REFERENCES psy_patients(id) ON DELETE CASCADE,
  read_at         TIMESTAMPTZ DEFAULT now(),
  UNIQUE (announcement_id, patient_id)
);

CREATE INDEX IF NOT EXISTS idx_ann_reads_ann ON psy_announcement_reads(announcement_id);

ALTER TABLE psy_announcement_reads ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Patients mark own reads" ON psy_announcement_reads;
CREATE POLICY "Patients mark own reads" ON psy_announcement_reads FOR INSERT
  WITH CHECK (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Patients view own reads" ON psy_announcement_reads;
CREATE POLICY "Patients view own reads" ON psy_announcement_reads FOR SELECT
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Staff view all reads" ON psy_announcement_reads;
CREATE POLICY "Staff view all reads" ON psy_announcement_reads FOR SELECT
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));


-- ─────────────────────────────────────────────────────────────────
-- FAIL: 20260924_event_meet_link_capacity.sql
-- ─────────────────────────────────────────────────────────────────
-- Audit management 23 Sept 2026, Tier 5 (#H-35, #H-36) — kuatkuasa kapasiti
-- pendaftaran acara + keluarkan meet_link dari psy_events (RLS row-level tak
-- boleh sembunyi satu lajur sahaja — jadual berasingan supaya pesakit yang
-- BELUM daftar betul-betul tak dapat baca pautan Meet, bukan sekadar disorok
-- di UI). Rujuk: database/schema/19_events_announcements.sql

CREATE TABLE IF NOT EXISTS psy_event_meet_links (
  event_id   UUID PRIMARY KEY REFERENCES psy_events(id) ON DELETE CASCADE,
  meet_link  TEXT,
  updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE psy_event_meet_links ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff manage event meet links" ON psy_event_meet_links;
CREATE POLICY "Staff manage event meet links" ON psy_event_meet_links FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
  WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "Registered patients read meet link" ON psy_event_meet_links;
CREATE POLICY "Registered patients read meet link" ON psy_event_meet_links FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM psy_event_registrations r
    JOIN psy_patients p ON p.id = r.patient_id
    WHERE r.event_id = psy_event_meet_links.event_id
      AND p.user_id = auth.uid() AND r.status <> 'batal'
  ));

-- Backfill dari lajur lama SEBELUM dibuang. Dibungkus check column wujud —
-- kalau section ni dah pernah run (meet_link dah dibuang dari psy_events),
-- run berulang kali skip terus (bukan error 42703 "column does not exist",
-- sebab SELECT meet_link FROM psy_events cuma sah bila lajur tu masih ada).
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'psy_events' AND column_name = 'meet_link'
  ) THEN
    INSERT INTO psy_event_meet_links (event_id, meet_link)
    SELECT id, meet_link FROM psy_events WHERE meet_link IS NOT NULL
    ON CONFLICT (event_id) DO UPDATE SET meet_link = EXCLUDED.meet_link;

    ALTER TABLE psy_events DROP COLUMN meet_link;
  END IF;
END $$;

-- #H-35 — kuatkuasa kapasiti pendaftaran acara (server-side, staf override dibenarkan)
CREATE OR REPLACE FUNCTION trg_enforce_event_capacity()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_capacity INT;
  v_count    INT;
  v_is_staff BOOLEAN;
BEGIN
  IF NEW.status = 'batal' THEN RETURN NEW; END IF;
  SELECT EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff') INTO v_is_staff;
  IF v_is_staff THEN RETURN NEW; END IF;

  SELECT capacity INTO v_capacity FROM psy_events WHERE id = NEW.event_id;
  IF v_capacity IS NULL THEN RETURN NEW; END IF;

  SELECT COUNT(*) INTO v_count FROM psy_event_registrations
    WHERE event_id = NEW.event_id AND status <> 'batal' AND id <> COALESCE(NEW.id, '00000000-0000-0000-0000-000000000000'::uuid);
  IF v_count >= v_capacity THEN
    RAISE EXCEPTION 'Acara ini telah penuh (kapasiti % peserta).', v_capacity;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_enforce_event_capacity ON psy_event_registrations;
CREATE TRIGGER trg_enforce_event_capacity
  BEFORE INSERT OR UPDATE ON psy_event_registrations
  FOR EACH ROW EXECUTE FUNCTION trg_enforce_event_capacity();


-- ─────────────────────────────────────────────────────────────────
-- FAIL: 20260924_split_invoice_receipt_payment.sql
-- ─────────────────────────────────────────────────────────────────
-- Audit management 23 Sept 2026 (#F-23, Tier 3→5 — sengaja ditangguh di Tier 3,
-- kini dibuat) — Pisah Invoice/Receipt/Payment jadi 3 jadual berasingan.
-- Rujuk: database/schema/06_payments.sql (sumber kebenaran, dah dikemaskini).
--
-- PENDEKATAN: tambahan sahaja (additive) — psy_payments KEKAL bentuk sedia ada,
-- SEMUA laluan tulis sedia ada (webhook gateway, autocharge ansuran, GHL sync,
-- entri manual staf KOB/kedai) TAK disentuh langsung. Cuma denda tidak hadir
-- (plan-week.html) dipindah guna psy_invoices sebenar (kod app dikemaskini
-- berasingan, bukan dalam migration ni).

-- ──── 1. Betulkan trigger invoice_no sedia ada (elak nombor berganda) ────
ALTER TABLE psy_payments ADD COLUMN IF NOT EXISTS invoice_id UUID;

CREATE OR REPLACE FUNCTION psy_assign_payment_invoice_no() RETURNS trigger AS $$
BEGIN
  IF NEW.invoice_no IS NULL AND NEW.status IN ('pending','completed')
     AND (NEW.intent ->> 'kob_session_id') IS NULL
     AND NEW.invoice_id IS NULL THEN
    NEW.invoice_no := 'INV-' || lpad(nextval('psy_invoice_no_seq')::text, 6, '0');
  END IF;
  RETURN NEW;
END $$ LANGUAGE plpgsql;

-- ──── 2. psy_receipts — trigger-created sahaja, tiada laluan client INSERT ────
CREATE TABLE IF NOT EXISTS psy_receipts (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  payment_id UUID NOT NULL UNIQUE REFERENCES psy_payments(id) ON DELETE CASCADE,
  patient_id UUID REFERENCES psy_patients(id),
  receipt_no TEXT,
  total      NUMERIC(10,2) NOT NULL,
  issued_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  pdf_url    TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_psy_receipts_patient ON psy_receipts(patient_id);

ALTER TABLE psy_receipts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Patients read own receipts" ON psy_receipts;
CREATE POLICY "Patients read own receipts" ON psy_receipts FOR SELECT
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Staff read all receipts" ON psy_receipts;
CREATE POLICY "Staff read all receipts" ON psy_receipts FOR SELECT
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

CREATE OR REPLACE FUNCTION trg_create_receipt_on_payment_completed()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NEW.status = 'completed' AND (TG_OP = 'INSERT' OR OLD.status IS DISTINCT FROM 'completed') THEN
    INSERT INTO psy_receipts (payment_id, patient_id, receipt_no, total, pdf_url)
    VALUES (NEW.id, NEW.patient_id, NEW.receipt_no, NEW.total, NEW.receipt_url)
    ON CONFLICT (payment_id) DO NOTHING;
  END IF;
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE LOG 'trg_create_receipt_on_payment_completed: %', SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_create_receipt_on_payment_completed ON psy_payments;
CREATE TRIGGER trg_create_receipt_on_payment_completed
  AFTER INSERT OR UPDATE OF status ON psy_payments
  FOR EACH ROW EXECUTE FUNCTION trg_create_receipt_on_payment_completed();

-- Backfill sejarah — semua bayaran 'completed' sedia ada dapat rekod resit serta-merta.
INSERT INTO psy_receipts (payment_id, patient_id, receipt_no, total, pdf_url, issued_at)
SELECT id, patient_id, receipt_no, total, receipt_url, COALESCE(paid_at, created_at)
FROM psy_payments WHERE status = 'completed'
ON CONFLICT (payment_id) DO NOTHING;

-- ──── 3. psy_invoices — amaun tertunggak, boleh wujud sebelum sebarang bayaran ────
CREATE TABLE IF NOT EXISTS psy_invoices (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  invoice_no  TEXT UNIQUE,
  patient_id  UUID NOT NULL REFERENCES psy_patients(id),
  description TEXT NOT NULL,
  amount      NUMERIC(10,2) NOT NULL CHECK (amount > 0),
  status      TEXT NOT NULL DEFAULT 'unpaid' CHECK (status IN ('unpaid','partially_paid','paid','void')),
  source_type TEXT,
  source_ref  TEXT,
  created_by  UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  created_at  TIMESTAMPTZ DEFAULT now(),
  updated_at  TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_psy_invoices_patient ON psy_invoices(patient_id, status);

ALTER TABLE psy_invoices ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Patients read own invoices" ON psy_invoices;
CREATE POLICY "Patients read own invoices" ON psy_invoices FOR SELECT
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Staff manage invoices" ON psy_invoices;
CREATE POLICY "Staff manage invoices" ON psy_invoices FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

CREATE OR REPLACE FUNCTION psy_assign_invoice_no() RETURNS trigger AS $$
BEGIN
  IF NEW.invoice_no IS NULL THEN
    NEW.invoice_no := 'INV-' || lpad(nextval('psy_invoice_no_seq')::text, 6, '0');
  END IF;
  RETURN NEW;
END $$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_psy_assign_invoice_no ON psy_invoices;
CREATE TRIGGER trg_psy_assign_invoice_no BEFORE INSERT ON psy_invoices
  FOR EACH ROW EXECUTE FUNCTION psy_assign_invoice_no();

ALTER TABLE psy_payments DROP CONSTRAINT IF EXISTS psy_payments_invoice_id_fkey;
ALTER TABLE psy_payments ADD CONSTRAINT psy_payments_invoice_id_fkey
  FOREIGN KEY (invoice_id) REFERENCES psy_invoices(id);
CREATE INDEX IF NOT EXISTS idx_psy_payments_invoice ON psy_payments(invoice_id);

CREATE OR REPLACE FUNCTION trg_update_invoice_status_on_payment()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_amount NUMERIC;
  v_paid   NUMERIC;
BEGIN
  IF NEW.invoice_id IS NULL THEN RETURN NEW; END IF;
  SELECT amount INTO v_amount FROM psy_invoices WHERE id = NEW.invoice_id;
  IF v_amount IS NULL THEN RETURN NEW; END IF;
  SELECT COALESCE(SUM(total), 0) INTO v_paid FROM psy_payments
    WHERE invoice_id = NEW.invoice_id AND status = 'completed';
  UPDATE psy_invoices SET
    status = CASE
      WHEN v_paid <= 0 THEN 'unpaid'
      WHEN v_paid + 0.005 >= v_amount THEN 'paid'
      ELSE 'partially_paid'
    END,
    updated_at = now()
  WHERE id = NEW.invoice_id AND status <> 'void';
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE LOG 'trg_update_invoice_status_on_payment: %', SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_update_invoice_status_on_payment ON psy_payments;
CREATE TRIGGER trg_update_invoice_status_on_payment
  AFTER INSERT OR UPDATE OF status ON psy_payments
  FOR EACH ROW EXECUTE FUNCTION trg_update_invoice_status_on_payment();


-- ─────────────────────────────────────────────────────────────────
-- FAIL: 20260925_patients_created_by.sql
-- ─────────────────────────────────────────────────────────────────
-- Jejak SIAPA cipta rekod pesakit manual dalam PT System (roles/staff/patients.html
-- "+ Tambah Pesakit / Tempah KOB") — sebelum ni cuma `created_by_staff` (boolean,
-- true/false je). Punca rekod pendua Sept 2026: staf create manual SEBELUM cron
-- ghl-pull-sync sempat proses contact GHL yang sama, dua patient_id berasingan
-- tercipta. `created_by`/`created_by_name` bantu kenal pasti punca (rekod mana
-- dicipta staf manual vs auto-sync GHL, referral_source dah bezakan tu — lajur
-- ni tambah SIAPA secara khusus).

ALTER TABLE psy_patients ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES psy_profiles(id) ON DELETE SET NULL;
ALTER TABLE psy_patients ADD COLUMN IF NOT EXISTS created_by_name TEXT;


-- ─────────────────────────────────────────────────────────────────
-- FAIL: 20260925_ghl_kob_code.sql
-- ─────────────────────────────────────────────────────────────────
-- GHL Workflow "SU KOB Auto ID" prepend kod (cth "KOB'26-000139") depan
-- nama contact ("KOB'26-000139. Pn Syamira"). ghl-booking-webhook kini
-- auto-asingkan kod tu drpd full_name, simpan berasingan di sini — BUKAN
-- reference_code ("Kod Pesakit", diisi lepas pesakit signup pakej OB,
-- tujuan lain). Rujuk: database/schema/04_patients.sql,
-- supabase/functions/_shared/ghl-sync.ts (splitGhlNameCode).

ALTER TABLE psy_patients ADD COLUMN IF NOT EXISTS ghl_kob_code TEXT;


-- ─────────────────────────────────────────────────────────────────
-- FAIL: 20260925_registrant_capacity.sql
-- ─────────────────────────────────────────────────────────────────
-- GHL borang tanya 2 soalan berasingan pasal pendaftar: "Peranan
-- Pendaftar" (Pesakit/Waris Bertanggungjawab/Waris Wakil/Waris — map ke
-- contact_preference sedia ada) DAN "Anda mengisi borang ini sebagai?"
-- (sejauh mana terlibat — sendiri/urus penuh/bantu isi sahaja, medan
-- BAHARU registrant_capacity, TIADA di sistem lagi). Rujuk:
-- database/schema/04_patients.sql, supabase/functions/ghl-booking-webhook.

ALTER TABLE psy_patients ADD COLUMN IF NOT EXISTS registrant_capacity TEXT;


-- ─────────────────────────────────────────────────────────────────
-- FAIL: 20260925_ghl_contact_id.sql
-- ─────────────────────────────────────────────────────────────────
-- Simpan ID dalaman contact GHL ({{contact.id}}) sebagai rujukan pantas/
-- debug & future API call terus ke GHL. TIDAK dipakai untuk padanan
-- pesakit (kekal ikut telefon). Rujuk: database/schema/04_patients.sql,
-- supabase/functions/ghl-booking-webhook.

ALTER TABLE psy_patients ADD COLUMN IF NOT EXISTS ghl_contact_id TEXT;


-- ─────────────────────────────────────────────────────────────────
-- FAIL: 20260925_kob_status_kiv_noshow.sql
-- ─────────────────────────────────────────────────────────────────
-- Status KOB dropdown boleh-edit di kob-list.html — 2 status BAHARU:
-- kiv (sesi selesai, pesakit tak teruskan pakej) & no_show (staff sahkan
-- tak hadir, status TETAP — beza drpd "Terlepas" label terbitan
-- sementara). Disync balik ke GHL "ISW STATUS" (sync-ghl). Rujuk:
-- database/schema/09_kob.sql, supabase/functions/sync-ghl.

ALTER TABLE psy_kob_sessions DROP CONSTRAINT IF EXISTS psy_kob_sessions_status_check;
ALTER TABLE psy_kob_sessions ADD CONSTRAINT psy_kob_sessions_status_check
  CHECK (status IN ('booked','hadir','completed','reschedule','cancelled','kiv','no_show'));




-- ═════════════════════════════════════════════════════════════════
-- BUNDLE: 20260930_data_maintenance.sql
-- ═════════════════════════════════════════════════════════════════
-- ═══════════════════════════════════════════════════════════════════
-- GABUNGAN MIGRATION TERTUNGGAK — audit management Sept 2026 (batch 2)
-- Digabung 2026-09-30 drpd 7 fail berasingan (senarai di bawah), semua
-- ditulis/disemak SELEPAS 20260925_combined_pending.sql (checkpoint gabungan
-- sebelum ni). Semua idempotent (selamat run berulang). Susunan tiada
-- kebergantungan antara satu sama lain (jadual berlainan) KECUALI 2 fail
-- Library — KEKALKAN turutan (rls_package_restrict dulu, workflow_week_audience
-- lepas, policy kedua menggantikan yang pertama dgn versi lebih lengkap).
-- ═══════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────────
-- FAIL: 20260925_library_rls_package_restrict.sql
-- ─────────────────────────────────────────────────────────────────
-- Audit management batch 3 (25 Sept 2026), Tier 7 #2 — isu keselamatan:
-- psy_library_items policy lama "Anyone read library" USING (true) bermakna
-- sekatan package_ids cuma di UI (isLocked() client-side), sesiapa (termasuk
-- tak login) boleh baca content_url semua rekod terus melalui API. Gantikan
-- dgn policy yang benar-benar kuatkuasa sekatan pakej di server.
-- Rujuk: database/schema/13_library_faq.sql, memory project_audit_tier6_7_sept2026.

DROP POLICY IF EXISTS "Anyone read library" ON psy_library_items;
DROP POLICY IF EXISTS "Patients read allowed library" ON psy_library_items;
CREATE POLICY "Patients read allowed library" ON psy_library_items FOR SELECT
  TO authenticated
  USING (
    is_active = true
    AND (
      package_ids IS NULL OR array_length(package_ids, 1) IS NULL
      OR EXISTS (
        SELECT 1 FROM psy_patients p
        LEFT JOIN psy_packages pk
          ON pk.id::text = p.active_package_id OR pk.package_id = p.active_package_id
        WHERE p.user_id = auth.uid()
          AND (p.active_package_id = ANY(package_ids) OR pk.package_id = ANY(package_ids))
      )
    )
  );

-- ─────────────────────────────────────────────────────────────────
-- FAIL: 20260925_library_workflow_week_audience.sql
-- ─────────────────────────────────────────────────────────────────
-- Audit management batch 3 (25 Sept 2026), Tier 7 #1/#2/#3a/#4 — Library.
-- Rujuk: database/schema/13_library_faq.sql, database/schema/24_storage.sql

-- ═══ 1. Kolum baharu psy_library_items ═══
ALTER TABLE psy_library_items ADD COLUMN IF NOT EXISTS week_number INT;
ALTER TABLE psy_library_items ADD COLUMN IF NOT EXISTS staff_roles TEXT[];
ALTER TABLE psy_library_items ADD COLUMN IF NOT EXISTS publish_at TIMESTAMPTZ;

COMMENT ON COLUMN psy_library_items.status IS
  'draft | review | approved | published | archived. is_active = (status=published). Pesakit nampak published sahaja.';
COMMENT ON COLUMN psy_library_items.week_number IS
  'Minggu rawatan (dalam pakej yg dipilih di package_ids) kandungan ni relevan. NULL = semua minggu.';
COMMENT ON COLUMN psy_library_items.staff_roles IS
  'Kalau diisi, kandungan ni RUJUKAN STAF sahaja (bukan pesakit) — hanya staff dgn salah satu peranan ni nampak. NULL/kosong = kandungan pesakit biasa.';
COMMENT ON COLUMN psy_library_items.publish_at IS
  'Kalau diisi & di masa depan, kandungan tak nampak kpd pesakit walau status=published/is_active=true sehingga masa ni sampai (dikuatkuasa di RLS).';

-- ═══ 2. RLS: kuatkuasa sekatan pakej + role + jadual terbit di server ═══
-- (menggantikan policy dari fail sebelum ni dgn versi lebih lengkap)
DROP POLICY IF EXISTS "Anyone read library" ON psy_library_items;
DROP POLICY IF EXISTS "Patients read allowed library" ON psy_library_items;
CREATE POLICY "Patients read allowed library" ON psy_library_items FOR SELECT
  TO authenticated
  USING (
    is_active = true
    AND (staff_roles IS NULL OR array_length(staff_roles, 1) IS NULL)
    AND (publish_at IS NULL OR publish_at <= now())
    AND (
      package_ids IS NULL OR array_length(package_ids, 1) IS NULL
      OR EXISTS (
        SELECT 1 FROM psy_patients p
        LEFT JOIN psy_packages pk
          ON pk.id::text = p.active_package_id OR pk.package_id = p.active_package_id
        WHERE p.user_id = auth.uid()
          AND (p.active_package_id = ANY(package_ids) OR pk.package_id = ANY(package_ids))
      )
    )
  );

-- ═══ 3. Bucket library-media — had saiz/format (dulu tiada langsung) ═══
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('library-media', 'library-media', true, 524288000, ARRAY[
  'video/mp4','video/quicktime','video/webm',
  'audio/mpeg','audio/mp4','audio/x-m4a','audio/wav',
  'image/png','image/jpeg','image/jpg','image/webp',
  'application/pdf','application/msword',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'application/vnd.ms-powerpoint',
  'application/vnd.openxmlformats-officedocument.presentationml.presentation'
])
ON CONFLICT (id) DO UPDATE
  SET public = EXCLUDED.public,
      file_size_limit = EXCLUDED.file_size_limit,
      allowed_mime_types = EXCLUDED.allowed_mime_types;

DROP POLICY IF EXISTS "library_media_staff_write" ON storage.objects;
CREATE POLICY "library_media_staff_write" ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'library-media' AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "library_media_staff_update" ON storage.objects;
CREATE POLICY "library_media_staff_update" ON storage.objects
    FOR UPDATE TO authenticated
    USING (bucket_id = 'library-media' AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "library_media_staff_delete" ON storage.objects;
CREATE POLICY "library_media_staff_delete" ON storage.objects
    FOR DELETE TO authenticated
    USING (bucket_id = 'library-media' AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "library_media_public_read" ON storage.objects;
CREATE POLICY "library_media_public_read" ON storage.objects
    FOR SELECT USING (bucket_id = 'library-media');

-- ─────────────────────────────────────────────────────────────────
-- FAIL: 20260925_recommended_directory.sql
-- ─────────────────────────────────────────────────────────────────
-- Audit management 23 Sept 2026, Tier 5 batch 2 module VI & VII — 2 modul
-- BAHARU: Master Produk & Bahan + Direktori Cadangan.
-- Rujuk: database/schema/39_recommended_directory.sql, database/schema/03_rbac_security.sql

-- ═══ 1. Jadual baharu ═══

CREATE TABLE IF NOT EXISTS psy_recommended_products (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name              TEXT NOT NULL,
  category          TEXT,
  purpose           TEXT,
  qty_note          TEXT,
  requirement_level TEXT NOT NULL DEFAULT 'cadangan'
                    CHECK (requirement_level IN ('wajib','cadangan','opsyenal')),
  price             NUMERIC(10,2),
  notes             TEXT,
  is_active         BOOLEAN NOT NULL DEFAULT true,
  last_verified_at  TIMESTAMPTZ,
  created_by        UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  created_at        TIMESTAMPTZ DEFAULT now(),
  updated_at        TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_rec_products_active ON psy_recommended_products(is_active);

ALTER TABLE psy_recommended_products ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff manage recommended products" ON psy_recommended_products;
CREATE POLICY "Staff manage recommended products" ON psy_recommended_products FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
  WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

CREATE TABLE IF NOT EXISTS psy_recommended_product_sellers (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id  UUID NOT NULL REFERENCES psy_recommended_products(id) ON DELETE CASCADE,
  platform    TEXT,
  seller_name TEXT,
  link        TEXT,
  price       NUMERIC(10,2),
  notes       TEXT,
  sort_order  INT DEFAULT 0,
  created_at  TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_rec_sellers_product ON psy_recommended_product_sellers(product_id);

ALTER TABLE psy_recommended_product_sellers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff manage recommended product sellers" ON psy_recommended_product_sellers;
CREATE POLICY "Staff manage recommended product sellers" ON psy_recommended_product_sellers FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
  WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

CREATE TABLE IF NOT EXISTS psy_package_recommended_products (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  package_id  TEXT NOT NULL,
  product_id  UUID NOT NULL REFERENCES psy_recommended_products(id) ON DELETE CASCADE,
  week_number INT,
  created_at  TIMESTAMPTZ DEFAULT now(),
  UNIQUE (package_id, product_id, week_number)
);

CREATE INDEX IF NOT EXISTS idx_rec_pkg_map_package ON psy_package_recommended_products(package_id);
CREATE INDEX IF NOT EXISTS idx_rec_pkg_map_product ON psy_package_recommended_products(product_id);

ALTER TABLE psy_package_recommended_products ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff manage package recommended products" ON psy_package_recommended_products;
CREATE POLICY "Staff manage package recommended products" ON psy_package_recommended_products FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
  WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

CREATE TABLE IF NOT EXISTS psy_recommended_restaurants (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name              TEXT NOT NULL,
  category          TEXT,
  location          TEXT,
  maps_url          TEXT,
  menu_notes        TEXT,
  price_range       TEXT,
  status            TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active','inactive')),
  notes             TEXT,
  last_verified_at  TIMESTAMPTZ,
  created_by        UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  created_at        TIMESTAMPTZ DEFAULT now(),
  updated_at        TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_rec_restaurants_status ON psy_recommended_restaurants(status);

ALTER TABLE psy_recommended_restaurants ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff manage recommended restaurants" ON psy_recommended_restaurants;
CREATE POLICY "Staff manage recommended restaurants" ON psy_recommended_restaurants FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
  WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- ═══ 2. Pendaftaran RBAC (2 modul baharu) ═══

INSERT INTO psy_modules (code, label, icon, scope, sort_order) VALUES
  ('produk_bahan',      'Produk & Bahan Luar',  '🧴', 'staff', 101),
  ('direktori_cadangan','Direktori Cadangan',   '📇', 'staff', 102)
ON CONFLICT (code) DO UPDATE SET
  label = EXCLUDED.label, icon = EXCLUDED.icon, scope = EXCLUDED.scope, sort_order = EXCLUDED.sort_order;

-- Module × Action — semua action utk 2 modul baharu
INSERT INTO psy_module_actions (module_code, action_code)
SELECT m.code, a.code FROM psy_modules m CROSS JOIN psy_actions a
WHERE m.code IN ('produk_bahan','direktori_cadangan')
ON CONFLICT DO NOTHING;

-- super_admin / manager / admin dapat automatik (grant sedia ada guna
-- "WHERE scope='staff'" blanket query — cuma perlu ULANG langkah 3 di bawah
-- utk 2 modul baharu ni kembang ke create/edit/delete/export).
INSERT INTO psy_role_module_actions (role_code, module_code, action_code)
SELECT 'super_admin', code, 'view' FROM psy_modules WHERE code IN ('produk_bahan','direktori_cadangan')
ON CONFLICT DO NOTHING;
INSERT INTO psy_role_module_actions (role_code, module_code, action_code)
SELECT 'manager', code, 'view' FROM psy_modules WHERE code IN ('produk_bahan','direktori_cadangan')
ON CONFLICT DO NOTHING;
INSERT INTO psy_role_module_actions (role_code, module_code, action_code)
SELECT 'admin', code, 'view' FROM psy_modules WHERE code IN ('produk_bahan','direktori_cadangan')
ON CONFLICT DO NOTHING;
-- Doctor & Coach — paling relevan (beri cadangan kpd pesakit)
INSERT INTO psy_role_module_actions (role_code, module_code, action_code)
SELECT r.role, m.code, 'view'
FROM (VALUES ('doctor'),('coach')) AS r(role)
CROSS JOIN (VALUES ('produk_bahan'),('direktori_cadangan')) AS m(code)
ON CONFLICT DO NOTHING;

-- Kembangkan 'view' → create/edit/delete/export utk role yg baru diberi view di atas
INSERT INTO psy_role_module_actions (role_code, module_code, action_code)
SELECT rma.role_code, rma.module_code, a.code
FROM psy_role_module_actions rma
CROSS JOIN psy_actions a
WHERE rma.module_code IN ('produk_bahan','direktori_cadangan')
  AND rma.action_code = 'view'
  AND a.code IN ('create','edit','delete','export')
ON CONFLICT DO NOTHING;

-- ─────────────────────────────────────────────────────────────────
-- FAIL: 20260928_rename_telesales_role_to_kob.sql
-- ─────────────────────────────────────────────────────────────────
-- Rename legacy role code 'telesales' (label "KOB" di peranan.html, drives
-- Collector/Closer assign dropdown di roles/staff/kob-list.html/kob-detail.html)
-- -> 'kob', ikut niat asal reka bentuk (lihat komen "staff_role 'kob'" di
-- database/schema/09_kob.sql baris 34/38). Keputusan 28 Sept 2026.
--
-- Kebenaran (psy_role_module_actions) DIKEKALKAN apa adanya (~semua modul,
-- keputusan user 28 Sept — bukan direset ke set KOB-focus yg dirangka utk
-- role 'telesale' berasingan di 03_rbac_security.sql; 'telesale' tu kekal
-- tidak digunakan/orphan, tiada kaitan dgn rename ni).
--
-- Guna INSERT+UPDATE+DELETE (bukan UPDATE terus atas psy_roles.code) sebab
-- psy_role_module_actions.role_code ada FK ke psy_roles(code) TANPA
-- ON UPDATE CASCADE — UPDATE PK terus akan gagal dgn FK violation.
-- Idempotent — selamat di-run berulang kali (no-op lepas kali pertama).

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM psy_roles WHERE code = 'telesales')
     AND NOT EXISTS (SELECT 1 FROM psy_roles WHERE code = 'kob') THEN
    INSERT INTO psy_roles (code, label, description, color, icon, is_active, is_system, sort_order)
    SELECT 'kob', label, description, color, icon, is_active, is_system, sort_order
    FROM psy_roles WHERE code = 'telesales';
  END IF;
END $$;

UPDATE psy_role_module_actions SET role_code = 'kob' WHERE role_code = 'telesales';
UPDATE psy_profiles SET staff_role = 'kob' WHERE staff_role = 'telesales';

DELETE FROM psy_roles WHERE code = 'telesales';

-- ─────────────────────────────────────────────────────────────────
-- FAIL: 20260929_ghl_patient_phone_unique.sql
-- ─────────────────────────────────────────────────────────────────
-- Jaring keselamatan DB terhadap bug dedup pesakit GHL (syncContactToPatient
-- gagal senyap cari padanan phone sedia ada, cipta pesakit BAHARU setiap
-- kali dipanggil semula utk contact yg sama — punca sebenar dalam kod masih
-- disiasat 28-29 Sept 2026). Constraint ni tak fix punca, tapi tukar tingkah
-- laku dari "senyap cipta pendua" ke "INSERT gagal terus" — nampak jelas
-- dalam psy_audit_log/errors, bukan senyap corrupt data lagi.
--
-- Skop HANYA referral_source='GHL' (bukan semua psy_patients) — rekod
-- staff-created/self-signup masih boleh kongsi phone (cth ahli keluarga
-- guna nombor sama), cuma pesakit auto-sync GHL yang patut 1 phone = 1 rekod.
CREATE UNIQUE INDEX IF NOT EXISTS idx_psy_patients_ghl_phone_unique
  ON psy_patients (phone) WHERE referral_source = 'GHL' AND phone IS NOT NULL;

-- ─────────────────────────────────────────────────────────────────
-- FAIL: 20260930_package_version_number.sql
-- ─────────────────────────────────────────────────────────────────
-- Version Management pakej (audit management, gantikan corak manual "(new)" dlm
-- nama pakej — lihat pakej.html versionCell()/pakej-edit.html f-version).
-- psy_packages.version_number sudah ADA dlm CREATE TABLE (database/schema/05_packages.sql)
-- utk pemasangan BAHARU, tapi tiada ALTER TABLE ditulis utk DB SEDIA ADA (testing/prod)
-- — kod UI dah siap sejak 18 Sept 2026 tapi lajur ni tak pernah benar-benar wujud
-- di live DB sehingga migration ni dijalankan.
ALTER TABLE psy_packages ADD COLUMN IF NOT EXISTS version_number INT NOT NULL DEFAULT 1;

COMMENT ON COLUMN psy_packages.version_number IS
  'Nombor version pakej (1, 2, 3, ...) — gantikan corak manual "(new)" dalam nama pakej. Version tertinggi bagi Nama Pakej yang sama = version semasa (implicit ikut nombor, tiada medan status berasingan).';

-- ─────────────────────────────────────────────────────────────────
-- FAIL: 20260930_vitals_threshold_governance.sql
-- ─────────────────────────────────────────────────────────────────
-- Audit management batch 3 (29-30 Sept 2026) — Governance ambang vitals.
-- Menggantikan pendekatan lama (20260923_vitals_critical_emergency.sql, TAK PERNAH
-- dijalankan) yang hardcode nombor kritikal terus dalam fungsi SQL tanpa pengesahan
-- doktor. Kini ambang dibaca dari psy_settings.vitals_thresholds (diedit oleh
-- super_admin/doktor di tetapan.html, tab "Ambang Vitals").
--
-- PENTING: critical_min/critical_max SENGAJA null untuk semua vital dalam seed di
-- bawah — automasi Protokol Kecemasan (is_critical → auto-cipta psy_emergency_alerts)
-- TAK AKAN aktif sehingga seseorang isi nilai melalui UI. Migration ni sendiri TIDAK
-- menghidupkan apa-apa automasi baharu.
--
-- Rujuk: database/schema/10_vitals.sql, database/schema/23_settings.sql

-- ═══ 1. Kolum is_critical (belum wujud di prod) ═══
ALTER TABLE psy_vitals ADD COLUMN IF NOT EXISTS is_critical BOOLEAN NOT NULL DEFAULT false;
CREATE INDEX IF NOT EXISTS idx_psy_vitals_abnormal ON psy_vitals(is_abnormal) WHERE is_abnormal = true;

-- ═══ 2. Seed ambang — normal_* sepadan angka client-side sedia ada (tiada perubahan
-- tingkah laku is_abnormal semasa cutover); critical_* kosong sehingga doktor sahkan ═══
INSERT INTO psy_settings (key, value) VALUES
  ('vitals_thresholds', '{
    "bp_systolic":      {"normal_min": 90,   "normal_max": 129,  "critical_min": null, "critical_max": null},
    "bp_diastolic":      {"normal_min": 60,   "normal_max": 84,   "critical_min": null, "critical_max": null},
    "heart_rate":        {"normal_min": 60,   "normal_max": 100,  "critical_min": null, "critical_max": null},
    "temperature":       {"normal_min": 36.1, "normal_max": 37.2, "critical_min": null, "critical_max": null},
    "spo2":              {"normal_min": 95,   "normal_max": null, "critical_min": null, "critical_max": null},
    "respiratory_rate":  {"normal_min": 12,   "normal_max": 20,   "critical_min": null, "critical_max": null}
  }'::jsonb)
ON CONFLICT (key) DO NOTHING;

-- ═══ 3. fn_vitals_compute_critical() — config-driven, exception-safe sepenuhnya
-- (BEFORE trigger; kalau throw, ia boleh sekat SEMUA simpanan vitals klinik) ═══
CREATE OR REPLACE FUNCTION fn_vitals_compute_critical()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
  v_cfg JSONB;
  v_bp_sys JSONB; v_bp_dia JSONB; v_hr JSONB; v_temp JSONB; v_spo2 JSONB; v_rr JSONB;
BEGIN
  NEW.is_critical := false;

  BEGIN
    SELECT value INTO v_cfg FROM psy_settings WHERE key = 'vitals_thresholds';
  EXCEPTION WHEN OTHERS THEN
    v_cfg := NULL;
  END;

  IF v_cfg IS NULL THEN
    RETURN NEW;
  END IF;

  BEGIN
    v_bp_sys := v_cfg -> 'bp_systolic';
    v_bp_dia := v_cfg -> 'bp_diastolic';
    v_hr     := v_cfg -> 'heart_rate';
    v_temp   := v_cfg -> 'temperature';
    v_spo2   := v_cfg -> 'spo2';
    v_rr     := v_cfg -> 'respiratory_rate';

    NEW.is_critical := (
      (NEW.bp_systolic IS NOT NULL AND v_bp_sys IS NOT NULL AND (
        (v_bp_sys->>'critical_min' IS NOT NULL AND NEW.bp_systolic < (v_bp_sys->>'critical_min')::numeric) OR
        (v_bp_sys->>'critical_max' IS NOT NULL AND NEW.bp_systolic >= (v_bp_sys->>'critical_max')::numeric)
      )) OR
      (NEW.bp_diastolic IS NOT NULL AND v_bp_dia IS NOT NULL AND (
        (v_bp_dia->>'critical_min' IS NOT NULL AND NEW.bp_diastolic < (v_bp_dia->>'critical_min')::numeric) OR
        (v_bp_dia->>'critical_max' IS NOT NULL AND NEW.bp_diastolic >= (v_bp_dia->>'critical_max')::numeric)
      )) OR
      (NEW.heart_rate IS NOT NULL AND v_hr IS NOT NULL AND (
        (v_hr->>'critical_min' IS NOT NULL AND NEW.heart_rate < (v_hr->>'critical_min')::numeric) OR
        (v_hr->>'critical_max' IS NOT NULL AND NEW.heart_rate > (v_hr->>'critical_max')::numeric)
      )) OR
      (NEW.temperature IS NOT NULL AND v_temp IS NOT NULL AND (
        (v_temp->>'critical_min' IS NOT NULL AND NEW.temperature < (v_temp->>'critical_min')::numeric) OR
        (v_temp->>'critical_max' IS NOT NULL AND NEW.temperature >= (v_temp->>'critical_max')::numeric)
      )) OR
      (NEW.spo2 IS NOT NULL AND v_spo2 IS NOT NULL AND
        (v_spo2->>'critical_min' IS NOT NULL AND NEW.spo2 < (v_spo2->>'critical_min')::numeric)
      ) OR
      (NEW.respiratory_rate IS NOT NULL AND v_rr IS NOT NULL AND (
        (v_rr->>'critical_min' IS NOT NULL AND NEW.respiratory_rate < (v_rr->>'critical_min')::numeric) OR
        (v_rr->>'critical_max' IS NOT NULL AND NEW.respiratory_rate > (v_rr->>'critical_max')::numeric)
      ))
    );
  EXCEPTION WHEN OTHERS THEN
    RAISE LOG 'fn_vitals_compute_critical: %', SQLERRM;
    NEW.is_critical := false;
  END;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_vitals_compute_critical ON psy_vitals;
CREATE TRIGGER trg_vitals_compute_critical
  BEFORE INSERT OR UPDATE ON psy_vitals
  FOR EACH ROW EXECUTE FUNCTION fn_vitals_compute_critical();

-- TIADA backfill is_critical — config critical_* kosong (NULL) secara default, jadi
-- backfill akan sentiasa false utk semua rekod sedia ada sehingga doktor isi ambang.

COMMENT ON COLUMN psy_vitals.is_critical IS
  'Bacaan kritikal (bahaya klinikal, perlu tindakan segera) — dikira SERVER-SIDE sahaja '
  '(trg_vitals_compute_critical), staf TAK boleh override/uncheck macam is_abnormal. Bila true, '
  'trg_vitals_notify_emergency (18_notifications_automations.sql) auto-cipta/kemaskini kes di '
  'psy_emergency_alerts — Red Emergency Protocol. Ambang dibaca dari psy_settings.vitals_thresholds '
  '(diedit oleh super_admin/doktor di tetapan.html) — kosong (NULL) = automasi TAK aktif utk vital tu.';


-- ═════════════════════════════════════════════════════════════════
-- BUNDLE: 20260930_pakej_report_completion_rbac.sql
-- ═════════════════════════════════════════════════════════════════
-- Audit management batch 3 (30 Sept 2026) — Laporan Siap/Berhenti/Meninggal
-- per-pakej (pakej-laporan.html + pakej-report.html) kini guna outcome_status
-- sebenar (bukan status cetek). Coach & Doktor diberi akses 'view' modul
-- package/pakej_laporan (sebelum ni tiada langsung, tersekat RBAC).
-- Rujuk: database/schema/03_rbac_security.sql

INSERT INTO psy_role_module_actions (role_code, module_code, action_code)
SELECT 'doctor', m.code, 'view'
FROM (VALUES ('package'), ('pakej_laporan')) AS m(code)
ON CONFLICT DO NOTHING;

INSERT INTO psy_role_module_actions (role_code, module_code, action_code)
SELECT 'coach', m.code, 'view'
FROM (VALUES ('package'), ('pakej_laporan')) AS m(code)
ON CONFLICT DO NOTHING;


-- ═════════════════════════════════════════════════════════════════
-- BUNDLE: 20260930b_legacy_pending_combined.sql
-- ═════════════════════════════════════════════════════════════════
-- ═══════════════════════════════════════════════════════════════════
-- GABUNGAN MIGRATION TERTUNGGAK (batch lama, 1 Ogos - 24 Sept 2026)
-- Digabung 2026-09-30 drpd 30 fail berasingan (senarai di bawah), yang
-- kekal berdiri sendiri (belum masuk 20260901_combined_migrations.sql
-- atau 20260925_combined_pending.sql). Semua idempotent (selamat run
-- berulang). Susunan KEKAL ikut tarikh asal (penting — psy_hk1_slot_config
-- dicipta 24 Ogos lalu dibuang balik hari sama, sama pola macam Purchase
-- Orders di 20260901_combined_migrations.sql).
-- ═══════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────────
-- FAIL: 20260801_dna_sample_appointment.sql
-- ─────────────────────────────────────────────────────────────────
-- Jadual Pengambilan Sampel DNA (Step 1 dna-test.html) — reuse psy_appointments
-- (macam Step 5 Consultation) + peringatan WA sehari sebelum via event-reminders.
-- Rujuk: database/schema/26_dna_test.sql, database/schema/18_notifications_automations.sql

ALTER TABLE psy_dna_test_process
  ADD COLUMN IF NOT EXISTS sample_appointment_id UUID REFERENCES psy_appointments(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS sample_reminder_sent_at TIMESTAMPTZ;

-- Seed config Mesej Automatik (dna_sample_reminder) — is_active = false, staff semak &
-- aktifkan sendiri di halaman Tetapan Mesej Automatik.
insert into psy_auto_messages
  (key, name, description, channel, trigger_type, message_template,
   placeholders, channels, rule, category, language, is_active)
values
  ('dna_sample_reminder',
   'Peringatan Pengambilan Sampel DNA',
   'Sehari sebelum tarikh janji temu pengambilan sampel DNA Test, hantar WA kpd pesakit — nyatakan tarikh/masa & syarat persediaan (makan 2 jam sebelum, jangan makan/minum 30 minit sebelum).',
   'whatsapp', 'before_event',
   E'Salam {nama} 👋\n\nPeringatan: esok anda dijadualkan untuk *Pengambilan Sampel DNA Test* di klinik.\n\n📅 {tarikh_sample} · {masa_sample}\n\n⚠️ Sila patuhi sebelum ujian:\n• Pastikan anda telah makan sekurang-kurangnya 2 jam sebelum ujian.\n• Jangan makan atau minum sekurang-kurangnya 30 minit sebelum ujian.\n\nJumpa esok!\n\n— {nama_klinik}',
   '["{nama}","{tarikh_sample}","{masa_sample}","{nama_klinik}"]'::jsonb,
   '["whatsapp"]'::jsonb,
   '{"lead_days":1}'::jsonb,
   'dna_test', 'ms',
   false)
on conflict (key) do update set
  name             = excluded.name,
  description      = excluded.description,
  channel          = excluded.channel,
  trigger_type     = excluded.trigger_type,
  message_template = excluded.message_template,
  placeholders     = excluded.placeholders,
  channels         = excluded.channels,
  rule             = excluded.rule,
  category         = excluded.category,
  language         = excluded.language,
  updated_at       = now();


-- ─────────────────────────────────────────────────────────────────
-- FAIL: 20260803_points.sql
-- ─────────────────────────────────────────────────────────────────
-- Sistem Mata (points) — psy_points_ledger + psy_point_rewards + redeem_point_reward() RPC
-- + trigger 1 mata/hari Catatan Harian. Rujuk: database/schema/31_points.sql

CREATE TABLE IF NOT EXISTS psy_points_ledger (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id   UUID NOT NULL REFERENCES psy_patients(id) ON DELETE CASCADE,
  source_type  TEXT NOT NULL,
  source_ref   UUID,
  points       INT NOT NULL CHECK (points <> 0),
  note         TEXT,
  created_at   TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_psy_points_ledger_patient ON psy_points_ledger(patient_id, created_at);

ALTER TABLE psy_points_ledger ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Patients view own points" ON psy_points_ledger;
CREATE POLICY "Patients view own points" ON psy_points_ledger FOR SELECT
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Staff view all points" ON psy_points_ledger;
CREATE POLICY "Staff view all points" ON psy_points_ledger FOR SELECT
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

CREATE OR REPLACE VIEW psy_points_balance
  WITH (security_invoker = true) AS
  SELECT patient_id, COALESCE(SUM(points), 0)::INT AS balance
  FROM psy_points_ledger
  GROUP BY patient_id;

CREATE OR REPLACE FUNCTION trg_award_daily_checkin_point()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  INSERT INTO psy_points_ledger (patient_id, source_type, source_ref, points, note)
  VALUES (NEW.patient_id, 'daily_checkin', NEW.id, 1, 'Catatan Harian — ' || NEW.log_date);
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE LOG 'trg_award_daily_checkin_point: %', SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_award_daily_checkin_point ON psy_kepatuhan_log;
CREATE TRIGGER trg_award_daily_checkin_point
  AFTER INSERT ON psy_kepatuhan_log
  FOR EACH ROW EXECUTE FUNCTION trg_award_daily_checkin_point();

CREATE TABLE IF NOT EXISTS psy_point_rewards (
  id                          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name                        TEXT NOT NULL,
  description                 TEXT,
  points_cost                 INT NOT NULL CHECK (points_cost > 0),
  voucher_amount              NUMERIC(10,2) NOT NULL CHECK (voucher_amount > 0),
  max_redemptions_per_patient INT,
  is_active                   BOOLEAN NOT NULL DEFAULT true,
  created_by                  UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  created_at                  TIMESTAMPTZ DEFAULT now(),
  updated_at                  TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE psy_point_rewards ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone read point rewards" ON psy_point_rewards;
CREATE POLICY "Anyone read point rewards" ON psy_point_rewards FOR SELECT USING (true);

DROP POLICY IF EXISTS "Staff manage point rewards" ON psy_point_rewards;
CREATE POLICY "Staff manage point rewards" ON psy_point_rewards
  FOR ALL USING      (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
           WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

CREATE OR REPLACE FUNCTION redeem_point_reward(p_reward_id UUID)
RETURNS psy_vouchers
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_patient_id UUID;
  v_reward     psy_point_rewards%ROWTYPE;
  v_balance    INT;
  v_redeemed   INT;
  v_voucher    psy_vouchers%ROWTYPE;
BEGIN
  SELECT id INTO v_patient_id FROM psy_patients WHERE user_id = auth.uid() LIMIT 1;
  IF v_patient_id IS NULL THEN
    RAISE EXCEPTION 'Rekod pesakit tidak dijumpai.';
  END IF;

  SELECT * INTO v_reward FROM psy_point_rewards WHERE id = p_reward_id;
  IF v_reward.id IS NULL OR NOT v_reward.is_active THEN
    RAISE EXCEPTION 'Ganjaran ini tidak sah atau tidak lagi ditawarkan.';
  END IF;

  IF v_reward.max_redemptions_per_patient IS NOT NULL THEN
    SELECT COUNT(*) INTO v_redeemed FROM psy_points_ledger
      WHERE patient_id = v_patient_id AND source_type = 'reward_redeem' AND source_ref = v_reward.id;
    IF v_redeemed >= v_reward.max_redemptions_per_patient THEN
      RAISE EXCEPTION 'Anda telah mencapai had tukaran untuk ganjaran ini.';
    END IF;
  END IF;

  SELECT COALESCE(SUM(points), 0) INTO v_balance FROM psy_points_ledger WHERE patient_id = v_patient_id;
  IF v_balance < v_reward.points_cost THEN
    RAISE EXCEPTION 'Mata tidak mencukupi.';
  END IF;

  INSERT INTO psy_points_ledger (patient_id, source_type, source_ref, points, note)
  VALUES (v_patient_id, 'reward_redeem', v_reward.id, -v_reward.points_cost, 'Tukar: ' || v_reward.name);

  INSERT INTO psy_vouchers (patient_id, source_type, source_ref, amount, note)
  VALUES (v_patient_id, 'point_redeem', v_reward.id, v_reward.voucher_amount, 'Ditukar dari mata: ' || v_reward.name)
  RETURNING * INTO v_voucher;

  RETURN v_voucher;
END;
$$;

GRANT EXECUTE ON FUNCTION redeem_point_reward(UUID) TO authenticated;


-- ─────────────────────────────────────────────────────────────────
-- FAIL: 20260803_promo_claims.sql
-- ─────────────────────────────────────────────────────────────────
-- Voucher Wallet (claim kod promo) — psy_promo_claims + claim_promo_code() RPC
-- + extend trigger trg_promo_mark_used_on_payment (dari 20260803_promo_codes.sql).
-- Rujuk: database/schema/29_promo_codes.sql, database/schema/30_promo_claims.sql

ALTER TABLE psy_promo_codes
  ADD COLUMN IF NOT EXISTS wallet_validity_days INT;

CREATE TABLE IF NOT EXISTS psy_promo_claims (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id        UUID NOT NULL REFERENCES psy_patients(id) ON DELETE CASCADE,
  promo_id          UUID NOT NULL REFERENCES psy_promo_codes(id) ON DELETE CASCADE,
  code              TEXT NOT NULL,
  discount_type     TEXT NOT NULL,
  discount_value    NUMERIC(10,2) NOT NULL,
  min_subtotal      NUMERIC(10,2) NOT NULL DEFAULT 0,
  claimed_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at        TIMESTAMPTZ,
  status            TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active','used')),
  used_at           TIMESTAMPTZ,
  used_in_payment_id UUID REFERENCES psy_payments(id) ON DELETE SET NULL,
  UNIQUE (promo_id, patient_id)
);

CREATE INDEX IF NOT EXISTS idx_psy_promo_claims_patient ON psy_promo_claims(patient_id, status);

ALTER TABLE psy_promo_claims ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Patients view own promo claims" ON psy_promo_claims;
CREATE POLICY "Patients view own promo claims" ON psy_promo_claims FOR SELECT
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Staff view all promo claims" ON psy_promo_claims;
CREATE POLICY "Staff view all promo claims" ON psy_promo_claims FOR SELECT
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- ──── claim_promo_code() ────
CREATE OR REPLACE FUNCTION claim_promo_code(p_code TEXT)
RETURNS psy_promo_claims
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_patient_id UUID;
  v_promo      psy_promo_codes%ROWTYPE;
  v_today      DATE := now()::date;
  v_expires_at TIMESTAMPTZ;
  v_claim      psy_promo_claims%ROWTYPE;
BEGIN
  SELECT id INTO v_patient_id FROM psy_patients WHERE user_id = auth.uid() LIMIT 1;
  IF v_patient_id IS NULL THEN
    RAISE EXCEPTION 'Rekod pesakit tidak dijumpai.';
  END IF;

  SELECT * INTO v_promo FROM psy_promo_codes WHERE code = upper(trim(p_code));
  IF v_promo.id IS NULL OR NOT v_promo.is_active THEN
    RAISE EXCEPTION 'Kod tidak sah atau telah luput.';
  END IF;
  IF v_promo.valid_from IS NOT NULL AND v_promo.valid_from > v_today THEN
    RAISE EXCEPTION 'Kod tidak sah atau telah luput.';
  END IF;
  IF v_promo.valid_until IS NOT NULL AND v_promo.valid_until < v_today THEN
    RAISE EXCEPTION 'Kod tidak sah atau telah luput.';
  END IF;
  IF v_promo.max_uses IS NOT NULL AND v_promo.used_count >= v_promo.max_uses THEN
    RAISE EXCEPTION 'Kod ini telah mencapai had penggunaan.';
  END IF;

  v_expires_at := CASE
    WHEN v_promo.valid_until IS NOT NULL THEN v_promo.valid_until::timestamptz + INTERVAL '1 day' - INTERVAL '1 second'
    WHEN v_promo.wallet_validity_days IS NOT NULL THEN now() + (v_promo.wallet_validity_days || ' days')::interval
    ELSE NULL
  END;

  BEGIN
    INSERT INTO psy_promo_claims (patient_id, promo_id, code, discount_type, discount_value, min_subtotal, expires_at)
    VALUES (v_patient_id, v_promo.id, v_promo.code, v_promo.discount_type, v_promo.discount_value, v_promo.min_subtotal, v_expires_at)
    RETURNING * INTO v_claim;
  EXCEPTION WHEN unique_violation THEN
    RAISE EXCEPTION 'Anda sudah menuntut kod ini.';
  END;

  RETURN v_claim;
END;
$$;

GRANT EXECUTE ON FUNCTION claim_promo_code(TEXT) TO authenticated;

-- ──── Extend trg_promo_mark_used_on_payment: tandakan claim wallet 'used' ────
CREATE OR REPLACE FUNCTION trg_promo_mark_used_on_payment()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_promo_id UUID;
  v_discount NUMERIC;
  v_patient_id UUID;
BEGIN
  IF NEW.status IS DISTINCT FROM 'completed' THEN RETURN NEW; END IF;
  IF TG_OP = 'UPDATE' AND OLD.status = 'completed' THEN RETURN NEW; END IF;

  v_promo_id := (NEW.intent ->> 'promoCodeId')::uuid;
  IF v_promo_id IS NULL THEN RETURN NEW; END IF;

  v_discount := COALESCE((NEW.intent ->> 'promoDiscount')::numeric, 0);
  v_patient_id := NEW.patient_id;
  IF v_patient_id IS NULL THEN RETURN NEW; END IF;

  INSERT INTO psy_promo_redemptions (promo_id, patient_id, payment_id, discount_amount)
  VALUES (v_promo_id, v_patient_id, NEW.id, v_discount);

  UPDATE psy_promo_codes SET used_count = used_count + 1, updated_at = now()
  WHERE id = v_promo_id;

  UPDATE psy_promo_claims SET status = 'used', used_at = now(), used_in_payment_id = NEW.id
  WHERE promo_id = v_promo_id AND patient_id = v_patient_id AND status = 'active';

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE LOG 'trg_promo_mark_used_on_payment: %', SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_promo_mark_used_on_payment ON psy_payments;
CREATE TRIGGER trg_promo_mark_used_on_payment
  AFTER INSERT OR UPDATE ON psy_payments
  FOR EACH ROW EXECUTE FUNCTION trg_promo_mark_used_on_payment();


-- ─────────────────────────────────────────────────────────────────
-- FAIL: 20260803_promo_codes.sql
-- ─────────────────────────────────────────────────────────────────
-- Kod Promo (kedai) — psy_promo_codes + psy_promo_redemptions + trigger redeem.
-- Rujuk: database/schema/29_promo_codes.sql (sumber kebenaran, sync manual ke sini).

-- ──── psy_promo_codes ────
CREATE TABLE IF NOT EXISTS psy_promo_codes (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code                  TEXT UNIQUE NOT NULL,
  description           TEXT,
  discount_type         TEXT NOT NULL CHECK (discount_type IN ('percent','fixed')),
  discount_value        NUMERIC(10,2) NOT NULL CHECK (discount_value > 0),
  min_subtotal          NUMERIC(10,2) NOT NULL DEFAULT 0,
  max_uses              INT,
  used_count            INT NOT NULL DEFAULT 0,
  max_uses_per_patient  INT NOT NULL DEFAULT 1,
  valid_from            DATE,
  valid_until           DATE,
  is_active             BOOLEAN NOT NULL DEFAULT true,
  created_by            UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  created_at            TIMESTAMPTZ DEFAULT now(),
  updated_at            TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_psy_promo_codes_code ON psy_promo_codes(code);

ALTER TABLE psy_promo_codes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone read promo codes" ON psy_promo_codes;
CREATE POLICY "Anyone read promo codes" ON psy_promo_codes FOR SELECT USING (true);

DROP POLICY IF EXISTS "Staff manage promo codes" ON psy_promo_codes;
CREATE POLICY "Staff manage promo codes" ON psy_promo_codes
  FOR ALL USING      (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
           WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- ──── psy_promo_redemptions ────
CREATE TABLE IF NOT EXISTS psy_promo_redemptions (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  promo_id         UUID NOT NULL REFERENCES psy_promo_codes(id) ON DELETE CASCADE,
  patient_id       UUID NOT NULL REFERENCES psy_patients(id) ON DELETE CASCADE,
  payment_id       UUID REFERENCES psy_payments(id) ON DELETE SET NULL,
  discount_amount  NUMERIC(10,2) NOT NULL,
  created_at       TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_psy_promo_redemptions_promo_patient
  ON psy_promo_redemptions(promo_id, patient_id);

ALTER TABLE psy_promo_redemptions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Patients view own promo redemptions" ON psy_promo_redemptions;
CREATE POLICY "Patients view own promo redemptions" ON psy_promo_redemptions FOR SELECT
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Staff view all promo redemptions" ON psy_promo_redemptions;
CREATE POLICY "Staff view all promo redemptions" ON psy_promo_redemptions FOR SELECT
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- ──── Redeem trigger (kunci penggunaan bila bayaran completed) ────
CREATE OR REPLACE FUNCTION trg_promo_mark_used_on_payment()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_promo_id UUID;
  v_discount NUMERIC;
  v_patient_id UUID;
BEGIN
  IF NEW.status IS DISTINCT FROM 'completed' THEN RETURN NEW; END IF;
  IF TG_OP = 'UPDATE' AND OLD.status = 'completed' THEN RETURN NEW; END IF;

  v_promo_id := (NEW.intent ->> 'promoCodeId')::uuid;
  IF v_promo_id IS NULL THEN RETURN NEW; END IF;

  v_discount := COALESCE((NEW.intent ->> 'promoDiscount')::numeric, 0);
  v_patient_id := NEW.patient_id;
  IF v_patient_id IS NULL THEN RETURN NEW; END IF;

  INSERT INTO psy_promo_redemptions (promo_id, patient_id, payment_id, discount_amount)
  VALUES (v_promo_id, v_patient_id, NEW.id, v_discount);

  UPDATE psy_promo_codes SET used_count = used_count + 1, updated_at = now()
  WHERE id = v_promo_id;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE LOG 'trg_promo_mark_used_on_payment: %', SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_promo_mark_used_on_payment ON psy_payments;
CREATE TRIGGER trg_promo_mark_used_on_payment
  AFTER INSERT OR UPDATE ON psy_payments
  FOR EACH ROW EXECUTE FUNCTION trg_promo_mark_used_on_payment();


-- ─────────────────────────────────────────────────────────────────
-- FAIL: 20260807_treatment_plans_unique_active.sql
-- ─────────────────────────────────────────────────────────────────
-- Jaringan keselamatan: satu pesakit tak boleh ada 2 plan AKTIF utk pakej (template) sama
-- serentak. Punca duplicate disahkan prod 7 Ogos (pesakit 234bb418..., pakej "Overhaul Body
-- Diamond Y1" — 3 baris dicipta dlm 44 saat): race condition dalam trigger
-- fn_auto_inactive_on_session_done (auto-aktif pakej sambungan/continuity bila plan lama
-- selesai) — INSERT guna NOT EXISTS semakan bukan-atom, boleh race bila >1 baris
-- psy_plan_weekly_progress ditanda hadir hampir serentak. Race sama juga wujud (secara
-- berasingan) dalam supabase/functions/payments-webhook (HitPay retry webhook) — dah dibetulkan
-- di kod, relevan utk testing (payments-webhook tak deploy ke prod lagi).
-- Rujuk: database/schema/07_treatment_plans.sql

-- 1) SEMAK DULU sebelum run bahagian 2 — kalau query ni pulangkan baris, ada pesakit LAIN
--    yang juga kena isu sama (>1 plan status='active' utk template sama). CREATE UNIQUE INDEX
--    di bawah akan GAGAL kalau data macam ni masih wujud — kena selesaikan dulu (guna butang
--    "🗑️ Padam" di Pakej & Sejarah utk buang duplicate, atau tukar status yang tak patut aktif).
--
-- SELECT patient_id, template, count(*), array_agg(id) AS plan_ids
-- FROM psy_treatment_plans
-- WHERE status = 'active'
-- GROUP BY patient_id, template
-- HAVING count(*) > 1;

-- 2) Constraint sebenar — run bila (1) di atas dah bersih (tiada baris pulang).
CREATE UNIQUE INDEX IF NOT EXISTS uq_treatment_plans_active_patient_template
  ON psy_treatment_plans(patient_id, template) WHERE status = 'active';

-- 3) Trigger fn_auto_inactive_on_session_done — tangkap unique_violation supaya UPDATE
--    "tandakan hadir" yang mencetuskan trigger ni tak gagal walaupun panggilan/trigger lain
--    (concurrent) menang race dulu (unique index di atas yang jadi jaringan keselamatan sebenar).
CREATE OR REPLACE FUNCTION fn_auto_inactive_on_session_done()
RETURNS TRIGGER AS $$
DECLARE
  v_patient_id    UUID;
  v_pstatus       TEXT;
  v_pkg_expired   BOOLEAN;
  v_all_done      BOOLEAN;
  v_has_core      BOOLEAN;
  v_next_pkg      TEXT;
  v_next_name     TEXT;
BEGIN
  IF NEW.status NOT IN ('hadir','consultation_done') THEN
    RETURN NEW;
  END IF;
  IF TG_OP = 'UPDATE' AND OLD.status = NEW.status THEN
    RETURN NEW;
  END IF;

  SELECT patient_id INTO v_patient_id FROM psy_treatment_plans WHERE id = NEW.plan_id;
  IF v_patient_id IS NULL THEN RETURN NEW; END IF;

  -- v_all_done: tiada sesi teras belum selesai + tiada minggu continuity BERBAYAR belum selesai.
  -- Minggu continuity ditanda extension_for_week = 0; absen (extension_for_week >= 1) tak menghalang.
  SELECT
    EXISTS (SELECT 1 FROM psy_plan_weekly_progress
            WHERE plan_id = NEW.plan_id AND COALESCE(is_extension,false) = false),
    NOT EXISTS (
      SELECT 1 FROM psy_plan_weekly_progress
      WHERE plan_id = NEW.plan_id
        AND status NOT IN ('hadir','consultation_done')
        AND (
          COALESCE(is_extension,false) = false
          OR (COALESCE(extension_for_week, -1) = 0 AND status <> 'extension_pending_payment')
        )
    )
    INTO v_has_core, v_all_done;

  SELECT status, (package_expires_at IS NOT NULL AND package_expires_at < now()),
         next_package_id, next_package_name
    INTO v_pstatus, v_pkg_expired, v_next_pkg, v_next_name
    FROM psy_patients WHERE id = v_patient_id;

  IF v_pstatus IN ('inactive','archived','deceased','deleted') THEN
    RETURN NEW;
  END IF;

  IF (v_has_core AND v_all_done) OR v_pkg_expired THEN
    -- Pelan lama SELESAI (kekal di History — tiada data dipadam).
    UPDATE psy_treatment_plans SET status = 'completed'
      WHERE id = NEW.plan_id AND status <> 'completed';

    IF v_next_pkg IS NOT NULL AND v_next_pkg <> '' THEN
      -- ── Ada pakej sambungan beratur → AUTO-AKTIF, pesakit KEKAL aktif ──
      UPDATE psy_patients
        SET active_package_id    = v_next_pkg,
            active_package_name  = COALESCE(v_next_name, active_package_name),
            package_purchased_at = now(),
            package_expires_at   = now() + interval '3 months',
            next_package_id      = NULL,
            next_package_name    = NULL,
            status               = 'active'
        WHERE id = v_patient_id;

      -- Purchase beratur → aktif (tempoh 3 bulan bermula dari pengaktifan).
      UPDATE psy_package_purchases
        SET status = 'active', expires_at = now() + interval '3 months'
        WHERE patient_id = v_patient_id AND package_id = v_next_pkg AND status = 'queued';

      -- Cipta pelan baru dari pakej sambungan (jika belum wujud). Baris mingguan dijana
      -- kemudian bila pesakit set jadual (sama seperti pakej baru biasa).
      -- NOT EXISTS di bawah cuma "best-effort" — boleh race bila >1 baris psy_plan_weekly_progress
      -- ditanda hadir hampir serentak (setiap satu cetus trigger ni secara berasingan).
      -- uq_treatment_plans_active_patient_template (unique index) ialah jaringan keselamatan
      -- SEBENAR; tangkap unique_violation di sini supaya UPDATE hadir yang mencetuskan trigger
      -- ni tak gagal walaupun panggilan/trigger lain menang race dulu (punca duplicate plan
      -- prod 7 Ogos — 3 baris "Overhaul Body Diamond Y1" dicipta dlm 44 saat utk 1 pesakit).
      BEGIN
        INSERT INTO psy_treatment_plans
          (patient_id, name, template, duration_unit, duration_weeks, current_week, coaching_schedule, status)
        SELECT v_patient_id, COALESCE(pk.name,'Pakej') || ' Treatment Plan', pk.package_id,
               COALESCE(pk.duration_unit,'week'), COALESCE(pk.duration_weeks,12), 1,
               COALESCE(pk.coaching_schedule, '[]'::jsonb), 'active'
        FROM psy_packages pk
        WHERE pk.package_id = v_next_pkg
          AND NOT EXISTS (
            SELECT 1 FROM psy_treatment_plans
            WHERE patient_id = v_patient_id AND template = v_next_pkg AND status = 'active'
          );
      EXCEPTION WHEN unique_violation THEN
        NULL; -- plan aktif utk pakej sambungan ni dah dicipta oleh panggilan serentak — abaikan.
      END;
    ELSE
      -- ── Tiada sambungan → pesakit inactive + outcome completed ──
      UPDATE psy_patients
        SET status = 'inactive',
            outcome_status = CASE WHEN outcome_status IS NULL OR outcome_status = ''
                                  THEN 'completed' ELSE outcome_status END,
            outcome_status_at = CASE WHEN outcome_status IS NULL OR outcome_status = ''
                                     THEN now() ELSE outcome_status_at END
        WHERE id = v_patient_id;
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
-- Trigger trg_auto_inactive sedia ada sudah rujuk fungsi ni — tiada perlu DROP/CREATE semula.


-- ─────────────────────────────────────────────────────────────────
-- FAIL: 20260813_installment_checkpoints.sql
-- ─────────────────────────────────────────────────────────────────
-- ═══════════════════════════════════════════════════════════════════
-- Bayaran Ansuran — ganti model "slot ansuran bersaiz tetap" (20260813_
-- installment_payments.sql) dengan model checkpoint kumulatif custom:
-- pesakit bayar apa-apa amount bila-bila selepas deposit, wajib jumlah
-- TERKUMPUL cecah target tiap checkpoint (bulan + jumlah kumulatif).
-- ═══════════════════════════════════════════════════════════════════

-- ──── psy_kob_installments — buang (ganti psy_kob_installment_checkpoints) ────
-- Jadual kosong/tak digunakan lagi (fitur baru dilancar, belum ada data sebenar).
DROP TABLE IF EXISTS psy_kob_installments;

-- ──── psy_packages — deposit + jadual checkpoint (ganti installment_count) ────
ALTER TABLE psy_packages DROP CONSTRAINT IF EXISTS psy_packages_installment_count_check;
ALTER TABLE psy_packages DROP COLUMN IF EXISTS installment_count;
ALTER TABLE psy_packages
  ADD COLUMN IF NOT EXISTS installment_deposit_amount NUMERIC(10,2),
  ADD COLUMN IF NOT EXISTS installment_checkpoints JSONB DEFAULT '[]';

-- ──── psy_kob_installment_checkpoints ────
CREATE TABLE IF NOT EXISTS psy_kob_installment_checkpoints (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  kob_session_id    UUID NOT NULL REFERENCES psy_kob_sessions(id) ON DELETE CASCADE,
  patient_id        UUID NOT NULL REFERENCES psy_patients(id) ON DELETE CASCADE,
  seq               INT NOT NULL,
  month_offset      INT NOT NULL,
  due_date          DATE NOT NULL,
  target_cumulative NUMERIC(10,2) NOT NULL,
  status            TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','met','overdue')),
  met_at            TIMESTAMPTZ,
  created_at        TIMESTAMPTZ DEFAULT now(),
  CONSTRAINT psy_kob_installment_checkpoints_unique_seq UNIQUE (kob_session_id, seq)
);

CREATE INDEX IF NOT EXISTS idx_kob_checkpoints_session ON psy_kob_installment_checkpoints(kob_session_id);
CREATE INDEX IF NOT EXISTS idx_kob_checkpoints_patient ON psy_kob_installment_checkpoints(patient_id, status);
CREATE INDEX IF NOT EXISTS idx_kob_checkpoints_overdue ON psy_kob_installment_checkpoints(due_date) WHERE status = 'pending';

ALTER TABLE psy_kob_installment_checkpoints ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Patient read own checkpoints" ON psy_kob_installment_checkpoints;
CREATE POLICY "Patient read own checkpoints" ON psy_kob_installment_checkpoints FOR SELECT
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Staff manage checkpoints" ON psy_kob_installment_checkpoints;
CREATE POLICY "Staff manage checkpoints" ON psy_kob_installment_checkpoints FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- ──── psy_auto_messages — kemas kini templat WA ansuran tertunggak (placeholder baru) ────
insert into psy_auto_messages
  (key, name, description, channel, trigger_type, message_template,
   placeholders, channels, category, language, is_active)
values
  ('installment_overdue',
   'Ansuran Pakej Tertunggak',
   'Bila jumlah terkumpul pesakit tak cecah target checkpoint ansuran menjelang tarikh due, hantar WA + sekat tempahan sesi baru sehingga bayaran diselesaikan.',
   'whatsapp', 'installment_overdue',
   E'Salam {nama} 👋\n\nAnsuran pakej rawatan anda (checkpoint Bulan {bulan}) tertunggak sejak {tarikh_due}. Jumlah wajib terkumpul: RM {jumlah} — baki RM {baki} lagi.\n\nTempahan sesi baru disekat buat sementara waktu sehingga bayaran diselesaikan. Sila hubungi pusat rawatan untuk bantuan.\n\n— {nama_klinik}',
   '["{nama}","{bulan}","{jumlah}","{baki}","{tarikh_due}","{nama_klinik}"]'::jsonb,
   '["whatsapp"]'::jsonb,
   'pembayaran', 'ms',
   false)
on conflict (key) do update set
  name             = excluded.name,
  description      = excluded.description,
  channel          = excluded.channel,
  trigger_type     = excluded.trigger_type,
  message_template = excluded.message_template,
  placeholders     = excluded.placeholders,
  channels         = excluded.channels,
  category         = excluded.category,
  language         = excluded.language,
  updated_at       = now();


-- ─────────────────────────────────────────────────────────────────
-- FAIL: 20260813_installment_payments.sql
-- ─────────────────────────────────────────────────────────────────
-- ═══════════════════════════════════════════════════════════════════
-- Bayaran Ansuran (Pelan Pelaburan Ansuran) — pakej, jadual ansuran,
-- sekatan tempahan sesi bila tertunggak. Turut bawa naik perubahan
-- schema/ WIP sedia ada yang belum ada migration (Bayaran Manual
-- kob-detail.html — invoice_number/receipt_url, postcode).
-- ═══════════════════════════════════════════════════════════════════

-- ──── psy_payments — bayaran manual (invois + resit) ────
ALTER TABLE psy_payments
  ADD COLUMN IF NOT EXISTS invoice_number TEXT,
  ADD COLUMN IF NOT EXISTS receipt_url TEXT;

-- ──── psy_patients — alamat: poskod berasingan ────
ALTER TABLE psy_patients
  ADD COLUMN IF NOT EXISTS postcode TEXT;

-- ──── psy_packages — konfigurasi ansuran per pakej ────
ALTER TABLE psy_packages
  ADD COLUMN IF NOT EXISTS installment_allowed BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS installment_count INT;

ALTER TABLE psy_packages DROP CONSTRAINT IF EXISTS psy_packages_installment_count_check;
ALTER TABLE psy_packages
  ADD CONSTRAINT psy_packages_installment_count_check
  CHECK (installment_count IS NULL OR installment_count BETWEEN 2 AND 12);

-- ──── psy_patients — sekatan tempahan sesi ────
ALTER TABLE psy_patients
  ADD COLUMN IF NOT EXISTS booking_blocked BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS booking_blocked_reason TEXT,
  ADD COLUMN IF NOT EXISTS booking_blocked_since TIMESTAMPTZ;

-- ──── psy_kob_sessions — mod bayaran pakej ────
ALTER TABLE psy_kob_sessions
  ADD COLUMN IF NOT EXISTS package_payment_mode TEXT;

ALTER TABLE psy_kob_sessions DROP CONSTRAINT IF EXISTS psy_kob_sessions_package_payment_mode_check;
ALTER TABLE psy_kob_sessions
  ADD CONSTRAINT psy_kob_sessions_package_payment_mode_check
  CHECK (package_payment_mode IN ('full','installment'));

-- ──── psy_kob_installments — jadual ansuran ────
CREATE TABLE IF NOT EXISTS psy_kob_installments (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  kob_session_id   UUID NOT NULL REFERENCES psy_kob_sessions(id) ON DELETE CASCADE,
  patient_id       UUID NOT NULL REFERENCES psy_patients(id) ON DELETE CASCADE,
  seq              INT NOT NULL,
  due_date         DATE NOT NULL,
  amount           NUMERIC(10,2) NOT NULL,
  status           TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','paid','overdue')),
  paid_payment_id  UUID REFERENCES psy_payments(id) ON DELETE SET NULL,
  paid_at          TIMESTAMPTZ,
  created_at       TIMESTAMPTZ DEFAULT now(),
  CONSTRAINT psy_kob_installments_unique_seq UNIQUE (kob_session_id, seq)
);

CREATE INDEX IF NOT EXISTS idx_kob_installments_session ON psy_kob_installments(kob_session_id);
CREATE INDEX IF NOT EXISTS idx_kob_installments_patient ON psy_kob_installments(patient_id, status);
CREATE INDEX IF NOT EXISTS idx_kob_installments_overdue ON psy_kob_installments(due_date) WHERE status = 'pending';

ALTER TABLE psy_kob_installments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Patient read own installments" ON psy_kob_installments;
CREATE POLICY "Patient read own installments" ON psy_kob_installments FOR SELECT
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Staff manage installments" ON psy_kob_installments;
CREATE POLICY "Staff manage installments" ON psy_kob_installments FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- ──── psy_kob_sessions.package_payment_status — tambah 'declined' (kalau belum ada) ────
ALTER TABLE psy_kob_sessions DROP CONSTRAINT IF EXISTS psy_kob_sessions_package_payment_status_check;
ALTER TABLE psy_kob_sessions
  ADD CONSTRAINT psy_kob_sessions_package_payment_status_check
  CHECK (package_payment_status IN ('pending','partial','paid','skipped','declined','na'));

-- ──── psy_auto_messages — templat WA ansuran tertunggak (dikendalikan runInstallmentOverdueCheck di event-reminders) ────
insert into psy_auto_messages
  (key, name, description, channel, trigger_type, message_template,
   placeholders, channels, category, language, is_active)
values
  ('installment_overdue',
   'Ansuran Pakej Tertunggak',
   'Bila ansuran pakej pesakit lepas tarikh due & belum dibayar, hantar WA + sekat tempahan sesi baru sehingga bayaran diselesaikan.',
   'whatsapp', 'installment_overdue',
   E'Salam {nama} 👋\n\nAnsuran {seq} (RM {jumlah}) untuk pakej rawatan anda tertunggak sejak {tarikh_due}.\n\nTempahan sesi baru disekat buat sementara waktu sehingga bayaran diselesaikan. Sila hubungi pusat rawatan untuk bantuan.\n\n— {nama_klinik}',
   '["{nama}","{seq}","{jumlah}","{tarikh_due}","{nama_klinik}"]'::jsonb,
   '["whatsapp"]'::jsonb,
   'pembayaran', 'ms',
   false)
on conflict (key) do update set
  name             = excluded.name,
  description      = excluded.description,
  channel          = excluded.channel,
  trigger_type     = excluded.trigger_type,
  message_template = excluded.message_template,
  placeholders     = excluded.placeholders,
  channels         = excluded.channels,
  category         = excluded.category,
  language         = excluded.language,
  updated_at       = now();


-- ─────────────────────────────────────────────────────────────────
-- FAIL: 20260820_referral_session_type.sql
-- ─────────────────────────────────────────────────────────────────
-- Generalize Sesi 1:1 (dulu Hakeema sahaja) kepada 3 jenis: Hakeema / Hakeem / Dr Session.
-- Ditanda terus sebagai checkbox ad-hoc di plan-week.html (bukan lagi pra-set di pakej-edit.html).

ALTER TABLE psy_clinical_referrals
  ADD COLUMN IF NOT EXISTS session_type TEXT CHECK (session_type IN ('hakeema','hakeem','dr'));

-- Rekod plan_1on1 sedia ada semuanya Hakeema (satu-satunya jenis sebelum ini).
UPDATE psy_clinical_referrals SET session_type = 'hakeema'
  WHERE source = 'plan_1on1' AND session_type IS NULL;

DROP INDEX IF EXISTS uq_psy_clinical_referrals_plan_1on1;
CREATE UNIQUE INDEX IF NOT EXISTS uq_psy_clinical_referrals_plan_1on1
  ON psy_clinical_referrals(plan_id, week_number, session_type) WHERE source = 'plan_1on1';


-- ─────────────────────────────────────────────────────────────────
-- FAIL: 20260824_hk1_slot_config.sql
-- ─────────────────────────────────────────────────────────────────
-- Konfig slot Sesi 1:1 (Hakeema/Hakeem/Dr) — hari beroperasi + jam pagi/petang + tempoh slot.
-- Baris tunggal (singleton, id=1). Diurus di kob-slots.html ("C. Slot Sesi 1:1"), dibaca
-- oleh shared/hk1.js (hk1GetSlots()) di sesi-1on1-form.html.
-- Jadual sendiri (bukan psy_settings) sebab psy_settings RLS kunci tulis kpd super_admin
-- sahaja — Sesi 1:1 config ni sepatutnya boleh diubah SEMUA staff (bukan super_admin sahaja).

CREATE TABLE IF NOT EXISTS psy_hk1_slot_config (
  id                     INT PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  days                   INT[] NOT NULL DEFAULT '{0,3,4,5,6}',
  pagi_start             TIME NOT NULL DEFAULT '09:00',
  pagi_end               TIME NOT NULL DEFAULT '12:00',
  petang_start           TIME NOT NULL DEFAULT '14:00',
  petang_end             TIME NOT NULL DEFAULT '17:00',
  slot_duration_minutes  INT NOT NULL DEFAULT 30,
  updated_at             TIMESTAMPTZ DEFAULT now(),
  updated_by             UUID REFERENCES psy_profiles(id) ON DELETE SET NULL
);

INSERT INTO psy_hk1_slot_config (id) VALUES (1) ON CONFLICT (id) DO NOTHING;

ALTER TABLE psy_hk1_slot_config ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff read hk1 slot config" ON psy_hk1_slot_config;
CREATE POLICY "Staff read hk1 slot config" ON psy_hk1_slot_config
  FOR SELECT USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "Staff manage hk1 slot config" ON psy_hk1_slot_config;
CREATE POLICY "Staff manage hk1 slot config" ON psy_hk1_slot_config FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));


-- ─────────────────────────────────────────────────────────────────
-- FAIL: 20260824_installment_reminder.sql
-- ─────────────────────────────────────────────────────────────────
-- Peringatan Ansuran Akan Tamat Tempoh (installment_reminder) — lihat
-- database/schema/09_kob.sql & database/schema/18_notifications_automations.sql
-- utk versi sumber kebenaran + nota lengkap.

ALTER TABLE psy_kob_installment_checkpoints
  ADD COLUMN IF NOT EXISTS installment_reminder_sent_at TIMESTAMPTZ;

insert into psy_auto_messages
  (key, name, description, channel, trigger_type, message_template,
   placeholders, channels, rule, category, language, is_active)
values
  ('installment_reminder',
   'Peringatan Ansuran Akan Tamat Tempoh',
   'Sebelum checkpoint ansuran KOB jatuh tempoh (rule.lead_days hari, default 3), hantar WA kpd pesakit dengan pautan bayaran HitPay — dijana automatik.',
   'whatsapp', 'installment_reminder',
   E'Salam {nama} 👋\n\nPeringatan mesra: ansuran *{ansuran}* pakej rawatan anda (RM {jumlah}) akan tamat tempoh pada *{tarikh_due}*.\n\nSila selesaikan bayaran melalui pautan selamat:\n{pautan}\n\nTerima kasih — ISW',
   '["{nama}","{ansuran}","{jumlah}","{tarikh_due}","{pautan}"]'::jsonb,
   '["whatsapp"]'::jsonb,
   '{"lead_days":3}'::jsonb,
   'pembayaran', 'ms',
   false)
on conflict (key) do update set
  name             = excluded.name,
  description      = excluded.description,
  channel          = excluded.channel,
  trigger_type     = excluded.trigger_type,
  message_template = excluded.message_template,
  placeholders     = excluded.placeholders,
  channels         = excluded.channels,
  rule             = excluded.rule,
  category         = excluded.category,
  language         = excluded.language,
  updated_at       = now();


-- ─────────────────────────────────────────────────────────────────
-- FAIL: 20260824b_hk1_slot_as_kob_type.sql
-- ─────────────────────────────────────────────────────────────────
-- Rombak semula: Slot Sesi 1:1 (Hakeema/Hakeem/Dr) guna model SAMA macam Slot KOB/Rawatan
-- (jadual baris-per-blok + hari ON/OFF), bukan model generator pagi/petang+tempoh — user
-- rasa model generator tu mengelirukan ("apa maksud pagi mula pagi akhir ni susah la").
-- Buang jadual singleton psy_hk1_slot_config (baru RUN sekali, tak sempat dipakai sesiapa),
-- tambah 'sesi_1on1' sbg slot_type ketiga pada psy_kob_slot_config sedia ada (reuse penuh
-- UI+logik "+ Tambah Slot"/toggle ON-OFF/edit/padam kob-slots.html — cuma parameterized ikut
-- type, tiada perubahan besar diperlukan pada jadual/RLS sedia ada).

DROP TABLE IF EXISTS psy_hk1_slot_config;

ALTER TABLE psy_kob_slot_config DROP CONSTRAINT IF EXISTS psy_kob_slot_config_slot_type_check;
ALTER TABLE psy_kob_slot_config ADD CONSTRAINT psy_kob_slot_config_slot_type_check
  CHECK (slot_type IN ('kob', 'rawatan', 'sesi_1on1'));

-- Seed lalai — 2 blok (pagi/petang) x hari Rabu-Ahad, sama pattern KOB/Rawatan.
INSERT INTO psy_kob_slot_config (slot_type, day_of_week, slot_start, slot_end, label, sort_order, is_active)
SELECT
  'sesi_1on1',
  d.day_of_week,
  s.slot_start::time,
  s.slot_end::time,
  s.label,
  s.sort_order,
  true
FROM
  (VALUES (3), (4), (5), (6), (0)) AS d(day_of_week),
  (VALUES
    ('09:00', '12:00', '9-12 pg',  1),
    ('14:00', '17:00', '2-5 ptg',  2)
  ) AS s(slot_start, slot_end, label, sort_order)
ON CONFLICT ON CONSTRAINT psy_kob_slot_config_unique DO NOTHING;


-- ─────────────────────────────────────────────────────────────────
-- FAIL: 20260826_extension_price_per_session.sql
-- ─────────────────────────────────────────────────────────────────
-- Kolum harga berasingan untuk "Tambah Sesi" (1 sesi tunggal pada minggu sedia
-- ada, cth patient-hub.html) — sebelum ni dikira secara automatik sebagai
-- extension_price_per_week / 2, tiada tempat staff boleh tetapkan sendiri.
-- Lihat database/schema/05_packages.sql utk versi sumber kebenaran + nota lengkap.

ALTER TABLE psy_packages
  ADD COLUMN IF NOT EXISTS extension_price_per_session NUMERIC(10,2) DEFAULT 25;


-- ─────────────────────────────────────────────────────────────────
-- FAIL: 20260826_package_rata_4tier_pricing.sql
-- ─────────────────────────────────────────────────────────────────
-- Model ansuran RATA (deposit + tempoh(bulan) + bayaran bulanan tetap) & harga
-- 4-tier KOB (Now/Today) — lihat database/schema/05_packages.sql utk versi
-- sumber kebenaran + nota lengkap.
--
-- Kolum ni dah lama wujud dalam CREATE TABLE psy_packages di schema/, tapi
-- CREATE TABLE IF NOT EXISTS tak buat apa-apa bila jadual dah wujud — sebab
-- tu tak pernah "sampai" ke PRODUCTION walaupun testing dah jalan lama
-- (sama corak dgn gotcha status/internal_notes/automation_flags/access_flags/
-- supplies/addons 14 Ogos). Ni yang buat dropdown "Cadangan Pakej Rawatan" di
-- kob-detail.html kosong di prod — SELECT eksplisit kolum ni gagal (PostgREST
-- 400 kolum tak wujud), data jadi null → cache pakej kosong, senyap tanpa error
-- dipaparkan.

ALTER TABLE psy_packages
  ADD COLUMN IF NOT EXISTS installment_duration_months INT,
  ADD COLUMN IF NOT EXISTS installment_monthly_amount NUMERIC(10,2),
  ADD COLUMN IF NOT EXISTS nilai_program NUMERIC(10,2),
  ADD COLUMN IF NOT EXISTS harga_asal NUMERIC(10,2),
  ADD COLUMN IF NOT EXISTS today_price NUMERIC(10,2),
  ADD COLUMN IF NOT EXISTS today_installment_deposit_amount NUMERIC(10,2),
  ADD COLUMN IF NOT EXISTS today_installment_duration_months INT,
  ADD COLUMN IF NOT EXISTS today_installment_monthly_amount NUMERIC(10,2);


-- ─────────────────────────────────────────────────────────────────
-- FAIL: 20260827_sync_kyc_waris_rel_email.sql
-- ─────────────────────────────────────────────────────────────────
-- Patch sync_kyc_to_patient() supaya emergency_contact_relationship & emergency_contact_email
-- turut disalin dari psy_kyc_submissions ke psy_patients bila KYC diluluskan — dua medan ni
-- sebelum ini tercicir (staff kob-detail.html/patient-form.html tak nampak Hubungan/Emel Waris
-- yang pesakit isi sendiri di pendaftaran.html). Lihat database/schema/04_patients.sql utk
-- versi sumber kebenaran + nota lengkap.

CREATE OR REPLACE FUNCTION sync_kyc_to_patient()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  -- Hanya sync bila status berubah jadi 'approved'
  IF NEW.status = 'approved' AND (OLD.status IS NULL OR OLD.status != 'approved') THEN
    UPDATE psy_patients
    SET
      status                  = 'active',
      full_name               = COALESCE(NULLIF(full_name, ''), NEW.patient_name),
      phone                   = COALESCE(NULLIF(phone, ''), NEW.phone),
      ic_number               = COALESCE(NULLIF(ic_number, ''), NEW.ic_number),
      date_of_birth           = COALESCE(date_of_birth, NEW.date_of_birth),
      gender                  = COALESCE(NULLIF(gender, ''), NEW.gender),
      address                 = COALESCE(NULLIF(address, ''), NEW.address),
      emergency_contact_name  = COALESCE(NULLIF(emergency_contact_name, ''), NEW.emergency_contact_name),
      emergency_contact_phone = COALESCE(NULLIF(emergency_contact_phone, ''), NEW.emergency_contact_phone),
      emergency_contact_relationship = COALESCE(NULLIF(emergency_contact_relationship, ''), NEW.emergency_contact_relationship),
      emergency_contact_email = COALESCE(NULLIF(emergency_contact_email, ''), NEW.emergency_contact_email),
      referral_source         = COALESCE(NULLIF(referral_source, ''), NEW.referral_source),
      medical_condition       = COALESCE(NULLIF(medical_condition, ''), NEW.medical_condition),
      condition_duration      = COALESCE(NULLIF(condition_duration, ''), NEW.condition_duration),
      medical_notes           = COALESCE(NULLIF(medical_notes, ''), NEW.medical_notes)
    WHERE user_id = NEW.user_id;
  END IF;
  RETURN NEW;
END;
$$;


-- ─────────────────────────────────────────────────────────────────
-- FAIL: 20260901_stock_movements_ledger.sql
-- ─────────────────────────────────────────────────────────────────
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


-- ─────────────────────────────────────────────────────────────────
-- FAIL: 20260901b_letter_approval_workflow.sql
-- ─────────────────────────────────────────────────────────────────
-- Letter Module: staff-as-requester + real approval workflow (draft/submitted/pending_approval/
-- revision_requested) + auto-issue for templates that don't need approval.
-- Rujuk database/schema/15_letters.sql untuk nota penuh.

ALTER TABLE psy_letter_templates ADD COLUMN IF NOT EXISTS department TEXT;

ALTER TABLE psy_letter_requests ALTER COLUMN patient_id DROP NOT NULL;
ALTER TABLE psy_letter_requests ALTER COLUMN patient_name DROP NOT NULL;
ALTER TABLE psy_letter_requests ADD COLUMN IF NOT EXISTS requester_type TEXT NOT NULL DEFAULT 'patient';
ALTER TABLE psy_letter_requests ADD COLUMN IF NOT EXISTS requested_by_staff_id UUID REFERENCES psy_profiles(id) ON DELETE SET NULL;
ALTER TABLE psy_letter_requests ADD COLUMN IF NOT EXISTS requested_by_staff_name TEXT;
ALTER TABLE psy_letter_requests ADD COLUMN IF NOT EXISTS revision_note TEXT;
ALTER TABLE psy_letter_requests ADD COLUMN IF NOT EXISTS recipient TEXT;

ALTER TABLE psy_letter_requests DROP CONSTRAINT IF EXISTS psy_letter_requests_requester_type_check;
ALTER TABLE psy_letter_requests ADD CONSTRAINT psy_letter_requests_requester_type_check
  CHECK (requester_type IN ('patient','staff'));

-- PENTING: constraint LAMA yang live sekarang cuma benarkan ('pending','issued','rejected','cancelled')
-- — 'pending_approval' pun tak sah di bawah constraint lama ni. Kena DROP constraint lama DULU
-- sebelum UPDATE data, barulah ADD constraint baru selepas data dah bersih.
ALTER TABLE psy_letter_requests DROP CONSTRAINT IF EXISTS psy_letter_requests_status_check;

-- Rekod lama guna status 'pending' — sepadankan ke 'pending_approval'.
UPDATE psy_letter_requests SET status = 'pending_approval' WHERE status = 'pending';

-- Jaring keselamatan: mana-mana rekod lama/seed guna status lain yang tak dikenali langsung
-- (bukan 'pending' pun) — sepadankan ke 'pending_approval' supaya staff boleh semak & proses
-- manual, bukan hilang senyap. Tanpa ni, ADD CONSTRAINT di bawah akan gagal setiap kali jumpa
-- rekod lama yang tak dijangka.
UPDATE psy_letter_requests SET status = 'pending_approval'
  WHERE status NOT IN ('draft','submitted','pending_approval','revision_requested','rejected','issued','cancelled');

ALTER TABLE psy_letter_requests ADD CONSTRAINT psy_letter_requests_status_check
  CHECK (status IN ('draft','submitted','pending_approval','revision_requested','rejected','issued','cancelled'));
ALTER TABLE psy_letter_requests ALTER COLUMN status SET DEFAULT 'draft';

CREATE INDEX IF NOT EXISTS idx_letter_req_staff ON psy_letter_requests(requested_by_staff_id);

DROP POLICY IF EXISTS "Staff manage own letter requests" ON psy_letter_requests;
CREATE POLICY "Staff manage own letter requests" ON psy_letter_requests
  FOR ALL USING (requested_by_staff_id = auth.uid())
  WITH CHECK (requested_by_staff_id = auth.uid());

-- Auto-issue: requester sendiri (pesakit/staff) insert psy_letter_issued terus utk request
-- kepunyaan mereka bila template tak perlukan kelulusan.
DROP POLICY IF EXISTS "issued_self_auto_insert" ON psy_letter_issued;
CREATE POLICY "issued_self_auto_insert" ON psy_letter_issued FOR INSERT
  WITH CHECK (
    request_id IN (
      SELECT id FROM psy_letter_requests
      WHERE (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()))
         OR (requested_by_staff_id = auth.uid())
    )
  );

DROP POLICY IF EXISTS "issued_self_read" ON psy_letter_issued;
CREATE POLICY "issued_self_read" ON psy_letter_issued FOR SELECT
  USING (
    request_id IN (SELECT id FROM psy_letter_requests WHERE requested_by_staff_id = auth.uid())
  );

-- ──── psy_letter_request_attachments ────
CREATE TABLE IF NOT EXISTS psy_letter_request_attachments (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id       UUID NOT NULL REFERENCES psy_letter_requests(id) ON DELETE CASCADE,
  file_name        TEXT NOT NULL,
  file_path        TEXT NOT NULL,
  file_size        INT,
  file_type        TEXT,
  uploaded_by      UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  uploaded_by_name TEXT,
  created_at       TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_letter_attach_request ON psy_letter_request_attachments(request_id);

ALTER TABLE psy_letter_request_attachments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "attach_staff_all" ON psy_letter_request_attachments;
CREATE POLICY "attach_staff_all" ON psy_letter_request_attachments FOR ALL
  USING (user_has_perm('communication','view'))
  WITH CHECK (user_has_perm('communication','create'));

DROP POLICY IF EXISTS "attach_self_all" ON psy_letter_request_attachments;
CREATE POLICY "attach_self_all" ON psy_letter_request_attachments FOR ALL
  USING (
    request_id IN (
      SELECT id FROM psy_letter_requests
      WHERE (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()))
         OR (requested_by_staff_id = auth.uid())
    )
  )
  WITH CHECK (
    request_id IN (
      SELECT id FROM psy_letter_requests
      WHERE (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()))
         OR (requested_by_staff_id = auth.uid())
    )
  );

-- ──── Storage: letter-attachments bucket ────
INSERT INTO storage.buckets (id, name, public) VALUES ('letter-attachments', 'letter-attachments', false)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "letter_attachments_staff_all" ON storage.objects;
CREATE POLICY "letter_attachments_staff_all" ON storage.objects
    FOR ALL TO authenticated
    USING (bucket_id = 'letter-attachments' AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
    WITH CHECK (bucket_id = 'letter-attachments' AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "letter_attachments_self_all" ON storage.objects;
CREATE POLICY "letter_attachments_self_all" ON storage.objects
    FOR ALL TO authenticated
    USING (
      bucket_id = 'letter-attachments'
      AND (storage.foldername(name))[1] IN (
        SELECT id::text FROM psy_letter_requests
        WHERE (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()))
           OR (requested_by_staff_id = auth.uid())
      )
    )
    WITH CHECK (
      bucket_id = 'letter-attachments'
      AND (storage.foldername(name))[1] IN (
        SELECT id::text FROM psy_letter_requests
        WHERE (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()))
           OR (requested_by_staff_id = auth.uid())
      )
    );


-- ─────────────────────────────────────────────────────────────────
-- FAIL: 20260921_invoice_receipt_numbers.sql
-- ─────────────────────────────────────────────────────────────────
-- No. resit (REC10001..) & no. invois (INV-000001..) berjujukan + diskaun.
-- receipt_ref KEKAL kunci teknikal (webhook, nama fail PDF, redirect) — receipt_no hanya utk paparan.

ALTER TABLE psy_payments ADD COLUMN IF NOT EXISTS receipt_no TEXT;
ALTER TABLE psy_payments ADD COLUMN IF NOT EXISTS discount NUMERIC(10,2) NOT NULL DEFAULT 0;
ALTER TABLE psy_kob_sessions ADD COLUMN IF NOT EXISTS package_discount NUMERIC(12,2) NOT NULL DEFAULT 0;
ALTER TABLE psy_kob_sessions ADD COLUMN IF NOT EXISTS invoice_no TEXT;

CREATE SEQUENCE IF NOT EXISTS psy_receipt_no_seq START 10001;
CREATE SEQUENCE IF NOT EXISTS psy_invoice_no_seq START 1;

CREATE OR REPLACE FUNCTION psy_assign_receipt_no() RETURNS trigger AS $$
BEGIN
  IF NEW.status = 'completed' AND NEW.receipt_no IS NULL THEN
    NEW.receipt_no := 'REC' || nextval('psy_receipt_no_seq');
  END IF;
  RETURN NEW;
END $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION psy_assign_invoice_no() RETURNS trigger AS $$
BEGIN
  IF NEW.recommended_package_id IS NOT NULL AND NEW.invoice_no IS NULL THEN
    NEW.invoice_no := 'INV-' || lpad(nextval('psy_invoice_no_seq')::text, 6, '0');
  END IF;
  RETURN NEW;
END $$ LANGUAGE plpgsql;

-- Backfill rekod sedia ada ikut susunan masa. Trigger pengguna dimatikan sementara
-- supaya trigger promo/referral/baucar (AFTER UPDATE) tak menyala semula.
ALTER TABLE psy_payments DISABLE TRIGGER USER;
ALTER TABLE psy_kob_sessions DISABLE TRIGGER USER;
DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN SELECT id FROM psy_payments WHERE status = 'completed' AND receipt_no IS NULL
           ORDER BY COALESCE(paid_at, created_at), created_at, id LOOP
    UPDATE psy_payments SET receipt_no = 'REC' || nextval('psy_receipt_no_seq') WHERE id = r.id;
  END LOOP;
  FOR r IN SELECT id FROM psy_kob_sessions WHERE recommended_package_id IS NOT NULL AND invoice_no IS NULL
           ORDER BY created_at, id LOOP
    UPDATE psy_kob_sessions SET invoice_no = 'INV-' || lpad(nextval('psy_invoice_no_seq')::text, 6, '0') WHERE id = r.id;
  END LOOP;
END $$;
ALTER TABLE psy_payments ENABLE TRIGGER USER;
ALTER TABLE psy_kob_sessions ENABLE TRIGGER USER;

CREATE UNIQUE INDEX IF NOT EXISTS uq_psy_payments_receipt_no ON psy_payments(receipt_no);
CREATE UNIQUE INDEX IF NOT EXISTS uq_psy_kob_sessions_invoice_no ON psy_kob_sessions(invoice_no);

DROP TRIGGER IF EXISTS trg_psy_assign_receipt_no ON psy_payments;
CREATE TRIGGER trg_psy_assign_receipt_no BEFORE INSERT OR UPDATE OF status ON psy_payments
  FOR EACH ROW EXECUTE FUNCTION psy_assign_receipt_no();

DROP TRIGGER IF EXISTS trg_psy_assign_invoice_no ON psy_kob_sessions;
CREATE TRIGGER trg_psy_assign_invoice_no BEFORE INSERT OR UPDATE OF recommended_package_id ON psy_kob_sessions
  FOR EACH ROW EXECUTE FUNCTION psy_assign_invoice_no();

NOTIFY pgrst, 'reload schema';


-- ─────────────────────────────────────────────────────────────────
-- FAIL: 20260921b_payments_manual_method.sql
-- ─────────────────────────────────────────────────────────────────
-- Kaedah bayaran manual (transfer/tunai/lain) — dipapar di resit. NULL utk bayaran lama & gateway.
ALTER TABLE psy_payments ADD COLUMN IF NOT EXISTS manual_method TEXT;
ALTER TABLE psy_payments DROP CONSTRAINT IF EXISTS psy_payments_manual_method_check;
ALTER TABLE psy_payments ADD CONSTRAINT psy_payments_manual_method_check
  CHECK (manual_method IS NULL OR manual_method IN ('transfer','cash','other'));
NOTIFY pgrst, 'reload schema';


-- ─────────────────────────────────────────────────────────────────
-- FAIL: 20260921c_payment_invoice_no.sql
-- ─────────────────────────────────────────────────────────────────
-- Invois auto (INV-…) untuk SEMUA bayaran bukan-pakej-KOB. Jalankan selepas 20260921 & 20260921b.
ALTER TABLE psy_payments ADD COLUMN IF NOT EXISTS invoice_no TEXT;
CREATE SEQUENCE IF NOT EXISTS psy_invoice_no_seq START 1;

CREATE OR REPLACE FUNCTION psy_assign_payment_invoice_no() RETURNS trigger AS $$
BEGIN
  IF NEW.invoice_no IS NULL AND NEW.status IN ('pending','completed')
     AND (NEW.intent ->> 'kob_session_id') IS NULL THEN
    NEW.invoice_no := 'INV-' || lpad(nextval('psy_invoice_no_seq')::text, 6, '0');
  END IF;
  RETURN NEW;
END $$ LANGUAGE plpgsql;

-- Backfill ikut masa (trigger pengguna dimatikan sementara supaya trigger promo/referral/baucar tak menyala semula)
ALTER TABLE psy_payments DISABLE TRIGGER USER;
DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN SELECT id FROM psy_payments
           WHERE invoice_no IS NULL AND status IN ('pending','completed') AND (intent ->> 'kob_session_id') IS NULL
           ORDER BY COALESCE(paid_at, created_at), created_at, id LOOP
    UPDATE psy_payments SET invoice_no = 'INV-' || lpad(nextval('psy_invoice_no_seq')::text, 6, '0') WHERE id = r.id;
  END LOOP;
END $$;
ALTER TABLE psy_payments ENABLE TRIGGER USER;

CREATE UNIQUE INDEX IF NOT EXISTS uq_psy_payments_invoice_no ON psy_payments(invoice_no);

DROP TRIGGER IF EXISTS trg_psy_assign_payment_invoice_no ON psy_payments;
CREATE TRIGGER trg_psy_assign_payment_invoice_no BEFORE INSERT OR UPDATE OF status ON psy_payments
  FOR EACH ROW EXECUTE FUNCTION psy_assign_payment_invoice_no();

NOTIFY pgrst, 'reload schema';


-- ─────────────────────────────────────────────────────────────────
-- FAIL: 20260921d_seed_installment_reminder_automation.sql
-- ─────────────────────────────────────────────────────────────────
-- Seed automasi "Peringatan Ansuran" (Sistem Automasi) — 2 mesej: 7 hari & 2 hari sebelum due date.
-- Dicipta sebagai DRAF (tidak aktif) — semak teks dalam halaman Automasi kemudian aktifkan.
-- Pautan HitPay + invois PDF dilampirkan automatik bila templat guna {{pautan}} (automations-runner).
-- Jangan hidupkan serentak dgn Auto Mesej "installment_reminder" (psy_auto_messages) — mesej berganda.
-- Idempotent: tak dicipta semula kalau automasi bernama sama sudah wujud.
do $$
declare v_id uuid;
begin
  if exists (select 1 from psy_automations where name = 'Peringatan Ansuran Pakej') then
    return;
  end if;

  insert into psy_automations
    (name, description, is_active, status, trigger_category, trigger_event, trigger_timing,
     conditions_enabled, conditions, actions, message_channel, run_mode)
  values
    ('Peringatan Ansuran Pakej',
     'Ingatkan pesakit sebelum ansuran pakej jatuh tempoh: 7 hari dan 2 hari sebelum. Sertakan pautan bayaran HitPay + invois PDF.',
     false, 'draft', 'installment', 'installment_reminder', '{"when":"before"}'::jsonb,
     false, '[]'::jsonb, '["whatsapp"]'::jsonb, 'whatsapp', 'always')
  returning id into v_id;

  insert into psy_automation_messages
    (automation_id, position, send_mode, day_offset, send_time, content_type, message_text)
  values
    (v_id, 1, 'specific_time', 7, '10:00', 'text',
     E'Salam {{nama}} 👋\n\nMakluman: ansuran *{{ansuran}}* pakej rawatan anda (RM {{jumlah}}) akan tamat tempoh pada *{{tarikh_due}}*.\n\nInvois dilampirkan. Anda boleh bayar melalui pautan selamat ini:\n{{pautan}}\n\nTerima kasih — ISW'),
    (v_id, 2, 'specific_time', 2, '10:00', 'text',
     E'Salam {{nama}} 👋\n\nPeringatan: ansuran *{{ansuran}}* (RM {{jumlah}}) akan tamat tempoh pada *{{tarikh_due}}*.\n\nSila selesaikan bayaran sebelum tarikh itu untuk mengelakkan tempahan sesi disekat:\n{{pautan}}\n\nTerima kasih — ISW');
end $$;


-- ─────────────────────────────────────────────────────────────────
-- FAIL: 20260921e_automation_attach_invoice.sql
-- ─────────────────────────────────────────────────────────────────
-- Pilihan eksplisit per mesej automasi: "Lampirkan invois PDF" (trigger ansuran).
alter table psy_automation_messages add column if not exists attach_invoice boolean not null default false;

-- Mesej automasi seed "Peringatan Ansuran Pakej" (20260921d) melampirkan invois.
update psy_automation_messages set attach_invoice = true
where automation_id in (select id from psy_automations where name = 'Peringatan Ansuran Pakej');

notify pgrst, 'reload schema';


-- ─────────────────────────────────────────────────────────────────
-- FAIL: 20260921f_manual_payment_audit.sql
-- ─────────────────────────────────────────────────────────────────
-- Bayaran manual yang boleh diaudit: rujukan bank, staf perekod, sasaran bayaran, bendera separa.
-- paid_at = tarikh & masa bayaran SEBENAR (bukan masa staf key-in); created_at = masa direkod.
alter table psy_payments add column if not exists bank_reference text;
alter table psy_payments add column if not exists recorded_by uuid references psy_profiles(id) on delete set null;
alter table psy_payments add column if not exists paid_for_type text;
alter table psy_payments add column if not exists paid_for_seq int;
alter table psy_payments add column if not exists paid_for_ref text;
alter table psy_payments add column if not exists is_partial boolean not null default false;

alter table psy_payments drop constraint if exists psy_payments_paid_for_type_check;
alter table psy_payments add constraint psy_payments_paid_for_type_check
  check (paid_for_type is null or paid_for_type in ('package','installment','invoice','consultation','product','other'));

-- Bayaran manual lama: no. rujukan yang ditaip staf (invoice_number) ialah rujukan bank/transfer.
alter table psy_payments disable trigger user;
update psy_payments set bank_reference = invoice_number
  where payment_method = 'manual' and bank_reference is null and invoice_number is not null;
alter table psy_payments enable trigger user;

notify pgrst, 'reload schema';


-- ─────────────────────────────────────────────────────────────────
-- FAIL: 20260923_installment_autocharge.sql
-- ─────────────────────────────────────────────────────────────────
-- ⚠️ AMARAN (30 Sept 2026): skema/kolum di bawah SELAMAT run (idempotent,
-- ADD COLUMN IF NOT EXISTS). TAPI fitur auto-caj kad ni sendiri BELUM
-- disahkan selamat guna duit sebenar — belum diuji sandbox HitPay sama
-- ada deposit yg dicaj melalui recurring-billing betul-betul sampai ke
-- akaun ISW, atau cuma tokenize kad tanpa duit bergerak. JANGAN aktifkan
-- ciri auto-caj (deploy edge function/aktifkan templat WA) sebelum sesi
-- sandbox sebenar disahkan — lihat memory project_hitpay_installment_autocharge.
-- ═══════════════════════════════════════════════════════════════════
-- Auto-Caj Ansuran (kad tersimpan HitPay) — lihat database/schema/09_kob.sql
-- & database/schema/18_notifications_automations.sql utk versi sumber
-- kebenaran + nota lengkap. Jalankan di TESTING dulu, kemudian PROD (xmvqvq).
--
-- Ringkasan: pesakit lampir kad SEKALI (recurring-billing HitPay,
-- save_payment_method) → tiap checkpoint ansuran seterusnya dicaj ON-DEMAND
-- automatik pada due_date (jumlah berbeza-beza ikut checkpoint, BUKAN
-- subscription/cycle tetap HitPay) — gantikan/lengkapi aliran pautan-manual
-- sedia ada (installment_reminder/installment_overdue).
-- ═══════════════════════════════════════════════════════════════════

-- ──── psy_kob_installment_checkpoints — jejak percubaan auto-caj ────
ALTER TABLE psy_kob_installment_checkpoints
  ADD COLUMN IF NOT EXISTS autocharge_status TEXT NOT NULL DEFAULT 'not_attempted'
    CHECK (autocharge_status IN ('not_attempted','succeeded','failed')),
  ADD COLUMN IF NOT EXISTS autocharge_last_attempt_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS autocharge_attempts INT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS autocharge_payment_id UUID REFERENCES psy_payments(id) ON DELETE SET NULL;

-- ──── psy_kob_card_authorizations — kad tersimpan, 1 rekod per sesi KOB ────
CREATE TABLE IF NOT EXISTS psy_kob_card_authorizations (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  kob_session_id    UUID NOT NULL REFERENCES psy_kob_sessions(id) ON DELETE CASCADE,
  patient_id        UUID NOT NULL REFERENCES psy_patients(id) ON DELETE CASCADE,
  gateway_provider  TEXT NOT NULL DEFAULT 'hitpay',
  gateway_auth_ref  TEXT NOT NULL,
  status            TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','attached','detached','failed')),
  card_last4        TEXT,
  card_brand        TEXT,
  attached_at       TIMESTAMPTZ,
  detached_at       TIMESTAMPTZ,
  created_at        TIMESTAMPTZ DEFAULT now(),
  CONSTRAINT psy_kob_card_authorizations_unique_session UNIQUE (kob_session_id)
);

CREATE INDEX IF NOT EXISTS idx_kob_card_auth_patient ON psy_kob_card_authorizations(patient_id);

ALTER TABLE psy_kob_card_authorizations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Patient read own card auth" ON psy_kob_card_authorizations;
CREATE POLICY "Patient read own card auth" ON psy_kob_card_authorizations FOR SELECT
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Staff manage card auth" ON psy_kob_card_authorizations;
CREATE POLICY "Staff manage card auth" ON psy_kob_card_authorizations FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- ──── psy_auto_messages — templat WA baharu (is_active=false, staff aktifkan bila sedia) ────
insert into psy_auto_messages
  (key, name, description, channel, trigger_type, message_template,
   placeholders, channels, category, language, is_active)
values
  ('card_attach_invite',
   'Jemputan Lampir Kad — Ansuran Automatik',
   'Pautan HitPay "lampir kad" (RM1 pengesahan) supaya ansuran seterusnya dicaj automatik pada tarikh due, pesakit tak perlu klik pautan tiap bulan.',
   'whatsapp', 'card_attach_invite',
   E'Salam {nama} 👋\n\nUntuk memudahkan bayaran ansuran pakej rawatan anda, sila lampirkan kad debit/kredit anda (pengesahan RM1) melalui pautan selamat di bawah. Ansuran seterusnya akan ditolak SECARA AUTOMATIK pada tarikh due — anda tak perlu klik pautan bayaran setiap bulan lagi.\n\n{pautan}\n\n— {nama_klinik}',
   '["{nama}","{pautan}","{nama_klinik}"]'::jsonb,
   '["whatsapp"]'::jsonb,
   'pembayaran', 'ms',
   false),
  ('installment_autocharge_success',
   'Ansuran Auto-Caj Berjaya',
   'Kad tersimpan pesakit berjaya dicaj automatik pada tarikh due checkpoint ansuran — hantar WA makluman ringkas.',
   'whatsapp', 'installment_autocharge_success',
   E'Salam {nama} 👋\n\nAnsuran *{ansuran}* pakej rawatan anda (RM {jumlah}) telah berjaya ditolak secara automatik daripada kad tersimpan anda pada hari ini.\n\nTerima kasih — {nama_klinik}',
   '["{nama}","{ansuran}","{jumlah}","{nama_klinik}"]'::jsonb,
   '["whatsapp"]'::jsonb,
   'pembayaran', 'ms',
   false),
  ('installment_autocharge_failed',
   'Ansuran Auto-Caj Gagal',
   'Kad tersimpan pesakit gagal dicaj (ditolak/tamat tempoh dll) semasa cuba caj automatik pada tarikh due — hantar WA + pautan bayaran manual fallback.',
   'whatsapp', 'installment_autocharge_failed',
   E'Salam {nama} 👋\n\nAnsuran *{ansuran}* pakej rawatan anda (RM {jumlah}) GAGAL ditolak secara automatik daripada kad tersimpan anda (kad mungkin ditolak/tamat tempoh).\n\nSila selesaikan bayaran melalui pautan selamat di bawah, atau hubungi klinik untuk kemas kini kad:\n{pautan}\n\n— {nama_klinik}',
   '["{nama}","{ansuran}","{jumlah}","{pautan}","{nama_klinik}"]'::jsonb,
   '["whatsapp"]'::jsonb,
   'pembayaran', 'ms',
   false)
on conflict (key) do update set
  name             = excluded.name,
  description      = excluded.description,
  channel          = excluded.channel,
  trigger_type     = excluded.trigger_type,
  message_template = excluded.message_template,
  placeholders     = excluded.placeholders,
  channels         = excluded.channels,
  category         = excluded.category,
  language         = excluded.language,
  updated_at       = now();


-- ─────────────────────────────────────────────────────────────────
-- FAIL: 20260923_package_value_stack.sql
-- ─────────────────────────────────────────────────────────────────
-- Value stack pemasaran pakej — kad "Apa Yang Anda Terima" + bonus + jadual
-- ringkasan nilai, macam dokumen ISW_OBD_OFFER_STACK_DET (Package Treatment/).
-- Lihat database/schema/05_packages.sql utk versi sumber kebenaran + nota lengkap.
--
-- Prototaip: OBD1 sahaja dulu (14 komponen + 3 bonus, jumlah RM192,000, sepadan
-- dgn "Jumlah Nilai Keseluruhan" dlm dokumen asal). Pakej lain (OBDX1/Y1,
-- OBG/OBG+/OBG1+, OBP+) belum diisi — akan fallback ke senarai Produk/Bimbingan
-- ringkas sedia ada sehingga data dimasukkan.

ALTER TABLE psy_packages
  ADD COLUMN IF NOT EXISTS value_stack JSONB DEFAULT '[]',
  ADD COLUMN IF NOT EXISTS value_bonuses JSONB DEFAULT '[]';

UPDATE psy_packages
SET
  value_stack = '[
    {"category":"Done For You","title_bm":"Protokol Reset Metabolik dan Penyucian Dalaman","title_en":"Metabolic Reset & Purification Protocol","description":"Rawatan di ISW — setiap keputusan disesuaikan dengan JASAD anda.","bullets":["22 sesi rawatan fizikal di ISW sepanjang 12 minggu","Sesi Online: 36 sesi bimbingan & pantauan berkala secara online — Rabu hingga Jumaat (9:00am-9.15am)"],"value":22000},
    {"category":"Done For You","title_bm":"Set Pemulihan Penyembuhan Lanjutan","title_en":"Recovery Knowledge Blueprint","description":"13 buku panduan + Passport OB rekod peribadi — senjata ilmu pemulihan anda yang menjawab SEMUA persoalan sepanjang perjalanan.","bullets":["Sains di Sebalik Overhaul Body","Panduan 101 Penyakit (7 buku — 1 set rujukan komprehensif)","Gaya Hidup Fitrah + Bahaya Nafsu Perut + Nikmat Selera Sel","Resipi SuperImun + Resipi SuperEnergi","Passport OB — fail pemantauan & rekod progres"],"value":4000},
    {"category":"Done With You","title_bm":"Profil DNA Peribadi — Oh My Gene","title_en":"Genetic Blueprint Analysis","description":"Ketahui TEPAT mengapa badan anda bertindak begini — jawapan ada dalam DNA unik anda sendiri.","bullets":["1 sesi ujian DNA swab (mudah & tidak invasif)","Laporan DNA peribadi: softcopy PDF","Analisis kecenderungan penyakit & profil risiko genetik","Sesi konsultasi DNA report bersama Nutritionist: cadangan pemakanan berdasarkan genetik & pelan tindakan pencegahan"],"value":6000},
    {"category":"Done For You","title_bm":"Formula Herba Reset Metabolik dan Penyucian","title_en":"Metabolic Reset & Purification System","description":"ISW urus segalanya — bekalan, jadual, prosedur & pemantauan. Anda hanya hadir dan fokus pulih.","bullets":["Lote Tree Honey (LTH) 6kg, Lote Tree Honey Pearl Garlic (LTHPG) 6kg — bekalan penuh 12 minggu","Herba Thoharah — 220 gelas, 20 sesi penyucian dalaman","Set Penyucian Kolon — 1 set, 6 sesi","Terapi IV Saline Drip — 4 sesi hidrasi & nutrisi","Terapi Aktivasi Neuron — 7 hari","Terapi Air Afiyah — 84 hari","Terapi Penyucian Aura — 120 hari"],"value":56000},
    {"category":"Sistem","title_bm":"Hala Tuju Pemulihan 12 Minggu","title_en":"12-Week Recovery Roadmap Framework","description":"PETA pemulihan anda — jelas arah, tidak panik, tidak keliru.","bullets":["Panduan bergambar perjalanan sepanjang 84 hari","Ringkasan Rutin Harian"],"value":1000},
    {"category":"Transformasi Identiti","title_bm":"Program New Life Challenge","title_en":"","description":"Program transformasi diri berasaskan pendekatan biopsikososial-spiritual untuk membantu pesakit membina sistem kepercayaan yang lebih sihat, mengurus emosi dan meningkatkan kesejahteraan jasad, jiwa, akal dan roh.","bullets":["6 kelas siaran langsung (2 jam/sesi)","Group sokongan New Life Challenge"],"value":8000},
    {"category":"Sistem","title_bm":"Sistem Bimbingan Pemulihan Harian","title_en":"Daily Healing Guidance System","description":"Rawatan tidak berhenti walaupun anda di rumah — sistem panduan harian memastikan pemulihan berterusan 24/7.","bullets":["OB Home Guidance Series (video harian berjadual)","Customer Care Daily Practice Videos","Siri Video Santapan Fitrah"],"value":6000},
    {"category":"Done With You","title_bm":"Pengalaman Penilaian Pemulihan Peribadi","title_en":"Personalised Healing Assessment Experience","description":"Bimbingan terus 1-on-1. Dua sesi eksklusif untuk pastikan pemulihan anda tepat dan selamat.","bullets":["2 sesi bersemuka eksklusif bersama Hakeema","Sesi penilaian dan bimbingan pemulihan"],"value":6000},
    {"category":"Pengalaman","title_bm":"Dokumentari Overhaul Body Moments","title_en":"Transformation Overhaul Body Moments Documentation","description":"Perjalanan transformasi anda diabadikan secara profesional — bukti hidup kejayaan yang boleh dikongsi seumur hidup.","bullets":["Foto sebelum, semasa & selepas rawatan (rekod penuh)","Rakaman video progres setiap 3 minggu (4 sesi)","Penerbitan Dokumentari Hasil OB Fasa 1","Fail digital eksklusif yang telah siap disunting dan dikongsi kepada keluarga & rakan"],"value":12000},
    {"category":"Done With You","title_bm":"Pengalaman Pemulihan Rohani — Akses Sepanjang Hayat","title_en":"Spiritual Healing Immersion Experience","description":"Akses sepanjang hayat kepada sesi pemulihan rohani dalam talian yang menyokong pesakit melalui bimbingan spiritual, motivasi dan komuniti yang positif.","bullets":["Sesi Online: Bacaan Manzil harian bersama Sheikh/Ustaz — 6:45am & 6:30pm","Sesi Online: Bacaan Doa Syifa — Rabu hingga Jumaat (8:45am-9.00am)"],"value":6000},
    {"category":"Done With You","title_bm":"Sokongan Pemulihan Mingguan","title_en":"Weekly Recovery Support","description":"Sesi online harian yang menghimpunkan pesakit dalam suasana sokongan, motivasi dan pengukuhan emosi.","bullets":["Sesi Online — Perubatan Alami: Terapi Pernafasan, Terapi Bumi, Terapi Berjemur Matahari — Rabu hingga Jumaat (9:00am-9.15am)"],"value":12000},
    {"category":"Access","title_bm":"Sistem Integrasi Komuniti GengALIVE","title_en":"GengALIVE Community Integration System","description":"Anda tidak bersendirian, komuniti GengALIVE akan angkat semangat anda setiap hari.","bullets":["6 bulan sesi perkongsian Sabtu/Ahad oleh GengALIVE (bekas pesakit OB) di ISW","Program Santapan Fitrah & Ziarah Cinta","Sokongan emosi + semangat komuniti + harapan bersama"],"value":12000},
    {"category":"Access","title_bm":"Pasukan Penjagaan Pemulihan Overhaul Body (6 Bulan)","title_en":"Overhaul Body Care Team","description":"Pasukan pakar anda — sedia setiap hari. Tiada soalan dibiarkan, tiada reaksi pemulihan dihadapi bersendirian.","bullets":["WhatsApp support sepanjang reaksi pemulihan","Nutritionist on call — Rabu hingga Jumaat (10:00am-4:00pm)","Follow up aktif 3x seminggu (pengisian online checklist amalan harian — Isnin, Rabu & Jumaat)","ISW Patient Portal OB","Sokongan penuh Team ISW"],"value":12000},
    {"category":"Eksklusif ISW","title_bm":"Pelan Rawatan Peribadi","title_en":"Clinical Coordination & Personalised Protocol Design","description":"Rekabentuk pelan rawatan JASAD-JIWA-AKAL-ROHANI 100% peribadi menggunakan model Biopsychosocial-Spiritual.","bullets":["Pemantauan menyeluruh Fasa 1","Pelarasan rawatan berasaskan respon Fasa 1"],"value":12000}
  ]'::jsonb,
  value_bonuses = '[
    {"category":"Bonus #1 — Percuma","title_bm":"Video Talk Eksklusif Hakeema","title_en":"Hakeema Wisdom Journal Series","description":"Setiap minggu ilmu terus dari Hakeema — topik JASAD, JIWA, AKAL & ROHANI yang tidak dikongsikan di luar ISW.","bullets":["Live talk Sabtu & Ahad oleh Hakeema sepanjang 10 minggu","Topik kesihatan holistik JASAD-JIWA-AKAL-ROHANI mendalam","Akses rakaman video terpilih untuk tontonan semula"],"value":6000},
    {"category":"Bonus #2 — Percuma","title_bm":"Hadiah Khas Peserta Overhaul Body","title_en":"Exclusive Wellness Starter Blueprint","description":"Hadiah kejutan eksklusif untuk anda yang memilih transformasi hari ini — tidak tersedia untuk umum.","bullets":["Baucar Konsultasi Overhaul Body (RM500)","Baucar Perubatan Minda JumpStart (3 Bulan)","Baucar Tunai RM100"],"value":5000},
    {"category":"Bonus #3 — Percuma","title_bm":"Bimbingan Protokol Pemulihan","title_en":"Healing Protocol Mastery Framework","description":"Nikmati bimbingan lengkap merangkumi protokol pemulihan, pemakanan dan nutrisi, amalan spiritual, terapi semula jadi serta pengurusan reaksi pemulihan.","bullets":["Peminuman madu LTH & LTHPG","Diet & Nutrisi","Terapi Zikir Bersanad","Terapi Pernafasan Fitrah","Terapi Berjemur Cahaya Matahari","Terapi Bumi","Herba Thoharah","Terapi IV Saline Drip","Terapi Air Afiyah","Terapi Aktivasi Neuron","Terapi Penyucian Aura","Reaksi Pemulihan","Terapi Penyucian Kolon","Terapi Ozon","OMG DNA Test Kit","Pengurusan Reaksi Pemulihan Secara Menyeluruh"],"value":6000}
  ]'::jsonb
WHERE LOWER(package_id) IN ('obd1', 'pkg-obd1')
  AND (value_stack IS NULL OR value_stack = '[]'::jsonb);


-- ─────────────────────────────────────────────────────────────────
-- FAIL: 20260923_patient_events_emergency_link.sql
-- ─────────────────────────────────────────────────────────────────
-- Audit management 23 Sept 2026, Tier 1 (#B1-40): pesakit Masuk Wad/Hospital/Perlu
-- Lawatan dari kes Red Emergency Protocol perlu auto-link ke Rekod Klinikal Pesakit
-- (Modul Peristiwa Pesakit, sedia ada) — bila rekod klinikal ditutup, kes emergency
-- asal dikemaskini automatik.
-- Rujuk: database/schema/25_patient_events.sql

ALTER TABLE psy_patient_events
  ADD COLUMN IF NOT EXISTS source_emergency_alert_id UUID REFERENCES psy_emergency_alerts(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_pe_source_alert ON psy_patient_events(source_emergency_alert_id) WHERE source_emergency_alert_id IS NOT NULL;

CREATE OR REPLACE FUNCTION trg_patient_event_notify_emergency()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_note TEXT;
BEGIN
  IF NEW.source_emergency_alert_id IS NULL THEN RETURN NEW; END IF;
  IF NOT (NEW.status = 'closed' AND OLD.status <> 'closed') THEN RETURN NEW; END IF;

  v_note := 'Rekod Klinikal Pesakit (' || NEW.event_type || ') ditutup pada ' ||
            to_char(now(), 'DD Mon YYYY HH24:MI') ||
            COALESCE(' — ' || NEW.notes, '') ||
            '. Lihat peristiwa-detail.html?id=' || NEW.id::TEXT;

  UPDATE psy_emergency_alerts
  SET notes = CASE WHEN notes IS NULL OR notes = '' THEN v_note ELSE notes || E'\n' || v_note END,
      updated_at = now()
  WHERE id = NEW.source_emergency_alert_id;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE LOG 'trg_patient_event_notify_emergency: %', SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_patient_event_notify_emergency ON psy_patient_events;
CREATE TRIGGER trg_patient_event_notify_emergency
  AFTER UPDATE ON psy_patient_events
  FOR EACH ROW EXECUTE FUNCTION trg_patient_event_notify_emergency();


-- ─────────────────────────────────────────────────────────────────
-- FAIL: 20260924_dna_test_package_config.sql
-- ─────────────────────────────────────────────────────────────────
-- Audit management 23 Sept 2026, Tier 4 (#B1-7, #B1-8): DNA Test auto-create dari
-- entitlement pakej + config Package Master (Required/bilangan/timing), pola sama
-- macam hk1_types Sesi 1:1.
-- Rujuk: database/schema/05_packages.sql, database/schema/26_dna_test.sql

ALTER TABLE psy_packages ADD COLUMN IF NOT EXISTS dna_test_required BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE psy_packages ADD COLUMN IF NOT EXISTS dna_test_count INT DEFAULT 1;
ALTER TABLE psy_packages ADD COLUMN IF NOT EXISTS dna_test_week INT DEFAULT 1;

ALTER TABLE psy_dna_test_process ADD COLUMN IF NOT EXISTS plan_id UUID REFERENCES psy_treatment_plans(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS idx_dna_test_plan ON psy_dna_test_process(plan_id) WHERE plan_id IS NOT NULL;


-- ─────────────────────────────────────────────────────────────────
-- FAIL: 20260924_kalendar_jadual_tier4.sql
-- ─────────────────────────────────────────────────────────────────
-- Audit management 23 Sept 2026, Tier 4 batch 2 item IV (Kalendar & Jadual /
-- Pelan Mingguan #17, #27, #28, #30, #47) — hanya #47 (kapasiti slot) perlukan
-- migration; #17/#27/#28/#30 semuanya guna kod + enum status sedia ada.
-- Rujuk: database/schema/09_kob.sql

ALTER TABLE psy_kob_slot_config ADD COLUMN IF NOT EXISTS max_bookings INT;


-- ─────────────────────────────────────────────────────────────────
-- FAIL: 20260924_payment_adjustments.sql
-- ─────────────────────────────────────────────────────────────────
-- Audit management 23 Sept 2026, Tier 3 (#B1-24 Void/Refund/Correction, #B1-23 test flag).
-- Rujuk: database/schema/06_payments.sql

ALTER TABLE psy_payments DROP CONSTRAINT IF EXISTS psy_payments_status_check;
ALTER TABLE psy_payments ADD CONSTRAINT psy_payments_status_check
  CHECK (status IN ('pending','completed','refunded','failed','voided'));

ALTER TABLE psy_payments ADD COLUMN IF NOT EXISTS is_test BOOLEAN NOT NULL DEFAULT false;

CREATE TABLE IF NOT EXISTS psy_payment_adjustments (
  id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  payment_id         UUID NOT NULL REFERENCES psy_payments(id) ON DELETE CASCADE,
  type               TEXT NOT NULL CHECK (type IN ('void','refund','correction')),
  reason             TEXT NOT NULL,
  amount             NUMERIC(10,2),
  requested_by       UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  requested_by_name  TEXT,
  requested_at       TIMESTAMPTZ DEFAULT now(),
  approved_by        UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  approved_by_name   TEXT,
  approved_at        TIMESTAMPTZ,
  status             TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected')),
  notes              TEXT,
  created_at         TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_payment_adj_payment ON psy_payment_adjustments(payment_id);
CREATE INDEX IF NOT EXISTS idx_payment_adj_status  ON psy_payment_adjustments(status, requested_at);

ALTER TABLE psy_payment_adjustments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff manage payment adjustments" ON psy_payment_adjustments;
CREATE POLICY "Staff manage payment adjustments" ON psy_payment_adjustments FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));


-- ─────────────────────────────────────────────────────────────────
-- FAIL: 20260924_payment_status_timeline.sql
-- ─────────────────────────────────────────────────────────────────
-- Audit management 23 Sept 2026, Tier 3 (#B1-25/26, item 2 of 3 previously scoped out):
-- Status Timeline — jejak SETIAP perubahan status bayaran, bukan cuma status terkini.
-- Rujuk: database/schema/06_payments.sql

CREATE TABLE IF NOT EXISTS psy_payment_status_log (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  payment_id  UUID NOT NULL REFERENCES psy_payments(id) ON DELETE CASCADE,
  old_status  TEXT,
  new_status  TEXT NOT NULL,
  changed_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_payment_status_log_payment ON psy_payment_status_log(payment_id, changed_at);

ALTER TABLE psy_payment_status_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff read payment status log" ON psy_payment_status_log;
CREATE POLICY "Staff read payment status log" ON psy_payment_status_log FOR SELECT
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

CREATE OR REPLACE FUNCTION trg_log_payment_status()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO psy_payment_status_log (payment_id, old_status, new_status) VALUES (NEW.id, NULL, NEW.status);
  ELSIF TG_OP = 'UPDATE' AND NEW.status IS DISTINCT FROM OLD.status THEN
    INSERT INTO psy_payment_status_log (payment_id, old_status, new_status) VALUES (NEW.id, OLD.status, NEW.status);
  END IF;
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE LOG 'trg_log_payment_status: %', SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_log_payment_status ON psy_payments;
CREATE TRIGGER trg_log_payment_status
  AFTER INSERT OR UPDATE OF status ON psy_payments
  FOR EACH ROW EXECUTE FUNCTION trg_log_payment_status();

-- Backfill sekali sahaja — bayaran sedia ada dapat SATU baris "current status"
-- (bukan sejarah penuh, sbb sejarah lama tak wujud, tapi baris ni supaya timeline
-- UI tak kosong terus utk rekod lama).
INSERT INTO psy_payment_status_log (payment_id, old_status, new_status, changed_at)
SELECT id, NULL, status, COALESCE(paid_at, created_at)
FROM psy_payments p
WHERE NOT EXISTS (SELECT 1 FROM psy_payment_status_log l WHERE l.payment_id = p.id);


-- ─────────────────────────────────────────────────────────────────
-- FAIL: 20260924_receipt_delivery_status.sql
-- ─────────────────────────────────────────────────────────────────
-- Audit management 23 Sept 2026, Tier 3 (#B1-27): status penghantaran resit/invois.
-- Rujuk: database/schema/06_payments.sql

ALTER TABLE psy_payments ADD COLUMN IF NOT EXISTS receipt_last_sent_at TIMESTAMPTZ;
ALTER TABLE psy_payments ADD COLUMN IF NOT EXISTS receipt_last_sent_status TEXT;
ALTER TABLE psy_payments DROP CONSTRAINT IF EXISTS psy_payments_receipt_last_sent_status_check;
ALTER TABLE psy_payments ADD CONSTRAINT psy_payments_receipt_last_sent_status_check
  CHECK (receipt_last_sent_status IS NULL OR receipt_last_sent_status IN ('sent','failed'));




