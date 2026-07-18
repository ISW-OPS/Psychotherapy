-- ═══════════════════════════════════════════════════════════════
-- MAKLUM BALAS
-- Jadual: psy_feedback (mingguan per-sesi + keseluruhan rawatan),
--         psy_weekly_feedback (rating mingguan ringkas per pelan)
-- ═══════════════════════════════════════════════════════════════

-- ──── psy_feedback ────
CREATE TABLE IF NOT EXISTS psy_feedback (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id    UUID REFERENCES psy_patients(id) ON DELETE CASCADE,
  user_id       UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  patient_name  TEXT,
  feedback_type TEXT NOT NULL DEFAULT 'overall'
                  CHECK (feedback_type IN ('weekly','overall')),
  week_number   INT,
  plan_id       UUID REFERENCES psy_treatment_plans(id) ON DELETE SET NULL,
  coach_id      UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  coach_name    TEXT,
  rating        INT CHECK (rating BETWEEN 1 AND 5),
  coach_rating  INT CHECK (coach_rating BETWEEN 1 AND 5),
  supply_rating INT CHECK (supply_rating BETWEEN 1 AND 5),
  comment       TEXT,
  helpful_tags  JSONB DEFAULT '[]',
  created_at    TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_feedback_type_patient
  ON psy_feedback(patient_id, feedback_type);

CREATE INDEX IF NOT EXISTS idx_feedback_coach
  ON psy_feedback(coach_id) WHERE coach_id IS NOT NULL;

ALTER TABLE psy_feedback ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Patients manage own feedback" ON psy_feedback;
CREATE POLICY "Patients manage own feedback" ON psy_feedback FOR ALL
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()))
  WITH CHECK (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Staff read all feedback" ON psy_feedback;
CREATE POLICY "Staff read all feedback" ON psy_feedback FOR SELECT
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

COMMENT ON COLUMN psy_feedback.feedback_type IS
  '"weekly" = per-session feedback (rates coach + supplies); "overall" = end-of-treatment review';

-- ──── psy_weekly_feedback ────
CREATE TABLE IF NOT EXISTS psy_weekly_feedback (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id     UUID REFERENCES psy_treatment_plans(id) ON DELETE CASCADE NOT NULL,
  patient_id  UUID REFERENCES psy_patients(id) ON DELETE CASCADE NOT NULL,
  week_number INT NOT NULL,
  rating      INT CHECK (rating BETWEEN 1 AND 5),
  comment     TEXT,
  created_at  TIMESTAMPTZ DEFAULT now(),
  UNIQUE (plan_id, week_number)
);

CREATE INDEX IF NOT EXISTS idx_psy_feedback_plan ON psy_weekly_feedback(plan_id, week_number);

ALTER TABLE psy_weekly_feedback ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Patients manage own weekly feedback" ON psy_weekly_feedback;
CREATE POLICY "Patients manage own weekly feedback" ON psy_weekly_feedback FOR ALL
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()))
  WITH CHECK (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Staff read all weekly feedback" ON psy_weekly_feedback;
CREATE POLICY "Staff read all weekly feedback" ON psy_weekly_feedback FOR SELECT
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
