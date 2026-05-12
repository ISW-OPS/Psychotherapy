-- Add session_type and consultation_done status to psy_plan_weekly_progress

-- 1. Add session_type column (f2f / online)
ALTER TABLE psy_plan_weekly_progress
  ADD COLUMN IF NOT EXISTS session_type TEXT NOT NULL DEFAULT 'f2f'
  CHECK (session_type IN ('f2f', 'online'));

-- 2. Add consultation_done to status constraint
ALTER TABLE psy_plan_weekly_progress
  DROP CONSTRAINT IF EXISTS psy_plan_weekly_progress_status_check;

ALTER TABLE psy_plan_weekly_progress
  ADD CONSTRAINT psy_plan_weekly_progress_status_check
  CHECK (status IN ('pending', 'booked', 'hadir', 'consultation_done', 'reschedule', 'cancel', 'dna'));
