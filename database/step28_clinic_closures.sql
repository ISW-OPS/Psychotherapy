-- ============================================================
-- step28_clinic_closures.sql
-- Calendar lock for public holidays, Hari Raya, and ad-hoc clinic closure days.
-- Booking flow checks this table to auto-block the date.
-- ============================================================

CREATE TABLE IF NOT EXISTS psy_clinic_closures (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  closure_date DATE NOT NULL,
  label       TEXT NOT NULL,
  category    TEXT NOT NULL DEFAULT 'public_holiday'
              CHECK (category IN ('public_holiday','hari_raya','clinic_closed','training','other')),
  is_recurring BOOLEAN NOT NULL DEFAULT false,  -- annual recurrence on same MM-DD
  notes       TEXT,
  created_by  UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at  TIMESTAMPTZ DEFAULT now(),
  updated_at  TIMESTAMPTZ DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS uniq_clinic_closure_date
  ON psy_clinic_closures (closure_date);

CREATE INDEX IF NOT EXISTS idx_clinic_closure_date
  ON psy_clinic_closures (closure_date);

ALTER TABLE psy_clinic_closures ENABLE ROW LEVEL SECURITY;

-- Everyone authenticated (staff + patient) can read — used by booking + patient dashboard
DO $$ BEGIN
  CREATE POLICY "Anyone read clinic closures" ON psy_clinic_closures
    FOR SELECT USING (auth.uid() IS NOT NULL);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Only admin/manager can mutate
DO $$ BEGIN
  CREATE POLICY "Admin manage clinic closures" ON psy_clinic_closures
    FOR ALL USING (
      EXISTS (SELECT 1 FROM psy_profiles
              WHERE id = auth.uid()
              AND role = 'staff'
              AND staff_role IN ('admin','manager'))
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
