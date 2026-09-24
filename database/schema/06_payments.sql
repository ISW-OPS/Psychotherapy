-- ═══════════════════════════════════════════════════════════════════
-- SKEMA: PEMBAYARAN & PESANAN
-- Jadual: psy_payments, psy_orders
-- Gateway bayaran provider-agnostic (HitPay/Fiuu) via kolum gateway_*.
-- ═══════════════════════════════════════════════════════════════════

-- ──────────────────────────────────────────────────────────────
-- psy_payments — rekod bayaran (manual + gateway)
-- ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS psy_payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  receipt_ref TEXT UNIQUE NOT NULL,
  patient_id UUID REFERENCES psy_patients(id),
  user_id UUID REFERENCES psy_profiles(id) ON DELETE CASCADE,
  items JSONB DEFAULT '[]',
  subtotal NUMERIC(10,2) DEFAULT 0,
  service_charge NUMERIC(10,2) DEFAULT 0,
  sst NUMERIC(10,2) DEFAULT 0,
  total NUMERIC(10,2) NOT NULL,
  payment_method TEXT CHECK (payment_method IN ('fpx','card','transfer','ghl','manual','gateway')),
  -- 'voided' ditambah 24 Sept 2026 (audit management #B1-24) — transaksi yg tersalah
  -- rekod terus (bukan pesakit betul-betul minta wang balik). Beza drpd 'refunded'
  -- (bayaran sah, wang dipulangkan). Lihat psy_payment_adjustments utk sebab/approver.
  status TEXT DEFAULT 'completed' CHECK (status IN ('pending','completed','refunded','failed','voided')),
  -- Ditambah 24 Sept 2026 (audit management #B1-23) — bayaran ujian/demo, DIKECUALIKAN
  -- drpd semua laporan kewangan sebenar (KPI dashboard, laporan bulanan dll).
  is_test BOOLEAN NOT NULL DEFAULT false,
  -- Ditambah 24 Sept 2026 (audit management #B1-27) — status penghantaran resit/invois
  -- (WhatsApp) supaya staf tahu ia dihantar atau gagal, bukan senyap "fire and forget".
  receipt_last_sent_at     TIMESTAMPTZ,
  receipt_last_sent_status TEXT CHECK (receipt_last_sent_status IS NULL OR receipt_last_sent_status IN ('sent','failed')),
  ghl_transaction_id TEXT,
  invoice_number TEXT,                        -- bayaran manual — no. invois ditaip staff/doktor
  manual_method TEXT CHECK (manual_method IN ('transfer','cash','other')),  -- kaedah bayaran manual (payment_method='manual')
  invoice_no TEXT UNIQUE,                     -- no. invois (INV-…) utk bayaran BUKAN pakej KOB — auto bila 'pending'/'completed'; bayaran KOB guna psy_kob_sessions.invoice_no
  bank_reference TEXT,                        -- no. rujukan transaksi bank / transfer (bayaran manual)
  recorded_by UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,  -- staf yg merekod bayaran manual (paid_at = tarikh bayaran SEBENAR; created_at = masa direkod)
  paid_for_type TEXT CHECK (paid_for_type IN ('package','installment','invoice','consultation','product','other')),  -- bayaran ni utk apa (bayaran manual)
  paid_for_seq INT,                           -- checkpoint ansuran yg dilunaskan (paid_for_type='installment')
  paid_for_ref TEXT,                          -- rujukan sasaran (cth invoice_no yg dilunaskan, paid_for_type='invoice')
  is_partial BOOLEAN NOT NULL DEFAULT false,  -- bayaran separa (kurang drpd baki sasaran) — dibenderakan
  receipt_no TEXT UNIQUE,                     -- no. resit paparan (REC10001..) — auto bila status jadi 'completed'; receipt_ref kekal kunci teknikal
  discount NUMERIC(10,2) NOT NULL DEFAULT 0,  -- diskaun pada bayaran ini (papar di resit; subtotal = total + discount)
  receipt_url TEXT,                           -- bayaran manual — resit yang di-upload
  notes TEXT,
  -- gateway bayaran (HitPay/Fiuu) — pending row dicipta sebelum redirect,
  -- webhook padankan gateway_ref & jalankan fulfillment ikut intent
  gateway_provider TEXT,                      -- 'hitpay' | 'fiuu' | NULL (manual)
  gateway_ref      TEXT,                      -- id rujukan dari gateway
  gateway_status   TEXT,                      -- status mentah dari gateway
  checkout_url     TEXT,                      -- pautan checkout gateway (utk staff share/salin semula bila status pending)
  intent           JSONB DEFAULT '{}'::jsonb, -- niat bayaran utk fulfillment
  fulfilled_at     TIMESTAMPTZ,               -- bila fulfillment benar-benar jalan
  paid_at TIMESTAMPTZ DEFAULT now(),
  created_at TIMESTAMPTZ DEFAULT now()
);

-- No. resit paparan berjujukan — diberi sekali bila bayaran 'completed' (bukan masa 'pending' gateway, elak nombor terbuang).
CREATE SEQUENCE IF NOT EXISTS psy_receipt_no_seq START 10001;

CREATE OR REPLACE FUNCTION psy_assign_receipt_no() RETURNS trigger AS $$
BEGIN
  IF NEW.status = 'completed' AND NEW.receipt_no IS NULL THEN
    NEW.receipt_no := 'REC' || nextval('psy_receipt_no_seq');
  END IF;
  RETURN NEW;
END $$ LANGUAGE plpgsql;

-- Invois utk bayaran bukan-KOB (kedai, sambungan minggu, dll): jujukan dikongsi dgn invois pakej KOB.
CREATE SEQUENCE IF NOT EXISTS psy_invoice_no_seq START 1;

CREATE OR REPLACE FUNCTION psy_assign_payment_invoice_no() RETURNS trigger AS $$
BEGIN
  IF NEW.invoice_no IS NULL AND NEW.status IN ('pending','completed')
     AND (NEW.intent ->> 'kob_session_id') IS NULL THEN
    NEW.invoice_no := 'INV-' || lpad(nextval('psy_invoice_no_seq')::text, 6, '0');
  END IF;
  RETURN NEW;
END $$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_psy_assign_payment_invoice_no ON psy_payments;
CREATE TRIGGER trg_psy_assign_payment_invoice_no BEFORE INSERT OR UPDATE OF status ON psy_payments
  FOR EACH ROW EXECUTE FUNCTION psy_assign_payment_invoice_no();

DROP TRIGGER IF EXISTS trg_psy_assign_receipt_no ON psy_payments;
CREATE TRIGGER trg_psy_assign_receipt_no BEFORE INSERT OR UPDATE OF status ON psy_payments
  FOR EACH ROW EXECUTE FUNCTION psy_assign_receipt_no();

CREATE INDEX IF NOT EXISTS idx_psy_payments_patient ON psy_payments(patient_id);
CREATE INDEX IF NOT EXISTS idx_psy_payments_receipt ON psy_payments(receipt_ref);
CREATE INDEX IF NOT EXISTS idx_psy_payments_gateway_ref ON psy_payments (gateway_ref);

ALTER TABLE psy_payments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Patients read own payments" ON psy_payments;
CREATE POLICY "Patients read own payments" ON psy_payments FOR SELECT
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

-- pesakit hanya boleh insert baris bayaran MILIK SENDIRI
DROP POLICY IF EXISTS "Patients insert own payments" ON psy_payments;
CREATE POLICY "Patients insert own payments" ON psy_payments
  FOR INSERT WITH CHECK (
    patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid())
  );

DROP POLICY IF EXISTS "Staff manage all payments" ON psy_payments;
CREATE POLICY "Staff manage all payments" ON psy_payments FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

COMMENT ON COLUMN psy_payments.intent IS
  'Snapshot pendingItems + konteks bayaran; dibaca oleh payments-webhook untuk fulfillment idempotent selepas gateway sahkan.';

-- ──────────────────────────────────────────────────────────────
-- psy_payment_adjustments — Void/Refund/Correction workflow (audit #B1-24, 24 Sept 2026)
-- Transaksi kewangan tersalah TAK boleh dipadam terus — kena melalui rekod ni dgn
-- sebab+amount+approver. type='void' (transaksi tak sepatutnya wujud, status→'voided'),
-- 'refund' (bayaran sah, wang dipulangkan, status→'refunded'), 'correction'
-- (dokumentasi pembetulan — TAK ubah amount psy_payments terus, sbb amount berkait
-- invois/jadual ansuran KOB; staf betulkan rekod berkaitan secara manual selepas
-- catat sebab di sini).
-- ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS psy_payment_adjustments (
  id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  payment_id         UUID NOT NULL REFERENCES psy_payments(id) ON DELETE CASCADE,
  type               TEXT NOT NULL CHECK (type IN ('void','refund','correction')),
  reason             TEXT NOT NULL,
  amount             NUMERIC(10,2),  -- refund/correction; NULL utk void (batal penuh)
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

COMMENT ON COLUMN psy_payment_adjustments.status IS
  'pending = menunggu kelulusan super_admin; approved = diluluskan & kesan diterapkan (psy_payments.status dikemaskini); rejected = ditolak, psy_payments tak berubah.';

-- ──────────────────────────────────────────────────────────────
-- psy_orders — pesanan produk pesakit (penghantaran bekalan)
-- ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS psy_orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_ref TEXT UNIQUE NOT NULL,
  patient_id UUID NOT NULL,
  items JSONB NOT NULL DEFAULT '[]',
  total NUMERIC(10,2) DEFAULT 0,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending','paid','packed','shipped','delivered','cancelled')),
  delivery_method TEXT DEFAULT 'pos' CHECK (delivery_method IN ('pickup','pos')),
  delivery_address TEXT,
  courier TEXT,
  tracking_number TEXT,
  tracking_photo_url TEXT,
  notes TEXT,
  paid_at TIMESTAMPTZ,
  packed_at TIMESTAMPTZ,
  shipped_at TIMESTAMPTZ,
  delivered_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE psy_orders ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Patient view own orders" ON psy_orders;
CREATE POLICY "Patient view own orders" ON psy_orders FOR SELECT
  USING (patient_id = auth.uid());

DROP POLICY IF EXISTS "Patient insert own orders" ON psy_orders;
CREATE POLICY "Patient insert own orders" ON psy_orders FOR INSERT
  WITH CHECK (patient_id = auth.uid());

DROP POLICY IF EXISTS "Patient confirm delivery" ON psy_orders;
CREATE POLICY "Patient confirm delivery" ON psy_orders FOR UPDATE
  USING (patient_id = auth.uid() AND status = 'shipped')
  WITH CHECK (status = 'delivered');

DROP POLICY IF EXISTS "Staff manage orders" ON psy_orders;
CREATE POLICY "Staff manage orders" ON psy_orders FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- Nota trigger pada psy_orders (diletak bersama fungsi masing-masing):
--   trg_psy_order_deduct_inventory → 14_products_inventory.sql
--   trg_notify_staff_new_order     → 18_notifications_automations.sql

-- ──────────────────────────────────────────────────────────────
-- psy_ghl_transactions — ledger RAW transaksi GHL (Laluan A, guna
-- GHL_ISW_TOKEN sahaja, TIADA akses Stripe secret diperlukan).
-- TUJUAN: reconciliation kewangan/accounting — BUKAN untuk paparan
-- sejarah bayaran pesakit (itu kekal psy_payments, diisi ghl-pull-sync
-- untuk yuran KOB sahaja). Jadual BERASINGAN sengaja — grain berbeza
-- (SEMUA transaksi lokasi, bukan sekadar yang lulus gate KOB) & elak
-- double-count rekod yang SAMA muncul di psy_payments (dari sudut
-- pandang GHL Transaction) DAN di sini (dari sudut pandang ledger
-- mentah) kalau digabung jadi satu jadual.
-- Diisi oleh supabase/functions/ghl-transactions-sync/index.ts.
-- ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS psy_ghl_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ghl_transaction_id TEXT UNIQUE NOT NULL,   -- GHL `_id`
  contact_id TEXT,
  contact_name TEXT,
  contact_email TEXT,
  patient_id UUID REFERENCES psy_patients(id),   -- padan ikut email bila boleh, NULL kalau tak jumpa
  amount NUMERIC(10,2) NOT NULL DEFAULT 0,   -- RM (unit manusia, BUKAN sen — GHL amount top-level dah RM)
  amount_refunded NUMERIC(10,2) DEFAULT 0,
  currency TEXT DEFAULT 'MYR',
  status TEXT,                               -- succeeded/failed/pending/dll (mentah GHL)
  payment_provider_type TEXT,                -- 'stripe' | 'manual' | lain
  entity_type TEXT,                          -- 'order' | 'invoice'
  entity_source_type TEXT,                   -- 'payment_link' | 'text2Pay' | dll
  entity_source_name TEXT,                   -- nama produk/invois
  entity_id TEXT,
  charge_id TEXT,                            -- Stripe payment_intent id (stripe sahaja, NULL kalau manual)
  payment_method_type TEXT,                  -- 'fpx' | 'card' | 'bank_transfer' | dll (derived, lihat sync fn)
  receipt_url TEXT,                          -- resit rasmi Stripe (stripe sahaja)
  invoice_number TEXT,                       -- cth "INV-000952" (entityType='invoice' sahaja, dari entitySourceMeta)
  issue_date TIMESTAMPTZ,                    -- tarikh invois DIISUKAN (BEZA dari ghl_created_at = bila transaksi/bayaran direkod; perlu panggilan /invoices/ berasingan, lihat sync fn)
  live_mode BOOLEAN,
  ghl_created_at TIMESTAMPTZ,                -- createdAt GHL (masa transaksi sebenar)
  ghl_updated_at TIMESTAMPTZ,
  fulfilled_at TIMESTAMPTZ,
  raw JSONB DEFAULT '{}'::jsonb,              -- objek PENUH GHL — safety net field yang terlepas
  synced_at TIMESTAMPTZ DEFAULT now(),
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ghl_tx_patient ON psy_ghl_transactions(patient_id);
CREATE INDEX IF NOT EXISTS idx_ghl_tx_contact ON psy_ghl_transactions(contact_id);
CREATE INDEX IF NOT EXISTS idx_ghl_tx_created ON psy_ghl_transactions(ghl_created_at);

ALTER TABLE psy_ghl_transactions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff manage ghl transactions" ON psy_ghl_transactions;
CREATE POLICY "Staff manage ghl transactions" ON psy_ghl_transactions FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- ──────────────────────────────────────────────────────────────
-- vw_payment_ledger — VIEW gabungan untuk accountant trace SEMUA
-- bayaran dalam SATU senarai (roles/staff/payment-ledger.html).
-- UNION psy_payments (sumber='ISW') + psy_ghl_transactions
-- (sumber='GHL') — DEDUP eksplisit: baris GHL yang `ghl_transaction_id`
-- dia DAH wujud dalam psy_payments (kes yuran KOB yang lulus gate
-- ghl-pull-sync) DIKECUALIKAN dari sisi GHL supaya bayaran yang SAMA
-- tak muncul dua kali. security_invoker=true — VIEW jalan ikut
-- kebenaran PEMANGGIL (RLS "Staff manage..." pada 2 jadual asal
-- terpakai terus), bukan pemilik view.
-- ──────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW vw_payment_ledger WITH (security_invoker = true) AS
SELECT
  p.id::text                       AS id,
  'ISW'                             AS source,
  COALESCE(p.paid_at, p.created_at) AS tx_date,
  p.patient_id,
  COALESCE(pt.full_name, 'Pesakit') AS contact_name,
  p.total                          AS amount,
  p.payment_method                 AS method,
  COALESCE(p.gateway_provider, p.payment_method) AS provider,
  p.status,
  p.receipt_ref                    AS reference,
  p.ghl_transaction_id,
  p.invoice_number,
  NULL::TIMESTAMPTZ                AS issue_date,
  p.notes
FROM psy_payments p
LEFT JOIN psy_patients pt ON pt.id = p.patient_id

UNION ALL

SELECT
  g.id::text                       AS id,
  'GHL'                             AS source,
  g.ghl_created_at                 AS tx_date,
  g.patient_id,
  g.contact_name,
  g.amount,
  g.payment_provider_type          AS method,
  g.payment_provider_type          AS provider,
  g.status,
  COALESCE(g.invoice_number, g.ghl_transaction_id) AS reference,
  g.ghl_transaction_id,
  g.invoice_number,
  g.issue_date,
  g.entity_source_name             AS notes
FROM psy_ghl_transactions g
WHERE g.ghl_transaction_id IS NULL
   OR g.ghl_transaction_id NOT IN (SELECT ghl_transaction_id FROM psy_payments WHERE ghl_transaction_id IS NOT NULL);

-- ──── psy_notifications: benarkan type 'payment' ────
-- GOTCHA (rujuk 27_affiliate.sql): jangan tulis semula senarai type inline
-- dalam CREATE TABLE — kekalkan semua nilai sedia ada + tambah 'payment'.
-- Dipakai oleh payments-webhook (notifyStaffPaymentReceived) supaya coach
-- + admin/manager dapat notifikasi loceng bila pesakit bayar apa-apa jenis
-- (pakej/KOB/temujanji/sambungan minggu), bukan sekadar shop_order.
DO $$
DECLARE
  v_types TEXT;
BEGIN
  SELECT COALESCE(string_agg(DISTINCT quote_literal(type), ','), '') INTO v_types
  FROM psy_notifications;

  IF v_types = '' THEN
    v_types := quote_literal('system');
  END IF;
  IF position('payment' in v_types) = 0 THEN
    v_types := v_types || ',' || quote_literal('payment');
  END IF;

  ALTER TABLE psy_notifications DROP CONSTRAINT IF EXISTS psy_notifications_type_check;
  EXECUTE format(
    'ALTER TABLE psy_notifications ADD CONSTRAINT psy_notifications_type_check CHECK (type IN (%s))',
    v_types
  );
END $$;
