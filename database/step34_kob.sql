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
