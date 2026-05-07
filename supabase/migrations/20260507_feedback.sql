-- ── psy_feedback ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS psy_feedback (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id  UUID REFERENCES psy_patients(id) ON DELETE SET NULL,
  user_id     UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  patient_name TEXT,
  rating      SMALLINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
  helpful     JSONB DEFAULT '[]',
  comment     TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE psy_feedback ENABLE ROW LEVEL SECURITY;

-- Patients: insert only their own
DROP POLICY IF EXISTS "feedback_patient_insert" ON psy_feedback;
CREATE POLICY "feedback_patient_insert" ON psy_feedback
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Staff: read all
DROP POLICY IF EXISTS "feedback_staff_read" ON psy_feedback;
CREATE POLICY "feedback_staff_read" ON psy_feedback
  FOR SELECT USING (EXISTS (
    SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'
  ));
