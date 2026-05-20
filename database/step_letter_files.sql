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
