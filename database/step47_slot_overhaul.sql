-- ============================================================
-- step47_slot_overhaul.sql
-- 1. Add slot_type column ('kob' | 'rawatan') to existing slot config
-- 2. Replace old 4 slots with new 5 slots
-- 3. Seed for both KOB + Rawatan × 5 days
-- 4. Add per-date override table (staff manual lock/unlock specific dates)
-- ============================================================

-- ── 1. Add slot_type column ──
ALTER TABLE psy_kob_slot_config
  ADD COLUMN IF NOT EXISTS slot_type TEXT NOT NULL DEFAULT 'kob'
  CHECK (slot_type IN ('kob','rawatan'));

-- Rebuild unique constraint to include slot_type
ALTER TABLE psy_kob_slot_config
  DROP CONSTRAINT IF EXISTS psy_kob_slot_config_day_of_week_slot_start_key;

DO $$ BEGIN
  ALTER TABLE psy_kob_slot_config
    ADD CONSTRAINT psy_kob_slot_config_unique UNIQUE (slot_type, day_of_week, slot_start);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ── 2. Clear old slot definitions (template only, no FK to bookings) ──
DELETE FROM psy_kob_slot_config;

-- ── 3. Seed new 5 slots × 2 types × 5 days ──
-- Slots:
--   1: 07:00 - 09:00  "7-9 pg"
--   2: 09:30 - 11:30  "9.30-11.30 pg"
--   3: 14:00 - 16:00  "2-4 ptg"
--   4: 14:30 - 16:30  "2.30-4.30 ptg"
--   5: 16:30 - 18:30  "4.30-6.30 ptg"
-- Days: Rabu(3), Khamis(4), Jumaat(5), Sabtu(6), Ahad(0)

INSERT INTO psy_kob_slot_config (slot_type, day_of_week, slot_start, slot_end, label, sort_order, is_active)
SELECT
  t.slot_type,
  d.day_of_week,
  s.slot_start::time,
  s.slot_end::time,
  s.label,
  s.sort_order,
  true
FROM
  (VALUES ('kob'), ('rawatan')) AS t(slot_type),
  (VALUES (3), (4), (5), (6), (0)) AS d(day_of_week),
  (VALUES
    ('07:00', '09:00', '7-9 pg',          1),
    ('09:30', '11:30', '9.30-11.30 pg',   2),
    ('14:00', '16:00', '2-4 ptg',         3),
    ('14:30', '16:30', '2.30-4.30 ptg',   4),
    ('16:30', '18:30', '4.30-6.30 ptg',   5)
  ) AS s(slot_start, slot_end, label, sort_order);

-- ── 4. Per-date override (staff lock/offer specific slots per date) ──
CREATE TABLE IF NOT EXISTS psy_slot_date_overrides (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slot_date   DATE NOT NULL,
  slot_type   TEXT NOT NULL CHECK (slot_type IN ('kob','rawatan')),
  slot_start  TIME NOT NULL,
  is_offered  BOOLEAN NOT NULL DEFAULT true,
  note        TEXT,
  created_by  UUID,
  created_at  TIMESTAMPTZ DEFAULT now(),
  updated_at  TIMESTAMPTZ DEFAULT now(),
  UNIQUE (slot_date, slot_type, slot_start)
);

CREATE INDEX IF NOT EXISTS idx_slot_overrides_date
  ON psy_slot_date_overrides(slot_date, slot_type);

ALTER TABLE psy_slot_date_overrides ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "Anyone read slot overrides"
    ON psy_slot_date_overrides FOR SELECT
    USING (auth.uid() IS NOT NULL);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "Staff manage slot overrides"
    ON psy_slot_date_overrides FOR ALL
    USING (EXISTS (
      SELECT 1 FROM psy_profiles
      WHERE id = auth.uid() AND role = 'staff'
      AND staff_role IN ('admin','manager','doctor')
    ));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

SELECT 'Step 47 OK — 5 slot template × 2 types × 5 days + per-date override ready' AS status;
