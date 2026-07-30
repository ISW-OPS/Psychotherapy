-- ═══════════════════════════════════════════════════════════════════
-- MIGRASI: Benarkan psy_notifications.type = 'payment'
-- Run SEKALI di Supabase SQL Editor (testing & prod).
-- Diperlukan oleh payments-webhook (notifyStaffPaymentReceived) supaya
-- coach + admin/manager dapat notifikasi loceng bila pesakit bayar
-- apa-apa jenis (pakej/KOB/temujanji/sambungan minggu), bukan sekadar
-- shop_order (yang sedia ada guna type 'order').
--
-- GOTCHA (rujuk migrasi 'affiliate' sebelum ini): jangan hardcode
-- semula senarai type — kekalkan semua nilai sedia ada dalam jadual
-- + tambah 'payment' sahaja, supaya constraint tak mengecilkan liputan
-- type lain yang mungkin dah wujud di PROD.
-- ═══════════════════════════════════════════════════════════════════

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
