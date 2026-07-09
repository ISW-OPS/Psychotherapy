-- STEP 91 — Pengesahan Sesi — Fasa 2
-- ─────────────────────────────────────────────────────────────────────────
-- Aliran: sebelum sesi rawatan, sistem hantar peringatan WhatsApp (teks
-- sahaja, tiada butang/pautan) minta pesakit BALAS untuk sahkan kehadiran.
-- Staff baca balasan tu & tandakan di roles/staff/kehadiran.html (butang
-- "Tandakan Disahkan" / "Tukar Tarikh" → plan-week.html). Notifikasi in-app
-- turut dihantar dgn pautan plan.html (laluan pilihan utk pesakit guna app).
-- Bila tinggal ≤ deadline_hours (cth 24 jam) masih belum ditandakan sahkan
-- → alert COACH (psy_risk_alerts + loceng). Enjin: supabase/functions/
-- event-reminders (runSessionConfirm). Konfig di sini (psy_auto_messages
-- key='session_confirm'). Idempotent. WAJIB run TESTING & PROD, kemudian
-- redeploy event-reminders.

-- ── 1) Lajur dedup + pengesahan pada baris sesi ──
-- (patient_confirmed / patient_confirmed_at / patient_absence_reason sepatutnya
--  sudah wujud dari langkah terdahulu — tambah defensif jika belum.)
alter table psy_plan_weekly_progress add column if not exists patient_confirmed        boolean;
alter table psy_plan_weekly_progress add column if not exists patient_confirmed_at      timestamptz;
alter table psy_plan_weekly_progress add column if not exists patient_absence_reason    text;
alter table psy_plan_weekly_progress add column if not exists confirm_reminder_sent_at  timestamptz;  -- dedup peringatan (per sesi)
alter table psy_plan_weekly_progress add column if not exists confirm_escalated_at      timestamptz;  -- dedup escalation coach (per sesi)

-- Index bantu enjin cari sesi belum-sahkan dalam tetingkap
create index if not exists idx_pwp_confirm_window
  on psy_plan_weekly_progress (session_date)
  where status = 'booked' and patient_confirmed is null;

-- ── 2) Pastikan lajur konfig psy_auto_messages sedia (defensif) ──
alter table psy_auto_messages add column if not exists channels     jsonb default '["whatsapp","inapp"]'::jsonb;
alter table psy_auto_messages add column if not exists rule         jsonb;
alter table psy_auto_messages add column if not exists link         text;
alter table psy_auto_messages add column if not exists days_of_week jsonb;
alter table psy_auto_messages add column if not exists session_time time;
alter table psy_auto_messages add column if not exists last_broadcast_at timestamptz;
alter table psy_auto_messages add column if not exists category     text;
alter table psy_auto_messages add column if not exists language     text default 'ms';

-- ── 3) Seed/kemaskini baris konfig 'session_confirm' (staff hidupkan di UI) ──
--   rule.lead_days      : berapa hari sebelum sesi peringatan dihantar (default 3)
--   rule.deadline_hours : had sahkan/tukar tarikh sebelum sesi (default 24)
--   rule.escalate       : alert coach bila lepas had & belum ditandakan sahkan
--   send_at_time        : jam harian peringatan dihantar (elak tengah malam)
--   Pembolehubah {sesi_akan_datang}/{tarikh_sesi}/{masa_sesi}/{nama_klinik} —
--   sepadan set kanonik (Variables Library, kategori "Temujanji"), supaya
--   skrin Test Automation & Automation Builder pun boleh papar/uji betul.
-- UPSERT: guna DO UPDATE (bukan DO NOTHING) supaya run semula step ni
-- mengemaskini template/config sedia ada — is_active TIDAK disentuh (kekal
-- toggle staff semasa).
insert into psy_auto_messages
  (key, name, description, channel, trigger_type, send_at_time, message_template,
   placeholders, channels, rule, category, language, is_active)
values
  ('session_confirm',
   'Pengesahan Sesi Rawatan',
   'Sebelum sesi rawatan, WA minta pesakit balas teks utk sahkan kehadiran; staff tandakan di Kehadiran. Bila tinggal ≤ had jam & belum ditandakan, alert coach.',
   'whatsapp', 'before_session', '10:00',
   E'Salam {nama} 👋\n\nPeringatan sesi rawatan anda:\n📅 {sesi_akan_datang}\n🗓️ {tarikh_sesi} · {masa_sesi}\n\nBoleh hadir? Sila *balas mesej ini* untuk sahkan kehadiran 🙏\nJika perlu tukar tarikh, beritahu kami — pihak klinik akan bantu aturkan (selewat-lewatnya 24 jam sebelum sesi).\n\nJika tiada maklum balas, slot mungkin dilepaskan & caj tidak hadir boleh dikenakan.\n\n— {nama_klinik}',
   '["{nama}","{sesi_akan_datang}","{tarikh_sesi}","{masa_sesi}","{nama_klinik}"]'::jsonb,
   '["whatsapp","inapp"]'::jsonb,
   '{"lead_days":3,"deadline_hours":24,"escalate":{"on":true,"severity":"medium"}}'::jsonb,
   'temujanji', 'ms',
   false)
on conflict (key) do update set
  name             = excluded.name,
  description      = excluded.description,
  channel          = excluded.channel,
  trigger_type     = excluded.trigger_type,
  send_at_time     = excluded.send_at_time,
  message_template = excluded.message_template,
  placeholders     = excluded.placeholders,
  channels         = excluded.channels,
  rule             = excluded.rule,
  category         = excluded.category,
  language         = excluded.language,
  updated_at       = now();
  -- is_active SENGAJA tidak dikemaskini — kekal pilihan staff semasa

select 'Step 91 OK — pengesahan sesi (session_confirm) sedia' as status;
