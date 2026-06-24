-- =====================================================================
-- Mesej Automatik — Alert Kepatuhan kepada COACH (gabungan multi-check)
-- ---------------------------------------------------------------------
-- Setiap malam, untuk setiap pesakit aktif yang ada coach di-assign,
-- sistem nilai beberapa "check" kepatuhan dan GABUNG jadi SATU alert
-- (papan pemuka risk + loceng + email) supaya coach boleh hubungi
-- pesakit esok pagi. Dedup 1×/minggu/pesakit.
--
-- Checks (rule.checks):
--   amalan    — item Catatan Harian yang 'tidak' dibuat / bawah sasaran
--   checklist — bilangan hari TIDAK isi Catatan Harian
--   skor      — skor kepatuhan (Pilihan B) bawah min_score
--   vitals    — tiada bacaan kesihatan dalam N hari
-- (ubat/herba & no-show coaching DITANGGUH — tiada sumber data lagi.)
--
-- Runner `runKepatuhanAlerts` (Edge Function event-reminders) baca konfig
-- dari sini. Ambang dalam lajur `rule` (jsonb) → ubah tanpa re-deploy.
-- Kekal is_active = FALSE — staff aktifkan dari UI bila sedia. Idempotent.
-- =====================================================================

-- Lajur ambang/peraturan (untuk alert berasaskan logik, bukan template sahaja)
alter table psy_auto_messages add column if not exists rule jsonb;

comment on column psy_auto_messages.rule is
  'Peraturan/ambang untuk alert berasaskan logik. Cth kepatuhan: {"severity":"high","window_days":7,"email_from":"support@ibnusinawellness.com","checks":{"amalan":{"on":true,"min_days_short":3},"checklist":{"on":true,"min_days_missing":3},"skor":{"on":true,"min_score":80},"vitals":{"on":true,"min_days_since":7}}}';

-- 'email' = saluran sah (selain whatsapp/inapp/announcement) — via GHL type:Email.

-- Buang baris lama (madu-sahaja) jika wujud → diganti dgn engine gabungan
update psy_auto_messages set key = 'kepatuhan_alert',
       name = 'Alert Coach — Kepatuhan Pesakit',
       trigger_type = 'daily_reminder'
 where key = 'kepatuhan_alert_madu';

insert into psy_auto_messages
  (key, name, description, trigger_type, send_at_time, days_of_week, audience, channels, rule, message_template, placeholders, is_active)
values
  ('kepatuhan_alert',
   'Alert Coach — Kepatuhan Pesakit',
   'Setiap malam, semak kepatuhan setiap pesakit aktif (amalan Catatan Harian tak dibuat/bawah sasaran, hari tak isi, skor rendah, tiada bacaan kesihatan). Gabung jadi SATU alert kepada COACH yang di-assign (papan pemuka + loceng + email) supaya boleh hubungi pesakit esok pagi. Dedup 1×/minggu/pesakit.',
   'daily_reminder',                 -- supaya UI papar pemilih masa harian
   '21:00',                          -- nilai hujung hari
   '[0,1,2,3,4,5,6]'::jsonb,          -- setiap hari (0=Ahad .. 6=Sabtu)
   '["coach"]'::jsonb,               -- sasaran = coach (bukan pesakit)
   '["inapp"]'::jsonb,               -- loceng dalam app sahaja (email DIMATIKAN; tambah "email" utk hidupkan via GHL)
   '{"severity":"high","window_days":7,"email_from":"support@ibnusinawellness.com","checks":{"amalan":{"on":true,"min_days_short":3},"checklist":{"on":true,"min_days_missing":3},"skor":{"on":true,"min_score":80},"vitals":{"on":true,"min_days_since":7}}}'::jsonb,
   E'Assalamualaikum Coach 👋\n\nPesakit {nama} memerlukan perhatian anda.\n\nBerikut perkara yang perlu diberi perhatian (7 hari lepas):\n{senarai}\n\nTindakan Disyorkan:\n📞 Hubungi pesakit untuk membuat semakan keadaan semasa dan memberikan sokongan agar rawatan dapat diteruskan dengan lebih konsisten.\n\nTerima kasih atas perhatian dan bimbingan anda.\n\n— Sistem Auto-Kepatuhan ISW',
   '["{nama}","{senarai}"]'::jsonb,
   false)
on conflict (key) do update set
   name = excluded.name, description = excluded.description, audience = excluded.audience,
   channels = excluded.channels, rule = excluded.rule, message_template = excluded.message_template,
   placeholders = excluded.placeholders;

select 'OK — kepatuhan_alert (gabungan) config ready (is_active=false; aktifkan di UI bila sedia)' as status;
