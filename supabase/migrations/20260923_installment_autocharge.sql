-- ═══════════════════════════════════════════════════════════════════
-- Auto-Caj Ansuran (kad tersimpan HitPay) — lihat database/schema/09_kob.sql
-- & database/schema/18_notifications_automations.sql utk versi sumber
-- kebenaran + nota lengkap. Jalankan di TESTING dulu, kemudian PROD (xmvqvq).
--
-- Ringkasan: pesakit lampir kad SEKALI (recurring-billing HitPay,
-- save_payment_method) → tiap checkpoint ansuran seterusnya dicaj ON-DEMAND
-- automatik pada due_date (jumlah berbeza-beza ikut checkpoint, BUKAN
-- subscription/cycle tetap HitPay) — gantikan/lengkapi aliran pautan-manual
-- sedia ada (installment_reminder/installment_overdue).
-- ═══════════════════════════════════════════════════════════════════

-- ──── psy_kob_installment_checkpoints — jejak percubaan auto-caj ────
ALTER TABLE psy_kob_installment_checkpoints
  ADD COLUMN IF NOT EXISTS autocharge_status TEXT NOT NULL DEFAULT 'not_attempted'
    CHECK (autocharge_status IN ('not_attempted','succeeded','failed')),
  ADD COLUMN IF NOT EXISTS autocharge_last_attempt_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS autocharge_attempts INT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS autocharge_payment_id UUID REFERENCES psy_payments(id) ON DELETE SET NULL;

-- ──── psy_kob_card_authorizations — kad tersimpan, 1 rekod per sesi KOB ────
CREATE TABLE IF NOT EXISTS psy_kob_card_authorizations (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  kob_session_id    UUID NOT NULL REFERENCES psy_kob_sessions(id) ON DELETE CASCADE,
  patient_id        UUID NOT NULL REFERENCES psy_patients(id) ON DELETE CASCADE,
  gateway_provider  TEXT NOT NULL DEFAULT 'hitpay',
  gateway_auth_ref  TEXT NOT NULL,
  status            TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','attached','detached','failed')),
  card_last4        TEXT,
  card_brand        TEXT,
  attached_at       TIMESTAMPTZ,
  detached_at       TIMESTAMPTZ,
  created_at        TIMESTAMPTZ DEFAULT now(),
  CONSTRAINT psy_kob_card_authorizations_unique_session UNIQUE (kob_session_id)
);

CREATE INDEX IF NOT EXISTS idx_kob_card_auth_patient ON psy_kob_card_authorizations(patient_id);

ALTER TABLE psy_kob_card_authorizations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Patient read own card auth" ON psy_kob_card_authorizations;
CREATE POLICY "Patient read own card auth" ON psy_kob_card_authorizations FOR SELECT
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Staff manage card auth" ON psy_kob_card_authorizations;
CREATE POLICY "Staff manage card auth" ON psy_kob_card_authorizations FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- ──── psy_auto_messages — templat WA baharu (is_active=false, staff aktifkan bila sedia) ────
insert into psy_auto_messages
  (key, name, description, channel, trigger_type, message_template,
   placeholders, channels, category, language, is_active)
values
  ('card_attach_invite',
   'Jemputan Lampir Kad — Ansuran Automatik',
   'Pautan HitPay "lampir kad" (RM1 pengesahan) supaya ansuran seterusnya dicaj automatik pada tarikh due, pesakit tak perlu klik pautan tiap bulan.',
   'whatsapp', 'card_attach_invite',
   E'Salam {nama} 👋\n\nUntuk memudahkan bayaran ansuran pakej rawatan anda, sila lampirkan kad debit/kredit anda (pengesahan RM1) melalui pautan selamat di bawah. Ansuran seterusnya akan ditolak SECARA AUTOMATIK pada tarikh due — anda tak perlu klik pautan bayaran setiap bulan lagi.\n\n{pautan}\n\n— {nama_klinik}',
   '["{nama}","{pautan}","{nama_klinik}"]'::jsonb,
   '["whatsapp"]'::jsonb,
   'pembayaran', 'ms',
   false),
  ('installment_autocharge_success',
   'Ansuran Auto-Caj Berjaya',
   'Kad tersimpan pesakit berjaya dicaj automatik pada tarikh due checkpoint ansuran — hantar WA makluman ringkas.',
   'whatsapp', 'installment_autocharge_success',
   E'Salam {nama} 👋\n\nAnsuran *{ansuran}* pakej rawatan anda (RM {jumlah}) telah berjaya ditolak secara automatik daripada kad tersimpan anda pada hari ini.\n\nTerima kasih — {nama_klinik}',
   '["{nama}","{ansuran}","{jumlah}","{nama_klinik}"]'::jsonb,
   '["whatsapp"]'::jsonb,
   'pembayaran', 'ms',
   false),
  ('installment_autocharge_failed',
   'Ansuran Auto-Caj Gagal',
   'Kad tersimpan pesakit gagal dicaj (ditolak/tamat tempoh dll) semasa cuba caj automatik pada tarikh due — hantar WA + pautan bayaran manual fallback.',
   'whatsapp', 'installment_autocharge_failed',
   E'Salam {nama} 👋\n\nAnsuran *{ansuran}* pakej rawatan anda (RM {jumlah}) GAGAL ditolak secara automatik daripada kad tersimpan anda (kad mungkin ditolak/tamat tempoh).\n\nSila selesaikan bayaran melalui pautan selamat di bawah, atau hubungi klinik untuk kemas kini kad:\n{pautan}\n\n— {nama_klinik}',
   '["{nama}","{ansuran}","{jumlah}","{pautan}","{nama_klinik}"]'::jsonb,
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
