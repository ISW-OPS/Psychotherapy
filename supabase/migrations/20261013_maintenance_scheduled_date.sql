-- ═══════════════════════════════════════════════════════════════════
-- Tarikh kena buat maintenance (diisi manager masa lulus)
-- Perlu migration 20261008 dijalankan dulu.
-- ═══════════════════════════════════════════════════════════════════

ALTER TABLE psy_equipment_maintenance
  ADD COLUMN IF NOT EXISTS scheduled_date DATE;
