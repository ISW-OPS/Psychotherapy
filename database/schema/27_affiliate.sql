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

-- ──── psy_patients — attribution GHL Affiliate Manager (27 Okt 2026) ────
-- Skop BAHARU di luar rujukan pesakit-ke-pesakit asal (psy_referrals di
-- atas): GHL Affiliate Manager (affiliate luar/"Duta", bukan semestinya
-- pesakit ISW) ada sistem rujukan+komisen SENDIRI (tertutup — tiada API
-- awam/merge tag standard, disahkan 27 Okt 2026). Custom field GHL
-- (folder "PT Sytem") bekalkan field keys ni — rujuk
-- supabase/functions/ghl-booking-webhook/README.md bahagian (d)/(e):
--   contact.referred_by_affiliate → nama affiliate yang rujuk PESAKIT ni
--     (hidup pada contact PESAKIT, event='contact'/'appointment'/'order')
--   contact.kob_referal_code / contact.affiliate_link → kod & pautan
--     affiliate ITU SENDIRI (hidup pada contact AFFILIATE, event='affiliate')
-- Padanan affiliate↔pesakit cuma ikut NAMA (text) — GHL tak bekalkan kod
-- affiliate pada contact pelanggan lagi (boleh ditambah kemudian utk
-- padanan lebih tepat, lihat README).
ALTER TABLE psy_patients ADD COLUMN IF NOT EXISTS referred_by_affiliate_name TEXT;
ALTER TABLE psy_patients ADD COLUMN IF NOT EXISTS affiliate_code TEXT;
ALTER TABLE psy_patients ADD COLUMN IF NOT EXISTS affiliate_link TEXT;

-- contact.referred_by_affiliate_email / _phone (folder "PT Sytem", disahkan
-- 29 Okt 2026 via list_custom_fields) — email & no phone affiliate yang
-- rujuk pesakit ni, sama field group dengan referred_by_affiliate_name di
-- atas. Dipaparkan terus di kob-detail.html seksyen "Affiliate" (keputusan
-- user: 3 data ni terus dari GHL, bukan pengiraan psy_referrals).
ALTER TABLE psy_patients ADD COLUMN IF NOT EXISTS referred_by_affiliate_email TEXT;
ALTER TABLE psy_patients ADD COLUMN IF NOT EXISTS referred_by_affiliate_phone TEXT;

-- ──── psy_external_affiliates — affiliate GHL yang BUKAN semestinya pesakit
-- ISW (keputusan user 27 Okt 2026: komisen pakej OB — bayaran HitPay di ISW,
-- GHL tiada visibiliti — mesti dikira di ISW utk SEMUA affiliate, pesakit
-- atau tidak). `linked_patient_id` diisi automatik kalau telefon affiliate
-- padan dgn psy_patients sedia ada (dia kebetulan pesakit juga) — rujuk
-- upsertExternalAffiliate() di ghl-sync.ts.
CREATE TABLE IF NOT EXISTS psy_external_affiliates (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  full_name           TEXT NOT NULL,
  phone               TEXT,
  email               TEXT,
  bank_name           TEXT,
  bank_account_no     TEXT,
  bank_account_holder TEXT,
  ic_number           TEXT,   -- {{contact.no_ic_agent}} (borang "Duta Sihat Sefitrahnya", 28 Okt 2026)
  address             TEXT,   -- {{contact.alamat_agent}}
  ghl_affiliate_code  TEXT,   -- {{contact.kob_referal_code}} (ejaan GHL — SATU "r")
  affiliate_link      TEXT,   -- {{contact.affiliate_link}}
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
-- Tiada polisi pesakit/login — affiliate luar tiada akaun ISW, staff sahaja nampak.

-- ──── psy_referrals — benarkan perujuk jadi affiliate luar (bukan psy_patients) ────
-- referrer_patient_id (sedia ada) kekal utk rujukan pesakit-ke-pesakit asal
-- (laluan ?ref=). referrer_affiliate_id (baharu) utk rujukan dari GHL
-- Affiliate Manager — TEPAT SATU drpd dua ni wajib diisi (CHECK di bawah).
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

-- ──── psy_referrals — tambah kolum komisen ────
ALTER TABLE psy_referrals ADD COLUMN IF NOT EXISTS qualifying_payment_id UUID REFERENCES psy_payments(id) ON DELETE SET NULL;
ALTER TABLE psy_referrals ADD COLUMN IF NOT EXISTS qualifying_package_id UUID REFERENCES psy_packages(id) ON DELETE SET NULL;
ALTER TABLE psy_referrals ADD COLUMN IF NOT EXISTS commission_amount NUMERIC(10,2) DEFAULT 0;
ALTER TABLE psy_referrals ADD COLUMN IF NOT EXISTS payout_id UUID; -- FK ditambah di bawah (selepas psy_affiliate_payouts wujud)

-- ──── psy_affiliate_payouts — lejar bayaran keluar (batch per pesakit/affiliate) ────
CREATE TABLE IF NOT EXISTS psy_affiliate_payouts (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id    UUID REFERENCES psy_patients(id) ON DELETE CASCADE,
  affiliate_id  UUID REFERENCES psy_external_affiliates(id) ON DELETE CASCADE, -- (27 Okt 2026) payout utk affiliate GHL luar
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

-- (27 Okt 2026) Jadual sedia ada dicipta dgn patient_id NOT NULL — kini
-- payout boleh jadi affiliate luar pulak (affiliate_id), jadi patient_id
-- kena jadi opsyenal. affiliate_id ditambah di atas (CREATE TABLE IF NOT
-- EXISTS tak sentuh jadual sedia ada — ALTER eksplisit di sini jamin ia
-- wujud jua pada jadual yg dah dicipta sebelum perubahan ni).
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

CREATE INDEX IF NOT EXISTS idx_psy_affiliate_payouts_patient ON psy_affiliate_payouts(patient_id, status);
CREATE INDEX IF NOT EXISTS idx_psy_affiliate_payouts_affiliate ON psy_affiliate_payouts(affiliate_id, status);

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

-- ──── psy_affiliate_commission_tiers — komisen TIER ikut volume SU/bulan
-- (27 Okt 2026, keputusan user: "kadar komisen OB pun sama macam KOB")
-- GANTI model lama (psy_affiliate_commission_rules, fixed/percent PER
-- PAKEJ) khas utk rujukan GHL affiliate (source='ghl_affiliate') —
-- kadar kini ikut JUMLAH "SU" (sign-up pakej, lepas KOB settle) affiliate
-- tu hasilkan BULAN tu, bukan ikut pakej mana dibeli. Rujukan pesakit-ke-
-- pesakit asal (?ref=, source='patient') KEKAL guna
-- psy_affiliate_commission_rules — TIDAK terjejas/diubah.
--
-- Tier disahkan (poster "Duta Sihat Sefitrahnya"):
--   0-49 SU/bulan   → RM20/SU, tiada bonus bulanan        = RM20/SU
--   50-99 SU/bulan  → RM20/SU + RM10 bonus bulanan/SU     = RM30/SU
--   100+ SU/bulan   → RM20/SU + RM20 bonus bulanan/SU     = RM40/SU
-- Bonus TAHUNAN (RM10/RM20 extra lepas 1,000+ SU setahun) BELUM dibina —
-- poster cuma beri 2 titik data ilustrasi (99/bulan, 100/bulan), tak
-- cukup spec tepat macam mana kadar ditentukan bila volume affiliate
-- naik-turun merentas bulan. TANGGUH sehingga disahkan.
CREATE TABLE IF NOT EXISTS psy_affiliate_commission_tiers (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  min_su               INT NOT NULL,
  max_su               INT,  -- NULL = tiada had atas
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

-- ──── fn: kira semula tier affiliate utk SATU bulan (retroaktif) ────
-- Dipanggil lepas SETIAP SU baharu qualify bulan tu — jumlah SU TERKINI
-- bulan tu ditentukan tier, kadar gabungan (rate_per_su+bonus_bulanan_per_su)
-- disapu KE SEMUA SU bulan tu (bukan pro-rata). Memandangkan SU tak pernah
-- "backdate" (qualified_at = now() semasa trigger bayaran), nilai yang
-- tersimpan pada bila-bila masa SUDAH jadi jawapan akhir bulan tu —
-- TIADA cron/batch bulanan diperlukan, trigger ni cukup.
-- Payout yang DAH dicipta (payout_id bukan NULL) TAK disentuh — kunci
-- amaun selepas staff mula proses bayaran.
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
    RETURN NEW; -- elak kira dua kali
  END IF;

  SELECT id, referrer_patient_id, referrer_affiliate_id, source
    INTO v_ref_id, v_referrer_patient_id, v_referrer_affiliate_id, v_source
  FROM psy_referrals
  WHERE referee_patient_id = NEW.patient_id AND status = 'pending'
  LIMIT 1;
  IF v_ref_id IS NULL THEN
    RETURN NEW;
  END IF;

  -- (27 Okt 2026) Rujukan GHL affiliate — "1 SU" cuma layak lepas pesakit
  -- SETTLE sesi KOB (hadir/completed), bukan setakat bayar pakej.
  IF v_source = 'ghl_affiliate' THEN
    SELECT EXISTS (
      SELECT 1 FROM psy_kob_sessions WHERE patient_id = NEW.patient_id AND status IN ('hadir','completed')
    ) INTO v_has_kob;
    IF NOT v_has_kob THEN
      RETURN NEW; -- KOB belum settle — belum layak qualify lagi
    END IF;
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

  IF v_source = 'ghl_affiliate' THEN
    -- Nilai AWAL sahaja — recalc_affiliate_commission_tier() di bawah
    -- timpa dgn kadar tier SEBENAR serta-merta (dalam transaksi sama).
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
