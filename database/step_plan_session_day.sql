-- Phase 1: 2 sesi seminggu — tambah session_day untuk pisahkan sesi A vs B.
-- Existing rows tetap session_day=1 supaya plan lama tak terjejas.

ALTER TABLE psy_plan_weekly_progress
  ADD COLUMN IF NOT EXISTS session_day INT DEFAULT 1 CHECK (session_day IN (1,2)),
  ADD COLUMN IF NOT EXISTS is_extension BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS extension_for_week INT,
  ADD COLUMN IF NOT EXISTS extension_price NUMERIC(10,2),
  ADD COLUMN IF NOT EXISTS extension_paid_at TIMESTAMPTZ;

-- Drop old uniqueness yang assume 1 row per minggu
ALTER TABLE psy_plan_weekly_progress
  DROP CONSTRAINT IF EXISTS psy_plan_weekly_progress_plan_id_week_number_key;

-- Composite unique: 1 row per sesi (plan + minggu + day)
DO $$ BEGIN
  ALTER TABLE psy_plan_weekly_progress
    ADD CONSTRAINT psy_plan_weekly_progress_plan_week_day_key
    UNIQUE (plan_id, week_number, session_day);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Status tambahan untuk extension flow
ALTER TABLE psy_plan_weekly_progress
  DROP CONSTRAINT IF EXISTS psy_plan_weekly_progress_status_check;

ALTER TABLE psy_plan_weekly_progress
  ADD CONSTRAINT psy_plan_weekly_progress_status_check
  CHECK (status IN (
    'pending','booked','hadir','reschedule','cancel','consultation_done',
    'extension_pending_payment','extension_paid'
  ));

COMMENT ON COLUMN psy_plan_weekly_progress.session_day IS
  '1 = sesi pertama dalam minggu (Jum/Sab), 2 = sesi kedua (Sab/Ahad). Default 1 untuk backward compat.';
COMMENT ON COLUMN psy_plan_weekly_progress.is_extension IS
  'true = minggu tambahan (extension) selepas miss sesi. Perlu bayar sebelum tempah.';
COMMENT ON COLUMN psy_plan_weekly_progress.extension_for_week IS
  'Refer minggu asal yang miss, untuk audit trail.';
