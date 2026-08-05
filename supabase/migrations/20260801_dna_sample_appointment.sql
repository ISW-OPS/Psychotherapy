-- Jadual Pengambilan Sampel DNA (Step 1 dna-test.html) — reuse psy_appointments
-- (macam Step 5 Consultation) + peringatan WA sehari sebelum via event-reminders.
-- Rujuk: database/schema/26_dna_test.sql, database/schema/18_notifications_automations.sql

ALTER TABLE psy_dna_test_process
  ADD COLUMN IF NOT EXISTS sample_appointment_id UUID REFERENCES psy_appointments(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS sample_reminder_sent_at TIMESTAMPTZ;

-- Seed config Mesej Automatik (dna_sample_reminder) — is_active = false, staff semak &
-- aktifkan sendiri di halaman Tetapan Mesej Automatik.
insert into psy_auto_messages
  (key, name, description, channel, trigger_type, message_template,
   placeholders, channels, rule, category, language, is_active)
values
  ('dna_sample_reminder',
   'Peringatan Pengambilan Sampel DNA',
   'Sehari sebelum tarikh janji temu pengambilan sampel DNA Test, hantar WA kpd pesakit — nyatakan tarikh/masa & syarat persediaan (makan 2 jam sebelum, jangan makan/minum 30 minit sebelum).',
   'whatsapp', 'before_event',
   E'Salam {nama} 👋\n\nPeringatan: esok anda dijadualkan untuk *Pengambilan Sampel DNA Test* di klinik.\n\n📅 {tarikh_sample} · {masa_sample}\n\n⚠️ Sila patuhi sebelum ujian:\n• Pastikan anda telah makan sekurang-kurangnya 2 jam sebelum ujian.\n• Jangan makan atau minum sekurang-kurangnya 30 minit sebelum ujian.\n\nJumpa esok!\n\n— {nama_klinik}',
   '["{nama}","{tarikh_sample}","{masa_sample}","{nama_klinik}"]'::jsonb,
   '["whatsapp"]'::jsonb,
   '{"lead_days":1}'::jsonb,
   'dna_test', 'ms',
   false)
on conflict (key) do update set
  name             = excluded.name,
  description      = excluded.description,
  channel          = excluded.channel,
  trigger_type     = excluded.trigger_type,
  message_template = excluded.message_template,
  placeholders     = excluded.placeholders,
  channels         = excluded.channels,
  rule             = excluded.rule,
  category         = excluded.category,
  language         = excluded.language,
  updated_at       = now();
