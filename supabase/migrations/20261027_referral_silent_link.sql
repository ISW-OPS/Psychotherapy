-- ═══════════════════════════════════════════════════════════════════
-- 20261027 — Pautan Rujukan Senyap (Silent Referral Link)
-- Gap: butang "attach kod rujukan" dibuang 20 Ogos (pendaftaran/patient-form/
-- kob-detail/patients), tiada laluan ganti dibina. Sejak itu psy_referrals
-- tak pernah dapat baris baharu (trigger trg_referral_qualify_on_payment
-- di 27_affiliate.sql masih betul, cuma tiada input). Fix: pesakit kongsi
-- pautan peribadi (?ref=KOD) — kawan klik & daftar, sistem link rujukan
-- SENYAP di belakang tabir (tiada medan "kod rujukan" dipaparkan kat borang).
--
-- RLS psy_referrals TIADA polisi INSERT untuk pesakit (cuma "Staff manage
-- referrals" ALL + "Patients read own referrals" SELECT) — insert client-side
-- terus akan block. RPC SECURITY DEFINER ni ikut pattern sedia ada
-- (check_referral_code/find_unclaimed_patient/claim_unclaimed_patient).
-- ═══════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION create_patient_referral(p_code TEXT, p_referee_patient_id UUID)
RETURNS TABLE (ok BOOLEAN, message TEXT)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_referrer_id UUID;
BEGIN
  -- referee MESTI padan akaun pemanggil — elak sesiapa cipta rujukan bagi pihak pesakit lain.
  IF NOT EXISTS (
    SELECT 1 FROM psy_patients WHERE id = p_referee_patient_id AND user_id = auth.uid()
  ) THEN
    RETURN QUERY SELECT FALSE, 'Tidak sah — bukan akaun anda'; RETURN;
  END IF;

  IF p_code IS NULL OR trim(p_code) = '' THEN
    RETURN QUERY SELECT FALSE, 'Tiada kod'; RETURN;
  END IF;

  SELECT id INTO v_referrer_id FROM psy_patients
  WHERE upper(trim(referral_code)) = upper(trim(p_code)) LIMIT 1;

  IF v_referrer_id IS NULL THEN
    RETURN QUERY SELECT FALSE, 'Kod rujukan tidak dijumpai'; RETURN;
  END IF;

  IF v_referrer_id = p_referee_patient_id THEN
    RETURN QUERY SELECT FALSE, 'Tidak boleh rujuk diri sendiri'; RETURN;
  END IF;

  -- UNIQUE(referee_patient_id) di psy_referrals jamin ini di peringkat DB jua —
  -- semakan EXISTS di sini sekadar elak error & bagi mesej mesra.
  IF EXISTS (SELECT 1 FROM psy_referrals WHERE referee_patient_id = p_referee_patient_id) THEN
    RETURN QUERY SELECT FALSE, 'Pesakit ini sudah ada rujukan'; RETURN;
  END IF;

  INSERT INTO psy_referrals (referrer_patient_id, referee_patient_id, code_used, status)
  VALUES (v_referrer_id, p_referee_patient_id, upper(trim(p_code)), 'pending');

  RETURN QUERY SELECT TRUE, 'OK';
EXCEPTION WHEN OTHERS THEN
  RETURN QUERY SELECT FALSE, SQLERRM;
END;
$$;

-- ──── Kod rujukan: ISW+MRN (boleh diteka) → 6 huruf rawak ────
-- Format lama 'ISW' || digit MRN (cth ISW019) secara tak langsung dedahkan
-- MRN pesakit dalam pautan rujukan awam (?ref=ISW019) & senang diteka
-- (ISW001, ISW002...). Tukar ke 6 huruf rawak — lihat 20_referrals.sql.
CREATE OR REPLACE FUNCTION assign_referral_code()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  candidate TEXT;
BEGIN
  IF NEW.referral_code IS NOT NULL AND length(trim(NEW.referral_code)) > 0 THEN
    NEW.referral_code := upper(trim(NEW.referral_code));
    RETURN NEW;
  END IF;

  LOOP
    SELECT string_agg(substr('ABCDEFGHIJKLMNOPQRSTUVWXYZ', (random() * 25 + 1)::int, 1), '')
    INTO candidate FROM generate_series(1, 6);
    EXIT WHEN NOT EXISTS (SELECT 1 FROM psy_patients WHERE referral_code = candidate);
  END LOOP;

  NEW.referral_code := candidate;
  RETURN NEW;
END;
$$;

-- Backfill — jana semula kod SEDIA ADA (format lama ISW+MRN) ke format
-- baharu. Selamat: disahkan 27 Okt 2026 tiada satu pun baris psy_referrals
-- wujud lagi (rantaian rujukan putus sejak Ogos — lihat nota migration ni
-- di atas), jadi tiada kod lama yang sedang "aktif" dikongsi/digunakan.
DO $$
DECLARE
  r RECORD;
  candidate TEXT;
BEGIN
  FOR r IN SELECT id FROM psy_patients WHERE referral_code IS NOT NULL LOOP
    LOOP
      SELECT string_agg(substr('ABCDEFGHIJKLMNOPQRSTUVWXYZ', (random() * 25 + 1)::int, 1), '')
      INTO candidate FROM generate_series(1, 6);
      EXIT WHEN NOT EXISTS (SELECT 1 FROM psy_patients WHERE referral_code = candidate);
    END LOOP;
    UPDATE psy_patients SET referral_code = candidate WHERE id = r.id;
  END LOOP;
END $$;

-- ═══════════════════════════════════════════════════════════════════
-- GHL Affiliate Manager — attribution + maklumat agent sendiri
-- (sambungan supabase/functions/ghl-booking-webhook event='affiliate'
-- baharu + field "referred_by_affiliate" pada event sedia ada)
-- ═══════════════════════════════════════════════════════════════════
ALTER TABLE psy_patients ADD COLUMN IF NOT EXISTS referred_by_affiliate_name TEXT;
ALTER TABLE psy_patients ADD COLUMN IF NOT EXISTS affiliate_code TEXT;
ALTER TABLE psy_patients ADD COLUMN IF NOT EXISTS affiliate_link TEXT;

-- ──── psy_external_affiliates — affiliate GHL BUKAN semestinya pesakit ISW ────
-- (keputusan user 27 Okt 2026: komisen pakej OB (bayaran HitPay di ISW,
-- GHL tiada visibiliti) mesti dikira di ISW utk SEMUA affiliate.)
CREATE TABLE IF NOT EXISTS psy_external_affiliates (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  full_name           TEXT NOT NULL,
  phone               TEXT,
  email               TEXT,
  bank_name           TEXT,
  bank_account_no     TEXT,
  bank_account_holder TEXT,
  ghl_affiliate_code  TEXT,
  affiliate_link      TEXT,
  ghl_contact_id      TEXT,
  linked_patient_id   UUID REFERENCES psy_patients(id) ON DELETE SET NULL,
  created_at          TIMESTAMPTZ DEFAULT now(),
  updated_at          TIMESTAMPTZ DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_psy_external_affiliates_phone
  ON psy_external_affiliates (phone) WHERE phone IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_psy_external_affiliates_name
  ON psy_external_affiliates (lower(full_name));

ALTER TABLE psy_external_affiliates ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Staff manage external affiliates" ON psy_external_affiliates;
CREATE POLICY "Staff manage external affiliates" ON psy_external_affiliates FOR ALL
  USING      (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
  WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- ──── psy_referrals — benarkan perujuk jadi affiliate luar ────
ALTER TABLE psy_referrals ADD COLUMN IF NOT EXISTS referrer_affiliate_id UUID REFERENCES psy_external_affiliates(id) ON DELETE CASCADE;
ALTER TABLE psy_referrals ADD COLUMN IF NOT EXISTS source TEXT NOT NULL DEFAULT 'patient' CHECK (source IN ('patient','ghl_affiliate'));

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_psy_referrals_referrer') THEN
    ALTER TABLE psy_referrals ADD CONSTRAINT chk_psy_referrals_referrer CHECK (
      (referrer_patient_id IS NOT NULL AND referrer_affiliate_id IS NULL) OR
      (referrer_patient_id IS NULL AND referrer_affiliate_id IS NOT NULL)
    );
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_psy_referrals_referrer_affiliate ON psy_referrals (referrer_affiliate_id);

-- ──── psy_affiliate_payouts — benarkan payout utk affiliate luar ────
ALTER TABLE psy_affiliate_payouts ALTER COLUMN patient_id DROP NOT NULL;
ALTER TABLE psy_affiliate_payouts ADD COLUMN IF NOT EXISTS affiliate_id UUID REFERENCES psy_external_affiliates(id) ON DELETE CASCADE;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_psy_affiliate_payouts_target') THEN
    ALTER TABLE psy_affiliate_payouts ADD CONSTRAINT chk_psy_affiliate_payouts_target CHECK (
      (patient_id IS NOT NULL AND affiliate_id IS NULL) OR
      (patient_id IS NULL AND affiliate_id IS NOT NULL)
    );
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_psy_affiliate_payouts_affiliate ON psy_affiliate_payouts(affiliate_id, status);

-- ═══════════════════════════════════════════════════════════════════
-- Komisen TIER ikut volume SU/bulan utk rujukan GHL affiliate
-- (keputusan user 27 Okt 2026: "kadar komisen OB pun sama macam KOB")
-- Rujukan pesakit-ke-pesakit asal (source='patient') KEKAL guna
-- psy_affiliate_commission_rules — TIDAK terjejas.
-- ═══════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS psy_affiliate_commission_tiers (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  min_su               INT NOT NULL,
  max_su               INT,
  rate_per_su          NUMERIC(10,2) NOT NULL,
  bonus_bulanan_per_su NUMERIC(10,2) NOT NULL DEFAULT 0,
  is_active            BOOLEAN NOT NULL DEFAULT true,
  created_at           TIMESTAMPTZ DEFAULT now()
);

INSERT INTO psy_affiliate_commission_tiers (min_su, max_su, rate_per_su, bonus_bulanan_per_su)
SELECT * FROM (VALUES
  (0,   49,   20.00, 0.00),
  (50,  99,   20.00, 10.00),
  (100, NULL, 20.00, 20.00)
) AS v(min_su, max_su, rate_per_su, bonus_bulanan_per_su)
WHERE NOT EXISTS (SELECT 1 FROM psy_affiliate_commission_tiers);

ALTER TABLE psy_affiliate_commission_tiers ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Staff manage commission tiers" ON psy_affiliate_commission_tiers;
CREATE POLICY "Staff manage commission tiers" ON psy_affiliate_commission_tiers FOR ALL
  USING      (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
  WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

ALTER TABLE psy_referrals ADD COLUMN IF NOT EXISTS commission_month DATE;

CREATE OR REPLACE FUNCTION recalc_affiliate_commission_tier(p_affiliate_id UUID, p_month DATE)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_su_count INT;
  v_tier     RECORD;
  v_rate     NUMERIC(10,2);
BEGIN
  IF p_affiliate_id IS NULL OR p_month IS NULL THEN RETURN; END IF;

  SELECT count(*) INTO v_su_count FROM psy_referrals
  WHERE referrer_affiliate_id = p_affiliate_id
    AND source = 'ghl_affiliate'
    AND status = 'qualified'
    AND commission_month = p_month;

  SELECT * INTO v_tier FROM psy_affiliate_commission_tiers
  WHERE is_active AND min_su <= v_su_count AND (max_su IS NULL OR v_su_count <= max_su)
  ORDER BY min_su DESC LIMIT 1;

  v_rate := COALESCE(v_tier.rate_per_su, 0) + COALESCE(v_tier.bonus_bulanan_per_su, 0);

  UPDATE psy_referrals SET commission_amount = v_rate
  WHERE referrer_affiliate_id = p_affiliate_id
    AND source = 'ghl_affiliate'
    AND status = 'qualified'
    AND payout_id IS NULL
    AND commission_month = p_month;
END;
$$;

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
  v_referrer_patient_id   UUID;
  v_referrer_affiliate_id UUID;
  v_referrer_user_id      UUID;
  v_source    TEXT;
  v_has_kob   BOOLEAN;
  v_month     DATE;
BEGIN
  IF NEW.status IS DISTINCT FROM 'completed' OR NEW.patient_id IS NULL THEN
    RETURN NEW;
  END IF;
  IF TG_OP = 'UPDATE' AND OLD.status = 'completed' THEN
    RETURN NEW;
  END IF;

  SELECT id, referrer_patient_id, referrer_affiliate_id, source
    INTO v_ref_id, v_referrer_patient_id, v_referrer_affiliate_id, v_source
  FROM psy_referrals
  WHERE referee_patient_id = NEW.patient_id AND status = 'pending'
  LIMIT 1;
  IF v_ref_id IS NULL THEN
    RETURN NEW;
  END IF;

  IF v_source = 'ghl_affiliate' THEN
    SELECT EXISTS (
      SELECT 1 FROM psy_kob_sessions WHERE patient_id = NEW.patient_id AND status IN ('hadir','completed')
    ) INTO v_has_kob;
    IF NOT v_has_kob THEN
      RETURN NEW;
    END IF;
  END IF;

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

  IF v_source = 'ghl_affiliate' THEN
    v_amount := 0;
  ELSE
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
  END IF;

  v_month := date_trunc('month', now())::date;

  UPDATE psy_referrals SET
    status = 'qualified',
    qualified_at = now(),
    qualifying_payment_id = NEW.id,
    qualifying_package_id = v_pkg_id,
    commission_amount = v_amount,
    commission_month = v_month
  WHERE id = v_ref_id;

  IF v_source = 'ghl_affiliate' THEN
    PERFORM recalc_affiliate_commission_tier(v_referrer_affiliate_id, v_month);
    SELECT commission_amount INTO v_amount FROM psy_referrals WHERE id = v_ref_id;
  END IF;

  INSERT INTO psy_notifications (user_id, type, title, body, link)
  SELECT id, 'affiliate',
    '💰 Komisen Affiliate Layak',
    'Satu rujukan pesakit layak komisen RM ' || v_amount::text || '.',
    'affiliate.html'
  FROM psy_profiles WHERE role = 'staff';

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
