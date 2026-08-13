-- ═══════════════════════════════════════════════════════════════════
-- Bayaran Ansuran — ganti model "slot ansuran bersaiz tetap" (20260813_
-- installment_payments.sql) dengan model checkpoint kumulatif custom:
-- pesakit bayar apa-apa amount bila-bila selepas deposit, wajib jumlah
-- TERKUMPUL cecah target tiap checkpoint (bulan + jumlah kumulatif).
-- ═══════════════════════════════════════════════════════════════════

-- ──── psy_kob_installments — buang (ganti psy_kob_installment_checkpoints) ────
-- Jadual kosong/tak digunakan lagi (fitur baru dilancar, belum ada data sebenar).
DROP TABLE IF EXISTS psy_kob_installments;

-- ──── psy_packages — deposit + jadual checkpoint (ganti installment_count) ────
ALTER TABLE psy_packages DROP CONSTRAINT IF EXISTS psy_packages_installment_count_check;
ALTER TABLE psy_packages DROP COLUMN IF EXISTS installment_count;
ALTER TABLE psy_packages
  ADD COLUMN IF NOT EXISTS installment_deposit_amount NUMERIC(10,2),
  ADD COLUMN IF NOT EXISTS installment_checkpoints JSONB DEFAULT '[]';

-- ──── psy_kob_installment_checkpoints ────
CREATE TABLE IF NOT EXISTS psy_kob_installment_checkpoints (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  kob_session_id    UUID NOT NULL REFERENCES psy_kob_sessions(id) ON DELETE CASCADE,
  patient_id        UUID NOT NULL REFERENCES psy_patients(id) ON DELETE CASCADE,
  seq               INT NOT NULL,
  month_offset      INT NOT NULL,
  due_date          DATE NOT NULL,
  target_cumulative NUMERIC(10,2) NOT NULL,
  status            TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','met','overdue')),
  met_at            TIMESTAMPTZ,
  created_at        TIMESTAMPTZ DEFAULT now(),
  CONSTRAINT psy_kob_installment_checkpoints_unique_seq UNIQUE (kob_session_id, seq)
);

CREATE INDEX IF NOT EXISTS idx_kob_checkpoints_session ON psy_kob_installment_checkpoints(kob_session_id);
CREATE INDEX IF NOT EXISTS idx_kob_checkpoints_patient ON psy_kob_installment_checkpoints(patient_id, status);
CREATE INDEX IF NOT EXISTS idx_kob_checkpoints_overdue ON psy_kob_installment_checkpoints(due_date) WHERE status = 'pending';

ALTER TABLE psy_kob_installment_checkpoints ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Patient read own checkpoints" ON psy_kob_installment_checkpoints;
CREATE POLICY "Patient read own checkpoints" ON psy_kob_installment_checkpoints FOR SELECT
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Staff manage checkpoints" ON psy_kob_installment_checkpoints;
CREATE POLICY "Staff manage checkpoints" ON psy_kob_installment_checkpoints FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- ──── psy_auto_messages — kemas kini templat WA ansuran tertunggak (placeholder baru) ────
insert into psy_auto_messages
  (key, name, description, channel, trigger_type, message_template,
   placeholders, channels, category, language, is_active)
values
  ('installment_overdue',
   'Ansuran Pakej Tertunggak',
   'Bila jumlah terkumpul pesakit tak cecah target checkpoint ansuran menjelang tarikh due, hantar WA + sekat tempahan sesi baru sehingga bayaran diselesaikan.',
   'whatsapp', 'installment_overdue',
   E'Salam {nama} 👋\n\nAnsuran pakej rawatan anda (checkpoint Bulan {bulan}) tertunggak sejak {tarikh_due}. Jumlah wajib terkumpul: RM {jumlah} — baki RM {baki} lagi.\n\nTempahan sesi baru disekat buat sementara waktu sehingga bayaran diselesaikan. Sila hubungi pusat rawatan untuk bantuan.\n\n— {nama_klinik}',
   '["{nama}","{bulan}","{jumlah}","{baki}","{tarikh_due}","{nama_klinik}"]'::jsonb,
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
