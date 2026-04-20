-- Add patient feedback fields to plan_weekly_progress
ALTER TABLE plan_weekly_progress
  ADD COLUMN IF NOT EXISTS feedback_rating INT CHECK (feedback_rating BETWEEN 1 AND 5),
  ADD COLUMN IF NOT EXISTS feedback_comment TEXT,
  ADD COLUMN IF NOT EXISTS feedback_at TIMESTAMPTZ;
