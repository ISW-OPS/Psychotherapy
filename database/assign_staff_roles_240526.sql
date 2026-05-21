-- ============================================================
-- ASSIGN STAFF ROLES — 24 Mei 2026
-- Tetapkan staff_role kepada akaun sedia ada
-- ============================================================
--
-- PRA-SYARAT:
-- 1. Semua email di bawah mesti sudah daftar (auth.users + psy_profiles wujud).
-- 2. Untuk akaun BARU yang belum daftar (cth: syafairdina@...), buat signup
--    dahulu melalui auth flow biasa (Sign Up page), kemudian jalankan
--    blok BAHAGIAN B di bawah untuk set role manager.
--
-- Skrip ini hanya UPDATE rekod sedia ada. Tidak boleh cipta auth user
-- dari SQL — itu perlu Supabase Admin API atau signup flow.
-- ============================================================

-- ── BAHAGIAN A: Update role staff untuk akaun yang dah ada ──

-- COACH (4 orang)
UPDATE psy_profiles
SET role = 'staff',
    staff_role = 'coach',
    updated_at = now()
WHERE email IN (
  'tasnimsenusi@gmail.com',
  'fazirahsamah@gmail.com',
  'muhammaduweiszulkifli@gmail.com',
  'izzah@ibnusinawellness.com'
);

-- DOCTOR
UPDATE psy_profiles
SET role = 'staff',
    staff_role = 'doctor',
    updated_at = now()
WHERE email = 'doc03@ibnusinawellness.com';

-- ADMIN
UPDATE psy_profiles
SET role = 'staff',
    staff_role = 'admin',
    updated_at = now()
WHERE email = 'iswcustomersuccess@gmail.com';

-- ── BAHAGIAN B: Manager (selepas signup syafairdina@...) ──
-- Jalankan SELEPAS user signup dengan password 123456789

UPDATE psy_profiles
SET role = 'staff',
    staff_role = 'manager',
    updated_at = now()
WHERE email = 'syafairdina@ibnusinawellness.com';

-- ── VERIFICATION ──
-- Semak hasil update
SELECT email, full_name, role, staff_role, is_active
FROM psy_profiles
WHERE email IN (
  'tasnimsenusi@gmail.com',
  'fazirahsamah@gmail.com',
  'muhammaduweiszulkifli@gmail.com',
  'izzah@ibnusinawellness.com',
  'doc03@ibnusinawellness.com',
  'iswcustomersuccess@gmail.com',
  'syafairdina@ibnusinawellness.com'
)
ORDER BY staff_role, email;

-- ── DIAGNOSTIK: Senarai email yang tiada profile (belum signup) ──
WITH wanted AS (
  SELECT email FROM (VALUES
    ('tasnimsenusi@gmail.com'),
    ('fazirahsamah@gmail.com'),
    ('muhammaduweiszulkifli@gmail.com'),
    ('izzah@ibnusinawellness.com'),
    ('doc03@ibnusinawellness.com'),
    ('iswcustomersuccess@gmail.com'),
    ('syafairdina@ibnusinawellness.com')
  ) AS t(email)
)
SELECT w.email AS belum_daftar
FROM wanted w
LEFT JOIN psy_profiles p ON p.email = w.email
WHERE p.id IS NULL;

SELECT 'OK - staff roles assigned' AS status;
