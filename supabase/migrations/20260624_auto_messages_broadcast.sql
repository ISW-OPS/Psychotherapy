-- =====================================================================
-- Mesej Automatik — jenis "Broadcast Berulang" (recurring_broadcast)
-- ---------------------------------------------------------------------
-- Untuk sesi berulang (cth Manzil Live setiap Rab/Kha/Jum 8.45 pagi):
-- broadcast jemputan ke pesakit sebelum sesi, melalui WhatsApp + loceng
-- + auto-Pengumuman. Idempotent.
-- =====================================================================

alter table psy_auto_messages add column if not exists days_of_week      jsonb;       -- [3,4,5] = Rab/Kha/Jum (0=Ahad .. 6=Sabtu)
alter table psy_auto_messages add column if not exists session_time      time;        -- masa sesi bermula (cth 08:45)
alter table psy_auto_messages add column if not exists audience          jsonb default '["patient"]'::jsonb;
alter table psy_auto_messages add column if not exists package_ids       jsonb default '[]'::jsonb;
alter table psy_auto_messages add column if not exists channels          jsonb default '["whatsapp"]'::jsonb;  -- whatsapp | inapp | announcement
alter table psy_auto_messages add column if not exists link              text;        -- pautan Google Meet
alter table psy_auto_messages add column if not exists last_broadcast_at timestamptz; -- dedup: kali terakhir dihantar

-- Seed: Manzil Live (draf — staff lengkapkan link & aktifkan)
insert into psy_auto_messages
  (key, name, description, trigger_type, minutes_before, session_time, days_of_week, audience, package_ids, channels, link, message_template, placeholders, is_active)
values
  ('manzil_live',
   'Live Bacaan Manzil & Perubatan Alami',
   'Broadcast jemputan sesi Manzil live kepada pesakit, sebelum sesi bermula pada hari terpilih.',
   'recurring_broadcast', 30, '08:45', '[3,4,5]'::jsonb, '["patient"]'::jsonb, '[]'::jsonb,
   '["whatsapp","inapp","announcement"]'::jsonb, 'https://meet.google.com/xxx-xxxx-xxx',
   E'Salam {nama} 👋\n\n📿 *Sesi Rohani Eksklusif: Alunan Manzil*\nBersama Sheikh Fares Mohammed\n\nSesi akan bermula {lead} lagi (pukul {masa}). Jom sertai untuk ketenangan & perlindungan hari anda.\n\n📹 Sertai: {pautan}\n\n— Ibnu Sina Wellness',
   '["{nama}","{masa}","{lead}","{pautan}"]'::jsonb,
   false)
on conflict (key) do nothing;

select 'OK — recurring_broadcast ready' as status;
