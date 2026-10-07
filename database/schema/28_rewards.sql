-- ═══════════════════════════════════════════════════════════════════
-- 28 — GANJARAN (REWARD/VOUCHER — GENERIK)
-- Jadual: psy_vouchers — lejar baucar RM generik, boleh dijana oleh
-- PELBAGAI jenis peraturan ganjaran (source_type) yang akan bertambah
-- dari semasa ke semasa (cth 'referral_signup' sekarang, akan datang:
-- 'spend_threshold', 'checkin_streak', dll). Setiap peraturan cuma
-- perlu INSERT satu baris ke jadual ni bila syarat dipenuhi — logik
-- redeem (tolak dari total checkout) ditulis SEKALI dalam
-- payments-initiate & terpakai untuk semua jenis ganjaran selamanya.
-- ═══════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS psy_vouchers (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id        UUID NOT NULL REFERENCES psy_patients(id) ON DELETE CASCADE,
  source_type       TEXT NOT NULL,      -- 'referral_signup' | 'spend_threshold' | 'checkin_streak' | 'manual' | ...
  source_ref        UUID,               -- rujukan longgar ke rekod asal (cth psy_referrals.id) — tiada FK sebab jadual sumber berbeza ikut source_type
  amount            NUMERIC(10,2) NOT NULL CHECK (amount > 0),
  status            TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active','used','expired','void')),
  note              TEXT,
  expires_at        TIMESTAMPTZ,        -- NULL = tiada tarikh luput
  used_at           TIMESTAMPTZ,
  used_in_payment_id UUID REFERENCES psy_payments(id) ON DELETE SET NULL,
  created_at        TIMESTAMPTZ DEFAULT now(),
  -- Fasa 2 (6 Okt 2026)
  voucher_code      TEXT NOT NULL UNIQUE DEFAULT ('VC' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8))),  -- kod paparan baucar (auto jika tak diisi)
  title             TEXT,                  -- nama baucar (cth "Birthday Reward")
  min_subtotal      NUMERIC(10,2) NOT NULL DEFAULT 0,
  applies_to        TEXT NOT NULL DEFAULT 'all' CHECK (applies_to IN ('all','product','category','package')),
  applies_to_values TEXT[],
  issued_by         UUID REFERENCES psy_profiles(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_psy_vouchers_patient_active
  ON psy_vouchers(patient_id, status, created_at);

ALTER TABLE psy_vouchers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Patients view own vouchers" ON psy_vouchers;
CREATE POLICY "Patients view own vouchers" ON psy_vouchers FOR SELECT
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Staff manage vouchers" ON psy_vouchers;
CREATE POLICY "Staff manage vouchers" ON psy_vouchers FOR ALL
  USING      (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
  WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- ──── Peraturan #1: baucar untuk pesakit yang DIRUJUK (referee) ────
-- Bila rekod psy_referrals baru dicipta (status='pending', masa KYC
-- diluluskan), terus jana SATU baucar aktif untuk pesakit yang dirujuk
-- (referee) — boleh digunakan untuk MANA-MANA bayaran akan datang (bukan
-- terhad pakej pertama — elak baucar "terperap" kalau pakej diaktifkan
-- melalui laluan lain, cth staff Tandakan Selesai KOB terus tanpa checkout).
-- Kadar RM boleh diubah staff di Tetapan → Affiliate (psy_settings
-- key 'referral_signup_voucher_amount'), lalai RM30.
CREATE OR REPLACE FUNCTION trg_create_referral_signup_voucher()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_amount NUMERIC(10,2);
BEGIN
  IF NEW.referee_patient_id IS NULL THEN RETURN NEW; END IF;

  SELECT (value #>> '{}')::numeric INTO v_amount
  FROM psy_settings WHERE key = 'referral_signup_voucher_amount';
  v_amount := COALESCE(v_amount, 30);

  INSERT INTO psy_vouchers (patient_id, source_type, source_ref, amount, note)
  VALUES (
    NEW.referee_patient_id, 'referral_signup', NEW.id, v_amount,
    'Baucar pendaftaran — guna kod rujukan ' || COALESCE(NEW.code_used, '')
  );

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE LOG 'trg_create_referral_signup_voucher: %', SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_create_referral_signup_voucher ON psy_referrals;
CREATE TRIGGER trg_create_referral_signup_voucher
  AFTER INSERT ON psy_referrals
  FOR EACH ROW EXECUTE FUNCTION trg_create_referral_signup_voucher();

-- ──── Redeem: tandakan baucar 'used' bila bayaran yang memakainya selesai ────
-- payments-initiate simpan voucherId dalam psy_payments.intent bila baucar
-- diguna pakai (total dah ditolak). Trigger ni sahkan bayaran itu betul-
-- betul SELESAI sebelum kunci baucar (elak bayaran gagal/dibatal "makan"
-- baucar orang).
CREATE OR REPLACE FUNCTION trg_voucher_mark_used_on_payment()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_voucher_id UUID;
BEGIN
  IF NEW.status IS DISTINCT FROM 'completed' THEN RETURN NEW; END IF;
  IF TG_OP = 'UPDATE' AND OLD.status = 'completed' THEN RETURN NEW; END IF;

  v_voucher_id := (NEW.intent ->> 'voucherId')::uuid;
  IF v_voucher_id IS NULL THEN RETURN NEW; END IF;

  UPDATE psy_vouchers SET status = 'used', used_at = now(), used_in_payment_id = NEW.id
  WHERE id = v_voucher_id AND status = 'active';

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE LOG 'trg_voucher_mark_used_on_payment: %', SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_voucher_mark_used_on_payment ON psy_payments;
CREATE TRIGGER trg_voucher_mark_used_on_payment
  AFTER INSERT OR UPDATE ON psy_payments
  FOR EACH ROW EXECUTE FUNCTION trg_voucher_mark_used_on_payment();
