-- ═══════════════════════════════════════════════════════════════════
-- 30 — VOUCHER WALLET (CLAIM KOD PROMO)
-- Jadual: psy_promo_claims. Fungsi: claim_promo_code().
-- Lapisan kedua di atas psy_promo_codes (29_promo_codes.sql) — pesakit
-- boleh "claim" kod ke wallet peribadi (gaya ZUS: tab Active/Past,
-- kotak "Add a voucher") supaya tak perlu ingat/taip kod setiap kali
-- checkout. Cara "taip terus di cart" (29) KEKAL berfungsi tanpa claim.
-- ═══════════════════════════════════════════════════════════════════

ALTER TABLE psy_promo_codes
  ADD COLUMN IF NOT EXISTS wallet_validity_days INT;

COMMENT ON COLUMN psy_promo_codes.wallet_validity_days IS
  'Bilangan hari sah dari tarikh CLAIM (bukan dari cipta kod) — dipakai bila valid_until tiada. NULL + valid_until tiada = tiada had.';

-- ──── psy_promo_claims ────
-- Snapshot nilai kod pada masa claim (elak join semasa papar wallet,
-- & kekal betul walaupun kod dipinda/dipadam kemudian).
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

-- Pesakit cuma boleh BACA claim sendiri. TIADA INSERT/UPDATE policy untuk
-- pesakit — semua tulisan lalui claim_promo_code() (SECURITY DEFINER) atau
-- trigger trg_promo_mark_used_on_payment (29_promo_codes.sql). Ini elak
-- pesakit forge discount_value/discount_type terus via client insert.
DROP POLICY IF EXISTS "Patients view own promo claims" ON psy_promo_claims;
CREATE POLICY "Patients view own promo claims" ON psy_promo_claims FOR SELECT
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Staff view all promo claims" ON psy_promo_claims;
CREATE POLICY "Staff view all promo claims" ON psy_promo_claims FOR SELECT
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

COMMENT ON TABLE psy_promo_claims IS
  'Wallet peribadi pesakit — 1 baris = 1 kod yang di-"claim" (gaya ZUS Voucher Wallet). status=used ditanda oleh trg_promo_mark_used_on_payment bila bayaran yg guna kod ni SELESAI.';

-- ──── claim_promo_code() ────
-- RPC dipanggil client (window.db.rpc('claim_promo_code', { p_code })).
-- Sah kod SEPENUHNYA server-side (sama syarat macam blok promo dalam
-- payments-initiate) sebelum insert snapshot. RAISE EXCEPTION dgn mesej
-- BM mesra bila gagal — client papar terus error.message.
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
