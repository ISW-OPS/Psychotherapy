-- ============================================================
-- step94_payment_gateway.sql
-- Sambungan gateway bayaran sebenar (HitPay sekarang, Fiuu nanti).
--
-- Menambah kolum "gateway" pada psy_payments supaya sistem boleh:
--   1. Cipta baris PENDING sebelum redirect ke gateway
--   2. Simpan NIAT bayaran (intent) — supaya webhook boleh fulfill
--      (aktif pakej/plan/KOB) SELEPAS bayaran disahkan, bukan sebelum
--   3. Padan webhook balik ke baris betul (gateway_ref) + elak double-proses
--
-- Reka bentuk provider-agnostic: gateway_provider simpan 'hitpay'|'fiuu'.
-- Tukar gateway nanti TAK sentuh skema — cuma tulis adapter baru.
--
-- Idempotent — selamat run berulang. Jalankan di Supabase (testing & prod).
-- ============================================================

ALTER TABLE psy_payments
  ADD COLUMN IF NOT EXISTS gateway_provider TEXT,          -- 'hitpay' | 'fiuu' | NULL (manual)
  ADD COLUMN IF NOT EXISTS gateway_ref      TEXT,          -- id rujukan dari gateway (cth HitPay payment_request id)
  ADD COLUMN IF NOT EXISTS gateway_status   TEXT,          -- status mentah dari gateway (cth 'pending'|'completed'|'failed')
  ADD COLUMN IF NOT EXISTS intent           JSONB DEFAULT '{}'::jsonb,  -- NIAT bayaran (pendingItems + konteks) utk fulfillment
  ADD COLUMN IF NOT EXISTS fulfilled_at     TIMESTAMPTZ;   -- bila fulfillment (aktif pakej/plan) benar-benar jalan

-- Benarkan payment_method 'gateway' (redirect FPX/kad via HitPay) selain fpx/card/transfer/ghl/manual
DO $$ BEGIN
  ALTER TABLE psy_payments DROP CONSTRAINT IF EXISTS psy_payments_payment_method_check;
  ALTER TABLE psy_payments ADD CONSTRAINT psy_payments_payment_method_check
    CHECK (payment_method IN ('fpx','card','transfer','ghl','manual','gateway'));
EXCEPTION WHEN others THEN NULL; END $$;

-- Webhook cari baris ikut gateway_ref — perlu index
CREATE INDEX IF NOT EXISTS idx_psy_payments_gateway_ref ON psy_payments (gateway_ref);

-- Pesakit boleh BACA baris pending sendiri (untuk poll status di halaman pulangan).
-- (Polisi SELECT sedia ada dah cover patient_id; tiada perubahan RLS diperlukan.)
-- Edge Function guna service_role → pintas RLS untuk cipta pending + fulfill.

COMMENT ON COLUMN psy_payments.intent IS
  'Snapshot pendingItems + konteks bayaran; dibaca oleh payments-webhook untuk fulfillment idempotent selepas gateway sahkan.';
