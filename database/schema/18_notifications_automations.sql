-- ═══════════════════════════════════════════════════════════════════
-- 18 — NOTIFIKASI & AUTOMASI
-- Notifikasi dalam-app, mesej automatik (template WhatsApp), builder
-- automasi + log, audience tersimpan, alert kepatuhan & risiko, task coach.
-- Jadual: psy_notifications, psy_auto_messages, psy_automations,
--         psy_notification_logs, psy_audiences, psy_adherence_alerts,
--         psy_risk_alerts, psy_coach_tasks
-- ═══════════════════════════════════════════════════════════════════

-- ──── psy_notifications — notifikasi loceng dalam-app ────
CREATE TABLE IF NOT EXISTS psy_notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES psy_profiles(id) ON DELETE CASCADE NOT NULL,
  type TEXT DEFAULT 'system'
    CHECK (type IN ('appointment','order','plan','system','reaksi','kyc','referral')),
  title TEXT NOT NULL,
  body TEXT,
  link TEXT,
  is_read BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_psy_notifications_user ON psy_notifications(user_id, is_read, created_at DESC);

ALTER TABLE psy_notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users read own notifications" ON psy_notifications;
CREATE POLICY "Users read own notifications" ON psy_notifications FOR SELECT
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Users update own notifications" ON psy_notifications;
CREATE POLICY "Users update own notifications" ON psy_notifications FOR UPDATE
  USING (user_id = auth.uid());

-- INSERT dihadkan kepada staff sahaja; pesakit cetus notif via trigger SECURITY DEFINER
DROP POLICY IF EXISTS "Staff insert notifications" ON psy_notifications;
CREATE POLICY "Staff insert notifications" ON psy_notifications FOR INSERT
  WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- Nota: fn_complete_expired_treatments() ditakrif dalam 07_treatment_plans.sql
-- (domain rawatan); fungsi itu insert ke psy_notifications di atas.

-- ──── Fungsi trigger: notif pesakit bila coach buka minggu baru ────
CREATE OR REPLACE FUNCTION trg_notify_patient_new_week()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_user_id UUID;
BEGIN
  SELECT user_id INTO v_user_id FROM psy_patients WHERE id = NEW.patient_id;
  IF v_user_id IS NULL THEN RETURN NEW; END IF;

  -- Dedup: satu notifikasi per pesakit per plan+minggu
  IF EXISTS (
    SELECT 1 FROM psy_notifications
    WHERE user_id = v_user_id
      AND type = 'plan'
      AND link LIKE '%plan_id=' || NEW.plan_id::TEXT || '%week=' || NEW.week_number
    LIMIT 1
  ) THEN RETURN NEW; END IF;

  INSERT INTO psy_notifications (user_id, type, title, body, link)
  VALUES (
    v_user_id, 'plan',
    'Sila Hantar Laporan Reaksi — Minggu ' || NEW.week_number,
    'Minggu ' || NEW.week_number || ' rawatan anda bermula. Rekod simptom reaksi pemulihan yang anda alami.',
    'plan-week.html?plan_id=' || NEW.plan_id::TEXT || '&week=' || NEW.week_number
  );
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE LOG 'trg_notify_patient_new_week: %', SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_patient_new_week ON psy_plan_weekly_progress;
CREATE TRIGGER trg_notify_patient_new_week
  AFTER INSERT ON psy_plan_weekly_progress
  FOR EACH ROW EXECUTE FUNCTION trg_notify_patient_new_week();

-- ──── Fungsi trigger: notif coach bila pesakit hantar laporan reaksi ────
CREATE OR REPLACE FUNCTION trg_patient_reaksi_notify_coach()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_coach_id    UUID;
  v_patient_name TEXT;
BEGIN
  -- Hantar sekali sahaja pada INSERT, bukan UPDATE
  IF TG_OP != 'INSERT' THEN RETURN NEW; END IF;

  SELECT pr.full_name INTO v_patient_name
  FROM psy_patients pt
  JOIN psy_profiles pr ON pr.id = pt.user_id
  WHERE pt.id = NEW.patient_id;

  -- Coach dari psy_patients.coach_id dahulu
  SELECT coach_id INTO v_coach_id FROM psy_patients WHERE id = NEW.patient_id;

  -- Fallback: baris progres mingguan terkini untuk plan ini
  IF v_coach_id IS NULL THEN
    SELECT coach_id INTO v_coach_id FROM psy_plan_weekly_progress
    WHERE plan_id = NEW.plan_id AND patient_id = NEW.patient_id
    ORDER BY created_at DESC LIMIT 1;
  END IF;

  IF v_coach_id IS NOT NULL THEN
    INSERT INTO psy_notifications (user_id, type, title, body, link)
    VALUES (
      v_coach_id, 'reaksi',
      '🌀 Laporan Reaksi: ' || COALESCE(v_patient_name, 'Pesakit'),
      'Minggu ' || NEW.week_number || ' — ' || COALESCE(v_patient_name, 'Pesakit') || ' telah hantar laporan reaksi pemulihan.',
      'plan-week.html?plan_id=' || NEW.plan_id::TEXT || '&week=' || NEW.week_number
    );
  END IF;
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE LOG 'trg_patient_reaksi_notify_coach: %', SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_patient_reaksi_notify_coach ON psy_patient_reaksi_reports;
CREATE TRIGGER trg_patient_reaksi_notify_coach
  AFTER INSERT ON psy_patient_reaksi_reports
  FOR EACH ROW EXECUTE FUNCTION trg_patient_reaksi_notify_coach();

-- ──── Fungsi trigger: notif semua staff bila pesanan baru ────
CREATE OR REPLACE FUNCTION trg_notify_staff_new_order()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_patient_name TEXT;
  v_staff        RECORD;
BEGIN
  SELECT full_name INTO v_patient_name FROM psy_profiles WHERE id = NEW.patient_id;

  FOR v_staff IN SELECT id FROM psy_profiles WHERE role = 'staff' LOOP
    INSERT INTO psy_notifications (user_id, type, title, body, link)
    VALUES (
      v_staff.id, 'order',
      '📦 Pesanan Baru: ' || COALESCE(v_patient_name, 'Pesakit'),
      'Pesanan ' || COALESCE(NEW.order_ref, '') || ' diterima. Sila proses penghantaran.',
      'orders.html'
    );
  END LOOP;
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE LOG 'trg_notify_staff_new_order: %', SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_staff_new_order ON psy_orders;
CREATE TRIGGER trg_notify_staff_new_order
  AFTER INSERT ON psy_orders
  FOR EACH ROW EXECUTE FUNCTION trg_notify_staff_new_order();

-- ──── Fungsi trigger: alert coach bila advice log zon merah/kuning ────
-- Satu submission boleh insert hingga 3 baris mesej serentak; notifikasi
-- hanya utk BARIS PERTAMA (send_after ≈ created_at; baris 2/3 = +5/+10 min).
CREATE OR REPLACE FUNCTION trg_reaksi_advice_notify_emergency()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_coach_id     UUID;
  v_patient_name TEXT;
  v_first_row    BOOLEAN;
BEGIN
  -- Baris pertama submission sahaja (elak notifikasi berganda 3x)
  v_first_row := (NEW.send_after IS NULL OR NEW.send_after <= NEW.created_at + interval '2 minutes');
  IF NOT v_first_row THEN RETURN NEW; END IF;

  IF NOT (NEW.is_emergency OR NEW.zon IN ('merah','kuning')) THEN RETURN NEW; END IF;

  SELECT pt.coach_id, COALESCE(pr.full_name, pt.full_name, 'Pesakit')
    INTO v_coach_id, v_patient_name
  FROM psy_patients pt
  LEFT JOIN psy_profiles pr ON pr.id = pt.user_id
  WHERE pt.id = NEW.patient_id;
  IF v_coach_id IS NULL THEN RETURN NEW; END IF;

  IF NEW.is_emergency OR NEW.zon = 'merah' THEN
    INSERT INTO psy_notifications (user_id, type, title, body, link)
    VALUES (
      v_coach_id, 'reaksi',
      '🔴 ZON MERAH: ' || v_patient_name,
      v_patient_name || ' melaporkan simptom tahap tinggi/kecemasan dalam Poll Harian. Pesakit dinasihatkan ke hospital & telah dihantar mesej kritikal — sila susul SEGERA.',
      'kepatuhan.html'
    );
  ELSE
    INSERT INTO psy_notifications (user_id, type, title, body, link)
    VALUES (
      v_coach_id, 'reaksi',
      '🟡 Zon Kuning: ' || v_patient_name,
      v_patient_name || ' melaporkan simptom tahap sederhana dalam Poll Harian — perlukan perhatian coach. Sila semak dan susul pesakit.',
      'kepatuhan.html'
    );
  END IF;
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE LOG 'trg_reaksi_advice_notify_emergency: %', SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_reaksi_advice_notify_emergency ON psy_reaksi_advice_log;
CREATE TRIGGER trg_reaksi_advice_notify_emergency
  AFTER INSERT ON psy_reaksi_advice_log
  FOR EACH ROW EXECUTE FUNCTION trg_reaksi_advice_notify_emergency();

-- ──── psy_auto_messages — Mesej Automatik (template + masa + on/off) ────
-- Edge function (cth event-reminders) baca konfig dari sini; ubah di UI
-- auto-mesej.html = terus berkesan tanpa re-deploy.
create table if not exists psy_auto_messages (
  id uuid primary key default gen_random_uuid(),
  key text not null unique,               -- 'event_reminder', 'catatan_harian', ...
  name text not null,
  description text,
  channel text not null default 'whatsapp',
  trigger_type text not null,             -- before_event | before_session | daily_reminder | on_action | recurring_broadcast
  minutes_before int,                     -- untuk before_* (cth 15/30/60)
  send_at_time time,                      -- untuk daily_reminder (cth 20:00)
  days_of_week jsonb,                     -- [3,4,5] = Rab/Kha/Jum (0=Ahad .. 6=Sabtu)
  session_time time,                      -- masa sesi bermula (recurring_broadcast)
  audience jsonb default '["patient"]'::jsonb,
  package_ids jsonb default '[]'::jsonb,
  channels jsonb default '["whatsapp"]'::jsonb,  -- whatsapp | inapp | announcement | email
  link text,
  last_broadcast_at timestamptz,          -- dedup: kali terakhir dihantar
  rule jsonb,                             -- ambang utk alert berasaskan logik (cth kepatuhan)
  message_template text not null,
  placeholders jsonb default '[]'::jsonb, -- senarai placeholder sah (rujukan UI)
  category text,
  language text default 'ms',
  tags jsonb default '[]'::jsonb,
  created_by uuid references psy_profiles(id) on delete set null,
  is_active boolean default true,
  updated_by uuid references psy_profiles(id) on delete set null,
  updated_at timestamptz default now(),
  created_at timestamptz default now()
);

alter table psy_auto_messages enable row level security;

drop policy if exists "auto_msg staff read" on psy_auto_messages;
create policy "auto_msg staff read" on psy_auto_messages for select
  using (auth.uid() in (select id from psy_profiles where role = 'staff'));

drop policy if exists "auto_msg super manage" on psy_auto_messages;
create policy "auto_msg super manage" on psy_auto_messages for all
  using (auth.uid() in (select id from psy_profiles where staff_role = 'super_admin'))
  with check (auth.uid() in (select id from psy_profiles where staff_role = 'super_admin'));

-- Pesakit perlu BACA template reaksi sahaja (client jana mesej semasa submit
-- Poll Harian). Template auto-mesej lain kekal staff-only.
drop policy if exists "auto_msg patient read reaksi" on psy_auto_messages;
create policy "auto_msg patient read reaksi" on psy_auto_messages for select
  using (auth.uid() is not null and key like 'reaksi_%' and is_active = true);

comment on column psy_auto_messages.rule is
  'Peraturan/ambang untuk alert berasaskan logik. Cth kepatuhan: {"severity":"high","window_days":7,"email_from":"support@ibnusinawellness.com","checks":{"amalan":{"on":true,"min_days_short":3},"checklist":{"on":true,"min_days_missing":3},"skor":{"on":true,"min_score":80},"vitals":{"on":true,"min_days_since":7}}}';

-- ──── psy_automations — builder automasi (trigger + conditions + actions) ────
-- Enjin (Edge Function) baca automasi aktif → nilai syarat → laksana aksi →
-- tulis ke psy_notification_logs.
create table if not exists psy_automations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  is_active boolean default true,
  -- status bertiga (is_active disegerakkan: is_active = status='active')
  status text default 'draft',                -- draft | active | paused
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

alter table psy_automations enable row level security;

-- Staff boleh baca; super_admin/manager urus automasi.
drop policy if exists "automations staff read" on psy_automations;
create policy "automations staff read" on psy_automations for select
  using (auth.uid() in (select id from psy_profiles where role = 'staff'));

drop policy if exists "automations mgr manage" on psy_automations;
create policy "automations mgr manage" on psy_automations for all
  using (auth.uid() in (select id from psy_profiles where staff_role in ('super_admin','manager')))
  with check (auth.uid() in (select id from psy_profiles where staff_role in ('super_admin','manager')));

-- ──── psy_notification_logs — log hantaran enjin automasi ────
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

alter table psy_notification_logs enable row level security;

-- Log: staff baca; sistem (service_role) tulis dari Edge Function (bypass RLS).
drop policy if exists "notif_logs staff read" on psy_notification_logs;
create policy "notif_logs staff read" on psy_notification_logs for select
  using (auth.uid() in (select id from psy_profiles where role = 'staff'));

-- ──── psy_audiences — audience tersimpan (guna semula merentas automasi) ────
-- Bentuk conditions SAMA dengan psy_automations: [{field, op, value}]
--   field: patient_status | gender | has_whatsapp | package | state | age
--   op:    eq | in | between
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

drop policy if exists "audiences staff read" on psy_audiences;
create policy "audiences staff read" on psy_audiences for select
  using (auth.uid() in (select id from psy_profiles where role = 'staff'));

drop policy if exists "audiences mgr manage" on psy_audiences;
create policy "audiences mgr manage" on psy_audiences for all
  using (auth.uid() in (select id from psy_profiles where staff_role in ('super_admin','manager')))
  with check (auth.uid() in (select id from psy_profiles where staff_role in ('super_admin','manager')));

-- ──── psy_adherence_alerts — alert kepatuhan pesakit (madu, dll) ────
-- Coach dapat notif bila patient kurang madu 4+ hari berturut.
CREATE TABLE IF NOT EXISTS psy_adherence_alerts (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id    UUID REFERENCES psy_patients(id) ON DELETE CASCADE NOT NULL,
  alert_type    TEXT NOT NULL,             -- 'madu_low_5days' / 'madu_low_4days'
  trigger_date  DATE NOT NULL,             -- tarikh alert dikira
  details       JSONB DEFAULT '{}',        -- snapshot: { target, days_below: [...], counts: {} }
  notified_coach_id UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  acknowledged_by   UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  acknowledged_at   TIMESTAMPTZ,
  created_at    TIMESTAMPTZ DEFAULT now(),
  UNIQUE (patient_id, alert_type, trigger_date)  -- elak duplicate sehari
);

CREATE INDEX IF NOT EXISTS idx_adherence_patient ON psy_adherence_alerts(patient_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_adherence_unack   ON psy_adherence_alerts(acknowledged_at) WHERE acknowledged_at IS NULL;

ALTER TABLE psy_adherence_alerts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Patient read own adherence" ON psy_adherence_alerts;
CREATE POLICY "Patient read own adherence" ON psy_adherence_alerts
  FOR SELECT USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Staff read all adherence" ON psy_adherence_alerts;
CREATE POLICY "Staff read all adherence" ON psy_adherence_alerts
  FOR SELECT USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "Staff manage adherence" ON psy_adherence_alerts;
CREATE POLICY "Staff manage adherence" ON psy_adherence_alerts
  FOR ALL USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
  WITH CHECK (auth.uid() IS NOT NULL);

-- Patient pun boleh insert (patient dashboard trigger check)
DROP POLICY IF EXISTS "Patient insert own adherence" ON psy_adherence_alerts;
CREATE POLICY "Patient insert own adherence" ON psy_adherence_alerts
  FOR INSERT WITH CHECK (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

-- ──── psy_risk_alerts — alert risiko pesakit ────
CREATE TABLE IF NOT EXISTS psy_risk_alerts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id UUID REFERENCES psy_patients(id) ON DELETE CASCADE NOT NULL,
  patient_name TEXT,
  created_by UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  created_by_name TEXT,
  severity TEXT DEFAULT 'medium' CHECK (severity IN ('low','medium','high','critical')),
  category TEXT,
  description TEXT,
  status TEXT DEFAULT 'open' CHECK (status IN ('open','acknowledged','resolved')),
  acknowledged_by UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  resolved_at TIMESTAMPTZ,
  resolution_notes TEXT,                    -- nota tindakan semasa resolve
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_psy_risk_patient ON psy_risk_alerts(patient_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_psy_risk_status ON psy_risk_alerts(status, created_at DESC);

ALTER TABLE psy_risk_alerts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff manage risk alerts" ON psy_risk_alerts;
CREATE POLICY "Staff manage risk alerts" ON psy_risk_alerts FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- ──── psy_coach_tasks — task harian peribadi coach (ClickUp-style) ────
CREATE TABLE IF NOT EXISTS psy_coach_tasks (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  coach_id     UUID NOT NULL REFERENCES psy_profiles(id) ON DELETE CASCADE,
  title        TEXT NOT NULL,
  notes        TEXT,
  task_date    DATE NOT NULL,
  status       TEXT DEFAULT 'belum_mula' CHECK (status IN ('belum_mula','dalam_proses','selesai')),
  priority     TEXT DEFAULT 'sederhana'  CHECK (priority IN ('rendah','sederhana','tinggi')),
  patient_id   UUID REFERENCES psy_patients(id) ON DELETE SET NULL,
  session_id   UUID REFERENCES psy_plan_weekly_progress(id) ON DELETE SET NULL,
  created_at   TIMESTAMPTZ DEFAULT now(),
  updated_at   TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_coach_tasks_coach_date ON psy_coach_tasks (coach_id, task_date);

ALTER TABLE psy_coach_tasks ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "coach_tasks_own" ON psy_coach_tasks;
CREATE POLICY "coach_tasks_own" ON psy_coach_tasks
  USING (coach_id = auth.uid())
  WITH CHECK (coach_id = auth.uid());

DROP POLICY IF EXISTS "coach_tasks_manager_read" ON psy_coach_tasks;
CREATE POLICY "coach_tasks_manager_read" ON psy_coach_tasks
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff' AND staff_role IN ('manager','admin'))
  );

-- ═══════════════════════════════════════════════════════════════════
-- SEED — template Mesej Automatik (psy_auto_messages)
-- ═══════════════════════════════════════════════════════════════════

-- Peringatan acara/kelas + Catatan Harian + hari jadi
insert into psy_auto_messages (key, name, description, trigger_type, minutes_before, send_at_time, days_of_week, audience, channels, message_template, placeholders, is_active) values
  ('event_reminder',
   'Peringatan Acara & Kelas',
   'Hantar peringatan kepada pesakit yang telah daftar, sebelum acara/kelas bermula.',
   'before_event', 30, null, null, '["patient"]'::jsonb, '["whatsapp"]'::jsonb,
   E'Salam {nama} 👋\n\nPeringatan: acara *{acara}* akan bermula lebih kurang {lead} lagi ({masa}).\n{pautan}\n\n— Ibnu Sina Wellness',
   '["{nama}","{acara}","{masa}","{lead}","{pautan}"]'::jsonb,
   true),

  ('catatan_harian',
   'Peringatan Catatan Harian',
   'Hantar WA kpd pesakit aktif yang belum isi Catatan Harian pada masa ditetapkan (cth 20:00). Dedup 1×/hari. Aktifkan di UI bila sedia.',
   'daily_reminder', null, '20:00', '[0,1,2,3,4,5,6]'::jsonb, '["patient"]'::jsonb, '["whatsapp"]'::jsonb,
   E'Salam {nama} 👋\n\nKami perasan anda belum isi *Catatan Harian* hari ini. Luangkan 2 minit untuk rekod amalan & perasaan anda — konsistensi setiap hari membantu pemulihan anda lebih cepat. 🌱\n\nIsi sekarang di aplikasi Ibnu Sina Wellness.\n\n— Ibnu Sina Wellness',
   '["{nama}"]'::jsonb,
   false),

  ('birthday',
   'Ucapan Hari Jadi',
   'Hantar ucapan pada tarikh lahir pesakit. Pencetus belum disambung.',
   'daily_reminder', null, '09:00', null, '["patient"]'::jsonb, '["whatsapp"]'::jsonb,
   E'Selamat Hari Jadi, {nama}! 🎂\n\nSemoga sihat sejahtera & dimurahkan rezeki. Kami doakan kesembuhan & kebahagiaan anda.\n\n— Ibnu Sina Wellness',
   '["{nama}"]'::jsonb,
   false)
on conflict (key) do nothing;

-- Broadcast berulang: Manzil Live (draf — staff lengkapkan link & aktifkan)
insert into psy_auto_messages
  (key, name, description, trigger_type, minutes_before, session_time, days_of_week, audience, package_ids, channels, link, message_template, placeholders, is_active)
values
  ('manzil_live',
   'Live Bacaan Manzil & Perubatan Alami',
   'Broadcast jemputan sesi Manzil live kepada pesakit, sebelum sesi bermula pada hari terpilih.',
   'recurring_broadcast', 30, '08:45', '[3,4,5]'::jsonb, '["patient"]'::jsonb, '[]'::jsonb,
   '["whatsapp","inapp","announcement"]'::jsonb, 'https://meet.google.com/xxx-xxxx-xxx',
   E'Salam {nama} 👋\n\n📿 *Sesi Rohani Eksklusif: Alunan Manzil*\nBersama Sheikh Fares Mohammed\n\nSesi akan bermula {lead} lagi (pukul {masa}). Jom sertai untuk ketenangan & perlindungan hari anda.\n\n📹 Sertai: {pautan}\n\n— Ibnu Sina Wellness',
   '["{nama}","{masa}","{lead}","{pautan}"]'::jsonb,
   false)
on conflict (key) do nothing;

-- Alert Coach — Kepatuhan Pesakit (gabungan multi-check, runner runKepatuhanAlerts)
insert into psy_auto_messages
  (key, name, description, trigger_type, send_at_time, days_of_week, audience, channels, rule, message_template, placeholders, is_active)
values
  ('kepatuhan_alert',
   'Alert Coach — Kepatuhan Pesakit',
   'Setiap malam, semak kepatuhan setiap pesakit aktif (amalan Catatan Harian tak dibuat/bawah sasaran, hari tak isi, skor rendah, tiada bacaan kesihatan). Gabung jadi SATU alert kepada COACH yang di-assign (papan pemuka + loceng + email) supaya boleh hubungi pesakit esok pagi. Dedup 1×/minggu/pesakit.',
   'daily_reminder',                 -- supaya UI papar pemilih masa harian
   '21:00',                          -- nilai hujung hari
   '[0,1,2,3,4,5,6]'::jsonb,          -- setiap hari (0=Ahad .. 6=Sabtu)
   '["coach"]'::jsonb,               -- sasaran = coach (bukan pesakit)
   '["inapp"]'::jsonb,               -- loceng dalam app sahaja (tambah "email" utk hidupkan via GHL)
   '{"severity":"high","window_days":7,"email_from":"support@ibnusinawellness.com","checks":{"amalan":{"on":true,"min_days_short":3},"checklist":{"on":true,"min_days_missing":3},"skor":{"on":true,"min_score":80},"vitals":{"on":true,"min_days_since":7}}}'::jsonb,
   E'Assalamualaikum Coach 👋\n\nPesakit {nama} memerlukan perhatian anda.\n\nBerikut perkara yang perlu diberi perhatian (7 hari lepas):\n{senarai}\n\nTindakan Disyorkan:\n📞 Hubungi pesakit untuk membuat semakan keadaan semasa dan memberikan sokongan agar rawatan dapat diteruskan dengan lebih konsisten.\n\nTerima kasih atas perhatian dan bimbingan anda.\n\n— Sistem Auto-Kepatuhan ISW',
   '["{nama}","{senarai}"]'::jsonb,
   false)
on conflict (key) do update set
   name = excluded.name, description = excluded.description, audience = excluded.audience,
   channels = excluded.channels, rule = excluded.rule, message_template = excluded.message_template,
   placeholders = excluded.placeholders;

-- Templat "Saranan Rujukan" (boleh-edit oleh staff; placeholder diganti oleh kod)
INSERT INTO psy_auto_messages (key, name, description, channel, trigger_type, channels, audience, message_template, placeholders, is_active)
VALUES (
  'referral_saranan',
  'Saranan Rujukan (WhatsApp)',
  'Mesej yang dihantar ke pesakit selepas konsultasi rujukan (butang "Hantar ke WhatsApp"). Boleh edit ayat & susun placeholder.',
  'whatsapp',
  'on_action',
  '["whatsapp"]'::jsonb,
  '["patient"]'::jsonb,
  E'Salam {nama}, \U0001F44B\nBerikut saranan daripada {pengesyor} (Ibnu Sina Wellness):\n\n{saranan}\n\n⏱️ Sila ikut selama *{tempoh} hari* bermula {tarikh}.\n\nTerima kasih & semoga cepat sihat. \U0001F33F',
  '["{nama}","{pengesyor}","{saranan}","{tempoh}","{tarikh}"]'::jsonb,
  true
)
ON CONFLICT (key) DO NOTHING;

-- Pengesahan Sesi Rawatan (session_confirm) — UPSERT dgn DO UPDATE supaya
-- run semula mengemaskini template/config; is_active TIDAK disentuh.
--   rule.lead_days      : berapa hari sebelum sesi peringatan dihantar (default 3)
--   rule.deadline_hours : had sahkan/tukar tarikh sebelum sesi (default 24)
--   rule.escalate       : alert coach bila lepas had & belum ditandakan sahkan
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

-- Template Reaksi Pemulihan (pesakit boleh baca — policy 'reaksi_%')
-- reaksi_harian: mesej 1 (terus) — {{sections}} = blok per kategori,
-- tindakan sama disebut SEKALI sahaja (dedup global oleh klien).
INSERT INTO psy_auto_messages (key, name, description, trigger_type, message_template, placeholders, is_active) VALUES
  ('reaksi_harian',
   'Cadangan Reaksi Harian',
   'Mesej 1 (terus) selepas Poll Harian — reaksi & Cadangan Pemulihan dikumpulkan ikut kategori; tindakan sama disebut sekali sahaja.',
   'on_action',
   E'Assalamualaikum {{patient_name}},\n\nTerima kasih kerana melengkapkan Poll Harian hari ini.\n\nBerdasarkan jawapan anda, kami mengesan beberapa reaksi pemulihan.\n\n{{sections}}\n\nJika simptom menjadi semakin teruk atau berpanjangan, sila hubungi coach anda.\n\nSemoga Allah mempermudahkan urusan pemulihan anda.\n\nSalam kasih,\nPasukan Ibnu Sina Wellness 💚',
   '["{{patient_name}}","{{sections}}"]'::jsonb,
   true),
  ('reaksi_kritikal',
   'Cadangan Reaksi Kritikal',
   'Draf mesej untuk reaksi berisiko tinggi / kecemasan — TIDAK auto-hantar, staff semak & hantar dari halaman Semak & Hantar Mesej.',
   'on_action',
   E'Assalamualaikum {{patient_name}},\n\n🚨 PENTING: Berdasarkan Poll Harian anda, terdapat simptom yang memerlukan perhatian segera.\n\nReaksi yang dikesan:\n{{symptom_list}}\n\nTindakan disyorkan:\n{{action_list}}\n\nSila hubungi coach anda DENGAN SEGERA atau dapatkan rawatan di hospital berdekatan jika keadaan serius.\n\nPasukan Ibnu Sina Wellness',
   '["{{patient_name}}","{{symptom_list}}","{{action_list}}"]'::jsonb,
   true),
  ('reaksi_gaya_hidup',
   'Saranan Gaya Hidup Fitrah',
   'Mesej ke-2 selepas Poll Harian (+5 minit) — saranan gaya hidup fitrah berdasarkan reaksi dikesan (tindakan jenis "gaya_hidup").',
   'on_action',
   E'Assalamualaikum {{patient_name}},\n\n🌿 *Saranan Gaya Hidup Fitrah* untuk hari ini:\n\n{{lifestyle_list}}\n\nSedikit demi sedikit, secara istiqamah — insyaAllah membantu pemulihan anda.\n\nSalam kasih,\nPasukan Ibnu Sina Wellness 💚',
   '["{{patient_name}}","{{lifestyle_list}}"]'::jsonb,
   true),
  ('reaksi_diet',
   'Saranan Diet & Nutrisi',
   'Mesej ke-3 selepas Poll Harian (+10 minit) — saranan pemakanan berdasarkan reaksi dikesan (tindakan jenis "pemakanan").',
   'on_action',
   E'Assalamualaikum {{patient_name}},\n\n🍽️ *Saranan Diet & Nutrisi* untuk membantu pemulihan anda hari ini:\n\n{{diet_list}}\n\nAmalkan mengikut kemampuan dan secara konsisten, insyaAllah.\n\nSalam kasih,\nPasukan Ibnu Sina Wellness 💚',
   '["{{patient_name}}","{{diet_list}}"]'::jsonb,
   true)
ON CONFLICT (key) DO NOTHING;
