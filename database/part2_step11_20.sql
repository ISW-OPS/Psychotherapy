-- ISW — Part 2/4: Step 11-20
Run after part1_step01_10.sql.
-- Generated: 2026-06-12T04:04:17.890990Z
-- Total files: 10
-- Run this entire file in Supabase SQL Editor (new project).


-- ════════════════════════════════════════════════════════════════
-- step11_staff_roles.sql
-- ════════════════════════════════════════════════════════════════

-- ============================================================
-- STEP 11 — STAFF SUB-ROLES
-- Tambah staff_role ke psy_profiles
-- Run ini di Supabase SQL Editor
-- ============================================================

-- 1. Tambah kolum staff_role
ALTER TABLE psy_profiles
  ADD COLUMN IF NOT EXISTS staff_role TEXT CHECK (staff_role IN ('admin', 'coach', 'manager'));

-- 2. Staff yang ada sekarang → set admin by default supaya tak kena lock out
UPDATE psy_profiles
  SET staff_role = 'admin'
  WHERE role = 'staff' AND staff_role IS NULL;

-- 3. Update trigger supaya staff baru boleh dapat staff_role dari metadata
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.psy_profiles (id, full_name, role, email, staff_role)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', split_part(NEW.email, '@', 1)),
    COALESCE(NEW.raw_user_meta_data->>'role', 'patient'),
    NEW.email,
    CASE
      WHEN COALESCE(NEW.raw_user_meta_data->>'role', 'patient') = 'staff'
      THEN COALESCE(NEW.raw_user_meta_data->>'staff_role', 'coach')
      ELSE NULL
    END
  );
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE LOG 'Error creating profile: %', SQLERRM;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

SELECT 'Step 11 OK — staff_role column added' AS status;


-- ════════════════════════════════════════════════════════════════
-- step12_library_media.sql
-- ════════════════════════════════════════════════════════════════

-- ============================================================
-- STEP 12 — Add thumbnail_url to psy_library_items
-- Run in Supabase SQL Editor
-- ============================================================

ALTER TABLE psy_library_items
  ADD COLUMN IF NOT EXISTS thumbnail_url TEXT;

-- Create storage bucket for library media (run once)
-- In Supabase Dashboard → Storage → New Bucket → "library-media" → Public
-- OR run via API. Manual step needed in dashboard.

SELECT 'Step 12 OK — library thumbnail_url column added' AS status;


-- ════════════════════════════════════════════════════════════════
-- step13_coach_assignment.sql
-- ════════════════════════════════════════════════════════════════

-- STEP 13 — Coach assignment to patients
-- Run in Supabase SQL Editor

ALTER TABLE psy_patients
  ADD COLUMN IF NOT EXISTS coach_id UUID REFERENCES psy_profiles(id),
  ADD COLUMN IF NOT EXISTS assigned_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_psy_patients_coach ON psy_patients(coach_id);

SELECT 'Step 13 OK — coach_id + assigned_at added to psy_patients' AS status;


-- ════════════════════════════════════════════════════════════════
-- step14_doctor_role.sql
-- ════════════════════════════════════════════════════════════════

-- ============================================================
-- STEP 14 — Doctor Staff Role
-- Run in Supabase SQL Editor
-- ============================================================

-- 1. Update CHECK constraint on staff_role to include 'doctor'
ALTER TABLE psy_profiles
  DROP CONSTRAINT IF EXISTS psy_profiles_staff_role_check;

ALTER TABLE psy_profiles
  ADD CONSTRAINT psy_profiles_staff_role_check
  CHECK (staff_role IN ('admin', 'doctor', 'coach', 'manager'));

-- 2. Verify
SELECT 'Step 14 OK — doctor role added to staff_role constraint' AS status;


-- ════════════════════════════════════════════════════════════════
-- step15_kyc_extra_fields.sql
-- ════════════════════════════════════════════════════════════════

-- ============================================================
-- STEP 15 — Extra KYC fields (marital status, occupation, etc.)
-- Run in Supabase SQL Editor
-- ============================================================

-- 1. Add new columns to psy_kyc_submissions
ALTER TABLE psy_kyc_submissions
  ADD COLUMN IF NOT EXISTS marital_status TEXT,
  ADD COLUMN IF NOT EXISTS occupation TEXT,
  ADD COLUMN IF NOT EXISTS company TEXT,
  ADD COLUMN IF NOT EXISTS emergency_contact_relationship TEXT,
  ADD COLUMN IF NOT EXISTS emergency_contact_email TEXT;

-- 2. Add matching columns to psy_patients (for quick access without joining KYC)
ALTER TABLE psy_patients
  ADD COLUMN IF NOT EXISTS marital_status TEXT,
  ADD COLUMN IF NOT EXISTS occupation TEXT,
  ADD COLUMN IF NOT EXISTS company TEXT;

SELECT 'Step 15 OK — extra KYC fields added' AS status;


-- ════════════════════════════════════════════════════════════════
-- step16_missing_tables.sql
-- ════════════════════════════════════════════════════════════════

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


-- ════════════════════════════════════════════════════════════════
-- step17_inventory.sql
-- ════════════════════════════════════════════════════════════════

-- step17_inventory.sql — placeholder (notes only, no DDL)
/*
Bimbingan Peminuman madu
Bimbingan Diet dan Nutrisi
Bimbingan Zikir bersanad
*/


-- ════════════════════════════════════════════════════════════════
-- step18_reference_code.sql
-- ════════════════════════════════════════════════════════════════

-- Add reference_code column to store old patient codes (e.g. OB'25-0710, NLC'25-0177)
ALTER TABLE psy_patients ADD COLUMN IF NOT EXISTS reference_code TEXT;


-- ════════════════════════════════════════════════════════════════
-- step19_kyc_patients_sync.sql
-- ════════════════════════════════════════════════════════════════

-- Add missing columns to psy_patients for full form sync (idempotent)
ALTER TABLE psy_patients ADD COLUMN IF NOT EXISTS company TEXT;
ALTER TABLE psy_patients ADD COLUMN IF NOT EXISTS referral_source TEXT;
ALTER TABLE psy_patients ADD COLUMN IF NOT EXISTS condition_duration TEXT;
ALTER TABLE psy_patients ADD COLUMN IF NOT EXISTS emergency_contact_ic TEXT;
ALTER TABLE psy_patients ADD COLUMN IF NOT EXISTS reference_code TEXT;
ALTER TABLE psy_patients ADD COLUMN IF NOT EXISTS documents JSONB DEFAULT '{}';
ALTER TABLE psy_kyc_submissions ADD COLUMN IF NOT EXISTS emergency_contact_ic TEXT;

INSERT INTO storage.buckets (id, name, public) VALUES ('medical-reports', 'medical-reports', false) ON CONFLICT DO NOTHING;

DO $$ BEGIN
  CREATE POLICY "Staff can upload medical reports" ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'medical-reports' AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "Staff can read all medical reports" ON storage.objects
    FOR SELECT TO authenticated
    USING (bucket_id = 'medical-reports' AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "Patients can upload own medical reports" ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'medical-reports' AND (storage.foldername(name))[1] = 'patient' AND EXISTS (SELECT 1 FROM psy_patients WHERE user_id = auth.uid()));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "Patients can read own medical reports" ON storage.objects
    FOR SELECT TO authenticated
    USING (bucket_id = 'medical-reports' AND EXISTS (SELECT 1 FROM psy_patients WHERE user_id = auth.uid() AND id::text = (storage.foldername(name))[2]));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;


-- ════════════════════════════════════════════════════════════════
-- step20_soft_delete.sql
-- ════════════════════════════════════════════════════════════════

-- Soft delete: add 'deleted' as valid status for psy_patients
ALTER TABLE psy_patients DROP CONSTRAINT IF EXISTS psy_patients_status_check;
ALTER TABLE psy_patients ADD CONSTRAINT psy_patients_status_check
  CHECK (status IN ('pending_kyc','active','inactive','rejected','deleted'));
