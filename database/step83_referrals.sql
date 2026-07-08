-- ═══════════════════════════════════════════════════════════════
-- step83: Rujukan Klinikal Pesakit (care referral) — Jul 2026
-- Coach/staff rujuk pesakit kepada doctor / coach lain / manager
-- (Hakeem/Hakeema). Sasaran dipilih secara spesifik (target_id).
-- NOTA: `psy_referrals` sedia ada = sistem GANJARAN rujukan pesakit-ke-
-- pesakit (marketing). Ini feature BERBEZA → guna `psy_clinical_referrals`.
-- Notifikasi guna psy_notifications type 'referral'.
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS psy_clinical_referrals (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id       UUID NOT NULL REFERENCES psy_patients(id) ON DELETE CASCADE,
  referred_by      UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  referred_by_name TEXT,
  target_role      TEXT NOT NULL CHECK (target_role IN ('doctor','coach','manager')),
  target_id        UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  target_name      TEXT,
  reason           TEXT NOT NULL,
  meet_date        DATE,                    -- tarikh pesakit perlu jumpa (dari jadual rawatan)
  priority         TEXT NOT NULL DEFAULT 'sederhana' CHECK (priority IN ('rendah','sederhana','tinggi')),
  status           TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','accepted','resolved','declined')),
  resolution_note   TEXT,
  consultation_note TEXT,                       -- nota sesi rujukan (Hakeem/doctor/coach)
  attachments       JSONB DEFAULT '[]'::jsonb,  -- transkrip/dokumen: [{name,path,uploaded_at}]
  created_at       TIMESTAMPTZ DEFAULT now(),
  updated_at       TIMESTAMPTZ DEFAULT now(),
  resolved_at      TIMESTAMPTZ
);
-- Tambah kolum kalau jadual dah wujud dari run terdahulu (idempotent)
ALTER TABLE psy_clinical_referrals
  ADD COLUMN IF NOT EXISTS meet_date DATE,
  ADD COLUMN IF NOT EXISTS consultation_note TEXT,
  ADD COLUMN IF NOT EXISTS attachments JSONB DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS consultation JSONB DEFAULT '{}'::jsonb;  -- borang konsultasi berstruktur

-- Priori 3-tahap (rendah/sederhana/tinggi) — naik taraf dari biasa/segera
UPDATE psy_clinical_referrals SET priority = CASE WHEN priority = 'segera' THEN 'tinggi' WHEN priority = 'biasa' THEN 'sederhana' ELSE priority END
  WHERE priority NOT IN ('rendah','sederhana','tinggi');
ALTER TABLE psy_clinical_referrals DROP CONSTRAINT IF EXISTS psy_clinical_referrals_priority_check;
ALTER TABLE psy_clinical_referrals ALTER COLUMN priority SET DEFAULT 'sederhana';
ALTER TABLE psy_clinical_referrals ADD CONSTRAINT psy_clinical_referrals_priority_check CHECK (priority IN ('rendah','sederhana','tinggi'));
NOTIFY pgrst, 'reload schema';

ALTER TABLE psy_clinical_referrals ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  CREATE POLICY "Staff manage clinical referrals" ON psy_clinical_referrals FOR ALL
    USING      (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
    WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE INDEX IF NOT EXISTS idx_psy_clinical_referrals_target  ON psy_clinical_referrals(target_id, status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_psy_clinical_referrals_patient ON psy_clinical_referrals(patient_id, created_at DESC);

-- Benarkan jenis notifikasi 'referral'
DO $$ DECLARE r RECORD; BEGIN
  FOR r IN SELECT conname FROM pg_constraint
    WHERE conrelid = 'psy_notifications'::regclass AND contype = 'c'
      AND pg_get_constraintdef(oid) LIKE '%type%'
  LOOP EXECUTE 'ALTER TABLE psy_notifications DROP CONSTRAINT ' || quote_ident(r.conname); END LOOP;
END $$;
ALTER TABLE psy_notifications ADD CONSTRAINT psy_notifications_type_check
  CHECK (type IN ('appointment','order','plan','system','reaksi','kyc','referral'));

-- Storage bucket untuk transkrip/dokumen rujukan (private, staff sahaja)
INSERT INTO storage.buckets (id, name, public) VALUES ('referral-docs', 'referral-docs', false) ON CONFLICT DO NOTHING;
DO $$ BEGIN
  CREATE POLICY "Staff upload referral docs" ON storage.objects FOR INSERT
    WITH CHECK (bucket_id = 'referral-docs' AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "Staff read referral docs" ON storage.objects FOR SELECT
    USING (bucket_id = 'referral-docs' AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "Staff delete referral docs" ON storage.objects FOR DELETE
    USING (bucket_id = 'referral-docs' AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

SELECT 'Step 83 OK -- psy_clinical_referrals + docs bucket + referral notif type' AS status;
