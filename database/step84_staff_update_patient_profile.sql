-- STEP 84 — Benarkan STAFF update profil PESAKIT (psy_profiles)
-- ─────────────────────────────────────────────────────────────────────────
-- Masalah: polisi asal psy_profiles hanya benarkan "Update own profile"
--          (auth.uid() = id). Jadi bila staff edit nama/telefon pesakit dari
--          borang, sync ke psy_profiles DISEKAT senyap (0 baris) → paparan
--          hub (baca profil-dulu) kekal nilai lama = "kembali ke asal".
--
-- Penyelesaian: tambah polisi UPDATE untuk staff, TERHAD kepada baris pesakit
--               (role='patient') sahaja — staff tak boleh ubah profil staff lain.
--
-- Nota recursion: polisi ON psy_profiles yang query psy_profiles boleh rekursi.
--                 Guna fungsi SECURITY DEFINER (bypass RLS dalaman) untuk semak.
-- Idempotent — selamat run berulang. WAJIB run di TESTING & PRODUCTION.

CREATE OR REPLACE FUNCTION public.isw_is_staff()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.psy_profiles
    WHERE id = auth.uid() AND role = 'staff'
  );
$$;

GRANT EXECUTE ON FUNCTION public.isw_is_staff() TO authenticated;

DO $$ BEGIN
  DROP POLICY IF EXISTS "Staff update patient profiles" ON psy_profiles;
  CREATE POLICY "Staff update patient profiles" ON psy_profiles
    FOR UPDATE
    USING (role = 'patient' AND public.isw_is_staff())
    WITH CHECK (role = 'patient');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

SELECT 'Step 84 OK — staff boleh update profil pesakit' AS status;
