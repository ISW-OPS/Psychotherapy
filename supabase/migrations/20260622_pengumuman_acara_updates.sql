-- =====================================================================
-- Kemaskini Pengumuman & Acara — gabungan (Jun 2026)
-- ---------------------------------------------------------------------
-- Semua statement idempotent — selamat run berulang. Run SEKALI di
-- production untuk pasang semua perubahan sesi ini.
--
-- Kandungan:
--   1) psy_events.host_role        — peranan pengendali (Penceramah/Coach/Moderator)
--   2) psy_event_registrations.reminder_sent_at — penanda peringatan WhatsApp 1 jam
--   3) RBAC staff: modul `events` (Acara & Kelas) berasingan dari Pengumuman
--   4) RBAC patient: modul `pat_announcements` + `pat_events`
-- =====================================================================


-- 1) ──────────  Acara: peranan pengendali  ──────────
alter table psy_events add column if not exists host_role text;   -- Penceramah / Coach / Moderator


-- 2) ──────────  Peringatan WhatsApp 1 jam sebelum acara  ──────────
-- Penanda dedup — setiap pendaftaran diperingat sekali sahaja (Edge Function event-reminders).
alter table psy_event_registrations add column if not exists reminder_sent_at timestamptz;

-- (OPSYENAL) Jadual pg_cron — panggil Edge Function tiap 15 minit.
-- Perlukan extension pg_cron + pg_net. Ganti <PROJECT_REF> & <CRON_SECRET>.
-- create extension if not exists pg_cron;
-- create extension if not exists pg_net;
-- select cron.schedule('event-reminders', '*/15 * * * *', $$
--   select net.http_post(
--     url     := 'https://<PROJECT_REF>.supabase.co/functions/v1/event-reminders',
--     headers := jsonb_build_object('Content-Type','application/json','x-cron-secret','<CRON_SECRET>'),
--     body    := '{}'::jsonb
--   );
-- $$);


-- 3) ──────────  RBAC staff: modul Acara & Kelas (events)  ──────────
-- Berasingan dari `announcements`. Warisi grant sedia ada dari Pengumuman
-- supaya role yang sudah urus Pengumuman tak hilang akses Acara.
insert into psy_modules (code, label, icon, sort_order) values
  ('events', 'Acara & Kelas', '📅', 92)
on conflict (code) do update
  set label = excluded.label, icon = excluded.icon, sort_order = excluded.sort_order, is_active = true;

insert into psy_module_actions (module_code, action_code) values
  ('events','view'),('events','create'),('events','edit'),('events','delete'),('events','settings')
on conflict do nothing;

insert into psy_role_module_actions (role_code, module_code, action_code)
select 'super_admin', module_code, action_code from psy_module_actions where module_code = 'events'
on conflict do nothing;

insert into psy_role_module_actions (role_code, module_code, action_code)
select 'manager', module_code, action_code from psy_module_actions where module_code = 'events'
on conflict do nothing;

insert into psy_role_module_actions (role_code, module_code, action_code)
select role_code, 'events', action_code
from psy_role_module_actions
where module_code = 'announcements'
  and action_code in (select action_code from psy_module_actions where module_code = 'events')
on conflict do nothing;


-- 4) ──────────  RBAC patient: Pengumuman + Acara & Kelas  ──────────
insert into psy_modules (code, label, icon, scope, sort_order) values
  ('pat_announcements', 'Pengumuman',    '📢', 'patient', 12),
  ('pat_events',        'Acara & Kelas', '📅', 'patient', 15)
on conflict (code) do update
  set label = excluded.label, icon = excluded.icon, scope = 'patient', is_active = true;

insert into psy_module_actions (module_code, action_code) values
  ('pat_announcements', 'view'),
  ('pat_events', 'view')
on conflict do nothing;

insert into psy_role_module_actions (role_code, module_code, action_code) values
  ('patient', 'pat_announcements', 'view'),
  ('patient', 'pat_events', 'view')
on conflict do nothing;


select 'OK — Pengumuman & Acara updates applied' as status;
