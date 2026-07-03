-- step81_enable_realtime.sql
-- Enable Supabase Realtime untuk psy_patients & psy_plan_weekly_progress supaya
-- perubahan status pesakit / kehadiran auto-tolak ke UI (tanpa refresh).
-- Realtime hormati RLS — staff terima event hanya utk baris yang mereka boleh SELECT.
-- Jalankan di TESTING dahulu, kemudian PRODUCTION (xmvqvq).

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'psy_patients'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE psy_patients;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'psy_plan_weekly_progress'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE psy_plan_weekly_progress;
  END IF;
END $$;

-- Semak (patut senaraikan kedua-dua jadual):
-- SELECT tablename FROM pg_publication_tables
--   WHERE pubname='supabase_realtime' AND tablename IN ('psy_patients','psy_plan_weekly_progress');

SELECT 'OK — Realtime enabled utk psy_patients & psy_plan_weekly_progress' AS status;
