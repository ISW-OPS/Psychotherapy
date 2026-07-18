-- ═══════════════════════════════════════════════════════════════════
-- SKEMA: CATATAN HARIAN & KEPATUHAN
-- Jadual: psy_daily_checkins, psy_daily_completions,
--         psy_kepatuhan_item, psy_kepatuhan_log, psy_kepatuhan_weekly
-- Daily check-in pesakit (mood/emosi/tidur/madu), checklist aktiviti
-- harian, dan modul Kepatuhan (item config per fasa, log harian,
-- kelas A/B/C mingguan auto + override coach).
-- ═══════════════════════════════════════════════════════════════════

-- ──── psy_daily_checkins ────
CREATE TABLE IF NOT EXISTS psy_daily_checkins (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id     UUID REFERENCES psy_patients(id) ON DELETE CASCADE NOT NULL,
  checkin_date   DATE DEFAULT CURRENT_DATE NOT NULL,
  mood_score     INT CHECK (mood_score BETWEEN 1 AND 10),
  energy_score   INT CHECK (energy_score BETWEEN 1 AND 10),
  sleep_quality  INT CHECK (sleep_quality BETWEEN 1 AND 10),
  sleep_hours    NUMERIC(3,1),
  symptoms       JSONB DEFAULT '[]',
  activities     JSONB DEFAULT '[]',
  emotions       JSONB DEFAULT '[]',   -- senarai emosi dipilih
  sleep_time     TEXT,                 -- tidur pukul (HH:MM)
  wake_time      TEXT,                 -- bangun pukul (HH:MM)
  activity_level TEXT,                 -- tahap gangguan aktiviti harian
  madu_count     INT NOT NULL DEFAULT 0,
  notes          TEXT,
  created_at     TIMESTAMPTZ DEFAULT now(),
  UNIQUE (patient_id, checkin_date)
);

CREATE INDEX IF NOT EXISTS idx_psy_checkins_patient ON psy_daily_checkins(patient_id);

ALTER TABLE psy_daily_checkins ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Patients manage daily check-ins" ON psy_daily_checkins;
CREATE POLICY "Patients manage daily check-ins" ON psy_daily_checkins FOR ALL
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()))
  WITH CHECK (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Staff read daily check-ins" ON psy_daily_checkins;
CREATE POLICY "Staff read daily check-ins" ON psy_daily_checkins FOR SELECT
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "Staff can read all checkins" ON psy_daily_checkins;
CREATE POLICY "Staff can read all checkins"
  ON psy_daily_checkins FOR SELECT
  USING (
    auth.uid() IN (SELECT id FROM psy_profiles WHERE role = 'staff')
    OR auth.uid() IN (SELECT user_id FROM psy_patients WHERE id = patient_id)
  );

-- Staff isi Catatan Harian bagi pihak pesakit (mod staff borang kepatuhan)
DROP POLICY IF EXISTS "Staff manage daily checkins" ON psy_daily_checkins;
CREATE POLICY "Staff manage daily checkins" ON psy_daily_checkins FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
  WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

COMMENT ON COLUMN psy_daily_checkins.madu_count IS
  'Bilangan kali pesakit minum madu hari ini. Target dari psy_packages.madu_frequency_per_day.';

-- ──── psy_daily_completions ────
-- Checklist aktiviti harian pesakit: 1 baris per item ditanda per hari.
CREATE TABLE IF NOT EXISTS psy_daily_completions (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id   UUID NOT NULL REFERENCES psy_patients(id) ON DELETE CASCADE,
  log_date     DATE NOT NULL DEFAULT CURRENT_DATE,
  item_time    TEXT NOT NULL,      -- 'HH:MM' dari jadual
  activity     TEXT NOT NULL,      -- snapshot nama aktiviti
  completed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(patient_id, log_date, item_time)
);

CREATE INDEX IF NOT EXISTS idx_daily_completions_patient_date
  ON psy_daily_completions(patient_id, log_date);

ALTER TABLE psy_daily_completions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Patient manage own completions" ON psy_daily_completions;
CREATE POLICY "Patient manage own completions"
  ON psy_daily_completions FOR ALL
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()))
  WITH CHECK (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Staff read completions" ON psy_daily_completions;
CREATE POLICY "Staff read completions"
  ON psy_daily_completions FOR SELECT
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- ──── psy_kepatuhan_item ────
-- Config soalan checklist per fasa (coach boleh edit).
-- Kelas: A >= 85%, B 50-84%, C < 50% (cutoff lalai).
CREATE TABLE IF NOT EXISTS psy_kepatuhan_item (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  fasa        TEXT NOT NULL CHECK (fasa IN ('week1','week2_4','week5_12','fasa2','fasa3')),
  item_key    TEXT NOT NULL,
  label       TEXT NOT NULL,
  nota        TEXT,                       -- keterangan (cth singkatan LTH/IB)
  jenis_input TEXT NOT NULL DEFAULT 'pilih_satu'
              CHECK (jenis_input IN ('kiraan','pilih_satu','pilih_banyak')),
  period      TEXT NOT NULL DEFAULT 'harian'
              CHECK (period IN ('harian','mingguan','bulanan')),
  options     JSONB NOT NULL DEFAULT '[]', -- [{value,label,mata}] ; 'mata' = markah
  meta        JSONB NOT NULL DEFAULT '{}', -- cth {"target":3} utk item kiraan (madu)
  berskor     BOOLEAN NOT NULL DEFAULT true, -- false = tracking sahaja
  urutan      INT NOT NULL DEFAULT 0,
  aktif       BOOLEAN NOT NULL DEFAULT true,
  created_at  TIMESTAMPTZ DEFAULT now(),
  updated_at  TIMESTAMPTZ DEFAULT now(),
  UNIQUE (fasa, item_key)
);

CREATE INDEX IF NOT EXISTS idx_kepatuhan_item_fasa ON psy_kepatuhan_item(fasa, urutan);

ALTER TABLE psy_kepatuhan_item ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "kepatuhan_item_staff_all" ON psy_kepatuhan_item;
CREATE POLICY "kepatuhan_item_staff_all" ON psy_kepatuhan_item FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
  WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "kepatuhan_item_patient_read" ON psy_kepatuhan_item;
CREATE POLICY "kepatuhan_item_patient_read" ON psy_kepatuhan_item FOR SELECT
  USING (aktif = true);

-- ──── psy_kepatuhan_log ────
-- Jawapan pesakit, 1 baris / hari.
CREATE TABLE IF NOT EXISTS psy_kepatuhan_log (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id  UUID REFERENCES psy_patients(id) ON DELETE CASCADE NOT NULL,
  log_date    DATE NOT NULL DEFAULT CURRENT_DATE,
  fasa        TEXT NOT NULL CHECK (fasa IN ('week1','week2_4','week5_12','fasa2','fasa3')),
  jawapan     JSONB NOT NULL DEFAULT '{}', -- {item_key: value | [values]}
  skor_harian NUMERIC(5,2),                -- % markah hari itu (item berskor sahaja)
  created_at  TIMESTAMPTZ DEFAULT now(),
  updated_at  TIMESTAMPTZ DEFAULT now(),
  UNIQUE (patient_id, log_date)
);

CREATE INDEX IF NOT EXISTS idx_kepatuhan_log_patient ON psy_kepatuhan_log(patient_id, log_date);

ALTER TABLE psy_kepatuhan_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "kepatuhan_log_patient_all" ON psy_kepatuhan_log;
CREATE POLICY "kepatuhan_log_patient_all" ON psy_kepatuhan_log FOR ALL
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()))
  WITH CHECK (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "kepatuhan_log_staff_read" ON psy_kepatuhan_log;
CREATE POLICY "kepatuhan_log_staff_read" ON psy_kepatuhan_log FOR SELECT
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- Staff boleh upsert log bagi pihak pesakit (kepatuhan-fill.html / mod staff)
DROP POLICY IF EXISTS "kepatuhan_log_staff_write" ON psy_kepatuhan_log;
CREATE POLICY "kepatuhan_log_staff_write" ON psy_kepatuhan_log FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
  WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "Staff manage kepatuhan log" ON psy_kepatuhan_log;
CREATE POLICY "Staff manage kepatuhan log" ON psy_kepatuhan_log FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
  WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- ──── psy_kepatuhan_weekly ────
-- Kelas A/B/C dikira mingguan (auto + coach override).
CREATE TABLE IF NOT EXISTS psy_kepatuhan_weekly (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id     UUID REFERENCES psy_patients(id) ON DELETE CASCADE NOT NULL,
  minggu_mula    DATE NOT NULL,             -- tarikh Isnin minggu berkenaan
  fasa           TEXT,
  skor           NUMERIC(5,2),              -- % mingguan (purata item berskor)
  bil_hari_isi   INT DEFAULT 0,             -- berapa hari pesakit isi minggu itu
  kelas          CHAR(1) CHECK (kelas IN ('A','B','C')),           -- auto
  override_kelas CHAR(1) CHECK (override_kelas IN ('A','B','C')),  -- coach pinda
  override_by    UUID REFERENCES psy_profiles(id),
  override_at    TIMESTAMPTZ,
  nota_coach     TEXT,
  created_at     TIMESTAMPTZ DEFAULT now(),
  updated_at     TIMESTAMPTZ DEFAULT now(),
  UNIQUE (patient_id, minggu_mula)
);

CREATE INDEX IF NOT EXISTS idx_kepatuhan_weekly_patient ON psy_kepatuhan_weekly(patient_id, minggu_mula);

ALTER TABLE psy_kepatuhan_weekly ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "kepatuhan_weekly_patient_read" ON psy_kepatuhan_weekly;
CREATE POLICY "kepatuhan_weekly_patient_read" ON psy_kepatuhan_weekly FOR SELECT
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "kepatuhan_weekly_staff_all" ON psy_kepatuhan_weekly;
CREATE POLICY "kepatuhan_weekly_staff_all" ON psy_kepatuhan_weekly FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
  WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "kepatuhan_weekly_staff_write" ON psy_kepatuhan_weekly;
CREATE POLICY "kepatuhan_weekly_staff_write" ON psy_kepatuhan_weekly FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
  WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- ═══════════════════════════════════════════════════════════════════
-- SEED — item checklist kepatuhan WEEK 1
-- Set asas semasa (5 item aktif): madu LTH/IB, madu LTHPG/YHPG,
-- zikir bersanad, pantang makan, reaksi pemulihan (tracking sahaja).
-- Item lain (pernafasan, terapi bumi, berjemur, air kelapa, yogurt)
-- dinyahaktif buat sementara — diaktifkan balik bila set penuh diguna.
-- Madu (jenis kiraan) guna mata bertingkat: Tidak=0, 2x=1, 3x=2,
-- 4x=3, 5x=4, Lebih 5x=4 (maks 4 mata/item).
-- ═══════════════════════════════════════════════════════════════════
INSERT INTO psy_kepatuhan_item (fasa, item_key, label, nota, jenis_input, period, options, meta, berskor, urutan, aktif) VALUES
('week1','madu_lth_ib','Minum Madu (LTH / IB)','LTH: Lote Tree Honey · IB: Immune Booster Honey','kiraan','harian',
 '[{"value":"tidak","label":"Tidak minum","mata":0},{"value":"2","label":"2x","mata":1},{"value":"3","label":"3x","mata":2},{"value":"4","label":"4x","mata":3},{"value":"5","label":"5x","mata":4},{"value":"other","label":"Lebih 5x","mata":4}]',
 '{"target":3}', true, 1, true),

('week1','madu_lthpg_yhpg','Minum Madu (LTHPG / YHPG)','LTHPG: Lote Tree Honey Pearl Garlic · YHPG: Young & Healthy Pearl Garlic','kiraan','harian',
 '[{"value":"tidak","label":"Tidak minum","mata":0},{"value":"2","label":"2x","mata":1},{"value":"3","label":"3x","mata":2},{"value":"4","label":"4x","mata":3},{"value":"5","label":"5x","mata":4},{"value":"other","label":"Lebih 5x","mata":4}]',
 '{"target":3}', true, 2, true),

('week1','zikir_bersanad','Zikir Bersanad Subuh & Maghrib',NULL,'pilih_satu','harian',
 '[{"value":"subuh_maghrib","label":"Buat waktu Subuh & Maghrib","mata":2},{"value":"subuh","label":"Hanya waktu Subuh","mata":1},{"value":"maghrib","label":"Hanya waktu Maghrib","mata":1},{"value":"tidak","label":"Tidak buat","mata":0}]',
 '{}', true, 3, true),

('week1','pantang_makan','Pantang Makan',NULL,'pilih_satu','harian',
 '[{"value":"baik","label":"Menjaga pantang dengan baik","mata":2},{"value":"separa","label":"Pantang tapi tak sepenuhnya","mata":1},{"value":"tidak","label":"Tidak menjaga pantang","mata":0}]',
 '{}', true, 4, true),

('week1','reaksi_pemulihan','Reaksi Pemulihan','Tracking sahaja — tidak dikira dalam skor','pilih_banyak','harian',
 '[{"value":"kerap_kencing","label":"Kerap Kencing"},{"value":"kerap_bab","label":"Kerap Buang Air Besar"},{"value":"gatal","label":"Gatal"},{"value":"selera","label":"Berubah selera makan"},{"value":"bp_naik","label":"Tekanan darah naik"},{"value":"bp_turun","label":"Tekanan darah turun"},{"value":"haid","label":"Haid banyak"},{"value":"kembung","label":"Perut berangin atau kembung"},{"value":"sakit_kepala","label":"Sakit kepala"},{"value":"resdung","label":"Resdung"},{"value":"mencucuk","label":"Rasa sakit mencucuk"},{"value":"radang","label":"Radang, bengkak, kebas, sakit urat"},{"value":"sakit_dada","label":"Sakit dada atau susah bernafas"},{"value":"demam","label":"Demam"},{"value":"lemah","label":"Lemah"},{"value":"mengantuk","label":"Mengantuk"},{"value":"batuk","label":"Batuk atau berkahak"},{"value":"tiada","label":"Tiada"}]',
 '{}', false, 5, true),

('week1','pernafasan_fitrah','Pernafasan Fitrah 30 Minit',NULL,'pilih_satu','harian',
 '[{"value":"cukup_30","label":"Cukup 30 minit","mata":2},{"value":"10_20","label":"10-20 minit","mata":1},{"value":"bawah_10","label":"Kurang dari 10 minit","mata":0}]',
 '{}', true, 3, false),

('week1','terapi_bumi','Terapi Bumi',NULL,'pilih_satu','harian',
 '[{"value":"20_30","label":"20-30 minit","mata":2},{"value":"10_20","label":"10-20 minit","mata":1},{"value":"tidak","label":"Tidak buat","mata":0}]',
 '{}', true, 5, false),

('week1','berjemur','Berjemur Matahari',NULL,'pilih_satu','harian',
 '[{"value":"20_30","label":"20-30 minit","mata":2},{"value":"10_20","label":"10-20 minit","mata":1},{"value":"tidak","label":"Tidak buat","mata":0},{"value":"other","label":"Other","mata":1}]',
 '{}', true, 6, false),

('week1','air_kelapa','Air Kelapa',NULL,'pilih_satu','harian',
 '[{"value":"minum","label":"Minum","mata":2},{"value":"tidak","label":"Tidak minum","mata":0}]',
 '{}', true, 7, false),

('week1','yogurt','Yogurt',NULL,'pilih_satu','harian',
 '[{"value":"ambil","label":"Ambil","mata":2},{"value":"tidak","label":"Tidak ambil","mata":0}]',
 '{}', true, 8, false)

ON CONFLICT (fasa, item_key) DO UPDATE SET
  label       = EXCLUDED.label,
  nota        = EXCLUDED.nota,
  jenis_input = EXCLUDED.jenis_input,
  period      = EXCLUDED.period,
  options     = EXCLUDED.options,
  meta        = EXCLUDED.meta,
  berskor     = EXCLUDED.berskor,
  urutan      = EXCLUDED.urutan,
  aktif       = EXCLUDED.aktif,
  updated_at  = now();
