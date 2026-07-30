-- Red Emergency Protocol — worklist zon merah/kuning (ganti roles/staff/risk.html
-- yang dibuang 21 Jul 2026 sebab hanya papar data demo tanpa enjin sebenar).
--
-- Guna sistem zon merah/kuning/hijau SEDIA ADA (psy_reaksi_advice_log.zon,
-- dikira client-side di roles/patient/kepatuhan.html) sebagai punca data —
-- jadual ni cuma tambah "worklist" (satu alert terbuka per pesakit + response
-- timer) dan tindakan mudah: staff hubungi pesakit → tandakan selesai.
-- TIADA checklist 8-langkah / incident report (dipermudah atas arahan user).

-- ──── psy_emergency_alerts ────
CREATE TABLE IF NOT EXISTS psy_emergency_alerts (
  id                       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id               UUID REFERENCES psy_patients(id) ON DELETE CASCADE NOT NULL,
  zon                      TEXT NOT NULL CHECK (zon IN ('kuning','merah')),
  symptoms                 JSONB DEFAULT '[]',
  source                   TEXT DEFAULT 'auto' CHECK (source IN ('auto','manual')),
  source_log_id            UUID REFERENCES psy_reaksi_advice_log(id) ON DELETE SET NULL,
  reported_at              TIMESTAMPTZ DEFAULT now(),
  response_target_minutes  INT NOT NULL,
  assigned_to              UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  status                   TEXT DEFAULT 'waiting_coach'
                            CHECK (status IN ('waiting_coach','contacted','waiting_vital','follow_up','resolved')),
  resolved_at              TIMESTAMPTZ,
  resolved_by              UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  notes                    TEXT,
  created_by                UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  created_at               TIMESTAMPTZ DEFAULT now(),
  updated_at               TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_emergency_alerts_status  ON psy_emergency_alerts(status, reported_at);
CREATE INDEX IF NOT EXISTS idx_emergency_alerts_patient ON psy_emergency_alerts(patient_id);

ALTER TABLE psy_emergency_alerts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff manage emergency alerts" ON psy_emergency_alerts;
CREATE POLICY "Staff manage emergency alerts" ON psy_emergency_alerts FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
  WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- ──── Ganti fungsi trigger sedia ada: tambah upsert psy_emergency_alerts + betulkan link notif ────
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
-- Trigger itu sendiri (AFTER INSERT ON psy_reaksi_advice_log) tak perlu di-DROP/CREATE
-- semula sebab kekal terikat pada fungsi yang sama (CREATE OR REPLACE FUNCTION di atas cukup).

-- ──── RBAC: buang modul 'risk' (orphan), tambah modul 'emergency' ────
DELETE FROM psy_modules WHERE code = 'risk';   -- CASCADE buang grant lama sekali

INSERT INTO psy_modules (code, label, icon, scope, sort_order) VALUES
  ('emergency', 'Red Emergency Protocol', '🚨', 'staff', 80)
ON CONFLICT (code) DO UPDATE SET label=EXCLUDED.label, icon=EXCLUDED.icon, scope=EXCLUDED.scope, sort_order=EXCLUDED.sort_order;

INSERT INTO psy_module_actions (module_code, action_code)
SELECT 'emergency', a.code FROM psy_actions a
ON CONFLICT DO NOTHING;

INSERT INTO psy_role_module_actions (role_code, module_code, action_code)
SELECT r, 'emergency', 'view' FROM (VALUES ('super_admin'),('manager'),('admin'),('doctor'),('coach')) AS x(r)
ON CONFLICT DO NOTHING;

INSERT INTO psy_role_module_actions (role_code, module_code, action_code)
SELECT rma.role_code, 'emergency', a.code
FROM psy_role_module_actions rma
CROSS JOIN psy_actions a
WHERE rma.module_code = 'emergency' AND rma.action_code = 'view'
  AND a.code IN ('create','edit','delete','export')
ON CONFLICT DO NOTHING;
