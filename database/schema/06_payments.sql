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
  status TEXT DEFAULT 'completed' CHECK (status IN ('pending','completed','refunded','failed')),
  ghl_transaction_id TEXT,
  invoice_number TEXT,                        -- bayaran manual — no. invois ditaip staff/doktor
  receipt_url TEXT,                           -- bayaran manual — resit yang di-upload
  notes TEXT,
  -- gateway bayaran (HitPay/Fiuu) — pending row dicipta sebelum redirect,
  -- webhook padankan gateway_ref & jalankan fulfillment ikut intent
  gateway_provider TEXT,                      -- 'hitpay' | 'fiuu' | NULL (manual)
  gateway_ref      TEXT,                      -- id rujukan dari gateway
  gateway_status   TEXT,                      -- status mentah dari gateway
  intent           JSONB DEFAULT '{}'::jsonb, -- niat bayaran utk fulfillment
  fulfilled_at     TIMESTAMPTZ,               -- bila fulfillment benar-benar jalan
  paid_at TIMESTAMPTZ DEFAULT now(),
  created_at TIMESTAMPTZ DEFAULT now()
);

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
