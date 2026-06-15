-- ISW — Part 4/4: Step 31+ plus all unnumbered + fixes
Run after part3_step21_30.sql.
-- Generated: 2026-06-12T04:04:17.901373Z
-- Total files: 95
-- Run this entire file in Supabase SQL Editor (new project).


-- ════════════════════════════════════════════════════════════════
-- step31_patient_self_vitals.sql
-- ════════════════════════════════════════════════════════════════

-- ============================================================
-- step31_patient_self_vitals.sql
-- Allow patients to log own BP / HbA1c readings (e.g. taken at home).
-- Add hba1c column + source column to distinguish staff vs patient entries.
-- ============================================================

ALTER TABLE psy_vitals
  ADD COLUMN IF NOT EXISTS hba1c NUMERIC(4,2);

ALTER TABLE psy_vitals
  ADD COLUMN IF NOT EXISTS source TEXT NOT NULL DEFAULT 'staff'
  CHECK (source IN ('staff','patient_self'));

ALTER TABLE psy_vitals
  ADD COLUMN IF NOT EXISTS reading_date DATE;

COMMENT ON COLUMN psy_vitals.hba1c IS 'HbA1c % (e.g. 6.5 = 6.5%)';
COMMENT ON COLUMN psy_vitals.source IS 'Who entered the reading: staff at clinic, or patient self-reported';
COMMENT ON COLUMN psy_vitals.reading_date IS 'Date the reading was actually taken (may differ from created_at for back-dated entries)';

-- Allow patient to insert OWN readings (only with source = patient_self)
DO $$ BEGIN
  CREATE POLICY "Patients insert own vitals" ON psy_vitals FOR INSERT
    WITH CHECK (
      source = 'patient_self'
      AND patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid())
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;


-- ════════════════════════════════════════════════════════════════
-- step32_package_extensions.sql
-- ════════════════════════════════════════════════════════════════

-- ============================================================
-- step32_package_extensions.sql
-- Sprint 1: Package System Foundation
--
-- Extends psy_packages with fields needed for:
-- - Jadual peminuman madu auto (10x/8x/4x ikut pakej)
-- - Lock butang ONLINE dari minggu 3 (kecuali pakej OB direct: OBD1/OBDX1/OBDY1/OBP1/OBPX1/OBPY1)
-- - Bekalan per minggu (foundation untuk inventory auto-deduct)
-- - Content unlock rule per minggu
-- - WhatsApp message template per minggu
-- ============================================================

ALTER TABLE psy_packages
  ADD COLUMN IF NOT EXISTS madu_frequency_per_day INT,
  ADD COLUMN IF NOT EXISTS madu_schedule_label TEXT,
  ADD COLUMN IF NOT EXISTS allow_online_full_duration BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS online_lock_from_week INT NOT NULL DEFAULT 3,
  ADD COLUMN IF NOT EXISTS weekly_supplies JSONB DEFAULT '[]',
  ADD COLUMN IF NOT EXISTS weekly_content JSONB DEFAULT '[]',
  ADD COLUMN IF NOT EXISTS weekly_message JSONB DEFAULT '[]';

COMMENT ON COLUMN psy_packages.madu_frequency_per_day IS
  'Frekuensi peminuman madu sehari. Examples: 10 (12-minggu), 8 (3-bulan), 4 (3-bulan-sekali). NULL = no madu schedule.';
COMMENT ON COLUMN psy_packages.madu_schedule_label IS
  'Human-readable label for madu schedule, e.g. "10x sehari (12 minggu)"';
COMMENT ON COLUMN psy_packages.allow_online_full_duration IS
  'true = online sessions allowed throughout (OBD1/OBDX1/OBDY1/OBP1/OBPX1/OBPY1). false = lock to f2f after online_lock_from_week.';
COMMENT ON COLUMN psy_packages.online_lock_from_week IS
  'Week number from which online sessions are locked (must use f2f). Default 3.';
COMMENT ON COLUMN psy_packages.weekly_supplies IS
  'Array of {week, items: [{product_id, qty, name}]} — bekalan auto-deduct per week';
COMMENT ON COLUMN psy_packages.weekly_content IS
  'Array of {week, content_ids: []} — library content unlock per week';
COMMENT ON COLUMN psy_packages.weekly_message IS
  'Array of {week, message} — WhatsApp template per week';

-- Mark OB-direct packages as allowing online full duration
UPDATE psy_packages
  SET allow_online_full_duration = true
  WHERE LOWER(package_id) IN ('obd1','obdx1','obdy1','obp1','obpx1','obpy1');


-- ════════════════════════════════════════════════════════════════
-- step33_madu_tracking.sql
-- ════════════════════════════════════════════════════════════════

-- ============================================================
-- step33_madu_tracking.sql
-- Track madu intake count per day in daily check-in.
-- Target frequency comes from patient's active package (madu_frequency_per_day).
-- ============================================================

ALTER TABLE psy_daily_checkins
  ADD COLUMN IF NOT EXISTS madu_count INT NOT NULL DEFAULT 0;

COMMENT ON COLUMN psy_daily_checkins.madu_count IS
  'Bilangan kali pesakit minum madu hari ini. Target dari psy_packages.madu_frequency_per_day.';


-- ════════════════════════════════════════════════════════════════
-- step34_kob.sql
-- ════════════════════════════════════════════════════════════════

-- ============================================================
-- step34_kob.sql
-- Konsultasi Orang Baru (KOB) — mandatory paid entry-point.
--
-- Flow:
--   Register → Bayar RM199 → Isi KYC → Pilih tarikh KOB →
--   Doktor: Hadir → Patient sign agreement → Doktor isi notes + upload → Selesai →
--   Unlock pakej rawatan
-- ============================================================

-- ── 1. Extend psy_patients with KOB lifecycle status ──────
ALTER TABLE psy_patients
  ADD COLUMN IF NOT EXISTS kob_status TEXT NOT NULL DEFAULT 'pending_payment'
  CHECK (kob_status IN (
    'pending_payment',  -- Patient baru daftar, belum bayar RM199
    'paid',             -- Sudah bayar, KYC belum hantar
    'kyc_done',         -- KYC selesai, belum book slot KOB
    'booked',           -- Slot KOB ditempah
    'hadir',            -- Doktor tekan Hadir (sesi sedang berlangsung)
    'completed',        -- Doktor tekan Selesai → pakej unlocked
    'na'                -- Not applicable (patient staff-created, grandfathered)
  ));

COMMENT ON COLUMN psy_patients.kob_status IS
  'Lifecycle KOB. Self-registered patient mula pending_payment → completed sebelum boleh pilih pakej. Staff-created patient = na.';

-- Existing patients: bulk-categorize
-- Staff-created (created_by_staff=true) → na (bypass KOB)
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns
             WHERE table_name='psy_patients' AND column_name='created_by_staff') THEN
    EXECUTE $sql$
      UPDATE psy_patients SET kob_status = 'na'
      WHERE created_by_staff = true AND kob_status = 'pending_payment'
    $sql$;
  END IF;
END $$;

-- Existing patients with active package → grandfather as completed
UPDATE psy_patients SET kob_status = 'completed'
  WHERE active_package_id IS NOT NULL AND kob_status = 'pending_payment';

-- Patients with terminal outcome → na (skip if outcome_status column not yet present)
DO $$ BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name='psy_patients' AND column_name='outcome_status'
  ) THEN
    EXECUTE $sql$
      UPDATE psy_patients SET kob_status = 'na'
      WHERE outcome_status IN ('berhenti','meninggal') AND kob_status = 'pending_payment'
    $sql$;
  END IF;
END $$;

-- ── 2. psy_kob_sessions: booking, attendance, notes ───────
CREATE TABLE IF NOT EXISTS psy_kob_sessions (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id          UUID NOT NULL REFERENCES psy_patients(id) ON DELETE CASCADE,
  scheduled_at        TIMESTAMPTZ NOT NULL,
  mode                TEXT NOT NULL DEFAULT 'f2f' CHECK (mode IN ('f2f','online')),
  meet_link           TEXT,
  status              TEXT NOT NULL DEFAULT 'booked'
                      CHECK (status IN ('booked','hadir','completed','reschedule','cancelled')),

  -- Doctor who marked attendance (may differ from who completes)
  doctor_hadir_id     UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  doctor_hadir_name   TEXT,
  hadir_at            TIMESTAMPTZ,

  -- Doctor who marked completion
  doctor_selesai_id   UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  doctor_selesai_name TEXT,
  selesai_at          TIMESTAMPTZ,

  -- Clinical notes from doctor
  notes               TEXT,
  -- Uploaded reports / supporting docs for this KOB
  documents           JSONB DEFAULT '[]',

  reschedule_count    INT NOT NULL DEFAULT 0,
  reschedule_reason   TEXT,

  created_at          TIMESTAMPTZ DEFAULT now(),
  updated_at          TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_kob_patient ON psy_kob_sessions(patient_id);
CREATE INDEX IF NOT EXISTS idx_kob_scheduled ON psy_kob_sessions(scheduled_at);
CREATE INDEX IF NOT EXISTS idx_kob_status ON psy_kob_sessions(status);

ALTER TABLE psy_kob_sessions ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "Patient read own KOB" ON psy_kob_sessions FOR SELECT
    USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "Patient book own KOB" ON psy_kob_sessions FOR INSERT
    WITH CHECK (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "Patient reschedule own KOB" ON psy_kob_sessions FOR UPDATE
    USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "Staff manage KOB sessions" ON psy_kob_sessions FOR ALL
    USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ── 3. psy_kob_agreements: signed agreement record ────────
CREATE TABLE IF NOT EXISTS psy_kob_agreements (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id        UUID NOT NULL REFERENCES psy_patients(id) ON DELETE CASCADE,
  kob_session_id    UUID REFERENCES psy_kob_sessions(id) ON DELETE SET NULL,
  agreement_version TEXT NOT NULL DEFAULT 'ISW.SOP OB KOB FORM 03 CONTRACT 250711',
  patient_name      TEXT NOT NULL,
  patient_ic        TEXT NOT NULL,
  signature_url     TEXT NOT NULL,   -- raw PNG signature in storage
  signed_pdf_url    TEXT,            -- generated PDF with signature embedded
  signed_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
  ip_address        TEXT,
  user_agent        TEXT,
  created_at        TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_kob_agreements_patient ON psy_kob_agreements(patient_id);

ALTER TABLE psy_kob_agreements ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "Patient read own agreement" ON psy_kob_agreements FOR SELECT
    USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "Patient sign own agreement" ON psy_kob_agreements FOR INSERT
    WITH CHECK (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "Staff read all agreements" ON psy_kob_agreements FOR SELECT
    USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ── 4. Storage bucket for KOB documents + signatures ──────
-- Run separately in Supabase Storage UI or via:
--   INSERT INTO storage.buckets (id, name, public) VALUES ('kob-documents', 'kob-documents', false);
--   INSERT INTO storage.buckets (id, name, public) VALUES ('kob-signatures', 'kob-signatures', false);

SELECT 'Step 34 OK — KOB tables ready' AS status;


-- ════════════════════════════════════════════════════════════════
-- step35_kob_skip_payment.sql
-- ════════════════════════════════════════════════════════════════

-- ============================================================
-- step35_kob_skip_payment.sql
-- Simplification: payment is handled externally (GHL), not in this system.
-- New patients land directly at KYC step.
-- When GHL integration ready, can revert default to 'pending_payment'
-- and re-introduce pay-banner.
-- ============================================================

-- Change default for new patients: skip payment, start at 'paid' (assumed paid externally)
ALTER TABLE psy_patients ALTER COLUMN kob_status SET DEFAULT 'paid';

-- Bulk-update existing patients stuck at 'pending_payment' → 'paid'
UPDATE psy_patients SET kob_status = 'paid' WHERE kob_status = 'pending_payment';

COMMENT ON COLUMN psy_patients.kob_status IS
  'KOB lifecycle. Payment external (GHL). New self-registered patient starts at paid → kyc_done → booked → hadir → completed. Staff-created can be na (grandfathered).';

SELECT 'Step 35 OK — payment step skipped, KYC is now first step' AS status;


-- ════════════════════════════════════════════════════════════════
-- step36_kob_slots.sql
-- ════════════════════════════════════════════════════════════════

-- ============================================================
-- step36_kob_slots.sql
-- KOB slot template configuration.
-- Slots are a fixed template — same 4 time slots for Wed-Sun.
-- Admin can toggle each slot on/off. No per-patient capacity (infinite per slot).
-- ============================================================

CREATE TABLE IF NOT EXISTS psy_kob_slot_config (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  day_of_week  INT NOT NULL CHECK (day_of_week IN (0, 3, 4, 5, 6)),  -- 0=Sun, 3=Wed, 4=Thu, 5=Fri, 6=Sat
  slot_start   TIME NOT NULL,
  slot_end     TIME NOT NULL,
  is_active    BOOLEAN NOT NULL DEFAULT true,
  label        TEXT NOT NULL,         -- human-readable e.g. "8.30 AM - 10.00 AM"
  sort_order   INT NOT NULL DEFAULT 0,
  created_at   TIMESTAMPTZ DEFAULT now(),
  updated_at   TIMESTAMPTZ DEFAULT now(),
  UNIQUE (day_of_week, slot_start)
);

CREATE INDEX IF NOT EXISTS idx_kob_slots_day ON psy_kob_slot_config(day_of_week, is_active);

ALTER TABLE psy_kob_slot_config ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "Anyone read kob slots" ON psy_kob_slot_config
    FOR SELECT USING (auth.uid() IS NOT NULL);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "Admin manage kob slots" ON psy_kob_slot_config FOR ALL
    USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff' AND staff_role IN ('admin','manager','doctor')));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ── Seed: 5 hari (Rabu-Ahad) × 4 slot ────────────────────
-- Slot 1: 8.30 AM - 10.00 AM
-- Slot 2: 10.30 AM - 12.00 PM
-- Slot 3: 2.00 PM - 3.30 PM
-- Slot 4: 3.30 PM - 5.00 PM
INSERT INTO psy_kob_slot_config (day_of_week, slot_start, slot_end, label, sort_order) VALUES
  (3, '08:30', '10:00', '8.30 AM - 10.00 AM', 1),
  (3, '10:30', '12:00', '10.30 AM - 12.00 PM', 2),
  (3, '14:00', '15:30', '2.00 PM - 3.30 PM', 3),
  (3, '15:30', '17:00', '3.30 PM - 5.00 PM', 4),
  (4, '08:30', '10:00', '8.30 AM - 10.00 AM', 1),
  (4, '10:30', '12:00', '10.30 AM - 12.00 PM', 2),
  (4, '14:00', '15:30', '2.00 PM - 3.30 PM', 3),
  (4, '15:30', '17:00', '3.30 PM - 5.00 PM', 4),
  (5, '08:30', '10:00', '8.30 AM - 10.00 AM', 1),
  (5, '10:30', '12:00', '10.30 AM - 12.00 PM', 2),
  (5, '14:00', '15:30', '2.00 PM - 3.30 PM', 3),
  (5, '15:30', '17:00', '3.30 PM - 5.00 PM', 4),
  (6, '08:30', '10:00', '8.30 AM - 10.00 AM', 1),
  (6, '10:30', '12:00', '10.30 AM - 12.00 PM', 2),
  (6, '14:00', '15:30', '2.00 PM - 3.30 PM', 3),
  (6, '15:30', '17:00', '3.30 PM - 5.00 PM', 4),
  (0, '08:30', '10:00', '8.30 AM - 10.00 AM', 1),
  (0, '10:30', '12:00', '10.30 AM - 12.00 PM', 2),
  (0, '14:00', '15:30', '2.00 PM - 3.30 PM', 3),
  (0, '15:30', '17:00', '3.30 PM - 5.00 PM', 4)
ON CONFLICT DO NOTHING;

SELECT 'Step 36 OK — KOB slot config ready' AS status;


-- ════════════════════════════════════════════════════════════════
-- step37_kob_questionnaire.sql
-- ════════════════════════════════════════════════════════════════

-- ============================================================
-- step37_kob_questionnaire.sql
-- Structured questionnaire for KOB session — doctor fills during consultation.
-- Stored as JSONB so we can evolve the question set without schema changes.
-- ============================================================

ALTER TABLE psy_kob_sessions
  ADD COLUMN IF NOT EXISTS questionnaire JSONB DEFAULT '{}';

COMMENT ON COLUMN psy_kob_sessions.questionnaire IS
  'Structured Q&A captured during KOB. Keys: anak[], tidur{}, gaya_hidup{}, masalah_kesihatan{} — see kob-detail.html for shape.';

SELECT 'Step 37 OK — KOB questionnaire column ready' AS status;


-- ════════════════════════════════════════════════════════════════
-- step38_kob_package_recommendation.sql
-- ════════════════════════════════════════════════════════════════

-- ============================================================
-- step38_kob_package_recommendation.sql
-- Doctor recommends a treatment package during KOB session.
-- Patient pays for it → signs agreement → doctor marks Selesai → activates everything.
-- ============================================================

ALTER TABLE psy_kob_sessions
  ADD COLUMN IF NOT EXISTS recommended_package_id   TEXT,
  ADD COLUMN IF NOT EXISTS recommended_package_name TEXT,
  ADD COLUMN IF NOT EXISTS recommended_package_price NUMERIC(10,2),
  ADD COLUMN IF NOT EXISTS recommended_at           TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS recommended_by           UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS recommended_by_name      TEXT,
  ADD COLUMN IF NOT EXISTS package_payment_status   TEXT DEFAULT 'pending'
    CHECK (package_payment_status IN ('pending','paid','skipped','na')),
  ADD COLUMN IF NOT EXISTS package_paid_at          TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS package_receipt_ref      TEXT;

COMMENT ON COLUMN psy_kob_sessions.recommended_package_id IS
  'Package recommended by doctor during KOB. Patient must pay before agreement signing.';

-- Extend patient kob_status enum with new transitional states
ALTER TABLE psy_patients DROP CONSTRAINT IF EXISTS psy_patients_kob_status_check;
ALTER TABLE psy_patients ADD CONSTRAINT psy_patients_kob_status_check
  CHECK (kob_status IN (
    'pending_payment',
    'paid',
    'kyc_done',
    'booked',
    'hadir',
    'package_recommended',  -- Doctor picked a package, patient needs to pay
    'package_paid',         -- Patient paid for the package
    'completed',
    'na'
  ));

SELECT 'Step 38 OK — KOB package recommendation ready' AS status;


-- ════════════════════════════════════════════════════════════════
-- step39_package_agreement.sql
-- ════════════════════════════════════════════════════════════════

-- ============================================================
-- step39_package_agreement.sql
-- Each package has its own agreement PDF template.
-- Patient signs the agreement matching their recommended package.
-- Fallback to generic 'agreement.pdf' if not set.
-- ============================================================

ALTER TABLE psy_packages
  ADD COLUMN IF NOT EXISTS agreement_pdf TEXT;

COMMENT ON COLUMN psy_packages.agreement_pdf IS
  'Filename of agreement PDF in shared/documents/agreements/ (relative path). NULL = use default agreement.pdf';

-- Seed mapping for known packages (idempotent — only set if column currently null)
UPDATE psy_packages SET agreement_pdf = 'ELIXIR_EOL_CONTRACT_[TEMPLATE].pdf'
  WHERE LOWER(package_id) IN ('pkg-eol','eol') AND agreement_pdf IS NULL;

UPDATE psy_packages SET agreement_pdf = 'ELIXIR_EOL+_CONTRACT_[TEMPLATE].pdf'
  WHERE LOWER(package_id) IN ('pkg-eol-plus','pkg-eolplus','eol+','eol-plus') AND agreement_pdf IS NULL;

UPDATE psy_packages SET agreement_pdf = 'ELIXIR__JUMPSTART_CONTRACT_[TEMPLATE].pdf'
  WHERE LOWER(package_id) IN ('pkg-jumpstart','pkg-js','js','jumpstart') AND agreement_pdf IS NULL;

UPDATE psy_packages SET agreement_pdf = 'ELIXIR__JUMPSTART+_CONTRACT_[TEMPLATE].pdf'
  WHERE LOWER(package_id) IN ('pkg-jumpstart-plus','pkg-jsplus','js+','jumpstart+') AND agreement_pdf IS NULL;

UPDATE psy_packages SET agreement_pdf = 'OBD1_-_CONTRACT_[TEMPLATE].pdf'
  WHERE LOWER(package_id) IN ('pkg-obd1','obd1') AND agreement_pdf IS NULL;

UPDATE psy_packages SET agreement_pdf = 'OBDX1_-_CONTRACT_[TEMPLATE].pdf'
  WHERE LOWER(package_id) IN ('pkg-obdx1','obdx1') AND agreement_pdf IS NULL;

UPDATE psy_packages SET agreement_pdf = 'OBDY1_-_CONTRACT_[TEMPLATE].pdf'
  WHERE LOWER(package_id) IN ('pkg-obdy1','obdy1') AND agreement_pdf IS NULL;

UPDATE psy_packages SET agreement_pdf = 'OBG_(NLC)_-_CONTRACT_[TEMPLATE].pdf'
  WHERE LOWER(package_id) IN ('pkg-obg-nlc','pkg-obg','obg','obg-nlc') AND agreement_pdf IS NULL;

UPDATE psy_packages SET agreement_pdf = 'OBP1_-_CONTRACT_[TEMPLATE].pdf'
  WHERE LOWER(package_id) IN ('pkg-obp1','obp1') AND agreement_pdf IS NULL;

UPDATE psy_packages SET agreement_pdf = 'OBPX1_-_CONTRACT_[TEMPLATE].pdf'
  WHERE LOWER(package_id) IN ('pkg-obpx1','obpx1') AND agreement_pdf IS NULL;

UPDATE psy_packages SET agreement_pdf = 'OBPY1_-_CONTRACT_[TEMPLATE].pdf'
  WHERE LOWER(package_id) IN ('pkg-obpy1','obpy1') AND agreement_pdf IS NULL;

SELECT 'Step 39 OK — agreement_pdf mapping ready' AS status;


-- ════════════════════════════════════════════════════════════════
-- step40_agreement_storage.sql
-- ════════════════════════════════════════════════════════════════

-- ============================================================
-- step40_agreement_storage.sql
-- Storage bucket setup for package agreement PDFs.
-- Staff upload via pakej-edit.html → saved here → patient reads when signing.
-- ============================================================

-- Create the private bucket
INSERT INTO storage.buckets (id, name, public)
  VALUES ('agreement-templates', 'agreement-templates', false)
ON CONFLICT (id) DO NOTHING;

-- All authenticated users can READ (so patient can preview + load to sign)
DO $$ BEGIN
  CREATE POLICY "Authenticated read agreement templates"
    ON storage.objects FOR SELECT
    USING (bucket_id = 'agreement-templates' AND auth.uid() IS NOT NULL);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Only admin / manager / doctor can UPLOAD / UPDATE / DELETE
DO $$ BEGIN
  CREATE POLICY "Staff manage agreement templates"
    ON storage.objects FOR ALL
    USING (
      bucket_id = 'agreement-templates'
      AND EXISTS (
        SELECT 1 FROM psy_profiles
        WHERE id = auth.uid()
        AND role = 'staff'
        AND staff_role IN ('admin','manager','doctor')
      )
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

SELECT 'Step 40 OK — agreement-templates storage bucket ready' AS status;


-- ════════════════════════════════════════════════════════════════
-- step41_agreement_clauses.sql
-- ════════════════════════════════════════════════════════════════

-- ============================================================
-- step41_agreement_clauses.sql
-- Migrate from PDF upload to HTML text clauses approach.
-- Admin edit clauses → patient render as HTML → sign → auto-generate PDF.
--
-- agreement_clauses structure:
--   [{ "title": "1. Tanggungjawab", "body": "Saya bersetuju..." }, ...]
--
-- Supports variables: {{patient_name}}, {{patient_ic}}, {{package_name}}, {{today}}, {{price}}
-- ============================================================

ALTER TABLE psy_packages
  ADD COLUMN IF NOT EXISTS agreement_clauses JSONB DEFAULT '[]',
  ADD COLUMN IF NOT EXISTS agreement_version TEXT,
  ADD COLUMN IF NOT EXISTS agreement_title TEXT DEFAULT 'Kontrak Pelaburan Kesihatan';

COMMENT ON COLUMN psy_packages.agreement_clauses IS
  'Array of {title, body} clauses for the patient agreement. Supports variables like {{patient_name}}.';
COMMENT ON COLUMN psy_packages.agreement_version IS
  'Version label, e.g. ISW.SOP OB KOB FORM 03 CONTRACT 250711';
COMMENT ON COLUMN psy_packages.agreement_title IS
  'Title shown at top of agreement (default: Kontrak Pelaburan Kesihatan)';

-- Seed default clauses (matching the original PDF content) for all packages with empty clauses
UPDATE psy_packages
SET
  agreement_clauses = '[
    {"title": "1. Tanggungjawab Maklumat", "body": "Saya mengambil tanggungjawab sepenuhnya terhadap kesihatan saya dan telah mengisi borang ini dengan sukarela dengan memberikan maklumat kesihatan saya kepada Ibnu Sina Wellness."},
    {"title": "2. Khidmat Nasihat", "body": "Saya berpuas hati dengan khidmat nasihat kesihatan yang diberikan oleh perawat Ibnu Sina Wellness."},
    {"title": "3. Bukan Rawatan Medikal", "body": "Saya faham dengan sepenuhnya bahawa ia bukan diagnosis medikal atau rawatan medikal atau substitut untuk diagnosis medikal atau rawatan medikal."},
    {"title": "4. Penyakit Mental & Sihir", "body": "Saya faham bahawa sekiranya saya mempunyai masalah mental atau sihir dan saka, saya harus dirawat terlebih dahulu sebelum memulakan program {{package_name}} di Ibnu Sina Wellness."},
    {"title": "5. Rawatan Alternatif", "body": "Saya faham bahawa program {{package_name}} di Ibnu Sina Wellness adalah rawatan alternatif dan ia tidak menggantikan perubatan hospital maka saya akan meneruskan pengambilan ubat, perubatan dan pemeriksaan hospital."},
    {"title": "6. Komitmen Harian", "body": "Saya faham bagi mencapai hasil yang baik, saya perlu amalkan secara komited setiap hari segala tatacara yang disusun dan diajarkan oleh Ibnu Sina Wellness secara sepenuhnya."},
    {"title": "7. Gaya Pemikiran Fitrah", "body": "Saya komited untuk mengikuti program {{package_name}} bagi menukar kepada Gaya Pemikiran Follow Fitrah sebagai tahap asas untuk mencapai kesihatan yang sihat."},
    {"title": "8. Penyembuhan Di Tangan Allah", "body": "Saya faham penyembuhan penyakit adalah di tangan Allah SWT dan jangkamasa penyembuhan bergantung kepada keizinan Allah."},
    {"title": "9. Penerangan Pakej", "body": "Saya telah diberi penerangan penuh pakej program {{package_name}} dengan jelas oleh Ibnu Sina Wellness."},
    {"title": "10. Reaksi Pemulihan", "body": "Ibnu Sina Wellness telah memaklumkan tentang reaksi pemulihan dan gejala prosedur, yang boleh termasuk, tetapi tidak terhad kepada: pening atau loya, sakit-sakit badan, flu, lebam, perubahan warna kulit, dan kemungkinan risiko lain yang tidak dijangka. Dalam sesetengah kes, simptom saya mungkin bertambah buat sementara waktu sebelum ia mula beransur baik. Saya akan menanggung segala risiko yang terlibat dengan prosedur saya."},
    {"title": "11. Kecemasan Hospital", "body": "Saya faham saya perlu ke hospital untuk kecemasan. Saya juga akan segera ke hospital sekiranya saya sakit atau mengalami reaksi pemulihan yang teruk seperti yang tertera di buku Sains di Sebalik {{package_name}} atau seperti yang dinasihatkan oleh perawat dan coach Ibnu Sina Wellness."},
    {"title": "12. Tiada Jaminan Keputusan", "body": "Saya faham bahawa tiada jaminan keputusan untuk sebarang prosedur yang sedang dijalani. Prosedur kesihatan alternatif dan holistik selalunya tidak akan menunjukkan hasil rawatan dengan serta merta."},
    {"title": "13. Tempoh Hasil", "body": "Tempoh untuk mencapai hasil serta keputusan bergantung pada tahap kesihatan saya, disiplin serta komitmen saya mengamalkan kaedah program {{package_name}} di Ibnu Sina Wellness."},
    {"title": "14. Tiada Paksa Tanggungjawab", "body": "Saya tidak akan memaksa Ibnu Sina Wellness untuk bertanggungjawab ke atas sebarang kekurangan hasil program {{package_name}}."},
    {"title": "15. Kerosakan Peralatan", "body": "Saya faham bahawa sekiranya terdapat sebarang kerosakan terhadap peralatan rawatan Ibnu Sina Wellness disebabkan oleh kecuaian atau kegagalan untuk bertindak sewajarnya dari diri saya sendiri, saya akan membayar pampasan kepada pihak Ibnu Sina Wellness kos yang munasabah untuk membaiki kerosakan peralatan rawatan tersebut berdasarkan permintaan Ibnu Sina Wellness."},
    {"title": "16. Pilihan Sendiri", "body": "Dengan rela hati saya sendiri membuat keputusan untuk mengikuti program {{package_name}} Ibnu Sina Wellness dan telah dimaklumkan tentang risiko serta manfaatnya."},
    {"title": "17. Pembebasan Tanggungjawab", "body": "Saya membebaskan pihak Ibnu Sina Wellness, herba-herba yang digunakan, peralatan yang digunakan, fasiliti, perawat, strategist, pekerja Ibnu Sina Wellness, pesakit yang memberi testimoni serta kesemua produksi media Ibnu Sina Wellness dari sebarang tindakan dan kerugian selamanya."},
    {"title": "18. Barang Peribadi", "body": "Saya faham bahawa semua barang peribadi di dalam fasiliti Ibnu Sina Wellness adalah di bawah tanggungjawab saya sendiri dan pihak Ibnu Sina Wellness tidak akan bertanggungjawab pada sebarang kerosakan atau kecurian atau penyelewengan barang peribadi saya."},
    {"title": "19. Rakaman Laporan Progres", "body": "19.1 Saya dengan ini mengesahkan persetujuan yang diberikan kepada Ibnu Sina Wellness berkenaan dengan fotografi, rakaman video, penggambaran, atau rakaman audio bagi tujuan penyimpanan rekod pesakit, informasi, pembelajaran atau promosi.\n\n19.2 Saya sedia maklum bahawa maklumat yang diberikan kepada Ibnu Sina Wellness akan digunakan, diedarkan atau dikongsikan kepada mana-mana pihak ketiga berkenaan dengan fotografi, rakaman video, penggambaran, atau rakaman audio untuk siaran - langsung atau pre-rakaman."},
    {"title": "20. Pembatalan Program", "body": "Saya akan memberi notis bertulis tempoh 7 hari sekiranya saya ingin membatalkan program {{package_name}}."},
    {"title": "21. Pemulangan Wang", "body": "Saya faham tiada pemulangan wang secara tunai ke atas pembayaran yang dilakukan. Lebihan wang yang telah dibayar akan digantikan dengan mana-mana perkhidmatan dan/atau produk Ibnu Sina Wellness yang lain."},
    {"title": "22. Hari Rawatan", "body": "22.1 Hari rawatan ialah pada hari Jumaat, Sabtu dan Ahad.\n\n22.2 Saya faham bahawa jika rawatan di luar waktu dan hari yang dinyatakan, akan ada cas \"on-call\" RM50/sejam.\n\n22.3 Saya faham bahawa ISW berhak untuk menukar waktu dan hari rawatan atas apa-apa sebab dan tiada cas \"on-call\" akan dikenakan."},
    {"title": "23. Pembayaran Ansuran", "body": "Saya bertanggungjawab untuk melunaskan bayaran mengikut tarikh dan jumlah yang telah ditetapkan mengikut Pelan Pelaburan Ansuran."},
    {"title": "24. Kegagalan Ansuran", "body": "Saya faham jika saya gagal menunaikan pembayaran mengikut Pelan Pelaburan Ansuran, yuran pakej saya akan berbalik ke yuran asal."},
    {"title": "25. Tindakan Undang-undang", "body": "Saya juga sedar kegagalan mematuhi bayaran mengikut tarikh dan jumlah yang telah ditetapkan akan menyebabkan kes saya dirujuk untuk tindakan undang-undang."},
    {"title": "26. Persetujuan Hutang", "body": "Saya bersetuju untuk menjalani program {{package_name}} sepenuhnya di Ibnu Sina Wellness secara berhutang."},
    {"title": "27. Janji Pembayaran", "body": "Saya berjanji untuk melangsaikan semua bayaran mengikut Pelan Pelaburan Ansuran."},
    {"title": "28. Tiada Refund", "body": "Saya faham tiada pemulangan wang akan diberikan atas bayaran yang telah dibuat. Lebihan wang yang telah dibayar boleh digantikan dengan mana-mana perkhidmatan dan/atau produk Ibnu Sina Wellness yang lain, tertakluk pada pengurusan Ibnu Sina Wellness."},
    {"title": "29. Bayaran Online Transfer", "body": "Untuk bayaran online transfer, saya hanya akan buat bayaran ke akaun di bawah:\n\nIBNU SINA WELLNESS SDN BHD - CIMB BANK - 8605794539\nWA SCREENSHOT BAYARAN KE COACH DI 0389663702"}
  ]'::jsonb,
  agreement_version = 'ISW.SOP OB KOB FORM 03 CONTRACT 250711',
  agreement_title = 'Kontrak Pelaburan Kesihatan'
WHERE agreement_clauses = '[]' OR agreement_clauses IS NULL;

SELECT 'Step 41 OK — agreement clauses seeded for all packages' AS status;


-- ════════════════════════════════════════════════════════════════
-- step42_kob_storage_buckets.sql
-- ════════════════════════════════════════════════════════════════

-- ============================================================
-- step42_kob_storage_buckets.sql
-- Setup storage buckets for KOB signatures + documents.
-- Patient uploads signature PNG + generated signed PDF here.
-- Doctor uploads supporting documents here.
-- ============================================================

-- ── kob-signatures bucket (patient signature PNG + signed PDF) ──
INSERT INTO storage.buckets (id, name, public)
  VALUES ('kob-signatures', 'kob-signatures', false)
ON CONFLICT (id) DO NOTHING;

-- Patient can upload their own signature
DO $$ BEGIN
  CREATE POLICY "Patient upload own signature"
    ON storage.objects FOR INSERT
    WITH CHECK (
      bucket_id = 'kob-signatures'
      AND auth.uid() IS NOT NULL
      AND (storage.foldername(name))[1] IN (
        SELECT id::text FROM psy_patients WHERE user_id = auth.uid()
      )
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Patient can read own signature
DO $$ BEGIN
  CREATE POLICY "Patient read own signature"
    ON storage.objects FOR SELECT
    USING (
      bucket_id = 'kob-signatures'
      AND auth.uid() IS NOT NULL
      AND (storage.foldername(name))[1] IN (
        SELECT id::text FROM psy_patients WHERE user_id = auth.uid()
      )
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Staff can read all signatures
DO $$ BEGIN
  CREATE POLICY "Staff read all signatures"
    ON storage.objects FOR SELECT
    USING (
      bucket_id = 'kob-signatures'
      AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff')
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ── kob-documents bucket (doctor uploads docs during KOB session) ──
INSERT INTO storage.buckets (id, name, public)
  VALUES ('kob-documents', 'kob-documents', false)
ON CONFLICT (id) DO NOTHING;

DO $$ BEGIN
  CREATE POLICY "Staff manage kob documents"
    ON storage.objects FOR ALL
    USING (
      bucket_id = 'kob-documents'
      AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff')
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "Patient read own kob documents"
    ON storage.objects FOR SELECT
    USING (
      bucket_id = 'kob-documents'
      AND auth.uid() IS NOT NULL
      AND (storage.foldername(name))[1] IN (
        SELECT id::text FROM psy_patients WHERE user_id = auth.uid()
      )
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

SELECT 'Step 42 OK — kob-signatures + kob-documents buckets ready' AS status;


-- ════════════════════════════════════════════════════════════════
-- step43_pakej_rujukan_storage.sql
-- ════════════════════════════════════════════════════════════════

-- ============================================================
-- step43_pakej_rujukan_storage.sql
-- Storage bucket for package weekly rujukan files (SOPs, scripts, docs).
-- Staff-only read+write. Patient does NOT see rujukan.
-- ============================================================

-- Create private bucket
INSERT INTO storage.buckets (id, name, public)
  VALUES ('pakej-rujukan', 'pakej-rujukan', false)
ON CONFLICT (id) DO NOTHING;

-- Staff (any role) can read
DO $$ BEGIN
  CREATE POLICY "Staff read pakej rujukan"
    ON storage.objects FOR SELECT
    USING (
      bucket_id = 'pakej-rujukan'
      AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff')
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Only admin / manager / doctor can upload / update / delete
DO $$ BEGIN
  CREATE POLICY "Staff manage pakej rujukan"
    ON storage.objects FOR ALL
    USING (
      bucket_id = 'pakej-rujukan'
      AND EXISTS (
        SELECT 1 FROM psy_profiles
        WHERE id = auth.uid()
        AND role = 'staff'
        AND staff_role IN ('admin','manager','doctor')
      )
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

SELECT 'Step 43 OK — pakej-rujukan storage bucket ready' AS status;


-- ════════════════════════════════════════════════════════════════
-- step44_daily_schedule.sql
-- ════════════════════════════════════════════════════════════════

-- ============================================================
-- step44_daily_schedule.sql
-- Daily schedule template per package (staff defines)
-- + per-patient customized copy (patient can edit)
-- + in-app reminder fires when patient opens app at scheduled time
-- ============================================================

-- Template per package
ALTER TABLE psy_packages
  ADD COLUMN IF NOT EXISTS daily_schedule JSONB DEFAULT '[]'::jsonb;

COMMENT ON COLUMN psy_packages.daily_schedule IS
  'Array of {time:"HH:MM", activity:"text"} — default daily routine for patients on this package.';

-- Patient's customized copy (NULL = follow package template, [] or array = patient-customized)
ALTER TABLE psy_patients
  ADD COLUMN IF NOT EXISTS daily_schedule JSONB;

COMMENT ON COLUMN psy_patients.daily_schedule IS
  'Patient-customized daily schedule. NULL = inherit from active package template. Array = patient has overridden.';

SELECT 'Step 44 OK — daily_schedule columns ready' AS status;


-- ════════════════════════════════════════════════════════════════
-- step45_seed_daily_schedule.sql
-- ════════════════════════════════════════════════════════════════

-- ============================================================
-- step45_seed_daily_schedule.sql
-- Seed sample daily_schedule for demo. Single UPDATE with CASE
-- to avoid deadlock between multiple UPDATE statements.
-- ============================================================

UPDATE psy_packages
SET daily_schedule = CASE
  WHEN LOWER(package_id) IN (
    'obd1','obdx1','obdy1','obp1','obpx1','obpy1',
    'pkg-obd1','pkg-obdx1','pkg-obdy1','pkg-obp1','pkg-obpx1','pkg-obpy1'
  ) THEN '[
    {"time":"06:15","activity":"Zikir bersanad"},
    {"time":"06:30","activity":"Minum madu LTHPG"},
    {"time":"07:30","activity":"Minum madu LTH"},
    {"time":"07:45","activity":"Berjemur cahaya matahari pagi & terapi bumi & pernafasan fitrah (10 minit)"},
    {"time":"08:15","activity":"Makan breakfast (Yogurt dan buah)"},
    {"time":"09:15","activity":"Minum madu LTHPG"},
    {"time":"10:15","activity":"Minum madu LTH"},
    {"time":"11:15","activity":"Minum madu LTHPG"},
    {"time":"12:15","activity":"Minum madu LTH"},
    {"time":"12:30","activity":"Lunch & minum air kelapa"},
    {"time":"13:15","activity":"Solat Zohor & pernafasan fitrah (5 minit)"},
    {"time":"14:15","activity":"Minum madu LTHPG"},
    {"time":"15:15","activity":"Minum madu LTH"},
    {"time":"16:15","activity":"Minum madu LTHPG"},
    {"time":"16:40","activity":"Solat Asar & pernafasan fitrah (5 minit)"},
    {"time":"17:00","activity":"Berkebun @ Terapi bumi"},
    {"time":"18:30","activity":"Makan malam"},
    {"time":"19:30","activity":"Solat Maghrib & Zikir bersanad"},
    {"time":"20:30","activity":"Solat Isyak & Pernafasan Fitrah (5 minit)"},
    {"time":"21:00","activity":"Minum madu LTH"},
    {"time":"21:30","activity":"Pernafasan fitrah (5 minit) & Tidur"}
  ]'::jsonb
  WHEN LOWER(package_id) IN (
    'eol','pkg-eol','eol-plus','eol+','pkg-eol-plus','pkg-eolplus',
    'js','jumpstart','js+','jumpstart+','pkg-js','pkg-jumpstart','pkg-jumpstart-plus','pkg-jsplus'
  ) THEN '[
    {"time":"06:30","activity":"Zikir pagi & pernafasan fitrah"},
    {"time":"07:00","activity":"Minum air Afiyah"},
    {"time":"08:00","activity":"Sarapan ringan"},
    {"time":"10:00","activity":"Sesi bimbingan terapi (online/F2F)"},
    {"time":"13:00","activity":"Solat Zohor & rehat"},
    {"time":"14:00","activity":"Makan tengahari"},
    {"time":"17:00","activity":"Berkebun atau aktiviti luar"},
    {"time":"19:30","activity":"Solat Maghrib & Zikir bersanad"},
    {"time":"21:30","activity":"Tidur awal"}
  ]'::jsonb
  ELSE daily_schedule
END
WHERE LOWER(package_id) IN (
  'obd1','obdx1','obdy1','obp1','obpx1','obpy1',
  'pkg-obd1','pkg-obdx1','pkg-obdy1','pkg-obp1','pkg-obpx1','pkg-obpy1',
  'eol','pkg-eol','eol-plus','eol+','pkg-eol-plus','pkg-eolplus',
  'js','jumpstart','js+','jumpstart+','pkg-js','pkg-jumpstart','pkg-jumpstart-plus','pkg-jsplus'
)
AND (daily_schedule IS NULL OR daily_schedule = '[]'::jsonb);

SELECT
  package_id,
  name,
  jsonb_array_length(COALESCE(daily_schedule,'[]'::jsonb)) AS items
FROM psy_packages
WHERE jsonb_array_length(COALESCE(daily_schedule,'[]'::jsonb)) > 0
ORDER BY package_id;


-- ════════════════════════════════════════════════════════════════
-- step46_daily_completions.sql
-- ════════════════════════════════════════════════════════════════

-- ============================================================
-- step46_daily_completions.sql
-- Track patient's daily activity completion (checklist).
-- One row per checked item per day. Resets implicitly via log_date.
-- ============================================================

CREATE TABLE IF NOT EXISTS psy_daily_completions (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id   UUID NOT NULL REFERENCES psy_patients(id) ON DELETE CASCADE,
  log_date     DATE NOT NULL DEFAULT CURRENT_DATE,
  item_time    TEXT NOT NULL,      -- 'HH:MM' string from schedule
  activity     TEXT NOT NULL,      -- snapshot of activity name for reference
  completed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(patient_id, log_date, item_time)
);

CREATE INDEX IF NOT EXISTS idx_daily_completions_patient_date
  ON psy_daily_completions(patient_id, log_date);

ALTER TABLE psy_daily_completions ENABLE ROW LEVEL SECURITY;

-- Patient manages own
DO $$ BEGIN
  CREATE POLICY "Patient manage own completions"
    ON psy_daily_completions FOR ALL
    USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()))
    WITH CHECK (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Staff read all (for compliance views)
DO $$ BEGIN
  CREATE POLICY "Staff read completions"
    ON psy_daily_completions FOR SELECT
    USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

SELECT 'Step 46 OK — psy_daily_completions ready' AS status;


-- ════════════════════════════════════════════════════════════════
-- step47_slot_overhaul.sql
-- ════════════════════════════════════════════════════════════════

-- ============================================================
-- step47_slot_overhaul.sql
-- 1. Add slot_type column ('kob' | 'rawatan') to existing slot config
-- 2. Replace old 4 slots with new 5 slots
-- 3. Seed for both KOB + Rawatan × 5 days
-- 4. Add per-date override table (staff manual lock/unlock specific dates)
-- ============================================================

-- ── 1. Add slot_type column ──
ALTER TABLE psy_kob_slot_config
  ADD COLUMN IF NOT EXISTS slot_type TEXT NOT NULL DEFAULT 'kob'
  CHECK (slot_type IN ('kob','rawatan'));

-- Rebuild unique constraint to include slot_type
ALTER TABLE psy_kob_slot_config
  DROP CONSTRAINT IF EXISTS psy_kob_slot_config_day_of_week_slot_start_key;

ALTER TABLE psy_kob_slot_config DROP CONSTRAINT IF EXISTS psy_kob_slot_config_unique;
ALTER TABLE psy_kob_slot_config
  ADD CONSTRAINT psy_kob_slot_config_unique UNIQUE (slot_type, day_of_week, slot_start);

-- ── 2. Clear old slot definitions (template only, no FK to bookings) ──
DELETE FROM psy_kob_slot_config;

-- ── 3. Seed new 5 slots × 2 types × 5 days ──
-- Slots:
--   1: 07:00 - 09:00  "7-9 pg"
--   2: 09:30 - 11:30  "9.30-11.30 pg"
--   3: 14:00 - 16:00  "2-4 ptg"
--   4: 14:30 - 16:30  "2.30-4.30 ptg"
--   5: 16:30 - 18:30  "4.30-6.30 ptg"
-- Days: Rabu(3), Khamis(4), Jumaat(5), Sabtu(6), Ahad(0)

INSERT INTO psy_kob_slot_config (slot_type, day_of_week, slot_start, slot_end, label, sort_order, is_active)
SELECT
  t.slot_type,
  d.day_of_week,
  s.slot_start::time,
  s.slot_end::time,
  s.label,
  s.sort_order,
  true
FROM
  (VALUES ('kob'), ('rawatan')) AS t(slot_type),
  (VALUES (3), (4), (5), (6), (0)) AS d(day_of_week),
  (VALUES
    ('07:00', '09:00', '7-9 pg',          1),
    ('09:30', '11:30', '9.30-11.30 pg',   2),
    ('14:00', '16:00', '2-4 ptg',         3),
    ('14:30', '16:30', '2.30-4.30 ptg',   4),
    ('16:30', '18:30', '4.30-6.30 ptg',   5)
  ) AS s(slot_start, slot_end, label, sort_order);

-- ── 4. Per-date override (staff lock/offer specific slots per date) ──
CREATE TABLE IF NOT EXISTS psy_slot_date_overrides (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slot_date   DATE NOT NULL,
  slot_type   TEXT NOT NULL CHECK (slot_type IN ('kob','rawatan')),
  slot_start  TIME NOT NULL,
  is_offered  BOOLEAN NOT NULL DEFAULT true,
  note        TEXT,
  created_by  UUID,
  created_at  TIMESTAMPTZ DEFAULT now(),
  updated_at  TIMESTAMPTZ DEFAULT now(),
  UNIQUE (slot_date, slot_type, slot_start)
);

CREATE INDEX IF NOT EXISTS idx_slot_overrides_date
  ON psy_slot_date_overrides(slot_date, slot_type);

ALTER TABLE psy_slot_date_overrides ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "Anyone read slot overrides"
    ON psy_slot_date_overrides FOR SELECT
    USING (auth.uid() IS NOT NULL);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "Staff manage slot overrides"
    ON psy_slot_date_overrides FOR ALL
    USING (EXISTS (
      SELECT 1 FROM psy_profiles
      WHERE id = auth.uid() AND role = 'staff'
      AND staff_role IN ('admin','manager','doctor')
    ));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

SELECT 'Step 47 OK — 5 slot template × 2 types × 5 days + per-date override ready' AS status;


-- ════════════════════════════════════════════════════════════════
-- step48_feedback_weekly.sql
-- ════════════════════════════════════════════════════════════════

-- ============================================================
-- step48_feedback_weekly.sql
-- Extend psy_feedback to support weekly per-session feedback
-- + overall end-of-treatment feedback (existing behavior).
-- ============================================================

-- Create base table if not exists (was missing in earlier migrations)
CREATE TABLE IF NOT EXISTS psy_feedback (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id  UUID REFERENCES psy_patients(id) ON DELETE CASCADE,
  rating      INT CHECK (rating BETWEEN 1 AND 5),
  comment     TEXT,
  helpful_tags JSONB DEFAULT '[]',
  created_at  TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE psy_feedback ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "Patients manage own feedback" ON psy_feedback FOR ALL
    USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()))
    WITH CHECK (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "Staff read all feedback" ON psy_feedback FOR SELECT
    USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

ALTER TABLE psy_feedback
  ADD COLUMN IF NOT EXISTS feedback_type   TEXT NOT NULL DEFAULT 'overall'
    CHECK (feedback_type IN ('weekly','overall')),
  ADD COLUMN IF NOT EXISTS week_number     INT,
  ADD COLUMN IF NOT EXISTS plan_id         UUID REFERENCES psy_treatment_plans(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS coach_id        UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS coach_name      TEXT,
  ADD COLUMN IF NOT EXISTS coach_rating    INT CHECK (coach_rating BETWEEN 1 AND 5),
  ADD COLUMN IF NOT EXISTS supply_rating   INT CHECK (supply_rating BETWEEN 1 AND 5);

COMMENT ON COLUMN psy_feedback.feedback_type IS
  '"weekly" = per-session feedback (rates coach + supplies); "overall" = end-of-treatment review';

CREATE INDEX IF NOT EXISTS idx_feedback_type_patient
  ON psy_feedback(patient_id, feedback_type);

CREATE INDEX IF NOT EXISTS idx_feedback_coach
  ON psy_feedback(coach_id) WHERE coach_id IS NOT NULL;

SELECT 'Step 48 OK — feedback weekly + KPI tracking ready' AS status;


-- ════════════════════════════════════════════════════════════════
-- step49_library_package_filter.sql
-- ════════════════════════════════════════════════════════════════

-- ============================================================
-- step49_library_package_filter.sql
-- Library content can be tagged with package IDs to restrict visibility.
-- NULL or empty array = visible to everyone (default).
-- Array of package_ids = only patients on matching package see it.
-- ============================================================

ALTER TABLE psy_library_items
  ADD COLUMN IF NOT EXISTS package_ids TEXT[];

COMMENT ON COLUMN psy_library_items.package_ids IS
  'Package IDs (psy_packages.package_id) that can access this content. NULL/empty = public for all.';

CREATE INDEX IF NOT EXISTS idx_library_package_ids
  ON psy_library_items USING GIN (package_ids);

SELECT 'Step 49 OK — library package filter ready' AS status;


-- ════════════════════════════════════════════════════════════════
-- step50_package_categories.sql
-- ════════════════════════════════════════════════════════════════

-- ============================================================
-- step50_package_categories.sql
-- Dynamic categories for packages — admin boleh CRUD dari UI
-- ============================================================

CREATE TABLE IF NOT EXISTS psy_package_categories (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug        TEXT NOT NULL UNIQUE,
  label       TEXT NOT NULL,
  badge_color TEXT,
  sort_order  INTEGER NOT NULL DEFAULT 100,
  is_active   BOOLEAN NOT NULL DEFAULT true,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE psy_package_categories IS 'Senarai kategori pakej (dahulu hardcoded: standard/free/vip). Slug disimpan dalam psy_packages.tier.';
COMMENT ON COLUMN psy_package_categories.slug IS 'Stored value in psy_packages.tier (e.g. standard, free, vip, detox)';
COMMENT ON COLUMN psy_package_categories.badge_color IS 'Tailwind color suffix for badge (e.g. gold, green, navy) — null = no badge';

-- Seed kategori sedia ada
INSERT INTO psy_package_categories (slug, label, badge_color, sort_order)
VALUES
  ('standard', 'Program Intensif', NULL,    10),
  ('free',     'Pakej Percuma',    'green', 20),
  ('vip',      'VIP / Premium',    'gold',  30)
ON CONFLICT (slug) DO NOTHING;

-- RLS
ALTER TABLE psy_package_categories ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "Anyone read categories" ON psy_package_categories
    FOR SELECT USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "Staff manage categories" ON psy_package_categories
    FOR ALL USING (
      EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff')
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;


-- ════════════════════════════════════════════════════════════════
-- step50_library_topic_faq.sql
-- ════════════════════════════════════════════════════════════════

-- ============================================================
-- step50_library_topic_faq.sql
-- Library redesign: explicit media_type + topic category + FAQ support.
--   • media_type — jenis eksplisit (video/article/pdf/course/faq/image)
--     supaya tab & KPI tepat (sebelum ni jenis diteka dari content_url).
--   • topic       — kategori topik (Kesihatan Mental, Pemakanan, dll).
--     Berasingan dari `category` (yang simpan warna kad).
--   • FAQ disimpan sebagai media_type='faq': title = soalan, content_body = jawapan.
-- ============================================================

ALTER TABLE psy_library_items
  ADD COLUMN IF NOT EXISTS media_type TEXT,
  ADD COLUMN IF NOT EXISTS topic      TEXT;

COMMENT ON COLUMN psy_library_items.media_type IS
  'Jenis eksplisit: video | article | pdf | course | faq | image. Sumber tunggal untuk tab/KPI.';
COMMENT ON COLUMN psy_library_items.topic IS
  'Kategori topik (cth: Kesihatan Mental, Pemakanan). Berbeza dari category (warna kad).';

-- ── Backfill media_type untuk rekod sedia ada (heuristik sama macam UI lama) ──
UPDATE psy_library_items SET media_type = CASE
  WHEN content_type ILIKE '%faq%' THEN 'faq'
  WHEN lower(coalesce(content_url,'')) ~ '\.(jpg|jpeg|png|gif|webp)' THEN 'image'
  WHEN lower(coalesce(content_url,'')) ~ '\.(mp4|webm|mov)' OR lower(coalesce(content_url,'')) LIKE '%youtube%' OR lower(coalesce(content_url,'')) LIKE '%youtu.be%' THEN 'video'
  WHEN lower(coalesce(content_url,'')) ~ '\.pdf' OR lower(coalesce(content_url,'')) LIKE '%drive.google.com%' THEN 'pdf'
  WHEN lower(coalesce(content_url,'')) ~ 'course|membership|portal' OR content_type ILIKE '%course%' THEN 'course'
  ELSE 'article'
END
WHERE media_type IS NULL;

CREATE INDEX IF NOT EXISTS idx_library_media_type ON psy_library_items(media_type);
CREATE INDEX IF NOT EXISTS idx_library_topic      ON psy_library_items(topic);

SELECT 'Step 50 OK — library media_type + topic ready' AS status,
       count(*) FILTER (WHERE media_type='video')   AS video,
       count(*) FILTER (WHERE media_type='article') AS article,
       count(*) FILTER (WHERE media_type='faq')     AS faq,
       count(*) AS total
FROM psy_library_items;


-- ════════════════════════════════════════════════════════════════
-- step51_treatment_completion.sql
-- ════════════════════════════════════════════════════════════════

-- ============================================================
-- step51_treatment_completion.sql
-- Auto-complete treatment when package expires + audit Google Review clicks
-- ============================================================

-- Add outcome_status column kalau belum ada
ALTER TABLE psy_patients
  ADD COLUMN IF NOT EXISTS outcome_status TEXT;

-- Function: complete expired treatments
CREATE OR REPLACE FUNCTION fn_complete_expired_treatments()
RETURNS TABLE (patient_id UUID, plan_id UUID, action TEXT) AS $$
BEGIN
  RETURN QUERY
  WITH expired_patients AS (
    SELECT p.id AS pat_id, p.user_id, p.active_package_name
    FROM psy_patients p
    WHERE p.active_package_id IS NOT NULL
      AND p.package_expires_at IS NOT NULL
      AND p.package_expires_at < now()
      AND (p.outcome_status IS NULL OR p.outcome_status <> 'completed')
  ),
  plan_updates AS (
    UPDATE psy_treatment_plans tp
       SET status = 'completed'
      FROM expired_patients ep
     WHERE tp.patient_id = ep.pat_id
       AND tp.status = 'active'
    RETURNING tp.id, tp.patient_id
  ),
  patient_updates AS (
    UPDATE psy_patients p
       SET outcome_status = 'completed'
      FROM expired_patients ep
     WHERE p.id = ep.pat_id
    RETURNING p.id
  ),
  notif_inserts AS (
    INSERT INTO psy_notifications (user_id, type, title, body, link, is_read)
    SELECT ep.user_id, 'plan',
           'Rawatan Anda Telah Tamat 🎉',
           'Tahniah atas penyelesaian rawatan ' || COALESCE(ep.active_package_name, 'anda') || '. Sila kongsi maklum balas anda.',
           'feedback.html',
           false
      FROM expired_patients ep
      WHERE NOT EXISTS (
        SELECT 1 FROM psy_notifications n
         WHERE n.user_id = ep.user_id
           AND n.type = 'plan'
           AND n.title LIKE 'Rawatan Anda Telah Tamat%'
      )
    RETURNING user_id
  )
  SELECT ep.pat_id, pu.id, 'completed'::TEXT
    FROM expired_patients ep
    LEFT JOIN plan_updates pu ON pu.patient_id = ep.pat_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION fn_complete_expired_treatments() IS
  'Auto-mark treatment plans + patient outcome_status sebagai completed bila pakej tamat. Insert notifikasi feedback. Boleh dipanggil manual atau via pg_cron.';

-- Optional: schedule daily (kalau pg_cron extension installed)
-- SELECT cron.schedule('complete-expired-treatments', '0 1 * * *', $$SELECT fn_complete_expired_treatments()$$);

-- Jalankan sekali sekarang untuk catch existing expired
SELECT * FROM fn_complete_expired_treatments();

-- ── AUDIT: Google Review click tracking ──
-- Audit log dah ada, tak perlu table baru. Action key: 'google_review.clicked'
COMMENT ON TABLE psy_audit_log IS
  'Audit trail. Untuk Google Review tracking guna action=''google_review.clicked'', meta={rating: N}';

SELECT 'Step 51 OK — treatment auto-completion + audit setup' AS status;


-- ════════════════════════════════════════════════════════════════
-- step51_library_editor_fields.sql
-- ════════════════════════════════════════════════════════════════

-- ============================================================
-- step51_library_editor_fields.sql
-- Field tambahan untuk editor "Tambah Kandungan" reka bentuk baru:
--   • tags          — tag carian (max 5), array.
--   • duration       — tempoh video (mm:ss) — papar pada kad video.
--   • attachment_url — dokumen sokongan (PDF/DOC) opsional.
-- content_body kini boleh simpan HTML (rich text "Penerangan Kandungan").
-- ============================================================

ALTER TABLE psy_library_items
  ADD COLUMN IF NOT EXISTS tags           TEXT[],
  ADD COLUMN IF NOT EXISTS duration       TEXT,
  ADD COLUMN IF NOT EXISTS attachment_url TEXT;

COMMENT ON COLUMN psy_library_items.tags IS 'Tag carian (max 5).';
COMMENT ON COLUMN psy_library_items.duration IS 'Tempoh video mm:ss (papar pada kad).';
COMMENT ON COLUMN psy_library_items.attachment_url IS 'Dokumen sokongan (PDF/DOC) opsional.';

CREATE INDEX IF NOT EXISTS idx_library_tags ON psy_library_items USING GIN (tags);

SELECT 'Step 51 OK — library editor fields ready' AS status;


-- ════════════════════════════════════════════════════════════════
-- step52_library_view_meta.sql
-- ════════════════════════════════════════════════════════════════

-- ============================================================
-- step52_library_view_meta.sql
-- Meta untuk page "Lihat Kandungan" (view detail):
--   • view_count      — Jumlah Tontonan (auto-increment bila pesakit buka).
--   • created_by_name — "Diterbitkan Oleh" (nama staff yang cipta).
-- ============================================================

ALTER TABLE psy_library_items
  ADD COLUMN IF NOT EXISTS view_count      INT DEFAULT 0,
  ADD COLUMN IF NOT EXISTS created_by_name TEXT;

COMMENT ON COLUMN psy_library_items.view_count IS 'Jumlah tontonan — increment bila pesakit buka library-detail.';
COMMENT ON COLUMN psy_library_items.created_by_name IS 'Nama staff yang cipta kandungan (Diterbitkan Oleh).';

-- Increment selamat tanpa race (dipanggil dari client via RPC)
CREATE OR REPLACE FUNCTION psy_library_bump_view(p_item_id TEXT)
RETURNS void LANGUAGE sql SECURITY DEFINER AS $$
  UPDATE psy_library_items SET view_count = COALESCE(view_count,0) + 1 WHERE item_id = p_item_id;
$$;

GRANT EXECUTE ON FUNCTION psy_library_bump_view(TEXT) TO anon, authenticated;

SELECT 'Step 52 OK — library view meta ready' AS status;


-- ════════════════════════════════════════════════════════════════
-- step53_library_bookmark_feedback.sql
-- ════════════════════════════════════════════════════════════════

-- ============================================================
-- step53_library_bookmark_feedback.sql
-- Interaksi pesakit pada page baca kandungan:
--   • psy_library_bookmarks — "Simpan" (bookmark) per pesakit.
--   • psy_library_feedback  — "Adakah ini membantu?" 👍/👎 per pesakit.
-- ============================================================

CREATE TABLE IF NOT EXISTS psy_library_bookmarks (
  user_id    UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  item_id    TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (user_id, item_id)
);
ALTER TABLE psy_library_bookmarks ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  CREATE POLICY "own bookmarks" ON psy_library_bookmarks FOR ALL
    USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE TABLE IF NOT EXISTS psy_library_feedback (
  user_id    UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  item_id    TEXT NOT NULL,
  helpful    BOOLEAN NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (user_id, item_id)
);
ALTER TABLE psy_library_feedback ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  CREATE POLICY "own feedback" ON psy_library_feedback FOR ALL
    USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE INDEX IF NOT EXISTS idx_lib_bookmark_user ON psy_library_bookmarks(user_id);

SELECT 'Step 53 OK — library bookmark + feedback ready' AS status;


-- ════════════════════════════════════════════════════════════════
-- step54_library_unique_views.sql
-- ════════════════════════════════════════════════════════════════

-- ============================================================
-- step54_library_unique_views.sql
-- Jumlah Bacaan = UNIK per pesakit (bukan setiap buka).
--   • psy_library_views — log satu baris per (pesakit, kandungan).
--   • psy_library_bump_view() ditakrif semula: increment view_count
--     HANYA kali pertama pesakit buka kandungan tersebut.
-- Client (patient library-detail.html) panggil RPC sama — tiada perubahan kod.
-- ============================================================

CREATE TABLE IF NOT EXISTS psy_library_views (
  user_id    UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  item_id    TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (user_id, item_id)
);
ALTER TABLE psy_library_views ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  CREATE POLICY "own views" ON psy_library_views FOR ALL
    USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Redefine: hanya kira sekali per pesakit
CREATE OR REPLACE FUNCTION psy_library_bump_view(p_item_id TEXT)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_uid UUID := auth.uid();
BEGIN
  IF v_uid IS NULL THEN RETURN; END IF;             -- tak login → skip
  INSERT INTO psy_library_views(user_id, item_id)
    VALUES (v_uid, p_item_id)
    ON CONFLICT (user_id, item_id) DO NOTHING;
  IF FOUND THEN                                       -- baris baru = bacaan pertama
    UPDATE psy_library_items
      SET view_count = COALESCE(view_count,0) + 1
      WHERE item_id = p_item_id;
  END IF;
END $$;

GRANT EXECUTE ON FUNCTION psy_library_bump_view(TEXT) TO anon, authenticated;

SELECT 'Step 54 OK — unique-per-patient view count ready' AS status;


-- ════════════════════════════════════════════════════════════════
-- step55_library_status.sql
-- ════════════════════════════════════════════════════════════════

-- ============================================================
-- step55_library_status.sql
-- Status 3-keadaan untuk kandungan (terutama FAQ editor):
--   published | draft | inactive
-- is_active kekal sebagai gate paparan pesakit (is_active = status='published').
-- Kedua-dua editor tulis status + is_active serentak (app-level).
-- ============================================================

ALTER TABLE psy_library_items
  ADD COLUMN IF NOT EXISTS status TEXT;

COMMENT ON COLUMN psy_library_items.status IS
  'published | draft | inactive. is_active = (status=published). Pesakit nampak published sahaja.';

-- Backfill dari is_active sedia ada
UPDATE psy_library_items
  SET status = CASE WHEN is_active THEN 'published' ELSE 'draft' END
  WHERE status IS NULL;

SELECT 'Step 55 OK — library status ready' AS status,
       count(*) FILTER (WHERE status='published') AS published,
       count(*) FILTER (WHERE status='draft')     AS draft,
       count(*) AS total
FROM psy_library_items;


-- ════════════════════════════════════════════════════════════════
-- step56_patient_medical_upload.sql
-- ════════════════════════════════════════════════════════════════

-- ============================================================
-- step56_patient_medical_upload.sql
-- Benarkan PESAKIT upload laporan perubatan berkategori
-- (X-Ray, Ultrasound, CT, MRI, Colonoscopy, Endoscopy, Blood, dll)
-- ke table kanonikal psy_medical_reports — terus mengalir ke
-- patient-hub doktor untuk semakan.
--
-- Idempotent: satukan psy_dna_reports → psy_medical_reports kalau perlu,
-- pastikan semua column wujud, kemudian tambah policy INSERT/DELETE pesakit.
-- ============================================================

-- 1. Satukan nama table (kalau lama masih wujud)
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='psy_dna_reports')
     AND NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='psy_medical_reports') THEN
    ALTER TABLE psy_dna_reports RENAME TO psy_medical_reports;
  END IF;
END $$;

-- 2. Pastikan table + column wujud
CREATE TABLE IF NOT EXISTS psy_medical_reports (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id       UUID NOT NULL REFERENCES psy_patients(id) ON DELETE CASCADE,
  file_name        TEXT NOT NULL,
  file_path        TEXT,
  file_url         TEXT,
  notes            TEXT,
  uploaded_by      UUID,
  uploaded_by_name TEXT,
  uploaded_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE psy_medical_reports
  ADD COLUMN IF NOT EXISTS report_type   TEXT DEFAULT 'dna',
  ADD COLUMN IF NOT EXISTS title         TEXT,
  ADD COLUMN IF NOT EXISTS status        TEXT DEFAULT 'pending',
  ADD COLUMN IF NOT EXISTS sample_date   DATE,
  ADD COLUMN IF NOT EXISTS doctor_name   TEXT,
  ADD COLUMN IF NOT EXISTS doctor_review TEXT,
  ADD COLUMN IF NOT EXISTS review_status TEXT DEFAULT 'pending',
  ADD COLUMN IF NOT EXISTS reviewed_at   TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS shared_with_patient BOOLEAN DEFAULT false;

CREATE INDEX IF NOT EXISTS idx_medical_reports_patient ON psy_medical_reports(patient_id, uploaded_at DESC);
CREATE INDEX IF NOT EXISTS idx_medical_reports_type    ON psy_medical_reports(report_type);

ALTER TABLE psy_medical_reports ENABLE ROW LEVEL SECURITY;

-- 3. Policy sedia ada (idempotent)
DO $$ BEGIN
  CREATE POLICY "staff_medical_all" ON psy_medical_reports FOR ALL
    USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "patient_medical_read" ON psy_medical_reports FOR SELECT
    USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- 4. BARU: pesakit boleh INSERT laporan sendiri
DO $$ BEGIN
  CREATE POLICY "patient_medical_insert" ON psy_medical_reports FOR INSERT
    WITH CHECK (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- 5. BARU: pesakit boleh PADAM laporan yang dia upload sendiri (belum disemak)
DO $$ BEGIN
  CREATE POLICY "patient_medical_delete_own" ON psy_medical_reports FOR DELETE
    USING (
      uploaded_by = auth.uid()
      AND patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid())
      AND COALESCE(review_status,'pending') = 'pending'
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

SELECT 'Step 56 OK — patient medical upload ready' AS status;


-- ════════════════════════════════════════════════════════════════
-- step57_medical_storage_policies.sql
-- ════════════════════════════════════════════════════════════════

-- ============================================================
-- step57_medical_storage_policies.sql
-- Policy STORAGE untuk bucket 'medical-reports' (private).
-- Membolehkan signed URL berfungsi:
--   • Pesakit: upload + baca + padam fail SENDIRI (owner = auth.uid()).
--   • Staff:   baca semua fail.
-- Bucket kekal PRIVATE (data perubatan sensitif) — akses via signed URL.
-- ============================================================

-- Pastikan bucket wujud & private
INSERT INTO storage.buckets (id, name, public)
  VALUES ('medical-reports', 'medical-reports', false)
  ON CONFLICT (id) DO NOTHING;

-- Upload: pengguna authenticated boleh insert ke medical-reports
DO $$ BEGIN
  CREATE POLICY "medical_upload" ON storage.objects FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'medical-reports');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Baca: pemilik fail sendiri (signed URL pesakit)
DO $$ BEGIN
  CREATE POLICY "medical_read_own" ON storage.objects FOR SELECT TO authenticated
    USING (bucket_id = 'medical-reports' AND owner = auth.uid());
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Baca: staff baca semua laporan pesakit
DO $$ BEGIN
  CREATE POLICY "medical_read_staff" ON storage.objects FOR SELECT TO authenticated
    USING (bucket_id = 'medical-reports'
           AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Padam: pemilik fail sendiri
DO $$ BEGIN
  CREATE POLICY "medical_delete_own" ON storage.objects FOR DELETE TO authenticated
    USING (bucket_id = 'medical-reports' AND owner = auth.uid());
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

SELECT 'Step 57 OK — medical-reports storage policies ready' AS status;


-- ════════════════════════════════════════════════════════════════
-- step58_library_categories.sql
-- ════════════════════════════════════════════════════════════════

-- ============================================================
-- step58_library_categories.sql
-- Sumber TUNGGAL untuk kategori library (topic).
-- Editor + filter baca dari sini → tukar sekali, semua ikut.
-- psy_library_items.topic = name kategori (text).
-- ============================================================

CREATE TABLE IF NOT EXISTS psy_library_categories (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name        TEXT NOT NULL,
  sort_order  INT DEFAULT 0,
  is_active   BOOLEAN DEFAULT true,
  created_at  TIMESTAMPTZ DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS uq_library_cat_name ON psy_library_categories(lower(name));

-- Seed kategori sedia ada (skip kalau dah ada)
INSERT INTO psy_library_categories (name, sort_order)
SELECT v.name, v.ord FROM (VALUES
  ('Kesihatan Mental',1),('Pemakanan',2),('Kecergasan',3),('Gaya Hidup',4),
  ('Rawatan',5),('Spiritual',6),('Kewangan',7),('Tidur',8),('Lain-lain',99)
) AS v(name, ord)
WHERE NOT EXISTS (SELECT 1 FROM psy_library_categories c WHERE lower(c.name) = lower(v.name));

ALTER TABLE psy_library_categories ENABLE ROW LEVEL SECURITY;

-- Semua boleh baca (untuk dropdown/filter pesakit & staff)
DO $$ BEGIN
  CREATE POLICY "read_categories" ON psy_library_categories FOR SELECT USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Staff urus
DO $$ BEGIN
  CREATE POLICY "staff_categories_all" ON psy_library_categories FOR ALL
    USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
    WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

SELECT 'Step 58 OK — library categories ready' AS status, count(*) AS jumlah FROM psy_library_categories;


-- ════════════════════════════════════════════════════════════════
-- step59_faq_categories.sql
-- ════════════════════════════════════════════════════════════════

-- ============================================================
-- step59_faq_categories.sql
-- Kategori FAQ ADA set tersendiri (berbeza dari kategori kandungan).
-- Tambah kolum `scope` ('content' | 'faq') pada psy_library_categories.
--   content → editor Video/Artikel + filter library
--   faq     → editor FAQ + page Soalan Lazim pesakit
-- ============================================================

ALTER TABLE psy_library_categories
  ADD COLUMN IF NOT EXISTS scope TEXT DEFAULT 'content';

UPDATE psy_library_categories SET scope = 'content' WHERE scope IS NULL;

-- Unik ikut (scope, name) — nama boleh sama merentas scope
DROP INDEX IF EXISTS uq_library_cat_name;
CREATE UNIQUE INDEX IF NOT EXISTS uq_library_cat_scope_name
  ON psy_library_categories(scope, lower(name));

-- Seed 13 kategori FAQ (skip kalau dah ada)
INSERT INTO psy_library_categories (name, scope, sort_order)
SELECT v.name, 'faq', v.ord FROM (VALUES
  ('Pendahuluan Rawatan Overhaul Body',1),
  ('Buku PET',2),
  ('Buku Sains Di Sebalik Overhaul Body',3),
  ('Sistem Perubatan Overhaul Body (Perubatan Herba)',4),
  ('Sistem Perubatan Overhaul Body (Perubatan Alami)',5),
  ('Sistem Perubatan Overhaul Body (Perubatan Minda)',6),
  ('Sistem Perubatan Overhaul Body (Perubatan Rohani)',7),
  ('5 Formula Rawatan Overhaul Body',8),
  ('Fasa Rawatan Overhaul Body (Fasa 1)',9),
  ('Fasa Rawatan Overhaul Body (Fasa 2)',10),
  ('Fasa Rawatan Overhaul Body (Fasa 3)',11),
  ('Diet dan Nutrisi',12),
  ('Laporan Progres Report',13)
) AS v(name, ord)
WHERE NOT EXISTS (
  SELECT 1 FROM psy_library_categories c
  WHERE c.scope = 'faq' AND lower(c.name) = lower(v.name)
);

SELECT 'Step 59 OK — FAQ categories ready' AS status,
       count(*) FILTER (WHERE scope='content') AS content_cats,
       count(*) FILTER (WHERE scope='faq')     AS faq_cats
FROM psy_library_categories;


-- ════════════════════════════════════════════════════════════════
-- step60_medical_records_v2.sql
-- ════════════════════════════════════════════════════════════════

-- ============================================================
-- step60_medical_records_v2.sql
-- Rekod Perubatan v2:
--   • report_type = 5 kategori: laporan | ujian | imaging | rujukan | lain
--   • source (klinik/sumber), file_size (saiz fail untuk ruang simpanan)
--   • psy_medical_report_comments — thread komen doktor (banyak komen/banyak doktor)
-- ============================================================

ALTER TABLE psy_medical_reports
  ADD COLUMN IF NOT EXISTS source    TEXT,
  ADD COLUMN IF NOT EXISTS file_size BIGINT;

-- Thread komen doktor
CREATE TABLE IF NOT EXISTS psy_medical_report_comments (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  report_id   UUID NOT NULL REFERENCES psy_medical_reports(id) ON DELETE CASCADE,
  author_id   UUID,
  author_name TEXT,
  author_role TEXT,
  comment     TEXT NOT NULL,
  created_at  TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_med_comments_report ON psy_medical_report_comments(report_id, created_at);

ALTER TABLE psy_medical_report_comments ENABLE ROW LEVEL SECURITY;

-- Staff (doktor) urus semua komen
DO $$ BEGIN
  CREATE POLICY "staff_comments_all" ON psy_medical_report_comments FOR ALL
    USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
    WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Pesakit baca komen pada laporan sendiri
DO $$ BEGIN
  CREATE POLICY "patient_read_comments" ON psy_medical_report_comments FOR SELECT
    USING (report_id IN (
      SELECT id FROM psy_medical_reports
      WHERE patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid())
    ));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

SELECT 'Step 60 OK — medical records v2 ready' AS status;


-- ════════════════════════════════════════════════════════════════
-- step61_whatsapp_inbox.sql
-- ════════════════════════════════════════════════════════════════

-- ============================================================
-- step61_whatsapp_inbox.sql
-- Cache untuk ISW WhatsApp Inbox (Fasa 2 GHL integration).
-- ISW jadi muka depan; GHL Conversations API jadi sumber sebenar.
-- Edge Function `ghl-inbox` (service role) yang tulis ke jadual ni;
-- staff hanya SELECT (paparan inbox dalam roles/staff/inbox.html).
--
-- Idempotent — selamat jalan berulang.
-- ============================================================

-- ── 1. Perbualan (satu baris per perbualan GHL) ─────────────
CREATE TABLE IF NOT EXISTS psy_wa_conversations (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ghl_conversation_id  TEXT UNIQUE NOT NULL,
  ghl_contact_id       TEXT,
  contact_name         TEXT,
  phone_e164           TEXT,
  wa_number            TEXT,                 -- nombor talian mana mesej masuk
  last_message         TEXT,
  last_message_at      TIMESTAMPTZ,
  unread               INT DEFAULT 0,
  patient_id           UUID REFERENCES psy_patients(id) ON DELETE SET NULL, -- diisi bila phone padan (Fasa +1)
  synced_at            TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_wa_conv_last      ON psy_wa_conversations(last_message_at DESC);
CREATE INDEX IF NOT EXISTS idx_wa_conv_phone     ON psy_wa_conversations(phone_e164);
CREATE INDEX IF NOT EXISTS idx_wa_conv_patient   ON psy_wa_conversations(patient_id);

-- ── 2. Mesej (satu baris per mesej) ─────────────────────────
CREATE TABLE IF NOT EXISTS psy_wa_messages (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ghl_message_id       TEXT UNIQUE,
  ghl_conversation_id  TEXT NOT NULL,
  direction            TEXT,                 -- 'inbound' / 'outbound'
  body                 TEXT,
  msg_type             TEXT DEFAULT 'whatsapp',
  sent_by              UUID,                 -- staff id ISW kalau dihantar dari ISW
  sent_by_name         TEXT,
  created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_wa_msg_conv ON psy_wa_messages(ghl_conversation_id, created_at ASC);

-- ── 3. RLS — staff baca; tulis hanya via service role (Edge Fn) ──
ALTER TABLE psy_wa_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE psy_wa_messages      ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "staff_wa_conv_read" ON psy_wa_conversations FOR SELECT
    USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "staff_wa_msg_read" ON psy_wa_messages FOR SELECT
    USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- (Tiada policy INSERT/UPDATE untuk client — service role bypass RLS,
--  jadi Edge Function ghl-inbox sahaja yang boleh tulis.)

SELECT 'Step 61 OK — WhatsApp inbox cache ready' AS status;


-- ════════════════════════════════════════════════════════════════
-- step62_whatsapp_realtime.sql
-- ════════════════════════════════════════════════════════════════

-- ============================================================
-- step62_whatsapp_realtime.sql
-- Fasa +2 — aktifkan Supabase Realtime untuk WhatsApp Inbox
-- supaya mesej baru muncul sendiri + badge unread live.
--
-- Realtime hantar event INSERT/UPDATE ke client yang subscribe
-- (RLS tetap dikuatkuasakan — staff sahaja baca, lihat step61).
--
-- Idempotent — selamat jalan berulang.
-- ============================================================

DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE psy_wa_messages;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE psy_wa_conversations;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- REPLICA IDENTITY FULL supaya payload UPDATE bawa nilai lama (untuk kira unread)
ALTER TABLE psy_wa_messages      REPLICA IDENTITY FULL;
ALTER TABLE psy_wa_conversations REPLICA IDENTITY FULL;

SELECT 'Step 62 OK — WhatsApp realtime enabled' AS status;


-- ════════════════════════════════════════════════════════════════
-- step63_wa_outbox_storage.sql
-- ════════════════════════════════════════════════════════════════

-- ============================================================
-- step63_wa_outbox_storage.sql
-- Fasa +3 — bucket storage untuk media yang coach HANTAR dari ISW.
-- Fail di-upload ke bucket awam 'wa-outbox', URL awam dihantar ke
-- GHL (GHL muat turun & hantar ke WhatsApp pesakit).
--
-- Idempotent — selamat jalan berulang.
-- ============================================================

-- 1. Bucket awam (URL boleh diakses GHL untuk muat turun)
INSERT INTO storage.buckets (id, name, public)
VALUES ('wa-outbox', 'wa-outbox', true)
ON CONFLICT (id) DO UPDATE SET public = true;

-- 2. Staff boleh upload
DO $$ BEGIN
  CREATE POLICY "wa_outbox_staff_insert" ON storage.objects FOR INSERT
    WITH CHECK (
      bucket_id = 'wa-outbox'
      AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff')
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- 3. Baca awam (bucket public — GHL & browser boleh akses URL)
DO $$ BEGIN
  CREATE POLICY "wa_outbox_public_read" ON storage.objects FOR SELECT
    USING (bucket_id = 'wa-outbox');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- 4. Staff boleh padam fail sendiri (kemas kalau perlu)
DO $$ BEGIN
  CREATE POLICY "wa_outbox_staff_delete" ON storage.objects FOR DELETE
    USING (
      bucket_id = 'wa-outbox'
      AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff')
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

SELECT 'Step 63 OK — wa-outbox storage ready' AS status;


-- ════════════════════════════════════════════════════════════════
-- step64_kepatuhan.sql
-- ════════════════════════════════════════════════════════════════

-- ============================================================
-- step64_kepatuhan.sql
-- Modul Kepatuhan — ganti Google Form checklist amalan harian.
-- Pesakit isi HARIAN dalam app; kelas A/B/C dikira MINGGUAN.
--
-- Reka bentuk (disahkan user 9 Jun 2026):
--   1. Item checklist BEZA ikut fasa  -> psy_kepatuhan_item (config)
--   2. Pesakit isi 1 baris / hari      -> psy_kepatuhan_log
--   3. Skor A/B/C dikira mingguan      -> psy_kepatuhan_weekly (auto, coach override)
--
-- Kadar (period) per item: harian / mingguan / bulanan.
-- Kelas: A >= 85%, B 50-84%, C < 50%  (cutoff lalai; coach boleh ubah kelak).
--
-- Kod fasa: 'week1', 'week2_4', 'week5_12', 'fasa2', 'fasa3'.
--
-- Idempotent — selamat jalan berulang.
-- ============================================================

-- ============================================================
-- 1. CONFIG — soalan checklist per fasa (coach boleh edit)
-- ============================================================
CREATE TABLE IF NOT EXISTS psy_kepatuhan_item (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  fasa        TEXT NOT NULL CHECK (fasa IN ('week1','week2_4','week5_12','fasa2','fasa3')),
  item_key    TEXT NOT NULL,
  label       TEXT NOT NULL,
  nota        TEXT,                       -- keterangan (cth singkatan LTH/IB)
  jenis_input TEXT NOT NULL DEFAULT 'pilih_satu'
              CHECK (jenis_input IN ('kiraan','pilih_satu','pilih_banyak')),
  period      TEXT NOT NULL DEFAULT 'harian'
              CHECK (period IN ('harian','mingguan','bulanan')),
  options     JSONB NOT NULL DEFAULT '[]', -- [{value,label,mata}] ; 'mata' = markah (0/1/2)
  meta        JSONB NOT NULL DEFAULT '{}', -- cth {"target":3} utk item kiraan (madu)
  berskor     BOOLEAN NOT NULL DEFAULT true, -- false = tracking sahaja (reaksi pemulihan)
  urutan      INT NOT NULL DEFAULT 0,
  aktif       BOOLEAN NOT NULL DEFAULT true,
  created_at  TIMESTAMPTZ DEFAULT now(),
  updated_at  TIMESTAMPTZ DEFAULT now(),
  UNIQUE (fasa, item_key)
);

ALTER TABLE psy_kepatuhan_item ENABLE ROW LEVEL SECURITY;
-- Staff/coach urus penuh config
DO $$ BEGIN
  CREATE POLICY "kepatuhan_item_staff_all" ON psy_kepatuhan_item FOR ALL
    USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
    WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
-- Pesakit baca sahaja (untuk render borang harian)
DO $$ BEGIN
  CREATE POLICY "kepatuhan_item_patient_read" ON psy_kepatuhan_item FOR SELECT
    USING (aktif = true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE INDEX IF NOT EXISTS idx_kepatuhan_item_fasa ON psy_kepatuhan_item(fasa, urutan);

-- ============================================================
-- 2. LOG — jawapan pesakit, 1 baris / hari
-- ============================================================
CREATE TABLE IF NOT EXISTS psy_kepatuhan_log (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id  UUID REFERENCES psy_patients(id) ON DELETE CASCADE NOT NULL,
  log_date    DATE NOT NULL DEFAULT CURRENT_DATE,
  fasa        TEXT NOT NULL CHECK (fasa IN ('week1','week2_4','week5_12','fasa2','fasa3')),
  jawapan     JSONB NOT NULL DEFAULT '{}', -- {item_key: value | [values]}
  skor_harian NUMERIC(5,2),                -- % markah hari itu (item berskor sahaja)
  created_at  TIMESTAMPTZ DEFAULT now(),
  updated_at  TIMESTAMPTZ DEFAULT now(),
  UNIQUE (patient_id, log_date)
);

ALTER TABLE psy_kepatuhan_log ENABLE ROW LEVEL SECURITY;
-- Pesakit urus log sendiri
DO $$ BEGIN
  CREATE POLICY "kepatuhan_log_patient_all" ON psy_kepatuhan_log FOR ALL
    USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()))
    WITH CHECK (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
-- Staff/coach baca semua
DO $$ BEGIN
  CREATE POLICY "kepatuhan_log_staff_read" ON psy_kepatuhan_log FOR SELECT
    USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE INDEX IF NOT EXISTS idx_kepatuhan_log_patient ON psy_kepatuhan_log(patient_id, log_date);

-- ============================================================
-- 3. WEEKLY — kelas A/B/C dikira mingguan (auto + coach override)
-- ============================================================
CREATE TABLE IF NOT EXISTS psy_kepatuhan_weekly (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id    UUID REFERENCES psy_patients(id) ON DELETE CASCADE NOT NULL,
  minggu_mula   DATE NOT NULL,             -- tarikh Isnin minggu berkenaan
  fasa          TEXT,
  skor          NUMERIC(5,2),              -- % mingguan (purata item berskor)
  bil_hari_isi  INT DEFAULT 0,             -- berapa hari pesakit isi minggu itu
  kelas         CHAR(1) CHECK (kelas IN ('A','B','C')),       -- auto
  override_kelas CHAR(1) CHECK (override_kelas IN ('A','B','C')), -- coach pinda
  override_by   UUID REFERENCES psy_profiles(id),
  override_at   TIMESTAMPTZ,
  nota_coach    TEXT,
  created_at    TIMESTAMPTZ DEFAULT now(),
  updated_at    TIMESTAMPTZ DEFAULT now(),
  UNIQUE (patient_id, minggu_mula)
);

ALTER TABLE psy_kepatuhan_weekly ENABLE ROW LEVEL SECURITY;
-- Pesakit baca kelas sendiri
DO $$ BEGIN
  CREATE POLICY "kepatuhan_weekly_patient_read" ON psy_kepatuhan_weekly FOR SELECT
    USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
-- Staff/coach urus penuh (kira auto + override)
DO $$ BEGIN
  CREATE POLICY "kepatuhan_weekly_staff_all" ON psy_kepatuhan_weekly FOR ALL
    USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
    WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE INDEX IF NOT EXISTS idx_kepatuhan_weekly_patient ON psy_kepatuhan_weekly(patient_id, minggu_mula);

-- ============================================================
-- 4. SEED — item checklist WEEK 1 (10 item; 9 berskor + reaksi tracking)
--    Markah: penuh=2, separa=1, tidak=0.
--    Item kiraan (madu): meta.target = bil "cukup" (Week 1 = 3x, ubah kelak).
-- ============================================================
INSERT INTO psy_kepatuhan_item (fasa, item_key, label, nota, jenis_input, period, options, meta, berskor, urutan) VALUES
('week1','madu_lth_ib','Minum Madu (LTH / IB)','LTH: Lote Tree Honey · IB: Immune Booster Honey','kiraan','harian',
 '[{"value":"2","label":"2x","mata":1},{"value":"3","label":"3x","mata":2},{"value":"4","label":"4x","mata":2},{"value":"5","label":"5x","mata":2},{"value":"other","label":"Other","mata":1}]',
 '{"target":3}', true, 1),

('week1','madu_lthpg_yhpg','Minum Madu (LTHPG / YHPG)','LTHPG: Lote Tree Honey Pearl Garlic · YHPG: Young & Healthy Pearl Garlic','kiraan','harian',
 '[{"value":"2","label":"2x","mata":1},{"value":"3","label":"3x","mata":2},{"value":"4","label":"4x","mata":2},{"value":"5","label":"5x","mata":2},{"value":"other","label":"Other","mata":1}]',
 '{"target":3}', true, 2),

('week1','pernafasan_fitrah','Pernafasan Fitrah 30 Minit',NULL,'pilih_satu','harian',
 '[{"value":"cukup_30","label":"Cukup 30 minit","mata":2},{"value":"10_20","label":"10-20 minit","mata":1},{"value":"bawah_10","label":"Kurang dari 10 minit","mata":0}]',
 '{}', true, 3),

('week1','zikir_bersanad','Zikir Bersanad Subuh & Maghrib',NULL,'pilih_satu','harian',
 '[{"value":"subuh_maghrib","label":"Buat waktu Subuh & Maghrib","mata":2},{"value":"subuh","label":"Hanya waktu Subuh","mata":1},{"value":"maghrib","label":"Hanya waktu Maghrib","mata":1},{"value":"tidak","label":"Tidak buat","mata":0}]',
 '{}', true, 4),

('week1','terapi_bumi','Terapi Bumi',NULL,'pilih_satu','harian',
 '[{"value":"20_30","label":"20-30 minit","mata":2},{"value":"10_20","label":"10-20 minit","mata":1},{"value":"tidak","label":"Tidak buat","mata":0}]',
 '{}', true, 5),

('week1','berjemur','Berjemur Matahari',NULL,'pilih_satu','harian',
 '[{"value":"20_30","label":"20-30 minit","mata":2},{"value":"10_20","label":"10-20 minit","mata":1},{"value":"tidak","label":"Tidak buat","mata":0},{"value":"other","label":"Other","mata":1}]',
 '{}', true, 6),

('week1','air_kelapa','Air Kelapa',NULL,'pilih_satu','harian',
 '[{"value":"minum","label":"Minum","mata":2},{"value":"tidak","label":"Tidak minum","mata":0}]',
 '{}', true, 7),

('week1','yogurt','Yogurt',NULL,'pilih_satu','harian',
 '[{"value":"ambil","label":"Ambil","mata":2},{"value":"tidak","label":"Tidak ambil","mata":0}]',
 '{}', true, 8),

('week1','pantang_makan','Pantang Makan',NULL,'pilih_satu','harian',
 '[{"value":"baik","label":"Menjaga pantang dengan baik","mata":2},{"value":"separa","label":"Pantang tapi tak sepenuhnya","mata":1},{"value":"tidak","label":"Tidak menjaga pantang","mata":0}]',
 '{}', true, 9),

('week1','reaksi_pemulihan','Reaksi Pemulihan','Tracking sahaja — tidak dikira dalam skor','pilih_banyak','harian',
 '[{"value":"kerap_kencing","label":"Kerap Kencing"},{"value":"kerap_bab","label":"Kerap Buang Air Besar"},{"value":"gatal","label":"Gatal"},{"value":"selera","label":"Berubah selera makan"},{"value":"bp_naik","label":"Tekanan darah naik"},{"value":"bp_turun","label":"Tekanan darah turun"},{"value":"haid","label":"Haid banyak"},{"value":"kembung","label":"Perut berangin atau kembung"},{"value":"sakit_kepala","label":"Sakit kepala"},{"value":"resdung","label":"Resdung"},{"value":"mencucuk","label":"Rasa sakit mencucuk"},{"value":"radang","label":"Radang, bengkak, kebas, sakit urat"},{"value":"sakit_dada","label":"Sakit dada atau susah bernafas"},{"value":"demam","label":"Demam"},{"value":"lemah","label":"Lemah"},{"value":"mengantuk","label":"Mengantuk"},{"value":"batuk","label":"Batuk atau berkahak"},{"value":"tiada","label":"Tiada"}]',
 '{}', false, 10)

ON CONFLICT (fasa, item_key) DO UPDATE SET
  label       = EXCLUDED.label,
  nota        = EXCLUDED.nota,
  jenis_input = EXCLUDED.jenis_input,
  period      = EXCLUDED.period,
  options     = EXCLUDED.options,
  meta        = EXCLUDED.meta,
  berskor     = EXCLUDED.berskor,
  urutan      = EXCLUDED.urutan,
  updated_at  = now();

SELECT 'Step 64 OK — modul kepatuhan (item config + log + weekly) sedia; Week 1 di-seed' AS status;


-- ════════════════════════════════════════════════════════════════
-- step65_checkin_detail.sql
-- ════════════════════════════════════════════════════════════════

-- ============================================================
-- step65_checkin_detail.sql
-- Perkayakan Daily Check-in (digabung dalam Catatan Harian):
--   - emosi (5 domain), reaksi pemulihan terperinci, masa tidur/bangun,
--     tahap gangguan aktiviti harian.
-- Reaksi pemulihan dipindah ke check-in → nyahaktif item dalam checklist amalan.
--
-- Idempotent.
-- ============================================================

ALTER TABLE psy_daily_checkins
  ADD COLUMN IF NOT EXISTS emotions       JSONB DEFAULT '[]',   -- senarai emosi dipilih
  ADD COLUMN IF NOT EXISTS sleep_time     TEXT,                 -- tidur pukul (HH:MM)
  ADD COLUMN IF NOT EXISTS wake_time      TEXT,                 -- bangun pukul (HH:MM)
  ADD COLUMN IF NOT EXISTS activity_level TEXT;                 -- tahap gangguan aktiviti

-- Reaksi pemulihan kini di bahagian Daily Check-in (lebih terperinci, berkumpulan)
-- → nyahaktif item ringkas dalam checklist amalan supaya tidak bertindih.
UPDATE psy_kepatuhan_item SET aktif = false WHERE item_key = 'reaksi_pemulihan';

SELECT 'Step 65 OK — daily check-in detail fields ready; reaksi checklist dinyahaktifkan' AS status;


-- ════════════════════════════════════════════════════════════════
-- step66_patient_dedup.sql
-- ════════════════════════════════════════════════════════════════

-- ============================================================
-- step66_patient_dedup.sql
-- Cegah & bersihkan rekod pesakit BERGANDA (duplicate).
--
-- Punca: stub staff (created_by_staff, user_id NULL) + rekod auto-cipta
--   semasa signup boleh berkongsi user_id / No.KP yang SAMA apabila
--   padanan email gagal. Contoh: P-002 & P-017 (Sh Noraimiza).
--
-- Pencegahan di aplikasi sudah ditambah:
--   • patients.html savePatient()  → halang cipta jika No.KP sudah wujud
--   • patients.html autoLinkStaffPatients() → langkau link jika user_id
--     sudah dipegang rekod lain
--   • assignments.html → chip "KYC Cleared ⚠" tanda rekod tak sync
--
-- Migration ini = jaring keselamatan peringkat DATA.
-- ⚠️ JALANKAN MENGIKUT TURUTAN. Semak output BAHAGIAN 1 sebelum
--    nyahkomen BAHAGIAN 2 & 3.
-- Idempotent.
-- ============================================================


-- ============================================================
-- BAHAGIAN 1 — DIAGNOSTIK  (SELAMAT — hanya SELECT, tiada ubah data)
-- Jalankan dahulu. Lihat berapa banyak duplicate sebenar.
-- ============================================================

-- 1a. user_id dengan >1 rekod aktif (duplicate kongsi akaun)
SELECT user_id,
       count(*)                                   AS bil,
       array_agg(mrn    ORDER BY created_at)       AS mrn_list,
       array_agg(status ORDER BY created_at)       AS status_list
FROM   psy_patients
WHERE  user_id IS NOT NULL
  AND  status NOT IN ('deleted','archived')
GROUP  BY user_id
HAVING count(*) > 1;

-- 1b. No.KP dengan >1 rekod aktif
SELECT ic_number,
       count(*)                              AS bil,
       array_agg(mrn ORDER BY created_at)     AS mrn_list,
       array_agg(status ORDER BY created_at)  AS status_list
FROM   psy_patients
WHERE  ic_number IS NOT NULL
  AND  status NOT IN ('deleted','archived')
GROUP  BY ic_number
HAVING count(*) > 1;


-- ============================================================
-- BAHAGIAN 2 — PEMBERSIHAN  (⚠️ UBAH DATA — nyahkomen selepas semak Bhg 1)
--
-- Bagi setiap user_id berganda, SIMPAN satu rekod terbaik dan
-- ARKIB (status='archived') yang lain. Keutamaan simpan:
--   1) status = 'active'         (sudah lulus KYC / dalam rawatan)
--   2) ada pakej (active_package_id)
--   3) paling baharu (created_at)
--
-- 'archived' BUKAN padam — masih boleh dipulihkan dari senarai pesakit.
-- ============================================================

-- WITH ranked AS (
--   SELECT id,
--          row_number() OVER (
--            PARTITION BY user_id
--            ORDER BY (status = 'active')            DESC,
--                     (active_package_id IS NOT NULL) DESC,
--                     created_at                      DESC
--          ) AS rn
--   FROM   psy_patients
--   WHERE  user_id IS NOT NULL
--     AND  status NOT IN ('deleted','archived')
-- )
-- UPDATE psy_patients p
-- SET    status = 'archived'
-- FROM   ranked r
-- WHERE  p.id = r.id
--   AND  r.rn > 1;

-- (Pilihan) Stub staff TANPA user_id yang No.KP-nya bertindih dengan
-- rekod aktif lain — arkib juga. Semak dahulu di Bhg 1b.
-- UPDATE psy_patients s
-- SET    status = 'archived'
-- WHERE  s.user_id IS NULL
--   AND  s.created_by_staff = true
--   AND  s.status NOT IN ('deleted','archived')
--   AND  EXISTS (
--          SELECT 1 FROM psy_patients o
--          WHERE  o.ic_number = s.ic_number
--            AND  o.id <> s.id
--            AND  o.user_id IS NOT NULL
--            AND  o.status NOT IN ('deleted','archived')
--        );


-- ============================================================
-- BAHAGIAN 3 — UNIQUE INDEX  (jalankan SELEPAS Bhg 2 bersih)
-- Jaminan kukuh: tiada lagi dua rekod LIVE kongsi user_id / No.KP.
-- Index ini akan GAGAL dicipta jika masih ada duplicate live —
-- itu petanda Bhg 2 belum selesai (semak semula Bhg 1).
-- ============================================================

-- CREATE UNIQUE INDEX IF NOT EXISTS uq_patient_user_live
--   ON psy_patients (user_id)
--   WHERE user_id IS NOT NULL AND status NOT IN ('deleted','archived');

-- CREATE UNIQUE INDEX IF NOT EXISTS uq_patient_ic_live
--   ON psy_patients (ic_number)
--   WHERE ic_number IS NOT NULL AND status NOT IN ('deleted','archived');


SELECT 'Step 66 — semak BAHAGIAN 1 dahulu, kemudian nyahkomen BAHAGIAN 2 & 3' AS status;


-- ════════════════════════════════════════════════════════════════
-- step67_staff_sign_agreement_policy.sql
-- ════════════════════════════════════════════════════════════════
-- Benarkan staff (doktor) sign agreement bagi pihak patient
-- semasa sesi KOB inline (kob-detail.html).
-- ============================================================

-- Staff boleh INSERT ke psy_kob_agreements (sign inline semasa KOB)
DO $$ BEGIN
  CREATE POLICY "Staff insert agreement on behalf of patient"
    ON psy_kob_agreements FOR INSERT
    WITH CHECK (
      EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff')
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Staff juga boleh UPDATE agreement (e.g., tambah signed_pdf_url selepas generate PDF)
DO $$ BEGIN
  CREATE POLICY "Staff update agreement"
    ON psy_kob_agreements FOR UPDATE
    USING (
      EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff')
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

SELECT 'Step 67 OK — staff can sign KOB agreement inline' AS status;


-- ════════════════════════════════════════════════════════════════
-- step_patients_created_by_staff.sql
-- ════════════════════════════════════════════════════════════════

-- ============================================================
-- STEP — Add psy_patients.created_by_staff
-- Column ini digunakan dalam kod (patients.html) untuk flag pesakit
-- yang didaftarkan oleh staff (bypass KOB flow), tapi belum dicipta
-- dalam schema. Tambah sekarang.
-- ============================================================

ALTER TABLE psy_patients
  ADD COLUMN IF NOT EXISTS created_by_staff BOOLEAN DEFAULT false;

COMMENT ON COLUMN psy_patients.created_by_staff IS
  'TRUE = pesakit didaftarkan oleh staff (bukan self-signup). Akan bypass KOB flow (kob_status=na) dan tunggu auto-link bila pesakit signup sendiri guna IC sama.';

-- Backfill: existing patients dengan user_id (self-registered) → false
-- Tanpa user_id (likely staff-created) → true
UPDATE psy_patients
SET created_by_staff = (user_id IS NULL)
WHERE created_by_staff IS NULL OR created_by_staff = false;

-- Index untuk auto-link query (cari unlinked staff-created patients ikut IC)
CREATE INDEX IF NOT EXISTS idx_psy_patients_created_by_staff
  ON psy_patients(created_by_staff)
  WHERE created_by_staff = true AND user_id IS NULL;

-- Verifikasi
SELECT
  COUNT(*) FILTER (WHERE created_by_staff = true) AS staff_created,
  COUNT(*) FILTER (WHERE created_by_staff = false) AS self_registered,
  COUNT(*) AS total
FROM psy_patients;

SELECT 'OK — created_by_staff column ready' AS status;


-- ════════════════════════════════════════════════════════════════
-- step_patients_missing_columns.sql
-- ════════════════════════════════════════════════════════════════

-- ============================================================
-- STEP — psy_patients missing columns (full audit)
-- Cover semua field yang patients.html (Tambah/Edit Pesakit) hantar
-- tapi tidak wujud dalam schema asal psy_patients.
-- ============================================================

-- ── 1. Tambah column yang missing ──────────────────────────
ALTER TABLE psy_patients
  ADD COLUMN IF NOT EXISTS full_name                       TEXT,
  ADD COLUMN IF NOT EXISTS phone                           TEXT,
  ADD COLUMN IF NOT EXISTS emergency_contact_email         TEXT,
  ADD COLUMN IF NOT EXISTS emergency_contact_relationship  TEXT;

-- ── 2. Comments untuk dokumentasi ──────────────────────────
COMMENT ON COLUMN psy_patients.full_name IS
  'Nama pesakit. Bila ada user_id, biasanya match dgn psy_profiles.full_name. Snapshot untuk staff-created tanpa user_id.';
COMMENT ON COLUMN psy_patients.phone IS
  'Nombor telefon utama pesakit. Boleh berbeza dari psy_profiles.phone (cth: kalau staff tukar di sini).';
COMMENT ON COLUMN psy_patients.emergency_contact_email IS
  'Email kenalan kecemasan / waris.';
COMMENT ON COLUMN psy_patients.emergency_contact_relationship IS
  'Hubungan waris dengan pesakit (Suami, Isteri, Ibu, Bapa, Anak, dll).';

-- ── 3. Backfill: salin nama + phone dari profile (untuk patient yang ada user_id) ──
UPDATE psy_patients p
SET full_name = COALESCE(p.full_name, pr.full_name),
    phone     = COALESCE(p.phone,     pr.phone)
FROM psy_profiles pr
WHERE p.user_id = pr.id
  AND (p.full_name IS NULL OR p.phone IS NULL);

-- ── 4. Index untuk search ──────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_psy_patients_full_name ON psy_patients(full_name);
CREATE INDEX IF NOT EXISTS idx_psy_patients_phone     ON psy_patients(phone);

-- ── 5. Verification — semua column yang patients.html guna ──
DO $$
DECLARE
  required_cols TEXT[] := ARRAY[
    'full_name','phone','email',
    'ic_number','date_of_birth','gender','marital_status',
    'address','home_address','city','state',
    'occupation','company','referral_source',
    'medical_condition','condition_duration','medical_notes',
    'emergency_contact_name','emergency_contact_phone',
    'emergency_contact_ic','emergency_contact_relationship','emergency_contact_email',
    'active_package_id','active_package_name','package_purchased_at','package_expires_at',
    'reference_code','documents',
    'status','kob_status','outcome_status','outcome_status_at','outcome_status_notes',
    'coach_id','assigned_at','created_by_staff','user_id','mrn'
  ];
  missing_cols TEXT[] := '{}';
  col TEXT;
BEGIN
  FOREACH col IN ARRAY required_cols LOOP
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_name = 'psy_patients' AND column_name = col
    ) THEN
      missing_cols := array_append(missing_cols, col);
    END IF;
  END LOOP;

  IF array_length(missing_cols, 1) > 0 THEN
    RAISE NOTICE 'MASIH MISSING: %', missing_cols;
  ELSE
    RAISE NOTICE 'OK — semua column patients.html sudah ada dalam schema';
  END IF;
END $$;

SELECT 'OK — psy_patients missing columns added + verified' AS status;

-- ── 6. Diagnostic ──────────────────────────────────────────
SELECT
  COUNT(*) FILTER (WHERE full_name IS NOT NULL) AS ada_nama,
  COUNT(*) FILTER (WHERE phone IS NOT NULL)     AS ada_phone,
  COUNT(*) FILTER (WHERE user_id IS NOT NULL)   AS ada_user_id,
  COUNT(*) FILTER (WHERE created_by_staff)      AS staff_created,
  COUNT(*) AS total
FROM psy_patients;


-- ════════════════════════════════════════════════════════════════
-- step_profile_personal_fields.sql
-- ════════════════════════════════════════════════════════════════

-- ============================================================
-- STEP — Profile Personal Fields
-- Tambah maklumat peribadi staff (tarikh lahir, jantina, bahasa,
-- status perkahwinan, jabatan) untuk halaman profil yang lebih
-- lengkap.
-- ============================================================

ALTER TABLE psy_profiles
  ADD COLUMN IF NOT EXISTS birth_date     DATE,
  ADD COLUMN IF NOT EXISTS gender         TEXT CHECK (gender IN ('lelaki','perempuan')),
  ADD COLUMN IF NOT EXISTS language       TEXT,
  ADD COLUMN IF NOT EXISTS marital_status TEXT CHECK (marital_status IN ('bujang','berkahwin','bercerai','duda','janda')),
  ADD COLUMN IF NOT EXISTS department     TEXT;

COMMENT ON COLUMN psy_profiles.birth_date     IS 'Tarikh lahir staff (untuk paparan profil)';
COMMENT ON COLUMN psy_profiles.gender         IS 'Jantina: lelaki / perempuan';
COMMENT ON COLUMN psy_profiles.language       IS 'Bahasa utama yang digunakan';
COMMENT ON COLUMN psy_profiles.marital_status IS 'Status perkahwinan staff';
COMMENT ON COLUMN psy_profiles.department     IS 'Jabatan / Unit kerja';

SELECT 'OK — psy_profiles personal fields added' AS status;


-- ════════════════════════════════════════════════════════════════
-- step_add_patients_updated_at.sql
-- ════════════════════════════════════════════════════════════════

-- ============================================================
-- step_add_patients_updated_at.sql  (idempotent)
-- Tambah kolum updated_at pada psy_patients + trigger auto-update.
-- Punca: borang "Edit Profil Pesakit" (patient-hub.html saveProfileEdit)
--        & dashboard.html menulis/baca updated_at, tetapi kolum tiada
--        -> ralat "Could not find the 'updated_at' column ... in schema cache".
-- ============================================================

-- ── 1. Kolum updated_at ────────────────────────────────────
ALTER TABLE psy_patients
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now();

-- Isi nilai awal untuk rekod sedia ada (guna created_at jika ada)
UPDATE psy_patients
  SET updated_at = COALESCE(updated_at, created_at, now())
  WHERE updated_at IS NULL;

COMMENT ON COLUMN psy_patients.updated_at IS
  'Masa kemaskini terakhir rekod pesakit (auto dari trigger).';

-- ── 2. Trigger auto-update updated_at ──────────────────────
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

SELECT 'OK — psy_patients.updated_at + trigger ready' AS status;


-- ════════════════════════════════════════════════════════════════
-- step_sessions_per_week.sql
-- ════════════════════════════════════════════════════════════════

-- ============================================================
-- STEP — Sessions Per Week (per-pakej configuration)
-- Sokong pakej yang ada variasi sesi/minggu:
--   • OB/NLC = 2 sesi/minggu (Jum+Sab atau Sab+Ahd)
--   • OBG    = 1 sesi/minggu
--   • 777    = per-hari (guna duration_unit='day' yang sedia ada)
--
-- BACKWARD COMPAT: Sistem sudah ada `preferred_pair` (fri_sat|sat_sun),
-- `preferred_time_day1/2`, dan `session_day` (1|2) untuk handle 2 sesi.
-- Migration ni TAMBAH lapisan KONFIGURASI PER-PAKEJ supaya tidak hardcoded
-- pada 2 pilihan sahaja, dan boleh extend kepada 1 sesi/minggu.
-- ============================================================

-- ── psy_packages: konfigurasi pakej ─────────────────
ALTER TABLE psy_packages
  ADD COLUMN IF NOT EXISTS sessions_per_week INT DEFAULT 1
    CHECK (sessions_per_week BETWEEN 1 AND 7),
  ADD COLUMN IF NOT EXISTS session_days_options JSONB DEFAULT '[]';

COMMENT ON COLUMN psy_packages.sessions_per_week IS
  'Bilangan sesi seminggu untuk pakej ini. 1 = sekali (OBG), 2 = dua kali (OB/NLC). Pakej per-hari (777) guna duration_unit=day, biarkan field ini = 1.';

COMMENT ON COLUMN psy_packages.session_days_options IS
  'Pilihan variant hari sesi yang patient boleh pilih. Format: array of array of int (1=Mon, 7=Sun). Cth OB: [[5,6],[6,7]] = pilihan Jum+Sab ATAU Sab+Ahd. OBG: [[6]] = Sabtu sahaja.';

-- ── Existing columns (untuk rujukan, tak diubah): ──
-- psy_treatment_plans.preferred_pair       — 'fri_sat' atau 'sat_sun' (hardcoded, masih kekal)
-- psy_treatment_plans.preferred_time_day1  — masa sesi hari pertama
-- psy_treatment_plans.preferred_time_day2  — masa sesi hari kedua (NULL kalau 1 sesi/minggu)
-- psy_treatment_plans.schedule_setup_at    — bila setup siap
-- psy_plan_weekly_progress.session_day     — 1 atau 2 (sesi pertama/kedua minggu tu)
--
-- Bila migrate untuk extend lebih dari 2 pasangan (mis: Isn+Kha), boleh
-- ubah CHECK constraint pada `preferred_pair` jadi text bebas atau remove
-- check tu. Buat masa ni biar existing constraint kekal — tambah variant
-- baru dalam pakej `session_days_options` dan handle di UI/JS.

-- ── Verification ────────────────────────────────────
SELECT 'OK — sessions_per_week schema ready (build on existing preferred_pair/session_day)' AS status;

-- Senarai pakej sedia ada (untuk admin set sessions_per_week)
SELECT id, package_id, name, duration_unit, sessions_per_week, session_days_options
FROM psy_packages
ORDER BY name;


-- ════════════════════════════════════════════════════════════════
-- step_adherence_alerts.sql
-- ════════════════════════════════════════════════════════════════

-- ============================================================
-- step_adherence_alerts.sql
-- Track patient adherence alerts (madu, dll).
-- Coach dapat notif bila patient kurang madu 4+ hari berturut.
-- ============================================================

CREATE TABLE IF NOT EXISTS psy_adherence_alerts (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id    UUID REFERENCES psy_patients(id) ON DELETE CASCADE NOT NULL,
  alert_type    TEXT NOT NULL,             -- 'madu_low_5days' / 'madu_low_4days'
  trigger_date  DATE NOT NULL,             -- tarikh alert dikira
  details       JSONB DEFAULT '{}',        -- snapshot: { target, days_below: [...], counts: {} }
  notified_coach_id UUID REFERENCES psy_profiles(id),
  acknowledged_by   UUID REFERENCES psy_profiles(id),
  acknowledged_at   TIMESTAMPTZ,
  created_at    TIMESTAMPTZ DEFAULT now(),
  UNIQUE (patient_id, alert_type, trigger_date)  -- elak duplicate sehari
);

CREATE INDEX IF NOT EXISTS idx_adherence_patient ON psy_adherence_alerts(patient_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_adherence_unack   ON psy_adherence_alerts(acknowledged_at) WHERE acknowledged_at IS NULL;

ALTER TABLE psy_adherence_alerts ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "Patient read own adherence" ON psy_adherence_alerts
    FOR SELECT USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "Staff read all adherence" ON psy_adherence_alerts
    FOR SELECT USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "Staff manage adherence" ON psy_adherence_alerts
    FOR ALL USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
    WITH CHECK (auth.uid() IS NOT NULL);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Patient pun boleh insert (sebab patient dashboard akan trigger check)
DO $$ BEGIN
  CREATE POLICY "Patient insert own adherence" ON psy_adherence_alerts
    FOR INSERT WITH CHECK (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;


-- ════════════════════════════════════════════════════════════════
-- step_bottle_returns.sql
-- ════════════════════════════════════════════════════════════════

-- ============================================================
-- step_bottle_returns.sql
-- Sistem pulangan botol madu untuk patient.
-- ============================================================

CREATE TABLE IF NOT EXISTS psy_bottle_returns (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id           UUID REFERENCES psy_patients(id) ON DELETE CASCADE NOT NULL,
  patient_name         TEXT NOT NULL,
  qty                  INT NOT NULL CHECK (qty > 0),
  photo_urls           TEXT[] DEFAULT '{}',
  criteria_confirmed   JSONB NOT NULL DEFAULT '{}',
  notes                TEXT,
  status               TEXT NOT NULL DEFAULT 'pending'
                       CHECK (status IN ('pending','received','rejected')),
  reject_reason        TEXT,
  verified_by          UUID REFERENCES psy_profiles(id),
  verified_by_name     TEXT,
  verified_at          TIMESTAMPTZ,
  created_at           TIMESTAMPTZ DEFAULT now(),
  updated_at           TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_bottle_returns_patient ON psy_bottle_returns(patient_id);
CREATE INDEX IF NOT EXISTS idx_bottle_returns_status  ON psy_bottle_returns(status, created_at DESC);

ALTER TABLE psy_bottle_returns ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "Patient manage own returns" ON psy_bottle_returns
    FOR ALL USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()))
    WITH CHECK (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "Staff read all returns" ON psy_bottle_returns
    FOR SELECT USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "Staff update returns" ON psy_bottle_returns
    FOR UPDATE USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

COMMENT ON TABLE psy_bottle_returns IS
  'Permohonan pulangan botol madu patient. Chat thread guna psy_audit_log dengan meta.return_id.';
COMMENT ON COLUMN psy_bottle_returns.criteria_confirmed IS
  'JSONB: {tidak_berkarat, bersih, getah_ada, besi_kemas} - semua mesti true sebelum patient boleh submit.';
COMMENT ON COLUMN psy_bottle_returns.photo_urls IS
  'Array URL foto bukti botol (boleh upload multiple).';

-- Storage bucket untuk photos (manual setup di Supabase Dashboard atau via SQL kalau extension dah enable)
-- Bucket name: 'bottle-returns', public read, authenticated insert


-- ════════════════════════════════════════════════════════════════
-- step_coaching_catalog.sql
-- ════════════════════════════════════════════════════════════════

-- ============================================================
-- step_coaching_catalog.sql
-- Master catalog untuk Bimbingan/Calling & Aktiviti/Rawatan.
-- Admin CRUD via dedicated page. Pakej-edit pakai picker.
-- ============================================================

CREATE TABLE IF NOT EXISTS psy_coaching_catalog (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name          TEXT NOT NULL,
  type          TEXT NOT NULL CHECK (type IN ('bimbingan','aktiviti')),
  description   TEXT,
  category      TEXT,             -- optional grouping (cth: 'Bimbingan Reaksi', 'Herba', dll)
  is_active     BOOLEAN DEFAULT true,
  sort_order    INT DEFAULT 0,
  created_by    UUID REFERENCES psy_profiles(id),
  created_by_name TEXT,
  created_at    TIMESTAMPTZ DEFAULT now(),
  updated_at    TIMESTAMPTZ DEFAULT now(),
  UNIQUE (name, type)
);

CREATE INDEX IF NOT EXISTS idx_coaching_catalog_type ON psy_coaching_catalog(type, sort_order);
CREATE INDEX IF NOT EXISTS idx_coaching_catalog_active ON psy_coaching_catalog(is_active);

ALTER TABLE psy_coaching_catalog ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "Anyone read catalog" ON psy_coaching_catalog
    FOR SELECT USING (auth.uid() IS NOT NULL);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "Staff manage catalog" ON psy_coaching_catalog
    FOR ALL USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
    WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Seed beberapa default
INSERT INTO psy_coaching_catalog (name, type, category, sort_order) VALUES
  ('Bimbingan Reaksi',              'bimbingan', 'Reaksi',     10),
  ('Bimbingan Terapi Peminuman IB', 'bimbingan', 'Terapi',     20),
  ('Bimbingan Terapi Zikir Bersanad','bimbingan', 'Terapi',    30),
  ('Bimbingan Senaman Pernafasan',  'bimbingan', 'Senaman',    40),
  ('Bimbingan Pemakanan',           'bimbingan', 'Diet',       50),
  ('Herba Thoharah',                'aktiviti',  'Herba',      10),
  ('Terapi Madu LTHPG',             'aktiviti',  'Terapi',     20),
  ('Sesi Bekam',                    'aktiviti',  'Rawatan',    30),
  ('Senaman Pernafasan',            'aktiviti',  'Senaman',    40),
  ('Konsultasi Doktor',             'aktiviti',  'Konsultasi', 50),
  ('Berjemur Matahari',             'aktiviti',  'Amalan',     60)
ON CONFLICT (name, type) DO NOTHING;


-- ════════════════════════════════════════════════════════════════
-- step_compliance_session_day.sql
-- ════════════════════════════════════════════════════════════════

-- ============================================================
-- step_compliance_session_day.sql  (idempotent)
-- Jadikan kepatuhan rawatan boleh diskop ikut SESI (session_day),
-- bukan hanya ikut minggu. Plan 2-sesi/minggu (cth Jum + Sab) kini
-- boleh ada kepatuhan berasingan untuk setiap sesi.
--   • Rekod sedia ada → session_day = 1
--   • UNIQUE lama (plan_id, week_number) ditukar ke
--     (plan_id, week_number, session_day)
-- Nota: app pesakit baca rows[0] sahaja — tidak terjejas.
-- ============================================================

ALTER TABLE psy_plan_compliance
  ADD COLUMN IF NOT EXISTS session_day INT NOT NULL DEFAULT 1;

-- Tukar kekangan UNIQUE supaya merangkumi session_day
ALTER TABLE psy_plan_compliance
  DROP CONSTRAINT IF EXISTS psy_plan_compliance_plan_id_week_number_key;

DO $$ BEGIN
  ALTER TABLE psy_plan_compliance
    ADD CONSTRAINT psy_plan_compliance_plan_week_session_key
    UNIQUE (plan_id, week_number, session_day);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE INDEX IF NOT EXISTS idx_psy_compliance_plan_week_sess
  ON psy_plan_compliance (plan_id, week_number, session_day);

COMMENT ON COLUMN psy_plan_compliance.session_day IS
  'Sesi dalam minggu (1 atau 2) untuk kepatuhan ini. Default 1.';

SELECT 'OK — psy_plan_compliance session_day ready' AS status;


-- ════════════════════════════════════════════════════════════════
-- step_feedback_patient_meta.sql
-- ════════════════════════════════════════════════════════════════

-- ============================================================
-- step_feedback_patient_meta.sql  (idempotent)
-- Tambah lajur yang dijangka oleh kod tetapi tertinggal dari skema:
--   • user_id      — profil yang hantar feedback
--   • patient_name — nama pesakit (dipapar di feedback.html staf)
-- Diperlukan oleh borang feedback weekly (plan-week.html & feedback.html).
-- ============================================================

ALTER TABLE psy_feedback
  ADD COLUMN IF NOT EXISTS user_id      UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS patient_name TEXT;

SELECT 'OK — psy_feedback.user_id + patient_name ready' AS status;


-- ════════════════════════════════════════════════════════════════
-- step_inventory_auto_po.sql
-- ════════════════════════════════════════════════════════════════

-- ============================================================
-- step_inventory_auto_po.sql
-- Auto-trigger purchase invoice bila stok ≤ 30% dari max.
-- ============================================================

ALTER TABLE psy_inventory_items
  ADD COLUMN IF NOT EXISTS max_qty NUMERIC(10,2),
  ADD COLUMN IF NOT EXISTS auto_reorder_qty NUMERIC(10,2),
  ADD COLUMN IF NOT EXISTS auto_reorder_enabled BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS last_auto_po_at TIMESTAMPTZ;

COMMENT ON COLUMN psy_inventory_items.max_qty IS
  'Saiz stok penuh / target. Trigger auto-PO bila qty_in_stock <= 30% dari max_qty.';
COMMENT ON COLUMN psy_inventory_items.auto_reorder_qty IS
  'Kuantiti yang sistem cadang dalam auto-PO. Default: max_qty - qty_in_stock.';
COMMENT ON COLUMN psy_inventory_items.auto_reorder_enabled IS
  'true = auto-create purchase invoice bila stok rendah; false = manual sahaja.';
COMMENT ON COLUMN psy_inventory_items.last_auto_po_at IS
  'Tarikh auto-PO terakhir dijana — elak duplikat dalam tempoh pendek.';

-- Mark auto-generated requests
ALTER TABLE psy_inventory_requests
  ADD COLUMN IF NOT EXISTS is_auto_generated BOOLEAN DEFAULT false;

COMMENT ON COLUMN psy_inventory_requests.is_auto_generated IS
  'true = dijana automatik bila stok ≤ 30%, false = manual request oleh staff.';


-- ════════════════════════════════════════════════════════════════
-- step_inventory_auto_trigger.sql
-- ════════════════════════════════════════════════════════════════

-- ============================================================
-- step_inventory_auto_trigger.sql
-- Auto-create psy_inventory_requests bila stok turun ≤ threshold.
--
-- Threshold:
--   - Kalau max_qty diset → 30% daripada max_qty
--   - Kalau tidak → min_qty (fallback)
--
-- Status request:
--   - requires_approval = TRUE  → 'pending_approval' (manager kena approve)
--   - requires_approval = FALSE → 'approved' (staff terus boleh beli)
--
-- Duplicate guard:
--   - Skip kalau dah ada request status 'pending_approval' atau 'approved'
--     untuk item yang sama (belum purchased).
--   - Cooldown 24 jam guna last_auto_po_at — elak spam masa stok
--     turun-naik berkali-kali dalam masa singkat.
-- ============================================================

CREATE OR REPLACE FUNCTION psy_inventory_auto_request()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_threshold       NUMERIC;
  v_existing_count  INT;
  v_reorder_qty     NUMERIC;
  v_status          TEXT;
  v_target          NUMERIC;
BEGIN
  -- Hanya bertindak bila qty_in_stock benar-benar berubah & turun
  IF NEW.qty_in_stock IS NULL OR NEW.qty_in_stock = OLD.qty_in_stock THEN
    RETURN NEW;
  END IF;
  IF NEW.qty_in_stock > OLD.qty_in_stock THEN
    RETURN NEW;  -- stok naik (restock) — jangan trigger
  END IF;

  -- Kira threshold
  IF NEW.max_qty IS NOT NULL AND NEW.max_qty > 0 THEN
    v_threshold := NEW.max_qty * 0.30;
  ELSE
    v_threshold := COALESCE(NEW.min_qty, 0);
  END IF;

  IF v_threshold <= 0 THEN
    RETURN NEW;
  END IF;

  IF NEW.qty_in_stock > v_threshold THEN
    RETURN NEW;  -- masih di atas threshold
  END IF;

  -- Cooldown 24 jam
  IF NEW.last_auto_po_at IS NOT NULL
     AND NEW.last_auto_po_at > now() - INTERVAL '24 hours' THEN
    RETURN NEW;
  END IF;

  -- Duplicate guard
  SELECT COUNT(*) INTO v_existing_count
  FROM psy_inventory_requests
  WHERE item_id = NEW.id
    AND status IN ('pending_approval', 'approved');

  IF v_existing_count > 0 THEN
    RETURN NEW;
  END IF;

  -- Kira reorder qty
  IF NEW.max_qty IS NOT NULL AND NEW.max_qty > 0 THEN
    v_target := NEW.max_qty;
  ELSE
    v_target := COALESCE(NEW.min_qty, 0) * 3;
  END IF;

  v_reorder_qty := COALESCE(NEW.auto_reorder_qty,
                            GREATEST(1, v_target - NEW.qty_in_stock));

  -- Tentukan status ikut requires_approval
  v_status := CASE
                WHEN COALESCE(NEW.requires_approval, false) THEN 'pending_approval'
                ELSE 'approved'
              END;

  INSERT INTO psy_inventory_requests (
    item_id, item_name, qty_requested, unit_price, total_amount,
    reason, status, requested_by, requested_by_name, is_auto_generated
  ) VALUES (
    NEW.id,
    NEW.name,
    v_reorder_qty,
    NULL,
    NULL,
    format('Auto-trigger: stok %s%s ≤ threshold %s%s. Sila beli %s%s.',
           NEW.qty_in_stock, COALESCE(NEW.unit, ''),
           ROUND(v_threshold, 2), COALESCE(NEW.unit, ''),
           v_reorder_qty, COALESCE(NEW.unit, '')),
    v_status,
    NULL,
    'Sistem (Auto)',
    true
  );

  -- Tanda cooldown
  NEW.last_auto_po_at := now();

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_psy_inventory_auto_request ON psy_inventory_items;

CREATE TRIGGER trg_psy_inventory_auto_request
BEFORE UPDATE OF qty_in_stock ON psy_inventory_items
FOR EACH ROW
EXECUTE FUNCTION psy_inventory_auto_request();

COMMENT ON FUNCTION psy_inventory_auto_request() IS
  'Auto-cipta inventory_request bila stok turun ≤ 30% max_qty (atau ≤ min_qty kalau max_qty tiada). Hormat requires_approval untuk status.';


-- ════════════════════════════════════════════════════════════════
-- step_inventory_consumption_type.sql
-- ════════════════════════════════════════════════════════════════

-- ============================================================
-- step_inventory_consumption_type.sql
-- Klasifikasi barang inventory ikut sifat consumption:
--   package  = pakai sebagai bekalan pakej (kira dynamic dari patient × pakej supplies)
--   service  = pakai untuk service one-off (cth: DNA test kit, swab, urine cup)
--   general  = consumable umum (sarung tangan, alcohol swab, tissue) — manual min sahaja
-- ============================================================

ALTER TABLE psy_inventory_items
  ADD COLUMN IF NOT EXISTS consumption_type TEXT DEFAULT 'package'
    CHECK (consumption_type IN ('package','service','general'));

COMMENT ON COLUMN psy_inventory_items.consumption_type IS
  'package = bekalan pakej (dynamic auto-calc); service = guna semasa service one-off; general = consumable umum (manual min sahaja).';

UPDATE psy_inventory_items SET consumption_type = 'package' WHERE consumption_type IS NULL;

-- ============================================================
-- psy_services — Senarai service (appointment types) yang clinic tawarkan.
-- Page services.html dan service-detail.html guna table ni.
-- ============================================================
CREATE TABLE IF NOT EXISTS psy_services (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  service_id    TEXT UNIQUE NOT NULL,
  name          TEXT NOT NULL,
  description   TEXT,
  icon          TEXT DEFAULT '⚕',
  price         NUMERIC(10,2) DEFAULT 0,
  duration_min  INT DEFAULT 30,
  sort_order    INT DEFAULT 100,
  is_active     BOOLEAN DEFAULT true,
  supplies      JSONB DEFAULT '[]'::jsonb,
  created_at    TIMESTAMPTZ DEFAULT now(),
  updated_at    TIMESTAMPTZ DEFAULT now()
);

COMMENT ON COLUMN psy_services.supplies IS
  'Senarai item inventory yang diguna per session service. Format: [{item_id, item_name, qty}].';

ALTER TABLE psy_services ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "Staff manage services" ON psy_services FOR ALL
    USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "All authenticated read services" ON psy_services FOR SELECT
    USING (auth.uid() IS NOT NULL);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Kalau table sudah pernah wujud tanpa column supplies (cth. di-create melalui jalan lain), tambah dia.
ALTER TABLE psy_services
  ADD COLUMN IF NOT EXISTS supplies JSONB DEFAULT '[]'::jsonb;

-- Seed beberapa service umum (idempotent — skip jika sudah ada)
INSERT INTO psy_services (service_id, name, description, icon, price, duration_min, sort_order)
VALUES
  ('consultation', 'Consultation with Doctor', 'Sesi konsultasi dengan doktor',           '🩺',  50.00, 30, 10),
  ('dna_test',     'DNA Test',                  'Ujian genetik untuk profil kesihatan',  '🧬', 350.00, 45, 20),
  ('blood_test',   'Blood Test',                'Pemeriksaan darah asas',                '🩸', 120.00, 20, 30),
  ('kob',          'Kursus Orientasi Bestari',  'Kursus orientasi pesakit baru',         '🎓',   0.00, 90, 40)
ON CONFLICT (service_id) DO NOTHING;


-- ════════════════════════════════════════════════════════════════
-- step_inventory_supplier_info.sql
-- ════════════════════════════════════════════════════════════════

-- ============================================================
-- step_inventory_supplier_info.sql
-- Tambah supplier_info JSONB pada psy_inventory_items
-- Format: { name, cost_per_unit, lead_days, po_min, po_max }
-- ============================================================

ALTER TABLE psy_inventory_items
  ADD COLUMN IF NOT EXISTS supplier_info JSONB DEFAULT '{}'::jsonb;

COMMENT ON COLUMN psy_inventory_items.supplier_info IS
  'Format: { name, cost_per_unit, lead_days, po_min, po_max }. Maklumat pembekal dan cadangan PO.';


-- ════════════════════════════════════════════════════════════════
-- step_letter_base.sql
-- ════════════════════════════════════════════════════════════════

-- ============================================================
-- step_letters.sql
-- Sistem generate surat rasmi (KWSP, PERKESO, RELA, dll).
-- Patient request → Staff fill template → sign → patient download PDF.
-- ============================================================

-- Staff signature (upload sekali, reuse semua surat)
ALTER TABLE psy_profiles
  ADD COLUMN IF NOT EXISTS signature_url TEXT;

COMMENT ON COLUMN psy_profiles.signature_url IS
  'URL signature image staff. Embed dalam surat rasmi yang di-sign.';

-- Permintaan surat dari patient
CREATE TABLE IF NOT EXISTS psy_letter_requests (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id      UUID REFERENCES psy_patients(id) ON DELETE CASCADE NOT NULL,
  patient_name    TEXT NOT NULL,
  template_code   TEXT NOT NULL,
  template_name   TEXT NOT NULL,
  reason          TEXT,
  field_values    JSONB DEFAULT '{}',
  status          TEXT NOT NULL DEFAULT 'pending'
                  CHECK (status IN ('pending','issued','rejected','cancelled')),
  reject_reason   TEXT,
  created_at      TIMESTAMPTZ DEFAULT now(),
  updated_at      TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_letter_req_patient ON psy_letter_requests(patient_id);
CREATE INDEX IF NOT EXISTS idx_letter_req_status  ON psy_letter_requests(status, created_at DESC);

ALTER TABLE psy_letter_requests ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "Patient manage own letter requests" ON psy_letter_requests
    FOR ALL USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()))
    WITH CHECK (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "Staff read all letter requests" ON psy_letter_requests
    FOR SELECT USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "Staff update letter requests" ON psy_letter_requests
    FOR UPDATE USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;


-- Surat yang telah dikeluarkan & disign
CREATE TABLE IF NOT EXISTS psy_letter_issued (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id      UUID REFERENCES psy_letter_requests(id) ON DELETE SET NULL,
  patient_id      UUID REFERENCES psy_patients(id) ON DELETE CASCADE,  -- nullable: NULL = internal document
  patient_name    TEXT NOT NULL,
  template_code   TEXT NOT NULL,
  template_name   TEXT NOT NULL,
  field_values    JSONB NOT NULL DEFAULT '{}',
  ref_number      TEXT,  -- cth: ISW/RELA/2026/0001
  signed_by       UUID REFERENCES psy_profiles(id),
  signed_by_name  TEXT NOT NULL,
  signed_by_role  TEXT,
  signature_url   TEXT,  -- snapshot signature staff masa sign
  signed_at       TIMESTAMPTZ DEFAULT now(),
  created_at      TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_letter_issued_patient ON psy_letter_issued(patient_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_letter_issued_code    ON psy_letter_issued(template_code);

ALTER TABLE psy_letter_issued ENABLE ROW LEVEL SECURITY;

-- Untuk DB sedia ada — drop NOT NULL kalau ada
ALTER TABLE psy_letter_issued ALTER COLUMN patient_id DROP NOT NULL;

DO $$ BEGIN
  CREATE POLICY "Patient read own issued letters" ON psy_letter_issued
    FOR SELECT USING (patient_id IS NOT NULL AND patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "Staff manage issued letters" ON psy_letter_issued
    FOR ALL USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
    WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;


-- ════════════════════════════════════════════════════════════════
-- step_letter_template_overrides.sql
-- ════════════════════════════════════════════════════════════════

-- ============================================================
-- step_letter_template_overrides.sql
-- Staff boleh override templates surat hardcoded.
-- Cara kerja: DB override → kalau tiada, fallback ke hardcoded JS templates.
-- ============================================================

CREATE TABLE IF NOT EXISTS psy_letter_template_overrides (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  template_code   TEXT UNIQUE NOT NULL,  -- 'rela', 'kwsp', etc.
  name            TEXT NOT NULL,
  description     TEXT,
  icon            TEXT,
  body_html       TEXT NOT NULL,
  fields          JSONB NOT NULL DEFAULT '[]',  -- [{key,label,type,required,autofill}]
  updated_by      UUID REFERENCES psy_profiles(id),
  updated_by_name TEXT,
  updated_at      TIMESTAMPTZ DEFAULT now(),
  created_at      TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE psy_letter_template_overrides ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "Staff read templates" ON psy_letter_template_overrides
    FOR SELECT USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "Staff manage templates" ON psy_letter_template_overrides
    FOR ALL USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
    WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Patient juga boleh read (untuk render surat masa download — sebab template_code dirujuk)
DO $$ BEGIN
  CREATE POLICY "Patient read templates" ON psy_letter_template_overrides
    FOR SELECT USING (auth.uid() IS NOT NULL);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

COMMENT ON TABLE psy_letter_template_overrides IS
  'Override templates surat hardcoded. Tiada row = guna hardcoded defaults.';


-- ════════════════════════════════════════════════════════════════
-- step_letter_files.sql
-- ════════════════════════════════════════════════════════════════

-- ============================================================
-- step_letter_files.sql
-- Refactor sistem surat ke document repository (Word/PDF upload).
-- Staff upload templates → download → fill dalam Word → save PDF →
-- upload PDF balik untuk patient.
-- ============================================================

-- ── Storage untuk uploaded template files ────────────────────
CREATE TABLE IF NOT EXISTS psy_letter_template_files (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name            TEXT NOT NULL,            -- cth: "Surat Permohonan KWSP"
  description     TEXT,
  file_url        TEXT NOT NULL,
  file_name       TEXT NOT NULL,            -- nama original file
  file_size       INT,                      -- bytes
  file_type       TEXT,                     -- 'docx', 'pdf', 'doc'
  uploaded_by     UUID REFERENCES psy_profiles(id),
  uploaded_by_name TEXT,
  created_at      TIMESTAMPTZ DEFAULT now()
);

-- Sokong dua jenis templat: 'file' (upload Word/PDF) atau 'inline' (cipta dalam sistem)
ALTER TABLE psy_letter_template_files
  ADD COLUMN IF NOT EXISTS template_type TEXT DEFAULT 'file'
    CHECK (template_type IN ('file','inline')),
  ADD COLUMN IF NOT EXISTS body_html TEXT;

-- Buat file_url nullable (inline tak ada file)
ALTER TABLE psy_letter_template_files ALTER COLUMN file_url DROP NOT NULL;
ALTER TABLE psy_letter_template_files ALTER COLUMN file_name DROP NOT NULL;

CREATE INDEX IF NOT EXISTS idx_letter_tpl_files_created ON psy_letter_template_files(created_at DESC);

ALTER TABLE psy_letter_template_files ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "Staff manage template files" ON psy_letter_template_files
    FOR ALL USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
    WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;


-- ── Issued letters: tambah file_url untuk uploaded PDF ───────
ALTER TABLE psy_letter_issued
  ADD COLUMN IF NOT EXISTS file_url     TEXT,
  ADD COLUMN IF NOT EXISTS file_name    TEXT,
  ADD COLUMN IF NOT EXISTS file_size    INT,
  ADD COLUMN IF NOT EXISTS template_file_id UUID REFERENCES psy_letter_template_files(id) ON DELETE SET NULL;

COMMENT ON COLUMN psy_letter_issued.file_url IS
  'URL PDF/Word file lengkap yang dah disign (upload oleh staff).';
COMMENT ON COLUMN psy_letter_issued.template_file_id IS
  'Refer template yang digunakan (untuk track sahaja).';

-- Field lama (field_values, signature_url, body_html) jadi optional/legacy
-- Tak perlu drop sebab old data mungkin ada.


-- ════════════════════════════════════════════════════════════════
-- step_letter_simple.sql
-- ════════════════════════════════════════════════════════════════

-- ============================================================
-- step_letter_simple.sql
-- Sistem surat: format tetap (letterhead auto), admin define
-- template body + fields, staff fill form → generate PDF.
-- ============================================================

CREATE TABLE IF NOT EXISTS psy_letter_templates (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name            TEXT NOT NULL,
  description     TEXT,
  category        TEXT NOT NULL DEFAULT 'patient'
                  CHECK (category IN ('patient','internal')),
  recipient       TEXT,                 -- "Pengurus Besar, KWSP, ..."
  title           TEXT,                 -- "PERMOHONAN PENGELUARAN AHLI KWSP"
  body            TEXT NOT NULL,        -- plain text + [PLACEHOLDER]
  fields          JSONB NOT NULL DEFAULT '[]',  -- [{key,label,type,autofill}]
  created_by      UUID REFERENCES psy_profiles(id),
  created_by_name TEXT,
  created_at      TIMESTAMPTZ DEFAULT now(),
  updated_at      TIMESTAMPTZ DEFAULT now()
);

-- Tambah kalau table dah wujud
ALTER TABLE psy_letter_templates
  ADD COLUMN IF NOT EXISTS category TEXT NOT NULL DEFAULT 'patient';

ALTER TABLE psy_letter_templates ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "Anyone read templates" ON psy_letter_templates
    FOR SELECT USING (auth.uid() IS NOT NULL);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "Staff manage templates" ON psy_letter_templates
    FOR ALL USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
    WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Cleanup old tables (jika ada, dari iterasi lepas)
DROP TABLE IF EXISTS psy_letter_template_overrides;

-- Drop column dalam psy_letter_issued yang refer psy_letter_template_files dulu
ALTER TABLE psy_letter_issued DROP COLUMN IF EXISTS template_file_id;
DROP TABLE IF EXISTS psy_letter_template_files;


-- ════════════════════════════════════════════════════════════════
-- step_letter_auto_fields.sql
-- ════════════════════════════════════════════════════════════════

-- ============================================================
-- step_letter_auto_fields.sql
-- Admin boleh tambah auto-field tambahan (selain yang hardcoded).
-- Cth: [BMI], [BERAT], [PEKERJAAN] — sistem ambil dari column DB.
-- ============================================================

CREATE TABLE IF NOT EXISTS psy_letter_auto_fields (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  key             TEXT UNIQUE NOT NULL,        -- "BMI" (akan jadi [BMI] dalam templat)
  label           TEXT NOT NULL,               -- "BMI Patient" (yang muncul dalam palette)
  source          TEXT NOT NULL CHECK (source IN ('patient','staff','system')),
  data_path       TEXT NOT NULL,               -- nama column dalam table (cth: 'bmi', 'address', 'phone')
  format_type     TEXT,                        -- optional: 'date' / 'currency' / null
  is_active       BOOLEAN DEFAULT true,
  is_default      BOOLEAN DEFAULT false,       -- true = pre-seeded; boleh delete tapi reset bawa balik
  sort_order      INT DEFAULT 0,
  created_by      UUID REFERENCES psy_profiles(id),
  created_by_name TEXT,
  created_at      TIMESTAMPTZ DEFAULT now(),
  updated_at      TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE psy_letter_auto_fields
  ADD COLUMN IF NOT EXISTS is_default BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS sort_order INT DEFAULT 0;

ALTER TABLE psy_letter_auto_fields ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "Anyone read auto fields" ON psy_letter_auto_fields
    FOR SELECT USING (auth.uid() IS NOT NULL);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "Staff manage auto fields" ON psy_letter_auto_fields
    FOR ALL USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
    WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

COMMENT ON TABLE psy_letter_auto_fields IS
  'Auto-fields untuk surat. Admin manage via UI. Sistem ambil value dari DB column yang ditentukan.';

-- ── Seed default auto-fields ────────────────────────────────
INSERT INTO psy_letter_auto_fields (key, label, source, data_path, format_type, is_default, sort_order) VALUES
  ('NAMA',                'Nama Patient',          'patient', 'full_name',             NULL,       true, 10),
  ('IC',                  'No. K/P',                'patient', 'ic_number',             NULL,       true, 20),
  ('PHONE',               'No. Telefon',            'patient', 'phone',                 NULL,       true, 30),
  ('ALAMAT',              'Alamat Patient',         'patient', 'address',               NULL,       true, 40),
  ('TARIKH_LAHIR',        'Tarikh Lahir',           'patient', 'dob',                   'date',     true, 50),
  ('JANTINA',             'Jantina',                'patient', 'gender',                NULL,       true, 60),
  ('BANGSA',              'Bangsa',                 'patient', 'race',                  NULL,       true, 70),
  ('AGAMA',               'Agama',                  'patient', 'religion',              NULL,       true, 80),
  ('PEKERJAAN',           'Pekerjaan',              'patient', 'occupation',            NULL,       true, 90),
  ('PAKEJ',               'Pakej Aktif',            'patient', 'active_package_name',   NULL,       true, 100),
  ('TARIKH_MULA_RAWATAN', 'Tarikh Mula Rawatan',    'patient', 'package_purchased_at',  'date',     true, 110),
  ('STAFF_NAMA',          'Nama Staff',             'staff',   'full_name',             NULL,       true, 200),
  ('STAFF_JAWATAN',       'Jawatan Staff',          'staff',   'staff_role',            NULL,       true, 210),
  ('STAFF_REG_NO',        'No. Pendaftaran Staff',  'staff',   'registration_no',       NULL,       true, 220),
  ('STAFF_SPECIALIZATION','Pengkhususan Staff',     'staff',   'specialization',        NULL,       true, 230),
  ('TARIKH',              'Tarikh Hari Ini',        'system',  '__today__',             NULL,       true, 300),
  ('RUJUKAN',             'Nombor Rujukan',         'system',  '__ref_number__',        NULL,       true, 310)
ON CONFLICT (key) DO NOTHING;


-- ════════════════════════════════════════════════════════════════
-- step_surat_template_v2.sql
-- ════════════════════════════════════════════════════════════════

-- ============================================================
-- STEP SURAT — TEMPLATE V2 (wizard fields)
-- Tambah column untuk match mockup wizard UI
-- ============================================================

ALTER TABLE psy_letter_templates
  ADD COLUMN IF NOT EXISTS jenis_surat TEXT,           -- sub-category bebas: "Tujuan Rawatan", "KWSP", "RELA"
  ADD COLUMN IF NOT EXISTS language TEXT DEFAULT 'ms', -- 'ms' atau 'en'
  ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true;

COMMENT ON COLUMN psy_letter_templates.jenis_surat IS
  'Sub-category template (cth: Tujuan Rawatan, KWSP, RELA). Boleh diisi bebas.';
COMMENT ON COLUMN psy_letter_templates.language IS
  'Bahasa default template: ms (Bahasa Melayu) atau en (English).';
COMMENT ON COLUMN psy_letter_templates.is_active IS
  'Template aktif boleh diguna pakai. Tak aktif = draft / disembunyikan dari list patient.';

CREATE INDEX IF NOT EXISTS idx_letter_tpl_active ON psy_letter_templates(category, is_active);

SELECT 'Step Surat Template V2 OK' AS status;


-- ════════════════════════════════════════════════════════════════
-- step_surat_approval.sql
-- ════════════════════════════════════════════════════════════════

-- ============================================================
-- STEP SURAT — APPROVAL ROUTING
-- Setiap template boleh assign signer/approver specific (cth: RELA → Manager Shamsinar)
-- Patient request akan route ke approver tu sahaja, bukan semua staff
-- ============================================================

-- ── TEMPLATE: tambah approver ──
ALTER TABLE psy_letter_templates
  ADD COLUMN IF NOT EXISTS assigned_signer_id UUID REFERENCES psy_profiles(id) ON DELETE SET NULL;
ALTER TABLE psy_letter_templates
  ADD COLUMN IF NOT EXISTS requires_specific_approver BOOLEAN DEFAULT false;

COMMENT ON COLUMN psy_letter_templates.assigned_signer_id IS
  'Staff yang ditetapkan untuk sign template ini. NULL = mana-mana staff dengan permission boleh sign.';
COMMENT ON COLUMN psy_letter_templates.requires_specific_approver IS
  'true = HANYA assigned_signer (atau super_admin) boleh approve/sign. false = pilihan default sahaja.';

-- ── REQUEST: tambah approval tracking ──
ALTER TABLE psy_letter_requests
  ADD COLUMN IF NOT EXISTS assigned_signer_id UUID REFERENCES psy_profiles(id) ON DELETE SET NULL;
ALTER TABLE psy_letter_requests
  ADD COLUMN IF NOT EXISTS approved_by UUID REFERENCES psy_profiles(id) ON DELETE SET NULL;
ALTER TABLE psy_letter_requests
  ADD COLUMN IF NOT EXISTS approved_at TIMESTAMPTZ;

COMMENT ON COLUMN psy_letter_requests.assigned_signer_id IS
  'Snapshot signer ID dari template masa request dicipta. Tak berubah walau template di-edit kemudian.';

-- Update CHECK constraint untuk include 'cancelled'
ALTER TABLE psy_letter_requests DROP CONSTRAINT IF EXISTS psy_letter_requests_status_check;
ALTER TABLE psy_letter_requests ADD CONSTRAINT psy_letter_requests_status_check
  CHECK (status IN ('pending','issued','rejected','cancelled'));

-- ── Index untuk filter "show only mine" ──
CREATE INDEX IF NOT EXISTS idx_letter_req_signer ON psy_letter_requests(assigned_signer_id, status);

-- ── RLS update: assigned signer + super_admin/manager boleh nampak request mereka ──
-- (Sedia ada policy "req_staff_read" via user_has_perm('communication','view') — kekal.
--  Filter "milik saya sahaja" akan handle di UI layer.)

SELECT 'Step Surat Approval OK — assigned_signer columns added' AS status;


-- ════════════════════════════════════════════════════════════════
-- step_package_extension_price.sql
-- ════════════════════════════════════════════════════════════════

-- Phase 1: Harga tambah minggu rawatan (extension) — admin tetapkan per pakej.

ALTER TABLE psy_packages
  ADD COLUMN IF NOT EXISTS extension_price_per_week NUMERIC(10,2) DEFAULT 50;

COMMENT ON COLUMN psy_packages.extension_price_per_week IS
  'Harga (RM) untuk tambah satu minggu rawatan bila patient miss sesi. Default RM 50.';


-- ════════════════════════════════════════════════════════════════
-- step_package_meet_link.sql
-- ════════════════════════════════════════════════════════════════

-- Add single Gmeet link per package — used for all weeks with online/both mode.
ALTER TABLE psy_packages
  ADD COLUMN IF NOT EXISTS meet_link TEXT;

COMMENT ON COLUMN psy_packages.meet_link IS
  'Pautan Gmeet recurring untuk pakej. Dipaparkan kepada patient bila minggu semasa adalah online/both.';


-- ════════════════════════════════════════════════════════════════
-- step_patient_address_residence.sql
-- ════════════════════════════════════════════════════════════════

-- ============================================================
-- STEP — Patient Address: Residence + City/State columns
-- Tambah alamat kediaman (berasingan dari surat-menyurat) +
-- pecahkan bandar / negeri untuk filter & laporan.
-- ============================================================

ALTER TABLE psy_patients
  ADD COLUMN IF NOT EXISTS home_address TEXT,
  ADD COLUMN IF NOT EXISTS city         TEXT,
  ADD COLUMN IF NOT EXISTS state        TEXT;

COMMENT ON COLUMN psy_patients.home_address IS
  'Alamat kediaman pesakit (berbeza dari address yang digunakan untuk surat-menyurat / mailing).';
COMMENT ON COLUMN psy_patients.city  IS 'Bandar (sebahagian dari alamat kediaman).';
COMMENT ON COLUMN psy_patients.state IS 'Negeri (Selangor, Johor, dll.).';

CREATE INDEX IF NOT EXISTS idx_patients_state ON psy_patients(state);

SELECT 'Step Patient Address OK — home_address, city, state added' AS status;


-- ════════════════════════════════════════════════════════════════
-- step_patient_hub_v2.sql
-- ════════════════════════════════════════════════════════════════

-- ============================================================
-- STEP — Patient Hub v2 schema
-- 1. Rename psy_dna_reports → psy_medical_reports + expand
-- 2. NEW psy_patient_notes (Nota Coach / Sesi / General)
-- 3. NEW psy_patient_documents (KYC, IC, Persetujuan, Laporan, Gambar)
-- 4. Patient supplies = derived dari coaching_schedule + audit log (no new table)
-- ============================================================

-- ───────── 1. EXPAND DNA → Medical Reports (general purpose) ─────────
-- Rename only if old table exists with old name; otherwise skip
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'psy_dna_reports')
     AND NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'psy_medical_reports') THEN
    ALTER TABLE psy_dna_reports RENAME TO psy_medical_reports;
  END IF;
END $$;

-- If neither exists, create fresh
CREATE TABLE IF NOT EXISTS psy_medical_reports (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id      UUID NOT NULL REFERENCES psy_patients(id) ON DELETE CASCADE,
  file_name       TEXT NOT NULL,
  file_path       TEXT,
  file_url        TEXT,
  notes           TEXT,
  uploaded_by     UUID,
  uploaded_by_name TEXT,
  uploaded_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Add expanded columns
ALTER TABLE psy_medical_reports
  ADD COLUMN IF NOT EXISTS report_type    TEXT DEFAULT 'dna',
  ADD COLUMN IF NOT EXISTS title          TEXT,
  ADD COLUMN IF NOT EXISTS status         TEXT DEFAULT 'pending',
  ADD COLUMN IF NOT EXISTS sample_date    DATE,
  ADD COLUMN IF NOT EXISTS sample_type    TEXT,
  ADD COLUMN IF NOT EXISTS result_date    DATE,
  ADD COLUMN IF NOT EXISTS analysis_duration_days INT,
  ADD COLUMN IF NOT EXISTS categories     JSONB DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS summary        TEXT,
  ADD COLUMN IF NOT EXISTS doctor_id      UUID,
  ADD COLUMN IF NOT EXISTS doctor_name    TEXT,
  ADD COLUMN IF NOT EXISTS doctor_review  TEXT,
  ADD COLUMN IF NOT EXISTS review_status  TEXT DEFAULT 'pending',
  ADD COLUMN IF NOT EXISTS reviewed_at    TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS shared_with_patient BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS shared_at      TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS attached_files JSONB DEFAULT '[]';

COMMENT ON COLUMN psy_medical_reports.report_type IS
  'dna | xray | ct | mri | ultrasound | blood | colonoscopy | endoscopy | other';
COMMENT ON COLUMN psy_medical_reports.status IS
  'pending | sampling | lab | ready | reviewed';
COMMENT ON COLUMN psy_medical_reports.review_status IS
  'pending | diluluskan | ditolak';

CREATE INDEX IF NOT EXISTS idx_medical_reports_patient ON psy_medical_reports(patient_id, uploaded_at DESC);
CREATE INDEX IF NOT EXISTS idx_medical_reports_type    ON psy_medical_reports(report_type);

ALTER TABLE psy_medical_reports ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  CREATE POLICY "staff_medical_all" ON psy_medical_reports FOR ALL
    USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "patient_medical_read" ON psy_medical_reports FOR SELECT
    USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ───────── 2. NEW: Patient Notes ─────────
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
DO $$ BEGIN
  CREATE POLICY "staff_notes_all" ON psy_patient_notes FOR ALL
    USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "patient_notes_read" ON psy_patient_notes FOR SELECT
    USING (visibility IN ('patient','both') AND
           patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ───────── 3. NEW: Patient Documents ─────────
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
  approved_at  TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_patient_docs_patient ON psy_patient_documents(patient_id, uploaded_at DESC);
CREATE INDEX IF NOT EXISTS idx_patient_docs_type    ON psy_patient_documents(doc_type);

ALTER TABLE psy_patient_documents ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  CREATE POLICY "staff_docs_all" ON psy_patient_documents FOR ALL
    USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "patient_docs_read_own" ON psy_patient_documents FOR SELECT
    USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "patient_docs_insert_own" ON psy_patient_documents FOR INSERT
    WITH CHECK (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

SELECT 'Step Patient Hub v2 OK — medical_reports expanded, notes + documents created' AS status;


-- ════════════════════════════════════════════════════════════════
-- step_plan_schedule_setup.sql
-- ════════════════════════════════════════════════════════════════

-- Phase 1: Treatment plan schedule preferences
-- Patient pilih sekali masa onboarding: pasangan hari + jam untuk setiap hari.
-- Sistem auto-seed 24 sesi (12 minggu × 2 hari).

ALTER TABLE psy_treatment_plans
  ADD COLUMN IF NOT EXISTS preferred_pair TEXT CHECK (preferred_pair IN ('fri_sat','sat_sun')),
  ADD COLUMN IF NOT EXISTS preferred_time_day1 TIME,   -- jam hari pertama (Jum atau Sab)
  ADD COLUMN IF NOT EXISTS preferred_time_day2 TIME,   -- jam hari kedua (Sab atau Ahad)
  ADD COLUMN IF NOT EXISTS schedule_setup_at TIMESTAMPTZ;

COMMENT ON COLUMN psy_treatment_plans.preferred_pair IS
  'Pasangan hari pilihan patient: fri_sat (Jumaat+Sabtu) atau sat_sun (Sabtu+Ahad).';
COMMENT ON COLUMN psy_treatment_plans.preferred_time_day1 IS
  'Jam pilihan hari pertama dalam pair (Jumaat untuk fri_sat, Sabtu untuk sat_sun).';
COMMENT ON COLUMN psy_treatment_plans.preferred_time_day2 IS
  'Jam pilihan hari kedua dalam pair (Sabtu untuk fri_sat, Ahad untuk sat_sun).';
COMMENT ON COLUMN psy_treatment_plans.schedule_setup_at IS
  'Bila patient siap setup jadual. NULL = belum setup, tunjuk wizard.';


-- ════════════════════════════════════════════════════════════════
-- step_plan_session_day.sql
-- ════════════════════════════════════════════════════════════════

-- Phase 1: 2 sesi seminggu — tambah session_day untuk pisahkan sesi A vs B.
-- Existing rows tetap session_day=1 supaya plan lama tak terjejas.

ALTER TABLE psy_plan_weekly_progress
  ADD COLUMN IF NOT EXISTS session_day INT DEFAULT 1 CHECK (session_day IN (1,2)),
  ADD COLUMN IF NOT EXISTS is_extension BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS extension_for_week INT,
  ADD COLUMN IF NOT EXISTS extension_price NUMERIC(10,2),
  ADD COLUMN IF NOT EXISTS extension_paid_at TIMESTAMPTZ;

-- Drop old uniqueness yang assume 1 row per minggu
ALTER TABLE psy_plan_weekly_progress
  DROP CONSTRAINT IF EXISTS psy_plan_weekly_progress_plan_id_week_number_key;

-- Composite unique: 1 row per sesi (plan + minggu + day)
DO $$ BEGIN
  ALTER TABLE psy_plan_weekly_progress
    ADD CONSTRAINT psy_plan_weekly_progress_plan_week_day_key
    UNIQUE (plan_id, week_number, session_day);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Status tambahan untuk extension flow
ALTER TABLE psy_plan_weekly_progress
  DROP CONSTRAINT IF EXISTS psy_plan_weekly_progress_status_check;

ALTER TABLE psy_plan_weekly_progress
  ADD CONSTRAINT psy_plan_weekly_progress_status_check
  CHECK (status IN (
    'pending','booked','hadir','reschedule','cancel','consultation_done',
    'extension_pending_payment','extension_paid'
  ));

COMMENT ON COLUMN psy_plan_weekly_progress.session_day IS
  '1 = sesi pertama dalam minggu (Jum/Sab), 2 = sesi kedua (Sab/Ahad). Default 1 untuk backward compat.';
COMMENT ON COLUMN psy_plan_weekly_progress.is_extension IS
  'true = minggu tambahan (extension) selepas miss sesi. Perlu bayar sebelum tempah.';
COMMENT ON COLUMN psy_plan_weekly_progress.extension_for_week IS
  'Refer minggu asal yang miss, untuk audit trail.';


-- ════════════════════════════════════════════════════════════════
-- step_procedure_kits.sql
-- ════════════════════════════════════════════════════════════════

-- ============================================================
-- step_procedure_kits.sql
-- Kit prosedur — satu kit = set item inventory yang diguna
-- untuk satu prosedur (cth: IV Drip Setup, DNA Test Kit).
-- Bila pakej ada kit dalam supplies, demand auto-expand
-- kepada semua sub-items dalam kit.
-- ============================================================

CREATE TABLE IF NOT EXISTS psy_procedure_kits (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name         TEXT NOT NULL UNIQUE,
  description  TEXT,
  category     TEXT DEFAULT 'Umum',
  items        JSONB NOT NULL DEFAULT '[]'::jsonb,
  is_active    BOOLEAN DEFAULT true,
  created_by   UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  created_at   TIMESTAMPTZ DEFAULT now(),
  updated_at   TIMESTAMPTZ DEFAULT now()
);

COMMENT ON COLUMN psy_procedure_kits.items IS
  'Format: [{item_id, item_name, qty, unit}]. Senarai inventory item yang diperlukan per satu prosedur.';

ALTER TABLE psy_procedure_kits ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  CREATE POLICY "Staff manage kits" ON psy_procedure_kits FOR ALL
    USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Seed contoh kits
INSERT INTO psy_procedure_kits (name, description, category, items) VALUES
(
  'IV Drip Setup',
  'Set lengkap untuk satu sesi IV Saline Drip',
  'IV Therapy',
  '[
    {"item_id": null, "item_name": "IV Line",       "qty": 1, "unit": "unit"},
    {"item_id": null, "item_name": "Gloves",         "qty": 2, "unit": "pasang"},
    {"item_id": null, "item_name": "Alcohol Swab",   "qty": 3, "unit": "unit"},
    {"item_id": null, "item_name": "Cotton Ball",    "qty": 2, "unit": "unit"},
    {"item_id": null, "item_name": "Branula",        "qty": 1, "unit": "unit"},
    {"item_id": null, "item_name": "Plaster",        "qty": 2, "unit": "unit"},
    {"item_id": null, "item_name": "Scotch Tape",    "qty": 1, "unit": "unit"}
  ]'::jsonb
),
(
  'Blood Test Setup',
  'Set lengkap untuk pengambilan darah',
  'Diagnostik',
  '[
    {"item_id": null, "item_name": "Gloves",         "qty": 1, "unit": "pasang"},
    {"item_id": null, "item_name": "Alcohol Swab",   "qty": 2, "unit": "unit"},
    {"item_id": null, "item_name": "Cotton Ball",    "qty": 2, "unit": "unit"},
    {"item_id": null, "item_name": "Needle/Vacutainer","qty": 1, "unit": "unit"},
    {"item_id": null, "item_name": "Plaster",        "qty": 1, "unit": "unit"},
    {"item_id": null, "item_name": "Blood Tube",     "qty": 3, "unit": "tube"}
  ]'::jsonb
),
(
  'DNA Test Setup',
  'Set untuk pengambilan sampel DNA (buccal swab)',
  'Diagnostik',
  '[
    {"item_id": null, "item_name": "Gloves",         "qty": 1, "unit": "pasang"},
    {"item_id": null, "item_name": "DNA Swab",       "qty": 2, "unit": "unit"},
    {"item_id": null, "item_name": "DNA Collection Tube", "qty": 1, "unit": "unit"},
    {"item_id": null, "item_name": "Ziplock Bag",    "qty": 1, "unit": "unit"}
  ]'::jsonb
)
ON CONFLICT DO NOTHING;


-- ════════════════════════════════════════════════════════════════
-- step_product_inventory_link.sql
-- ════════════════════════════════════════════════════════════════

-- ============================================================
-- step_product_inventory_link.sql
-- Link psy_products → psy_inventory_items supaya stok shop
-- auto-deduct dari inventory bila order paid.
-- ============================================================

ALTER TABLE psy_products
  ADD COLUMN IF NOT EXISTS inventory_item_id UUID REFERENCES psy_inventory_items(id) ON DELETE SET NULL;

COMMENT ON COLUMN psy_products.inventory_item_id IS
  'Link ke inventory item. Bila order status=paid, qty_in_stock auto-deduct ikut quantity dibeli.';

-- ============================================================
-- Trigger: auto-deduct inventory bila order status tukar ke 'paid'.
-- Items JSONB format: [{product_id: "...", qty: N, ...}, ...]
-- ============================================================
CREATE OR REPLACE FUNCTION psy_order_deduct_inventory()
RETURNS TRIGGER AS $$
DECLARE
  v_item       JSONB;
  v_product    psy_products%ROWTYPE;
  v_qty        NUMERIC;
BEGIN
  IF NEW.status = 'paid' AND (OLD.status IS DISTINCT FROM 'paid') THEN
    FOR v_item IN SELECT * FROM jsonb_array_elements(COALESCE(NEW.items, '[]'::jsonb))
    LOOP
      -- Match by product_id (text id) atau id (UUID) — support kedua-dua format
      SELECT * INTO v_product FROM psy_products
        WHERE product_id = v_item->>'product_id'
           OR id::text   = v_item->>'product_id'
        LIMIT 1;

      IF v_product.inventory_item_id IS NOT NULL THEN
        v_qty := COALESCE((v_item->>'qty')::numeric, (v_item->>'quantity')::numeric, 1);
        UPDATE psy_inventory_items
          SET qty_in_stock = GREATEST(0, qty_in_stock - v_qty),
              updated_at   = now()
          WHERE id = v_product.inventory_item_id;
      END IF;
    END LOOP;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_psy_order_deduct_inventory ON psy_orders;
CREATE TRIGGER trg_psy_order_deduct_inventory
  AFTER UPDATE ON psy_orders
  FOR EACH ROW EXECUTE FUNCTION psy_order_deduct_inventory();


-- ════════════════════════════════════════════════════════════════
-- step_products_enhanced.sql
-- ════════════════════════════════════════════════════════════════

-- ============================================================
-- STEP — psy_products enhanced fields
-- Untuk sokong mockup baru: jenama, promo, stok lanjut, media, butiran, visibility
-- ============================================================

ALTER TABLE psy_products
  ADD COLUMN IF NOT EXISTS sku           TEXT,
  ADD COLUMN IF NOT EXISTS brand         TEXT,
  ADD COLUMN IF NOT EXISTS description_short TEXT,
  ADD COLUMN IF NOT EXISTS status        TEXT DEFAULT 'active',
  ADD COLUMN IF NOT EXISTS promo_price   NUMERIC(10,2),
  ADD COLUMN IF NOT EXISTS promo_until   DATE,
  ADD COLUMN IF NOT EXISTS min_stock     INT DEFAULT 5,
  ADD COLUMN IF NOT EXISTS unit          TEXT DEFAULT 'unit',
  ADD COLUMN IF NOT EXISTS track_inventory  BOOLEAN DEFAULT true,
  ADD COLUMN IF NOT EXISTS low_stock_alert  BOOLEAN DEFAULT true,
  ADD COLUMN IF NOT EXISTS image_urls    JSONB DEFAULT '[]',
  ADD COLUMN IF NOT EXISTS weight_size   TEXT,
  ADD COLUMN IF NOT EXISTS supplier      TEXT,
  ADD COLUMN IF NOT EXISTS tags          JSONB DEFAULT '[]',
  ADD COLUMN IF NOT EXISTS notes         TEXT,
  ADD COLUMN IF NOT EXISTS visible_in_shop  BOOLEAN DEFAULT true,
  ADD COLUMN IF NOT EXISTS featured      BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS online_purchase BOOLEAN DEFAULT true;

-- Backfill sku from product_id if null
UPDATE psy_products SET sku = product_id WHERE sku IS NULL;

-- Backfill status from is_active
UPDATE psy_products SET status = 'active'   WHERE status IS NULL AND is_active = true;
UPDATE psy_products SET status = 'inactive' WHERE status IS NULL AND is_active = false;

SELECT 'Step psy_products enhanced OK' AS status;


-- ════════════════════════════════════════════════════════════════
-- step_products_image_url.sql
-- ════════════════════════════════════════════════════════════════

-- ============================================================
-- STEP — psy_products.image_url (single primary image)
-- Schema sedia ada: image_urls JSONB (array, plural).
-- UI product-edit.html guna image_url (singular, satu gambar utama).
-- Tambah column untuk match dengan kod, kekal image_urls untuk future.
-- ============================================================

ALTER TABLE psy_products
  ADD COLUMN IF NOT EXISTS image_url TEXT;

COMMENT ON COLUMN psy_products.image_url IS
  'URL gambar utama produk (single). Untuk gallery multi-gambar, guna image_urls (JSONB array).';

-- Backfill: kalau image_urls ada element pertama, copy ke image_url
UPDATE psy_products
SET image_url = image_urls->>0
WHERE image_url IS NULL
  AND image_urls IS NOT NULL
  AND jsonb_array_length(image_urls) > 0;

-- ── Verification: semua column yang product-edit.html guna ──
DO $$
DECLARE
  required_cols TEXT[] := ARRAY[
    'name','sku','product_id','category','status','is_active',
    'brand','description','description_short',
    'price','promo_price','promo_until',
    'stock','min_stock','unit','track_inventory','low_stock_alert',
    'image_url','image_urls','weight_size','supplier','tags','notes',
    'visible_in_shop','featured','online_purchase',
    'inventory_item_id','updated_at'
  ];
  missing_cols TEXT[] := '{}';
  col TEXT;
BEGIN
  FOREACH col IN ARRAY required_cols LOOP
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_name = 'psy_products' AND column_name = col
    ) THEN
      missing_cols := array_append(missing_cols, col);
    END IF;
  END LOOP;

  IF array_length(missing_cols, 1) > 0 THEN
    RAISE NOTICE 'MASIH MISSING dalam psy_products: %', missing_cols;
  ELSE
    RAISE NOTICE 'OK — semua column product-edit.html sudah ada';
  END IF;
END $$;

SELECT 'OK — psy_products.image_url added + verified' AS status;


-- ════════════════════════════════════════════════════════════════
-- step_referral_system.sql
-- ════════════════════════════════════════════════════════════════

-- ============================================================
-- step_referral_system.sql  (idempotent)
-- FASA 1: Sistem Referral Code — DB + auto-jana kod.
--   • Setiap pesakit dapat kod unik (referral_code)
--   • Rekod siapa rujuk siapa (referred_by_*)
--   • Lejar jejak + ganjaran manual (psy_referrals)
-- Ganjaran 100% manual (staf beri baucar) — tiada logik auto-diskaun.
-- ============================================================

-- ── 1. Kolum baharu pada psy_patients ──────────────────────
ALTER TABLE psy_patients
  ADD COLUMN IF NOT EXISTS referral_code         TEXT,
  ADD COLUMN IF NOT EXISTS referred_by_code      TEXT,
  ADD COLUMN IF NOT EXISTS referred_by_patient_id UUID REFERENCES psy_patients(id) ON DELETE SET NULL;

-- Kod mesti unik (NULL dibenarkan berbilang dalam Postgres)
CREATE UNIQUE INDEX IF NOT EXISTS idx_psy_patients_referral_code
  ON psy_patients (referral_code) WHERE referral_code IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_psy_patients_referred_by
  ON psy_patients (referred_by_patient_id) WHERE referred_by_patient_id IS NOT NULL;

COMMENT ON COLUMN psy_patients.referral_code IS
  'Kod rujukan unik pesakit ini untuk dikongsi (auto-jana dari nama/MRN).';
COMMENT ON COLUMN psy_patients.referred_by_code IS
  'Kod rujukan perujuk yang dimasukkan semasa pesakit ini mendaftar.';
COMMENT ON COLUMN psy_patients.referred_by_patient_id IS
  'Pesakit perujuk yang telah diselesaikan dari referred_by_code.';

-- ── 2. Trigger auto-jana referral_code (fallback dari MRN) ──
-- Client (JS) akan set kod cantik (nama+MRN) sebelum insert; jika
-- masih NULL, trigger ini jamin satu kod unik tetap wujud.
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

DROP TRIGGER IF EXISTS trg_assign_referral_code ON psy_patients;
CREATE TRIGGER trg_assign_referral_code
  BEFORE INSERT ON psy_patients
  FOR EACH ROW
  EXECUTE FUNCTION assign_referral_code();

-- ── 3. Backfill kod untuk pesakit sedia ada ────────────────
DO $$
DECLARE
  r         RECORD;
  base      TEXT;
  candidate TEXT;
  n         INT;
BEGIN
  FOR r IN SELECT id, mrn FROM psy_patients WHERE referral_code IS NULL LOOP
    base := 'ISW' || regexp_replace(COALESCE(r.mrn, ''), '\D', '', 'g');
    IF base = 'ISW' THEN
      base := 'ISW' || to_char((random() * 9000 + 1000)::int, 'FM0000');
    END IF;
    candidate := base;
    n := 1;
    WHILE EXISTS (SELECT 1 FROM psy_patients WHERE referral_code = candidate) LOOP
      n := n + 1;
      candidate := base || n;
    END LOOP;
    UPDATE psy_patients SET referral_code = candidate WHERE id = r.id;
  END LOOP;
END $$;

-- ── 4. Lejar referral (jejak + ganjaran manual) ────────────
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

-- ── 5. RLS ─────────────────────────────────────────────────
ALTER TABLE psy_referrals ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "Staff manage referrals" ON psy_referrals FOR ALL
    USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "Patients read own referrals" ON psy_referrals FOR SELECT
    USING (EXISTS (
      SELECT 1 FROM psy_patients pp
      WHERE pp.id IN (psy_referrals.referrer_patient_id, psy_referrals.referee_patient_id)
        AND pp.user_id = auth.uid()
    ));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

SELECT 'OK — referral system (DB + auto-gen kod) ready' AS status;


-- ════════════════════════════════════════════════════════════════
-- step_session_notes_soap.sql
-- ════════════════════════════════════════════════════════════════

-- ============================================================
-- SESSION NOTES — SOAP format
-- Extend psy_plan_weekly_progress dengan medan SOAP +
-- risk flag + sign-off untuk compliance MDA.
-- ============================================================

ALTER TABLE psy_plan_weekly_progress
  ADD COLUMN IF NOT EXISTS soap_subjective TEXT,
  ADD COLUMN IF NOT EXISTS soap_objective  TEXT,
  ADD COLUMN IF NOT EXISTS soap_assessment TEXT,
  ADD COLUMN IF NOT EXISTS soap_plan       TEXT,
  ADD COLUMN IF NOT EXISTS risk_flag       TEXT CHECK (risk_flag IN ('none','low','medium','high','critical')),
  ADD COLUMN IF NOT EXISTS risk_note       TEXT,
  ADD COLUMN IF NOT EXISTS attended        BOOLEAN,
  ADD COLUMN IF NOT EXISTS notes_signed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS notes_signed_by UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS notes_signed_by_name TEXT;

COMMENT ON COLUMN psy_plan_weekly_progress.soap_subjective IS 'Apa pesakit cakap — keluhan, perasaan, simptom sendiri';
COMMENT ON COLUMN psy_plan_weekly_progress.soap_objective  IS 'Apa coach/doktor perhati — vital signs, body language, ujian';
COMMENT ON COLUMN psy_plan_weekly_progress.soap_assessment IS 'Penilaian klinikal — diagnosis, progress assessment';
COMMENT ON COLUMN psy_plan_weekly_progress.soap_plan       IS 'Pelan rawatan untuk sesi seterusnya';
COMMENT ON COLUMN psy_plan_weekly_progress.risk_flag       IS 'Tahap risiko: none/low/medium/high/critical. Trigger alert kalau ≥ medium';
COMMENT ON COLUMN psy_plan_weekly_progress.notes_signed_at IS 'Bila nota di-sign — selepas ini jadi read-only (audit compliance)';

CREATE INDEX IF NOT EXISTS idx_pwp_risk_flag ON psy_plan_weekly_progress(risk_flag) WHERE risk_flag IN ('high','critical');
CREATE INDEX IF NOT EXISTS idx_pwp_signed    ON psy_plan_weekly_progress(notes_signed_at) WHERE notes_signed_at IS NULL;

SELECT 'OK — SOAP columns added' AS status;


-- ════════════════════════════════════════════════════════════════
-- step_sync_kyc_to_patient.sql
-- ════════════════════════════════════════════════════════════════

-- ============================================================
-- FIX: Sync KYC data ke psy_patients
-- Untuk patient yang KYC dah diluluskan tapi patient row created lewat
-- (jadi ic_number, address dll kosong)
-- ============================================================

-- ── One-time backfill: sync KYC approved → patient row ──
UPDATE psy_patients p
SET
  status                  = 'active',
  full_name               = COALESCE(NULLIF(p.full_name, ''), k.patient_name),
  phone                   = COALESCE(NULLIF(p.phone, ''), k.phone),
  ic_number               = COALESCE(NULLIF(p.ic_number, ''), k.ic_number),
  date_of_birth           = COALESCE(p.date_of_birth, k.date_of_birth),
  gender                  = COALESCE(NULLIF(p.gender, ''), k.gender),
  address                 = COALESCE(NULLIF(p.address, ''), k.address),
  emergency_contact_name  = COALESCE(NULLIF(p.emergency_contact_name, ''), k.emergency_contact_name),
  emergency_contact_phone = COALESCE(NULLIF(p.emergency_contact_phone, ''), k.emergency_contact_phone),
  referral_source         = COALESCE(NULLIF(p.referral_source, ''), k.referral_source),
  medical_condition       = COALESCE(NULLIF(p.medical_condition, ''), k.medical_condition),
  condition_duration      = COALESCE(NULLIF(p.condition_duration, ''), k.condition_duration),
  medical_notes           = COALESCE(NULLIF(p.medical_notes, ''), k.medical_notes)
FROM psy_kyc_submissions k
WHERE k.user_id = p.user_id
  AND k.status  = 'approved'
  AND (p.ic_number IS NULL OR p.ic_number = '');

-- ── Trigger: auto-sync KYC → patient bila KYC diluluskan ──
-- Ini menjamin masa depan tak akan ada desync, walaupun patient row tak wujud masa KYC approved.
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

-- ── Verifikasi ──
SELECT p.mrn, p.full_name, p.ic_number, p.status, k.status AS kyc_status
FROM psy_patients p
LEFT JOIN psy_kyc_submissions k ON k.user_id = p.user_id AND k.status = 'approved'
WHERE k.id IS NOT NULL
ORDER BY p.created_at DESC
LIMIT 10;

SELECT 'OK — KYC→patient sync done + future trigger ready' AS status;


-- ════════════════════════════════════════════════════════════════
-- step_vitals_link_to_week.sql
-- ════════════════════════════════════════════════════════════════

-- ============================================================
-- STEP — Link psy_vitals ke minggu rawatan
-- Vitals patut "duduk dalam minggu" supaya boleh paparkan dalam
-- plan-week.html sebagai sebahagian dari rekod sesi minggu tu.
-- ============================================================

ALTER TABLE psy_vitals
  ADD COLUMN IF NOT EXISTS plan_id     UUID REFERENCES psy_treatment_plans(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS week_number INT;

COMMENT ON COLUMN psy_vitals.plan_id IS
  'Refer treatment plan masa vitals direkod. NULL kalau direkod luar konteks plan.';
COMMENT ON COLUMN psy_vitals.week_number IS
  'Minggu rawatan ke berapa bila vitals direkod. NULL kalau tiada plan aktif.';

-- Backfill: cuba match vitals lama dengan plan aktif patient + minggu ikut tarikh
UPDATE psy_vitals v
SET plan_id     = tp.id,
    week_number = tp.current_week
FROM psy_treatment_plans tp
WHERE v.patient_id = tp.patient_id
  AND tp.status = 'active'
  AND v.plan_id IS NULL;

-- Index untuk query "vitals minggu X plan Y"
CREATE INDEX IF NOT EXISTS idx_vitals_plan_week
  ON psy_vitals(plan_id, week_number) WHERE plan_id IS NOT NULL;

-- Verifikasi
SELECT
  COUNT(*) FILTER (WHERE plan_id IS NOT NULL) AS linked_to_plan,
  COUNT(*) FILTER (WHERE plan_id IS NULL)     AS no_plan,
  COUNT(*) AS total
FROM psy_vitals;

SELECT 'OK — psy_vitals linked to plan + week_number' AS status;


-- ════════════════════════════════════════════════════════════════
-- step_rbac_01_permissions.sql
-- ════════════════════════════════════════════════════════════════

-- ============================================================
-- STEP RBAC 01 — PERMISSIONS SCHEMA
-- 3 jadual + 1 view untuk Role-Based Access Control
-- Run di Supabase SQL Editor
-- ============================================================

-- 1. Tambah 'super_admin' kepada staff_role check constraint
ALTER TABLE psy_profiles DROP CONSTRAINT IF EXISTS psy_profiles_staff_role_check;
ALTER TABLE psy_profiles ADD CONSTRAINT psy_profiles_staff_role_check
  CHECK (staff_role IS NULL OR staff_role IN ('admin','coach','manager','doctor','super_admin'));

-- 2. Master list permission
CREATE TABLE IF NOT EXISTS psy_permissions (
  code        TEXT PRIMARY KEY,
  module      TEXT NOT NULL,
  action      TEXT NOT NULL,
  description TEXT,
  is_wired    BOOLEAN DEFAULT false,
  created_at  TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_psy_permissions_module ON psy_permissions(module);

-- 3. Default bundle per staff_role
CREATE TABLE IF NOT EXISTS psy_role_permissions (
  staff_role      TEXT NOT NULL,
  permission_code TEXT NOT NULL REFERENCES psy_permissions(code) ON DELETE CASCADE,
  created_at      TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (staff_role, permission_code)
);

-- 4. Override per-user (grant tambahan atau revoke default)
CREATE TABLE IF NOT EXISTS psy_user_permissions (
  user_id         UUID NOT NULL REFERENCES psy_profiles(id) ON DELETE CASCADE,
  permission_code TEXT NOT NULL REFERENCES psy_permissions(code) ON DELETE CASCADE,
  grant_type      TEXT NOT NULL CHECK (grant_type IN ('grant','revoke')),
  granted_by      UUID REFERENCES psy_profiles(id),
  granted_at      TIMESTAMPTZ DEFAULT now(),
  reason          TEXT,
  PRIMARY KEY (user_id, permission_code)
);
CREATE INDEX IF NOT EXISTS idx_psy_user_permissions_user ON psy_user_permissions(user_id);

-- 5. View: resolve final permission per user
--    final = (role_defaults - user_revokes) UNION user_grants
CREATE OR REPLACE VIEW psy_user_effective_permissions AS
SELECT p.id AS user_id, rp.permission_code
FROM psy_profiles p
JOIN psy_role_permissions rp ON rp.staff_role = p.staff_role
WHERE NOT EXISTS (
  SELECT 1 FROM psy_user_permissions up
  WHERE up.user_id = p.id
    AND up.permission_code = rp.permission_code
    AND up.grant_type = 'revoke'
)
UNION
SELECT user_id, permission_code
FROM psy_user_permissions
WHERE grant_type = 'grant';

-- 6. RLS — semua authenticated boleh read permissions; hanya super_admin boleh write
ALTER TABLE psy_permissions       ENABLE ROW LEVEL SECURITY;
ALTER TABLE psy_role_permissions  ENABLE ROW LEVEL SECURITY;
ALTER TABLE psy_user_permissions  ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "perm_read_all"  ON psy_permissions      FOR SELECT USING (auth.role() = 'authenticated');
  CREATE POLICY "rperm_read_all" ON psy_role_permissions FOR SELECT USING (auth.role() = 'authenticated');
  CREATE POLICY "uperm_read_all" ON psy_user_permissions FOR SELECT USING (auth.role() = 'authenticated');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "perm_write_superadmin" ON psy_permissions FOR ALL
    USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND staff_role = 'super_admin'))
    WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND staff_role = 'super_admin'));
  CREATE POLICY "rperm_write_superadmin" ON psy_role_permissions FOR ALL
    USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND staff_role = 'super_admin'))
    WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND staff_role = 'super_admin'));
  CREATE POLICY "uperm_write_superadmin" ON psy_user_permissions FOR ALL
    USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND staff_role = 'super_admin'))
    WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND staff_role = 'super_admin'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

SELECT 'Step RBAC 01 OK — schema ready' AS status;


-- ════════════════════════════════════════════════════════════════
-- step_rbac_02_seed_permissions.sql
-- ════════════════════════════════════════════════════════════════

-- ============================================================
-- STEP RBAC 02 — SEED MASTER PERMISSIONS
-- ~55 permission default, semua tanda is_wired=false (kena update bila code dah check)
-- ============================================================

INSERT INTO psy_permissions (code, module, action, description) VALUES
  -- Patient & KYC
  ('patient.view_all',          'patient',      'view_all',        'Lihat semua pesakit'),
  ('patient.view_assigned',     'patient',      'view_assigned',   'Lihat pesakit yang ditugaskan sahaja'),
  ('patient.create',            'patient',      'create',          'Daftar pesakit baru'),
  ('patient.edit',              'patient',      'edit',            'Edit maklumat pesakit'),
  ('patient.delete',            'patient',      'delete',          'Padam (soft delete) pesakit'),
  ('kyc.view',                  'kyc',          'view',            'Lihat borang KYC'),
  ('kyc.review',                'kyc',          'review',          'Semak borang KYC'),
  ('kyc.approve',               'kyc',          'approve',         'Lulus / tolak KYC'),
  ('vitals.view',               'vitals',       'view',            'Lihat tanda vital pesakit'),
  ('vitals.edit',               'vitals',       'edit',            'Rekod / edit tanda vital'),

  -- Coaching & Sesi
  ('assignment.view',           'assignment',   'view',            'Lihat assignment pesakit'),
  ('assignment.create',         'assignment',   'create',          'Cipta assignment'),
  ('assignment.review',         'assignment',   'review',          'Semak hasil assignment'),
  ('coaching.view',             'coaching',     'view',            'Lihat sesi coaching'),
  ('coaching.create',           'coaching',     'create',          'Cipta sesi coaching'),
  ('coaching.edit',             'coaching',     'edit',            'Edit sesi coaching'),
  ('consultation.view',         'consultation', 'view',            'Lihat konsultasi'),
  ('consultation.create',       'consultation', 'create',          'Cipta konsultasi'),
  ('plan.view',                 'plan',         'view',            'Lihat plan rawatan'),
  ('plan.edit',                 'plan',         'edit',            'Edit plan rawatan'),
  ('plan.weekly_manage',        'plan',         'weekly_manage',   'Urus jadual mingguan'),
  ('session_notes.view',        'session_notes','view',            'Lihat nota sesi'),
  ('session_notes.edit',        'session_notes','edit',            'Edit nota sesi'),

  -- KOB
  ('kob.view',                  'kob',          'view',            'Lihat KOB list'),
  ('kob.create',                'kob',          'create',          'Cipta KOB baru'),
  ('kob.manage_slots',          'kob',          'manage_slots',    'Urus slot KOB'),
  ('kob.recommend_package',     'kob',          'recommend',       'Cadang pakej dari KOB'),

  -- Inventori & Produk
  ('inventory.view',            'inventory',    'view',            'Lihat inventori'),
  ('inventory.edit',            'inventory',    'edit',            'Edit stok inventori'),
  ('inventory.issue',           'inventory',    'issue',           'Issue item kepada pesakit'),
  ('inventory.receive_return',  'inventory',    'receive_return',  'Terima pulangan botol/item'),
  ('product.view',              'product',      'view',            'Lihat produk'),
  ('product.edit',              'product',      'edit',            'Edit produk'),
  ('orders.view',               'orders',       'view',            'Lihat purchase orders'),
  ('orders.create',             'orders',       'create',          'Cipta PO'),
  ('orders.approve',            'orders',       'approve',         'Lulus PO'),
  ('kit.view',                  'kit',          'view',            'Lihat kit prosedur'),
  ('kit.edit',                  'kit',          'edit',            'Edit kit prosedur'),

  -- Pakej & Bayaran
  ('pakej.view',                'pakej',        'view',            'Lihat senarai pakej'),
  ('pakej.edit',                'pakej',        'edit',            'Edit pakej'),
  ('pakej.report',              'pakej',        'report',          'Lihat laporan pakej'),
  ('agreement.view',            'agreement',    'view',            'Lihat agreement pesakit'),
  ('agreement.sign',            'agreement',    'sign',            'Hantar agreement untuk tandatangan'),
  ('agreement.manage_clauses',  'agreement',    'manage_clauses',  'Urus klausa agreement'),
  ('payment.view',              'payment',      'view',            'Lihat bayaran'),
  ('payment.manage',            'payment',      'manage',          'Urus bayaran & invois'),

  -- Surat & Library
  ('surat.view',                'surat',        'view',            'Lihat surat'),
  ('surat.issue',               'surat',        'issue',           'Isu surat kepada pesakit'),
  ('surat.edit_template',       'surat',        'edit_template',   'Edit template surat'),
  ('library.view',              'library',      'view',            'Lihat library media'),
  ('library.edit',              'library',      'edit',            'Edit library media'),

  -- Operasi Klinik
  ('announcement.view',         'announcement', 'view',            'Lihat pengumuman'),
  ('announcement.create',       'announcement', 'create',          'Cipta pengumuman'),
  ('announcement.edit',         'announcement', 'edit',            'Edit pengumuman'),
  ('closures.view',             'closures',     'view',            'Lihat penutupan klinik'),
  ('closures.manage',           'closures',     'manage',          'Urus penutupan klinik'),
  ('kepatuhan.view',            'kepatuhan',    'view',            'Lihat status kepatuhan'),
  ('kepatuhan.manage',          'kepatuhan',    'manage',          'Urus peraturan kepatuhan'),
  ('risk_alert.view',           'risk_alert',   'view',            'Lihat risk alert'),
  ('risk_alert.respond',        'risk_alert',   'respond',         'Respon risk alert'),
  ('feedback.view',             'feedback',     'view',            'Lihat feedback pesakit'),
  ('feedback.respond',          'feedback',     'respond',         'Balas feedback'),

  -- Governance & Staff
  ('audit.view',                'audit',        'view',            'Lihat audit log'),
  ('governance.view',           'governance',   'view',            'Lihat governance'),
  ('governance.manage',         'governance',   'manage',          'Urus governance'),
  ('staff.view',                'staff',        'view',            'Lihat senarai staff'),
  ('staff.manage',              'staff',        'manage',          'Urus staff (tambah/buang/edit)'),
  ('staff.stats_view',          'staff',        'stats_view',      'Lihat statistik staff'),
  ('permissions.manage',        'permissions',  'manage',          'Urus permission & role (super admin only)')
ON CONFLICT (code) DO UPDATE
  SET module = EXCLUDED.module,
      action = EXCLUDED.action,
      description = EXCLUDED.description;

SELECT COUNT(*) || ' permissions seeded' AS status FROM psy_permissions;


-- ════════════════════════════════════════════════════════════════
-- step_rbac_03_role_defaults.sql
-- ════════════════════════════════════════════════════════════════

-- ============================================================
-- STEP RBAC 03 — DEFAULT ROLE BUNDLES
-- Tetapkan permission default untuk setiap staff_role
-- Boleh diubah kemudian via UI Tab "Role Matrix"
-- ============================================================

-- Reset bundle (idempotent)
DELETE FROM psy_role_permissions WHERE staff_role IN ('coach','doctor','admin','manager','super_admin');

-- ── COACH ──
INSERT INTO psy_role_permissions (staff_role, permission_code) VALUES
  ('coach','patient.view_assigned'),
  ('coach','vitals.view'),
  ('coach','assignment.view'),('coach','assignment.create'),('coach','assignment.review'),
  ('coach','coaching.view'),('coach','coaching.create'),('coach','coaching.edit'),
  ('coach','consultation.view'),('coach','consultation.create'),
  ('coach','plan.view'),('coach','plan.edit'),('coach','plan.weekly_manage'),
  ('coach','session_notes.view'),('coach','session_notes.edit'),
  ('coach','library.view'),
  ('coach','inventory.view'),('coach','inventory.issue'),('coach','inventory.receive_return'),
  ('coach','kit.view'),
  ('coach','surat.view'),('coach','surat.issue'),
  ('coach','announcement.view'),
  ('coach','kepatuhan.view'),
  ('coach','feedback.view'),('coach','feedback.respond');

-- ── DOCTOR (semua coach + extra) ──
INSERT INTO psy_role_permissions (staff_role, permission_code)
SELECT 'doctor', permission_code FROM psy_role_permissions WHERE staff_role = 'coach';
INSERT INTO psy_role_permissions (staff_role, permission_code) VALUES
  ('doctor','patient.view_all'),
  ('doctor','vitals.edit'),
  ('doctor','kyc.view'),('doctor','kyc.review'),
  ('doctor','risk_alert.view'),('doctor','risk_alert.respond'),
  ('doctor','kob.view'),('doctor','kob.manage_slots')
ON CONFLICT DO NOTHING;

-- ── ADMIN ──
INSERT INTO psy_role_permissions (staff_role, permission_code) VALUES
  ('admin','patient.view_all'),('admin','patient.create'),('admin','patient.edit'),
  ('admin','kyc.view'),('admin','kyc.review'),('admin','kyc.approve'),
  ('admin','vitals.view'),
  ('admin','assignment.view'),
  ('admin','plan.view'),
  ('admin','kob.view'),('admin','kob.create'),('admin','kob.manage_slots'),('admin','kob.recommend_package'),
  ('admin','inventory.view'),('admin','inventory.edit'),('admin','inventory.issue'),('admin','inventory.receive_return'),
  ('admin','product.view'),('admin','product.edit'),
  ('admin','orders.view'),('admin','orders.create'),
  ('admin','kit.view'),('admin','kit.edit'),
  ('admin','pakej.view'),('admin','pakej.edit'),
  ('admin','agreement.view'),('admin','agreement.sign'),
  ('admin','payment.view'),
  ('admin','surat.view'),('admin','surat.issue'),
  ('admin','library.view'),
  ('admin','announcement.view'),('admin','announcement.create'),('admin','announcement.edit'),
  ('admin','closures.view'),
  ('admin','kepatuhan.view'),
  ('admin','feedback.view'),
  ('admin','staff.view');

-- ── MANAGER (semua admin + extra) ──
INSERT INTO psy_role_permissions (staff_role, permission_code)
SELECT 'manager', permission_code FROM psy_role_permissions WHERE staff_role = 'admin';
INSERT INTO psy_role_permissions (staff_role, permission_code) VALUES
  ('manager','patient.delete'),
  ('manager','orders.approve'),
  ('manager','pakej.report'),
  ('manager','agreement.manage_clauses'),
  ('manager','payment.manage'),
  ('manager','surat.edit_template'),
  ('manager','library.edit'),
  ('manager','closures.manage'),
  ('manager','kepatuhan.manage'),
  ('manager','risk_alert.view'),
  ('manager','feedback.respond'),
  ('manager','audit.view'),
  ('manager','governance.view'),('manager','governance.manage'),
  ('manager','staff.manage'),('manager','staff.stats_view')
ON CONFLICT DO NOTHING;

-- ── SUPER ADMIN (semua) ──
INSERT INTO psy_role_permissions (staff_role, permission_code)
SELECT 'super_admin', code FROM psy_permissions
ON CONFLICT DO NOTHING;

SELECT staff_role, COUNT(*) AS jumlah_permission
FROM psy_role_permissions
GROUP BY staff_role
ORDER BY staff_role;


-- ════════════════════════════════════════════════════════════════
-- step_rbac_04_super_admin.sql
-- ════════════════════════════════════════════════════════════════

-- ============================================================
-- STEP RBAC 04 — ASSIGN SUPER ADMIN
-- Email: adminiswcustomer@ibnusinawellness.com
--
-- PRA-SYARAT:
--   Akaun mesti sudah signup melalui auth flow biasa
--   (psy_profiles row mesti wujud). Skrip ini tidak boleh cipta auth user.
-- ============================================================

UPDATE psy_profiles
SET role       = 'staff',
    staff_role = 'super_admin',
    updated_at = now()
WHERE email = 'adminiswcustomer@ibnusinawellness.com';

-- Verifikasi
SELECT email, full_name, role, staff_role, is_active
FROM psy_profiles
WHERE email = 'adminiswcustomer@ibnusinawellness.com';

-- Diagnostik: kalau kosong, ertinya belum signup
SELECT CASE
  WHEN EXISTS (SELECT 1 FROM psy_profiles WHERE email = 'adminiswcustomer@ibnusinawellness.com')
    THEN 'OK - super_admin assigned'
  ELSE 'BELUM SIGNUP - Daftar dulu via Sign Up page, kemudian run skrip ini semula'
END AS status;


-- ════════════════════════════════════════════════════════════════
-- step_rbac_05_v2_redesign.sql
-- ════════════════════════════════════════════════════════════════

-- ============================================================
-- STEP RBAC 05 — V2 REDESIGN (Module × Action matrix)
-- Refactor RBAC ikut mockup baru. Schema lama (step 01-03) di-drop
-- dan diganti dengan struktur Roles + Modules + Actions yang
-- boleh diurus sepenuhnya via UI.
--
-- AMARAN: Skrip ini akan DROP jadual psy_permissions, psy_role_permissions,
-- psy_user_permissions, dan view psy_user_effective_permissions.
-- Jalankan dengan teliti — semua mapping lama akan diseed semula di step_06.
-- ============================================================

-- 1) Drop schema lama
DROP VIEW  IF EXISTS psy_user_effective_permissions CASCADE;
DROP TABLE IF EXISTS psy_user_permissions          CASCADE;
DROP TABLE IF EXISTS psy_role_permissions          CASCADE;
DROP TABLE IF EXISTS psy_permissions               CASCADE;

-- 2) Buang CHECK constraint pada staff_role supaya boleh tambah role custom via UI
ALTER TABLE psy_profiles DROP CONSTRAINT IF EXISTS psy_profiles_staff_role_check;

-- 3) Roles (master list)
CREATE TABLE psy_roles (
  code        TEXT PRIMARY KEY,
  label       TEXT NOT NULL,
  description TEXT,
  color       TEXT DEFAULT 'navy',
  icon        TEXT DEFAULT '👤',
  is_active   BOOLEAN DEFAULT true,
  is_system   BOOLEAN DEFAULT false,
  sort_order  INT DEFAULT 100,
  created_at  TIMESTAMPTZ DEFAULT now(),
  updated_at  TIMESTAMPTZ DEFAULT now()
);

-- 4) Modules (master list of areas in the app)
CREATE TABLE psy_modules (
  code        TEXT PRIMARY KEY,
  label       TEXT NOT NULL,
  icon        TEXT,
  sort_order  INT DEFAULT 100,
  is_active   BOOLEAN DEFAULT true
);

-- 5) Actions (standard 6: Lihat / Tambah / Edit / Padam / Eksport / Tetapan)
CREATE TABLE psy_actions (
  code        TEXT PRIMARY KEY,
  label       TEXT NOT NULL,
  icon        TEXT,
  sort_order  INT DEFAULT 100
);

-- 6) Module × Action applicability — tentukan cell mana yang boleh ditick
--    Cell yang tiada dalam jadual ini akan paparkan "—" (Tidak Berkenaan)
CREATE TABLE psy_module_actions (
  module_code TEXT NOT NULL REFERENCES psy_modules(code) ON DELETE CASCADE,
  action_code TEXT NOT NULL REFERENCES psy_actions(code) ON DELETE CASCADE,
  PRIMARY KEY (module_code, action_code)
);

-- 7) Role → Module × Action grants (yang ditick "✓" dalam matrix)
CREATE TABLE psy_role_module_actions (
  role_code   TEXT NOT NULL REFERENCES psy_roles(code) ON DELETE CASCADE,
  module_code TEXT NOT NULL,
  action_code TEXT NOT NULL,
  created_at  TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (role_code, module_code, action_code),
  FOREIGN KEY (module_code, action_code) REFERENCES psy_module_actions(module_code, action_code) ON DELETE CASCADE
);

-- 8) User override (grant / revoke specific cell)
CREATE TABLE psy_user_overrides (
  user_id     UUID NOT NULL REFERENCES psy_profiles(id) ON DELETE CASCADE,
  module_code TEXT NOT NULL,
  action_code TEXT NOT NULL,
  grant_type  TEXT NOT NULL CHECK (grant_type IN ('grant','revoke')),
  granted_by  UUID REFERENCES psy_profiles(id),
  granted_at  TIMESTAMPTZ DEFAULT now(),
  reason      TEXT,
  PRIMARY KEY (user_id, module_code, action_code),
  FOREIGN KEY (module_code, action_code) REFERENCES psy_module_actions(module_code, action_code) ON DELETE CASCADE
);
CREATE INDEX idx_user_overrides_user ON psy_user_overrides(user_id);

-- 9) Audit log untuk setiap perubahan permission
CREATE TABLE psy_permission_audit (
  id          BIGSERIAL PRIMARY KEY,
  actor_id    UUID REFERENCES psy_profiles(id),
  actor_email TEXT,
  action      TEXT NOT NULL,
  target_type TEXT NOT NULL,
  target_id   TEXT NOT NULL,
  module_code TEXT,
  action_code TEXT,
  details     JSONB,
  created_at  TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX idx_perm_audit_created ON psy_permission_audit(created_at DESC);
CREATE INDEX idx_perm_audit_target  ON psy_permission_audit(target_type, target_id);

-- 10) View: effective permission per user (role default - revokes UNION grants)
CREATE OR REPLACE VIEW psy_user_effective_permissions AS
SELECT p.id AS user_id, rma.module_code, rma.action_code
FROM psy_profiles p
JOIN psy_role_module_actions rma ON rma.role_code = p.staff_role
WHERE NOT EXISTS (
  SELECT 1 FROM psy_user_overrides uo
  WHERE uo.user_id = p.id
    AND uo.module_code = rma.module_code
    AND uo.action_code = rma.action_code
    AND uo.grant_type = 'revoke'
)
UNION
SELECT user_id, module_code, action_code
FROM psy_user_overrides WHERE grant_type = 'grant';

-- 11) RLS
ALTER TABLE psy_roles                ENABLE ROW LEVEL SECURITY;
ALTER TABLE psy_modules              ENABLE ROW LEVEL SECURITY;
ALTER TABLE psy_actions              ENABLE ROW LEVEL SECURITY;
ALTER TABLE psy_module_actions       ENABLE ROW LEVEL SECURITY;
ALTER TABLE psy_role_module_actions  ENABLE ROW LEVEL SECURITY;
ALTER TABLE psy_user_overrides       ENABLE ROW LEVEL SECURITY;
ALTER TABLE psy_permission_audit     ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "r_read_all"   ON psy_roles               FOR SELECT USING (auth.role() = 'authenticated');
  CREATE POLICY "m_read_all"   ON psy_modules             FOR SELECT USING (auth.role() = 'authenticated');
  CREATE POLICY "a_read_all"   ON psy_actions             FOR SELECT USING (auth.role() = 'authenticated');
  CREATE POLICY "ma_read_all"  ON psy_module_actions      FOR SELECT USING (auth.role() = 'authenticated');
  CREATE POLICY "rma_read_all" ON psy_role_module_actions FOR SELECT USING (auth.role() = 'authenticated');
  CREATE POLICY "uo_read_all"  ON psy_user_overrides      FOR SELECT USING (auth.role() = 'authenticated');
  CREATE POLICY "au_read_all"  ON psy_permission_audit    FOR SELECT USING (
    EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND staff_role = 'super_admin')
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "r_write_sa"   ON psy_roles               FOR ALL
    USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND staff_role = 'super_admin'))
    WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND staff_role = 'super_admin'));
  CREATE POLICY "m_write_sa"   ON psy_modules             FOR ALL
    USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND staff_role = 'super_admin'))
    WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND staff_role = 'super_admin'));
  CREATE POLICY "a_write_sa"   ON psy_actions             FOR ALL
    USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND staff_role = 'super_admin'))
    WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND staff_role = 'super_admin'));
  CREATE POLICY "ma_write_sa"  ON psy_module_actions      FOR ALL
    USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND staff_role = 'super_admin'))
    WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND staff_role = 'super_admin'));
  CREATE POLICY "rma_write_sa" ON psy_role_module_actions FOR ALL
    USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND staff_role = 'super_admin'))
    WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND staff_role = 'super_admin'));
  CREATE POLICY "uo_write_sa"  ON psy_user_overrides      FOR ALL
    USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND staff_role = 'super_admin'))
    WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND staff_role = 'super_admin'));
  CREATE POLICY "au_write_sa"  ON psy_permission_audit    FOR INSERT
    WITH CHECK (auth.role() = 'authenticated');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

SELECT 'Step RBAC 05 OK — v2 schema ready' AS status;


-- ════════════════════════════════════════════════════════════════
-- step_rbac_06_v2_seed.sql
-- ════════════════════════════════════════════════════════════════

-- ============================================================
-- STEP RBAC 06 — SEED V2 (roles, modules, actions, defaults)
-- ============================================================

-- ── 1) Actions (6 standard) ──
INSERT INTO psy_actions (code, label, icon, sort_order) VALUES
  ('view',     'Lihat',    '👁️',  10),
  ('create',   'Tambah',   '➕',  20),
  ('edit',     'Edit',     '✏️',  30),
  ('delete',   'Padam',    '🗑️',  40),
  ('export',   'Eksport',  '📤',  50),
  ('settings', 'Tetapan',  '⚙️',  60)
ON CONFLICT (code) DO UPDATE SET label=EXCLUDED.label, icon=EXCLUDED.icon, sort_order=EXCLUDED.sort_order;

-- ── 2) Modules (13 group utama) ──
INSERT INTO psy_modules (code, label, icon, sort_order) VALUES
  ('dashboard',     'Dashboard',            '🏠',  10),
  ('patient',       'Pesakit & KYC',        '👥',  20),
  ('schedule',      'Kalender & Jadual',    '📅',  30),
  ('coaching',      'Coaching & Sesi',      '🧑‍🏫', 40),
  ('kob',           'KOB',                  '🩺',  50),
  ('inventory',     'Inventori & Produk',   '🏭',  60),
  ('orders',        'Orders & Tracking',    '📦',  70),
  ('package',       'Pakej & Pembayaran',   '💳',  80),
  ('communication', 'Komunikasi & Library', '📢',  90),
  ('operations',    'Operasi Klinik',       '⚙️', 100),
  ('reports',       'Laporan & Audit',      '📊', 110),
  ('staff',         'Pengurusan Staff',     '👨‍⚕️',120),
  ('rbac',          'Peranan & Kebenaran',  '🔐', 130)
ON CONFLICT (code) DO UPDATE SET label=EXCLUDED.label, icon=EXCLUDED.icon, sort_order=EXCLUDED.sort_order;

-- ── 3) Module × Action applicability ──
-- Dashboard hanya boleh "Lihat"
-- Audit/Reports tiada padam
-- RBAC tiada eksport
INSERT INTO psy_module_actions (module_code, action_code) VALUES
  ('dashboard','view'),

  ('patient','view'),('patient','create'),('patient','edit'),('patient','delete'),('patient','export'),('patient','settings'),

  ('schedule','view'),('schedule','create'),('schedule','edit'),('schedule','delete'),('schedule','export'),('schedule','settings'),

  ('coaching','view'),('coaching','create'),('coaching','edit'),('coaching','delete'),('coaching','export'),('coaching','settings'),

  ('kob','view'),('kob','create'),('kob','edit'),('kob','delete'),('kob','export'),('kob','settings'),

  ('inventory','view'),('inventory','create'),('inventory','edit'),('inventory','delete'),('inventory','export'),('inventory','settings'),

  ('orders','view'),('orders','create'),('orders','edit'),('orders','delete'),('orders','export'),('orders','settings'),

  ('package','view'),('package','create'),('package','edit'),('package','delete'),('package','export'),('package','settings'),

  ('communication','view'),('communication','create'),('communication','edit'),('communication','delete'),('communication','export'),('communication','settings'),

  ('operations','view'),('operations','create'),('operations','edit'),('operations','delete'),('operations','export'),('operations','settings'),

  ('reports','view'),('reports','export'),('reports','settings'),

  ('staff','view'),('staff','create'),('staff','edit'),('staff','delete'),('staff','export'),('staff','settings'),

  ('rbac','view'),('rbac','create'),('rbac','edit'),('rbac','delete'),('rbac','settings')
ON CONFLICT DO NOTHING;

-- ── 4) System Roles (5) ──
INSERT INTO psy_roles (code, label, description, color, icon, is_system, sort_order) VALUES
  ('super_admin', 'Super Admin', 'Akses penuh ke semua modul dan tetapan sistem.', 'purple', '🛡️', true, 10),
  ('manager',     'Manager',     'Pengurus klinik — operasi penuh + kewangan + governance.', 'navy', '👔', true, 20),
  ('admin',       'Admin',       'Admin operasi — urus pesakit, pakej, inventori, surat.', 'teal', '🧑‍💼', true, 30),
  ('doctor',      'Doctor',      'Doktor klinikal — pesakit, KYC, KOB, plan rawatan.', 'green', '🩺', true, 40),
  ('coach',       'Coach',       'Coach — pesakit ditugaskan, plan, sesi coaching.', 'gold', '🧑‍🏫', true, 50)
ON CONFLICT (code) DO UPDATE SET label=EXCLUDED.label, description=EXCLUDED.description, color=EXCLUDED.color, icon=EXCLUDED.icon, is_system=true;

-- ── 5) Role × Module × Action default grants ──
-- Super Admin: semua
INSERT INTO psy_role_module_actions (role_code, module_code, action_code)
SELECT 'super_admin', module_code, action_code FROM psy_module_actions
ON CONFLICT DO NOTHING;

-- Manager: semua kecuali rbac.create/edit/delete (hanya view)
INSERT INTO psy_role_module_actions (role_code, module_code, action_code)
SELECT 'manager', module_code, action_code FROM psy_module_actions
WHERE NOT (module_code = 'rbac' AND action_code IN ('create','edit','delete','settings'))
ON CONFLICT DO NOTHING;

-- Admin: operasi penuh, tiada governance/audit settings/staff manage/rbac
INSERT INTO psy_role_module_actions (role_code, module_code, action_code) VALUES
  ('admin','dashboard','view'),
  ('admin','patient','view'),('admin','patient','create'),('admin','patient','edit'),('admin','patient','export'),
  ('admin','schedule','view'),('admin','schedule','create'),('admin','schedule','edit'),('admin','schedule','delete'),
  ('admin','coaching','view'),
  ('admin','kob','view'),('admin','kob','create'),('admin','kob','edit'),('admin','kob','settings'),
  ('admin','inventory','view'),('admin','inventory','create'),('admin','inventory','edit'),('admin','inventory','delete'),('admin','inventory','export'),
  ('admin','orders','view'),('admin','orders','create'),('admin','orders','edit'),
  ('admin','package','view'),('admin','package','create'),('admin','package','edit'),
  ('admin','communication','view'),('admin','communication','create'),('admin','communication','edit'),('admin','communication','delete'),
  ('admin','operations','view'),
  ('admin','reports','view'),
  ('admin','staff','view')
ON CONFLICT DO NOTHING;

-- Doctor: klinikal
INSERT INTO psy_role_module_actions (role_code, module_code, action_code) VALUES
  ('doctor','dashboard','view'),
  ('doctor','patient','view'),('doctor','patient','edit'),
  ('doctor','schedule','view'),('doctor','schedule','create'),('doctor','schedule','edit'),
  ('doctor','coaching','view'),('doctor','coaching','create'),('doctor','coaching','edit'),
  ('doctor','kob','view'),('doctor','kob','create'),('doctor','kob','edit'),('doctor','kob','settings'),
  ('doctor','inventory','view'),
  ('doctor','communication','view'),
  ('doctor','operations','view')
ON CONFLICT DO NOTHING;

-- Coach: pesakit ditugaskan sahaja
INSERT INTO psy_role_module_actions (role_code, module_code, action_code) VALUES
  ('coach','dashboard','view'),
  ('coach','patient','view'),
  ('coach','schedule','view'),('coach','schedule','create'),('coach','schedule','edit'),
  ('coach','coaching','view'),('coach','coaching','create'),('coach','coaching','edit'),
  ('coach','inventory','view'),
  ('coach','communication','view'),
  ('coach','operations','view')
ON CONFLICT DO NOTHING;

-- ── 6) Pastikan adminiswcustomer kekal super_admin ──
UPDATE psy_profiles
SET staff_role = 'super_admin', updated_at = now()
WHERE email = 'adminiswcustomer@ibnusinawellness.com';

-- ── Verifikasi ──
SELECT
  (SELECT COUNT(*) FROM psy_roles)               AS roles,
  (SELECT COUNT(*) FROM psy_modules)             AS modules,
  (SELECT COUNT(*) FROM psy_actions)             AS actions,
  (SELECT COUNT(*) FROM psy_module_actions)      AS module_action_cells,
  (SELECT COUNT(*) FROM psy_role_module_actions) AS role_grants;

SELECT r.code, r.label, COUNT(rma.*) AS jumlah_kebenaran
FROM psy_roles r
LEFT JOIN psy_role_module_actions rma ON rma.role_code = r.code
GROUP BY r.code, r.label, r.sort_order
ORDER BY r.sort_order;


-- ════════════════════════════════════════════════════════════════
-- step_rbac_07_fix_fk_on_delete.sql
-- ════════════════════════════════════════════════════════════════

-- ============================================================
-- STEP RBAC 07 — FIX FK CONSTRAINTS untuk staff delete
-- Bila staff dipadam, kolum granted_by / actor_id sepatutnya jadi NULL,
-- bukan block delete.
-- ============================================================

-- psy_user_overrides.granted_by → SET NULL
ALTER TABLE psy_user_overrides
  DROP CONSTRAINT IF EXISTS psy_user_overrides_granted_by_fkey;
ALTER TABLE psy_user_overrides
  ADD CONSTRAINT psy_user_overrides_granted_by_fkey
  FOREIGN KEY (granted_by) REFERENCES psy_profiles(id) ON DELETE SET NULL;

-- psy_permission_audit.actor_id → SET NULL (rekod kekal, actor jadi NULL)
ALTER TABLE psy_permission_audit
  DROP CONSTRAINT IF EXISTS psy_permission_audit_actor_id_fkey;
ALTER TABLE psy_permission_audit
  ADD CONSTRAINT psy_permission_audit_actor_id_fkey
  FOREIGN KEY (actor_id) REFERENCES psy_profiles(id) ON DELETE SET NULL;

SELECT 'Step RBAC 07 OK — FK constraints fixed' AS status;


-- ════════════════════════════════════════════════════════════════
-- step_rbac_08_fix_all_profile_fks.sql
-- ════════════════════════════════════════════════════════════════

-- ============================================================
-- STEP RBAC 08 — FIX SEMUA FK ke psy_profiles
-- Tukar semua "NO ACTION" jadi:
--   • SET NULL untuk kolum audit trail (*_by, coach_id, staff_id, dll)
--   • CASCADE untuk kolum user_id (row milik user — kalau user dipadam,
--     row sepatutnya hilang juga)
-- Ni buatkan delete staff/patient tak block oleh FK.
-- ============================================================

-- Helper untuk replace constraint dengan cepat
-- (idempotent — kalau constraint tak wujud, ALTER akan continue)

-- ── SET NULL (audit / actor trail) ──

ALTER TABLE psy_adherence_alerts DROP CONSTRAINT IF EXISTS psy_adherence_alerts_notified_coach_id_fkey;
ALTER TABLE psy_adherence_alerts ADD  CONSTRAINT psy_adherence_alerts_notified_coach_id_fkey
  FOREIGN KEY (notified_coach_id) REFERENCES psy_profiles(id) ON DELETE SET NULL;

ALTER TABLE psy_adherence_alerts DROP CONSTRAINT IF EXISTS psy_adherence_alerts_acknowledged_by_fkey;
ALTER TABLE psy_adherence_alerts ADD  CONSTRAINT psy_adherence_alerts_acknowledged_by_fkey
  FOREIGN KEY (acknowledged_by) REFERENCES psy_profiles(id) ON DELETE SET NULL;

ALTER TABLE psy_appointments DROP CONSTRAINT IF EXISTS psy_appointments_staff_id_fkey;
ALTER TABLE psy_appointments ADD  CONSTRAINT psy_appointments_staff_id_fkey
  FOREIGN KEY (staff_id) REFERENCES psy_profiles(id) ON DELETE SET NULL;

ALTER TABLE psy_bottle_returns DROP CONSTRAINT IF EXISTS psy_bottle_returns_verified_by_fkey;
ALTER TABLE psy_bottle_returns ADD  CONSTRAINT psy_bottle_returns_verified_by_fkey
  FOREIGN KEY (verified_by) REFERENCES psy_profiles(id) ON DELETE SET NULL;

ALTER TABLE psy_coaching_catalog DROP CONSTRAINT IF EXISTS psy_coaching_catalog_created_by_fkey;
ALTER TABLE psy_coaching_catalog ADD  CONSTRAINT psy_coaching_catalog_created_by_fkey
  FOREIGN KEY (created_by) REFERENCES psy_profiles(id) ON DELETE SET NULL;

ALTER TABLE psy_coaching_sessions DROP CONSTRAINT IF EXISTS psy_coaching_sessions_coach_id_fkey;
ALTER TABLE psy_coaching_sessions ADD  CONSTRAINT psy_coaching_sessions_coach_id_fkey
  FOREIGN KEY (coach_id) REFERENCES psy_profiles(id) ON DELETE SET NULL;

ALTER TABLE psy_kyc_submissions DROP CONSTRAINT IF EXISTS psy_kyc_submissions_reviewed_by_fkey;
ALTER TABLE psy_kyc_submissions ADD  CONSTRAINT psy_kyc_submissions_reviewed_by_fkey
  FOREIGN KEY (reviewed_by) REFERENCES psy_profiles(id) ON DELETE SET NULL;

ALTER TABLE psy_letter_auto_fields DROP CONSTRAINT IF EXISTS psy_letter_auto_fields_created_by_fkey;
ALTER TABLE psy_letter_auto_fields ADD  CONSTRAINT psy_letter_auto_fields_created_by_fkey
  FOREIGN KEY (created_by) REFERENCES psy_profiles(id) ON DELETE SET NULL;

ALTER TABLE psy_letter_issued DROP CONSTRAINT IF EXISTS psy_letter_issued_signed_by_fkey;
ALTER TABLE psy_letter_issued ADD  CONSTRAINT psy_letter_issued_signed_by_fkey
  FOREIGN KEY (signed_by) REFERENCES psy_profiles(id) ON DELETE SET NULL;

-- psy_letter_template_overrides dropped in step_letter_simple — skip if not present
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'psy_letter_template_overrides') THEN
    ALTER TABLE psy_letter_template_overrides DROP CONSTRAINT IF EXISTS psy_letter_template_overrides_updated_by_fkey;
    ALTER TABLE psy_letter_template_overrides ADD CONSTRAINT psy_letter_template_overrides_updated_by_fkey
      FOREIGN KEY (updated_by) REFERENCES psy_profiles(id) ON DELETE SET NULL;
  END IF;
END $$;

ALTER TABLE psy_letter_templates DROP CONSTRAINT IF EXISTS psy_letter_templates_created_by_fkey;
ALTER TABLE psy_letter_templates ADD  CONSTRAINT psy_letter_templates_created_by_fkey
  FOREIGN KEY (created_by) REFERENCES psy_profiles(id) ON DELETE SET NULL;

ALTER TABLE psy_patients DROP CONSTRAINT IF EXISTS psy_patients_coach_id_fkey;
ALTER TABLE psy_patients ADD  CONSTRAINT psy_patients_coach_id_fkey
  FOREIGN KEY (coach_id) REFERENCES psy_profiles(id) ON DELETE SET NULL;

ALTER TABLE psy_plan_weekly_progress DROP CONSTRAINT IF EXISTS psy_plan_weekly_progress_updated_by_fkey;
ALTER TABLE psy_plan_weekly_progress ADD  CONSTRAINT psy_plan_weekly_progress_updated_by_fkey
  FOREIGN KEY (updated_by) REFERENCES psy_profiles(id) ON DELETE SET NULL;

ALTER TABLE psy_risk_alerts DROP CONSTRAINT IF EXISTS psy_risk_alerts_acknowledged_by_fkey;
ALTER TABLE psy_risk_alerts ADD  CONSTRAINT psy_risk_alerts_acknowledged_by_fkey
  FOREIGN KEY (acknowledged_by) REFERENCES psy_profiles(id) ON DELETE SET NULL;

ALTER TABLE psy_risk_alerts DROP CONSTRAINT IF EXISTS psy_risk_alerts_created_by_fkey;
ALTER TABLE psy_risk_alerts ADD  CONSTRAINT psy_risk_alerts_created_by_fkey
  FOREIGN KEY (created_by) REFERENCES psy_profiles(id) ON DELETE SET NULL;

ALTER TABLE psy_treatment_plans DROP CONSTRAINT IF EXISTS psy_treatment_plans_doctor_id_fkey;
ALTER TABLE psy_treatment_plans ADD  CONSTRAINT psy_treatment_plans_doctor_id_fkey
  FOREIGN KEY (doctor_id) REFERENCES psy_profiles(id) ON DELETE SET NULL;

ALTER TABLE psy_vitals DROP CONSTRAINT IF EXISTS psy_vitals_recorded_by_fkey;
ALTER TABLE psy_vitals ADD  CONSTRAINT psy_vitals_recorded_by_fkey
  FOREIGN KEY (recorded_by) REFERENCES psy_profiles(id) ON DELETE SET NULL;

-- ── CASCADE (kolum user_id — row milik user, hilang sekali) ──
-- Logik: kalau user (patient) dipadam, rekod patient/kyc/payment dia memang
-- patut ikut hilang. Untuk staff, kolum ni biasanya kosong jadi tak kena.

ALTER TABLE psy_patients DROP CONSTRAINT IF EXISTS psy_patients_user_id_fkey;
ALTER TABLE psy_patients ADD  CONSTRAINT psy_patients_user_id_fkey
  FOREIGN KEY (user_id) REFERENCES psy_profiles(id) ON DELETE CASCADE;

ALTER TABLE psy_kyc_submissions DROP CONSTRAINT IF EXISTS psy_kyc_submissions_user_id_fkey;
ALTER TABLE psy_kyc_submissions ADD  CONSTRAINT psy_kyc_submissions_user_id_fkey
  FOREIGN KEY (user_id) REFERENCES psy_profiles(id) ON DELETE CASCADE;

ALTER TABLE psy_payments DROP CONSTRAINT IF EXISTS psy_payments_user_id_fkey;
ALTER TABLE psy_payments ADD  CONSTRAINT psy_payments_user_id_fkey
  FOREIGN KEY (user_id) REFERENCES psy_profiles(id) ON DELETE CASCADE;

-- ── Verifikasi: pastikan tiada lagi "NO ACTION" ke psy_profiles ──
SELECT
  tc.table_schema || '.' || tc.table_name AS table_with_fk,
  kcu.column_name,
  rc.delete_rule
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
  ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage ccu
  ON tc.constraint_name = ccu.constraint_name
JOIN information_schema.referential_constraints rc
  ON tc.constraint_name = rc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND ccu.table_schema = 'public' AND ccu.table_name = 'psy_profiles'
  AND rc.delete_rule NOT IN ('CASCADE','SET NULL')
ORDER BY table_with_fk;

-- Kalau result query atas KOSONG, maksudnya semua FK dah handled.
SELECT 'Step RBAC 08 OK — semua FK psy_profiles handled' AS status;


-- ════════════════════════════════════════════════════════════════
-- step_rbac_09_rename_modules.sql
-- ════════════════════════════════════════════════════════════════

-- ============================================================
-- STEP RBAC 09 — RENAME MODULES untuk match navbar
-- ============================================================

UPDATE psy_modules SET label = 'Dashboard'           WHERE code = 'dashboard';
UPDATE psy_modules SET label = 'Pesakit & KYC'       WHERE code = 'patient';
UPDATE psy_modules SET label = 'Kalendar & Jadual'   WHERE code = 'schedule';
UPDATE psy_modules SET label = 'Rawatan & Sesi'      WHERE code = 'coaching';
UPDATE psy_modules SET label = 'KOB'                 WHERE code = 'kob';
UPDATE psy_modules SET label = 'Inventori & Produk'  WHERE code = 'inventory';
UPDATE psy_modules SET label = 'Orders & Tracking'   WHERE code = 'orders';
UPDATE psy_modules SET label = 'Pakej & Pembayaran'  WHERE code = 'package';
UPDATE psy_modules SET label = 'Komunikasi & Library' WHERE code = 'communication';
UPDATE psy_modules SET label = 'Operasi Klinik'      WHERE code = 'operations';
UPDATE psy_modules SET label = 'Laporan & Audit'     WHERE code = 'reports';
UPDATE psy_modules SET label = 'Manage Staff'        WHERE code = 'staff';
UPDATE psy_modules SET label = 'Peranan & Kebenaran' WHERE code = 'rbac';

SELECT code, label FROM psy_modules ORDER BY sort_order;


-- ════════════════════════════════════════════════════════════════
-- step_surat_rbac_tighten.sql
-- ════════════════════════════════════════════════════════════════

-- ============================================================
-- STEP SURAT — RLS tighten dengan RBAC
-- Sebelum: semua role='staff' boleh padam/edit template & surat issued
-- Selepas: kena ada effective permission communication.delete / edit
-- ============================================================

-- Helper function: cek user ada permission tertentu
CREATE OR REPLACE FUNCTION user_has_perm(p_module TEXT, p_action TEXT)
RETURNS BOOLEAN
LANGUAGE SQL STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM psy_user_effective_permissions
    WHERE user_id = auth.uid()
      AND module_code = p_module
      AND action_code = p_action
  );
$$;

-- ─────────────── TEMPLATES ───────────────
DROP POLICY IF EXISTS "Staff manage letter templates"  ON psy_letter_templates;
DROP POLICY IF EXISTS "Staff read letter templates"    ON psy_letter_templates;
DROP POLICY IF EXISTS "Staff insert letter templates"  ON psy_letter_templates;
DROP POLICY IF EXISTS "Staff update letter templates"  ON psy_letter_templates;
DROP POLICY IF EXISTS "Staff delete letter templates"  ON psy_letter_templates;

CREATE POLICY "tpl_select" ON psy_letter_templates FOR SELECT
  USING (user_has_perm('communication','view'));

CREATE POLICY "tpl_insert" ON psy_letter_templates FOR INSERT
  WITH CHECK (user_has_perm('communication','create'));

CREATE POLICY "tpl_update" ON psy_letter_templates FOR UPDATE
  USING (user_has_perm('communication','edit'))
  WITH CHECK (user_has_perm('communication','edit'));

CREATE POLICY "tpl_delete" ON psy_letter_templates FOR DELETE
  USING (user_has_perm('communication','delete'));

-- ─────────────── ISSUED LETTERS ───────────────
DROP POLICY IF EXISTS "Patient read own issued letters" ON psy_letter_issued;
DROP POLICY IF EXISTS "Staff manage issued letters"     ON psy_letter_issued;

-- Patient hanya boleh baca surat sendiri (kekal)
CREATE POLICY "issued_patient_read" ON psy_letter_issued FOR SELECT
  USING (
    patient_id IS NOT NULL
    AND patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid())
  );

-- Staff dengan view permission boleh baca semua
CREATE POLICY "issued_staff_read" ON psy_letter_issued FOR SELECT
  USING (user_has_perm('communication','view'));

CREATE POLICY "issued_staff_insert" ON psy_letter_issued FOR INSERT
  WITH CHECK (user_has_perm('communication','create'));

CREATE POLICY "issued_staff_update" ON psy_letter_issued FOR UPDATE
  USING (user_has_perm('communication','edit'))
  WITH CHECK (user_has_perm('communication','edit'));

CREATE POLICY "issued_staff_delete" ON psy_letter_issued FOR DELETE
  USING (user_has_perm('communication','delete'));

-- ─────────────── LETTER REQUESTS ───────────────
-- Patient policy kekal (manage own)
DROP POLICY IF EXISTS "Staff read all letter requests"   ON psy_letter_requests;
DROP POLICY IF EXISTS "Staff update letter requests"     ON psy_letter_requests;

CREATE POLICY "req_staff_read" ON psy_letter_requests FOR SELECT
  USING (user_has_perm('communication','view'));

CREATE POLICY "req_staff_update" ON psy_letter_requests FOR UPDATE
  USING (user_has_perm('communication','edit'))
  WITH CHECK (user_has_perm('communication','edit'));

CREATE POLICY "req_staff_delete" ON psy_letter_requests FOR DELETE
  USING (user_has_perm('communication','delete'));

SELECT 'Step Surat RBAC OK — RLS tightened via permission check' AS status;


-- ════════════════════════════════════════════════════════════════
-- step_cleanup_session_no.sql
-- ════════════════════════════════════════════════════════════════

-- ============================================================
-- CLEANUP — buang session_no + constraint yang saya tersilap tambah
-- Sistem sudah ada session_day untuk handle 2 sesi/minggu.
-- Jalankan SEKALI sahaja.
-- ============================================================

-- Drop the wrong constraint
ALTER TABLE psy_plan_weekly_progress
  DROP CONSTRAINT IF EXISTS psy_plan_weekly_progress_plan_week_session_unique;

-- Drop the duplicate column
ALTER TABLE psy_plan_weekly_progress
  DROP COLUMN IF EXISTS session_no;

-- Drop the redundant index (kalau wujud)
DROP INDEX IF EXISTS idx_plan_progress_week_session;

-- Verifikasi: constraint yang betul masih ada (session_day-based)
SELECT conname
FROM pg_constraint
WHERE conrelid = 'psy_plan_weekly_progress'::regclass
  AND contype = 'u'
ORDER BY conname;

-- Verifikasi: column session_day masih ada
SELECT column_name, data_type, column_default
FROM information_schema.columns
WHERE table_name = 'psy_plan_weekly_progress'
  AND column_name IN ('session_day', 'session_no');

SELECT 'OK — session_no removed, system uses session_day' AS status;


-- ════════════════════════════════════════════════════════════════
-- step_patient_plan_setup_rls.sql
-- ════════════════════════════════════════════════════════════════

-- ============================================================
-- STEP — Patient Plan Setup RLS
-- Benarkan patient update plan SENDIRI untuk setup jadual sahaja
-- (preferred_pair, preferred_time_day1/2, schedule_setup_at).
-- Bukan kebenaran penuh — staff masih perlu untuk ubah status,
-- duration, goals, dsb.
-- ============================================================

DO $$ BEGIN
  CREATE POLICY "Patients update own plan setup"
  ON psy_treatment_plans
  FOR UPDATE
  USING (
    patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid())
  )
  WITH CHECK (
    patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid())
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- NOTA: Policy ni bagi UPDATE pada SEMUA column untuk patient sendiri.
-- Kalau mahu lebih ketat (cth: cuma boleh update preferred_pair + masa),
-- guna kombinasi dengan trigger BEFORE UPDATE untuk reject column lain.
-- Untuk MVP, ini cukup sebab UI patient hanya expose 4 field setup.

SELECT 'OK — patient plan setup RLS policy added' AS status;


-- ════════════════════════════════════════════════════════════════
-- step_patient_docs_week_scope.sql
-- ════════════════════════════════════════════════════════════════

-- ============================================================
-- step_patient_docs_week_scope.sql  (idempotent)
-- Benarkan dokumen pesakit diskop ikut plan + minggu.
--   • plan_id NULL + week_number NULL  -> dokumen umum (Patient Hub)
--   • plan_id + week_number diisi       -> dokumen khusus minggu (plan-week)
-- ============================================================

ALTER TABLE psy_patient_documents
  ADD COLUMN IF NOT EXISTS plan_id     UUID REFERENCES psy_treatment_plans(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS week_number INT;

CREATE INDEX IF NOT EXISTS idx_patient_docs_plan_week
  ON psy_patient_documents (plan_id, week_number)
  WHERE plan_id IS NOT NULL;

COMMENT ON COLUMN psy_patient_documents.plan_id IS
  'Jika diisi, dokumen ini dilampirkan pada plan rawatan tertentu (skop minggu).';
COMMENT ON COLUMN psy_patient_documents.week_number IS
  'Nombor minggu plan untuk dokumen ini (NULL = dokumen umum pesakit).';

SELECT 'OK — psy_patient_documents plan_id + week_number ready' AS status;


-- ════════════════════════════════════════════════════════════════
-- step_fix_patient_mrn_autogen.sql
-- ════════════════════════════════════════════════════════════════

-- ============================================================
-- FIX: Auto-generate MRN untuk patient bila tidak dibekalkan
-- Punca: client tak boleh query MRN tertinggi sebab RLS, jadi
-- collision MRN biasa berlaku semasa self-signup.
-- Fix: trigger BEFORE INSERT yang auto-assign MRN unik.
-- ============================================================

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

-- Allow client untuk insert TANPA mrn (sebelum ni NOT NULL constraint blok ni)
ALTER TABLE psy_patients ALTER COLUMN mrn DROP NOT NULL;

SELECT 'OK — patient MRN auto-gen trigger ready' AS status;


-- ════════════════════════════════════════════════════════════════
-- step_fix_slot_rls_superadmin.sql
-- ════════════════════════════════════════════════════════════════

-- ============================================================
-- FIX: Tambah super_admin ke RLS policy untuk slot config + override
-- ============================================================

-- ── psy_kob_slot_config ──
DROP POLICY IF EXISTS "Admin manage kob slots" ON psy_kob_slot_config;
CREATE POLICY "Admin manage kob slots" ON psy_kob_slot_config FOR ALL
  USING (EXISTS (
    SELECT 1 FROM psy_profiles
    WHERE id = auth.uid() AND role = 'staff'
      AND staff_role IN ('admin','manager','doctor','super_admin')
  ));

-- ── psy_slot_date_overrides (kalau wujud dari step47) ──
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'psy_slot_date_overrides') THEN
    DROP POLICY IF EXISTS "Staff manage slot overrides" ON psy_slot_date_overrides;
    CREATE POLICY "Staff manage slot overrides" ON psy_slot_date_overrides FOR ALL
      USING (EXISTS (
        SELECT 1 FROM psy_profiles
        WHERE id = auth.uid() AND role = 'staff'
          AND staff_role IN ('admin','manager','doctor','super_admin')
      ));
  END IF;
END $$;

SELECT 'OK — super_admin boleh manage slot sekarang' AS status;


-- ════════════════════════════════════════════════════════════════
-- step_create_avatars_bucket.sql
-- ════════════════════════════════════════════════════════════════

-- ============================================================
-- Cipta storage bucket 'avatars' + policy
-- Untuk upload profile picture staff & patient
-- ============================================================

-- Cipta bucket public (boleh accessed tanpa auth — sebab profile pic biasanya public)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('avatars', 'avatars', true, 5242880, ARRAY['image/png','image/jpeg','image/jpg','image/webp','image/gif'])
ON CONFLICT (id) DO UPDATE
  SET public = EXCLUDED.public,
      file_size_limit = EXCLUDED.file_size_limit,
      allowed_mime_types = EXCLUDED.allowed_mime_types;

-- Policies: authenticated user boleh upload, sesiapa boleh lihat
DO $$ BEGIN
  CREATE POLICY "avatars_public_read" ON storage.objects FOR SELECT
    USING (bucket_id = 'avatars');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "avatars_authenticated_upload" ON storage.objects FOR INSERT
    WITH CHECK (bucket_id = 'avatars' AND auth.role() = 'authenticated');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "avatars_owner_update" ON storage.objects FOR UPDATE
    USING (bucket_id = 'avatars' AND auth.uid()::text = (storage.foldername(name))[1])
    WITH CHECK (bucket_id = 'avatars' AND auth.uid()::text = (storage.foldername(name))[1]);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "avatars_owner_delete" ON storage.objects FOR DELETE
    USING (bucket_id = 'avatars' AND auth.uid()::text = (storage.foldername(name))[1]);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

SELECT 'OK — avatars bucket created' AS status;


-- ════════════════════════════════════════════════════════════════
-- step_agreement_delete_policy.sql
-- ════════════════════════════════════════════════════════════════

-- ============================================================
-- FIX: Patient delete agreement sendiri sebelum doktor finalize
-- ============================================================

DO $$ BEGIN
  CREATE POLICY "Patient cancel own unfinalized agreement"
    ON psy_kob_agreements FOR DELETE
    USING (
      patient_id IN (
        SELECT id FROM psy_patients
        WHERE user_id = auth.uid()
          AND (kob_status IS NULL OR kob_status != 'completed')
      )
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

SELECT 'OK — patient boleh padam agreement sendiri sebelum kob_status=completed' AS status;


-- ════════════════════════════════════════════════════════════════
-- fix_audit_policy.sql
-- ════════════════════════════════════════════════════════════════

-- Fix RLS policy for psy_audit_log — allow any authenticated user to insert
DROP POLICY IF EXISTS "All authenticated insert audit" ON psy_audit_log;
CREATE POLICY "All authenticated insert audit" ON psy_audit_log FOR INSERT
  WITH CHECK (true);

SELECT 'Fix OK — audit_log insert policy updated' AS status;


-- ════════════════════════════════════════════════════════════════
-- fix_coach_assignment.sql
-- ════════════════════════════════════════════════════════════════

-- ============================================================
-- FIX: Coach Assignment Columns
-- Run this in Supabase SQL Editor to enable "Assign to me"
-- ============================================================

-- 1. Add coach_id and assigned_at to psy_patients
ALTER TABLE psy_patients
  ADD COLUMN IF NOT EXISTS coach_id UUID REFERENCES psy_profiles(id),
  ADD COLUMN IF NOT EXISTS assigned_at TIMESTAMPTZ;

-- 2. Index for fast coach lookup
CREATE INDEX IF NOT EXISTS idx_psy_patients_coach ON psy_patients(coach_id);

-- 3. Make sure staff can update these columns (policy already covers FOR ALL)
-- No change needed — existing "Staff manage patients" policy covers UPDATE

SELECT 'Fix OK — coach_id + assigned_at columns are ready' AS status;


-- ════════════════════════════════════════════════════════════════
-- fix_issue_patient_read.sql
-- ════════════════════════════════════════════════════════════════

-- Allow patients to read their own issues, staff replies, and their own follow-ups
-- Run this in Supabase SQL Editor

-- Drop old policy first if exists
DROP POLICY IF EXISTS "Patients read own issues" ON psy_audit_log;

-- Recreate with followup included
CREATE POLICY "Patients read own issues" ON psy_audit_log FOR SELECT
  USING (
    (action IN ('issue.reported', 'issue.followup') AND actor_id = auth.uid())
    OR (action = 'issue.responded' AND target = auth.uid()::text)
  );

SELECT 'Fix OK — patients can read reported, responded, and followup entries' AS status;


-- ════════════════════════════════════════════════════════════════
-- fix_staff_delete_fk.sql
-- ════════════════════════════════════════════════════════════════

-- ============================================================
-- FIX: Staff & Patient delete FK constraints
-- Run dalam Supabase SQL Editor
-- ============================================================

-- ── STAFF REFERENCES → SET NULL ──────────────────────────────

ALTER TABLE psy_appointments
  DROP CONSTRAINT IF EXISTS psy_appointments_staff_id_fkey;
ALTER TABLE psy_appointments
  ADD CONSTRAINT psy_appointments_staff_id_fkey
  FOREIGN KEY (staff_id) REFERENCES psy_profiles(id) ON DELETE SET NULL;

ALTER TABLE psy_treatment_plans
  DROP CONSTRAINT IF EXISTS psy_treatment_plans_doctor_id_fkey;
ALTER TABLE psy_treatment_plans
  ADD CONSTRAINT psy_treatment_plans_doctor_id_fkey
  FOREIGN KEY (doctor_id) REFERENCES psy_profiles(id) ON DELETE SET NULL;

ALTER TABLE psy_kyc_submissions
  DROP CONSTRAINT IF EXISTS psy_kyc_submissions_reviewed_by_fkey;
ALTER TABLE psy_kyc_submissions
  ADD CONSTRAINT psy_kyc_submissions_reviewed_by_fkey
  FOREIGN KEY (reviewed_by) REFERENCES psy_profiles(id) ON DELETE SET NULL;

ALTER TABLE psy_plan_weekly_progress
  DROP CONSTRAINT IF EXISTS psy_plan_weekly_progress_updated_by_fkey;
ALTER TABLE psy_plan_weekly_progress
  ADD CONSTRAINT psy_plan_weekly_progress_updated_by_fkey
  FOREIGN KEY (updated_by) REFERENCES psy_profiles(id) ON DELETE SET NULL;

-- coach_id ditambah dalam step13
ALTER TABLE psy_patients
  DROP CONSTRAINT IF EXISTS psy_patients_coach_id_fkey;
ALTER TABLE psy_patients
  ADD CONSTRAINT psy_patients_coach_id_fkey
  FOREIGN KEY (coach_id) REFERENCES psy_profiles(id) ON DELETE SET NULL;

-- ── PATIENT REFERENCES → CASCADE ─────────────────────────────

ALTER TABLE psy_patients
  DROP CONSTRAINT IF EXISTS psy_patients_user_id_fkey;
ALTER TABLE psy_patients
  ADD CONSTRAINT psy_patients_user_id_fkey
  FOREIGN KEY (user_id) REFERENCES psy_profiles(id) ON DELETE CASCADE;

ALTER TABLE psy_kyc_submissions
  DROP CONSTRAINT IF EXISTS psy_kyc_submissions_user_id_fkey;
ALTER TABLE psy_kyc_submissions
  ADD CONSTRAINT psy_kyc_submissions_user_id_fkey
  FOREIGN KEY (user_id) REFERENCES psy_profiles(id) ON DELETE CASCADE;

ALTER TABLE psy_payments
  DROP CONSTRAINT IF EXISTS psy_payments_user_id_fkey;
ALTER TABLE psy_payments
  ADD CONSTRAINT psy_payments_user_id_fkey
  FOREIGN KEY (user_id) REFERENCES psy_profiles(id) ON DELETE CASCADE;

SELECT 'FK fix OK — delete staff/patient sekarang berfungsi' AS status;


-- ════════════════════════════════════════════════════════════════
-- fix_staff_rls.sql
-- ════════════════════════════════════════════════════════════════

-- ============================================================
-- Fix RLS: Allow staff to read patient profiles & plans
-- Run AFTER step16_missing_tables.sql
-- Run in Supabase SQL Editor
-- ============================================================

-- NOTE: psy_profiles already has "Read all profiles authenticated" policy (step1)
-- Adding another SELECT policy with a self-referencing subquery causes recursion
-- No change needed for psy_profiles

-- 1. Staff can read all treatment plans
DROP POLICY IF EXISTS "Staff can read all treatment plans" ON psy_treatment_plans;
CREATE POLICY "Staff can read all treatment plans"
  ON psy_treatment_plans FOR SELECT
  USING (
    auth.uid() IN (
      SELECT id FROM psy_profiles WHERE role = 'staff'
    )
    OR auth.uid() IN (
      SELECT user_id FROM psy_patients WHERE id = patient_id
    )
  );

-- 3. Staff can read all weekly progress
DROP POLICY IF EXISTS "Staff can read all weekly progress" ON psy_plan_weekly_progress;
CREATE POLICY "Staff can read all weekly progress"
  ON psy_plan_weekly_progress FOR SELECT
  USING (
    auth.uid() IN (SELECT id FROM psy_profiles WHERE role = 'staff')
    OR auth.uid() IN (SELECT user_id FROM psy_patients WHERE id = patient_id)
  );

-- 4. Staff can read all compliance records
DROP POLICY IF EXISTS "Staff can read all compliance" ON psy_plan_compliance;
CREATE POLICY "Staff can read all compliance"
  ON psy_plan_compliance FOR SELECT
  USING (
    auth.uid() IN (SELECT id FROM psy_profiles WHERE role = 'staff')
    OR auth.uid() IN (SELECT user_id FROM psy_patients WHERE id = patient_id)
  );

-- 5. Staff can read all daily checkins
DROP POLICY IF EXISTS "Staff can read all checkins" ON psy_daily_checkins;
CREATE POLICY "Staff can read all checkins"
  ON psy_daily_checkins FOR SELECT
  USING (
    auth.uid() IN (SELECT id FROM psy_profiles WHERE role = 'staff')
    OR auth.uid() IN (SELECT user_id FROM psy_patients WHERE id = patient_id)
  );

-- 6. Staff can read all KYC submissions
DROP POLICY IF EXISTS "Staff can read all kyc" ON psy_kyc_submissions;
CREATE POLICY "Staff can read all kyc"
  ON psy_kyc_submissions FOR SELECT
  USING (
    auth.uid() IN (SELECT id FROM psy_profiles WHERE role = 'staff')
    OR auth.uid() = user_id
  );

SELECT 'RLS fix OK — staff can now read all patient data' AS status;
