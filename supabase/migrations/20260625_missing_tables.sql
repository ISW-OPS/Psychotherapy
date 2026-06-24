-- ════════════════════════════════════════════════════════════════
-- Missing tables — 25 Jun 2026
-- Mencipta 3 jadual yang dirujuk dalam HTML tetapi tidak wujud
-- dalam skema DB, menyebabkan ciri-ciri ini rosak sepenuhnya:
--   1. psy_soap_notes  — nota SOAP doktor (consultation.html, profile.html, plan-week.html)
--   2. psy_faq_sections + psy_faq_items — halaman FAQ (faq-overhaul.html)
-- Idempotent: CREATE TABLE IF NOT EXISTS.
-- ════════════════════════════════════════════════════════════════

-- ────────────────────────────────────────────────────────────────
-- 1. psy_soap_notes — rekod klinikal SOAP oleh doktor
-- ────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS psy_soap_notes (
  id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id         UUID NOT NULL REFERENCES psy_patients(id) ON DELETE CASCADE,
  doctor_id          UUID NOT NULL REFERENCES auth.users(id),
  chief_complaint    TEXT,
  hpi                TEXT,    -- History of Present Illness
  examination        TEXT,
  diagnoses          TEXT[] DEFAULT '{}',
  clinical_reasoning TEXT,
  plan_medications   TEXT[] DEFAULT '{}',
  plan_labs          TEXT[] DEFAULT '{}',
  follow_up          TEXT,
  status             TEXT NOT NULL DEFAULT 'draft'
                     CHECK (status IN ('draft', 'signed')),
  signed_at          TIMESTAMPTZ,
  created_at         TIMESTAMPTZ DEFAULT now(),
  updated_at         TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE psy_soap_notes ENABLE ROW LEVEL SECURITY;

-- Doktor/admin boleh insert/update/read nota SOAP
DO $$ BEGIN
  CREATE POLICY "soap_notes_staff_all" ON psy_soap_notes FOR ALL
    USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
    WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Pesakit hanya boleh baca nota bertanda 'signed' milik mereka sendiri
DO $$ BEGIN
  CREATE POLICY "soap_notes_patient_read" ON psy_soap_notes FOR SELECT
    USING (
      status = 'signed'
      AND patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid())
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE INDEX IF NOT EXISTS idx_soap_notes_patient ON psy_soap_notes(patient_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_soap_notes_doctor  ON psy_soap_notes(doctor_id, created_at DESC);

-- ────────────────────────────────────────────────────────────────
-- 2. psy_faq_sections — bahagian FAQ (cth "Umum", "Rawatan")
-- ────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS psy_faq_sections (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code       TEXT NOT NULL UNIQUE,   -- 'umum', 'rawatan', dsb.
  title      TEXT NOT NULL,
  sort_order INT  NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE psy_faq_sections ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "faq_sections_staff_all" ON psy_faq_sections FOR ALL
    USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
    WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "faq_sections_public_read" ON psy_faq_sections FOR SELECT
    USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ────────────────────────────────────────────────────────────────
-- 3. psy_faq_items — soal jawab individu dalam setiap bahagian
-- ────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS psy_faq_items (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  section_id UUID NOT NULL REFERENCES psy_faq_sections(id) ON DELETE CASCADE,
  soalan     TEXT NOT NULL,
  jawapan    TEXT NOT NULL,
  sort_order INT  NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE psy_faq_items ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "faq_items_staff_all" ON psy_faq_items FOR ALL
    USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
    WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "faq_items_public_read" ON psy_faq_items FOR SELECT
    USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE INDEX IF NOT EXISTS idx_faq_items_section ON psy_faq_items(section_id, sort_order);

-- ────────────────────────────────────────────────────────────────
-- 4. check_referral_code RPC — semak sama ada kod rujukan wujud
--    SECURITY DEFINER supaya pesakit baru boleh semak tanpa RLS.
-- ────────────────────────────────────────────────────────────────
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

-- Seed: bahagian FAQ asas
INSERT INTO psy_faq_sections (code, title, sort_order) VALUES
  ('umum',     'Soalan Umum',                 1),
  ('rawatan',  'Tentang Rawatan',             2),
  ('pakej',    'Pakej & Pembayaran',          3),
  ('kepatuhan','Kepatuhan & Catatan Harian',  4),
  ('teknikal', 'Teknikal & Akaun',            5)
ON CONFLICT (code) DO NOTHING;
-- ════════════════════════════════════════════════════════════════
