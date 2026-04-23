-- ============================================================
-- STEP 1 — PSY_PROFILES
-- Run dulu ini sebelum table lain
-- ============================================================

CREATE TABLE psy_profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name TEXT NOT NULL,
  role TEXT NOT NULL CHECK (role IN ('patient','staff')),
  phone TEXT,
  email TEXT,
  avatar_url TEXT,
  registration_no TEXT,
  specialization TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE psy_profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Read all profiles authenticated" ON psy_profiles FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "Update own profile" ON psy_profiles FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Insert own profile" ON psy_profiles FOR INSERT WITH CHECK (auth.uid() = id OR auth.role() = 'service_role');

-- Auto-create profile bila user baru register
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.psy_profiles (id, full_name, role, email)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', split_part(NEW.email, '@', 1)),
    COALESCE(NEW.raw_user_meta_data->>'role', 'patient'),
    NEW.email
  );
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE LOG 'Error creating profile: %', SQLERRM;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

CREATE INDEX idx_psy_profiles_role ON psy_profiles(role);

SELECT 'Step 1 OK — psy_profiles ready' AS status;
