-- ═══════════════════════════════════════════════════════════════════
-- SKEMA: Rekod Perubatan Pesakit (Medical Records)
-- Jadual: psy_medical_reports, psy_medical_report_comments
-- Nota: psy_dna_reports (legasi) telah dinamakan semula ke
--       psy_medical_reports — hanya nama akhir digunakan di sini.
-- ═══════════════════════════════════════════════════════════════════

-- ──── psy_medical_reports — laporan perubatan pesakit ────
-- Diupload oleh staff ATAU pesakit sendiri; mengalir ke patient-hub
-- doktor untuk semakan.

CREATE TABLE IF NOT EXISTS psy_medical_reports (
  id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id              UUID NOT NULL REFERENCES psy_patients(id) ON DELETE CASCADE,
  file_name               TEXT NOT NULL,
  file_path               TEXT NOT NULL,
  file_url                TEXT NOT NULL,
  notes                   TEXT,
  uploaded_by             UUID REFERENCES auth.users(id),
  uploaded_by_name        TEXT,
  uploaded_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  report_type             TEXT DEFAULT 'dna',
  title                   TEXT,
  status                  TEXT DEFAULT 'pending',
  sample_date             DATE,
  sample_type             TEXT,
  result_date             DATE,
  analysis_duration_days  INT,
  categories              JSONB DEFAULT '{}',
  summary                 TEXT,
  doctor_id               UUID,
  doctor_name             TEXT,
  doctor_review           TEXT,
  review_status           TEXT DEFAULT 'pending',
  reviewed_at             TIMESTAMPTZ,
  shared_with_patient     BOOLEAN DEFAULT false,
  shared_at               TIMESTAMPTZ,
  attached_files          JSONB DEFAULT '[]',
  source                  TEXT,
  file_size               BIGINT
);

CREATE INDEX IF NOT EXISTS idx_medical_reports_patient ON psy_medical_reports(patient_id, uploaded_at DESC);
CREATE INDEX IF NOT EXISTS idx_medical_reports_type    ON psy_medical_reports(report_type);

ALTER TABLE psy_medical_reports ENABLE ROW LEVEL SECURITY;

-- Staff urus semua laporan
DROP POLICY IF EXISTS "staff_medical_all" ON psy_medical_reports;
CREATE POLICY "staff_medical_all" ON psy_medical_reports FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- Pesakit baca laporan sendiri
DROP POLICY IF EXISTS "patient_medical_read" ON psy_medical_reports;
CREATE POLICY "patient_medical_read" ON psy_medical_reports FOR SELECT
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

-- Pesakit boleh INSERT laporan sendiri
DROP POLICY IF EXISTS "patient_medical_insert" ON psy_medical_reports;
CREATE POLICY "patient_medical_insert" ON psy_medical_reports FOR INSERT
  WITH CHECK (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

-- Pesakit boleh PADAM laporan yang dia upload sendiri (belum disemak)
DROP POLICY IF EXISTS "patient_medical_delete_own" ON psy_medical_reports;
CREATE POLICY "patient_medical_delete_own" ON psy_medical_reports FOR DELETE
  USING (
    uploaded_by = auth.uid()
    AND patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid())
    AND COALESCE(review_status,'pending') = 'pending'
  );

COMMENT ON COLUMN psy_medical_reports.report_type IS
  'dna | xray | ct | mri | ultrasound | blood | colonoscopy | endoscopy | other';
COMMENT ON COLUMN psy_medical_reports.status IS
  'pending | sampling | lab | ready | reviewed';
COMMENT ON COLUMN psy_medical_reports.review_status IS
  'pending | diluluskan | ditolak';

-- ──── psy_medical_report_comments — thread komen doktor ────
-- Banyak komen / banyak doktor per laporan.

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
DROP POLICY IF EXISTS "staff_comments_all" ON psy_medical_report_comments;
CREATE POLICY "staff_comments_all" ON psy_medical_report_comments FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
  WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- Pesakit baca komen pada laporan sendiri
DROP POLICY IF EXISTS "patient_read_comments" ON psy_medical_report_comments;
CREATE POLICY "patient_read_comments" ON psy_medical_report_comments FOR SELECT
  USING (report_id IN (
    SELECT id FROM psy_medical_reports
    WHERE patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid())
  ));
