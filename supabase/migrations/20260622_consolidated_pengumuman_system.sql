-- =====================================================================
-- CONSOLIDATED — Sistem Pengumuman & Acara (ISW)  ·  Jun 2026
-- ---------------------------------------------------------------------
-- Gabungan SEMUA migration untuk modul Pengumuman/Acara.
-- Semua statement idempotent (if not exists / drop-create) — selamat
-- di-run berulang kali. Run SEKALI di production untuk pasang semua.
--
-- Menggantikan fail berikut (boleh dipadam jika guna fail ini sahaja):
--   20260620_patient_height_cm.sql
--   20260621_events_mvp.sql
--   20260621_pengumuman_unified.sql
--   20260622_announcement_expiry.sql
--   20260622_announcement_categories.sql
--   20260622_announcement_package_targeting.sql
--   20260622_announcement_types.sql
--   20260622_event_materials.sql
-- =====================================================================


-- 1) ─────────────  Pesakit: tinggi (untuk auto-BMI)  ─────────────
alter table psy_patients add column if not exists height_cm numeric;


-- 2) ─────────────  Acara / Kelas (events + pendaftaran)  ─────────────
create table if not exists psy_events (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text,
  type text default 'kelas',            -- kelas/webinar/komuniti/challenge/manzil
  start_at timestamptz not null,
  end_at timestamptz,
  mode text default 'online',           -- online/f2f
  meet_link text,
  location text,
  capacity int,                          -- null = tanpa had
  registration_deadline timestamptz,
  cover_image text,
  tag text,
  host text,
  price numeric default 0,
  status text default 'published',       -- draft/published/cancelled/completed
  recording_url text,
  created_by uuid,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table if not exists psy_event_registrations (
  id uuid primary key default gen_random_uuid(),
  event_id uuid references psy_events(id) on delete cascade,
  patient_id uuid references psy_patients(id) on delete cascade,
  status text default 'registered',      -- registered/waitlist/hadir/tak_hadir/batal
  registered_at timestamptz default now(),
  unique(event_id, patient_id)
);
create index if not exists idx_event_regs_event on psy_event_registrations(event_id);
create index if not exists idx_event_regs_patient on psy_event_registrations(patient_id);

alter table psy_events enable row level security;
alter table psy_event_registrations enable row level security;

drop policy if exists "events read" on psy_events;
create policy "events read" on psy_events for select using (
  status = 'published' or auth.uid() in (select id from psy_profiles where role='staff')
);
drop policy if exists "events staff manage" on psy_events;
create policy "events staff manage" on psy_events for all
  using (auth.uid() in (select id from psy_profiles where role='staff'))
  with check (auth.uid() in (select id from psy_profiles where role='staff'));

drop policy if exists "regs read" on psy_event_registrations;
create policy "regs read" on psy_event_registrations for select using (
  patient_id in (select id from psy_patients where user_id = auth.uid())
  or auth.uid() in (select id from psy_profiles where role='staff')
);
drop policy if exists "regs patient insert" on psy_event_registrations;
create policy "regs patient insert" on psy_event_registrations for insert with check (
  patient_id in (select id from psy_patients where user_id = auth.uid())
);
drop policy if exists "regs patient update" on psy_event_registrations;
create policy "regs patient update" on psy_event_registrations for update using (
  patient_id in (select id from psy_patients where user_id = auth.uid())
  or auth.uid() in (select id from psy_profiles where role='staff')
);
drop policy if exists "regs staff delete" on psy_event_registrations;
create policy "regs staff delete" on psy_event_registrations for delete using (
  auth.uid() in (select id from psy_profiles where role='staff')
);


-- 3) ─────────────  Lajur tambahan (pengumuman & event)  ─────────────
-- Announcements: kategori, kandungan panjang, sasaran audiens, tarikh tamat papar
alter table psy_announcements add column if not exists category   text;
alter table psy_announcements add column if not exists content    text;
alter table psy_announcements add column if not exists audience   jsonb default '["patient"]'::jsonb;
alter table psy_announcements add column if not exists expires_at timestamptz;

-- Events: alamat fizikal + pautan maps + sasaran audiens
alter table psy_events add column if not exists address  text;
alter table psy_events add column if not exists maps_url text;
alter table psy_events add column if not exists audience jsonb default '["patient"]'::jsonb;

-- Sasaran ikut pakej (kod pakej; [] = tiada sekatan)
alter table psy_announcements add column if not exists package_ids jsonb default '[]'::jsonb;
alter table psy_events        add column if not exists package_ids jsonb default '[]'::jsonb;


-- 4) ─────────────  Bahan / rakaman acara (pautan)  ─────────────
create table if not exists psy_event_materials (
  id uuid primary key default gen_random_uuid(),
  event_id uuid references psy_events(id) on delete cascade,
  title text not null,
  type text default 'pautan',            -- nota/video/slaid/pautan
  url text not null,
  created_at timestamptz default now()
);
create index if not exists idx_event_materials_event on psy_event_materials(event_id);

alter table psy_event_materials enable row level security;
drop policy if exists "materials read" on psy_event_materials;
create policy "materials read" on psy_event_materials for select using (
  exists (select 1 from psy_events e where e.id = event_id
          and (e.status = 'published' or auth.uid() in (select id from psy_profiles where role='staff')))
);
drop policy if exists "materials staff manage" on psy_event_materials;
create policy "materials staff manage" on psy_event_materials for all
  using (auth.uid() in (select id from psy_profiles where role='staff'))
  with check (auth.uid() in (select id from psy_profiles where role='staff'));


-- 5) ─────────────  Kategori pengumuman (in-app, super admin CRUD)  ─────────────
create table if not exists psy_announcement_categories (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  sort_order int default 0,
  is_active boolean default true,
  created_by uuid references psy_profiles(id) on delete set null,
  created_at timestamptz default now()
);
alter table psy_announcement_categories enable row level security;
drop policy if exists "ann_cat read" on psy_announcement_categories;
create policy "ann_cat read" on psy_announcement_categories for select using (
  auth.uid() in (select id from psy_profiles where role = 'staff')
);
drop policy if exists "ann_cat manage" on psy_announcement_categories;
create policy "ann_cat manage" on psy_announcement_categories for all
  using (auth.uid() in (select id from psy_profiles where staff_role = 'super_admin'))
  with check (auth.uid() in (select id from psy_profiles where staff_role = 'super_admin'));
insert into psy_announcement_categories (name, sort_order) values
  ('Promosi',1),('Info',2),('Kesihatan',3),('Kelas & Acara',4),
  ('Komuniti',5),('Webinar',6),('Bacaan Manzil',7),('Kemaskini Sistem',8)
on conflict (name) do nothing;


-- 6) ─────────────  Jenis pengumuman (in-app, super admin CRUD)  ─────────────
create table if not exists psy_announcement_types (
  id uuid primary key default gen_random_uuid(),
  key text not null unique,
  title text not null,
  description text default '',
  kind text not null default 'announcement',   -- 'announcement' | 'event'
  mode text,                                    -- 'f2f' | 'online' (events only)
  etype text,                                   -- kod jenis event (psy_events.type)
  label text,                                   -- tajuk kad event
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
insert into psy_announcement_types (key, title, description, kind, mode, etype, label, sort_order) values
  ('makluman',  'Makluman',            'Makluman umum, notis dan pengumuman biasa.',                'announcement', null,     null,      null,                        1),
  ('event_f2f', 'Event Fizikal (F2F)', 'Program atau acara yang dijalankan secara bersemuka.',      'event',        'f2f',    'kelas',   'Maklumat Event (Fizikal)',  2),
  ('webinar',   'Webinar / Online',    'Program atau sesi yang dijalankan secara online.',          'event',        'online', 'webinar', 'Maklumat Webinar (Online)', 3),
  ('manzil',    'Bacaan Manzil',       'Sesi bacaan manzil secara berkumpulan.',                    'event',        'online', 'manzil',  'Maklumat Sesi Manzil',      4),
  ('survey',    'Survey / Tindakan',   'Tindakan atau maklum balas daripada pengguna.',             'announcement', null,     null,      null,                        5),
  ('sistem',    'Kemaskini Sistem',    'Makluman berkaitan kemaskini atau penyelenggaraan sistem.', 'announcement', null,     null,      null,                        6)
on conflict (key) do nothing;

-- =====================================================================
-- SELESAI.
-- =====================================================================
