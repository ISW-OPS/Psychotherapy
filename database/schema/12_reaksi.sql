-- ═══════════════════════════════════════════════════════════════════════════
-- REAKSI PEMULIHAN
-- Katalog simptom + kategori, engine saranan auto (Recovery Advice v2),
-- pemetaan simptom↔tindakan, log mesej WA berperingkat (queue + zon protokol),
-- dan laporan reaksi mingguan pesakit.
-- Jadual: psy_reaksi_item, psy_reaksi_kategori, psy_reaksi_actions,
--         psy_reaksi_action_map, psy_reaksi_advice_log, psy_patient_reaksi_reports
-- Nota: fungsi trigger trg_reaksi_advice_notify_emergency() dan
--       trg_patient_reaksi_notify_coach() ditakrif dalam fail skema notifikasi.
-- ═══════════════════════════════════════════════════════════════════════════

-- ──── psy_reaksi_item — katalog simptom reaksi pemulihan ────
-- Sumber tunggal reaksi pemulihan; diguna di checklist harian pesakit
-- (Catatan Harian item 5, grouped) + CRUD staff (kepatuhan.html).
CREATE TABLE IF NOT EXISTS psy_reaksi_item (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  kumpulan         TEXT NOT NULL,                     -- nama kumpulan, cth 'Pencernaan'
  ikon             TEXT,                              -- emoji kumpulan, cth '🍽️'
  label            TEXT NOT NULL,                     -- simptom, cth 'Kembung perut'
  urutan           INT  NOT NULL DEFAULT 0,           -- susunan global (kumpulan + item)
  aktif            BOOLEAN NOT NULL DEFAULT true,
  tahap_risiko     TEXT    NOT NULL DEFAULT 'rendah',
  markah_risiko    INT     NOT NULL DEFAULT 5,
  penerangan       TEXT,
  contoh           JSONB   NOT NULL DEFAULT '[]',
  perlu_pemantauan BOOLEAN NOT NULL DEFAULT false,
  tunjuk_ringkasan BOOLEAN NOT NULL DEFAULT true,
  notifikasi_coach BOOLEAN NOT NULL DEFAULT false,
  is_emergency     BOOLEAN NOT NULL DEFAULT false,
  created_at       TIMESTAMPTZ DEFAULT now(),
  updated_at       TIMESTAMPTZ DEFAULT now(),
  CONSTRAINT chk_reaksi_item_tahap CHECK (tahap_risiko IN ('rendah','sederhana','tinggi'))
);

CREATE INDEX IF NOT EXISTS idx_reaksi_item_tahap ON psy_reaksi_item(tahap_risiko);

ALTER TABLE psy_reaksi_item ENABLE ROW LEVEL SECURITY;

-- Semua staff boleh urus (tambah/edit/buang) senarai.
DROP POLICY IF EXISTS "Staff manage reaksi item" ON psy_reaksi_item;
CREATE POLICY "Staff manage reaksi item" ON psy_reaksi_item FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- Pesakit perlu BACA katalog reaksi utk wizard Catatan Harian (data rujukan sahaja)
DROP POLICY IF EXISTS "Authenticated boleh baca reaksi item" ON psy_reaksi_item;
CREATE POLICY "Authenticated boleh baca reaksi item" ON psy_reaksi_item FOR SELECT
  TO authenticated USING (true);

COMMENT ON COLUMN psy_reaksi_item.tahap_risiko  IS 'rendah (Green) / sederhana (Yellow) / tinggi (Red)';
COMMENT ON COLUMN psy_reaksi_item.markah_risiko IS 'Julat 1-100, semakin tinggi semakin berisiko';
COMMENT ON COLUMN psy_reaksi_item.contoh        IS 'Array string — contoh bagaimana simptom dirasai pesakit';
COMMENT ON COLUMN psy_reaksi_item.is_emergency  IS 'Simptom kecemasan: advice log ditanda emergency (tidak auto-hantar WA)';

-- ──── psy_reaksi_kategori — kategori/kumpulan reaksi ────
-- psy_reaksi_item.kumpulan kekal TEXT dan dipadankan dengan nama kategori.
CREATE TABLE IF NOT EXISTS psy_reaksi_kategori (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nama       TEXT NOT NULL UNIQUE,
  ikon       TEXT,
  penerangan TEXT,
  aktif      BOOLEAN NOT NULL DEFAULT true,
  urutan     INT NOT NULL DEFAULT 100,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE psy_reaksi_kategori ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff manage reaksi kategori" ON psy_reaksi_kategori;
CREATE POLICY "Staff manage reaksi kategori" ON psy_reaksi_kategori FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "Authenticated read reaksi kategori" ON psy_reaksi_kategori;
CREATE POLICY "Authenticated read reaksi kategori" ON psy_reaksi_kategori FOR SELECT
  USING (auth.uid() IS NOT NULL);

-- ──── psy_reaksi_actions — perpustakaan tindakan (Recovery Action) ────
-- Reusable merentasi simptom; doktor/admin kemaskini tanpa ubah kod.
CREATE TABLE IF NOT EXISTS psy_reaksi_actions (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title        TEXT NOT NULL,
  description  TEXT,
  priority     INT NOT NULL DEFAULT 100,   -- kecil = diutamakan/dipapar dulu
  is_emergency BOOLEAN NOT NULL DEFAULT false,
  aktif        BOOLEAN NOT NULL DEFAULT true,
  kategori     TEXT,
  jenis        TEXT NOT NULL DEFAULT 'am',
  panduan      TEXT,
  created_at   TIMESTAMPTZ DEFAULT now(),
  updated_at   TIMESTAMPTZ DEFAULT now(),
  CONSTRAINT chk_reaksi_actions_jenis CHECK (jenis IN ('am','pemakanan','gaya_hidup','terapi','pemerhatian','tindakan','kecemasan'))
);

ALTER TABLE psy_reaksi_actions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff manage reaksi actions" ON psy_reaksi_actions;
CREATE POLICY "Staff manage reaksi actions" ON psy_reaksi_actions FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "Authenticated read reaksi actions" ON psy_reaksi_actions;
CREATE POLICY "Authenticated read reaksi actions" ON psy_reaksi_actions FOR SELECT
  USING (auth.uid() IS NOT NULL);

COMMENT ON COLUMN psy_reaksi_actions.kategori IS 'Kategori bebas (biasanya kumpulan simptom, cth Pencernaan)';
COMMENT ON COLUMN psy_reaksi_actions.jenis    IS 'am/pemakanan/gaya_hidup/terapi/pemerhatian/tindakan/kecemasan';
COMMENT ON COLUMN psy_reaksi_actions.panduan  IS 'Panduan / cara penyediaan terperinci (teks; baris baharu dikekalkan)';

-- ──── psy_reaksi_action_map — pemetaan simptom ↔ tindakan (many-to-many) ────
CREATE TABLE IF NOT EXISTS psy_reaksi_action_map (
  symptom_id  UUID NOT NULL REFERENCES psy_reaksi_item(id)    ON DELETE CASCADE,
  action_id   UUID NOT NULL REFERENCES psy_reaksi_actions(id) ON DELETE CASCADE,
  created_at  TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (symptom_id, action_id)
);

CREATE INDEX IF NOT EXISTS idx_reaksi_action_map_symptom ON psy_reaksi_action_map(symptom_id);
CREATE INDEX IF NOT EXISTS idx_reaksi_action_map_action  ON psy_reaksi_action_map(action_id);

ALTER TABLE psy_reaksi_action_map ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff manage reaksi mapping" ON psy_reaksi_action_map;
CREATE POLICY "Staff manage reaksi mapping" ON psy_reaksi_action_map FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "Authenticated read reaksi mapping" ON psy_reaksi_action_map;
CREATE POLICY "Authenticated read reaksi mapping" ON psy_reaksi_action_map FOR SELECT
  USING (auth.uid() IS NOT NULL);

-- ──── psy_reaksi_advice_log — log mesej saranan (draf WA, satu baris = satu mesej) ────
-- Flow: pesakit submit Catatan Harian → client kumpul simptom ditanda →
-- padankan tindakan (psy_reaksi_action_map) → dedupe + susun ikut priority →
-- jana hingga 3 mesej (tindakan terus, gaya hidup +5 min, diet +10 min) →
-- queue send_after; cron reaksi-advice-send proses tiap 5 minit.
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
  msg_jenis        TEXT        NOT NULL DEFAULT 'tindakan',
  send_after       TIMESTAMPTZ NOT NULL DEFAULT now(),
  send_attempts    INT         NOT NULL DEFAULT 0,
  zon              TEXT,
  reviewed_by      UUID REFERENCES psy_profiles(id),
  reviewed_at      TIMESTAMPTZ,
  sent_by          UUID REFERENCES psy_profiles(id),
  sent_at          TIMESTAMPTZ,
  created_at       TIMESTAMPTZ DEFAULT now(),
  updated_at       TIMESTAMPTZ DEFAULT now(),
  CONSTRAINT chk_reaksi_advice_msg_jenis CHECK (msg_jenis IN ('tindakan','diet','gaya_hidup')),
  CONSTRAINT chk_reaksi_advice_zon       CHECK (zon IN ('hijau','kuning','merah'))
);

CREATE INDEX IF NOT EXISTS idx_reaksi_advice_log_status  ON psy_reaksi_advice_log(status, created_at);
CREATE INDEX IF NOT EXISTS idx_reaksi_advice_log_patient ON psy_reaksi_advice_log(patient_id, log_date);
CREATE INDEX IF NOT EXISTS idx_reaksi_advice_log_queue   ON psy_reaksi_advice_log(status, send_after);
CREATE INDEX IF NOT EXISTS idx_reaksi_advice_log_zon     ON psy_reaksi_advice_log(zon, log_date);

ALTER TABLE psy_reaksi_advice_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff manage advice log" ON psy_reaksi_advice_log;
CREATE POLICY "Staff manage advice log" ON psy_reaksi_advice_log FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "Patient insert own advice log" ON psy_reaksi_advice_log;
CREATE POLICY "Patient insert own advice log" ON psy_reaksi_advice_log FOR INSERT
  WITH CHECK (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

-- Pesakit perlu BACA baris sendiri (insert .select('id') utk auto-hantar WA)
DROP POLICY IF EXISTS "Patient read own advice log" ON psy_reaksi_advice_log;
CREATE POLICY "Patient read own advice log" ON psy_reaksi_advice_log FOR SELECT
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

-- Nota: trigger trg_reaksi_advice_notify_emergency (zon merah → notif coach)
-- berada dalam 18_notifications_automations.sql bersama fungsinya.

COMMENT ON COLUMN psy_reaksi_advice_log.msg_jenis     IS 'tindakan / diet / gaya_hidup — satu submission Poll Harian boleh jana hingga 3 mesej';
COMMENT ON COLUMN psy_reaksi_advice_log.send_after    IS 'Mesej hanya dihantar selepas waktu ini (queue; cron proses tiap 5 minit)';
COMMENT ON COLUMN psy_reaksi_advice_log.send_attempts IS 'Bilangan percubaan hantar gagal; cron berhenti cuba selepas 5';
COMMENT ON COLUMN psy_reaksi_advice_log.zon           IS 'hijau/kuning/merah — zon protokol dikira dari tahap_risiko tertinggi simptom submission ini';

-- ──── psy_patient_reaksi_reports — laporan reaksi mingguan pesakit ────
CREATE TABLE IF NOT EXISTS psy_patient_reaksi_reports (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id          UUID REFERENCES psy_treatment_plans(id) ON DELETE CASCADE NOT NULL,
  patient_id       UUID REFERENCES psy_patients(id)        ON DELETE CASCADE NOT NULL,
  week_number      INT  NOT NULL,
  reaksi_pemulihan JSONB DEFAULT '{}',
  submitted_at     TIMESTAMPTZ DEFAULT now(),
  updated_at       TIMESTAMPTZ DEFAULT now(),
  UNIQUE (plan_id, patient_id, week_number)
);

CREATE INDEX IF NOT EXISTS idx_patient_reaksi_plan_week
  ON psy_patient_reaksi_reports(plan_id, patient_id, week_number);

ALTER TABLE psy_patient_reaksi_reports ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Patient select own reaksi" ON psy_patient_reaksi_reports;
CREATE POLICY "Patient select own reaksi" ON psy_patient_reaksi_reports
  FOR SELECT USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Patient insert own reaksi" ON psy_patient_reaksi_reports;
CREATE POLICY "Patient insert own reaksi" ON psy_patient_reaksi_reports
  FOR INSERT WITH CHECK (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Patient update own reaksi" ON psy_patient_reaksi_reports;
CREATE POLICY "Patient update own reaksi" ON psy_patient_reaksi_reports
  FOR UPDATE USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Staff read reaksi reports" ON psy_patient_reaksi_reports;
CREATE POLICY "Staff read reaksi reports" ON psy_patient_reaksi_reports
  FOR SELECT USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- Nota: trigger trg_patient_reaksi_notify_coach berada dalam
-- 18_notifications_automations.sql bersama fungsinya.

-- ═══════════════════════════════════════════════════════════════════════════
-- DATA RUJUKAN (SEED)
-- ═══════════════════════════════════════════════════════════════════════════

-- ──── Seed psy_reaksi_item — 7 kumpulan / 48 simptom ────
-- (+ "Tiada simptom" setiap kumpulan; "Lain-lain" = free-text auto di UI).
-- Hanya seed bila jadual kosong supaya tak timpa tambahan staff (CRUD).
INSERT INTO psy_reaksi_item (kumpulan, ikon, label, urutan)
SELECT v.kumpulan, v.ikon, v.label, v.urutan
FROM (VALUES
  -- 1. Pencernaan
  ('Pencernaan','🍽️','Kembung perut',10),
  ('Pencernaan','🍽️','Banyak angin',20),
  ('Pencernaan','🍽️','Banyak sendawa',30),
  ('Pencernaan','🍽️','Sakit perut',40),
  ('Pencernaan','🍽️','Loya',50),
  ('Pencernaan','🍽️','Muntah',60),
  ('Pencernaan','🍽️','Hilang selera makan',70),
  ('Pencernaan','🍽️','Banyak membuang air besar',80),
  ('Pencernaan','🍽️','Cirit-birit',90),
  ('Pencernaan','🍽️','Sembelit',100),
  ('Pencernaan','🍽️','Najis hitam',110),
  ('Pencernaan','🍽️','Tiada simptom',120),
  -- 2. Peredaran Darah
  ('Peredaran Darah','🩸','Tekanan darah tinggi',130),
  ('Peredaran Darah','🩸','Tekanan darah rendah',140),
  ('Peredaran Darah','🩸','Berdebar-debar',150),
  ('Peredaran Darah','🩸','Tiada simptom',160),
  -- 3. Otot & Saraf
  ('Otot & Saraf','💪','Sakit badan',170),
  ('Otot & Saraf','💪','Sakit sendi',180),
  ('Otot & Saraf','💪','Sakit otot',190),
  ('Otot & Saraf','💪','Sakit pinggang',200),
  ('Otot & Saraf','💪','Sakit tengkuk',210),
  ('Otot & Saraf','💪','Sakit belikat',220),
  ('Otot & Saraf','💪','Kejang',230),
  ('Otot & Saraf','💪','Kebas',240),
  ('Otot & Saraf','💪','Tiada simptom',250),
  -- 4. Detoksifikasi
  ('Detoksifikasi','🧴','Mukus keluar',260),
  ('Detoksifikasi','🧴','Jerawat keluar',270),
  ('Detoksifikasi','🧴','Gatal-gatal',280),
  ('Detoksifikasi','🧴','Ruam',290),
  ('Detoksifikasi','🧴','Kulit mengelupas',300),
  ('Detoksifikasi','🧴','Kulit menjadi lebih sensitif',310),
  ('Detoksifikasi','🧴','Badan panas',320),
  ('Detoksifikasi','🧴','Badan sejuk',330),
  ('Detoksifikasi','🧴','Tiada simptom',340),
  -- 5. Emosi & Tenaga
  ('Emosi & Tenaga','⚡','Susah nak tidur (insomnia)',350),
  ('Emosi & Tenaga','⚡','Mengantuk luar biasa',360),
  ('Emosi & Tenaga','⚡','Kurang tenaga',370),
  ('Emosi & Tenaga','⚡','Cepat letih',380),
  ('Emosi & Tenaga','⚡','Lemah badan',390),
  ('Emosi & Tenaga','⚡','Mudah sebak',400),
  ('Emosi & Tenaga','⚡','Gelisah',410),
  ('Emosi & Tenaga','⚡','Badan terasa berat',420),
  ('Emosi & Tenaga','⚡','Tiada simptom',430),
  -- 6. Pernafasan
  ('Pernafasan','🫁','Sesak nafas',440),
  ('Pernafasan','🫁','Batuk',450),
  ('Pernafasan','🫁','Kahak',460),
  ('Pernafasan','🫁','Mukus',470),
  ('Pernafasan','🫁','Hidung berair',480),
  ('Pernafasan','🫁','Bersin',490),
  ('Pernafasan','🫁','Tiada simptom',500),
  -- 7. Bengkak & Cecair
  ('Bengkak & Cecair','💧','Bengkak kaki',510),
  ('Bengkak & Cecair','💧','Bengkak tangan',520),
  ('Bengkak & Cecair','💧','Bengkak muka',530),
  ('Bengkak & Cecair','💧','Edema',540),
  ('Bengkak & Cecair','💧','Tiada simptom',550)
) AS v(kumpulan, ikon, label, urutan)
WHERE NOT EXISTS (SELECT 1 FROM psy_reaksi_item);

-- ──── Seed psy_reaksi_kategori — dijana dari kumpulan psy_reaksi_item ────
INSERT INTO psy_reaksi_kategori (nama, ikon, urutan)
SELECT kumpulan, MAX(COALESCE(ikon, '')), MIN(COALESCE(urutan, 100))
FROM psy_reaksi_item GROUP BY kumpulan
ON CONFLICT (nama) DO NOTHING;

-- ──── Seed contoh psy_reaksi_actions + pemetaan (Pencernaan + Peredaran Darah) ────
-- Supaya engine boleh diuji serta-merta; staff tambah/kemaskini selebihnya
-- dari Staff Portal (bukan hardcode). Hanya jalan bila jadual masih kosong.
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

  SELECT id INTO s_kembung  FROM psy_reaksi_item WHERE kumpulan='Pencernaan' AND label='Kembung perut' LIMIT 1;
  SELECT id INTO s_angin    FROM psy_reaksi_item WHERE kumpulan='Pencernaan' AND label='Banyak angin' LIMIT 1;
  SELECT id INTO s_loya     FROM psy_reaksi_item WHERE kumpulan='Pencernaan' AND label='Loya' LIMIT 1;
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
