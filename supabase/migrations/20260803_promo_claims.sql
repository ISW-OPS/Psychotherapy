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
