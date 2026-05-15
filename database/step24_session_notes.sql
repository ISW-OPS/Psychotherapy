-- Merge coaching session notes into weekly progress (single source of truth)
ALTER TABLE psy_plan_weekly_progress
  ADD COLUMN IF NOT EXISTS notes           TEXT,
  ADD COLUMN IF NOT EXISTS mood_before     INT,
  ADD COLUMN IF NOT EXISTS mood_after      INT,
  ADD COLUMN IF NOT EXISTS goals_discussed TEXT[],
  ADD COLUMN IF NOT EXISTS homework_given  TEXT[],
  ADD COLUMN IF NOT EXISTS coach_id        UUID REFERENCES auth.users(id),
  ADD COLUMN IF NOT EXISTS coach_name      TEXT;
