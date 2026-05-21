-- ============================================================
-- step36_kob_slots.sql
-- KOB slot template configuration.
-- Slots are a fixed template — same 4 time slots for Wed-Sun.
-- Admin can toggle each slot on/off. No per-patient capacity (infinite per slot).
-- ============================================================

CREATE TABLE IF NOT EXISTS psy_kob_slot_config (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  day_of_week  INT NOT NULL CHECK (day_of_week IN (0, 3, 4, 5, 6)),  -- 0=Sun, 3=Wed, 4=Thu, 5=Fri, 6=Sat
  slot_start   TIME NOT NULL,
  slot_end     TIME NOT NULL,
  is_active    BOOLEAN NOT NULL DEFAULT true,
  label        TEXT NOT NULL,         -- human-readable e.g. "8.30 AM - 10.00 AM"
  sort_order   INT NOT NULL DEFAULT 0,
  created_at   TIMESTAMPTZ DEFAULT now(),
  updated_at   TIMESTAMPTZ DEFAULT now(),
  UNIQUE (day_of_week, slot_start)
);

CREATE INDEX IF NOT EXISTS idx_kob_slots_day ON psy_kob_slot_config(day_of_week, is_active);

ALTER TABLE psy_kob_slot_config ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "Anyone read kob slots" ON psy_kob_slot_config
    FOR SELECT USING (auth.uid() IS NOT NULL);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "Admin manage kob slots" ON psy_kob_slot_config FOR ALL
    USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff' AND staff_role IN ('admin','manager','doctor')));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ── Seed: 5 hari (Rabu-Ahad) × 4 slot ────────────────────
-- Slot 1: 8.30 AM - 10.00 AM
-- Slot 2: 10.30 AM - 12.00 PM
-- Slot 3: 2.00 PM - 3.30 PM
-- Slot 4: 3.30 PM - 5.00 PM
INSERT INTO psy_kob_slot_config (day_of_week, slot_start, slot_end, label, sort_order) VALUES
  (3, '08:30', '10:00', '8.30 AM - 10.00 AM', 1),
  (3, '10:30', '12:00', '10.30 AM - 12.00 PM', 2),
  (3, '14:00', '15:30', '2.00 PM - 3.30 PM', 3),
  (3, '15:30', '17:00', '3.30 PM - 5.00 PM', 4),
  (4, '08:30', '10:00', '8.30 AM - 10.00 AM', 1),
  (4, '10:30', '12:00', '10.30 AM - 12.00 PM', 2),
  (4, '14:00', '15:30', '2.00 PM - 3.30 PM', 3),
  (4, '15:30', '17:00', '3.30 PM - 5.00 PM', 4),
  (5, '08:30', '10:00', '8.30 AM - 10.00 AM', 1),
  (5, '10:30', '12:00', '10.30 AM - 12.00 PM', 2),
  (5, '14:00', '15:30', '2.00 PM - 3.30 PM', 3),
  (5, '15:30', '17:00', '3.30 PM - 5.00 PM', 4),
  (6, '08:30', '10:00', '8.30 AM - 10.00 AM', 1),
  (6, '10:30', '12:00', '10.30 AM - 12.00 PM', 2),
  (6, '14:00', '15:30', '2.00 PM - 3.30 PM', 3),
  (6, '15:30', '17:00', '3.30 PM - 5.00 PM', 4),
  (0, '08:30', '10:00', '8.30 AM - 10.00 AM', 1),
  (0, '10:30', '12:00', '10.30 AM - 12.00 PM', 2),
  (0, '14:00', '15:30', '2.00 PM - 3.30 PM', 3),
  (0, '15:30', '17:00', '3.30 PM - 5.00 PM', 4)
ON CONFLICT DO NOTHING;

SELECT 'Step 36 OK — KOB slot config ready' AS status;
