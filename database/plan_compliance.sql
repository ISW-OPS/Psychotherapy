-- ============================================================
-- PLAN COMPLIANCE — per-week fitrah compliance tracking
-- Minum madu, pernafasan fitrah, terapi bumi, berjemur,
-- pantang makanan, air kelapa, terapi kolon
-- ============================================================

CREATE TABLE IF NOT EXISTS plan_compliance (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id UUID REFERENCES treatment_plans(id) ON DELETE CASCADE NOT NULL,
  patient_id UUID REFERENCES patients(id) ON DELETE CASCADE NOT NULL,
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

ALTER TABLE plan_compliance ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff manage compliance" ON plan_compliance;
CREATE POLICY "Staff manage compliance" ON plan_compliance FOR ALL
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "Patients manage own compliance" ON plan_compliance;
CREATE POLICY "Patients manage own compliance" ON plan_compliance FOR ALL
  USING (patient_id IN (SELECT id FROM patients WHERE user_id = auth.uid()))
  WITH CHECK (patient_id IN (SELECT id FROM patients WHERE user_id = auth.uid()));

CREATE INDEX IF NOT EXISTS idx_compliance_plan ON plan_compliance(plan_id, week_number);
