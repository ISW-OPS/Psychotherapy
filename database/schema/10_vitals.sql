-- ═══════════════════════════════════════════════════════════════════
-- SKEMA: VITALS (Bacaan Klinikal Pesakit)
-- Jadual: psy_vitals
-- Bacaan vital (BP, HR, SpO2, berat, gula, HbA1c dll.) direkod oleh
-- staff di klinik atau oleh pesakit sendiri; boleh diikat pada plan
-- rawatan + minggu, dengan tarikh & masa bacaan (berbilang sehari).
-- ═══════════════════════════════════════════════════════════════════

-- ──── psy_vitals ────
CREATE TABLE IF NOT EXISTS psy_vitals (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id       UUID REFERENCES psy_patients(id) ON DELETE CASCADE NOT NULL,
  recorded_by      UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  recorded_by_name TEXT,
  bp_systolic      INT,
  bp_diastolic     INT,
  heart_rate       INT,
  spo2             NUMERIC(5,2),
  temperature      NUMERIC(4,1),
  weight           NUMERIC(5,2),
  height           NUMERIC(5,1),
  bmi              NUMERIC(4,1),
  waist_cm         NUMERIC(5,1),
  rbs              NUMERIC(6,2),
  hba1c            NUMERIC(4,2),
  phq2_score       INT,
  medications      TEXT,
  notes            TEXT,
  source           TEXT NOT NULL DEFAULT 'staff' CHECK (source IN ('staff','patient_self')),
  plan_id          UUID REFERENCES psy_treatment_plans(id) ON DELETE SET NULL,
  week_number      INT,
  reading_date     DATE,
  reading_time     TIME,
  created_at       TIMESTAMPTZ DEFAULT now()
);

-- Indeks
CREATE INDEX IF NOT EXISTS idx_psy_vitals_patient ON psy_vitals(patient_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_vitals_plan_week
  ON psy_vitals(plan_id, week_number) WHERE plan_id IS NOT NULL;

-- RLS
ALTER TABLE psy_vitals ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff manage vitals" ON psy_vitals;
CREATE POLICY "Staff manage vitals" ON psy_vitals FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "Patients read own vitals" ON psy_vitals;
CREATE POLICY "Patients read own vitals" ON psy_vitals FOR SELECT
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

-- Pesakit hanya boleh masuk/edit bacaan sendiri (source = patient_self)
DROP POLICY IF EXISTS "Patients insert own vitals" ON psy_vitals;
CREATE POLICY "Patients insert own vitals" ON psy_vitals FOR INSERT
  WITH CHECK (
    source = 'patient_self'
    AND patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid())
  );

DROP POLICY IF EXISTS "Patients update own vitals" ON psy_vitals;
CREATE POLICY "Patients update own vitals" ON psy_vitals FOR UPDATE
  USING (
    source = 'patient_self'
    AND patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid())
  )
  WITH CHECK (
    source = 'patient_self'
    AND patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid())
  );

-- Komen
COMMENT ON COLUMN psy_vitals.hba1c IS 'HbA1c % (e.g. 6.5 = 6.5%)';
COMMENT ON COLUMN psy_vitals.source IS 'Who entered the reading: staff at clinic, or patient self-reported';
COMMENT ON COLUMN psy_vitals.reading_date IS 'Date the reading was actually taken (may differ from created_at for back-dated entries)';
COMMENT ON COLUMN psy_vitals.plan_id IS
  'Refer treatment plan masa vitals direkod. NULL kalau direkod luar konteks plan.';
COMMENT ON COLUMN psy_vitals.week_number IS
  'Minggu rawatan ke berapa bila vitals direkod. NULL kalau tiada plan aktif.';
COMMENT ON COLUMN psy_vitals.reading_time IS
  'Masa bacaan (HH:MM). Staff boleh rekod beberapa bacaan sehari — masa bezakan setiap satu.';
