-- ═══════════════════════════════════════════════════════════════════
-- SKEMA: PRODUK & INVENTORI
-- Jadual: psy_inventory_items, psy_inventory_requests, psy_products,
--         psy_procedure_kits, psy_bottle_returns
-- Katalog produk kedai (shop), inventori klinik dengan auto-request
-- bila stok rendah, kit prosedur, dan pulangan botol madu pesakit.
-- ═══════════════════════════════════════════════════════════════════

-- ──── psy_inventory_items ────
CREATE TABLE IF NOT EXISTS psy_inventory_items (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name                 TEXT NOT NULL,
  shopee_url           TEXT,   -- pautan Shopee untuk beli produk ini
  category             TEXT NOT NULL DEFAULT 'Bekalan Coaching',
  unit                 TEXT NOT NULL DEFAULT 'Unit'
                       CHECK (unit IN ('Biji (pcs)','Botol','Kotak','Pek','Tiub','Tablet',
                                       'Kapsul','Set','Gulung','Beg','Pasang','Unit','Gram','Kg','Naskhah','Gelas',
                                       'Liter (L)','Mililiter (ml)','Inci (inch)','Sentimeter (cm)','Milimeter (mm)')),
  -- issue_unit/issue_units_per_stock_unit: bagi item yg dibeli dlm unit besar tapi
  -- diguna pesakit dlm unit kecil (cth: beli 1 Gulung tape = 30 Inci, pesakit
  -- guna 1 Inci setiap kali). NULL = tiada tukaran, bagi pesakit kena guna unit sama
  -- macam stok. Lihat shared/inventoryStock.js & roles/staff/patient-hub.html submitSupply().
  issue_unit           TEXT
                       CHECK (issue_unit IS NULL OR issue_unit IN ('Biji (pcs)','Botol','Kotak','Pek','Tiub','Tablet',
                                       'Kapsul','Set','Gulung','Beg','Pasang','Unit','Gram','Kg','Naskhah','Gelas',
                                       'Liter (L)','Mililiter (ml)','Inci (inch)','Sentimeter (cm)','Milimeter (mm)')),
  issue_units_per_stock_unit NUMERIC(10,4),
  qty_in_stock         NUMERIC(12,4) NOT NULL DEFAULT 0,
  min_qty              NUMERIC(10,2) NOT NULL DEFAULT 5,
  requires_approval    BOOLEAN NOT NULL DEFAULT false,
  notes                TEXT,
  max_qty              NUMERIC(10,2),
  auto_reorder_qty     NUMERIC(10,2),
  last_auto_po_at      TIMESTAMPTZ,
  consumption_type     TEXT DEFAULT 'package'
                       CHECK (consumption_type IN ('package','service','general')),
  supplier_info        JSONB DEFAULT '{}'::jsonb,
  source_type          TEXT NOT NULL DEFAULT 'am'
                       CHECK (source_type IN ('farmasi_klinikal','am')),
  batch_no             TEXT,
  expiry_date          DATE,
  item_code            TEXT UNIQUE,
  is_active            BOOLEAN NOT NULL DEFAULT true,
  status               TEXT NOT NULL DEFAULT 'active'
                       CHECK (status IN ('active','inactive','discontinued')),
  reorder_threshold_pct NUMERIC(5,2),
  manufacturer         TEXT,
  registration_no      TEXT,
  storage_location     TEXT,
  storage_condition    TEXT,
  barcode              TEXT,
  shelf_life_days      INT,
  image_url            TEXT,
  internal_notes       TEXT,
  created_at           TIMESTAMPTZ DEFAULT now(),
  updated_at           TIMESTAMPTZ DEFAULT now()
);

-- Kolum ditambah selepas jadual asal wujud (patch untuk install sedia ada)
ALTER TABLE psy_inventory_items ADD COLUMN IF NOT EXISTS source_type TEXT NOT NULL DEFAULT 'am'
  CHECK (source_type IN ('farmasi_klinikal','am'));
ALTER TABLE psy_inventory_items ADD COLUMN IF NOT EXISTS batch_no TEXT;
ALTER TABLE psy_inventory_items ADD COLUMN IF NOT EXISTS expiry_date DATE;
ALTER TABLE psy_inventory_items ADD COLUMN IF NOT EXISTS item_code TEXT UNIQUE;
ALTER TABLE psy_inventory_items ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT true;
ALTER TABLE psy_inventory_items ADD COLUMN IF NOT EXISTS reorder_threshold_pct NUMERIC(5,2);
ALTER TABLE psy_inventory_items ADD COLUMN IF NOT EXISTS manufacturer TEXT;
ALTER TABLE psy_inventory_items ADD COLUMN IF NOT EXISTS registration_no TEXT;
ALTER TABLE psy_inventory_items ADD COLUMN IF NOT EXISTS storage_location TEXT;
ALTER TABLE psy_inventory_items ADD COLUMN IF NOT EXISTS storage_condition TEXT;
ALTER TABLE psy_inventory_items ADD COLUMN IF NOT EXISTS barcode TEXT;
ALTER TABLE psy_inventory_items ADD COLUMN IF NOT EXISTS shelf_life_days INT;
ALTER TABLE psy_inventory_items ADD COLUMN IF NOT EXISTS image_url TEXT;
ALTER TABLE psy_inventory_items ADD COLUMN IF NOT EXISTS internal_notes TEXT;
-- Fail print-ready (PDF) item ni — cth reka bentuk Brochure BNP. Staff buka
-- inventory-detail.html item ni terus untuk cetak semula bila nak restock,
-- bukan cari dalam senarai dokumen berasingan. Bucket: inventory-print-files.
ALTER TABLE psy_inventory_items ADD COLUMN IF NOT EXISTS print_file_url TEXT;
ALTER TABLE psy_inventory_items ADD COLUMN IF NOT EXISTS print_file_size BIGINT;

-- 29 Okt 2026 — unit tukaran (issue_unit) supaya item boleh dibeli dlm unit besar
-- (cth Gulung) tapi diberi pesakit dlm unit kecil (cth Inci) tanpa tolak 1 Gulung
-- penuh setiap kali. qty_in_stock dilebarkan ke 4dp (asal 2dp) sebab deduct pecahan
-- (cth 1/30 Gulung = 0.0333) akan terkumpul ralat bundaran ketara kalau cuma 2dp.
ALTER TABLE psy_inventory_items DROP CONSTRAINT IF EXISTS psy_inventory_items_unit_check;
ALTER TABLE psy_inventory_items ADD CONSTRAINT psy_inventory_items_unit_check
  CHECK (unit IN ('Biji (pcs)','Botol','Kotak','Pek','Tiub','Tablet',
                   'Kapsul','Set','Gulung','Beg','Pasang','Unit','Gram','Kg','Naskhah','Gelas',
                   'Liter (L)','Mililiter (ml)','Inci (inch)','Sentimeter (cm)','Milimeter (mm)'));
ALTER TABLE psy_inventory_items ADD COLUMN IF NOT EXISTS issue_unit TEXT
  CHECK (issue_unit IS NULL OR issue_unit IN ('Biji (pcs)','Botol','Kotak','Pek','Tiub','Tablet',
                   'Kapsul','Set','Gulung','Beg','Pasang','Unit','Gram','Kg','Naskhah','Gelas',
                   'Liter (L)','Mililiter (ml)','Inci (inch)','Sentimeter (cm)','Milimeter (mm)'));
ALTER TABLE psy_inventory_items ADD COLUMN IF NOT EXISTS issue_units_per_stock_unit NUMERIC(10,4);
ALTER TABLE psy_inventory_items ALTER COLUMN qty_in_stock TYPE NUMERIC(12,4);
-- NOTA: psy_inventory_stock_by_location.qty_in_stock & psy_stock_movements.qty/balance_after
-- turut dilebarkan ke NUMERIC(12,4) — lihat ALTER COLUMN TYPE di 34_inventory_locations.sql
-- & 36_stock_movements.sql (jadual tu ditakrif SELEPAS fail ni, jadi ALTER kena di sana).
COMMENT ON COLUMN psy_inventory_items.issue_unit IS
  'Unit diberi kepada pesakit, jika berbeza drpd unit stok (cth stok=Gulung, issue_unit=Inci). NULL = tiada tukaran.';
COMMENT ON COLUMN psy_inventory_items.issue_units_per_stock_unit IS
  'Berapa issue_unit dalam 1 unit stok (cth 30 = 1 Gulung ada 30 Inci). Guna utk tukar kuantiti diberi pesakit kpd pecahan unit stok semasa tolak.';

-- status: peringkat lebih halus drpd is_active — 'discontinued' bermaksud dibuang
-- kekal (bukan cuma nyahaktif sementara). is_active DIKEKALKAN (banyak tempat lain
-- guna .eq('is_active', true) utk senarai produk boleh-pilih) — status='inactive'
-- ATAU 'discontinued' kedua-duanya set is_active=false, cuma UI Products list boleh
-- bezakan sebab & papar label yang betul.
ALTER TABLE psy_inventory_items ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'active'
  CHECK (status IN ('active','inactive','discontinued'));
UPDATE psy_inventory_items SET status = CASE WHEN is_active = false THEN 'inactive' ELSE 'active' END
  WHERE status = 'active' AND is_active = false;

-- auto_reorder_enabled dibuang — trigger auto-request tak pernah check flag ni,
-- sistem auto-cipta permintaan beli utk semua item bila stok rendah tanpa syarat.
ALTER TABLE psy_inventory_items DROP COLUMN IF EXISTS auto_reorder_enabled;

CREATE INDEX IF NOT EXISTS idx_inventory_items_source_type ON psy_inventory_items(source_type);
CREATE INDEX IF NOT EXISTS idx_inventory_items_is_active ON psy_inventory_items(is_active);

-- ──── item_code auto-generate (INV-01, INV-02, ... INV-99, INV-100) ────
CREATE SEQUENCE IF NOT EXISTS psy_inventory_item_code_seq START 1;

CREATE OR REPLACE FUNCTION psy_inventory_format_code(n BIGINT)
RETURNS TEXT
LANGUAGE sql IMMUTABLE
AS $$ SELECT 'INV-' || CASE WHEN n < 10 THEN '0' || n::text ELSE n::text END $$;

CREATE OR REPLACE FUNCTION psy_inventory_set_item_code()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.item_code IS NULL THEN
    NEW.item_code := psy_inventory_format_code(nextval('psy_inventory_item_code_seq'));
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_psy_inventory_set_item_code ON psy_inventory_items;
CREATE TRIGGER trg_psy_inventory_set_item_code
BEFORE INSERT ON psy_inventory_items
FOR EACH ROW EXECUTE FUNCTION psy_inventory_set_item_code();

-- Jujukan seterusnya bermula selepas nombor INV tertinggi sedia ada
SELECT setval('psy_inventory_item_code_seq',
  COALESCE((SELECT max(substring(item_code FROM 5)::bigint) FROM psy_inventory_items WHERE item_code ~ '^INV-[0-9]+$'), 0) + 1,
  false);

-- Beri kod kepada item yang belum ada, ikut tarikh dicipta
DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN SELECT id FROM psy_inventory_items WHERE item_code IS NULL ORDER BY created_at, id LOOP
    UPDATE psy_inventory_items
      SET item_code = psy_inventory_format_code(nextval('psy_inventory_item_code_seq'))
      WHERE id = r.id;
  END LOOP;
END $$;

-- RLS
ALTER TABLE psy_inventory_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff read inventory items" ON psy_inventory_items;
CREATE POLICY "Staff read inventory items" ON psy_inventory_items
  FOR SELECT USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "Admin manage inventory items" ON psy_inventory_items;
CREATE POLICY "Admin manage inventory items" ON psy_inventory_items
  FOR ALL USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff' AND staff_role IN ('super_admin','admin','manager')))
  WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff' AND staff_role IN ('super_admin','admin','manager')));

-- Komen
COMMENT ON COLUMN psy_inventory_items.max_qty IS
  'Saiz stok penuh / target. Trigger auto-PO bila qty_in_stock <= 30% dari max_qty.';
COMMENT ON COLUMN psy_inventory_items.auto_reorder_qty IS
  'Kuantiti yang sistem cadang dalam auto-PO. Default: max_qty - qty_in_stock.';
COMMENT ON COLUMN psy_inventory_items.last_auto_po_at IS
  'Tarikh auto-PO terakhir dijana — elak duplikat dalam tempoh pendek.';
COMMENT ON COLUMN psy_inventory_items.consumption_type IS
  'package = bekalan pakej (dynamic auto-calc); service = guna semasa service one-off; general = consumable umum (manual min sahaja).';
COMMENT ON COLUMN psy_inventory_items.supplier_info IS
  'Format: { name, pic_name, phone, email, address, payment_terms, cost_per_unit }. Maklumat pembekal.';
COMMENT ON COLUMN psy_inventory_items.item_code IS
  'Kod item auto-generate (INV-01, ...) via trigger — tidak boleh diedit.';
COMMENT ON COLUMN psy_inventory_items.is_active IS
  'false = item tidak aktif — disorok dari senarai pilihan (dispens/kit/jadual pakej) & auto-request.';
COMMENT ON COLUMN psy_inventory_items.print_file_url IS
  'Fail PDF print-ready (cth reka bentuk brochure) — dicetak terus dari inventory-detail.html bila restock.';
COMMENT ON COLUMN psy_inventory_items.reorder_threshold_pct IS
  'Peratus keperluan bulanan (dynamic_monthly) yang trigger status "Stok Rendah" utk item source_type=package. NULL = guna default sistem 30%.';
COMMENT ON COLUMN psy_inventory_items.manufacturer IS
  'Pengilang produk. Relevan utk source_type=farmasi_klinikal.';
COMMENT ON COLUMN psy_inventory_items.registration_no IS
  'No. pendaftaran/produk (cth MAL number). Relevan utk source_type=farmasi_klinikal.';
COMMENT ON COLUMN psy_inventory_items.storage_location IS
  'Lokasi simpanan fizikal (cth: Bilik Farmasi Rak 2). Relevan utk source_type=farmasi_klinikal.';
COMMENT ON COLUMN psy_inventory_items.storage_condition IS
  'Syarat simpanan (cth: Sejuk 2-8°C, Elak Cahaya). Relevan utk source_type=farmasi_klinikal.';
COMMENT ON COLUMN psy_inventory_items.source_type IS
  'farmasi_klinikal = ubat/bekalan perubatan (perlu batch_no/expiry_date, dispensing direkod di psy_supply_disbursements); am = inventori am/coaching/marketing. Default am.';
COMMENT ON COLUMN psy_inventory_items.batch_no IS
  'No. batch pembekal. Relevan hanya untuk item source_type=farmasi_klinikal.';
COMMENT ON COLUMN psy_inventory_items.expiry_date IS
  'Tarikh luput batch semasa. Relevan hanya untuk item source_type=farmasi_klinikal.';

-- ──── psy_inventory_requests ────
-- Header sahaja (banyak produk setiap permohonan — lihat psy_inventory_request_items).
-- Sebelum ni 1 request = 1 item (item_id/item_name/qty_requested/unit_price terus di
-- header); ditukar jadi multi-item macam psy_purchase_orders supaya konsisten.
CREATE TABLE IF NOT EXISTS psy_inventory_requests (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  request_no        TEXT UNIQUE,
  reason            TEXT,
  priority          TEXT NOT NULL DEFAULT 'sederhana'
                    CHECK (priority IN ('tinggi','sederhana','rendah')),
  status            TEXT NOT NULL DEFAULT 'pending_approval'
                    CHECK (status IN ('pending_approval','approved','partially_received','rejected','purchased')),
  subtotal          NUMERIC(12,2) NOT NULL DEFAULT 0,
  tax_amount        NUMERIC(12,2) NOT NULL DEFAULT 0,
  total_amount      NUMERIC(12,2) NOT NULL DEFAULT 0,
  requested_by      UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  requested_by_name TEXT NOT NULL DEFAULT '',
  requested_by_staff_code TEXT,
  approved_by       UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  approved_at       TIMESTAMPTZ,
  rejected_reason   TEXT,
  purchased_at      TIMESTAMPTZ,
  is_auto_generated BOOLEAN DEFAULT false,
  created_at        TIMESTAMPTZ DEFAULT now(),
  updated_at        TIMESTAMPTZ DEFAULT now()
);

-- ──── Line items (satu permohonan boleh ada banyak produk) ────
CREATE TABLE IF NOT EXISTS psy_inventory_request_items (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id     UUID NOT NULL REFERENCES psy_inventory_requests(id) ON DELETE CASCADE,
  item_id        UUID REFERENCES psy_inventory_items(id) ON DELETE SET NULL,
  item_name      TEXT NOT NULL,
  qty_requested  NUMERIC(10,2) NOT NULL,
  -- Kumulatif kuantiti item ni yang dah sampai (merentas berbilang Stock In jika
  -- supplier hantar berperingkat). Baki belum sampai = qty_requested - qty_received.
  qty_received   NUMERIC(10,2) NOT NULL DEFAULT 0,
  unit_price     NUMERIC(10,2) NOT NULL DEFAULT 0,
  subtotal       NUMERIC(12,2) NOT NULL DEFAULT 0,
  created_at     TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_inv_request_items_request ON psy_inventory_request_items(request_id);

-- ──── Dokumen lampiran (invois/resit pembelian) — boleh ditambah masa cipta
-- permohonan atau lepas tu (lazimnya invois/resit hanya ada lepas beli).
CREATE TABLE IF NOT EXISTS psy_inventory_request_attachments (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id        UUID NOT NULL REFERENCES psy_inventory_requests(id) ON DELETE CASCADE,
  file_name         TEXT NOT NULL,
  file_path         TEXT NOT NULL,
  file_size         BIGINT,
  file_type         TEXT,
  uploaded_by       UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  uploaded_by_name  TEXT,
  created_at        TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_inv_request_attachments_request ON psy_inventory_request_attachments(request_id);

-- ──── request_no auto-generate (PR-00001, PR-00002, ...) ────
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

-- Backfill request_no utk baris sedia ada (install lama) — susun ikut created_at.
DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN SELECT id FROM psy_inventory_requests WHERE request_no IS NULL ORDER BY created_at LOOP
    UPDATE psy_inventory_requests
      SET request_no = 'PR-' || LPAD(nextval('psy_inventory_request_no_seq')::text, 5, '0')
      WHERE id = r.id;
  END LOOP;
END $$;

COMMENT ON COLUMN psy_inventory_requests.request_no IS
  'Nombor rujukan permohonan auto-generate (PR-00001, ...) via trigger — tidak boleh diedit.';
COMMENT ON COLUMN psy_inventory_requests.priority IS
  'Keutamaan pembelian: tinggi/sederhana/rendah. Default sederhana — staff boleh naikkan bila mendesak.';

-- RLS
ALTER TABLE psy_inventory_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff read all requests" ON psy_inventory_requests;
CREATE POLICY "Staff read all requests" ON psy_inventory_requests
  FOR SELECT USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "Staff insert own requests" ON psy_inventory_requests;
CREATE POLICY "Staff insert own requests" ON psy_inventory_requests
  FOR INSERT WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "Manager admin update requests" ON psy_inventory_requests;
CREATE POLICY "Manager admin update requests" ON psy_inventory_requests
  FOR UPDATE USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff' AND staff_role IN ('admin','manager')));

ALTER TABLE psy_inventory_request_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff manage request items" ON psy_inventory_request_items;
CREATE POLICY "Staff manage request items" ON psy_inventory_request_items FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

ALTER TABLE psy_inventory_request_attachments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff manage request attachments" ON psy_inventory_request_attachments;
CREATE POLICY "Staff manage request attachments" ON psy_inventory_request_attachments FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

COMMENT ON COLUMN psy_inventory_requests.is_auto_generated IS
  'true = dijana automatik oleh checkAutoPO() (shared/inventoryForecast.js), false = manual request oleh staff.';

-- Auto-request bila stok rendah dikendalikan client-side (checkAutoPO() di inventory.html,
-- guna shared/inventoryForecast.js) — BUKAN trigger DB. Trigger lama psy_inventory_auto_request()
-- dibuang (lihat supabase/migrations/20260829_drop_inventory_auto_po_trigger.sql) sebab guna
-- medan `max_qty` yang tak pernah diisi di mana-mana borang (sentiasa NULL), jadi ia sentiasa
-- fallback ke min_qty untuk SEMUA item — tak selaras & duplicate logik dgn client-side.

-- ──── psy_products ────
CREATE TABLE IF NOT EXISTS psy_products (
  id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id         TEXT UNIQUE NOT NULL,
  name               TEXT NOT NULL,
  description        TEXT,
  description_short  TEXT,
  category           TEXT,
  sku                TEXT,
  brand              TEXT,
  price              NUMERIC(10,2) DEFAULT 0,
  promo_price        NUMERIC(10,2),
  promo_until        DATE,
  stock              INT,
  min_stock          INT DEFAULT 5,
  unit               TEXT DEFAULT 'Unit'
                     CHECK (unit IN ('Biji (pcs)','Botol','Kotak','Pek','Tiub','Tablet',
                                     'Kapsul','Set','Gulung','Beg','Pasang','Unit','Gram','Kg','Naskhah','Gelas')),
  track_inventory    BOOLEAN DEFAULT true,
  low_stock_alert    BOOLEAN DEFAULT true,
  inventory_item_id  UUID REFERENCES psy_inventory_items(id) ON DELETE SET NULL,
  icon               TEXT DEFAULT '📦',
  bg_color           TEXT DEFAULT 'bg-cream',
  image_url          TEXT,
  image_urls         JSONB DEFAULT '[]',
  weight_size        TEXT,
  supplier           TEXT,
  tags               JSONB DEFAULT '[]',
  notes              TEXT,
  status             TEXT DEFAULT 'active',
  is_active          BOOLEAN DEFAULT true,
  visible_in_shop    BOOLEAN DEFAULT true,
  featured           BOOLEAN DEFAULT false,
  online_purchase    BOOLEAN DEFAULT true,
  sort_order         INT DEFAULT 0,
  created_at         TIMESTAMPTZ DEFAULT now(),
  updated_at         TIMESTAMPTZ DEFAULT now()
);

-- RLS
ALTER TABLE psy_products ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone read products" ON psy_products;
CREATE POLICY "Anyone read products" ON psy_products FOR SELECT USING (true);

DROP POLICY IF EXISTS "Staff manage products" ON psy_products;
CREATE POLICY "Staff manage products" ON psy_products
  FOR ALL USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- Komen
COMMENT ON COLUMN psy_products.inventory_item_id IS
  'Link ke inventory item. Bila order status=paid, qty_in_stock auto-deduct ikut quantity dibeli.';
COMMENT ON COLUMN psy_products.image_url IS
  'URL gambar utama produk (single). Untuk gallery multi-gambar, guna image_urls (JSONB array).';

-- ──── Fungsi: auto-deduct inventori bila order paid ────
-- Trigger function untuk jadual order (items JSONB: [{product_id, qty, ...}]).
CREATE OR REPLACE FUNCTION psy_order_deduct_inventory()
RETURNS TRIGGER AS $$
DECLARE
  v_item       JSONB;
  v_product    psy_products%ROWTYPE;
  v_qty        NUMERIC;
BEGIN
  IF NEW.status = 'paid' AND (OLD.status IS DISTINCT FROM 'paid') THEN
    FOR v_item IN SELECT * FROM jsonb_array_elements(COALESCE(NEW.items, '[]'::jsonb))
    LOOP
      -- Match by product_id (text id) atau id (UUID) — support kedua-dua format
      SELECT * INTO v_product FROM psy_products
        WHERE product_id = v_item->>'product_id'
           OR id::text   = v_item->>'product_id'
        LIMIT 1;

      IF v_product.inventory_item_id IS NOT NULL THEN
        v_qty := COALESCE((v_item->>'qty')::numeric, (v_item->>'quantity')::numeric, 1);
        UPDATE psy_inventory_items
          SET qty_in_stock = GREATEST(0, qty_in_stock - v_qty),
              updated_at   = now()
          WHERE id = v_product.inventory_item_id;
      END IF;
    END LOOP;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger pada psy_orders (jadual dari 06_payments.sql) — diletak di sini
-- kerana fungsinya ditakrif di atas.
DROP TRIGGER IF EXISTS trg_psy_order_deduct_inventory ON psy_orders;
CREATE TRIGGER trg_psy_order_deduct_inventory
  AFTER UPDATE ON psy_orders
  FOR EACH ROW EXECUTE FUNCTION psy_order_deduct_inventory();

-- ──── psy_procedure_kits ────
-- Satu kit = set item inventori untuk satu prosedur (cth: IV Drip Setup).
CREATE TABLE IF NOT EXISTS psy_procedure_kits (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name         TEXT NOT NULL UNIQUE,
  description  TEXT,
  category     TEXT DEFAULT 'Umum',
  items        JSONB NOT NULL DEFAULT '[]'::jsonb,
  is_active    BOOLEAN DEFAULT true,
  created_by   UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  created_at   TIMESTAMPTZ DEFAULT now(),
  updated_at   TIMESTAMPTZ DEFAULT now()
);

COMMENT ON COLUMN psy_procedure_kits.items IS
  'Format: [{item_id, item_name, qty, unit}]. Senarai inventory item yang diperlukan per satu prosedur.';

-- RLS
ALTER TABLE psy_procedure_kits ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff manage kits" ON psy_procedure_kits;
CREATE POLICY "Staff manage kits" ON psy_procedure_kits FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- Baca sahaja utk pesakit (audit #144c) — roles/patient/plan-week.html perlu padan nama
-- item Bekalan dgn kit prosedur utk auto-collapse paparan "🧰 Nama Prosedur (N item)".
-- Data tak sensitif (nama kit + nama item generik), ikut corak baca-terbuka sedia ada
-- (cth psy_library_categories/psy_faq_items FOR SELECT USING (true)).
DROP POLICY IF EXISTS "Read active procedure kits" ON psy_procedure_kits;
CREATE POLICY "Read active procedure kits" ON psy_procedure_kits FOR SELECT
  USING (is_active = true);

-- ──── psy_bottle_returns ────
-- Permohonan pulangan botol madu oleh pesakit.
CREATE TABLE IF NOT EXISTS psy_bottle_returns (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id           UUID REFERENCES psy_patients(id) ON DELETE CASCADE NOT NULL,
  patient_name         TEXT NOT NULL,
  qty                  INT NOT NULL CHECK (qty > 0),
  photo_urls           TEXT[] DEFAULT '{}',
  criteria_confirmed   JSONB NOT NULL DEFAULT '{}',
  notes                TEXT,
  status               TEXT NOT NULL DEFAULT 'pending'
                       CHECK (status IN ('pending','received','rejected')),
  reject_reason        TEXT,
  verified_by          UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  verified_by_name     TEXT,
  verified_at          TIMESTAMPTZ,
  created_at           TIMESTAMPTZ DEFAULT now(),
  updated_at           TIMESTAMPTZ DEFAULT now()
);

-- Indeks
CREATE INDEX IF NOT EXISTS idx_bottle_returns_patient ON psy_bottle_returns(patient_id);
CREATE INDEX IF NOT EXISTS idx_bottle_returns_status  ON psy_bottle_returns(status, created_at DESC);

-- RLS
ALTER TABLE psy_bottle_returns ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Patient manage own returns" ON psy_bottle_returns;
CREATE POLICY "Patient manage own returns" ON psy_bottle_returns
  FOR ALL USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()))
  WITH CHECK (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Staff read all returns" ON psy_bottle_returns;
CREATE POLICY "Staff read all returns" ON psy_bottle_returns
  FOR SELECT USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "Staff update returns" ON psy_bottle_returns;
CREATE POLICY "Staff update returns" ON psy_bottle_returns
  FOR UPDATE USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- Komen
COMMENT ON TABLE psy_bottle_returns IS
  'Permohonan pulangan botol madu patient. Chat thread guna psy_audit_log dengan meta.return_id.';
COMMENT ON COLUMN psy_bottle_returns.criteria_confirmed IS
  'JSONB: {tidak_berkarat, bersih, getah_ada, besi_kemas} - semua mesti true sebelum patient boleh submit.';
COMMENT ON COLUMN psy_bottle_returns.photo_urls IS
  'Array URL foto bukti botol (boleh upload multiple).';

-- ═══════════════════════════════════════════════════════════════════
-- DATA RUJUKAN (SEED)
-- ═══════════════════════════════════════════════════════════════════

-- ──── Seed: produk kedai ────
INSERT INTO psy_products (product_id, name, description, category, price, icon, bg_color, sort_order) VALUES
  ('madu-shifa-500g',  'Madu Shifa 500g',        'Pure raw honey · acacia',            'Madu',           85,  '🍯', 'bg-gold-light',       1),
  ('madu-kelulut',     'Madu Kelulut 400g',       'Stingless bee honey',                'Madu',          120,  '🍯', 'bg-gold-light',       2),
  ('jus-halia',        'Jus Halia Concentrate',   '250ml · 100% natural',               'Herba',          45,  '🌿', 'bg-green-light',      3),
  ('herba-zaitun',     'Minyak Zaitun Tulen',     '500ml · cold-pressed',               'Herba',          65,  '🫒', 'bg-green-light',      4),
  ('magnesium',        'Magnesium Glycinate',      '60 caps · 200mg',                    'Supplements',    55,  '💊', 'bg-navy-light',       5),
  ('vitamin-d',        'Vitamin D3 5000IU',        '90 softgels',                        'Supplements',    48,  '☀️', 'bg-gold-light',       6),
  ('santapan-fitrah',  'Santapan Fitrah Set',      '7-day starter pack',                 'Santapan Fitrah',220, '🌱', 'bg-terracotta-light', 7),
  ('rahsia-syifa',     'Rahsia Syifa Book',        'Ibn Sina & modern med',              'Books',          35,  '📖', 'bg-navy-light',       8),
  ('doa-syifa-book',   'Kitab Doa Syifa',          'Tafsir + transliterasi',             'Books',          28,  '📖', 'bg-terracotta-light', 9)
ON CONFLICT (product_id) DO NOTHING;

-- ──── Seed: item inventori lalai ISW (IDEMPOTEN — insert HANYA kalau nama belum
-- wujud, TAK PERNAH padam baris sedia ada). SEBELUM NI fail ni ada "DELETE FROM
-- psy_inventory_items;" tanpa skop di atas INSERT — setiap kali schema/migration
-- ni di-run, SEMUA item sebenar (stok+ID) dipadam & diganti BARIS INI SAHAJA dgn
-- UUID RAWAK baharu. psy_inventory_items.id dirujuk sbg snapshot di BANYAK tempat
-- (coaching_schedule pakej, psy_stock_movements, psy_supply_invoices, kob_default_
-- supplies) — padam+insert semula = SEMUA rujukan tu jadi yatim SENYAP (tiada
-- error, cuma potong stok/invois bekalan senyap tak pernah berfungsi). Insiden ni
-- disahkan punca 100% rujukan item_id pakej jadi yatim (20 Okt 2026) — lihat
-- [[project_inventory_seed_destructive_delete]]. JANGAN tambah DELETE FROM balik
-- kat sini.
INSERT INTO psy_inventory_items (name, category, unit, qty_in_stock, min_qty, requires_approval, notes)
SELECT v.name, v.category, v.unit, v.qty_in_stock, v.min_qty, v.requires_approval, v.notes
FROM (VALUES

-- ── MADU & PRODUK ─────────────────────────────────────────
('Lebah Thoharah (LTH)',            'Madu & Produk', 'Kg',     0, 5,  false, 'Program NLC / JS / JS+ / EOL'),
('LTH Plus Green (LTHPG)',          'Madu & Produk', 'Kg',     0, 5,  false, 'Program NLC / JS / JS+ / EOL'),
('Ibu Bumi (IB)',                   'Madu & Produk', 'Kg',     0, 5,  false, 'Program OBD / OBP'),
('Young & Healthy Plus Green (YHPG)','Madu & Produk','Kg',     0, 5,  false, 'Program OBD / OBP'),
('Madu Kelulut',                    'Madu & Produk', 'Botol',  0, 3,  false, NULL),
('Minyak Zaitun Tulen',             'Madu & Produk', 'Botol',  0, 3,  false, NULL),

-- ── STARTER KIT ───────────────────────────────────────────
('SDS OB',                          'Starter Kit',   'Unit',   0, 5,  false, 'Starter kit OBD / OBP'),
('GHF',                             'Starter Kit',   'Unit',   0, 5,  false, 'Starter kit OBD / OBP'),
('BNP',                             'Starter Kit',   'Unit',   0, 5,  false, 'Bekalan pantang NLC / JS'),
('NSS',                             'Starter Kit',   'Unit',   0, 5,  false, 'Bekalan pantang NLC / JS'),
('Voucher Konsultasi',              'Starter Kit',   'Unit',   0, 10, false, 'Diedarkan semasa onboarding'),

-- ── SUPLEMEN & RESEPI ─────────────────────────────────────
('Resepi Superimun',                'Suplemen & Resepi', 'Unit', 0, 5, false, 'Diberi semasa onboarding'),
('Resepi Superenergi',              'Suplemen & Resepi', 'Unit', 0, 5, false, 'Diberi semasa onboarding'),
('Barley Organik',                  'Suplemen & Resepi', 'Kg',   0, 5, false, NULL),
('Spirulina',                       'Suplemen & Resepi', 'Botol',0, 3, false, NULL),
('Probiotik Advanced',              'Suplemen & Resepi', 'Botol',0, 3, false, NULL),
('Magnesium Glycinate',             'Suplemen & Resepi', 'Botol',0, 3, false, NULL),
('Vitamin D3',                      'Suplemen & Resepi', 'Botol',0, 3, false, NULL),
('Omega-3 Fish Oil',                'Suplemen & Resepi', 'Botol',0, 3, false, NULL),

-- ── BUKU & BAHAN CETAK ────────────────────────────────────
('Buku P101',                       'Buku & Bahan Cetak', 'Naskhah', 0, 10, false, '7 buku per set starter kit'),
('List Pantang',                    'Buku & Bahan Cetak', 'Naskhah', 0, 10, false, 'Diedarkan semasa onboarding'),
('Peta OB',                         'Buku & Bahan Cetak', 'Naskhah', 0, 10, false, 'Diedarkan semasa onboarding OBD / OBP'),
('Workbook Refleksi Harian',        'Buku & Bahan Cetak', 'Naskhah', 0, 10, false, NULL),
('Jadual Terapi Mingguan',          'Buku & Bahan Cetak', 'Naskhah', 0, 10, false, NULL),
('Mood Tracker',                    'Buku & Bahan Cetak', 'Naskhah', 0, 10, false, NULL),
('Buku Gaya Hidup Fitrah',          'Buku & Bahan Cetak', 'Naskhah', 0,  5, false, NULL),
('Kitab Doa Syifa',                 'Buku & Bahan Cetak', 'Naskhah', 0,  5, false, NULL),

-- ── BROSUR & MARKETING ────────────────────────────────────
('Brochure Madu',                   'Brosur & Marketing', 'Unit', 0, 20, false, NULL),
('Brochure ISW',                    'Brosur & Marketing', 'Unit', 0, 20, false, NULL),
('Brochure OB',                     'Brosur & Marketing', 'Unit', 0, 20, false, NULL),

-- ── BEKALAN COACHING ──────────────────────────────────────
('Air Afiyah',                      'Bekalan Coaching', 'Botol', 0, 10, false, '1 botol = 1.5L'),
('Air Za''afaran',                  'Bekalan Coaching', 'Botol', 0,  5, false, 'Untuk sesi Perubatan Rohani'),
('Herba Kolon',                     'Bekalan Coaching', 'Set',   0,  3, false, '1 set = 1 kursus rawatan'),
('Kurma Ajwa',                      'Bekalan Coaching', 'Biji (pcs)',  0, 50, false, '49 biji per pesakit 777 VIP'),

-- ── PERALATAN KLINIK ──────────────────────────────────────
('DNA Test Kit',                    'Peralatan Klinik', 'Set',  0, 2, true,  'Perlu kelulusan · hantar ke lab luar'),
('Enema Kit',                       'Peralatan Klinik', 'Set',  0, 3, true,  'Perlu kelulusan'),
('Mesin Ozon',                      'Peralatan Klinik', 'Unit', 0, 1, true,  'Rekod nombor siri setiap unit'),
('Alcohol Swab',                    'Peralatan Klinik', 'Pek',  0, 10, false, NULL),
('Cotton Ball',                     'Peralatan Klinik', 'Pek',  0, 10, false, NULL),
('Intravenous (IV) Infusion Set',   'Peralatan Klinik', 'Set',  0, 5,  false, NULL),
('Normal Saline (NS)',              'Peralatan Klinik', 'Botol',0, 5,  false, NULL),

-- ── BUKU & BAHAN CETAK (tambahan 20 Okt 2026 — susulan item yatim) ────────
('P101 Jilid 1',                    'Buku & Bahan Cetak', 'Naskhah', 0, 10, false, NULL),
('P101 Jilid 2',                    'Buku & Bahan Cetak', 'Naskhah', 0, 10, false, NULL),
('P101 Jilid 3',                    'Buku & Bahan Cetak', 'Naskhah', 0, 10, false, NULL),
('P101 Jilid 4',                    'Buku & Bahan Cetak', 'Naskhah', 0, 10, false, NULL),
('P101 Jilid 5',                    'Buku & Bahan Cetak', 'Naskhah', 0, 10, false, NULL),
('P101 Jilid 6',                    'Buku & Bahan Cetak', 'Naskhah', 0, 10, false, NULL),
('P101 Jilid 7',                    'Buku & Bahan Cetak', 'Naskhah', 0, 10, false, NULL),
('Biopsychosocial-Spiritual (BPS-S)', 'Buku & Bahan Cetak', 'Naskhah', 0, 10, false, NULL),
('Panduan Peminuman Madu (IB & YHPG)', 'Buku & Bahan Cetak', 'Naskhah', 0, 10, false, NULL),
('Panduan Peminuman Madu (LTH & LTHPG)', 'Buku & Bahan Cetak', 'Naskhah', 0, 10, false, NULL),
('Panduan Pengamalan Zikir Bersanad', 'Buku & Bahan Cetak', 'Naskhah', 0, 10, false, NULL),

-- ── STARTER KIT (tambahan 20 Okt 2026) ────────────────────
('Akses Portal ISW',                'Starter Kit', 'Unit', 0, 10, false, 'Diedarkan semasa onboarding'),
('BNP & NSS Pesakit Gastrik, Gerd, Radang Usus, Sembelit', 'Starter Kit', 'Unit', 0, 5, false, NULL)

) AS v(name, category, unit, qty_in_stock, min_qty, requires_approval, notes)
WHERE NOT EXISTS (SELECT 1 FROM psy_inventory_items existing WHERE existing.name = v.name);

-- ──── Seed: contoh kit prosedur ────
INSERT INTO psy_procedure_kits (name, description, category, items) VALUES
(
  'IV Drip Setup',
  'Set lengkap untuk satu sesi IV Saline Drip',
  'IV Therapy',
  '[
    {"item_id": null, "item_name": "IV Line",       "qty": 1, "unit": "Unit"},
    {"item_id": null, "item_name": "Gloves",         "qty": 2, "unit": "Pasang"},
    {"item_id": null, "item_name": "Alcohol Swab",   "qty": 3, "unit": "Unit"},
    {"item_id": null, "item_name": "Cotton Ball",    "qty": 2, "unit": "Unit"},
    {"item_id": null, "item_name": "Branula",        "qty": 1, "unit": "Unit"},
    {"item_id": null, "item_name": "Plaster",        "qty": 2, "unit": "Unit"},
    {"item_id": null, "item_name": "Scotch Tape",    "qty": 1, "unit": "Unit"}
  ]'::jsonb
),
(
  'Blood Test Setup',
  'Set lengkap untuk pengambilan darah',
  'Diagnostik',
  '[
    {"item_id": null, "item_name": "Gloves",         "qty": 1, "unit": "Pasang"},
    {"item_id": null, "item_name": "Alcohol Swab",   "qty": 2, "unit": "Unit"},
    {"item_id": null, "item_name": "Cotton Ball",    "qty": 2, "unit": "Unit"},
    {"item_id": null, "item_name": "Needle/Vacutainer","qty": 1, "unit": "Unit"},
    {"item_id": null, "item_name": "Plaster",        "qty": 1, "unit": "Unit"},
    {"item_id": null, "item_name": "Blood Tube",     "qty": 3, "unit": "Tiub"}
  ]'::jsonb
),
(
  'DNA Test Setup',
  'Set untuk pengambilan sampel DNA (buccal swab)',
  'Diagnostik',
  '[
    {"item_id": null, "item_name": "Gloves",         "qty": 1, "unit": "Pasang"},
    {"item_id": null, "item_name": "DNA Swab",       "qty": 2, "unit": "Unit"},
    {"item_id": null, "item_name": "DNA Collection Tube", "qty": 1, "unit": "Unit"},
    {"item_id": null, "item_name": "Ziplock Bag",    "qty": 1, "unit": "Unit"}
  ]'::jsonb
)
ON CONFLICT DO NOTHING;

-- ──────────────────────────────────────────────────────────────
-- Pautan silang domain: psy_supply_disbursements (fail 07) → item inventori
-- ──────────────────────────────────────────────────────────────
ALTER TABLE psy_supply_disbursements DROP CONSTRAINT IF EXISTS psy_supply_disbursements_item_id_fkey;
ALTER TABLE psy_supply_disbursements ADD CONSTRAINT psy_supply_disbursements_item_id_fkey
  FOREIGN KEY (item_id) REFERENCES psy_inventory_items(id) ON DELETE SET NULL;

-- ──────────────────────────────────────────────────────────────
-- Shop ↔ Inventori: produk MESTI wujud di Inventori (aktif) baru boleh dijual.
-- Pesakit tak boleh SELECT psy_inventory_items — fungsi SECURITY DEFINER ini dedah status/stok sahaja.
-- (Backfill pautan FK ikut nama: lihat database/add_shop_inventory_link.sql)
-- ──────────────────────────────────────────────────────────────
-- ── 2. Status inventori setiap produk ────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION psy_shop_product_inventory()
RETURNS TABLE (
  product_id    TEXT,
  name          TEXT,
  linked        BOOLEAN,
  item_status   TEXT,
  qty_in_stock  NUMERIC,
  unit          TEXT,
  sellable      BOOLEAN
)
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    p.product_id::text,
    p.name,
    (i.id IS NOT NULL) AS linked,
    CASE WHEN i.id IS NULL THEN NULL
         ELSE COALESCE(to_jsonb(i)->>'status',
                       CASE WHEN to_jsonb(i)->>'is_active' = 'false' THEN 'inactive' ELSE 'active' END) END AS item_status,
    i.qty_in_stock,
    i.unit,
    (i.id IS NOT NULL
      AND COALESCE(to_jsonb(i)->>'status',
                   CASE WHEN to_jsonb(i)->>'is_active' = 'false' THEN 'inactive' ELSE 'active' END) = 'active') AS sellable
  FROM psy_products p
  LEFT JOIN psy_inventory_items i ON i.id = p.inventory_item_id;
$$;

GRANT EXECUTE ON FUNCTION psy_shop_product_inventory() TO authenticated, anon;

-- ── 3. Fungsi lama (dipakai payment.html versi terdahulu): produk yang TIDAK boleh dijual ─
CREATE OR REPLACE FUNCTION psy_shop_unavailable_products()
RETURNS TABLE (product_id TEXT, name TEXT)
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT s.product_id, s.name FROM psy_shop_product_inventory() s WHERE NOT s.sellable;
$$;

GRANT EXECUTE ON FUNCTION psy_shop_unavailable_products() TO authenticated, anon;

-- ──────────────────────────────────────────────────────────────
-- Produk Shop ikut status Inventori secara automatik (sama dgn migration 20261006_shop_product_follow_inventory.sql)
-- ──────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION psy_inv_item_is_inactive(p_row JSONB)
RETURNS BOOLEAN LANGUAGE sql IMMUTABLE AS $$
  SELECT COALESCE(p_row->>'status',
                  CASE WHEN p_row->>'is_active' = 'false' THEN 'inactive' ELSE 'active' END) <> 'active'
$$;

CREATE OR REPLACE FUNCTION psy_sync_shop_products_on_inventory_change()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF psy_inv_item_is_inactive(to_jsonb(NEW)) THEN
    UPDATE psy_products
       SET is_active = false, status = 'inactive', updated_at = now()
     WHERE inventory_item_id = NEW.id
       AND (is_active IS DISTINCT FROM false OR status IS DISTINCT FROM 'inactive');
  END IF;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_sync_shop_products_on_inventory_change ON psy_inventory_items;
CREATE TRIGGER trg_sync_shop_products_on_inventory_change
  AFTER INSERT OR UPDATE ON psy_inventory_items
  FOR EACH ROW EXECUTE FUNCTION psy_sync_shop_products_on_inventory_change();

CREATE OR REPLACE FUNCTION psy_deactivate_shop_products_on_inventory_delete()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  UPDATE psy_products
     SET is_active = false, status = 'inactive', updated_at = now()
   WHERE inventory_item_id = OLD.id;
  RETURN OLD;
END $$;

DROP TRIGGER IF EXISTS trg_deactivate_shop_products_on_inventory_delete ON psy_inventory_items;
CREATE TRIGGER trg_deactivate_shop_products_on_inventory_delete
  BEFORE DELETE ON psy_inventory_items
  FOR EACH ROW EXECUTE FUNCTION psy_deactivate_shop_products_on_inventory_delete();

CREATE OR REPLACE FUNCTION psy_check_shop_product_link()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
  v_item JSONB;
BEGIN
  IF NEW.inventory_item_id IS NOT NULL THEN
    SELECT to_jsonb(i) INTO v_item FROM psy_inventory_items i WHERE i.id = NEW.inventory_item_id;
    IF v_item IS NOT NULL AND psy_inv_item_is_inactive(v_item) THEN
      NEW.is_active := false;
      NEW.status := 'inactive';
    END IF;
  END IF;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_check_shop_product_link ON psy_products;
CREATE TRIGGER trg_check_shop_product_link
  BEFORE INSERT OR UPDATE OF inventory_item_id ON psy_products
  FOR EACH ROW EXECUTE FUNCTION psy_check_shop_product_link();
