-- ═══════════════════════════════════════════════════════════════════
-- 27 — AFFILIATE (KOMISEN RUJUKAN PESAKIT + PAYOUT)
-- Extend fasa 1 rujukan (20_referrals.sql, psy_referrals): ganjaran kini
-- boleh jadi komisen RM sebenar (bukan sekadar baucar manual), kadar
-- boleh beza ikut pakej (psy_affiliate_commission_rules), dan staff boleh
-- proses bayaran keluar (psy_affiliate_payouts). Skop: pesakit sedia ada
-- sahaja (guna psy_patients.referral_code + psy_referrals yang dah wujud)
-- — bukan affiliate luar/influencer dengan login berasingan.
--
-- Payout guna bank transfer MANUAL dahulu (staff proses & tandakan
-- dibayar). Kolum `method` sengaja termasuk 'hitpay' sebagai tempat letak
-- masa depan — automasi HitPay Payout/Send API belum disambung (perlu
-- akses/approval berasingan yang belum disahkan).
-- ═══════════════════════════════════════════════════════════════════

-- ──── psy_affiliate_commission_rules — kadar komisen per pakej ────
CREATE TABLE IF NOT EXISTS psy_affiliate_commission_rules (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  package_id       UUID REFERENCES psy_packages(id) ON DELETE CASCADE, -- NULL = kadar lalai (pakej lain)
  commission_type  TEXT NOT NULL DEFAULT 'fixed' CHECK (commission_type IN ('fixed','percent')),
  amount           NUMERIC(10,2),  -- RM tetap (bila commission_type='fixed')
  rate_percent     NUMERIC(5,2),   -- % (bila commission_type='percent')
  cap_amount       NUMERIC(10,2),  -- had maksimum RM utk 'percent' (NULL = tiada had)
  is_active        BOOLEAN DEFAULT true,
  created_at       TIMESTAMPTZ DEFAULT now(),
  updated_at       TIMESTAMPTZ DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_psy_affiliate_commission_rules_package
  ON psy_affiliate_commission_rules (package_id)
  WHERE package_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS uq_psy_affiliate_commission_rules_default
  ON psy_affiliate_commission_rules ((1))
  WHERE package_id IS NULL;

ALTER TABLE psy_affiliate_commission_rules ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff manage commission rules" ON psy_affiliate_commission_rules;
CREATE POLICY "Staff manage commission rules" ON psy_affiliate_commission_rules FOR ALL
  USING      (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
  WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- Kadar lalai (package_id NULL) — wajib wujud supaya pakej tanpa rule
-- khusus tetap dapat komisen asas RM50.
INSERT INTO psy_affiliate_commission_rules (package_id, commission_type, amount)
SELECT NULL, 'fixed', 50.00
WHERE NOT EXISTS (SELECT 1 FROM psy_affiliate_commission_rules WHERE package_id IS NULL);

-- ──── psy_patients — maklumat bank (untuk payout) ────
ALTER TABLE psy_patients ADD COLUMN IF NOT EXISTS bank_name TEXT;
ALTER TABLE psy_patients ADD COLUMN IF NOT EXISTS bank_account_no TEXT;
ALTER TABLE psy_patients ADD COLUMN IF NOT EXISTS bank_account_holder TEXT;

-- ──── psy_referrals — tambah kolum komisen ────
ALTER TABLE psy_referrals ADD COLUMN IF NOT EXISTS qualifying_payment_id UUID REFERENCES psy_payments(id) ON DELETE SET NULL;
ALTER TABLE psy_referrals ADD COLUMN IF NOT EXISTS qualifying_package_id UUID REFERENCES psy_packages(id) ON DELETE SET NULL;
ALTER TABLE psy_referrals ADD COLUMN IF NOT EXISTS commission_amount NUMERIC(10,2) DEFAULT 0;
ALTER TABLE psy_referrals ADD COLUMN IF NOT EXISTS payout_id UUID; -- FK ditambah di bawah (selepas psy_affiliate_payouts wujud)

-- ──── psy_affiliate_payouts — lejar bayaran keluar (batch per pesakit) ────
CREATE TABLE IF NOT EXISTS psy_affiliate_payouts (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id    UUID NOT NULL REFERENCES psy_patients(id) ON DELETE CASCADE,
  amount        NUMERIC(10,2) NOT NULL,
  -- 'pending' sengaja tak dimasukkan: staff yang cetus bayaran (butang
  -- "Mulakan Bayaran"), payout terus jadi 'processing' — tiada laluan
  -- kelulusan pesakit-mohon dalam design semasa (Ags 2026).
  status        TEXT NOT NULL DEFAULT 'processing' CHECK (status IN ('processing','paid','rejected')),
  method        TEXT NOT NULL DEFAULT 'bank_transfer' CHECK (method IN ('bank_transfer','hitpay')),
  bank_snapshot JSONB DEFAULT '{}'::jsonb, -- salinan bank_name/account_no/holder masa payout dicipta
  payout_ref    TEXT,                      -- rujukan transaksi (manual, atau HitPay txn id kelak)
  note          TEXT,
  requested_at  TIMESTAMPTZ DEFAULT now(),
  processed_at  TIMESTAMPTZ,
  processed_by  UUID REFERENCES psy_profiles(id)
);

-- Sesuaikan constraint utk table sedia ada (idempotent).
-- GOTCHA (sama corak psy_notifications type_check): jangan teka nama
-- constraint (cth 'psy_affiliate_payouts_status_check') — kalau table
-- ni pernah dicipta/diubah melalui laluan lain, nama sebenar mungkin
-- tak sepadan dan DROP CONSTRAINT IF EXISTS senyap gagal (constraint
-- lama kekal, ADD baru pun gagal/insert lama-lama tersekat). Cari &
-- buang SEMUA check constraint pada kolum status secara dinamik.
UPDATE psy_affiliate_payouts SET status = 'processing' WHERE status NOT IN ('processing','paid','rejected');
DO $$
DECLARE c RECORD;
BEGIN
  FOR c IN
    SELECT con.conname FROM pg_constraint con
    JOIN pg_class rel ON rel.oid = con.conrelid
    WHERE rel.relname = 'psy_affiliate_payouts' AND con.contype = 'c'
      AND pg_get_constraintdef(con.oid) ILIKE '%status%'
  LOOP
    EXECUTE format('ALTER TABLE psy_affiliate_payouts DROP CONSTRAINT %I', c.conname);
  END LOOP;
END $$;
ALTER TABLE psy_affiliate_payouts ADD CONSTRAINT psy_affiliate_payouts_status_check
  CHECK (status IN ('processing','paid','rejected'));

-- GOTCHA lanjutan: CREATE TABLE IF NOT EXISTS tak ubah DEFAULT pada
-- jadual sedia ada — pada jadual yg dicipta sebelum ni, default kolum
-- `status` didapati kekal 'pending' (drift dari versi awal migration)
-- walaupun definisi CREATE TABLE atas kata 'processing'. Insert tanpa
-- nyatakan status (cth startPayout() di affiliate.html) jadi gagal
-- constraint. Paksa default betul secara eksplisit, idempotent.
ALTER TABLE psy_affiliate_payouts ALTER COLUMN status SET DEFAULT 'processing';

CREATE INDEX IF NOT EXISTS idx_psy_affiliate_payouts_patient ON psy_affiliate_payouts(patient_id, status);

ALTER TABLE psy_affiliate_payouts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Patients view own payouts" ON psy_affiliate_payouts;
CREATE POLICY "Patients view own payouts" ON psy_affiliate_payouts FOR SELECT
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

-- Payout dicipta oleh STAFF sahaja (staff proses & cetuskan bayaran, cth
-- sekali sebulan) — pesakit tak "mohon", cuma tengok status di profile.
DROP POLICY IF EXISTS "Staff manage payouts" ON psy_affiliate_payouts;
CREATE POLICY "Staff manage payouts" ON psy_affiliate_payouts FOR ALL
  USING      (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
  WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- FK psy_referrals.payout_id → psy_affiliate_payouts (jadual sasaran kini wujud)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE constraint_name = 'fk_psy_referrals_payout' AND table_name = 'psy_referrals'
  ) THEN
    ALTER TABLE psy_referrals
      ADD CONSTRAINT fk_psy_referrals_payout FOREIGN KEY (payout_id)
      REFERENCES psy_affiliate_payouts(id) ON DELETE SET NULL;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_psy_referrals_payout ON psy_referrals(payout_id);

-- ──── psy_notifications: benarkan type 'affiliate' ────
-- GOTCHA (dah pernah berlaku): ADD CONSTRAINT hardcode senarai 'type' boleh
-- gagal/mengecilkan liputan di PROD sebab constraint sebenar mungkin dah
-- melencong dari senarai inline dalam CREATE TABLE (banyak jenis notif
-- ditambah oleh modul lain, cth 'emergency'/'patient_event', tanpa
-- constraint fail ini diselaraskan). Jadi kita kekalkan SEMUA nilai type
-- sedia ada dalam jadual + tambah 'affiliate', bukan tulis semula senarai.
DO $$
DECLARE
  v_types TEXT;
BEGIN
  SELECT COALESCE(string_agg(DISTINCT quote_literal(type), ','), '') INTO v_types
  FROM psy_notifications;

  IF v_types = '' THEN
    v_types := quote_literal('system');
  END IF;
  IF position('affiliate' in v_types) = 0 THEN
    v_types := v_types || ',' || quote_literal('affiliate');
  END IF;

  ALTER TABLE psy_notifications DROP CONSTRAINT IF EXISTS psy_notifications_type_check;
  EXECUTE format(
    'ALTER TABLE psy_notifications ADD CONSTRAINT psy_notifications_type_check CHECK (type IN (%s))',
    v_types
  );
END $$;

-- ──── fn: kelayakan & kira komisen bila bayaran pesakit selesai ────
CREATE OR REPLACE FUNCTION trg_referral_qualify_on_payment()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_ref_id    UUID;
  v_pkg_text  TEXT;
  v_pkg_id    UUID;
  v_rule      RECORD;
  v_amount    NUMERIC(10,2);
  v_referrer_patient_id UUID;
  v_referrer_user_id    UUID;
BEGIN
  IF NEW.status IS DISTINCT FROM 'completed' OR NEW.patient_id IS NULL THEN
    RETURN NEW;
  END IF;
  IF TG_OP = 'UPDATE' AND OLD.status = 'completed' THEN
    RETURN NEW; -- elak kira dua kali
  END IF;

  SELECT id, referrer_patient_id INTO v_ref_id, v_referrer_patient_id FROM psy_referrals
  WHERE referee_patient_id = NEW.patient_id AND status = 'pending'
  LIMIT 1;
  IF v_ref_id IS NULL THEN
    RETURN NEW;
  END IF;

  -- Cuba kesan pakej dari baris pertama items[] (teks kod ATAU UUID —
  -- ikut ketidakkonsistenan active_package_id yang direkod dlm memory).
  BEGIN
    v_pkg_text := NEW.items -> 0 ->> 'packageId';
  EXCEPTION WHEN OTHERS THEN
    v_pkg_text := NULL;
  END;

  IF v_pkg_text IS NOT NULL THEN
    SELECT id INTO v_pkg_id FROM psy_packages
    WHERE id::text = v_pkg_text OR package_id = v_pkg_text
    LIMIT 1;
  END IF;

  SELECT * INTO v_rule FROM psy_affiliate_commission_rules
  WHERE package_id = v_pkg_id AND is_active LIMIT 1;

  IF NOT FOUND THEN
    SELECT * INTO v_rule FROM psy_affiliate_commission_rules
    WHERE package_id IS NULL AND is_active LIMIT 1;
  END IF;

  IF v_rule.id IS NOT NULL THEN
    IF v_rule.commission_type = 'fixed' THEN
      v_amount := COALESCE(v_rule.amount, 0);
    ELSE
      v_amount := ROUND(COALESCE(NEW.total, 0) * COALESCE(v_rule.rate_percent, 0) / 100, 2);
      IF v_rule.cap_amount IS NOT NULL THEN
        v_amount := LEAST(v_amount, v_rule.cap_amount);
      END IF;
    END IF;
  ELSE
    v_amount := 0;
  END IF;

  UPDATE psy_referrals SET
    status = 'qualified',
    qualified_at = now(),
    qualifying_payment_id = NEW.id,
    qualifying_package_id = v_pkg_id,
    commission_amount = v_amount
  WHERE id = v_ref_id;

  INSERT INTO psy_notifications (user_id, type, title, body, link)
  SELECT id, 'affiliate',
    '💰 Komisen Affiliate Layak',
    'Satu rujukan pesakit layak komisen RM ' || v_amount::text || '.',
    'affiliate.html'
  FROM psy_profiles WHERE role = 'staff';

  -- Bagitahu pesakit perujuk juga (kalau ada akaun) — supaya dia tahu
  -- serta-merta tanpa perlu check Profile secara manual.
  IF v_amount > 0 THEN
    SELECT user_id INTO v_referrer_user_id FROM psy_patients WHERE id = v_referrer_patient_id;
    IF v_referrer_user_id IS NOT NULL THEN
      INSERT INTO psy_notifications (user_id, type, title, body, link)
      VALUES (
        v_referrer_user_id, 'affiliate',
        '🎉 Kawan Anda Dah Daftar!',
        'Anda layak komisen RM ' || v_amount::text || ' dari rujukan anda.',
        'profile.html'
      );
    END IF;
  END IF;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE LOG 'trg_referral_qualify_on_payment: %', SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_referral_qualify_on_payment ON psy_payments;
CREATE TRIGGER trg_referral_qualify_on_payment
  AFTER INSERT OR UPDATE ON psy_payments
  FOR EACH ROW EXECUTE FUNCTION trg_referral_qualify_on_payment();
