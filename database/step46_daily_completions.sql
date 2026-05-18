-- ============================================================
-- step46_daily_completions.sql
-- Track patient's daily activity completion (checklist).
-- One row per checked item per day. Resets implicitly via log_date.
-- ============================================================

CREATE TABLE IF NOT EXISTS psy_daily_completions (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id   UUID NOT NULL REFERENCES psy_patients(id) ON DELETE CASCADE,
  log_date     DATE NOT NULL DEFAULT CURRENT_DATE,
  item_time    TEXT NOT NULL,      -- 'HH:MM' string from schedule
  activity     TEXT NOT NULL,      -- snapshot of activity name for reference
  completed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(patient_id, log_date, item_time)
);

CREATE INDEX IF NOT EXISTS idx_daily_completions_patient_date
  ON psy_daily_completions(patient_id, log_date);

ALTER TABLE psy_daily_completions ENABLE ROW LEVEL SECURITY;

-- Patient manages own
DO $$ BEGIN
  CREATE POLICY "Patient manage own completions"
    ON psy_daily_completions FOR ALL
    USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()))
    WITH CHECK (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Staff read all (for compliance views)
DO $$ BEGIN
  CREATE POLICY "Staff read completions"
    ON psy_daily_completions FOR SELECT
    USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

SELECT 'Step 46 OK — psy_daily_completions ready' AS status;
