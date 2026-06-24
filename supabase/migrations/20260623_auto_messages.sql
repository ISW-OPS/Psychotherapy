-- =====================================================================
-- Mesej Automatik (auto-messages) — rangka umum
-- ---------------------------------------------------------------------
-- Satu tempat urus SEMUA mesej automatik: template + masa + on/off.
-- Edge function (cth event-reminders) baca konfig dari sini, jadi ubah
-- di UI = terus berkesan tanpa re-deploy. Idempotent.
-- =====================================================================

create table if not exists psy_auto_messages (
  id               uuid primary key default gen_random_uuid(),
  key              text not null unique,         -- 'event_reminder', 'catatan_harian', ...
  name             text not null,
  description      text,
  channel          text not null default 'whatsapp',
  trigger_type     text not null,                -- before_event | before_session | daily_reminder | on_action
  minutes_before   int,                          -- untuk before_* (cth 15/30/60)
  send_at_time     time,                          -- untuk daily_reminder (cth 20:00)
  message_template text not null,
  placeholders     jsonb default '[]'::jsonb,    -- senarai placeholder sah (rujukan UI)
  is_active        boolean default true,
  updated_by       uuid references psy_profiles(id) on delete set null,
  updated_at       timestamptz default now(),
  created_at       timestamptz default now()
);

alter table psy_auto_messages enable row level security;

-- Staff boleh baca; super_admin boleh urus
do $$ begin
  create policy "auto_msg staff read" on psy_auto_messages for select
    using (auth.uid() in (select id from psy_profiles where role = 'staff'));
exception when duplicate_object then null; end $$;

do $$ begin
  create policy "auto_msg super manage" on psy_auto_messages for all
    using (auth.uid() in (select id from psy_profiles where staff_role = 'super_admin'))
    with check (auth.uid() in (select id from psy_profiles where staff_role = 'super_admin'));
exception when duplicate_object then null; end $$;

-- ── Seed: auto-mesej sedia ada + placeholder untuk yang akan datang ──
insert into psy_auto_messages (key, name, description, trigger_type, minutes_before, send_at_time, message_template, placeholders, is_active) values
  ('event_reminder',
   'Peringatan Acara & Kelas',
   'Hantar peringatan kepada pesakit yang telah daftar, sebelum acara/kelas bermula.',
   'before_event', 30, null,
   E'Salam {nama} 👋\n\nPeringatan: acara *{acara}* akan bermula lebih kurang {lead} lagi ({masa}).\n{pautan}\n\n— Ibnu Sina Wellness',
   '["{nama}","{acara}","{masa}","{lead}","{pautan}"]'::jsonb,
   true),

  ('catatan_harian',
   'Peringatan Catatan Harian',
   'Ingatkan pesakit isi Catatan Harian setiap hari (jika belum diisi). Pencetus belum disambung.',
   'daily_reminder', null, '20:00',
   E'Salam {nama} 👋\n\nJangan lupa isi *Catatan Harian* anda hari ini ya. Ia membantu coach pantau kemajuan anda. 🌱\n\n— Ibnu Sina Wellness',
   '["{nama}"]'::jsonb,
   false),

  ('birthday',
   'Ucapan Hari Jadi',
   'Hantar ucapan pada tarikh lahir pesakit. Pencetus belum disambung.',
   'daily_reminder', null, '09:00',
   E'Selamat Hari Jadi, {nama}! 🎂\n\nSemoga sihat sejahtera & dimurahkan rezeki. Kami doakan kesembuhan & kebahagiaan anda.\n\n— Ibnu Sina Wellness',
   '["{nama}"]'::jsonb,
   false)
on conflict (key) do nothing;

-- ── RBAC: modul auto_messages (super admin) ──
insert into psy_modules (code, label, icon, sort_order) values
  ('auto_messages', 'Mesej Automatik', '🤖', 93)
on conflict (code) do update set label = excluded.label, icon = excluded.icon, sort_order = excluded.sort_order, is_active = true;

insert into psy_module_actions (module_code, action_code) values
  ('auto_messages','view'),('auto_messages','edit'),('auto_messages','settings')
on conflict do nothing;

insert into psy_role_module_actions (role_code, module_code, action_code)
select 'super_admin', module_code, action_code from psy_module_actions where module_code = 'auto_messages'
on conflict do nothing;

insert into psy_role_module_actions (role_code, module_code, action_code)
select 'manager', 'auto_messages', 'view' on conflict do nothing;

select 'OK — psy_auto_messages ready' as status;
