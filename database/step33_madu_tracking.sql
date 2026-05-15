-- ============================================================
-- step33_madu_tracking.sql
-- Track madu intake count per day in daily check-in.
-- Target frequency comes from patient's active package (madu_frequency_per_day).
-- ============================================================

ALTER TABLE psy_daily_checkins
  ADD COLUMN IF NOT EXISTS madu_count INT NOT NULL DEFAULT 0;

COMMENT ON COLUMN psy_daily_checkins.madu_count IS
  'Bilangan kali pesakit minum madu hari ini. Target dari psy_packages.madu_frequency_per_day.';
