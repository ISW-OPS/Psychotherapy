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
