-- Event materials/recordings (link-based): staff add, patients view.
create table if not exists psy_event_materials (
  id uuid primary key default gen_random_uuid(),
  event_id uuid references psy_events(id) on delete cascade,
  title text not null,
  type text default 'pautan',     -- nota/video/slaid/pautan
  url text not null,
  created_at timestamptz default now()
);
create index if not exists idx_event_materials_event on psy_event_materials(event_id);

alter table psy_event_materials enable row level security;

-- Patients read materials of published events; staff read/manage all
drop policy if exists "materials read" on psy_event_materials;
create policy "materials read" on psy_event_materials for select using (
  exists (select 1 from psy_events e where e.id = event_id
          and (e.status = 'published' or auth.uid() in (select id from psy_profiles where role='staff')))
);
drop policy if exists "materials staff manage" on psy_event_materials;
create policy "materials staff manage" on psy_event_materials for all
  using (auth.uid() in (select id from psy_profiles where role='staff'))
  with check (auth.uid() in (select id from psy_profiles where role='staff'));
