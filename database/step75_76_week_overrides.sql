-- ════════════════════════════════════════════════════════════════
-- step75 + step76: Override bekalan & sesi PER-PESAKIT PER-MINGGU
-- Jalankan sekali di PROD (xmvqvq) via Supabase SQL Editor.
-- Idempotent & kalis-error — selamat jalan semula walau jadual separa wujud.
-- Tak sentuh data sedia ada.
--
-- Konsep: templat pakej (psy_packages.coaching_schedule + sessions_per_week)
-- kekal sebagai DEFAULT. Jadual ni simpan PENGECUALIAN untuk satu pesakit,
-- satu minggu. Logik baca di UI: override ?? default_pakej.
-- ════════════════════════════════════════════════════════════════

-- ── step75a: Longgarkan had session_day (dulu IN (1,2)) → boleh >2 sesi ──
ALTER TABLE psy_plan_weekly_progress
  DROP CONSTRAINT IF EXISTS psy_plan_weekly_progress_session_day_check;
ALTER TABLE psy_plan_weekly_progress
  ADD CONSTRAINT psy_plan_weekly_progress_session_day_check
  CHECK (session_day BETWEEN 1 AND 7);

-- ── step75b: Jadual override ──
-- Cipta jadual asas (kalau belum ada). Kolum penuh dipastikan di bawah
-- guna ADD COLUMN IF NOT EXISTS supaya jadual separa (dari run lama) turut dibaiki.
CREATE TABLE IF NOT EXISTS psy_plan_week_overrides (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id     UUID NOT NULL REFERENCES psy_treatment_plans(id) ON DELETE CASCADE,
  week_number INT  NOT NULL
);

-- Pastikan SEMUA kolum wujud (kalis jadual separa dari percubaan terdahulu)
ALTER TABLE psy_plan_week_overrides
  ADD COLUMN IF NOT EXISTS patient_id            UUID REFERENCES psy_patients(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS sessions_override     INT,
  ADD COLUMN IF NOT EXISTS supplies_override     JSONB,
  ADD COLUMN IF NOT EXISTS note                  TEXT,
  ADD COLUMN IF NOT EXISTS updated_by            UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS updated_at            TIMESTAMPTZ DEFAULT now(),
  ADD COLUMN IF NOT EXISTS session_days_override JSONB;

-- Had nilai sessions_override (1..7) — tambah kalau belum ada
DO $$ BEGIN
  ALTER TABLE psy_plan_week_overrides
    ADD CONSTRAINT psy_plan_week_overrides_sessions_override_check
    CHECK (sessions_override BETWEEN 1 AND 7);
EXCEPTION WHEN duplicate_object OR duplicate_table THEN NULL; END $$;

-- Unique (plan_id, week_number) — tambah kalau belum ada
DO $$ BEGIN
  ALTER TABLE psy_plan_week_overrides
    ADD CONSTRAINT psy_plan_week_overrides_plan_id_week_number_key
    UNIQUE (plan_id, week_number);
EXCEPTION WHEN duplicate_object OR duplicate_table THEN NULL; END $$;

CREATE INDEX IF NOT EXISTS idx_psy_plan_week_overrides_plan
  ON psy_plan_week_overrides(plan_id, week_number);

-- ── RLS ──
ALTER TABLE psy_plan_week_overrides ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff manage week overrides" ON psy_plan_week_overrides;
CREATE POLICY "Staff manage week overrides" ON psy_plan_week_overrides FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "Patients read own week overrides" ON psy_plan_week_overrides;
CREATE POLICY "Patients read own week overrides" ON psy_plan_week_overrides FOR SELECT
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

COMMENT ON TABLE psy_plan_week_overrides IS
  'Pengecualian bekalan/sesi per-pesakit per-minggu. Kalau tiada baris = ikut default pakej sepenuhnya.';
COMMENT ON COLUMN psy_plan_week_overrides.session_days_override IS
  'Hari-sesi aktif minggu ini untuk pesakit ini. NULL=ikut pakej; [1,2]/[1]/[2].';

SELECT 'step75+76 OK -- psy_plan_week_overrides sedia (bekalan + sesi override)' AS status;
