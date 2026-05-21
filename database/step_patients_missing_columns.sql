-- ============================================================
-- STEP — psy_patients missing columns (full audit)
-- Cover semua field yang patients.html (Tambah/Edit Pesakit) hantar
-- tapi tidak wujud dalam schema asal psy_patients.
-- ============================================================

-- ── 1. Tambah column yang missing ──────────────────────────
ALTER TABLE psy_patients
  ADD COLUMN IF NOT EXISTS full_name                       TEXT,
  ADD COLUMN IF NOT EXISTS phone                           TEXT,
  ADD COLUMN IF NOT EXISTS emergency_contact_email         TEXT,
  ADD COLUMN IF NOT EXISTS emergency_contact_relationship  TEXT;

-- ── 2. Comments untuk dokumentasi ──────────────────────────
COMMENT ON COLUMN psy_patients.full_name IS
  'Nama pesakit. Bila ada user_id, biasanya match dgn psy_profiles.full_name. Snapshot untuk staff-created tanpa user_id.';
COMMENT ON COLUMN psy_patients.phone IS
  'Nombor telefon utama pesakit. Boleh berbeza dari psy_profiles.phone (cth: kalau staff tukar di sini).';
COMMENT ON COLUMN psy_patients.emergency_contact_email IS
  'Email kenalan kecemasan / waris.';
COMMENT ON COLUMN psy_patients.emergency_contact_relationship IS
  'Hubungan waris dengan pesakit (Suami, Isteri, Ibu, Bapa, Anak, dll).';

-- ── 3. Backfill: salin nama + phone dari profile (untuk patient yang ada user_id) ──
UPDATE psy_patients p
SET full_name = COALESCE(p.full_name, pr.full_name),
    phone     = COALESCE(p.phone,     pr.phone)
FROM psy_profiles pr
WHERE p.user_id = pr.id
  AND (p.full_name IS NULL OR p.phone IS NULL);

-- ── 4. Index untuk search ──────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_psy_patients_full_name ON psy_patients(full_name);
CREATE INDEX IF NOT EXISTS idx_psy_patients_phone     ON psy_patients(phone);

-- ── 5. Verification — semua column yang patients.html guna ──
DO $$
DECLARE
  required_cols TEXT[] := ARRAY[
    'full_name','phone','email',
    'ic_number','date_of_birth','gender','marital_status',
    'address','home_address','city','state',
    'occupation','company','referral_source',
    'medical_condition','condition_duration','medical_notes',
    'emergency_contact_name','emergency_contact_phone',
    'emergency_contact_ic','emergency_contact_relationship','emergency_contact_email',
    'active_package_id','active_package_name','package_purchased_at','package_expires_at',
    'reference_code','documents',
    'status','kob_status','outcome_status','outcome_status_at','outcome_status_notes',
    'coach_id','assigned_at','created_by_staff','user_id','mrn'
  ];
  missing_cols TEXT[] := '{}';
  col TEXT;
BEGIN
  FOREACH col IN ARRAY required_cols LOOP
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_name = 'psy_patients' AND column_name = col
    ) THEN
      missing_cols := array_append(missing_cols, col);
    END IF;
  END LOOP;

  IF array_length(missing_cols, 1) > 0 THEN
    RAISE NOTICE 'MASIH MISSING: %', missing_cols;
  ELSE
    RAISE NOTICE 'OK — semua column patients.html sudah ada dalam schema';
  END IF;
END $$;

SELECT 'OK — psy_patients missing columns added + verified' AS status;

-- ── 6. Diagnostic ──────────────────────────────────────────
SELECT
  COUNT(*) FILTER (WHERE full_name IS NOT NULL) AS ada_nama,
  COUNT(*) FILTER (WHERE phone IS NOT NULL)     AS ada_phone,
  COUNT(*) FILTER (WHERE user_id IS NOT NULL)   AS ada_user_id,
  COUNT(*) FILTER (WHERE created_by_staff)      AS staff_created,
  COUNT(*) AS total
FROM psy_patients;
