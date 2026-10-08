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
  -- Ditambah 23 Sept 2026 (audit management #B1-40) — pautan balik ke kes Red
  -- Emergency Protocol (psy_emergency_alerts) yang mencetuskan rekod klinikal ni,
  -- cth staf tandakan pesakit Masuk Wad terus dari emergency.html. Bila rekod ni
  -- ditutup (status → closed), trigger di bawah auto-kemaskini nota kes asal —
  -- lihat trg_patient_event_notify_emergency.
  source_emergency_alert_id UUID REFERENCES psy_emergency_alerts(id) ON DELETE SET NULL,
  created_at            TIMESTAMPTZ DEFAULT now(),
  updated_at            TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_pe_patient  ON psy_patient_events(patient_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_pe_status   ON psy_patient_events(status, event_date DESC);
CREATE INDEX IF NOT EXISTS idx_pe_type     ON psy_patient_events(event_type);
CREATE INDEX IF NOT EXISTS idx_pe_assigned ON psy_patient_events(assigned_to) WHERE assigned_to IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_pe_source_alert ON psy_patient_events(source_emergency_alert_id) WHERE source_emergency_alert_id IS NOT NULL;

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

-- ──── Fungsi trigger: rekod klinikal (dicipta drpd kes Emergency) ditutup → kemaskini kes asal ────
-- Audit management #B1-40 (23 Sept 2026). Bila peristiwa (warded/ICU/kecemasan dll)
-- yang dipautkan ke satu kes Red Emergency Protocol (source_emergency_alert_id)
-- ditutup, tambah nota di kes asal supaya staf yang urus emergency.html nampak
-- perkembangan — TAK auto-resolve kes (staf tetap perlu semak & tutup sendiri
-- di emergency.html, sebab kes emergency mungkin masih perlukan susulan lain).
CREATE OR REPLACE FUNCTION trg_patient_event_notify_emergency()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_note TEXT;
BEGIN
  IF NEW.source_emergency_alert_id IS NULL THEN RETURN NEW; END IF;
  IF NOT (NEW.status = 'closed' AND OLD.status <> 'closed') THEN RETURN NEW; END IF;

  v_note := 'Rekod Klinikal Pesakit (' || NEW.event_type || ') ditutup pada ' ||
            to_char(now(), 'DD Mon YYYY HH24:MI') ||
            COALESCE(' — ' || NEW.notes, '') ||
            '. Lihat peristiwa-detail.html?id=' || NEW.id::TEXT;

  UPDATE psy_emergency_alerts
  SET notes = CASE WHEN notes IS NULL OR notes = '' THEN v_note ELSE notes || E'\n' || v_note END,
      updated_at = now()
  WHERE id = NEW.source_emergency_alert_id;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE LOG 'trg_patient_event_notify_emergency: %', SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_patient_event_notify_emergency ON psy_patient_events;
CREATE TRIGGER trg_patient_event_notify_emergency
  AFTER UPDATE ON psy_patient_events
  FOR EACH ROW EXECUTE FUNCTION trg_patient_event_notify_emergency();

-- ──── Fungsi trigger: auto-cipta Rekod Klinikal Pesakit bila status → 'warded' ────
-- Audit management #124 (7 Okt 2026). Staf dulu kena tukar status pesakit KE
-- 'warded' (roles/staff/patient-hub.html — butang "🏥 Tandakan Warded") DAN klik
-- pautan berasingan ke peristiwa-baru.html utk cipta rekod. Trigger ni gantikan
-- langkah manual kedua tu: sebaik status psy_patients bertukar ke 'warded', satu
-- psy_patient_events (event_type='warded') auto dicipta + lawatan auto-assign
-- kepada coach pesakit (assigned_to = psy_patients.coach_id). Notifikasi loceng &
-- log timeline ikut sendiri melalui trigger sedia ada (trg_patient_event_notify /
-- trg_patient_event_log_created) sebab ia AFTER INSERT ON psy_patient_events.
CREATE OR REPLACE FUNCTION trg_patient_warded_auto_event()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NEW.status <> 'warded' OR OLD.status IS NOT DISTINCT FROM 'warded' THEN
    RETURN NEW;
  END IF;

  -- Elak rekod berganda kalau dah ada rekod 'warded' TERBUKA utk pesakit ni
  -- (cth staf toggle status warded→aktif→warded semula tanpa tutup rekod lama).
  IF EXISTS (
    SELECT 1 FROM psy_patient_events
    WHERE patient_id = NEW.id AND event_type = 'warded' AND status = 'open'
  ) THEN
    RETURN NEW;
  END IF;

  INSERT INTO psy_patient_events (
    patient_id, event_type, priority, status, event_date,
    need_visit, visit_priority, assigned_to, notify_roles, notes, reported_by
  ) VALUES (
    NEW.id, 'warded', 'high', 'open', CURRENT_DATE,
    true, 'high', NEW.coach_id, '["manager","coach"]'::jsonb,
    'Rekod dicipta automatik — status pesakit ditukar ke Warded (Masuk Wad/Hospital).',
    NULL
  );

  -- Audit #146 (sub-3, 7 Okt 2026) — task peribadi auto-cipta & dipautkan kpd
  -- coach pesakit ni (psy_coach_tasks.patient_id), supaya terus muncul di
  -- widget "Task Peribadi" dashboard coach tanpa staf perlu taip manual.
  -- Marker '[auto:warded]' dlm notes elak duplikasi kalau status toggle
  -- warded→aktif→warded berulang kali sebelum task lama ditutup.
  IF NEW.coach_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM psy_coach_tasks
    WHERE patient_id = NEW.id AND coach_id = NEW.coach_id
      AND status <> 'selesai' AND notes LIKE '%[auto:warded]%'
  ) THEN
    INSERT INTO psy_coach_tasks (
      coach_id, title, notes, task_date, priority, status, patient_id
    ) VALUES (
      NEW.coach_id,
      '🏥 Pesakit ' || COALESCE(NEW.full_name, 'Tanpa Nama') || ' masuk Wad/Hospital — rancang lawatan',
      'Dicipta automatik — status pesakit ditukar ke Warded. [auto:warded]',
      CURRENT_DATE, 'tinggi', 'belum_mula', NEW.id
    );
  END IF;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE LOG 'trg_patient_warded_auto_event: %', SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_patient_warded_auto_event ON psy_patients;
CREATE TRIGGER trg_patient_warded_auto_event
  AFTER UPDATE ON psy_patients
  FOR EACH ROW EXECUTE FUNCTION trg_patient_warded_auto_event();
