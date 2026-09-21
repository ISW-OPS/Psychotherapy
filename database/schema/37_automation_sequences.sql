-- ═══════════════════════════════════════════════════════════════════
-- 37 — AUTOMATION SEQUENCES (psy_automation_messages)
-- Sokongan "sequence" berbilang mesej bagi SATU automasi (perjalanan
-- pesakit hari-demi-hari, cth Minggu 1 Hari 1/2/3...). Trigger
-- 'schedule' (Broadcast Berjadual) KEKAL guna psy_automations.message_template
-- sedia ada — jadual ini untuk trigger lain (cth patient_enrolled).
-- ═══════════════════════════════════════════════════════════════════

create table if not exists psy_automation_messages (
  id uuid primary key default gen_random_uuid(),
  automation_id uuid not null references psy_automations(id) on delete cascade,
  position int not null,
  -- BILA hantar (relatif ke anchor automasi, cth psy_treatment_plans.start_date)
  send_mode text not null default 'specific_time',   -- immediate | after_delay | specific_time
  day_offset int not null default 0,                 -- Hari ke-N sejak anchor (0 = hari sama)
  delay_value int,                                    -- utk send_mode='after_delay'
  delay_unit text,                                    -- minute | hour | day
  send_time time,                                     -- utk send_mode='specific_time' (jam:minit)
  -- APA hantar
  content_type text not null default 'text',          -- text | image | video | link
  message_text text not null default '',
  media_url text,                                     -- imej/video (attachment WhatsApp)
  link_url text,                                       -- pautan (dihantar sbg teks, BUKAN butang — GHL tiada sokongan butang)
  link_label text,
  attach_invoice boolean not null default false,       -- lampirkan PDF invois (hanya trigger ansuran — perlu {{pautan}} dlm teks)
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create index if not exists idx_psy_auto_msgs_automation on psy_automation_messages(automation_id, position);

alter table psy_automation_messages enable row level security;

drop policy if exists "auto_msgs staff read" on psy_automation_messages;
create policy "auto_msgs staff read" on psy_automation_messages for select
  using (auth.uid() in (select id from psy_profiles where role = 'staff'));

drop policy if exists "auto_msgs mgr manage" on psy_automation_messages;
create policy "auto_msgs mgr manage" on psy_automation_messages for all
  using (auth.uid() in (select id from psy_profiles where staff_role in ('super_admin','manager')))
  with check (auth.uid() in (select id from psy_profiles where staff_role in ('super_admin','manager')));

-- Kaitkan log hantaran dengan mesej tertentu dalam sequence (dedup + statistik per-mesej).
-- NULL utk log lama/broadcast tunggal (message_template).
alter table psy_notification_logs add column if not exists message_id uuid references psy_automation_messages(id) on delete set null;

create index if not exists idx_psy_notif_logs_message on psy_notification_logs(message_id);
