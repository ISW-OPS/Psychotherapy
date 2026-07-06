-- ════════════════════════════════════════════════════════════════
-- step78: Masa bacaan vitals (Jul 2026)
-- Staff boleh rekod vitals beberapa kali sehari (3-4 kali), setiap satu
-- dengan MASA sendiri. Tambah kolum reading_time.
-- Sekali gus pastikan kolum penanda (plan/minggu/tarikh) wujud — sesetengah
-- env lama mungkin tiada; ADD COLUMN IF NOT EXISTS = selamat & idempotent.
-- ════════════════════════════════════════════════════════════════

ALTER TABLE psy_vitals
  ADD COLUMN IF NOT EXISTS plan_id      UUID REFERENCES psy_treatment_plans(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS week_number  INT,
  ADD COLUMN IF NOT EXISTS reading_date DATE,
  ADD COLUMN IF NOT EXISTS reading_time TIME;

COMMENT ON COLUMN psy_vitals.reading_time IS
  'Masa bacaan (HH:MM). Staff boleh rekod beberapa bacaan sehari — masa bezakan setiap satu.';

SELECT 'step78 OK -- psy_vitals reading_time (+ plan/week/date safety)' AS status;
