-- ═══════════════════════════════════════════════════════════════════
-- 29 — KOD PROMO (KEDAI)
-- Jadual: psy_promo_codes, psy_promo_redemptions
-- Kod diskaun umum (cth 'RAYA10') dicipta staff, ditaip pesakit di cart
-- kedai (shop.html). Berbeza dari psy_vouchers (28_rewards.sql) yang
-- auto-apply ganjaran khusus per-pesakit — kod promo ni umum & manual.
-- Logik sah & redeem terpusat dalam payments-initiate; trigger di sini
-- cuma kunci penggunaan bila bayaran SAHAJA disahkan 'completed'.
-- ═══════════════════════════════════════════════════════════════════

-- ──── psy_promo_codes ────
CREATE TABLE IF NOT EXISTS psy_promo_codes (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code                  TEXT UNIQUE NOT NULL,
  description           TEXT,
  discount_type         TEXT NOT NULL CHECK (discount_type IN ('percent','fixed')),
  discount_value        NUMERIC(10,2) NOT NULL CHECK (discount_value > 0),
  min_subtotal          NUMERIC(10,2) NOT NULL DEFAULT 0,
  max_uses              INT,                       -- NULL = tiada had keseluruhan
  used_count            INT NOT NULL DEFAULT 0,
  max_uses_per_patient  INT NOT NULL DEFAULT 1,     -- NULL = tiada had per-pesakit
  valid_from            DATE,
  valid_until           DATE,
  is_active             BOOLEAN NOT NULL DEFAULT true,
  created_by            UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  created_at            TIMESTAMPTZ DEFAULT now(),
  updated_at            TIMESTAMPTZ DEFAULT now(),
  -- Audit #D-15/16/17 (Tier 5)
  applies_to            TEXT NOT NULL DEFAULT 'all' CHECK (applies_to IN ('all','product','category','package')),
  applies_to_values     TEXT[],       -- product_id / category / package_id list, ikut applies_to (NULL bila 'all')
  stackable             BOOLEAN NOT NULL DEFAULT false,  -- MVP: tak boleh gabung (lock 6 Okt). Medan kekal utk kegunaan masa depan
  new_customer_only     BOOLEAN NOT NULL DEFAULT false,  -- LEGACY — digantikan customer_eligibility='new' (kekal utk kod lama)
  campaign              TEXT,         -- label kempen (pilihan, utk pengelompokan/laporan sahaja — bukan gate)
  -- Fasa 2 (6 Okt 2026)
  start_time            TIME NOT NULL DEFAULT '00:00:00',  -- masa mula (masa tempatan MY)
  end_time              TIME NOT NULL DEFAULT '23:59:59',  -- masa tamat (masa tempatan MY)
  promotion_type        TEXT NOT NULL DEFAULT 'promo_code' CHECK (promotion_type IN ('promo_code','voucher')),  -- promo_code=taip/claim sendiri; voucher=push ke wallet (lihat 30_promo_claims.sql)
  name                  TEXT,         -- nama promosi (cth "New Patient 10% Off"); description kekal utk penerangan
  max_discount          NUMERIC(10,2) CHECK (max_discount IS NULL OR max_discount > 0),  -- had maksimum RM utk diskaun peratus (NULL = tiada)
  show_on_shop          BOOLEAN NOT NULL DEFAULT false,  -- papar dalam banner Shop pesakit?
  customer_eligibility  TEXT NOT NULL DEFAULT 'all' CHECK (customer_eligibility IN ('all','new','existing','selected')),
  selected_patient_ids  UUID[]        -- pesakit tertentu (bila customer_eligibility='selected')
);

CREATE INDEX IF NOT EXISTS idx_psy_promo_codes_code ON psy_promo_codes(code);

ALTER TABLE psy_promo_codes ENABLE ROW LEVEL SECURITY;

-- Baca terbuka (macam psy_products) — client perlu preview kod sebelum checkout.
DROP POLICY IF EXISTS "Anyone read promo codes" ON psy_promo_codes;
CREATE POLICY "Anyone read promo codes" ON psy_promo_codes FOR SELECT USING (true);

DROP POLICY IF EXISTS "Staff manage promo codes" ON psy_promo_codes;
CREATE POLICY "Staff manage promo codes" ON psy_promo_codes
  FOR ALL USING      (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
           WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

COMMENT ON COLUMN psy_promo_codes.code IS
  'Disimpan uppercase (cth RAYA10). Sentiasa banding upper(trim(input)) semasa sah kod.';
COMMENT ON COLUMN psy_promo_codes.min_subtotal IS
  'Subjumlah troli minimum (RM) sebelum kod boleh diguna. 0 = tiada syarat.';
COMMENT ON COLUMN psy_promo_codes.max_uses_per_patient IS
  'Had berapa kali SATU pesakit boleh guna kod ni (dikira dari psy_promo_redemptions).';
COMMENT ON COLUMN psy_promo_codes.applies_to IS
  'Skop troli yang perlu ADA sebelum kod sah dipakai (gate seluruh-atau-tiada — diskaun tetap kena SELURUH subjumlah, bukan pro-rata baris tertentu, sama falsafah macam min_subtotal).';
COMMENT ON COLUMN psy_promo_codes.applies_to_values IS
  'product_id (psy_products) / category (psy_products.category) / package_id (psy_packages), ikut applies_to.';
COMMENT ON COLUMN psy_promo_codes.stackable IS
  'false = tak boleh dipakai serentak dgn baucar ganjaran auto-apply (psy_vouchers, cth baucar tukar mata) dlm checkout yang sama.';

-- ──── psy_promo_redemptions ────
-- Lejar penggunaan — dicipta oleh trigger (bukan client) bila bayaran sah selesai.
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

-- ──── Redeem: kunci kod promo bila bayaran yang memakainya SAHAJA selesai ────
-- payments-initiate simpan promoCodeId + promoDiscount dalam psy_payments.intent
-- bila kod diguna pakai (total dah ditolak). Trigger ni sahkan bayaran itu betul-
-- betul SELESAI sebelum log penggunaan + naikkan used_count (elak bayaran
-- gagal/dibatal "makan" kuota kod orang). Sama pattern dengan
-- trg_voucher_mark_used_on_payment (28_rewards.sql).
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

  -- Tandakan claim wallet (30_promo_claims.sql) sebagai 'used' kalau pesakit
  -- claim kod ni dulu sebelum checkout. No-op senyap kalau tiada claim padan
  -- (pesakit taip kod terus tanpa claim pun sah — wallet cuma lapisan UX).
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
