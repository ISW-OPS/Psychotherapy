-- Add meet_link column to psy_plan_weekly_progress for online sessions
ALTER TABLE psy_plan_weekly_progress
  ADD COLUMN IF NOT EXISTS meet_link TEXT;
