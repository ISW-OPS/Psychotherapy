-- ============================================================
-- step97: Jadual rawatan fleksibel (ikut pakej) + slot masa global
-- ------------------------------------------------------------
-- Membolehkan wizard jadual plan.html baca konfigurasi pakej
-- (sessions_per_week 1-2 + session_days_options) dan slot masa
-- global, bukan hardcode fri_sat/sat_sun.
--
--   psy_treatment_plans.preferred_pair  — CHECK lama dilonggarkan
--   psy_treatment_plans.preferred_days  — [dow JS 0-6] ikut turutan sesi (baharu)
--   psy_treatment_plans.sessions_per_week — disalin dari pakej masa setup
--   psy_settings.schedule_time_slots    — senarai slot masa global (seed default)
--
-- Idempotent: selamat run berulang. Run di Supabase (TESTING dulu → PROD).
-- ============================================================

-- 1. Longgarkan CHECK constraint pada preferred_pair (dulu IN ('fri_sat','sat_sun')).
--    Buang mana-mana CHECK yang merujuk preferred_pair supaya boleh simpan NULL / nilai lain.
DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN
    SELECT conname FROM pg_constraint
    WHERE conrelid = 'psy_treatment_plans'::regclass
      AND contype = 'c'
      AND pg_get_constraintdef(oid) ILIKE '%preferred_pair%'
  LOOP
    EXECUTE 'ALTER TABLE psy_treatment_plans DROP CONSTRAINT ' || quote_ident(r.conname);
  END LOOP;
END $$;

-- 2. Lajur baharu pada psy_treatment_plans
ALTER TABLE psy_treatment_plans
  ADD COLUMN IF NOT EXISTS preferred_days    JSONB DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS sessions_per_week INT   DEFAULT NULL;

COMMENT ON COLUMN psy_treatment_plans.preferred_days IS
  'Hari sesi terpilih dalam nombor getDay() JS (0=Ahad..6=Sabtu), ikut turutan sesi. Cth [5,6]=Jum+Sab, [6]=Sab sahaja. Sumber kebenaran baharu; fallback ke preferred_pair utk plan lama.';
COMMENT ON COLUMN psy_treatment_plans.sessions_per_week IS
  'Bilangan sesi/minggu (1-2) disalin dari pakej masa setup jadual.';

-- 3. Seed slot masa global default (hanya jika belum wujud)
INSERT INTO psy_settings (key, value) VALUES
  ('schedule_time_slots',
   '[{"value":"09:00","label":"9:00 AM"},{"value":"10:00","label":"10:00 AM"},{"value":"14:00","label":"2:00 PM"},{"value":"15:00","label":"3:00 PM"},{"value":"16:00","label":"4:00 PM"}]'::jsonb)
ON CONFLICT (key) DO NOTHING;

SELECT 'Step 97 OK -- preferred_days + sessions_per_week + schedule_time_slots ready' AS status;
