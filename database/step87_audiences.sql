-- STEP 87 — Audience tersimpan (boleh guna semula merentas automasi)
-- ─────────────────────────────────────────────────────────────────────────
-- Simpan set kriteria sasaran (conditions) yang bernama supaya boleh guna
-- semula bila cipta automasi. Bentuk conditions SAMA dengan psy_automations
-- (dinilai oleh enjin): [{field, op, value}]
--   field: patient_status | gender | has_whatsapp | package | state | age
--   op:    eq | in | between
-- Idempotent. WAJIB run TESTING & PROD.

create table if not exists psy_audiences (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  conditions jsonb default '[]'::jsonb,
  created_by uuid references psy_profiles(id) on delete set null,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);
alter table psy_audiences enable row level security;
do $$ begin
  create policy "audiences staff read" on psy_audiences for select
    using (auth.uid() in (select id from psy_profiles where role = 'staff'));
exception when duplicate_object then null; end $$;
do $$ begin
  create policy "audiences mgr manage" on psy_audiences for all
    using (auth.uid() in (select id from psy_profiles where staff_role in ('super_admin','manager')))
    with check (auth.uid() in (select id from psy_profiles where staff_role in ('super_admin','manager')));
exception when duplicate_object then null; end $$;

select 'Step 87 OK — psy_audiences sedia' as status;
