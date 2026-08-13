-- ═══════════════════════════════════════════════════════════════════
-- Bayaran Ansuran (Pelan Pelaburan Ansuran) — pakej, jadual ansuran,
-- sekatan tempahan sesi bila tertunggak. Turut bawa naik perubahan
-- schema/ WIP sedia ada yang belum ada migration (Bayaran Manual
-- kob-detail.html — invoice_number/receipt_url, postcode).
-- ═══════════════════════════════════════════════════════════════════

-- ──── psy_payments — bayaran manual (invois + resit) ────
ALTER TABLE psy_payments
  ADD COLUMN IF NOT EXISTS invoice_number TEXT,
  ADD COLUMN IF NOT EXISTS receipt_url TEXT;

-- ──── psy_patients — alamat: poskod berasingan ────
ALTER TABLE psy_patients
  ADD COLUMN IF NOT EXISTS postcode TEXT;

-- ──── psy_packages — konfigurasi ansuran per pakej ────
ALTER TABLE psy_packages
  ADD COLUMN IF NOT EXISTS installment_allowed BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS installment_count INT;

ALTER TABLE psy_packages DROP CONSTRAINT IF EXISTS psy_packages_installment_count_check;
ALTER TABLE psy_packages
  ADD CONSTRAINT psy_packages_installment_count_check
  CHECK (installment_count IS NULL OR installment_count BETWEEN 2 AND 12);

-- ──── psy_patients — sekatan tempahan sesi ────
ALTER TABLE psy_patients
  ADD COLUMN IF NOT EXISTS booking_blocked BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS booking_blocked_reason TEXT,
  ADD COLUMN IF NOT EXISTS booking_blocked_since TIMESTAMPTZ;

-- ──── psy_kob_sessions — mod bayaran pakej ────
ALTER TABLE psy_kob_sessions
  ADD COLUMN IF NOT EXISTS package_payment_mode TEXT;

ALTER TABLE psy_kob_sessions DROP CONSTRAINT IF EXISTS psy_kob_sessions_package_payment_mode_check;
ALTER TABLE psy_kob_sessions
  ADD CONSTRAINT psy_kob_sessions_package_payment_mode_check
  CHECK (package_payment_mode IN ('full','installment'));

-- ──── psy_kob_installments — jadual ansuran ────
CREATE TABLE IF NOT EXISTS psy_kob_installments (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  kob_session_id   UUID NOT NULL REFERENCES psy_kob_sessions(id) ON DELETE CASCADE,
  patient_id       UUID NOT NULL REFERENCES psy_patients(id) ON DELETE CASCADE,
  seq              INT NOT NULL,
  due_date         DATE NOT NULL,
  amount           NUMERIC(10,2) NOT NULL,
  status           TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','paid','overdue')),
  paid_payment_id  UUID REFERENCES psy_payments(id) ON DELETE SET NULL,
  paid_at          TIMESTAMPTZ,
  created_at       TIMESTAMPTZ DEFAULT now(),
  CONSTRAINT psy_kob_installments_unique_seq UNIQUE (kob_session_id, seq)
);

CREATE INDEX IF NOT EXISTS idx_kob_installments_session ON psy_kob_installments(kob_session_id);
CREATE INDEX IF NOT EXISTS idx_kob_installments_patient ON psy_kob_installments(patient_id, status);
CREATE INDEX IF NOT EXISTS idx_kob_installments_overdue ON psy_kob_installments(due_date) WHERE status = 'pending';

ALTER TABLE psy_kob_installments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Patient read own installments" ON psy_kob_installments;
CREATE POLICY "Patient read own installments" ON psy_kob_installments FOR SELECT
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Staff manage installments" ON psy_kob_installments;
CREATE POLICY "Staff manage installments" ON psy_kob_installments FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- ──── psy_kob_sessions.package_payment_status — tambah 'declined' (kalau belum ada) ────
ALTER TABLE psy_kob_sessions DROP CONSTRAINT IF EXISTS psy_kob_sessions_package_payment_status_check;
ALTER TABLE psy_kob_sessions
  ADD CONSTRAINT psy_kob_sessions_package_payment_status_check
  CHECK (package_payment_status IN ('pending','partial','paid','skipped','declined','na'));

-- ──── psy_auto_messages — templat WA ansuran tertunggak (dikendalikan runInstallmentOverdueCheck di event-reminders) ────
insert into psy_auto_messages
  (key, name, description, channel, trigger_type, message_template,
   placeholders, channels, category, language, is_active)
values
  ('installment_overdue',
   'Ansuran Pakej Tertunggak',
   'Bila ansuran pakej pesakit lepas tarikh due & belum dibayar, hantar WA + sekat tempahan sesi baru sehingga bayaran diselesaikan.',
   'whatsapp', 'installment_overdue',
   E'Salam {nama} 👋\n\nAnsuran {seq} (RM {jumlah}) untuk pakej rawatan anda tertunggak sejak {tarikh_due}.\n\nTempahan sesi baru disekat buat sementara waktu sehingga bayaran diselesaikan. Sila hubungi pusat rawatan untuk bantuan.\n\n— {nama_klinik}',
   '["{nama}","{seq}","{jumlah}","{tarikh_due}","{nama_klinik}"]'::jsonb,
   '["whatsapp"]'::jsonb,
   'pembayaran', 'ms',
   false)
on conflict (key) do update set
  name             = excluded.name,
  description      = excluded.description,
  channel          = excluded.channel,
  trigger_type     = excluded.trigger_type,
  message_template = excluded.message_template,
  placeholders     = excluded.placeholders,
  channels         = excluded.channels,
  category         = excluded.category,
  language         = excluded.language,
  updated_at       = now();
