-- ============================================================
-- step32_package_extensions.sql
-- Sprint 1: Package System Foundation
--
-- Extends psy_packages with fields needed for:
-- - Jadual peminuman madu auto (10x/8x/4x ikut pakej)
-- - Lock butang ONLINE dari minggu 3 (kecuali pakej OB direct: OBD1/OBDX1/OBDY1/OBP1/OBPX1/OBPY1)
-- - Bekalan per minggu (foundation untuk inventory auto-deduct)
-- - Content unlock rule per minggu
-- - WhatsApp message template per minggu
-- ============================================================

ALTER TABLE psy_packages
  ADD COLUMN IF NOT EXISTS madu_frequency_per_day INT,
  ADD COLUMN IF NOT EXISTS madu_schedule_label TEXT,
  ADD COLUMN IF NOT EXISTS allow_online_full_duration BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS online_lock_from_week INT NOT NULL DEFAULT 3,
  ADD COLUMN IF NOT EXISTS weekly_supplies JSONB DEFAULT '[]',
  ADD COLUMN IF NOT EXISTS weekly_content JSONB DEFAULT '[]',
  ADD COLUMN IF NOT EXISTS weekly_message JSONB DEFAULT '[]';

COMMENT ON COLUMN psy_packages.madu_frequency_per_day IS
  'Frekuensi peminuman madu sehari. Examples: 10 (12-minggu), 8 (3-bulan), 4 (3-bulan-sekali). NULL = no madu schedule.';
COMMENT ON COLUMN psy_packages.madu_schedule_label IS
  'Human-readable label for madu schedule, e.g. "10x sehari (12 minggu)"';
COMMENT ON COLUMN psy_packages.allow_online_full_duration IS
  'true = online sessions allowed throughout (OBD1/OBDX1/OBDY1/OBP1/OBPX1/OBPY1). false = lock to f2f after online_lock_from_week.';
COMMENT ON COLUMN psy_packages.online_lock_from_week IS
  'Week number from which online sessions are locked (must use f2f). Default 3.';
COMMENT ON COLUMN psy_packages.weekly_supplies IS
  'Array of {week, items: [{product_id, qty, name}]} — bekalan auto-deduct per week';
COMMENT ON COLUMN psy_packages.weekly_content IS
  'Array of {week, content_ids: []} — library content unlock per week';
COMMENT ON COLUMN psy_packages.weekly_message IS
  'Array of {week, message} — WhatsApp template per week';

-- Mark OB-direct packages as allowing online full duration
UPDATE psy_packages
  SET allow_online_full_duration = true
  WHERE LOWER(package_id) IN ('obd1','obdx1','obdy1','obp1','obpx1','obpy1');
