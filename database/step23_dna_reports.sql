-- DNA Reports table
CREATE TABLE IF NOT EXISTS psy_dna_reports (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id      UUID NOT NULL REFERENCES psy_patients(id) ON DELETE CASCADE,
  file_name       TEXT NOT NULL,
  file_path       TEXT NOT NULL,
  file_url        TEXT NOT NULL,
  notes           TEXT,
  uploaded_by     UUID REFERENCES auth.users(id),
  uploaded_by_name TEXT,
  uploaded_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- RLS
ALTER TABLE psy_dna_reports ENABLE ROW LEVEL SECURITY;

-- Staff can read and insert all
CREATE POLICY "staff_dna_all" ON psy_dna_reports
  FOR ALL USING (
    EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff')
  );

-- Patient can only read their own reports
CREATE POLICY "patient_dna_read" ON psy_dna_reports
  FOR SELECT USING (
    patient_id IN (
      SELECT id FROM psy_patients WHERE user_id = auth.uid()
    )
  );
