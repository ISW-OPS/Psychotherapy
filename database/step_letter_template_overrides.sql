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
