-- ============================================================
-- STEP 4 — TREATMENT PLANS + APPOINTMENTS + NOTIFICATIONS
-- Run selepas step3_audit.sql
-- ============================================================

CREATE TABLE IF NOT EXISTS psy_appointments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id UUID REFERENCES psy_patients(id),
  staff_id UUID REFERENCES psy_profiles(id),
  patient_name TEXT,
  staff_name TEXT,
  service TEXT NOT NULL,
  appointment_time TIMESTAMPTZ NOT NULL,
  duration_min INT DEFAULT 30,
  status TEXT DEFAULT 'scheduled' CHECK (status IN ('scheduled','checked_in','in_progress','completed','no_show','cancelled')),
  room TEXT,
  notes TEXT,
  ghl_booking_id TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE psy_appointments ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  CREATE POLICY "Staff manage appointments" ON psy_appointments FOR ALL USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "Patients read own appointments" ON psy_appointments FOR SELECT USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "Patients insert own appointments" ON psy_appointments FOR INSERT WITH CHECK (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "Patients update own appointments" ON psy_appointments FOR UPDATE USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE TABLE IF NOT EXISTS psy_treatment_plans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id UUID REFERENCES psy_patients(id) NOT NULL,
  doctor_id UUID REFERENCES psy_profiles(id),
  name TEXT NOT NULL,
  template TEXT,
  duration_unit TEXT DEFAULT 'week',
  duration_weeks INT DEFAULT 13,
  current_week INT DEFAULT 1,
  bio_goals JSONB DEFAULT '[]',
  psycho_goals JSONB DEFAULT '[]',
  social_goals JSONB DEFAULT '[]',
  spiritual_goals JSONB DEFAULT '[]',
  coaching_schedule JSONB DEFAULT '[]',
  status TEXT DEFAULT 'active' CHECK (status IN ('draft','active','completed','paused')),
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE psy_treatment_plans ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  CREATE POLICY "Staff manage plans" ON psy_treatment_plans FOR ALL USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "Patients read own plans" ON psy_treatment_plans FOR SELECT USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "Patients insert own plans" ON psy_treatment_plans FOR INSERT WITH CHECK (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE TABLE IF NOT EXISTS psy_plan_weekly_progress (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id UUID REFERENCES psy_treatment_plans(id) ON DELETE CASCADE NOT NULL,
  patient_id UUID REFERENCES psy_patients(id) ON DELETE CASCADE NOT NULL,
  week_number INT NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('booked','hadir','reschedule','cancel','pending')),
  score INT CHECK (score BETWEEN 0 AND 10),
  notes TEXT,
  coaching_checks JSONB DEFAULT '{}',
  appointment_id UUID REFERENCES psy_appointments(id) ON DELETE SET NULL,
  updated_by UUID REFERENCES psy_profiles(id),
  updated_by_name TEXT,
  session_date TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (plan_id, week_number)
);

ALTER TABLE psy_plan_weekly_progress ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  CREATE POLICY "Staff manage weekly progress" ON psy_plan_weekly_progress FOR ALL USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "Patients read own progress" ON psy_plan_weekly_progress FOR SELECT USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "Patients insert own progress" ON psy_plan_weekly_progress FOR INSERT WITH CHECK (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "Patients update own progress" ON psy_plan_weekly_progress FOR UPDATE USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE TABLE IF NOT EXISTS psy_plan_check_ins (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id UUID REFERENCES psy_treatment_plans(id) ON DELETE CASCADE NOT NULL,
  patient_id UUID REFERENCES psy_patients(id) ON DELETE CASCADE NOT NULL,
  pillar TEXT NOT NULL CHECK (pillar IN ('bio','psycho','social','spiritual')),
  goal_index INT NOT NULL,
  goal_text TEXT,
  completed_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (plan_id, pillar, goal_index)
);

ALTER TABLE psy_plan_check_ins ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  CREATE POLICY "Patients manage own check-ins" ON psy_plan_check_ins FOR ALL USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid())) WITH CHECK (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "Staff read check-ins" ON psy_plan_check_ins FOR SELECT USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE TABLE IF NOT EXISTS psy_plan_compliance (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id UUID REFERENCES psy_treatment_plans(id) ON DELETE CASCADE NOT NULL,
  patient_id UUID REFERENCES psy_patients(id) ON DELETE CASCADE NOT NULL,
  week_number INT NOT NULL,
  madu_sudu INT,
  nafas_kali INT,
  bumi_minit INT,
  berjemur BOOLEAN,
  pantang BOOLEAN,
  kelapa_kali INT,
  kolon_kali INT,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (plan_id, week_number)
);

ALTER TABLE psy_plan_compliance ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  CREATE POLICY "Staff manage compliance" ON psy_plan_compliance FOR ALL USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "Patients manage own compliance" ON psy_plan_compliance FOR ALL USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid())) WITH CHECK (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE TABLE IF NOT EXISTS psy_notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES psy_profiles(id) ON DELETE CASCADE NOT NULL,
  type TEXT DEFAULT 'system' CHECK (type IN ('appointment','order','plan','system')),
  title TEXT NOT NULL,
  body TEXT,
  link TEXT,
  is_read BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE psy_notifications ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  CREATE POLICY "Users read own notifications" ON psy_notifications FOR SELECT USING (user_id = auth.uid());
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "Users update own notifications" ON psy_notifications FOR UPDATE USING (user_id = auth.uid());
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "Anyone insert notifications" ON psy_notifications FOR INSERT WITH CHECK (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE INDEX IF NOT EXISTS idx_psy_appointments_time ON psy_appointments(appointment_time);
CREATE INDEX IF NOT EXISTS idx_psy_appointments_patient ON psy_appointments(patient_id);
CREATE INDEX IF NOT EXISTS idx_psy_weekly_plan ON psy_plan_weekly_progress(plan_id);
CREATE INDEX IF NOT EXISTS idx_psy_weekly_patient ON psy_plan_weekly_progress(patient_id);
CREATE INDEX IF NOT EXISTS idx_psy_compliance_plan ON psy_plan_compliance(plan_id, week_number);
CREATE INDEX IF NOT EXISTS idx_psy_notifications_user ON psy_notifications(user_id, is_read, created_at DESC);

SELECT 'Step 4 OK — plans + appointments + notifications ready' AS status;
