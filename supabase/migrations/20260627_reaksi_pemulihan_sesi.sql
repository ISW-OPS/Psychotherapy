-- Reaksi Pemulihan (sesi mingguan) — diisi oleh coach masa sesi, tracking sahaja.
-- BERASINGAN daripada item 'reaksi_pemulihan' dalam psy_kepatuhan_item (check-in harian pesakit).
-- Disimpan per-rekod minggu pada psy_plan_weekly_progress sebagai JSONB:
--   { "<item_key>": true, ... }  -- hanya simptom yang ditanda disimpan.

ALTER TABLE psy_plan_weekly_progress
  ADD COLUMN IF NOT EXISTS reaksi_pemulihan JSONB DEFAULT '{}';

COMMENT ON COLUMN psy_plan_weekly_progress.reaksi_pemulihan IS
  'Checklist Reaksi Pemulihan diisi coach masa sesi (tracking sahaja, tiada skor). Format: {item_key: true}';
