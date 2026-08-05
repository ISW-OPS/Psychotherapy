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
