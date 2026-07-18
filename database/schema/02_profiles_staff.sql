-- ═══════════════════════════════════════════════════════════════════
-- ISW System — Skema Domain: Profil Pengguna & Peranan Staf
-- Jadual: psy_profiles
-- Termasuk: trigger auth.users → handle_new_user, polisi storage staf
-- ═══════════════════════════════════════════════════════════════════

-- ──── psy_profiles ────
-- Profil semua pengguna (pesakit & staf). id = auth.users.id.
-- staff_role bebas (tiada CHECK) supaya peranan custom boleh ditambah via UI.

CREATE TABLE IF NOT EXISTS psy_profiles (
  id              UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name       TEXT NOT NULL,
  role            TEXT NOT NULL CHECK (role IN ('patient','staff')),
  staff_role      TEXT,
  phone           TEXT,
  email           TEXT,
  avatar_url      TEXT,
  registration_no TEXT,
  specialization  TEXT,
  is_active       BOOLEAN DEFAULT true,
  birth_date      DATE,
  gender          TEXT CHECK (gender IN ('lelaki','perempuan')),
  language        TEXT,
  marital_status  TEXT CHECK (marital_status IN ('bujang','berkahwin','bercerai','duda','janda')),
  department      TEXT,
  signature_url   TEXT,
  created_at      TIMESTAMPTZ DEFAULT now(),
  updated_at      TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_psy_profiles_role ON psy_profiles(role);

ALTER TABLE psy_profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Read all profiles authenticated" ON psy_profiles;
CREATE POLICY "Read all profiles authenticated" ON psy_profiles
  FOR SELECT USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Update own profile" ON psy_profiles;
CREATE POLICY "Update own profile" ON psy_profiles
  FOR UPDATE USING (auth.uid() = id);

DROP POLICY IF EXISTS "Insert own profile" ON psy_profiles;
CREATE POLICY "Insert own profile" ON psy_profiles
  FOR INSERT WITH CHECK (auth.uid() = id OR auth.role() = 'service_role');

-- Staf boleh kemas kini profil pesakit (guna helper public.isw_is_staff())
DROP POLICY IF EXISTS "Staff update patient profiles" ON psy_profiles;
CREATE POLICY "Staff update patient profiles" ON psy_profiles
  FOR UPDATE
  USING (role = 'patient' AND public.isw_is_staff())
  WITH CHECK (role = 'patient');

COMMENT ON COLUMN psy_profiles.birth_date     IS 'Tarikh lahir staff (untuk paparan profil)';
COMMENT ON COLUMN psy_profiles.gender         IS 'Jantina: lelaki / perempuan';
COMMENT ON COLUMN psy_profiles.language       IS 'Bahasa utama yang digunakan';
COMMENT ON COLUMN psy_profiles.marital_status IS 'Status perkahwinan staff';
COMMENT ON COLUMN psy_profiles.department     IS 'Jabatan / Unit kerja';
COMMENT ON COLUMN psy_profiles.signature_url  IS
  'URL signature image staff. Embed dalam surat rasmi yang di-sign.';

-- ──── auto-cipta profil bila auth user baru didaftar ────
-- Staf baru dapat staff_role dari metadata (default 'coach').

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

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- Nota: trigger trg_new_patient_profile (auto-cipta rekod pesakit) berada
-- dalam 04_patients.sql bersama fungsinya handle_new_patient_profile().

-- Nota: semua polisi storage (medical-reports, kob, wa-outbox, referral-docs
-- dll.) diselenggara berpusat dalam 24_storage.sql.
