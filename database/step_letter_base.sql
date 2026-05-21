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
