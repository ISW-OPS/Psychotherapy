-- ============================================================
-- STEP — Profile Personal Fields
-- Tambah maklumat peribadi staff (tarikh lahir, jantina, bahasa,
-- status perkahwinan, jabatan) untuk halaman profil yang lebih
-- lengkap.
-- ============================================================

ALTER TABLE psy_profiles
  ADD COLUMN IF NOT EXISTS birth_date     DATE,
  ADD COLUMN IF NOT EXISTS gender         TEXT CHECK (gender IN ('lelaki','perempuan')),
  ADD COLUMN IF NOT EXISTS language       TEXT,
  ADD COLUMN IF NOT EXISTS marital_status TEXT CHECK (marital_status IN ('bujang','berkahwin','bercerai','duda','janda')),
  ADD COLUMN IF NOT EXISTS department     TEXT;

COMMENT ON COLUMN psy_profiles.birth_date     IS 'Tarikh lahir staff (untuk paparan profil)';
COMMENT ON COLUMN psy_profiles.gender         IS 'Jantina: lelaki / perempuan';
COMMENT ON COLUMN psy_profiles.language       IS 'Bahasa utama yang digunakan';
COMMENT ON COLUMN psy_profiles.marital_status IS 'Status perkahwinan staff';
COMMENT ON COLUMN psy_profiles.department     IS 'Jabatan / Unit kerja';

SELECT 'OK — psy_profiles personal fields added' AS status;
