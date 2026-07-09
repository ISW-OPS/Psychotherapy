-- STEP 86 — Rangka Sistem Automasi (builder penuh: trigger + conditions + actions)
-- ─────────────────────────────────────────────────────────────────────────
-- Jadual teras untuk "Create Automation" builder + log notifikasi.
-- Enjin (Edge Function) baca psy_automations aktif → nilai syarat → laksana
-- aksi → tulis ke psy_notification_logs. Idempotent. WAJIB run TESTING & PROD.

create table if not exists psy_automations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  is_active boolean default true,
  -- 1. TRIGGER
  trigger_category text not null,             -- appointment | payment | checkin | vitals | package | patient
  trigger_event text not null,                -- cth: session_reminder, payment_success, checkin_missed
  trigger_timing jsonb default '{}'::jsonb,   -- {when:'before'|'after'|'at'|'custom', value:1, unit:'day'}
  -- 2. CONDITIONS (AND) — pilihan
  conditions_enabled boolean default false,
  conditions jsonb default '[]'::jsonb,       -- [{field, op, value}]
  -- 3. ACTIONS
  actions jsonb default '[]'::jsonb,          -- ['whatsapp','inapp','email',...] + aksi lain
  -- 4. MESSAGE
  message_template text,                      -- teks inline (dgn {{placeholder}})
  message_channel text default 'whatsapp',
  -- Jadual jalan
  run_mode text default 'always',             -- always | scheduled
  run_days jsonb,                             -- [1,2,..] utk scheduled
  run_time time,
  -- Meta
  last_run_at timestamptz,
  created_by uuid references psy_profiles(id) on delete set null,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);
create index if not exists idx_psy_automations_active on psy_automations(is_active);
create index if not exists idx_psy_automations_trigger on psy_automations(trigger_category, trigger_event);

create table if not exists psy_notification_logs (
  id uuid primary key default gen_random_uuid(),
  automation_id uuid references psy_automations(id) on delete set null,
  patient_id uuid,
  patient_name text,
  event text,
  channel text,
  status text default 'pending',              -- sent | pending | failed | cancelled
  message text,
  response text,
  error text,
  sent_at timestamptz,
  created_at timestamptz default now()
);
create index if not exists idx_psy_notif_logs_created on psy_notification_logs(created_at desc);
create index if not exists idx_psy_notif_logs_automation on psy_notification_logs(automation_id);

alter table psy_automations enable row level security;
alter table psy_notification_logs enable row level security;

-- Staff boleh baca; super_admin/manager urus automasi.
do $$ begin
  create policy "automations staff read" on psy_automations for select
    using (auth.uid() in (select id from psy_profiles where role = 'staff'));
exception when duplicate_object then null; end $$;
do $$ begin
  create policy "automations mgr manage" on psy_automations for all
    using (auth.uid() in (select id from psy_profiles where staff_role in ('super_admin','manager')))
    with check (auth.uid() in (select id from psy_profiles where staff_role in ('super_admin','manager')));
exception when duplicate_object then null; end $$;

-- Log: staff baca; sistem (service_role) tulis dari Edge Function (bypass RLS).
do $$ begin
  create policy "notif_logs staff read" on psy_notification_logs for select
    using (auth.uid() in (select id from psy_profiles where role = 'staff'));
exception when duplicate_object then null; end $$;

select 'Step 86 OK — psy_automations + psy_notification_logs sedia' as status;
