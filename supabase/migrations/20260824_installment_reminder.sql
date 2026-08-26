-- Peringatan Ansuran Akan Tamat Tempoh (installment_reminder) — lihat
-- database/schema/09_kob.sql & database/schema/18_notifications_automations.sql
-- utk versi sumber kebenaran + nota lengkap.

ALTER TABLE psy_kob_installment_checkpoints
  ADD COLUMN IF NOT EXISTS installment_reminder_sent_at TIMESTAMPTZ;

insert into psy_auto_messages
  (key, name, description, channel, trigger_type, message_template,
   placeholders, channels, rule, category, language, is_active)
values
  ('installment_reminder',
   'Peringatan Ansuran Akan Tamat Tempoh',
   'Sebelum checkpoint ansuran KOB jatuh tempoh (rule.lead_days hari, default 3), hantar WA kpd pesakit dengan pautan bayaran HitPay — dijana automatik.',
   'whatsapp', 'installment_reminder',
   E'Salam {nama} 👋\n\nPeringatan mesra: ansuran *{ansuran}* pakej rawatan anda (RM {jumlah}) akan tamat tempoh pada *{tarikh_due}*.\n\nSila selesaikan bayaran melalui pautan selamat:\n{pautan}\n\nTerima kasih — ISW',
   '["{nama}","{ansuran}","{jumlah}","{tarikh_due}","{pautan}"]'::jsonb,
   '["whatsapp"]'::jsonb,
   '{"lead_days":3}'::jsonb,
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
  rule             = excluded.rule,
  category         = excluded.category,
  language         = excluded.language,
  updated_at       = now();
