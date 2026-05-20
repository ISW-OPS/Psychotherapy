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
