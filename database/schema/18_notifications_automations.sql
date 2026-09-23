-- ═══════════════════════════════════════════════════════════════════
-- 18 — NOTIFIKASI & AUTOMASI
-- Notifikasi dalam-app, mesej automatik (template WhatsApp), builder
-- automasi + log, audience tersimpan, alert kepatuhan & risiko, task coach.
-- Jadual: psy_notifications, psy_auto_messages, psy_automations,
--         psy_notification_logs, psy_audiences, psy_adherence_alerts,
--         psy_risk_alerts, psy_emergency_alerts, psy_coach_tasks
-- ═══════════════════════════════════════════════════════════════════

-- ──── psy_notifications — notifikasi loceng dalam-app ────
CREATE TABLE IF NOT EXISTS psy_notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES psy_profiles(id) ON DELETE CASCADE NOT NULL,
  type TEXT DEFAULT 'system'
    CHECK (type IN ('appointment','order','plan','system','reaksi','kyc','referral','event')),
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

-- ──── psy_emergency_alerts — Red Emergency Protocol (worklist zon merah/kuning) ────
-- Satu alert AKTIF (status <> 'resolved') per pesakit pada satu-satu masa
-- (dedup dlm trigger di bawah). Bukan gantian psy_risk_alerts (kekal, domain
-- lain) — khas utk worklist zon.
CREATE TABLE IF NOT EXISTS psy_emergency_alerts (
  id                       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id               UUID REFERENCES psy_patients(id) ON DELETE CASCADE NOT NULL,
  zon                      TEXT NOT NULL CHECK (zon IN ('kuning','merah')),
  symptoms                 JSONB DEFAULT '[]',   -- snapshot, sama bentuk dgn psy_reaksi_advice_log.symptoms
  -- source 'patient' ditambah 22 Jul 2026 via migration adaptif (20260722c) —
  -- pesakit lapor sendiri dari seksyen Protokol Kecemasan di roles/patient/dashboard.html
  -- (butang kecemasan; bukan lagi halaman berasingan — consolidated 22 Jul 2026).
  -- source 'vitals' ditambah 23 Sept 2026 — bacaan Vitals kritikal auto-cipta kes,
  -- lihat trg_vitals_notify_emergency di bawah.
  source                   TEXT DEFAULT 'auto' CHECK (source IN ('auto','manual','patient','vitals')),
  source_log_id            UUID REFERENCES psy_reaksi_advice_log(id) ON DELETE SET NULL,
  reported_at              TIMESTAMPTZ DEFAULT now(),
  response_target_minutes  INT NOT NULL,          -- 15 (merah) / 60 (kuning)
  assigned_to               UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,  -- default = coach_id pesakit
  status                    TEXT DEFAULT 'waiting_coach'
                             CHECK (status IN ('waiting_coach','contacted','waiting_vital','follow_up','resolved')),
  resolved_at                TIMESTAMPTZ,
  resolved_by                UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  notes                     TEXT,                 -- catatan terakhir (staff boleh kemaskini)
  created_by                 UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,  -- NULL = auto (trigger)
  created_at                TIMESTAMPTZ DEFAULT now(),
  updated_at                TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_emergency_alerts_status  ON psy_emergency_alerts(status, reported_at);
CREATE INDEX IF NOT EXISTS idx_emergency_alerts_patient ON psy_emergency_alerts(patient_id);

ALTER TABLE psy_emergency_alerts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff manage emergency alerts" ON psy_emergency_alerts;
CREATE POLICY "Staff manage emergency alerts" ON psy_emergency_alerts FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
  WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- Pesakit boleh BACA alert sendiri sahaja (papar status "Coach akan hubungi
-- anda" di seksyen Protokol Kecemasan, roles/patient/dashboard.html). INSERT/UPDATE
-- kekal staff-only — pesakit lapor sendiri via RPC SECURITY DEFINER fn_patient_report_emergency().
DROP POLICY IF EXISTS "Patient read own emergency alert" ON psy_emergency_alerts;
CREATE POLICY "Patient read own emergency alert" ON psy_emergency_alerts FOR SELECT
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

-- ──── Fungsi trigger: alert coach + worklist kecemasan bila advice log zon merah/kuning ────
-- Satu submission boleh insert hingga 3 baris mesej serentak; notifikasi
-- hanya utk BARIS PERTAMA (send_after ≈ created_at; baris 2/3 = +5/+10 min).
CREATE OR REPLACE FUNCTION trg_reaksi_advice_notify_emergency()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_coach_id     UUID;
  v_patient_name TEXT;
  v_first_row    BOOLEAN;
  v_zon          TEXT;
  v_target_min   INT;
  v_open_id      UUID;
  v_open_zon     TEXT;
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

  v_zon := CASE WHEN NEW.is_emergency THEN 'merah' ELSE NEW.zon END;
  v_target_min := CASE WHEN v_zon = 'merah' THEN 15 ELSE 60 END;

  IF v_zon = 'merah' THEN
    INSERT INTO psy_notifications (user_id, type, title, body, link)
    VALUES (
      v_coach_id, 'reaksi',
      '🔴 ZON MERAH: ' || v_patient_name,
      v_patient_name || ' melaporkan simptom tahap tinggi/kecemasan dalam Poll Harian. Pesakit dinasihatkan ke hospital & telah dihantar mesej kritikal — sila susul SEGERA.',
      'emergency.html?patient_id=' || NEW.patient_id::TEXT
    );
  ELSE
    INSERT INTO psy_notifications (user_id, type, title, body, link)
    VALUES (
      v_coach_id, 'reaksi',
      '🟡 Zon Kuning: ' || v_patient_name,
      v_patient_name || ' melaporkan simptom tahap sederhana dalam Poll Harian — perlukan perhatian coach. Sila semak dan susul pesakit.',
      'emergency.html?patient_id=' || NEW.patient_id::TEXT
    );
  END IF;

  -- Worklist: satu alert AKTIF per pesakit — kemaskini kalau dah ada, jangan gandakan.
  -- Taraf naik kuning→merah dibenarkan; JANGAN turun taraf merah→kuning.
  SELECT id, zon INTO v_open_id, v_open_zon
  FROM psy_emergency_alerts WHERE patient_id = NEW.patient_id AND status <> 'resolved'
  ORDER BY created_at DESC LIMIT 1;

  IF v_open_id IS NOT NULL THEN
    IF NOT (v_open_zon = 'merah' AND v_zon = 'kuning') THEN
      UPDATE psy_emergency_alerts
      SET zon = v_zon, symptoms = COALESCE(NEW.symptoms, symptoms),
          reported_at = now(), response_target_minutes = v_target_min, updated_at = now()
      WHERE id = v_open_id;
    END IF;
  ELSE
    INSERT INTO psy_emergency_alerts
      (patient_id, zon, symptoms, source, source_log_id, response_target_minutes, assigned_to)
    VALUES
      (NEW.patient_id, v_zon, COALESCE(NEW.symptoms, '[]'::jsonb), 'auto', NEW.id, v_target_min, v_coach_id);
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

-- ──── Fungsi trigger: bacaan Vitals KRITIKAL → auto-cipta/kemaskini kes Red Emergency ────
-- Sama pola dgn trg_reaksi_advice_notify_emergency di atas (satu alert AKTIF per
-- pesakit, taraf naik ke merah dibenarkan, taraf turun DISEKAT). is_critical
-- dikira server-side di fn_vitals_compute_critical() (10_vitals.sql) — trigger ni
-- cuma respons bila NEW.is_critical = true, tak kira laluan insert (patient-hub/
-- plan-week/vitals-detail) atau staf sedar/tidak.
CREATE OR REPLACE FUNCTION trg_vitals_notify_emergency()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_coach_id     UUID;
  v_patient_name TEXT;
  v_open_id      UUID;
  v_reason       TEXT;
BEGIN
  IF NOT NEW.is_critical THEN RETURN NEW; END IF;

  SELECT pt.coach_id, COALESCE(pr.full_name, pt.full_name, 'Pesakit')
    INTO v_coach_id, v_patient_name
  FROM psy_patients pt
  LEFT JOIN psy_profiles pr ON pr.id = pt.user_id
  WHERE pt.id = NEW.patient_id;
  IF v_coach_id IS NULL THEN RETURN NEW; END IF;

  v_reason := 'Bacaan Vitals kritikal: ' || COALESCE(NULLIF(concat_ws(', ',
    CASE WHEN NEW.bp_systolic IS NOT NULL AND (NEW.bp_systolic < 80 OR NEW.bp_systolic >= 180)
      THEN 'BP ' || NEW.bp_systolic || '/' || COALESCE(NEW.bp_diastolic::TEXT, '—') END,
    CASE WHEN NEW.bp_diastolic IS NOT NULL AND NEW.bp_diastolic >= 120
      THEN 'BP diastolik ' || NEW.bp_diastolic END,
    CASE WHEN NEW.heart_rate IS NOT NULL AND (NEW.heart_rate < 40 OR NEW.heart_rate > 130)
      THEN 'Nadi ' || NEW.heart_rate || ' bpm' END,
    CASE WHEN NEW.temperature IS NOT NULL AND (NEW.temperature < 35.0 OR NEW.temperature >= 39.5)
      THEN 'Suhu ' || NEW.temperature || '°C' END,
    CASE WHEN NEW.spo2 IS NOT NULL AND NEW.spo2 < 90
      THEN 'SpO2 ' || NEW.spo2 || '%' END,
    CASE WHEN NEW.respiratory_rate IS NOT NULL AND (NEW.respiratory_rate < 8 OR NEW.respiratory_rate > 30)
      THEN 'RR ' || NEW.respiratory_rate || '/min' END
  ), ''), 'ambang kritikal');

  INSERT INTO psy_notifications (user_id, type, title, body, link)
  VALUES (
    v_coach_id, 'vitals',
    '🔴 BACAAN KRITIKAL: ' || v_patient_name,
    v_reason || ' — sila susul SEGERA.',
    'emergency.html?patient_id=' || NEW.patient_id::TEXT
  );

  -- Worklist: satu alert AKTIF per pesakit — kemaskini kalau dah ada (taraf terus
  -- ke merah, tak pernah turun), cipta baharu kalau tiada.
  SELECT id INTO v_open_id FROM psy_emergency_alerts
  WHERE patient_id = NEW.patient_id AND status <> 'resolved'
  ORDER BY created_at DESC LIMIT 1;

  IF v_open_id IS NOT NULL THEN
    UPDATE psy_emergency_alerts
    SET zon = 'merah', reported_at = now(), response_target_minutes = 15, updated_at = now(),
        notes = CASE WHEN notes IS NULL OR notes = '' THEN v_reason ELSE notes || E'\n' || v_reason END
    WHERE id = v_open_id;
  ELSE
    INSERT INTO psy_emergency_alerts
      (patient_id, zon, source, response_target_minutes, assigned_to, notes)
    VALUES
      (NEW.patient_id, 'merah', 'vitals', 15, v_coach_id, v_reason);
  END IF;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE LOG 'trg_vitals_notify_emergency: %', SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_vitals_notify_emergency ON psy_vitals;
CREATE TRIGGER trg_vitals_notify_emergency
  AFTER INSERT ON psy_vitals
  FOR EACH ROW EXECUTE FUNCTION trg_vitals_notify_emergency();

-- ──── Fungsi trigger: saranan Reaksi tergantung 'needs_review' → notify coach ────
-- Audit management #B2-2 (23 Sept 2026). Bila roles/patient/kepatuhan.html kesan
-- >1 reaksi tercetus serentak dlm satu submission (conflict-check), baris
-- psy_reaksi_advice_log dicipta dgn status='needs_review' (bukan 'draft') supaya
-- cron reaksi-advice-send TAK auto-hantar. Patient client tak boleh INSERT terus
-- ke psy_notifications (RLS staff-only), jadi trigger ni yang notify coach.
-- Dedup: hanya baris PERTAMA (msg_jenis='tindakan', send_after≈created_at) bagi
-- satu submission yang cetus notifikasi — elak 3 notifikasi berulang.
CREATE OR REPLACE FUNCTION trg_reaksi_advice_notify_review()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_coach_id     UUID;
  v_patient_name TEXT;
BEGIN
  IF NEW.status <> 'needs_review' THEN RETURN NEW; END IF;
  IF NOT (NEW.send_after IS NULL OR NEW.send_after <= NEW.created_at + interval '2 minutes') THEN RETURN NEW; END IF;

  SELECT pt.coach_id, COALESCE(pr.full_name, pt.full_name, 'Pesakit')
    INTO v_coach_id, v_patient_name
  FROM psy_patients pt
  LEFT JOIN psy_profiles pr ON pr.id = pt.user_id
  WHERE pt.id = NEW.patient_id;
  IF v_coach_id IS NULL THEN RETURN NEW; END IF;

  INSERT INTO psy_notifications (user_id, type, title, body, link)
  VALUES (
    v_coach_id, 'reaksi',
    '⚠️ Cadangan Perlu Disemak: ' || v_patient_name,
    v_patient_name || ' alami beberapa reaksi serentak — cadangan digenerate TAPI belum dihantar sehingga disemak. Sila semak di reaksi-laporan.html.',
    'reaksi-laporan.html'
  );

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE LOG 'trg_reaksi_advice_notify_review: %', SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_reaksi_advice_notify_review ON psy_reaksi_advice_log;
CREATE TRIGGER trg_reaksi_advice_notify_review
  AFTER INSERT ON psy_reaksi_advice_log
  FOR EACH ROW EXECUTE FUNCTION trg_reaksi_advice_notify_review();

-- ──── Fungsi RPC: pesakit tekan butang kecemasan (seksyen Protokol Kecemasan, roles/patient/dashboard.html) ────
-- Satu alert AKTIF per pesakit — dedup sama logic dgn trigger di atas. Taraf
-- sentiasa naik ke 'merah' (pesakit tekan butang kecemasan = tahap tertinggi),
-- tak pernah turun taraf. SECURITY DEFINER supaya pesakit tak perlu grant
-- INSERT/UPDATE terus ke psy_emergency_alerts (RLS kekal staff-only).
CREATE OR REPLACE FUNCTION fn_patient_report_emergency(p_channel TEXT DEFAULT 'unknown')
RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_patient_id   UUID;
  v_coach_id     UUID;
  v_patient_name TEXT;
  v_open_id      UUID;
  v_alert_id     UUID;
  v_note         TEXT;
BEGIN
  SELECT id, coach_id INTO v_patient_id, v_coach_id FROM psy_patients WHERE user_id = auth.uid() LIMIT 1;
  IF v_patient_id IS NULL THEN
    RAISE EXCEPTION 'Rekod pesakit tidak dijumpai';
  END IF;

  SELECT COALESCE(pr.full_name, pt.full_name, 'Pesakit') INTO v_patient_name
  FROM psy_patients pt LEFT JOIN psy_profiles pr ON pr.id = pt.user_id
  WHERE pt.id = v_patient_id;

  v_note := 'Pesakit tekan butang kecemasan (' || COALESCE(p_channel, 'unknown') || ') pada '
            || to_char(now(), 'DD Mon YYYY HH24:MI');

  SELECT id INTO v_open_id FROM psy_emergency_alerts
  WHERE patient_id = v_patient_id AND status <> 'resolved'
  ORDER BY created_at DESC LIMIT 1;

  IF v_open_id IS NOT NULL THEN
    UPDATE psy_emergency_alerts
    SET zon = 'merah', reported_at = now(), response_target_minutes = 15, updated_at = now(),
        notes = CASE WHEN notes IS NULL OR notes = '' THEN v_note ELSE notes || E'\n' || v_note END
    WHERE id = v_open_id
    RETURNING id INTO v_alert_id;
  ELSE
    INSERT INTO psy_emergency_alerts (patient_id, zon, source, response_target_minutes, assigned_to, notes)
    VALUES (v_patient_id, 'merah', 'patient', 15, v_coach_id, v_note)
    RETURNING id INTO v_alert_id;
  END IF;

  IF v_coach_id IS NOT NULL THEN
    INSERT INTO psy_notifications (user_id, type, title, body, link)
    VALUES (
      v_coach_id, 'reaksi',
      '🚨 Pesakit Tekan Butang Kecemasan: ' || v_patient_name,
      v_patient_name || ' menekan butang kecemasan (' || COALESCE(p_channel, 'unknown') || ') di Protokol Kecemasan. Sila hubungi SEGERA.',
      'emergency.html?patient_id=' || v_patient_id::TEXT
    );
  END IF;

  RETURN v_alert_id;
END;
$$;

GRANT EXECUTE ON FUNCTION fn_patient_report_emergency(TEXT) TO authenticated;

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

-- Templat "Perjanjian KOB Ditandatangan" (butang manual "Hantar WhatsApp" di kob-detail.html,
-- lepas agreement disign; PDF sah dilampirkan sebagai attachment, bukan placeholder —
-- boleh edit ayat oleh staff; toggle off sembunyikan butang tu terus)
INSERT INTO psy_auto_messages (key, name, description, channel, trigger_type, channels, audience, message_template, placeholders, is_active)
VALUES (
  'kob_agreement_signed',
  'Perjanjian KOB Ditandatangan (WhatsApp)',
  'Mesej + PDF salinan perjanjian yang dihantar bila staff tekan butang "Hantar WhatsApp" (kad Sign Agreement, kob-detail.html) selepas agreement ditandatangan. Toggle off untuk sembunyikan butang tu.',
  'whatsapp',
  'on_action',
  '["whatsapp"]'::jsonb,
  '["patient"]'::jsonb,
  E'Assalamualaikum {nama}, berikut salinan Perjanjian Rawatan ISW yang telah anda tandatangani.',
  '["{nama}"]'::jsonb,
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

-- Peringatan Pengambilan Sampel DNA (dna_sample_reminder) — sehari sebelum tarikh
-- janji temu (psy_dna_test_process.sample_appointment_id), hantar WA + syarat
-- persediaan. Dedup via sample_reminder_sent_at. UPSERT dgn DO UPDATE macam session_confirm.
--   rule.lead_days : berapa hari sebelum tarikh peringatan dihantar (default 1)
insert into psy_auto_messages
  (key, name, description, channel, trigger_type, message_template,
   placeholders, channels, rule, category, language, is_active)
values
  ('dna_sample_reminder',
   'Peringatan Pengambilan Sampel DNA',
   'Sehari sebelum tarikh janji temu pengambilan sampel DNA Test, hantar WA kpd pesakit — nyatakan tarikh/masa & syarat persediaan (makan 2 jam sebelum, jangan makan/minum 30 minit sebelum).',
   'whatsapp', 'before_event',
   E'Salam {nama} 👋\n\nPeringatan: esok anda dijadualkan untuk *Pengambilan Sampel DNA Test* di klinik.\n\n📅 {tarikh_sample} · {masa_sample}\n\n⚠️ Sila patuhi sebelum ujian:\n• Pastikan anda telah makan sekurang-kurangnya 2 jam sebelum ujian.\n• Jangan makan atau minum sekurang-kurangnya 30 minit sebelum ujian.\n\nJumpa esok!\n\n— {nama_klinik}',
   '["{nama}","{tarikh_sample}","{masa_sample}","{nama_klinik}"]'::jsonb,
   '["whatsapp"]'::jsonb,
   '{"lead_days":1}'::jsonb,
   'dna_test', 'ms',
   false)
on conflict (key) do update set
  name             = excluded.name,
  description      = excluded.description,
  channel          = excluded.channel,
  trigger_type     = excluded.trigger_type,
  message_template = excluded.message_template,
  placeholders     = excluded.placeholders,
  channels         = excluded.channels,
  rule             = excluded.rule,
  category         = excluded.category,
  language         = excluded.language,
  updated_at       = now();

-- Ansuran pakej tertunggak (installment_overdue) — bila jumlah TERKUMPUL
-- pesakit (psy_payments) tak cecah target checkpoint (psy_kob_installment_
-- checkpoints) menjelang due_date, tandakan overdue + sekat tempahan sesi
-- baru pesakit, hantar WA sekali. Dijalankan setiap kali event-reminders cron cetus.
insert into psy_auto_messages
  (key, name, description, channel, trigger_type, message_template,
   placeholders, channels, category, language, is_active)
values
  ('installment_overdue',
   'Ansuran Pakej Tertunggak',
   'Bila jumlah terkumpul pesakit tak cecah target checkpoint ansuran menjelang tarikh due, hantar WA + sekat tempahan sesi baru sehingga bayaran diselesaikan.',
   'whatsapp', 'installment_overdue',
   E'Salam {nama} 👋\n\nAnsuran pakej rawatan anda (checkpoint Bulan {bulan}) tertunggak sejak {tarikh_due}. Jumlah wajib terkumpul: RM {jumlah} — baki RM {baki} lagi.\n\nTempahan sesi baru disekat buat sementara waktu sehingga bayaran diselesaikan. Sila hubungi pusat rawatan untuk bantuan.\n\n— {nama_klinik}',
   '["{nama}","{bulan}","{jumlah}","{baki}","{tarikh_due}","{nama_klinik}"]'::jsonb,
   '["whatsapp"]'::jsonb,
   'pembayaran', 'ms',
   false)
on conflict (key) do update set
  name             = excluded.name,
  description      = excluded.description,
  channel          = excluded.channel,
  trigger_type     = excluded.trigger_type,
  message_template = excluded.message_template,
  placeholders     = excluded.placeholders,
  channels         = excluded.channels,
  category         = excluded.category,
  language         = excluded.language,
  updated_at       = now();

-- Peringatan Ansuran Akan Tamat Tempoh (installment_reminder) — N hari sebelum
-- checkpoint psy_kob_installment_checkpoints jatuh tempoh (status masih 'pending'),
-- hantar WA + pautan bayaran HitPay dijana on-the-fly (runInstallmentReminderCheck,
-- event-reminders → _shared/kob_topup.ts). Dedup via installment_reminder_sent_at.
-- Beza dgn installment_overdue (lepas due date, sekat tempahan) — ni SEBELUM due date,
-- galakan bayar awal. UPSERT dgn DO UPDATE macam session_confirm/dna_sample_reminder.
--   rule.lead_days : berapa hari sebelum due_date peringatan dihantar (default 3)
insert into psy_auto_messages
  (key, name, description, channel, trigger_type, message_template,
   placeholders, channels, rule, category, language, is_active)
values
  ('installment_reminder',
   'Peringatan Ansuran Akan Tamat Tempoh',
   'Sebelum checkpoint ansuran KOB jatuh tempoh (rule.lead_days hari, default 3), hantar WA kpd pesakit dengan pautan bayaran HitPay — dijana automatik.',
   'whatsapp', 'installment_reminder',
   E'Salam {nama} 👋\n\nPeringatan mesra: ansuran *{ansuran}* pakej rawatan anda (RM {jumlah}) akan tamat tempoh pada *{tarikh_due}*.\n\nSila selesaikan bayaran melalui pautan selamat:\n{pautan}\n\nTerima kasih — ISW',
   '["{nama}","{ansuran}","{jumlah}","{tarikh_due}","{pautan}"]'::jsonb,
   '["whatsapp"]'::jsonb,
   '{"lead_days":3}'::jsonb,
   'pembayaran', 'ms',
   false)
on conflict (key) do update set
  name             = excluded.name,
  description      = excluded.description,
  channel          = excluded.channel,
  trigger_type     = excluded.trigger_type,
  message_template = excluded.message_template,
  placeholders     = excluded.placeholders,
  channels         = excluded.channels,
  rule             = excluded.rule,
  category         = excluded.category,
  language         = excluded.language,
  updated_at       = now();

-- Jemputan Lampir Kad (card_attach_invite) — staff hantar pautan HitPay
-- "lampir kad" (createKobCardAttachLink) supaya ansuran seterusnya boleh
-- di-auto-caj tanpa pesakit klik pautan tiap bulan. Dihantar MANUAL oleh
-- staff (butang kob-detail.html), bukan cron — is_active kawal sama ada
-- placeholder ni dipakai/skip terus ke teks manual.
insert into psy_auto_messages
  (key, name, description, channel, trigger_type, message_template,
   placeholders, channels, category, language, is_active)
values
  ('card_attach_invite',
   'Jemputan Lampir Kad — Ansuran Automatik',
   'Pautan HitPay "lampir kad" (RM1 pengesahan) supaya ansuran seterusnya dicaj automatik pada tarikh due, pesakit tak perlu klik pautan tiap bulan.',
   'whatsapp', 'card_attach_invite',
   E'Salam {nama} 👋\n\nUntuk memudahkan bayaran ansuran pakej rawatan anda, sila lampirkan kad debit/kredit anda (pengesahan RM1) melalui pautan selamat di bawah. Ansuran seterusnya akan ditolak SECARA AUTOMATIK pada tarikh due — anda tak perlu klik pautan bayaran setiap bulan lagi.\n\n{pautan}\n\n— {nama_klinik}',
   '["{nama}","{pautan}","{nama_klinik}"]'::jsonb,
   '["whatsapp"]'::jsonb,
   'pembayaran', 'ms',
   false)
on conflict (key) do update set
  name             = excluded.name,
  description      = excluded.description,
  channel          = excluded.channel,
  trigger_type     = excluded.trigger_type,
  message_template = excluded.message_template,
  placeholders     = excluded.placeholders,
  channels         = excluded.channels,
  category         = excluded.category,
  language         = excluded.language,
  updated_at       = now();

-- Auto-Caj Berjaya (installment_autocharge_success) — kad tersimpan berjaya
-- dicaj on due_date (runInstallmentAutoChargeCheck, event-reminders →
-- _shared/kob_autocharge.ts). Beza dgn resit HitPay biasa (payments-webhook
-- sendPaymentReceiptWhatsApp) — mesej RINGKAS khusus konteks auto-caj.
insert into psy_auto_messages
  (key, name, description, channel, trigger_type, message_template,
   placeholders, channels, category, language, is_active)
values
  ('installment_autocharge_success',
   'Ansuran Auto-Caj Berjaya',
   'Kad tersimpan pesakit berjaya dicaj automatik pada tarikh due checkpoint ansuran — hantar WA makluman ringkas.',
   'whatsapp', 'installment_autocharge_success',
   E'Salam {nama} 👋\n\nAnsuran *{ansuran}* pakej rawatan anda (RM {jumlah}) telah berjaya ditolak secara automatik daripada kad tersimpan anda pada hari ini.\n\nTerima kasih — {nama_klinik}',
   '["{nama}","{ansuran}","{jumlah}","{nama_klinik}"]'::jsonb,
   '["whatsapp"]'::jsonb,
   'pembayaran', 'ms',
   false)
on conflict (key) do update set
  name             = excluded.name,
  description      = excluded.description,
  channel          = excluded.channel,
  trigger_type     = excluded.trigger_type,
  message_template = excluded.message_template,
  placeholders     = excluded.placeholders,
  channels         = excluded.channels,
  category         = excluded.category,
  language         = excluded.language,
  updated_at       = now();

-- Auto-Caj Gagal (installment_autocharge_failed) — kad tersimpan DITOLAK
-- (kad tamat tempoh/tiada baki dll) semasa cuba caj automatik pada due_date.
-- Fallback ke pautan bayaran manual (createKobInstallmentTopupLink) — sama
-- pautan dgn installment_reminder, cuma konteks mesej berbeza (bukan sekadar
-- peringatan awal, tapi makluman kegagalan caj).
insert into psy_auto_messages
  (key, name, description, channel, trigger_type, message_template,
   placeholders, channels, category, language, is_active)
values
  ('installment_autocharge_failed',
   'Ansuran Auto-Caj Gagal',
   'Kad tersimpan pesakit gagal dicaj (ditolak/tamat tempoh dll) semasa cuba caj automatik pada tarikh due — hantar WA + pautan bayaran manual fallback.',
   'whatsapp', 'installment_autocharge_failed',
   E'Salam {nama} 👋\n\nAnsuran *{ansuran}* pakej rawatan anda (RM {jumlah}) GAGAL ditolak secara automatik daripada kad tersimpan anda (kad mungkin ditolak/tamat tempoh).\n\nSila selesaikan bayaran melalui pautan selamat di bawah, atau hubungi klinik untuk kemas kini kad:\n{pautan}\n\n— {nama_klinik}',
   '["{nama}","{ansuran}","{jumlah}","{pautan}","{nama_klinik}"]'::jsonb,
   '["whatsapp"]'::jsonb,
   'pembayaran', 'ms',
   false)
on conflict (key) do update set
  name             = excluded.name,
  description      = excluded.description,
  channel          = excluded.channel,
  trigger_type     = excluded.trigger_type,
  message_template = excluded.message_template,
  placeholders     = excluded.placeholders,
  channels         = excluded.channels,
  category         = excluded.category,
  language         = excluded.language,
  updated_at       = now();

-- Bayaran Gagal/Dibatalkan (payment_failed) — WA dihantar automatik oleh
-- payments-webhook bila HitPay report status 'failed' (kali pertama sahaja,
-- lihat notifyPaymentFailed). {pautan} diisi kod: sentence lengkap dgn
-- pautan HitPay BAHARU (auto-jana, kob_deposit sahaja) ATAU sentence fallback
-- "cuba semula/hubungi klinik" kalau tiada pautan (package/self-checkout,
-- atau sesi KOB dah tak eligible). UPSERT dgn DO UPDATE macam installment_*.
insert into psy_auto_messages
  (key, name, description, channel, trigger_type, message_template,
   placeholders, channels, category, language, is_active)
values
  ('payment_failed',
   'Bayaran Gagal / Dibatalkan',
   'Dihantar automatik bila bayaran (HitPay) gagal/dibatalkan (kali pertama sahaja per resit). {pautan} = ayat lengkap dgn pautan bayar-semula (auto-jana, kob_deposit sahaja) atau ayat "cuba semula/hubungi klinik" jika tiada pautan.',
   'whatsapp', 'on_action',
   E'Assalamualaikum {nama} 👋\n\nBayaran anda ({item}, RM {jumlah}) tidak berjaya/dibatalkan. {pautan}\n\n— Ibnu Sina Wellness',
   '["{nama}","{item}","{jumlah}","{pautan}"]'::jsonb,
   '["whatsapp"]'::jsonb,
   'pembayaran', 'ms',
   true)
on conflict (key) do update set
  name             = excluded.name,
  description      = excluded.description,
  channel          = excluded.channel,
  trigger_type     = excluded.trigger_type,
  message_template = excluded.message_template,
  placeholders     = excluded.placeholders,
  channels         = excluded.channels,
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
