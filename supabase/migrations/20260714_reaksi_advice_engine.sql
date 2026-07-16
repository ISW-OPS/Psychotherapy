-- ============================================================
-- 20260714_reaksi_advice_engine.sql
-- Auto Recovery Advice + WhatsApp draft engine.
-- Symptom master = psy_reaksi_item (sedia ada). Tindakan (Recovery Action)
-- dan pemetaan simptom<->tindakan disimpan dalam DB (bukan hardcode kod)
-- supaya doktor/admin boleh kemaskini saranan tanpa ubah kod.
--
-- Flow: pesakit submit Catatan Harian -> client kumpul simptom yang
-- ditanda -> cari tindakan berkaitan (psy_reaksi_action_map) -> dedupe
-- + susun ikut priority -> jana mesej draf -> simpan psy_reaksi_advice_log
-- (status='draft') -> staff semak/edit di Staff Portal -> staff hantar WA.
-- ============================================================

-- ── 1. Recovery Action (perpustakaan tindakan, reusable merentasi simptom) ──
CREATE TABLE IF NOT EXISTS psy_reaksi_actions (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title        TEXT NOT NULL,
  description  TEXT,
  priority     INT NOT NULL DEFAULT 100,   -- kecil = diutamakan/dipapar dulu
  is_emergency BOOLEAN NOT NULL DEFAULT false,
  aktif        BOOLEAN NOT NULL DEFAULT true,
  created_at   TIMESTAMPTZ DEFAULT now(),
  updated_at   TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE psy_reaksi_actions ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  CREATE POLICY "Staff manage reaksi actions" ON psy_reaksi_actions FOR ALL
    USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "Authenticated read reaksi actions" ON psy_reaksi_actions FOR SELECT
    USING (auth.uid() IS NOT NULL);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ── 2. Recovery Mapping (many-to-many: satu simptom -> banyak tindakan, ──
--       satu tindakan -> banyak simptom) ─────────────────────────────────
CREATE TABLE IF NOT EXISTS psy_reaksi_action_map (
  symptom_id  UUID NOT NULL REFERENCES psy_reaksi_item(id)    ON DELETE CASCADE,
  action_id   UUID NOT NULL REFERENCES psy_reaksi_actions(id) ON DELETE CASCADE,
  created_at  TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (symptom_id, action_id)
);
ALTER TABLE psy_reaksi_action_map ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  CREATE POLICY "Staff manage reaksi mapping" ON psy_reaksi_action_map FOR ALL
    USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "Authenticated read reaksi mapping" ON psy_reaksi_action_map FOR SELECT
    USING (auth.uid() IS NOT NULL);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE INDEX IF NOT EXISTS idx_reaksi_action_map_symptom ON psy_reaksi_action_map(symptom_id);
CREATE INDEX IF NOT EXISTS idx_reaksi_action_map_action  ON psy_reaksi_action_map(action_id);

-- ── 3. Generated advice log — draf mesej WA (staff semak sebelum hantar) ─
CREATE TABLE IF NOT EXISTS psy_reaksi_advice_log (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id       UUID NOT NULL REFERENCES psy_patients(id)     ON DELETE CASCADE,
  kepatuhan_log_id UUID REFERENCES psy_kepatuhan_log(id)         ON DELETE SET NULL,
  log_date         DATE NOT NULL DEFAULT CURRENT_DATE,
  symptoms         JSONB NOT NULL DEFAULT '[]',   -- ["Pencernaan::Kembung perut", ...]
  actions          JSONB NOT NULL DEFAULT '[]',   -- [{id,title,priority,is_emergency}] snapshot dijana
  message_text     TEXT NOT NULL,                 -- boleh diedit staff sebelum hantar
  is_emergency     BOOLEAN NOT NULL DEFAULT false,
  status           TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','sent','skipped')),
  reviewed_by      UUID REFERENCES psy_profiles(id),
  reviewed_at      TIMESTAMPTZ,
  sent_by          UUID REFERENCES psy_profiles(id),
  sent_at          TIMESTAMPTZ,
  created_at       TIMESTAMPTZ DEFAULT now(),
  updated_at       TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE psy_reaksi_advice_log ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  CREATE POLICY "Staff manage advice log" ON psy_reaksi_advice_log FOR ALL
    USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "Patient insert own advice log" ON psy_reaksi_advice_log FOR INSERT
    WITH CHECK (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
-- Pesakit perlu BACA baris sendiri (insert .select('id') utk auto-hantar WA)
DO $$ BEGIN
  CREATE POLICY "Patient read own advice log" ON psy_reaksi_advice_log FOR SELECT
    USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE INDEX IF NOT EXISTS idx_reaksi_advice_log_status  ON psy_reaksi_advice_log(status, created_at);
CREATE INDEX IF NOT EXISTS idx_reaksi_advice_log_patient ON psy_reaksi_advice_log(patient_id, log_date);

-- ── 4. Seed contoh (Pencernaan + Peredaran Darah) — reproduce senario ────
--       pemadanan yang dibincang (Kembung perut/Banyak angin/Loya/Berdebar).
--       Guna simptom sedia ada dalam psy_reaksi_item. Staff boleh tambah/
--       kemaskini selebihnya terus dari Staff Portal (bukan hardcode).
DO $$
DECLARE
  a_air_suam UUID; a_air_halia UUID; a_kurang_sukar UUID;
  a_elak_sejuk UUID; a_rehat UUID; a_elak_berminyak UUID; a_pernafasan UUID;
  s_kembung UUID; s_angin UUID; s_loya UUID; s_berdebar UUID;
BEGIN
  IF EXISTS (SELECT 1 FROM psy_reaksi_actions) THEN RETURN; END IF;

  INSERT INTO psy_reaksi_actions (title, priority) VALUES ('Minum air suam', 10) RETURNING id INTO a_air_suam;
  INSERT INTO psy_reaksi_actions (title, priority) VALUES ('Minum air halia', 20) RETURNING id INTO a_air_halia;
  INSERT INTO psy_reaksi_actions (title, priority) VALUES ('Kurangkan makanan sukar dihadam', 30) RETURNING id INTO a_kurang_sukar;
  INSERT INTO psy_reaksi_actions (title, priority) VALUES ('Elakkan minuman sejuk', 40) RETURNING id INTO a_elak_sejuk;
  INSERT INTO psy_reaksi_actions (title, priority) VALUES ('Rehat secukupnya', 50) RETURNING id INTO a_rehat;
  INSERT INTO psy_reaksi_actions (title, priority) VALUES ('Elakkan makanan berminyak', 60) RETURNING id INTO a_elak_berminyak;
  INSERT INTO psy_reaksi_actions (title, priority) VALUES ('Lakukan Pernafasan Fitrah', 70) RETURNING id INTO a_pernafasan;

  SELECT id INTO s_kembung FROM psy_reaksi_item WHERE kumpulan='Pencernaan' AND label='Kembung perut' LIMIT 1;
  SELECT id INTO s_angin   FROM psy_reaksi_item WHERE kumpulan='Pencernaan' AND label='Banyak angin' LIMIT 1;
  SELECT id INTO s_loya    FROM psy_reaksi_item WHERE kumpulan='Pencernaan' AND label='Loya' LIMIT 1;
  SELECT id INTO s_berdebar FROM psy_reaksi_item WHERE kumpulan='Peredaran Darah' AND label='Berdebar-debar' LIMIT 1;

  IF s_kembung IS NOT NULL THEN
    INSERT INTO psy_reaksi_action_map (symptom_id, action_id) VALUES
      (s_kembung, a_air_suam), (s_kembung, a_air_halia), (s_kembung, a_kurang_sukar);
  END IF;
  IF s_angin IS NOT NULL THEN
    INSERT INTO psy_reaksi_action_map (symptom_id, action_id) VALUES
      (s_angin, a_air_halia), (s_angin, a_elak_sejuk);
  END IF;
  IF s_loya IS NOT NULL THEN
    INSERT INTO psy_reaksi_action_map (symptom_id, action_id) VALUES
      (s_loya, a_air_halia), (s_loya, a_rehat), (s_loya, a_elak_berminyak);
  END IF;
  IF s_berdebar IS NOT NULL THEN
    INSERT INTO psy_reaksi_action_map (symptom_id, action_id) VALUES
      (s_berdebar, a_pernafasan);
  END IF;
END $$;

-- ── 5. Trigger: alert coach serta-merta bila advice log ditanda emergency ─
--       (patient client tak boleh insert psy_notifications terus sebab RLS
--       hanya benarkan staff — guna SECURITY DEFINER trigger macam pattern
--       trg_patient_reaksi_notify_coach sedia ada.)
CREATE OR REPLACE FUNCTION trg_reaksi_advice_notify_emergency()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_coach_id     UUID;
  v_patient_name TEXT;
BEGIN
  IF NOT NEW.is_emergency THEN RETURN NEW; END IF;

  SELECT pt.coach_id, COALESCE(pr.full_name, pt.full_name, 'Pesakit')
    INTO v_coach_id, v_patient_name
  FROM psy_patients pt
  LEFT JOIN psy_profiles pr ON pr.id = pt.user_id
  WHERE pt.id = NEW.patient_id;

  IF v_coach_id IS NOT NULL THEN
    INSERT INTO psy_notifications (user_id, type, title, body, link)
    VALUES (
      v_coach_id, 'reaksi',
      '🚨 Reaksi Kecemasan: ' || v_patient_name,
      v_patient_name || ' melaporkan simptom yang memerlukan perhatian segera. Sila semak & hantar Saranan Reaksi.',
      'reaksi-advice.html'
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

SELECT 'OK — reaksi advice engine (actions + mapping + advice log) ready' AS status;
