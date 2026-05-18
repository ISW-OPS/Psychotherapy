-- ============================================================
-- step48_feedback_weekly.sql
-- Extend psy_feedback to support weekly per-session feedback
-- + overall end-of-treatment feedback (existing behavior).
-- ============================================================

ALTER TABLE psy_feedback
  ADD COLUMN IF NOT EXISTS feedback_type   TEXT NOT NULL DEFAULT 'overall'
    CHECK (feedback_type IN ('weekly','overall')),
  ADD COLUMN IF NOT EXISTS week_number     INT,
  ADD COLUMN IF NOT EXISTS plan_id         UUID REFERENCES psy_treatment_plans(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS coach_id        UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS coach_name      TEXT,
  ADD COLUMN IF NOT EXISTS coach_rating    INT CHECK (coach_rating BETWEEN 1 AND 5),
  ADD COLUMN IF NOT EXISTS supply_rating   INT CHECK (supply_rating BETWEEN 1 AND 5);

COMMENT ON COLUMN psy_feedback.feedback_type IS
  '"weekly" = per-session feedback (rates coach + supplies); "overall" = end-of-treatment review';

CREATE INDEX IF NOT EXISTS idx_feedback_type_patient
  ON psy_feedback(patient_id, feedback_type);

CREATE INDEX IF NOT EXISTS idx_feedback_coach
  ON psy_feedback(coach_id) WHERE coach_id IS NOT NULL;

SELECT 'Step 48 OK — feedback weekly + KPI tracking ready' AS status;
