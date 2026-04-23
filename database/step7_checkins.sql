-- ============================================================
-- STEP 7 — PSY_DAILY_CHECKINS
-- ============================================================

CREATE TABLE IF NOT EXISTS psy_daily_checkins (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id UUID REFERENCES psy_patients(id) ON DELETE CASCADE NOT NULL,
  checkin_date DATE DEFAULT CURRENT_DATE NOT NULL,
  mood_score INT CHECK (mood_score BETWEEN 1 AND 10),
  energy_score INT CHECK (energy_score BETWEEN 1 AND 10),
  sleep_quality INT CHECK (sleep_quality BETWEEN 1 AND 10),
  sleep_hours NUMERIC(3,1),
  symptoms JSONB DEFAULT '[]',
  activities JSONB DEFAULT '[]',
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (patient_id, checkin_date)
);

ALTER TABLE psy_daily_checkins ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN CREATE POLICY "Patients manage daily check-ins" ON psy_daily_checkins FOR ALL USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid())) WITH CHECK (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid())); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "Staff read daily check-ins" ON psy_daily_checkins FOR SELECT USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff')); EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE INDEX IF NOT EXISTS idx_psy_checkins_patient ON psy_daily_checkins(patient_id);

SELECT 'Step 7 OK — psy_daily_checkins ready' AS status;
