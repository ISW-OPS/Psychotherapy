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
  category             TEXT NOT NULL DEFAULT 'Bekalan Coaching',
  unit                 TEXT NOT NULL DEFAULT 'unit',
  qty_in_stock         NUMERIC(10,2) NOT NULL DEFAULT 0,
  min_qty              NUMERIC(10,2) NOT NULL DEFAULT 5,
  requires_approval    BOOLEAN NOT NULL DEFAULT false,
  notes                TEXT,
  max_qty              NUMERIC(10,2),
  auto_reorder_qty     NUMERIC(10,2),
  auto_reorder_enabled BOOLEAN DEFAULT false,
  last_auto_po_at      TIMESTAMPTZ,
  consumption_type     TEXT DEFAULT 'package'
                       CHECK (consumption_type IN ('package','service','general')),
  supplier_info        JSONB DEFAULT '{}'::jsonb,
  created_at           TIMESTAMPTZ DEFAULT now(),
  updated_at           TIMESTAMPTZ DEFAULT now()
);

-- RLS
ALTER TABLE psy_inventory_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff read inventory items" ON psy_inventory_items;
CREATE POLICY "Staff read inventory items" ON psy_inventory_items
  FOR SELECT USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "Admin manage inventory items" ON psy_inventory_items;
CREATE POLICY "Admin manage inventory items" ON psy_inventory_items
  FOR ALL USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff' AND staff_role IN ('admin','manager')));

-- Komen
COMMENT ON COLUMN psy_inventory_items.max_qty IS
  'Saiz stok penuh / target. Trigger auto-PO bila qty_in_stock <= 30% dari max_qty.';
COMMENT ON COLUMN psy_inventory_items.auto_reorder_qty IS
  'Kuantiti yang sistem cadang dalam auto-PO. Default: max_qty - qty_in_stock.';
COMMENT ON COLUMN psy_inventory_items.auto_reorder_enabled IS
  'true = auto-create purchase invoice bila stok rendah; false = manual sahaja.';
COMMENT ON COLUMN psy_inventory_items.last_auto_po_at IS
  'Tarikh auto-PO terakhir dijana — elak duplikat dalam tempoh pendek.';
COMMENT ON COLUMN psy_inventory_items.consumption_type IS
  'package = bekalan pakej (dynamic auto-calc); service = guna semasa service one-off; general = consumable umum (manual min sahaja).';
COMMENT ON COLUMN psy_inventory_items.supplier_info IS
  'Format: { name, cost_per_unit, lead_days, po_min, po_max }. Maklumat pembekal dan cadangan PO.';

-- ──── psy_inventory_requests ────
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
  is_auto_generated BOOLEAN DEFAULT false,
  created_at        TIMESTAMPTZ DEFAULT now(),
  updated_at        TIMESTAMPTZ DEFAULT now()
);

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

COMMENT ON COLUMN psy_inventory_requests.is_auto_generated IS
  'true = dijana automatik bila stok ≤ 30%, false = manual request oleh staff.';

-- ──── Trigger: auto-request bila stok rendah ────
-- Threshold: 30% dari max_qty (fallback: min_qty). Hormat requires_approval,
-- duplicate guard (request pending/approved sedia ada) + cooldown 24 jam.
CREATE OR REPLACE FUNCTION psy_inventory_auto_request()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_threshold       NUMERIC;
  v_existing_count  INT;
  v_reorder_qty     NUMERIC;
  v_status          TEXT;
  v_target          NUMERIC;
BEGIN
  -- Hanya bertindak bila qty_in_stock benar-benar berubah & turun
  IF NEW.qty_in_stock IS NULL OR NEW.qty_in_stock = OLD.qty_in_stock THEN
    RETURN NEW;
  END IF;
  IF NEW.qty_in_stock > OLD.qty_in_stock THEN
    RETURN NEW;  -- stok naik (restock) — jangan trigger
  END IF;

  -- Kira threshold
  IF NEW.max_qty IS NOT NULL AND NEW.max_qty > 0 THEN
    v_threshold := NEW.max_qty * 0.30;
  ELSE
    v_threshold := COALESCE(NEW.min_qty, 0);
  END IF;

  IF v_threshold <= 0 THEN
    RETURN NEW;
  END IF;

  IF NEW.qty_in_stock > v_threshold THEN
    RETURN NEW;  -- masih di atas threshold
  END IF;

  -- Cooldown 24 jam
  IF NEW.last_auto_po_at IS NOT NULL
     AND NEW.last_auto_po_at > now() - INTERVAL '24 hours' THEN
    RETURN NEW;
  END IF;

  -- Duplicate guard
  SELECT COUNT(*) INTO v_existing_count
  FROM psy_inventory_requests
  WHERE item_id = NEW.id
    AND status IN ('pending_approval', 'approved');

  IF v_existing_count > 0 THEN
    RETURN NEW;
  END IF;

  -- Kira reorder qty
  IF NEW.max_qty IS NOT NULL AND NEW.max_qty > 0 THEN
    v_target := NEW.max_qty;
  ELSE
    v_target := COALESCE(NEW.min_qty, 0) * 3;
  END IF;

  v_reorder_qty := COALESCE(NEW.auto_reorder_qty,
                            GREATEST(1, v_target - NEW.qty_in_stock));

  -- Tentukan status ikut requires_approval
  v_status := CASE
                WHEN COALESCE(NEW.requires_approval, false) THEN 'pending_approval'
                ELSE 'approved'
              END;

  INSERT INTO psy_inventory_requests (
    item_id, item_name, qty_requested, unit_price, total_amount,
    reason, status, requested_by, requested_by_name, is_auto_generated
  ) VALUES (
    NEW.id,
    NEW.name,
    v_reorder_qty,
    NULL,
    NULL,
    format('Auto-trigger: stok %s%s ≤ threshold %s%s. Sila beli %s%s.',
           NEW.qty_in_stock, COALESCE(NEW.unit, ''),
           ROUND(v_threshold, 2), COALESCE(NEW.unit, ''),
           v_reorder_qty, COALESCE(NEW.unit, '')),
    v_status,
    NULL,
    'Sistem (Auto)',
    true
  );

  -- Tanda cooldown
  NEW.last_auto_po_at := now();

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_psy_inventory_auto_request ON psy_inventory_items;
CREATE TRIGGER trg_psy_inventory_auto_request
BEFORE UPDATE OF qty_in_stock ON psy_inventory_items
FOR EACH ROW
EXECUTE FUNCTION psy_inventory_auto_request();

COMMENT ON FUNCTION psy_inventory_auto_request() IS
  'Auto-cipta inventory_request bila stok turun ≤ 30% max_qty (atau ≤ min_qty kalau max_qty tiada). Hormat requires_approval untuk status.';

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
  unit               TEXT DEFAULT 'unit',
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

-- ──── Seed: item inventori lalai ISW (re-seed penuh) ────
DELETE FROM psy_inventory_items;

INSERT INTO psy_inventory_items (name, category, unit, qty_in_stock, min_qty, requires_approval, notes)
VALUES

-- ── MADU & PRODUK ─────────────────────────────────────────
('Lebah Thoharah (LTH)',            'Madu & Produk', 'kg',     0, 5,  false, 'Program NLC / JS / JS+ / EOL'),
('LTH Plus Green (LTHPG)',          'Madu & Produk', 'kg',     0, 5,  false, 'Program NLC / JS / JS+ / EOL'),
('Ibu Bumi (IB)',                   'Madu & Produk', 'kg',     0, 5,  false, 'Program OBD / OBP'),
('Young & Healthy Plus Green (YHPG)','Madu & Produk','kg',     0, 5,  false, 'Program OBD / OBP'),
('Madu Kelulut',                    'Madu & Produk', 'botol',  0, 3,  false, NULL),
('Minyak Zaitun Tulen',             'Madu & Produk', 'botol',  0, 3,  false, NULL),

-- ── STARTER KIT ───────────────────────────────────────────
('SDS OB',                          'Starter Kit',   'unit',   0, 5,  false, 'Starter kit OBD / OBP'),
('GHF',                             'Starter Kit',   'unit',   0, 5,  false, 'Starter kit OBD / OBP'),
('BNP',                             'Starter Kit',   'unit',   0, 5,  false, 'Bekalan pantang NLC / JS'),
('NSS',                             'Starter Kit',   'unit',   0, 5,  false, 'Bekalan pantang NLC / JS'),
('Voucher Konsultasi',              'Starter Kit',   'unit',   0, 10, false, 'Diedarkan semasa onboarding'),

-- ── SUPLEMEN & RESEPI ─────────────────────────────────────
('Resepi Superimun',                'Suplemen & Resepi', 'unit', 0, 5, false, 'Diberi semasa onboarding'),
('Resepi Superenergi',              'Suplemen & Resepi', 'unit', 0, 5, false, 'Diberi semasa onboarding'),
('Barley Organik',                  'Suplemen & Resepi', 'kg',   0, 5, false, NULL),
('Spirulina',                       'Suplemen & Resepi', 'botol',0, 3, false, NULL),
('Probiotik Advanced',              'Suplemen & Resepi', 'botol',0, 3, false, NULL),
('Magnesium Glycinate',             'Suplemen & Resepi', 'botol',0, 3, false, NULL),
('Vitamin D3',                      'Suplemen & Resepi', 'botol',0, 3, false, NULL),
('Omega-3 Fish Oil',                'Suplemen & Resepi', 'botol',0, 3, false, NULL),

-- ── BUKU & BAHAN CETAK ────────────────────────────────────
('Buku P101',                       'Buku & Bahan Cetak', 'naskhah', 0, 10, false, '7 buku per set starter kit'),
('List Pantang',                    'Buku & Bahan Cetak', 'naskhah', 0, 10, false, 'Diedarkan semasa onboarding'),
('Peta OB',                         'Buku & Bahan Cetak', 'naskhah', 0, 10, false, 'Diedarkan semasa onboarding OBD / OBP'),
('Workbook Refleksi Harian',        'Buku & Bahan Cetak', 'naskhah', 0, 10, false, NULL),
('Jadual Terapi Mingguan',          'Buku & Bahan Cetak', 'naskhah', 0, 10, false, NULL),
('Mood Tracker',                    'Buku & Bahan Cetak', 'naskhah', 0, 10, false, NULL),
('Buku Gaya Hidup Fitrah',          'Buku & Bahan Cetak', 'naskhah', 0,  5, false, NULL),
('Kitab Doa Syifa',                 'Buku & Bahan Cetak', 'naskhah', 0,  5, false, NULL),

-- ── BROSUR & MARKETING ────────────────────────────────────
('Brochure Madu',                   'Brosur & Marketing', 'unit', 0, 20, false, NULL),
('Brochure ISW',                    'Brosur & Marketing', 'unit', 0, 20, false, NULL),
('Brochure OB',                     'Brosur & Marketing', 'unit', 0, 20, false, NULL),

-- ── BEKALAN COACHING ──────────────────────────────────────
('Air Afiyah',                      'Bekalan Coaching', 'botol', 0, 10, false, '1 botol = 1.5L'),
('Air Za''afaran',                  'Bekalan Coaching', 'botol', 0,  5, false, 'Untuk sesi Perubatan Rohani'),
('Herba Kolon',                     'Bekalan Coaching', 'set',   0,  3, false, '1 set = 1 kursus rawatan'),
('Kurma Ajwa',                      'Bekalan Coaching', 'biji',  0, 50, false, '49 biji per pesakit 777 VIP'),

-- ── PERALATAN KLINIK ──────────────────────────────────────
('DNA Test Kit',                    'Peralatan Klinik', 'set',  0, 2, true,  'Perlu kelulusan · hantar ke lab luar'),
('Enema Kit',                       'Peralatan Klinik', 'set',  0, 3, true,  'Perlu kelulusan'),
('Mesin Ozon',                      'Peralatan Klinik', 'unit', 0, 1, true,  'Rekod nombor siri setiap unit')

;

-- ──── Seed: contoh kit prosedur ────
INSERT INTO psy_procedure_kits (name, description, category, items) VALUES
(
  'IV Drip Setup',
  'Set lengkap untuk satu sesi IV Saline Drip',
  'IV Therapy',
  '[
    {"item_id": null, "item_name": "IV Line",       "qty": 1, "unit": "unit"},
    {"item_id": null, "item_name": "Gloves",         "qty": 2, "unit": "pasang"},
    {"item_id": null, "item_name": "Alcohol Swab",   "qty": 3, "unit": "unit"},
    {"item_id": null, "item_name": "Cotton Ball",    "qty": 2, "unit": "unit"},
    {"item_id": null, "item_name": "Branula",        "qty": 1, "unit": "unit"},
    {"item_id": null, "item_name": "Plaster",        "qty": 2, "unit": "unit"},
    {"item_id": null, "item_name": "Scotch Tape",    "qty": 1, "unit": "unit"}
  ]'::jsonb
),
(
  'Blood Test Setup',
  'Set lengkap untuk pengambilan darah',
  'Diagnostik',
  '[
    {"item_id": null, "item_name": "Gloves",         "qty": 1, "unit": "pasang"},
    {"item_id": null, "item_name": "Alcohol Swab",   "qty": 2, "unit": "unit"},
    {"item_id": null, "item_name": "Cotton Ball",    "qty": 2, "unit": "unit"},
    {"item_id": null, "item_name": "Needle/Vacutainer","qty": 1, "unit": "unit"},
    {"item_id": null, "item_name": "Plaster",        "qty": 1, "unit": "unit"},
    {"item_id": null, "item_name": "Blood Tube",     "qty": 3, "unit": "tube"}
  ]'::jsonb
),
(
  'DNA Test Setup',
  'Set untuk pengambilan sampel DNA (buccal swab)',
  'Diagnostik',
  '[
    {"item_id": null, "item_name": "Gloves",         "qty": 1, "unit": "pasang"},
    {"item_id": null, "item_name": "DNA Swab",       "qty": 2, "unit": "unit"},
    {"item_id": null, "item_name": "DNA Collection Tube", "qty": 1, "unit": "unit"},
    {"item_id": null, "item_name": "Ziplock Bag",    "qty": 1, "unit": "unit"}
  ]'::jsonb
)
ON CONFLICT DO NOTHING;

-- ──────────────────────────────────────────────────────────────
-- Pautan silang domain: psy_supply_disbursements (fail 07) → item inventori
-- ──────────────────────────────────────────────────────────────
ALTER TABLE psy_supply_disbursements DROP CONSTRAINT IF EXISTS psy_supply_disbursements_item_id_fkey;
ALTER TABLE psy_supply_disbursements ADD CONSTRAINT psy_supply_disbursements_item_id_fkey
  FOREIGN KEY (item_id) REFERENCES psy_inventory_items(id) ON DELETE SET NULL;
