-- ============ EVENTS / KELAS (MVP) ============
-- Acara/kelas/webinar/komuniti yang pesakit boleh daftar (RSVP).
-- psy_events = acara; psy_event_registrations = pendaftaran pesakit.
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

-- Pesakit baca event published; staf urus semua
drop policy if exists "events read" on psy_events;
create policy "events read" on psy_events for select using (
  status = 'published' or auth.uid() in (select id from psy_profiles where role='staff')
);
drop policy if exists "events staff manage" on psy_events;
create policy "events staff manage" on psy_events for all
  using (auth.uid() in (select id from psy_profiles where role='staff'))
  with check (auth.uid() in (select id from psy_profiles where role='staff'));

-- Pendaftaran: pesakit urus sendiri; staf baca/urus semua
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
