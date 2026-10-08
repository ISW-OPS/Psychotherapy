-- ═══════════════════════════════════════════════════════════════════
-- 04_patients.sql — Domain Pesakit
-- Jadual: psy_patients, psy_kyc_submissions, psy_patient_notes,
--         psy_patient_documents
-- Fungsi/Trigger: MRN autogen, referral code, KYC→patient sync,
--                 updated_at, auto-inactive, stub pesakit self-register
-- Nota kebergantungan: psy_profiles (01), psy_treatment_plans /
--   psy_plan_weekly_progress (plan), fungsi assign_referral_code
--   (didefinisi dalam domain referral).
-- ═══════════════════════════════════════════════════════════════════

-- ────────────────────────────────────────────────
-- psy_patients — rekod induk pesakit
-- ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS psy_patients (
  id                              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id                         UUID REFERENCES psy_profiles(id) ON DELETE CASCADE,
  mrn                             TEXT UNIQUE,
  full_name                       TEXT,
  phone                           TEXT,
  email                           TEXT,
  ic_number                       TEXT,
  date_of_birth                   DATE,
  gender                          TEXT CHECK (gender IN ('M','F')),
  marital_status                  TEXT,
  occupation                      TEXT,
  company                         TEXT,
  address                         TEXT,
  home_address                    TEXT,
  postcode                        TEXT,
  city                            TEXT,
  state                           TEXT,
  emergency_contact_name          TEXT,
  emergency_contact_phone         TEXT,
  emergency_contact_ic            TEXT,
  emergency_contact_relationship  TEXT,
  emergency_contact_email         TEXT,
  contact_preference              TEXT DEFAULT 'pesakit' CHECK (contact_preference IN ('pesakit','waris')),
  -- Sejauh mana pendaftar (kalau bukan pesakit sendiri) terlibat isi borang.
  -- BEZA drpd contact_preference (siapa) — ni "sejauh mana" (urus penuh /
  -- bantu isi sahaja / sendiri). Sumber: GHL {{contact.anda_mengisi_borang_ini_sebagai}}.
  registrant_capacity             TEXT,
  -- ID dalaman contact GHL ({{contact.id}}) — rujukan pantas/debug & future
  -- API call terus ke GHL. TIDAK dipakai untuk padanan pesakit (kekal ikut
  -- telefon) — sekadar simpanan rujukan.
  ghl_contact_id                  TEXT,
  insurance_provider              TEXT,
  insurance_policy                TEXT,
  referral_source                 TEXT,
  medical_condition               TEXT,
  condition_duration              TEXT,
  medical_notes                   TEXT,
  -- Ditambah 8 Okt 2026 (audit #20) — flag eksplisit ditandakan staf (checkbox),
  -- BUKAN keyword-matching pada medical_condition free-text (terlalu fragile).
  -- Bila true, trigger trg_patient_kidney_alert_notify (bawah) amaran coach
  -- pasal kadar peminuman air & larangan suntikan/kolar vena di lengan akses
  -- dialisis. Banner amaran jugak papar di patient-hub.html bila profil dibuka.
  has_kidney_condition             BOOLEAN NOT NULL DEFAULT false,
  height_cm                       NUMERIC,
  active_package_id               TEXT,
  active_package_name             TEXT,
  package_purchased_at            TIMESTAMPTZ,
  package_expires_at              TIMESTAMPTZ,
  next_package_id                 TEXT,
  next_package_name               TEXT,
  daily_schedule                  JSONB,
  booking_blocked                 BOOLEAN NOT NULL DEFAULT false,
  booking_blocked_reason          TEXT,
  booking_blocked_since           TIMESTAMPTZ,
  status                          TEXT DEFAULT 'active',
  kob_status                      TEXT NOT NULL DEFAULT 'paid',
  outcome_status                  TEXT,
  outcome_status_at               TIMESTAMPTZ,
  outcome_status_notes            TEXT,
  coach_id                        UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  assigned_at                     TIMESTAMPTZ,
  created_by_staff                BOOLEAN DEFAULT false,
  reference_code                  TEXT,
  ghl_kob_code                    TEXT,  -- kod GHL "SU KOB Auto ID" (cth "KOB'26-000139"), diasingkan drpd full_name — LIHAT _shared/ghl-sync.ts. BUKAN reference_code (tu "Kod Pesakit", diisi lepas signup pakej OB).
  documents                       JSONB DEFAULT '{}',
  referral_code                   TEXT,
  referred_by_code                TEXT,
  referred_by_patient_id          UUID REFERENCES psy_patients(id) ON DELETE SET NULL,
  created_at                      TIMESTAMPTZ DEFAULT now(),
  updated_at                      TIMESTAMPTZ DEFAULT now(),
  CONSTRAINT psy_patients_user_id_unique UNIQUE (user_id),
  CONSTRAINT psy_patients_status_check CHECK (status IN (
    'pending_kyc','active','inactive','rejected','deleted',
    'unregistered','archived','deceased','warded'
  )),
  CONSTRAINT psy_patients_kob_status_check CHECK (kob_status IN (
    'pending_payment',      -- Patient baru daftar, belum bayar
    'paid',                 -- Sudah bayar (bayaran luaran/GHL), KYC belum hantar
    'kyc_done',             -- KYC selesai, belum book slot KOB
    'booked',               -- Slot KOB ditempah
    'hadir',                -- Doktor tekan Hadir (sesi sedang berlangsung)
    'package_recommended',  -- Doktor pilih pakej, pesakit perlu bayar
    'package_paid',         -- Pesakit sudah bayar pakej
    'completed',            -- KOB selesai → pakej unlocked
    'na'                    -- Not applicable (staff-created / grandfathered)
  )),
  CONSTRAINT psy_patients_outcome_status_check CHECK (
    outcome_status IN ('otw','berhenti','meninggal','completed')
  )
);

-- ──── indeks psy_patients ────
CREATE INDEX IF NOT EXISTS idx_psy_patients_user  ON psy_patients(user_id);
CREATE INDEX IF NOT EXISTS idx_psy_patients_mrn   ON psy_patients(mrn);
CREATE INDEX IF NOT EXISTS idx_psy_patients_coach ON psy_patients(coach_id);
CREATE INDEX IF NOT EXISTS idx_psy_patients_email ON psy_patients(email);
CREATE INDEX IF NOT EXISTS idx_psy_patients_full_name ON psy_patients(full_name);
CREATE INDEX IF NOT EXISTS idx_psy_patients_phone     ON psy_patients(phone);
CREATE INDEX IF NOT EXISTS idx_patients_state         ON psy_patients(state);

CREATE INDEX IF NOT EXISTS idx_psy_patients_outcome_status
  ON psy_patients (outcome_status) WHERE outcome_status IS NOT NULL;

-- Untuk auto-link query (cari unlinked staff-created patients ikut IC)
CREATE INDEX IF NOT EXISTS idx_psy_patients_created_by_staff
  ON psy_patients(created_by_staff)
  WHERE created_by_staff = true AND user_id IS NULL;

-- Kod rujukan mesti unik (NULL dibenarkan berbilang)
CREATE UNIQUE INDEX IF NOT EXISTS idx_psy_patients_referral_code
  ON psy_patients (referral_code) WHERE referral_code IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_psy_patients_referred_by
  ON psy_patients (referred_by_patient_id) WHERE referred_by_patient_id IS NOT NULL;

-- ──── RLS psy_patients ────
ALTER TABLE psy_patients ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff manage patients" ON psy_patients;
CREATE POLICY "Staff manage patients" ON psy_patients FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "Patients read own record" ON psy_patients;
CREATE POLICY "Patients read own record" ON psy_patients FOR SELECT
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Patients update own record" ON psy_patients;
CREATE POLICY "Patients update own record" ON psy_patients FOR UPDATE
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Patients insert own record" ON psy_patients;
CREATE POLICY "Patients insert own record" ON psy_patients FOR INSERT
  WITH CHECK (user_id = auth.uid());

-- ──── RPC: pesakit cari & claim rekod psy_patients belum-linked (staff/GHL) ────
-- RLS di atas (user_id = auth.uid()) sengaja block pesakit baca/kemaskini
-- rekod pesakit LAIN — termasuk stub kosong (user_id NULL) yang staff/GHL
-- dah isi SEBELUM pesakit signup sendiri. Tanpa laluan ni, borang Pendaftaran
-- pesakit (roles/patient/pendaftaran.html) tak boleh jumpa/padan rekod staff
-- langsung (query terus kena tapis RLS, senyap-senyap pulang 0 baris), dan
-- proses claim (pindah user_id) di submitKYC() turut gagal atas sebab sama.
-- Dua RPC SECURITY DEFINER ni bagi laluan terkawal & sempit: cari SATU rekod
-- belum-linked ikut phone/IC/emel (baca sahaja, utk prapapar borang), dan
-- pindah user_id ke rekod tu + padam stub lama bila pesakit hantar borang.
CREATE OR REPLACE FUNCTION find_unclaimed_patient(
  p_phone_key  TEXT DEFAULT NULL,   -- 9 digit terakhir no. telefon
  p_ic         TEXT DEFAULT NULL,
  p_email      TEXT DEFAULT NULL,
  p_exclude_id UUID DEFAULT NULL
)
RETURNS SETOF psy_patients
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_row psy_patients;
BEGIN
  IF p_phone_key IS NOT NULL AND p_phone_key <> '' THEN
    SELECT * INTO v_row FROM psy_patients
    WHERE user_id IS NULL AND (p_exclude_id IS NULL OR id <> p_exclude_id)
      AND (phone ILIKE '%' || p_phone_key OR emergency_contact_phone ILIKE '%' || p_phone_key)
    LIMIT 1;
    IF FOUND THEN RETURN NEXT v_row; RETURN; END IF;
  END IF;

  IF p_ic IS NOT NULL AND p_ic <> '' THEN
    SELECT * INTO v_row FROM psy_patients
    WHERE user_id IS NULL AND (p_exclude_id IS NULL OR id <> p_exclude_id)
      AND ic_number = p_ic
    LIMIT 1;
    IF FOUND THEN RETURN NEXT v_row; RETURN; END IF;
  END IF;

  IF p_email IS NOT NULL AND p_email <> '' THEN
    SELECT * INTO v_row FROM psy_patients
    WHERE user_id IS NULL AND (p_exclude_id IS NULL OR id <> p_exclude_id)
      AND email ILIKE p_email
    LIMIT 1;
    IF FOUND THEN RETURN NEXT v_row; RETURN; END IF;
  END IF;

  RETURN;
END;
$$;

GRANT EXECUTE ON FUNCTION find_unclaimed_patient(TEXT, TEXT, TEXT, UUID) TO authenticated;

CREATE OR REPLACE FUNCTION claim_unclaimed_patient(
  p_target_id UUID,
  p_stub_id   UUID DEFAULT NULL   -- stub kosong pesakit sendiri (auto-cipta masa signup) utk dipadam
)
RETURNS SETOF psy_patients
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF p_stub_id IS NOT NULL AND p_stub_id <> p_target_id THEN
    DELETE FROM psy_patients WHERE id = p_stub_id AND user_id = auth.uid();
  END IF;

  RETURN QUERY
  UPDATE psy_patients
  SET user_id = auth.uid(), created_by_staff = false
  WHERE id = p_target_id AND user_id IS NULL
  RETURNING *;
END;
$$;

GRANT EXECUTE ON FUNCTION claim_unclaimed_patient(UUID, UUID) TO authenticated;

-- ──── RPC: semak IC pesakit lain (dah linked ATAU belum) ikut IC ────
-- Sama sebab RLS macam di atas — "IC ini sudah didaftarkan" block di
-- pendaftaran.html (submitKYC/checkIcDuplicate) query rekod pesakit LAIN yang
-- boleh jadi dah linked ke akaun sebenar (user_id bukan NULL), yang
-- find_unclaimed_patient() sengaja tak cover (tu khas utk stub belum-linked
-- sahaja). Pulangkan hanya medan paparan minimum (bukan seluruh baris).
CREATE OR REPLACE FUNCTION find_duplicate_patient_by_ic(p_ic TEXT, p_exclude_id UUID DEFAULT NULL)
RETURNS TABLE (id UUID, mrn TEXT, full_name TEXT, user_id UUID)
LANGUAGE sql SECURITY DEFINER SET search_path = public
AS $$
  SELECT id, mrn, full_name, user_id FROM psy_patients
  WHERE ic_number = p_ic AND (p_exclude_id IS NULL OR id <> p_exclude_id)
  LIMIT 1;
$$;

GRANT EXECUTE ON FUNCTION find_duplicate_patient_by_ic(TEXT, UUID) TO authenticated;

-- ──── trigger: auto-update updated_at ────
CREATE OR REPLACE FUNCTION set_patients_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_set_patients_updated_at ON psy_patients;
CREATE TRIGGER trg_set_patients_updated_at
  BEFORE UPDATE ON psy_patients
  FOR EACH ROW
  EXECUTE FUNCTION set_patients_updated_at();

-- ──── trigger: sepadankan status <-> outcome_status ────
-- status (akses akaun: active/inactive/deceased/...) & outcome_status
-- (outcome klinikal utk laporan: otw/berhenti/meninggal/completed) overlap
-- bila rekod maut/selesai rawatan. Staff kadang tukar salah satu je (cth
-- dropdown "Status Outcome Rawatan" di patient-form.html) — medan lain
-- tercicir, jadi automasi (tapis ikut status) & laporan (tapis ikut
-- outcome_status) boleh tak sepadan utk pesakit yang sama. Trigger ni
-- paksa kedua-dua medan sentiasa konsisten tanpa kena ubah setiap tempat
-- yang baca/tulis column ni.
CREATE OR REPLACE FUNCTION sync_patient_status_outcome()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.outcome_status = 'meninggal' THEN
    NEW.status := 'deceased';
  ELSIF NEW.status = 'deceased' THEN
    NEW.outcome_status := 'meninggal';
  END IF;

  IF NEW.outcome_status IN ('completed', 'berhenti') AND NEW.status = 'active' THEN
    NEW.status := 'inactive';
  END IF;

  -- Account bertukar tak-aktif (session selesai/pakej luput/staff arkib) tapi
  -- outcome masih 'otw' (atau kosong) — 'otw' bermaksud "sedang berjalan",
  -- jadi dah tak tepat lagi bila akaun dah tak aktif. Naikkan ke 'completed'
  -- supaya UI tak papar kombinasi mengelirukan macam "Tidak Aktif" + "Sedang
  -- Berjalan". Staff masih boleh override ke 'berhenti' selepas ni kalau perlu.
  IF NEW.status IN ('inactive', 'archived')
     AND (NEW.outcome_status IS NULL OR NEW.outcome_status IN ('', 'otw')) THEN
    NEW.outcome_status := 'completed';
  END IF;

  IF NEW.outcome_status IS DISTINCT FROM OLD.outcome_status
     AND NEW.outcome_status IS NOT NULL
     AND NEW.outcome_status_at IS NULL THEN
    NEW.outcome_status_at := now();
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_patient_status_outcome ON psy_patients;
CREATE TRIGGER trg_sync_patient_status_outcome
  BEFORE UPDATE ON psy_patients
  FOR EACH ROW
  EXECUTE FUNCTION sync_patient_status_outcome();

-- ──── trigger: auto-jana MRN unik bila tidak dibekalkan ────
-- Client tak boleh query MRN tertinggi sebab RLS — jadi jana di DB.
CREATE OR REPLACE FUNCTION assign_patient_mrn()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  next_num INT;
  candidate TEXT;
BEGIN
  -- Kalau MRN dah diset client, biar je (mungkin migration / staff create)
  IF NEW.mrn IS NOT NULL AND NEW.mrn != '' THEN
    RETURN NEW;
  END IF;

  -- Ambil nombor tertinggi dari MRN format 'P-NNN'
  SELECT COALESCE(MAX(CAST(regexp_replace(mrn, '\D', '', 'g') AS INT)), 0)
  INTO next_num
  FROM psy_patients
  WHERE mrn LIKE 'P-%';

  -- Loop sampai dapat MRN yang unik (handle race condition)
  LOOP
    next_num := next_num + 1;
    candidate := 'P-' || LPAD(next_num::TEXT, 3, '0');
    EXIT WHEN NOT EXISTS (SELECT 1 FROM psy_patients WHERE mrn = candidate);
  END LOOP;

  NEW.mrn := candidate;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_assign_patient_mrn ON psy_patients;
CREATE TRIGGER trg_assign_patient_mrn
  BEFORE INSERT ON psy_patients
  FOR EACH ROW
  EXECUTE FUNCTION assign_patient_mrn();

-- Nota: trigger trg_assign_referral_code (auto-jana referral code) berada
-- dalam 20_referrals.sql bersama fungsinya assign_referral_code().

-- ──── fungsi + trigger: auto-create stub pesakit untuk self-register ────
-- Flow: signup → email confirm → login → KYC → KOB → ...
CREATE OR REPLACE FUNCTION handle_new_patient_profile()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NEW.role = 'patient' THEN
    IF NOT EXISTS (SELECT 1 FROM psy_patients WHERE user_id = NEW.id) THEN
      INSERT INTO psy_patients (user_id, full_name, status, kob_status, created_by_staff)
      VALUES (NEW.id, NEW.full_name, 'pending_kyc', 'paid', false);
    END IF;
  END IF;
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE LOG 'handle_new_patient_profile error: %', SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_new_patient_profile ON psy_profiles;
CREATE TRIGGER trg_new_patient_profile
  AFTER INSERT ON psy_profiles
  FOR EACH ROW
  EXECUTE FUNCTION handle_new_patient_profile();

-- ──── fungsi: auto-tandai pesakit Tidak Aktif bila rawatan selesai ────
-- Dicetus bila mana-mana sesi ditanda hadir/consultation_done (trigger pada
-- psy_plan_weekly_progress — didefinisi dalam domain plan). Pelan TIDAK
-- auto-tutup selagi ada minggu sambungan (continuity, extension_for_week=0)
-- yang sudah dibayar tetapi belum selesai.
CREATE OR REPLACE FUNCTION fn_auto_inactive_on_session_done()
RETURNS TRIGGER AS $$
DECLARE
  v_patient_id   UUID;
  v_pstatus      TEXT;
  v_pkg_expired  BOOLEAN;
  v_all_done     BOOLEAN;
  v_has_core     BOOLEAN;
BEGIN
  IF NEW.status NOT IN ('hadir','consultation_done') THEN
    RETURN NEW;
  END IF;
  IF TG_OP = 'UPDATE' AND OLD.status = NEW.status THEN
    RETURN NEW;
  END IF;

  SELECT patient_id INTO v_patient_id FROM psy_treatment_plans WHERE id = NEW.plan_id;
  IF v_patient_id IS NULL THEN RETURN NEW; END IF;

  -- v_has_core : ada sekurang-kurangnya satu sesi teras.
  -- v_all_done : tiada baris "menghalang" yang belum selesai, iaitu
  --   (a) sesi teras (is_extension=false) yang belum selesai, ATAU
  --   (b) minggu continuity BERBAYAR (extension_for_week = 0, bukan pending bayaran) yang belum selesai.
  SELECT
    EXISTS (SELECT 1 FROM psy_plan_weekly_progress
            WHERE plan_id = NEW.plan_id AND COALESCE(is_extension,false) = false),
    NOT EXISTS (
      SELECT 1 FROM psy_plan_weekly_progress
      WHERE plan_id = NEW.plan_id
        AND status NOT IN ('hadir','consultation_done')
        AND (
          COALESCE(is_extension,false) = false
          OR (COALESCE(extension_for_week, -1) = 0 AND status <> 'extension_pending_payment')
        )
    )
    INTO v_has_core, v_all_done;

  SELECT status, (package_expires_at IS NOT NULL AND package_expires_at < now())
    INTO v_pstatus, v_pkg_expired
    FROM psy_patients WHERE id = v_patient_id;

  -- Sudah tak aktif (atau sedang warded — jangan timpa status klinikal semasa) → jangan ganggu
  IF v_pstatus IN ('inactive','archived','deceased','deleted','warded') THEN
    RETURN NEW;
  END IF;

  IF (v_has_core AND v_all_done) OR v_pkg_expired THEN
    UPDATE psy_patients
      SET status = 'inactive',
          outcome_status = CASE WHEN outcome_status IS NULL OR outcome_status = ''
                                THEN 'completed' ELSE outcome_status END,
          outcome_status_at = CASE WHEN outcome_status IS NULL OR outcome_status = ''
                                   THEN now() ELSE outcome_status_at END
      WHERE id = v_patient_id;
    UPDATE psy_treatment_plans SET status = 'completed'
      WHERE id = NEW.plan_id AND status <> 'completed';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ──── komen psy_patients ────
COMMENT ON COLUMN psy_patients.kob_status IS
  'KOB lifecycle. Payment external (GHL). New self-registered patient starts at paid → kyc_done → booked → hadir → completed. Staff-created can be na (grandfathered).';

COMMENT ON COLUMN psy_patients.outcome_status IS
  'Clinical outcome: otw=On-going Treatment, berhenti=stopped, meninggal=passed away, completed=selesai rawatan';

COMMENT ON COLUMN psy_patients.daily_schedule IS
  'Patient-customized daily schedule. NULL = inherit from active package template. Array = patient has overridden.';

COMMENT ON COLUMN psy_patients.booking_blocked IS
  'TRUE = pesakit disekat daripada menempah sesi baru. Sebab semasa: ansuran pakej tertunggak (lihat psy_kob_installments). Auto set/reset oleh installment-overdue-check.';
COMMENT ON COLUMN psy_patients.booking_blocked_reason IS
  'Kod sebab sekatan, cth "installment_overdue". NULL bila booking_blocked = false.';
COMMENT ON COLUMN psy_patients.booking_blocked_since IS
  'Bila sekatan bermula. Dipadam (NULL) bila booking_blocked ditukar semula ke false.';

COMMENT ON COLUMN psy_patients.created_by_staff IS
  'TRUE = pesakit didaftarkan oleh staff (bukan self-signup). Akan bypass KOB flow (kob_status=na) dan tunggu auto-link bila pesakit signup sendiri guna IC sama.';

COMMENT ON COLUMN psy_patients.full_name IS
  'Nama pesakit. Bila ada user_id, biasanya match dgn psy_profiles.full_name. Snapshot untuk staff-created tanpa user_id.';

COMMENT ON COLUMN psy_patients.phone IS
  'Nombor telefon utama pesakit. Boleh berbeza dari psy_profiles.phone (cth: kalau staff tukar di sini).';

COMMENT ON COLUMN psy_patients.emergency_contact_email IS
  'Email kenalan kecemasan / waris.';

COMMENT ON COLUMN psy_patients.emergency_contact_relationship IS
  'Hubungan waris dengan pesakit (Suami, Isteri, Ibu, Bapa, Anak, dll).';

COMMENT ON COLUMN psy_patients.contact_preference IS
  'Siapa patut terima notifikasi/kemas kini (WhatsApp) pesakit ini: pesakit atau waris. Direkod sahaja setakat ini — belum digunakan oleh Edge Functions penghantaran WhatsApp.';

COMMENT ON COLUMN psy_patients.updated_at IS
  'Masa kemaskini terakhir rekod pesakit (auto dari trigger).';

COMMENT ON COLUMN psy_patients.home_address IS
  'Alamat kediaman pesakit (berbeza dari address yang digunakan untuk surat-menyurat / mailing).';

COMMENT ON COLUMN psy_patients.city  IS 'Bandar (sebahagian dari alamat kediaman).';

COMMENT ON COLUMN psy_patients.state IS 'Negeri (Selangor, Johor, dll.).';

COMMENT ON COLUMN psy_patients.referral_code IS
  'Kod rujukan unik pesakit ini untuk dikongsi (auto-jana dari nama/MRN).';

COMMENT ON COLUMN psy_patients.referred_by_code IS
  'Kod rujukan perujuk yang dimasukkan semasa pesakit ini mendaftar.';

COMMENT ON COLUMN psy_patients.referred_by_patient_id IS
  'Pesakit perujuk yang telah diselesaikan dari referred_by_code.';

COMMENT ON COLUMN psy_patients.next_package_id IS
  'Pakej sambungan (continuity) yang sudah dibayar & beratur; auto-aktif bila pakej semasa selesai (step93).';

-- ────────────────────────────────────────────────
-- psy_kyc_submissions — borang KYC pesakit
-- ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS psy_kyc_submissions (
  id                              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id                         UUID REFERENCES psy_profiles(id) ON DELETE CASCADE,
  patient_name                    TEXT NOT NULL,
  ic_number                       TEXT,
  date_of_birth                   DATE,
  gender                          TEXT,
  phone                           TEXT,
  email                           TEXT,
  address                         TEXT,
  marital_status                  TEXT,
  occupation                      TEXT,
  company                         TEXT,
  emergency_contact               TEXT,
  emergency_contact_name          TEXT,
  emergency_contact_phone         TEXT,
  emergency_contact_ic            TEXT,
  emergency_contact_relationship  TEXT,
  emergency_contact_email         TEXT,
  medical_condition               TEXT,
  condition_duration              TEXT,
  medical_notes                   TEXT,
  insurance_info                  JSONB,
  documents                       JSONB DEFAULT '{}',
  consent_data_processing         BOOLEAN DEFAULT false,
  consent_health_records          BOOLEAN DEFAULT false,
  consent_research                BOOLEAN DEFAULT false,
  consent_marketing               BOOLEAN DEFAULT false,
  referral_source                 TEXT,
  submitted_by_proxy              BOOLEAN NOT NULL DEFAULT false,
  contact_preference              TEXT DEFAULT 'pesakit' CHECK (contact_preference IN ('pesakit','waris')),
  status                          TEXT DEFAULT 'pending'
                                  CHECK (status IN ('pending','approved','rejected','needs_docs')),
  reviewed_by                     UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  review_notes                    TEXT,
  created_at                      TIMESTAMPTZ DEFAULT now()
);

-- ──── RLS psy_kyc_submissions ────
ALTER TABLE psy_kyc_submissions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff manage KYC" ON psy_kyc_submissions;
CREATE POLICY "Staff manage KYC" ON psy_kyc_submissions FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "Patients read own KYC" ON psy_kyc_submissions;
CREATE POLICY "Patients read own KYC" ON psy_kyc_submissions FOR SELECT
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Patients insert own KYC" ON psy_kyc_submissions;
CREATE POLICY "Patients insert own KYC" ON psy_kyc_submissions FOR INSERT
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Patients update own KYC" ON psy_kyc_submissions;
CREATE POLICY "Patients update own KYC" ON psy_kyc_submissions FOR UPDATE
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Staff can read all kyc" ON psy_kyc_submissions;
CREATE POLICY "Staff can read all kyc"
  ON psy_kyc_submissions FOR SELECT
  USING (
    auth.uid() IN (SELECT id FROM psy_profiles WHERE role = 'staff')
    OR auth.uid() = user_id
  );

-- ──── trigger: auto-sync KYC → patient bila KYC diluluskan ────
-- Menjamin tiada desync walaupun patient row tak wujud masa KYC approved.
CREATE OR REPLACE FUNCTION sync_kyc_to_patient()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  -- Hanya sync bila status berubah jadi 'approved'
  IF NEW.status = 'approved' AND (OLD.status IS NULL OR OLD.status != 'approved') THEN
    UPDATE psy_patients
    SET
      status                  = 'active',
      full_name               = COALESCE(NULLIF(full_name, ''), NEW.patient_name),
      phone                   = COALESCE(NULLIF(phone, ''), NEW.phone),
      ic_number               = COALESCE(NULLIF(ic_number, ''), NEW.ic_number),
      date_of_birth           = COALESCE(date_of_birth, NEW.date_of_birth),
      gender                  = COALESCE(NULLIF(gender, ''), NEW.gender),
      address                 = COALESCE(NULLIF(address, ''), NEW.address),
      emergency_contact_name  = COALESCE(NULLIF(emergency_contact_name, ''), NEW.emergency_contact_name),
      emergency_contact_phone = COALESCE(NULLIF(emergency_contact_phone, ''), NEW.emergency_contact_phone),
      emergency_contact_relationship = COALESCE(NULLIF(emergency_contact_relationship, ''), NEW.emergency_contact_relationship),
      emergency_contact_email = COALESCE(NULLIF(emergency_contact_email, ''), NEW.emergency_contact_email),
      referral_source         = COALESCE(NULLIF(referral_source, ''), NEW.referral_source),
      medical_condition       = COALESCE(NULLIF(medical_condition, ''), NEW.medical_condition),
      condition_duration      = COALESCE(NULLIF(condition_duration, ''), NEW.condition_duration),
      medical_notes           = COALESCE(NULLIF(medical_notes, ''), NEW.medical_notes)
    WHERE user_id = NEW.user_id;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_kyc_to_patient ON psy_kyc_submissions;
CREATE TRIGGER trg_sync_kyc_to_patient
  AFTER INSERT OR UPDATE ON psy_kyc_submissions
  FOR EACH ROW
  EXECUTE FUNCTION sync_kyc_to_patient();

-- ──── trigger: amaran coach bila pesakit buah pinggang/dialisis ────
-- Audit #20 (8 Okt 2026). Bila staf tandakan has_kidney_condition = true
-- (ATAU coach pesakit yg SUDAH ditanda true ditukar/diisi — supaya coach
-- BAHARU pun kena notify "setiap kali DAPAT pesakit"), hantar notify() kpd
-- coach_id tu. Ikut pola trg_patient_warded_auto_event (25_patient_events.sql)
-- — SECURITY DEFINER + EXCEPTION WHEN OTHERS supaya tak gagalkan transaksi
-- update psy_patients kalau notify silap. Banner visual (bukan notifikasi
-- sahaja) papar di patient-hub.html setiap kali profil pesakit ni dibuka.
CREATE OR REPLACE FUNCTION trg_patient_kidney_alert_notify()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_became_flagged BOOLEAN;
  v_coach_changed BOOLEAN;
BEGIN
  v_became_flagged := NEW.has_kidney_condition = true
    AND OLD.has_kidney_condition IS DISTINCT FROM true;
  v_coach_changed := NEW.has_kidney_condition = true
    AND NEW.coach_id IS NOT NULL
    AND NEW.coach_id IS DISTINCT FROM OLD.coach_id;

  IF NOT (v_became_flagged OR v_coach_changed) OR NEW.coach_id IS NULL THEN
    RETURN NEW;
  END IF;

  PERFORM notify_patient_kidney_alert(NEW.coach_id, NEW.id, NEW.full_name);

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE LOG 'trg_patient_kidney_alert_notify: %', SQLERRM;
  RETURN NEW;
END;
$$;

-- Helper berasingan (bukan terus insert dlm trigger) supaya boleh re-use kalau
-- perlu panggil dari tempat lain kemudian (cth backfill manual).
CREATE OR REPLACE FUNCTION notify_patient_kidney_alert(p_coach_id UUID, p_patient_id UUID, p_patient_name TEXT)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO psy_notifications (user_id, type, title, body, link)
  VALUES (
    p_coach_id,
    'kidney_alert',
    '⚠️ Pesakit Buah Pinggang/Dialisis',
    'Pesakit ' || COALESCE(p_patient_name, 'ini') ||
      ' ada masalah buah pinggang/dialisis — perhatikan kadar peminuman air pesakit ' ||
      '& ELAK penyuntikan/pengambilan darah di lengan yang ada akses dialisis (fistula/kolaps vena).',
    'patient-hub.html?id=' || p_patient_id::TEXT
  );
EXCEPTION WHEN OTHERS THEN
  RAISE LOG 'notify_patient_kidney_alert: %', SQLERRM;
END;
$$;

DROP TRIGGER IF EXISTS trg_patient_kidney_alert_notify ON psy_patients;
CREATE TRIGGER trg_patient_kidney_alert_notify
  AFTER UPDATE ON psy_patients
  FOR EACH ROW EXECUTE FUNCTION trg_patient_kidney_alert_notify();

-- ──── komen psy_kyc_submissions ────
COMMENT ON COLUMN psy_kyc_submissions.submitted_by_proxy IS
  'true = wakil/keluarga isi borang ini (info mesti tepat & boleh disahkan dengan pesakit sebenar)';

COMMENT ON COLUMN psy_kyc_submissions.contact_preference IS
  'Siapa patut terima notifikasi/kemas kini (WhatsApp) pesakit ini: pesakit atau waris.';

-- ────────────────────────────────────────────────
-- psy_patient_notes — catatan pesakit (staff)
-- ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS psy_patient_notes (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id   UUID NOT NULL REFERENCES psy_patients(id) ON DELETE CASCADE,
  note_type    TEXT NOT NULL DEFAULT 'general'
               CHECK (note_type IN ('general','coach','sesi','checkin','vitals','medical','dna','peringatan')),
  content      TEXT NOT NULL,
  related_session_id UUID,
  related_report_id  UUID,
  actor_id     UUID,
  actor_name   TEXT,
  actor_role   TEXT,
  is_pinned    BOOLEAN DEFAULT false,
  visibility   TEXT DEFAULT 'staff'
               CHECK (visibility IN ('staff','patient','both')),
  created_at   TIMESTAMPTZ DEFAULT now(),
  updated_at   TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_patient_notes_patient ON psy_patient_notes(patient_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_patient_notes_type    ON psy_patient_notes(note_type);

ALTER TABLE psy_patient_notes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "staff_notes_all" ON psy_patient_notes;
CREATE POLICY "staff_notes_all" ON psy_patient_notes FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "patient_notes_read" ON psy_patient_notes;
CREATE POLICY "patient_notes_read" ON psy_patient_notes FOR SELECT
  USING (visibility IN ('patient','both') AND
         patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

-- ────────────────────────────────────────────────
-- psy_patient_documents — dokumen pesakit
--   plan_id NULL + week_number NULL -> dokumen umum (Patient Hub)
--   plan_id + week_number diisi     -> dokumen khusus minggu (plan-week)
-- ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS psy_patient_documents (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id   UUID NOT NULL REFERENCES psy_patients(id) ON DELETE CASCADE,
  doc_type     TEXT NOT NULL DEFAULT 'other'
               CHECK (doc_type IN ('kyc','ic','passport','persetujuan','laporan_perubatan','gambar','surat_rasmi','resit','other')),
  doc_label    TEXT NOT NULL,
  description  TEXT,
  file_name    TEXT,
  file_path    TEXT,
  file_url     TEXT,
  file_size    INT,
  status       TEXT DEFAULT 'pending'
               CHECK (status IN ('pending','disahkan','disemak','tertunggak','ditolak')),
  uploaded_by  UUID,
  uploaded_by_name TEXT,
  uploaded_at  TIMESTAMPTZ DEFAULT now(),
  approved_by  UUID,
  approved_at  TIMESTAMPTZ,
  plan_id      UUID,  -- FK → psy_treatment_plans (dipasang di hujung 07_treatment_plans.sql)
  week_number  INT
);

CREATE INDEX IF NOT EXISTS idx_patient_docs_patient ON psy_patient_documents(patient_id, uploaded_at DESC);
CREATE INDEX IF NOT EXISTS idx_patient_docs_type    ON psy_patient_documents(doc_type);

CREATE INDEX IF NOT EXISTS idx_patient_docs_plan_week
  ON psy_patient_documents (plan_id, week_number)
  WHERE plan_id IS NOT NULL;

ALTER TABLE psy_patient_documents ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "staff_docs_all" ON psy_patient_documents;
CREATE POLICY "staff_docs_all" ON psy_patient_documents FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "patient_docs_read_own" ON psy_patient_documents;
CREATE POLICY "patient_docs_read_own" ON psy_patient_documents FOR SELECT
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "patient_docs_insert_own" ON psy_patient_documents;
CREATE POLICY "patient_docs_insert_own" ON psy_patient_documents FOR INSERT
  WITH CHECK (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

COMMENT ON COLUMN psy_patient_documents.plan_id IS
  'Jika diisi, dokumen ini dilampirkan pada plan rawatan tertentu (skop minggu).';

COMMENT ON COLUMN psy_patient_documents.week_number IS
  'Nombor minggu plan untuk dokumen ini (NULL = dokumen umum pesakit).';

-- Nota: polisi storage pesakit (medical-reports, kob-signatures, kob-documents)
-- diselenggara berpusat dalam 24_storage.sql.

-- ────────────────────────────────────────────────
-- Realtime — status pesakit / kehadiran auto-tolak ke UI
-- (Realtime hormati RLS)
-- ────────────────────────────────────────────────
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'psy_patients'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE psy_patients;
  END IF;
END $$;
-- (realtime psy_plan_weekly_progress: lihat 07_treatment_plans.sql)
