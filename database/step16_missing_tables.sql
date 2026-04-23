-- ============================================================
-- STEP 16 — MISSING TABLES: vitals, coaching, risk, feedback
-- Run in Supabase SQL Editor
-- ============================================================

-- 1. PSY_VITALS
CREATE TABLE IF NOT EXISTS psy_vitals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id UUID REFERENCES psy_patients(id) ON DELETE CASCADE NOT NULL,
  recorded_by UUID REFERENCES psy_profiles(id),
  recorded_by_name TEXT,
  bp_systolic INT,
  bp_diastolic INT,
  heart_rate INT,
  spo2 NUMERIC(5,2),
  temperature NUMERIC(4,1),
  weight NUMERIC(5,2),
  height NUMERIC(5,1),
  bmi NUMERIC(4,1),
  waist_cm NUMERIC(5,1),
  rbs NUMERIC(6,2),
  phq2_score INT,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE psy_vitals ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  CREATE POLICY "Staff manage vitals" ON psy_vitals FOR ALL
    USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "Patients read own vitals" ON psy_vitals FOR SELECT
    USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE INDEX IF NOT EXISTS idx_psy_vitals_patient ON psy_vitals(patient_id, created_at DESC);

-- 2. PSY_COACHING_SESSIONS
CREATE TABLE IF NOT EXISTS psy_coaching_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id UUID REFERENCES psy_patients(id) ON DELETE CASCADE NOT NULL,
  coach_id UUID REFERENCES psy_profiles(id),
  patient_name TEXT,
  pillar TEXT CHECK (pillar IN ('bio','psycho','social','spiritual')),
  session_date TIMESTAMPTZ DEFAULT now(),
  duration_min INT DEFAULT 60,
  mood_pre INT CHECK (mood_pre BETWEEN 1 AND 10),
  mood_post INT CHECK (mood_post BETWEEN 1 AND 10),
  notes TEXT,
  goals_discussed JSONB DEFAULT '[]',
  homework JSONB DEFAULT '[]',
  status TEXT DEFAULT 'completed' CHECK (status IN ('completed','no_show','cancelled')),
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE psy_coaching_sessions ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  CREATE POLICY "Staff manage coaching sessions" ON psy_coaching_sessions FOR ALL
    USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "Patients read own coaching sessions" ON psy_coaching_sessions FOR SELECT
    USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE INDEX IF NOT EXISTS idx_psy_coaching_patient ON psy_coaching_sessions(patient_id, session_date DESC);

-- 3. PSY_RISK_ALERTS
CREATE TABLE IF NOT EXISTS psy_risk_alerts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id UUID REFERENCES psy_patients(id) ON DELETE CASCADE NOT NULL,
  patient_name TEXT,
  created_by UUID REFERENCES psy_profiles(id),
  created_by_name TEXT,
  severity TEXT DEFAULT 'medium' CHECK (severity IN ('low','medium','high','critical')),
  category TEXT,
  description TEXT,
  status TEXT DEFAULT 'open' CHECK (status IN ('open','acknowledged','resolved')),
  acknowledged_by UUID REFERENCES psy_profiles(id),
  resolved_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE psy_risk_alerts ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  CREATE POLICY "Staff manage risk alerts" ON psy_risk_alerts FOR ALL
    USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE INDEX IF NOT EXISTS idx_psy_risk_patient ON psy_risk_alerts(patient_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_psy_risk_status ON psy_risk_alerts(status, created_at DESC);

-- 4. PSY_WEEKLY_FEEDBACK
CREATE TABLE IF NOT EXISTS psy_weekly_feedback (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id UUID REFERENCES psy_treatment_plans(id) ON DELETE CASCADE NOT NULL,
  patient_id UUID REFERENCES psy_patients(id) ON DELETE CASCADE NOT NULL,
  week_number INT NOT NULL,
  rating INT CHECK (rating BETWEEN 1 AND 5),
  comment TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (plan_id, week_number)
);

ALTER TABLE psy_weekly_feedback ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  CREATE POLICY "Patients manage own weekly feedback" ON psy_weekly_feedback FOR ALL
    USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()))
    WITH CHECK (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "Staff read all weekly feedback" ON psy_weekly_feedback FOR SELECT
    USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE INDEX IF NOT EXISTS idx_psy_feedback_plan ON psy_weekly_feedback(plan_id, week_number);

SELECT 'Step 16 OK — psy_vitals, psy_coaching_sessions, psy_risk_alerts, psy_weekly_feedback ready' AS status;
