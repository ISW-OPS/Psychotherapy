-- ═══════════════════════════════════════════════════════════════
-- RUJUKAN
-- Jadual: psy_referrals (ganjaran rujukan pesakit-ke-pesakit),
--         psy_clinical_referrals (coach/staff rujuk pesakit kpd
--         doctor / coach lain / manager)
-- Fungsi: assign_referral_code (trigger fn), check_referral_code (RPC)
-- ═══════════════════════════════════════════════════════════════

-- ──── assign_referral_code (auto-jana kod rujukan pesakit) ────
-- Client (JS) akan set kod cantik (nama+MRN) sebelum insert; jika
-- masih NULL, fungsi trigger ini jamin satu kod unik tetap wujud.
-- Nota: trigger MRN (trg_assign_patient_mrn) berjalan dulu ikut abjad
-- nama, jadi NEW.mrn sudah diisi bila trigger ini berjalan.
CREATE OR REPLACE FUNCTION assign_referral_code()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  base      TEXT;
  candidate TEXT;
  n         INT := 1;
BEGIN
  -- Kod sudah diset client — normalkan ke huruf besar & biarkan
  IF NEW.referral_code IS NOT NULL AND length(trim(NEW.referral_code)) > 0 THEN
    NEW.referral_code := upper(trim(NEW.referral_code));
    RETURN NEW;
  END IF;

  -- Fallback: 'ISW' + digit MRN (cth P-019 -> ISW019)
  base := 'ISW' || regexp_replace(COALESCE(NEW.mrn, ''), '\D', '', 'g');
  IF base = 'ISW' THEN
    base := 'ISW' || to_char((random() * 9000 + 1000)::int, 'FM0000');
  END IF;

  candidate := base;
  WHILE EXISTS (SELECT 1 FROM psy_patients WHERE referral_code = candidate) LOOP
    n := n + 1;
    candidate := base || n;
  END LOOP;

  NEW.referral_code := candidate;
  RETURN NEW;
END;
$$;

-- Trigger pada psy_patients (jadual dari 04_patients.sql) — diletak di sini
-- kerana fungsinya ditakrif di atas.
DROP TRIGGER IF EXISTS trg_assign_referral_code ON psy_patients;
CREATE TRIGGER trg_assign_referral_code
  BEFORE INSERT ON psy_patients
  FOR EACH ROW
  EXECUTE FUNCTION assign_referral_code();

-- ──── check_referral_code (RPC) ────
-- Semak sama ada kod rujukan wujud. SECURITY DEFINER supaya pesakit
-- baru boleh semak tanpa RLS.
CREATE OR REPLACE FUNCTION check_referral_code(p_code TEXT)
RETURNS TABLE (valid BOOLEAN, referrer_name TEXT)
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  RETURN QUERY
  SELECT TRUE, p.full_name
  FROM psy_patients p
  WHERE upper(trim(p.referral_code)) = upper(trim(p_code))
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN QUERY SELECT FALSE, NULL::TEXT;
  END IF;
END;
$$;

-- ──── psy_referrals (lejar ganjaran rujukan pesakit-ke-pesakit) ────
CREATE TABLE IF NOT EXISTS psy_referrals (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  referrer_patient_id UUID REFERENCES psy_patients(id) ON DELETE CASCADE,
  referee_patient_id  UUID REFERENCES psy_patients(id) ON DELETE CASCADE,
  code_used           TEXT,
  -- pending   = pesakit baru dah daftar, belum bayar
  -- qualified = pesakit baru dah buat bayaran pertama (ganjaran layak)
  -- rewarded  = staf dah beri baucar (kedua-dua pihak)
  -- void      = dibatalkan (cth rujukan palsu)
  status              TEXT DEFAULT 'pending'
                        CHECK (status IN ('pending','qualified','rewarded','void')),
  qualified_at        TIMESTAMPTZ,
  reward_note         TEXT,
  rewarded_at         TIMESTAMPTZ,
  rewarded_by         UUID REFERENCES psy_profiles(id),
  created_at          TIMESTAMPTZ DEFAULT now(),
  -- Satu pesakit baru hanya boleh dirujuk sekali
  UNIQUE (referee_patient_id)
);

CREATE INDEX IF NOT EXISTS idx_psy_referrals_referrer ON psy_referrals (referrer_patient_id);
CREATE INDEX IF NOT EXISTS idx_psy_referrals_status   ON psy_referrals (status);

ALTER TABLE psy_referrals ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff manage referrals" ON psy_referrals;
CREATE POLICY "Staff manage referrals" ON psy_referrals FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "Patients read own referrals" ON psy_referrals;
CREATE POLICY "Patients read own referrals" ON psy_referrals FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM psy_patients pp
    WHERE pp.id IN (psy_referrals.referrer_patient_id, psy_referrals.referee_patient_id)
      AND pp.user_id = auth.uid()
  ));

-- ──── psy_clinical_referrals (rujukan klinikal pesakit) ────
-- Coach/staff rujuk pesakit kepada doctor / coach lain / manager
-- (Hakeem/Hakeema). Sasaran dipilih secara spesifik (target_id).
-- Notifikasi guna psy_notifications type 'referral'.
CREATE TABLE IF NOT EXISTS psy_clinical_referrals (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id        UUID NOT NULL REFERENCES psy_patients(id) ON DELETE CASCADE,
  referred_by       UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  referred_by_name  TEXT,
  target_role       TEXT NOT NULL CHECK (target_role IN ('doctor','coach','manager')),
  target_id         UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  target_name       TEXT,
  reason            TEXT NOT NULL,
  meet_date         DATE,                       -- tarikh pesakit perlu jumpa (dari jadual rawatan)
  priority          TEXT NOT NULL DEFAULT 'sederhana'
                      CHECK (priority IN ('rendah','sederhana','tinggi')),
  status            TEXT NOT NULL DEFAULT 'pending'
                      CHECK (status IN ('pending','accepted','resolved','declined')),
  resolution_note   TEXT,
  consultation_note TEXT,                       -- nota sesi rujukan (Hakeem/doctor/coach)
  consultation      JSONB DEFAULT '{}'::jsonb,  -- borang konsultasi berstruktur
  attachments       JSONB DEFAULT '[]'::jsonb,  -- transkrip/dokumen: [{name,path,uploaded_at}]
  -- Sesi 1:1 auto-jana dari week plan (cth Hakeema 1:1 minggu 6/11) — plan_id+week_number
  -- kekal NULL utk rujukan manual biasa. source='plan_1on1' + session_type + unique index elak duplicate.
  plan_id           UUID REFERENCES psy_treatment_plans(id) ON DELETE SET NULL,
  week_number       INT,
  source            TEXT NOT NULL DEFAULT 'manual' CHECK (source IN ('manual','plan_1on1')),
  -- Jenis sesi 1:1 ad-hoc ditanda terus di plan-week.html (checkbox Hakeema/Hakeem/Dr
  -- Session). NULL utk rujukan manual biasa (source='manual').
  session_type      TEXT CHECK (session_type IN ('hakeema','hakeem','dr')),
  created_at        TIMESTAMPTZ DEFAULT now(),
  updated_at        TIMESTAMPTZ DEFAULT now(),
  resolved_at       TIMESTAMPTZ,
  -- Ditambah 23 Sept 2026 (audit management #B2-4) — saranan sesi tak boleh berhenti
  -- sbg nota bebas; perlu Next Action + PIC + Due Date boleh dijejak sehingga selesai.
  next_action        TEXT,
  next_action_pic    UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  next_action_due    DATE,
  next_action_done_at TIMESTAMPTZ,
  -- Ditambah 8 Okt 2026 (audit #17b/#17c) — follow-up saranan Sesi 1:1 kini
  -- AUTO-hantar oleh cron (event-reminders), bukan staf klik wa.me manual lagi;
  -- follow_up_date/follow_up_result sendiri KEKAL dlm consultation JSONB (sedia
  -- ada), tapi follow_up_sent_at diletak TOP-LEVEL supaya cron senang query/dedup.
  follow_up_sent_at        TIMESTAMPTZ,
  -- Reminder harian per-saranan (audit #17c) — staf tandakan masa di
  -- sesi-1on1-detail.html, cron hantar WA ringkas tiap hari sepanjang
  -- tempoh saranan (saranan_start + saranan_days, dlm consultation JSONB).
  reminder_time            TIME,
  reminder_last_sent_date  DATE
);

CREATE INDEX IF NOT EXISTS idx_psy_clinical_referrals_target  ON psy_clinical_referrals(target_id, status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_psy_clinical_referrals_patient ON psy_clinical_referrals(patient_id, created_at DESC);
CREATE UNIQUE INDEX IF NOT EXISTS uq_psy_clinical_referrals_plan_1on1
  ON psy_clinical_referrals(plan_id, week_number, session_type) WHERE source = 'plan_1on1';

ALTER TABLE psy_clinical_referrals ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff manage clinical referrals" ON psy_clinical_referrals;
CREATE POLICY "Staff manage clinical referrals" ON psy_clinical_referrals FOR ALL
  USING      (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
  WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
