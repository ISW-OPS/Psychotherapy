-- ═══════════════════════════════════════════════════════════════════
-- MIGRASI: Modul Peristiwa Pesakit (Patient Events)
-- Run SEKALI di Supabase SQL Editor (testing & prod).
-- Kandungan:
--   A) psy_notifications.type — tambah 'event' (corak penyesuai-diri:
--      union nilai sedia ada + baru, elak gagal atas baris type lama)
--   B) RBAC — daftar modul patient_events + grant semua role staff
--   C) Bucket storage 'event-docs' + polisi staff
--   D) Jadual + trigger modul (salinan database/schema/25_patient_events.sql)
-- ═══════════════════════════════════════════════════════════════════

-- ──── A) psy_notifications.type + 'event' ────
DO $$
DECLARE v_types TEXT;
BEGIN
  SELECT string_agg(DISTINCT quote_literal(t), ',') INTO v_types
  FROM (
    SELECT type AS t FROM psy_notifications WHERE type IS NOT NULL
    UNION
    SELECT unnest(ARRAY['appointment','order','plan','system','reaksi','kyc','referral','event'])
  ) s;
  EXECUTE 'ALTER TABLE psy_notifications DROP CONSTRAINT IF EXISTS psy_notifications_type_check';
  EXECUTE format('ALTER TABLE psy_notifications ADD CONSTRAINT psy_notifications_type_check CHECK (type IN (%s))', v_types);
END $$;

-- ──── B) RBAC — modul patient_events ────
INSERT INTO psy_modules (code, label, icon, scope, sort_order) VALUES
  ('patient_events', 'Peristiwa Pesakit', '🏥', 'staff', 82)
ON CONFLICT (code) DO UPDATE SET
  label = EXCLUDED.label, icon = EXCLUDED.icon,
  scope = EXCLUDED.scope, sort_order = EXCLUDED.sort_order;

-- Semua action boleh ditick (tiada cell "—")
INSERT INTO psy_module_actions (module_code, action_code)
SELECT 'patient_events', code FROM psy_actions
ON CONFLICT DO NOTHING;

-- Grant kepada semua role staff sistem: view/create/edit/delete/export
INSERT INTO psy_role_module_actions (role_code, module_code, action_code)
SELECT r, 'patient_events', a
FROM unnest(ARRAY['super_admin','manager','admin','doctor','coach']) r
CROSS JOIN unnest(ARRAY['view','create','edit','delete','export']) a
ON CONFLICT DO NOTHING;

-- Tetapan: super_admin + manager sahaja
INSERT INTO psy_role_module_actions (role_code, module_code, action_code) VALUES
  ('super_admin', 'patient_events', 'settings'),
  ('manager',     'patient_events', 'settings')
ON CONFLICT DO NOTHING;

-- ──── C) Bucket storage 'event-docs' ────
INSERT INTO storage.buckets (id, name, public) VALUES ('event-docs', 'event-docs', false)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "event_docs_staff_all" ON storage.objects;
CREATE POLICY "event_docs_staff_all" ON storage.objects
    FOR ALL TO authenticated
    USING (bucket_id = 'event-docs' AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
    WITH CHECK (bucket_id = 'event-docs' AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- ──── D0) Pastikan helper RLS wujud (DB lama mungkin belum ada) ────
CREATE OR REPLACE FUNCTION public.isw_is_staff()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.psy_profiles
    WHERE id = auth.uid() AND role = 'staff'
  );
$$;

GRANT EXECUTE ON FUNCTION public.isw_is_staff() TO authenticated;

-- ──── D) Jadual + trigger (salinan schema/25_patient_events.sql) ────
-- ═══════════════════════════════════════════════════════════════════
-- 25 — PERISTIWA PESAKIT (Patient Events)
-- Rekod kejadian kritikal pesakit: masuk wad, ICU, temujanji doktor,
-- pembedahan, kecemasan, kematian, discaj, rehat rumah — dengan
-- notifikasi automatik kepada staff + penjejakan lawatan (visit).
-- Jadual: psy_patient_events, psy_patient_event_visits,
--         psy_patient_event_logs, psy_patient_event_docs
-- Trigger: notifikasi staff (loceng), auto-lockdown kematian
--          (status pesakit → deceased, automasi terhenti), log timeline.
-- Nota: bucket storage 'event-docs' didaftar dalam 24_storage.sql.
-- ═══════════════════════════════════════════════════════════════════

-- ──── psy_patient_events — jadual induk peristiwa ────
-- event_type (tiada CHECK — fleksibel utk jenis baru):
--   warded | icu | temujanji_doktor | pembedahan | kecemasan |
--   kematian | discaj | rehat_rumah
CREATE TABLE IF NOT EXISTS psy_patient_events (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id            UUID NOT NULL REFERENCES psy_patients(id) ON DELETE CASCADE,
  event_type            TEXT NOT NULL,
  priority              TEXT DEFAULT 'medium' CHECK (priority IN ('critical','high','medium','low')),
  status                TEXT DEFAULT 'open'   CHECK (status IN ('open','closed')),
  event_date            DATE NOT NULL,
  event_time            TIME,
  expected_discharge    DATE,
  hospital_name         TEXT,
  ward_room             TEXT,
  bed_unit              TEXT,
  doctor_in_charge      TEXT,
  diagnosis             TEXT,
  reference_no          TEXT,
  emergency_contact_name         TEXT,
  emergency_contact_phone        TEXT,
  emergency_contact_relationship TEXT,
  need_visit            BOOLEAN DEFAULT false,
  visit_priority        TEXT CHECK (visit_priority IS NULL OR visit_priority IN ('high','medium','low')),
  expected_visit_date   DATE,
  assigned_to           UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  notify_roles          JSONB DEFAULT '["manager","coach"]'::jsonb,
  notes                 TEXT,
  reported_by           UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  closed_by             UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  closed_at             TIMESTAMPTZ,
  created_at            TIMESTAMPTZ DEFAULT now(),
  updated_at            TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_pe_patient  ON psy_patient_events(patient_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_pe_status   ON psy_patient_events(status, event_date DESC);
CREATE INDEX IF NOT EXISTS idx_pe_type     ON psy_patient_events(event_type);
CREATE INDEX IF NOT EXISTS idx_pe_assigned ON psy_patient_events(assigned_to) WHERE assigned_to IS NOT NULL;

ALTER TABLE psy_patient_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "pe staff manage" ON psy_patient_events;
CREATE POLICY "pe staff manage" ON psy_patient_events FOR ALL
  USING (isw_is_staff()) WITH CHECK (isw_is_staff());

-- ──── psy_patient_event_visits — rekod lawatan / susulan ────
CREATE TABLE IF NOT EXISTS psy_patient_event_visits (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id          UUID NOT NULL REFERENCES psy_patient_events(id) ON DELETE CASCADE,
  patient_id        UUID REFERENCES psy_patients(id) ON DELETE CASCADE,
  visit_date        DATE NOT NULL,
  visit_time        TIME,
  visit_type        TEXT DEFAULT 'hospital' CHECK (visit_type IN ('hospital','rumah','klinik','panggilan')),
  visited_by        UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  status            TEXT DEFAULT 'pending' CHECK (status IN ('pending','in_progress','completed','cancelled')),
  patient_condition TEXT CHECK (patient_condition IS NULL OR patient_condition IN
                      ('sangat_lemah','lemah','stabil','beransur_baik','sangat_baik')),
  location          TEXT,
  ward_room         TEXT,
  person_met        TEXT,
  relationship      TEXT,
  notes             TEXT,
  vitals            JSONB DEFAULT '{}'::jsonb,   -- {bp, hr, temp, spo2, sugar}
  next_visit_date   DATE,
  next_visit_time   TIME,
  next_visit_type   TEXT,
  completed_at      TIMESTAMPTZ,
  created_by        UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  created_at        TIMESTAMPTZ DEFAULT now(),
  updated_at        TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_pev_event   ON psy_patient_event_visits(event_id, visit_date);
CREATE INDEX IF NOT EXISTS idx_pev_status  ON psy_patient_event_visits(status, visit_date);
CREATE INDEX IF NOT EXISTS idx_pev_visitor ON psy_patient_event_visits(visited_by) WHERE visited_by IS NOT NULL;

ALTER TABLE psy_patient_event_visits ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "pev staff manage" ON psy_patient_event_visits;
CREATE POLICY "pev staff manage" ON psy_patient_event_visits FOR ALL
  USING (isw_is_staff()) WITH CHECK (isw_is_staff());

-- ──── psy_patient_event_logs — timeline + nota peristiwa ────
-- action: created | updated | notified | assigned | visit_scheduled |
--         visit_completed | note | doc_uploaded | closed | reopened
CREATE TABLE IF NOT EXISTS psy_patient_event_logs (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id   UUID NOT NULL REFERENCES psy_patient_events(id) ON DELETE CASCADE,
  visit_id   UUID REFERENCES psy_patient_event_visits(id) ON DELETE SET NULL,
  actor_id   UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  actor_name TEXT,
  action     TEXT NOT NULL,
  detail     TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_pel_event ON psy_patient_event_logs(event_id, created_at);

ALTER TABLE psy_patient_event_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "pel staff manage" ON psy_patient_event_logs;
CREATE POLICY "pel staff manage" ON psy_patient_event_logs FOR ALL
  USING (isw_is_staff()) WITH CHECK (isw_is_staff());

-- ──── psy_patient_event_docs — lampiran dokumen / gambar ────
CREATE TABLE IF NOT EXISTS psy_patient_event_docs (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id         UUID NOT NULL REFERENCES psy_patient_events(id) ON DELETE CASCADE,
  visit_id         UUID REFERENCES psy_patient_event_visits(id) ON DELETE SET NULL,
  name             TEXT NOT NULL,
  path             TEXT NOT NULL,              -- path dalam bucket event-docs
  size_kb          INT,
  mime             TEXT,
  uploaded_by      UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  uploaded_by_name TEXT,
  created_at       TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ped_event ON psy_patient_event_docs(event_id);

ALTER TABLE psy_patient_event_docs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "ped staff manage" ON psy_patient_event_docs;
CREATE POLICY "ped staff manage" ON psy_patient_event_docs FOR ALL
  USING (isw_is_staff()) WITH CHECK (isw_is_staff());

-- ──── Fungsi trigger: updated_at ────
CREATE OR REPLACE FUNCTION pe_touch_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END; $$;

DROP TRIGGER IF EXISTS trg_pe_touch ON psy_patient_events;
CREATE TRIGGER trg_pe_touch BEFORE UPDATE ON psy_patient_events
  FOR EACH ROW EXECUTE FUNCTION pe_touch_updated_at();

DROP TRIGGER IF EXISTS trg_pev_touch ON psy_patient_event_visits;
CREATE TRIGGER trg_pev_touch BEFORE UPDATE ON psy_patient_event_visits
  FOR EACH ROW EXECUTE FUNCTION pe_touch_updated_at();

-- ──── Fungsi trigger: notifikasi loceng staff bila peristiwa baru ────
-- Penerima = coach pesakit (jika 'coach' dlm notify_roles) + semua staff
-- dgn staff_role dalam notify_roles + staff yang ditugaskan (assigned_to).
-- Dedup penerima; notifikasi type='event' → peristiwa-detail.html.
CREATE OR REPLACE FUNCTION trg_patient_event_notify()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_patient_name TEXT;
  v_coach        UUID;
  v_roles        JSONB;
  v_recipients   UUID[] := '{}';
  v_uid          UUID;
  v_title        TEXT;
  v_body         TEXT;
  v_type_lbl     TEXT;
BEGIN
  SELECT COALESCE(pr.full_name, pt.full_name, pt.mrn, 'Pesakit'), pt.coach_id
    INTO v_patient_name, v_coach
  FROM psy_patients pt
  LEFT JOIN psy_profiles pr ON pr.id = pt.user_id
  WHERE pt.id = NEW.patient_id;

  v_roles := COALESCE(NEW.notify_roles, '["manager","coach"]'::jsonb);

  IF v_roles ? 'coach' AND v_coach IS NOT NULL THEN
    v_recipients := array_append(v_recipients, v_coach);
  END IF;

  FOR v_uid IN
    SELECT id FROM psy_profiles
    WHERE role = 'staff'
      AND staff_role IN (SELECT jsonb_array_elements_text(v_roles))
      AND staff_role <> 'coach'
  LOOP
    v_recipients := array_append(v_recipients, v_uid);
  END LOOP;

  IF NEW.assigned_to IS NOT NULL THEN
    v_recipients := array_append(v_recipients, NEW.assigned_to);
  END IF;

  v_type_lbl := CASE NEW.event_type
    WHEN 'warded'           THEN 'Masuk Wad'
    WHEN 'icu'              THEN 'ICU'
    WHEN 'temujanji_doktor' THEN 'Temujanji Doktor'
    WHEN 'pembedahan'       THEN 'Pembedahan'
    WHEN 'kecemasan'        THEN 'Kecemasan'
    WHEN 'kematian'         THEN 'Meninggal Dunia'
    WHEN 'discaj'           THEN 'Discaj'
    WHEN 'rehat_rumah'      THEN 'Rehat di Rumah'
    ELSE NEW.event_type END;

  IF NEW.event_type = 'kematian' THEN
    v_title := '🕊️ Kematian: ' || v_patient_name;
    v_body  := 'Salam takziah. ' || v_patient_name || ' telah dilaporkan meninggal dunia'
               || COALESCE(' di ' || NEW.hospital_name, '') || ' pada '
               || to_char(NEW.event_date, 'DD/MM/YYYY')
               || '. Semua automasi & mesej kepada pesakit ini dihentikan secara automatik.';
  ELSIF NEW.priority = 'critical' THEN
    v_title := '🚨 KRITIKAL — ' || v_type_lbl || ': ' || v_patient_name;
    v_body  := v_patient_name || ' — ' || v_type_lbl
               || COALESCE(' di ' || NEW.hospital_name, '')
               || ' (' || to_char(NEW.event_date, 'DD/MM/YYYY') || ').'
               || CASE WHEN NEW.need_visit THEN ' Perlu lawatan — sila atur & maklum manager.' ELSE '' END;
  ELSE
    v_title := '🏥 ' || v_type_lbl || ': ' || v_patient_name;
    v_body  := v_patient_name || ' — ' || v_type_lbl
               || COALESCE(' di ' || NEW.hospital_name, '')
               || ' (' || to_char(NEW.event_date, 'DD/MM/YYYY') || ').'
               || CASE WHEN NEW.need_visit THEN ' Perlu lawatan.' ELSE '' END;
  END IF;

  FOR v_uid IN SELECT DISTINCT u FROM unnest(v_recipients) u LOOP
    INSERT INTO psy_notifications (user_id, type, title, body, link)
    VALUES (v_uid, 'event', v_title, v_body, 'peristiwa-detail.html?id=' || NEW.id);
  END LOOP;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE LOG 'trg_patient_event_notify: %', SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_patient_event_notify ON psy_patient_events;
CREATE TRIGGER trg_patient_event_notify
  AFTER INSERT ON psy_patient_events
  FOR EACH ROW EXECUTE FUNCTION trg_patient_event_notify();

-- ──── Fungsi trigger: auto-lockdown bila peristiwa KEMATIAN ────
-- status pesakit → 'deceased' + outcome 'meninggal'. Kesan: semua automasi/
-- mesej auto (WA, peringatan, birthday) skip pesakit ini kerana penapis
-- status='active'; tawaran sambungan pakej yang pending dibatalkan.
CREATE OR REPLACE FUNCTION trg_patient_event_kematian()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NEW.event_type <> 'kematian' THEN RETURN NEW; END IF;

  UPDATE psy_patients SET
    status            = 'deceased',
    outcome_status    = 'meninggal',
    outcome_status_at = now(),
    outcome_status_notes = COALESCE(outcome_status_notes,
      'Direkod melalui modul Peristiwa Pesakit (' || to_char(NEW.event_date,'DD/MM/YYYY') || ')')
  WHERE id = NEW.patient_id;

  -- Batal tawaran sambungan pakej yang belum diterima (jika modul wujud)
  BEGIN
    IF to_regclass('public.psy_continuity_offers') IS NOT NULL THEN
      EXECUTE 'UPDATE psy_continuity_offers SET status = ''cancelled''
               WHERE patient_id = $1 AND status = ''pending''' USING NEW.patient_id;
    END IF;
  EXCEPTION WHEN OTHERS THEN
    RAISE LOG 'trg_patient_event_kematian (continuity): %', SQLERRM;
  END;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE LOG 'trg_patient_event_kematian: %', SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_patient_event_kematian ON psy_patient_events;
CREATE TRIGGER trg_patient_event_kematian
  AFTER INSERT ON psy_patient_events
  FOR EACH ROW EXECUTE FUNCTION trg_patient_event_kematian();

-- ──── Fungsi trigger: log 'created' automatik ke timeline ────
CREATE OR REPLACE FUNCTION trg_patient_event_log_created()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_name TEXT;
BEGIN
  SELECT full_name INTO v_name FROM psy_profiles WHERE id = NEW.reported_by;
  INSERT INTO psy_patient_event_logs (event_id, actor_id, actor_name, action, detail)
  VALUES (NEW.id, NEW.reported_by, v_name, 'created',
          'Peristiwa direkodkan' || COALESCE(' oleh ' || v_name, ''));
  INSERT INTO psy_patient_event_logs (event_id, action, detail)
  VALUES (NEW.id, 'notified',
          'Notifikasi dihantar kepada: ' ||
          COALESCE((SELECT string_agg(x, ', ') FROM jsonb_array_elements_text(
            COALESCE(NEW.notify_roles,'["manager","coach"]'::jsonb)) x), '-'));
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE LOG 'trg_patient_event_log_created: %', SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_patient_event_log_created ON psy_patient_events;
CREATE TRIGGER trg_patient_event_log_created
  AFTER INSERT ON psy_patient_events
  FOR EACH ROW EXECUTE FUNCTION trg_patient_event_log_created();
