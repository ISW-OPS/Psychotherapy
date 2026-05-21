-- ============================================================
-- STEP — Sessions Per Week (per-pakej configuration)
-- Sokong pakej yang ada variasi sesi/minggu:
--   • OB/NLC = 2 sesi/minggu (Jum+Sab atau Sab+Ahd)
--   • OBG    = 1 sesi/minggu
--   • 777    = per-hari (guna duration_unit='day' yang sedia ada)
--
-- BACKWARD COMPAT: Sistem sudah ada `preferred_pair` (fri_sat|sat_sun),
-- `preferred_time_day1/2`, dan `session_day` (1|2) untuk handle 2 sesi.
-- Migration ni TAMBAH lapisan KONFIGURASI PER-PAKEJ supaya tidak hardcoded
-- pada 2 pilihan sahaja, dan boleh extend kepada 1 sesi/minggu.
-- ============================================================

-- ── psy_packages: konfigurasi pakej ─────────────────
ALTER TABLE psy_packages
  ADD COLUMN IF NOT EXISTS sessions_per_week INT DEFAULT 1
    CHECK (sessions_per_week BETWEEN 1 AND 7),
  ADD COLUMN IF NOT EXISTS session_days_options JSONB DEFAULT '[]';

COMMENT ON COLUMN psy_packages.sessions_per_week IS
  'Bilangan sesi seminggu untuk pakej ini. 1 = sekali (OBG), 2 = dua kali (OB/NLC). Pakej per-hari (777) guna duration_unit=day, biarkan field ini = 1.';

COMMENT ON COLUMN psy_packages.session_days_options IS
  'Pilihan variant hari sesi yang patient boleh pilih. Format: array of array of int (1=Mon, 7=Sun). Cth OB: [[5,6],[6,7]] = pilihan Jum+Sab ATAU Sab+Ahd. OBG: [[6]] = Sabtu sahaja.';

-- ── Existing columns (untuk rujukan, tak diubah): ──
-- psy_treatment_plans.preferred_pair       — 'fri_sat' atau 'sat_sun' (hardcoded, masih kekal)
-- psy_treatment_plans.preferred_time_day1  — masa sesi hari pertama
-- psy_treatment_plans.preferred_time_day2  — masa sesi hari kedua (NULL kalau 1 sesi/minggu)
-- psy_treatment_plans.schedule_setup_at    — bila setup siap
-- psy_plan_weekly_progress.session_day     — 1 atau 2 (sesi pertama/kedua minggu tu)
--
-- Bila migrate untuk extend lebih dari 2 pasangan (mis: Isn+Kha), boleh
-- ubah CHECK constraint pada `preferred_pair` jadi text bebas atau remove
-- check tu. Buat masa ni biar existing constraint kekal — tambah variant
-- baru dalam pakej `session_days_options` dan handle di UI/JS.

-- ── Verification ────────────────────────────────────
SELECT 'OK — sessions_per_week schema ready (build on existing preferred_pair/session_day)' AS status;

-- Senarai pakej sedia ada (untuk admin set sessions_per_week)
SELECT id, package_id, name, duration_unit, sessions_per_week, session_days_options
FROM psy_packages
ORDER BY name;
