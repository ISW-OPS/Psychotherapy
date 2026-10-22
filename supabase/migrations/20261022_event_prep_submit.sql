-- ═══════════════════════════════════════════════════════════════════
-- Submit Senarai Persediaan — tab "Pemulangan Barang" kini hanya
-- muncul lepas staff tekan "Submit Senarai Persediaan" (bukan auto
-- sebaik tambah barang pertama).
-- ═══════════════════════════════════════════════════════════════════
ALTER TABLE psy_event_prep_meta ADD COLUMN IF NOT EXISTS submitted_at TIMESTAMPTZ;

-- ═══════════════════════════════════════════════════════════════════
-- Kunci Harga = "OB Lock Harga" reservation (kob-detail.html Langkah 3). Pesakit
-- bayar OB Lock Harga hari ini utk "freeze" harga, diberi tempoh (staff set)
-- utk settle baki & mula pakej. Tiada refund kalau tempoh luput tanpa
-- bayaran penuh (lock_status = forfeited).
-- ═══════════════════════════════════════════════════════════════════
ALTER TABLE psy_kob_sessions ADD COLUMN IF NOT EXISTS lock_deposit_amount NUMERIC(12,2);
ALTER TABLE psy_kob_sessions ADD COLUMN IF NOT EXISTS lock_deposit_payment_id UUID REFERENCES psy_payments(id) ON DELETE SET NULL;
ALTER TABLE psy_kob_sessions ADD COLUMN IF NOT EXISTS lock_deposit_paid_at TIMESTAMPTZ;
ALTER TABLE psy_kob_sessions ADD COLUMN IF NOT EXISTS lock_deposit_method TEXT;
ALTER TABLE psy_kob_sessions ADD COLUMN IF NOT EXISTS lock_deposit_reference TEXT;
ALTER TABLE psy_kob_sessions ADD COLUMN IF NOT EXISTS lock_deposit_recorded_by UUID REFERENCES psy_profiles(id) ON DELETE SET NULL;
ALTER TABLE psy_kob_sessions ADD COLUMN IF NOT EXISTS lock_deposit_recorded_by_name TEXT;
ALTER TABLE psy_kob_sessions ADD COLUMN IF NOT EXISTS lock_expiry_date DATE;
ALTER TABLE psy_kob_sessions ADD COLUMN IF NOT EXISTS lock_status TEXT;
ALTER TABLE psy_kob_sessions ADD COLUMN IF NOT EXISTS lock_extended_count INT NOT NULL DEFAULT 0;
ALTER TABLE psy_kob_sessions ADD COLUMN IF NOT EXISTS lock_forfeited_at TIMESTAMPTZ;
ALTER TABLE psy_kob_sessions ADD COLUMN IF NOT EXISTS lock_forfeited_by UUID REFERENCES psy_profiles(id) ON DELETE SET NULL;
ALTER TABLE psy_kob_sessions ADD COLUMN IF NOT EXISTS lock_forfeited_by_name TEXT;

DO $$ BEGIN
  ALTER TABLE psy_kob_sessions ADD CONSTRAINT psy_kob_sessions_lock_deposit_method_check
    CHECK (lock_deposit_method IN ('cash','transfer','gateway'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  ALTER TABLE psy_kob_sessions ADD CONSTRAINT psy_kob_sessions_lock_status_check
    CHECK (lock_status IN ('active','tempoh_tamat','forfeited','completed'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
