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
  v_now_my     TIMESTAMP;
  v_start_my   TIMESTAMP;
  v_end_my     TIMESTAMP;
  v_expires_at TIMESTAMPTZ;
  v_claim      psy_promo_claims%ROWTYPE;
  v_elig_mode  TEXT;
  v_has_paid   BOOLEAN;
  v_redeemed   INT;
BEGIN
  SELECT id INTO v_patient_id FROM psy_patients WHERE user_id = auth.uid() LIMIT 1;
  IF v_patient_id IS NULL THEN
    RAISE EXCEPTION 'Rekod pesakit tidak dijumpai.';
  END IF;

  SELECT * INTO v_promo FROM psy_promo_codes WHERE code = upper(trim(p_code));
  IF v_promo.id IS NULL OR NOT v_promo.is_active THEN
    RAISE EXCEPTION 'Kod tidak sah atau telah luput.';
  END IF;

  -- Tarikh + masa (waktu tempatan Malaysia, UTC+8) — sama kaedah dgn payments-initiate
  v_now_my := (now() + interval '8 hours');
  v_start_my := CASE WHEN v_promo.valid_from IS NOT NULL THEN v_promo.valid_from::timestamp + COALESCE(v_promo.start_time, '00:00:00')::time ELSE NULL END;
  v_end_my := CASE WHEN v_promo.valid_until IS NOT NULL THEN v_promo.valid_until::timestamp + COALESCE(v_promo.end_time, '23:59:59')::time ELSE NULL END;
  IF (v_start_my IS NOT NULL AND v_now_my < v_start_my) OR (v_end_my IS NOT NULL AND v_now_my > v_end_my) THEN
    RAISE EXCEPTION 'Kod tidak sah atau telah luput.';
  END IF;

  IF v_promo.max_uses IS NOT NULL AND v_promo.used_count >= v_promo.max_uses THEN
    RAISE EXCEPTION 'Kod ini telah mencapai had penggunaan.';
  END IF;

  -- Had setiap pesakit (dikira dari penggunaan SEBENAR, bukan claim)
  IF v_promo.max_uses_per_patient IS NOT NULL THEN
    SELECT count(*) INTO v_redeemed FROM psy_promo_redemptions
      WHERE promo_id = v_promo.id AND patient_id = v_patient_id;
    IF v_redeemed >= v_promo.max_uses_per_patient THEN
      RAISE EXCEPTION 'Anda sudah guna had maksimum untuk kod ini.';
    END IF;
  END IF;

  -- Kelayakan pelanggan
  v_elig_mode := COALESCE(v_promo.customer_eligibility, CASE WHEN v_promo.new_customer_only THEN 'new' ELSE 'all' END);
  IF v_elig_mode IN ('new', 'existing') THEN
    SELECT EXISTS (SELECT 1 FROM psy_payments WHERE patient_id = v_patient_id AND status = 'completed') INTO v_has_paid;
    IF v_elig_mode = 'new' AND v_has_paid THEN
      RAISE EXCEPTION 'Kod ini untuk pesakit baharu sahaja.';
    END IF;
    IF v_elig_mode = 'existing' AND NOT v_has_paid THEN
      RAISE EXCEPTION 'Kod ini untuk pesakit sedia ada sahaja.';
    END IF;
  ELSIF v_elig_mode = 'selected' AND NOT (v_patient_id = ANY(COALESCE(v_promo.selected_patient_ids, ARRAY[]::UUID[]))) THEN
    RAISE EXCEPTION 'Kod ini tidak sah untuk akaun anda.';
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

-- ═══════════════════════════════════════════════════════════════════
-- Fasa 2b (7 Okt 2026) — Promosi jenis "Voucher": AUTO-PUSH claim ke
-- wallet ramai pesakit sekali gus bila promosi jadi/kekal Aktif
-- (bukan pesakit taip/claim sendiri, dan bukan butang manual staff).
-- Idempoten — ON CONFLICT (promo_id, patient_id) DO NOTHING, jadi
-- selamat dicetus berulang kali (setiap kali disunting semasa Aktif);
-- pesakit baharu yang jadi layak akan terangkum pada push seterusnya.
-- "History" (used/expired) guna status + expires_at sedia ada pada
-- psy_promo_claims — roles/patient/vouchers.html dah pisah tab
-- Aktif/Lepas berdasarkan ini, tiada kerja tambahan diperlukan.
-- ═══════════════════════════════════════════════════════════════════

-- ──── _push_promo_wallet_rows(): logik insert sebenar (dalaman, tiada semakan staff) ────
-- Dipanggil oleh trigger (selepas UPDATE/INSERT yang DAH lepas RLS staff-only
-- pada psy_promo_codes — jadi kebenaran dah disahkan oleh UPDATE/INSERT itu sendiri).
CREATE OR REPLACE FUNCTION _push_promo_wallet_rows(p_promo_id UUID)
RETURNS INT
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_promo psy_promo_codes%ROWTYPE;
  v_expires_at TIMESTAMPTZ;
  v_count INT;
BEGIN
  SELECT * INTO v_promo FROM psy_promo_codes WHERE id = p_promo_id;
  IF v_promo.id IS NULL OR v_promo.promotion_type IS DISTINCT FROM 'voucher' OR NOT v_promo.is_active THEN
    RETURN 0;
  END IF;

  v_expires_at := CASE
    WHEN v_promo.valid_until IS NOT NULL THEN v_promo.valid_until::timestamptz + INTERVAL '1 day' - INTERVAL '1 second'
    WHEN v_promo.wallet_validity_days IS NOT NULL THEN now() + (v_promo.wallet_validity_days || ' days')::interval
    ELSE NULL
  END;

  INSERT INTO psy_promo_claims (patient_id, promo_id, code, discount_type, discount_value, min_subtotal, expires_at)
  SELECT p.id, v_promo.id, v_promo.code, v_promo.discount_type, v_promo.discount_value, v_promo.min_subtotal, v_expires_at
  FROM psy_patients p
  WHERE p.status <> 'deleted'
    AND (
      v_promo.customer_eligibility = 'all' OR v_promo.customer_eligibility IS NULL
      OR (v_promo.customer_eligibility = 'new' AND NOT EXISTS (SELECT 1 FROM psy_payments pay WHERE pay.patient_id = p.id AND pay.status = 'completed'))
      OR (v_promo.customer_eligibility = 'existing' AND EXISTS (SELECT 1 FROM psy_payments pay WHERE pay.patient_id = p.id AND pay.status = 'completed'))
      OR (v_promo.customer_eligibility = 'selected' AND p.id = ANY(COALESCE(v_promo.selected_patient_ids, ARRAY[]::UUID[])))
    )
  ON CONFLICT (promo_id, patient_id) DO NOTHING;

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

-- ──── trg_promo_push_voucher(): auto-push bila promosi Voucher jadi/kekal Aktif ────
CREATE OR REPLACE FUNCTION trg_promo_push_voucher()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NEW.promotion_type = 'voucher' AND NEW.is_active THEN
    PERFORM _push_promo_wallet_rows(NEW.id);
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_promo_push_voucher ON psy_promo_codes;
CREATE TRIGGER trg_promo_push_voucher
  AFTER INSERT OR UPDATE ON psy_promo_codes
  FOR EACH ROW EXECUTE FUNCTION trg_promo_push_voucher();
