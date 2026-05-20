-- Phase 1: Treatment plan schedule preferences
-- Patient pilih sekali masa onboarding: pasangan hari + jam untuk setiap hari.
-- Sistem auto-seed 24 sesi (12 minggu × 2 hari).

ALTER TABLE psy_treatment_plans
  ADD COLUMN IF NOT EXISTS preferred_pair TEXT CHECK (preferred_pair IN ('fri_sat','sat_sun')),
  ADD COLUMN IF NOT EXISTS preferred_time_day1 TIME,   -- jam hari pertama (Jum atau Sab)
  ADD COLUMN IF NOT EXISTS preferred_time_day2 TIME,   -- jam hari kedua (Sab atau Ahad)
  ADD COLUMN IF NOT EXISTS schedule_setup_at TIMESTAMPTZ;

COMMENT ON COLUMN psy_treatment_plans.preferred_pair IS
  'Pasangan hari pilihan patient: fri_sat (Jumaat+Sabtu) atau sat_sun (Sabtu+Ahad).';
COMMENT ON COLUMN psy_treatment_plans.preferred_time_day1 IS
  'Jam pilihan hari pertama dalam pair (Jumaat untuk fri_sat, Sabtu untuk sat_sun).';
COMMENT ON COLUMN psy_treatment_plans.preferred_time_day2 IS
  'Jam pilihan hari kedua dalam pair (Sabtu untuk fri_sat, Ahad untuk sat_sun).';
COMMENT ON COLUMN psy_treatment_plans.schedule_setup_at IS
  'Bila patient siap setup jadual. NULL = belum setup, tunjuk wizard.';
