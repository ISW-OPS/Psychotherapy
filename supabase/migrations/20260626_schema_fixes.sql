-- ════════════════════════════════════════════════════════════════
-- Schema fixes — 26 Jun 2026
-- Menambah kolum yang dirujuk dalam HTML tetapi tiada dalam skema.
-- Idempotent: ADD COLUMN IF NOT EXISTS.
-- ════════════════════════════════════════════════════════════════

-- 1. psy_risk_alerts: tambah resolution_notes (nota tindakan semasa resolve)
ALTER TABLE psy_risk_alerts
  ADD COLUMN IF NOT EXISTS resolution_notes TEXT;

-- 2. psy_kob_slot_config: tambah note (nota peringatan untuk slot)
ALTER TABLE psy_kob_slot_config
  ADD COLUMN IF NOT EXISTS note TEXT;

SELECT 'Schema fixes OK' AS status;
