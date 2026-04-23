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
