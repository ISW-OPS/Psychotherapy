-- ============================================================
-- WEEKLY PROGRESS — coach/staff track patient attendance per week
-- ============================================================

CREATE TABLE IF NOT EXISTS plan_weekly_progress (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id UUID REFERENCES treatment_plans(id) ON DELETE CASCADE NOT NULL,
  patient_id UUID REFERENCES patients(id) ON DELETE CASCADE NOT NULL,
  week_number INT NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('hadir','reschedule','cancel','pending')),
  score INT CHECK (score BETWEEN 0 AND 10),
  notes TEXT,
  updated_by UUID REFERENCES profiles(id),
  updated_by_name TEXT,
  session_date TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (plan_id, week_number)
);

ALTER TABLE plan_weekly_progress ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Staff manage weekly progress" ON plan_weekly_progress FOR ALL
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'staff'));

CREATE POLICY "Patients read own progress" ON plan_weekly_progress FOR SELECT
  USING (patient_id IN (SELECT id FROM patients WHERE user_id = auth.uid()));

CREATE INDEX idx_weekly_plan ON plan_weekly_progress(plan_id);
CREATE INDEX idx_weekly_patient ON plan_weekly_progress(patient_id);
