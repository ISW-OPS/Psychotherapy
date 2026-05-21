-- ============================================================
-- CLEANUP — buang session_no + constraint yang saya tersilap tambah
-- Sistem sudah ada session_day untuk handle 2 sesi/minggu.
-- Jalankan SEKALI sahaja.
-- ============================================================

-- Drop the wrong constraint
ALTER TABLE psy_plan_weekly_progress
  DROP CONSTRAINT IF EXISTS psy_plan_weekly_progress_plan_week_session_unique;

-- Drop the duplicate column
ALTER TABLE psy_plan_weekly_progress
  DROP COLUMN IF EXISTS session_no;

-- Drop the redundant index (kalau wujud)
DROP INDEX IF EXISTS idx_plan_progress_week_session;

-- Verifikasi: constraint yang betul masih ada (session_day-based)
SELECT conname
FROM pg_constraint
WHERE conrelid = 'psy_plan_weekly_progress'::regclass
  AND contype = 'u'
ORDER BY conname;

-- Verifikasi: column session_day masih ada
SELECT column_name, data_type, column_default
FROM information_schema.columns
WHERE table_name = 'psy_plan_weekly_progress'
  AND column_name IN ('session_day', 'session_no');

SELECT 'OK — session_no removed, system uses session_day' AS status;
