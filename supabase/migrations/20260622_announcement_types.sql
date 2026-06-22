-- Announcement types: managed in-app (super admin CRUD). Each type carries behaviour:
-- kind = 'announcement' (plain) or 'event'; for events, mode = 'f2f' | 'online'.
create table if not exists psy_announcement_types (
  id uuid primary key default gen_random_uuid(),
  key text not null unique,
  title text not null,
  description text default '',
  kind text not null default 'announcement',   -- 'announcement' | 'event'
  mode text,                                    -- 'f2f' | 'online' (events only)
  etype text,                                   -- event type code (stored on psy_events.type)
  label text,                                   -- event card heading
  sort_order int default 0,
  is_active boolean default true,
  created_by uuid references psy_profiles(id) on delete set null,
  created_at timestamptz default now()
);
create index if not exists idx_ann_types_sort on psy_announcement_types(sort_order);

alter table psy_announcement_types enable row level security;

drop policy if exists "ann_types read" on psy_announcement_types;
create policy "ann_types read" on psy_announcement_types for select using (
  auth.uid() in (select id from psy_profiles where role = 'staff')
);

drop policy if exists "ann_types manage" on psy_announcement_types;
create policy "ann_types manage" on psy_announcement_types for all
  using (auth.uid() in (select id from psy_profiles where staff_role = 'super_admin'))
  with check (auth.uid() in (select id from psy_profiles where staff_role = 'super_admin'));

-- Seed the existing built-in types
insert into psy_announcement_types (key, title, description, kind, mode, etype, label, sort_order) values
  ('makluman',  'Makluman',            'Makluman umum, notis dan pengumuman biasa.',                     'announcement', null,     null,      null,                         1),
  ('event_f2f', 'Event Fizikal (F2F)', 'Program atau acara yang dijalankan secara bersemuka.',           'event',        'f2f',    'kelas',   'Maklumat Event (Fizikal)',   2),
  ('webinar',   'Webinar / Online',    'Program atau sesi yang dijalankan secara online.',               'event',        'online', 'webinar', 'Maklumat Webinar (Online)',  3),
  ('manzil',    'Bacaan Manzil',       'Sesi bacaan manzil secara berkumpulan.',                         'event',        'online', 'manzil',  'Maklumat Sesi Manzil',       4),
  ('survey',    'Survey / Tindakan',   'Tindakan atau maklum balas daripada pengguna.',                  'announcement', null,     null,      null,                         5),
  ('sistem',    'Kemaskini Sistem',    'Makluman berkaitan kemaskini atau penyelenggaraan sistem.',      'announcement', null,     null,      null,                         6)
on conflict (key) do nothing;
