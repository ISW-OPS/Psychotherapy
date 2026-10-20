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
  boleh_pilih_teruk BOOLEAN NOT NULL DEFAULT true,  -- pesakit pilih Biasa/Teruk (Teruk→Merah terus); false = ikut tahap_risiko tetap
  markah_risiko    INT     NOT NULL DEFAULT 5,
  penerangan       TEXT,
  contoh           JSONB   NOT NULL DEFAULT '[]',
  perlu_pemantauan BOOLEAN NOT NULL DEFAULT false,
  tunjuk_ringkasan BOOLEAN NOT NULL DEFAULT true,
  notifikasi_coach BOOLEAN NOT NULL DEFAULT false,
  is_emergency     BOOLEAN NOT NULL DEFAULT false,
  -- Ditambah 7 Okt 2026 (audit management #B2-111) — status semakan, sama pola
  -- dgn psy_reaksi_actions.status. DEFAULT 'active' supaya rekod sedia ada tak
  -- terjejas; kod baharu (borang Tambah Reaksi) set 'draft' secara eksplisit.
  status           TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('draft','reviewed','approved','active')),
  -- Ditambah 8 Okt 2026 — simptom yang boleh berlaku sebelah (kiri/kanan),
  -- cth Kejang/Kebas/Sakit lutut/Sakit bahu. Pesakit pilih bila card ditanda;
  -- false = tiada sub-pilihan sisi langsung.
  boleh_pilih_lokasi BOOLEAN NOT NULL DEFAULT false,
  -- Ditambah 8 Okt 2026 — simptom yang juga boleh ditentukan ikut anggota
  -- (tangan/kaki), cth Kejang/Kebas. Hanya relevan bila boleh_pilih_lokasi=true.
  boleh_pilih_anggota BOOLEAN NOT NULL DEFAULT false,
  created_at       TIMESTAMPTZ DEFAULT now(),
  updated_at       TIMESTAMPTZ DEFAULT now(),
  CONSTRAINT chk_reaksi_item_tahap CHECK (tahap_risiko IN ('rendah','sederhana','tinggi')),
  -- Biasa/Teruk WAJIB ada pada semua reaksi (20 Okt 2026, arahan management) —
  -- kunci di DB supaya tiada laluan (termasuk SQL/import terus) boleh set false.
  CONSTRAINT chk_reaksi_item_pilih_teruk_wajib CHECK (boleh_pilih_teruk = true)
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
COMMENT ON COLUMN psy_reaksi_item.boleh_pilih_teruk IS 'WAJIB true pada semua baris (CHECK constraint, 20 Okt 2026) — pesakit sentiasa tanda Biasa/Teruk di Catatan Harian (Teruk→Merah terus, apa-apa tahap_risiko pun). Kolum dikekalkan (bukan dibuang) supaya kod baca sedia ada (!== false) terus berfungsi.';
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
  -- Ditambah 7 Okt 2026 (audit management #B2-111) — status semakan peringkat
  -- kategori, sama pola dgn psy_reaksi_actions.status.
  status     TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('draft','reviewed','approved','active')),
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
  -- Ditambah 23 Sept 2026 (audit management #B2-3, contraindication) — kata kunci
  -- dipisah koma (cth "diabetes, kencing manis") yang, bila dijumpai dalam
  -- psy_patients.medical_condition pesakit (carian teks, tak sensitif huruf besar),
  -- akan sorok/gantung cadangan ni + papar amaran kat staf/coach dari terus hantar
  -- kat pesakit. Pilihan (NULL/kosong = tiada sekatan diketahui).
  contraindication_keywords TEXT,
  -- Ditambah 23 Sept 2026 (audit management #B2-39/#B2-45) — status semakan.
  -- DEFAULT DB ialah 'active' (kekalkan tingkah laku sedia ada utk rekod sedia
  -- ada/laluan insert lain yg tak eksplisit set), TAPI kod baharu (import, tindakan
  -- baharu di drawer) set 'draft' secara eksplisit supaya kandungan baharu tak terus
  -- pengaruh cadangan pesakit sebelum staf semak. Cuma tindakan status='active' yang
  -- digunakan utk jana cadangan — lihat filter di roles/patient/kepatuhan.html.
  status       TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('draft','reviewed','approved','active')),
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

-- ──── psy_reaksi_conflict_pairs — pasangan tindakan yang BERCANGGAH (audit #118) ────
-- Staf tetapkan sendiri pasangan tindakan yang bercanggah bila tercadang serentak
-- (cth "Tambah air" vs "Kurangkan air") — sistem TIDAK cuba teka secara automatik
-- berdasarkan makna teks. Diguna generateReaksiAdvice() (roles/patient/kepatuhan.html)
-- utk paksa status='needs_review' bila mana-mana 2 tindakan dlm cadangan sepadan
-- dgn pasangan di sini, dan reaksi-preview.html (UI uji staf) utk papar amaran
-- SEBELUM pesakit submit sebenar. Urus senarai di reaksi-item.html tab Konflik.
CREATE TABLE IF NOT EXISTS psy_reaksi_conflict_pairs (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  action_id_1 UUID NOT NULL REFERENCES psy_reaksi_actions(id) ON DELETE CASCADE,
  action_id_2 UUID NOT NULL REFERENCES psy_reaksi_actions(id) ON DELETE CASCADE,
  note        TEXT,                                   -- sebab bercanggah (pilihan)
  created_by  UUID REFERENCES psy_profiles(id),
  created_at  TIMESTAMPTZ DEFAULT now(),
  CONSTRAINT chk_reaksi_conflict_pair_distinct CHECK (action_id_1 <> action_id_2)
);

-- Elak pasangan duplicate tak kira arah (A,B) sama dgn (B,A) — LEAST/GREATEST
-- supaya index tak kira susunan 2 tindakan diisi dalam borang.
CREATE UNIQUE INDEX IF NOT EXISTS uq_reaksi_conflict_pair
  ON psy_reaksi_conflict_pairs (LEAST(action_id_1, action_id_2), GREATEST(action_id_1, action_id_2));

ALTER TABLE psy_reaksi_conflict_pairs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff manage reaksi conflict pairs" ON psy_reaksi_conflict_pairs;
CREATE POLICY "Staff manage reaksi conflict pairs" ON psy_reaksi_conflict_pairs FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "Authenticated read reaksi conflict pairs" ON psy_reaksi_conflict_pairs;
CREATE POLICY "Authenticated read reaksi conflict pairs" ON psy_reaksi_conflict_pairs FOR SELECT
  USING (auth.uid() IS NOT NULL);

COMMENT ON COLUMN psy_reaksi_conflict_pairs.note IS 'Sebab bercanggah — dipaparkan kpd staf, pilihan';

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
  -- 'needs_review' ditambah 23 Sept 2026 (audit management #B2-2, conflict-check) —
  -- bila 1 submission Catatan Harian cetuskan >1 reaksi serentak, baris digantung
  -- di status ni (cron reaksi-advice-send HANYA proses status='draft' — lihat
  -- supabase/functions/reaksi-advice-send/index.ts, jadi 'needs_review' auto tak
  -- terhantar) sehingga staff Lulus (→'draft') atau Skip (→'skipped') di
  -- reaksi-laporan.html. Guna kolum reviewed_by/reviewed_at sedia ada.
  status           TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','sent','skipped','needs_review')),
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

-- Simptom yang pesakit tanda "Teruk" (format sama dgn symptoms: "Kumpulan::Label").
-- Dibaca oleh trg_reaksi_compute_zon utk kira zon di server, bukan pelayar pesakit.
ALTER TABLE psy_reaksi_advice_log ADD COLUMN IF NOT EXISTS teruk_labels JSONB NOT NULL DEFAULT '[]';

-- Pasangan tindakan bercanggah (audit #118) yg dikesan semasa generateReaksiAdvice()
-- — array of {action_id_1, title_1, action_id_2, title_2}. Diguna reaksi-laporan.html
-- papar SEBAB khusus di kad "Perlu Disemak" (bukan setakat "≥2 simptom" generik).
ALTER TABLE psy_reaksi_advice_log ADD COLUMN IF NOT EXISTS conflict_pairs JSONB NOT NULL DEFAULT '[]';

CREATE INDEX IF NOT EXISTS idx_reaksi_advice_log_status ON psy_reaksi_advice_log(status, created_at);
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
  -- 2. Jantung (dulu "Peredaran Darah", ditukar 1 Okt 2026 atas permintaan staf)
  ('Jantung','❤️','Tekanan darah tinggi',130),
  ('Jantung','❤️','Tekanan darah rendah',140),
  ('Jantung','❤️','Berdebar-debar',150),
  ('Jantung','❤️','Tiada simptom',160),
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

-- ──── Tambah simptom baharu (8 Okt 2026): Pencernaan — Najis berdarah, Buasir, Buasir dah pulih ────
-- Guard per-baris (bukan "jadual kosong") supaya jalan selamat pada DB sedia ada.
INSERT INTO psy_reaksi_item (kumpulan, ikon, label, urutan)
SELECT 'Pencernaan', '', v.label, v.urutan
FROM (VALUES
  ('Najis berdarah', 111),
  ('Buasir', 112),
  ('Buasir dah pulih', 113)
) AS v(label, urutan)
WHERE NOT EXISTS (
  SELECT 1 FROM psy_reaksi_item WHERE kumpulan = 'Pencernaan' AND label = v.label
);

-- ──── Otot & Saraf (8 Okt 2026): Kejang & Kebas dapat sub-pilihan sisi + anggota ────
-- (bukan item berasingan — ditarik balik, gantikan dgn boleh_pilih_lokasi di atas)
UPDATE psy_reaksi_item SET boleh_pilih_lokasi = true, boleh_pilih_anggota = true
WHERE kumpulan = 'Otot & Saraf' AND label IN ('Kejang','Kebas');

-- ──── Otot & Saraf (8 Okt 2026): tambah Sakit lutut, Sakit bahu — sisi sahaja ────
INSERT INTO psy_reaksi_item (kumpulan, ikon, label, urutan, boleh_pilih_lokasi)
SELECT 'Otot & Saraf', '', v.label, v.urutan, true
FROM (VALUES
  ('Sakit lutut', 245),
  ('Sakit bahu', 246)
) AS v(label, urutan)
WHERE NOT EXISTS (
  SELECT 1 FROM psy_reaksi_item WHERE kumpulan = 'Otot & Saraf' AND label = v.label
);

-- ──── Kumpulan baharu (8 Okt 2026): 8. Wanita ────
INSERT INTO psy_reaksi_item (kumpulan, ikon, label, urutan)
SELECT 'Wanita', '🌸', v.label, v.urutan
FROM (VALUES
  ('Keputihan (discharge)', 560),
  ('Period lambat datang', 570),
  ('Tempoh haid lama', 580),
  ('Keluar ketulan darah', 590),
  ('Keluar nanah di payudara', 600),
  ('Keluar lendir/darah/air di payudara', 610),
  ('Senggugut', 620),
  ('Keluar darah selepas menopaus', 630),
  ('Tiada simptom', 640)
) AS v(label, urutan)
WHERE NOT EXISTS (
  SELECT 1 FROM psy_reaksi_item WHERE kumpulan = 'Wanita' AND label = v.label
);

-- ──── Pernafasan (8 Okt 2026): kekal Sesak nafas/Batuk, tambah Semput/Tercungap-cungap,
-- buang Kahak/Mukus/Hidung berair/Bersin + item staf tambah (Radang Paru-paru) ────
INSERT INTO psy_reaksi_item (kumpulan, ikon, label, urutan)
SELECT 'Pernafasan', '🫁', v.label, v.urutan
FROM (VALUES
  ('Semput', 445),
  ('Tercungap-cungap', 447)
) AS v(label, urutan)
WHERE NOT EXISTS (
  SELECT 1 FROM psy_reaksi_item WHERE kumpulan = 'Pernafasan' AND label = v.label
);

DELETE FROM psy_reaksi_item
WHERE kumpulan = 'Pernafasan'
  AND label NOT IN ('Sesak nafas','Batuk','Semput','Tercungap-cungap','Tiada simptom');

-- ──── Emosi & Tenaga (8 Okt 2026): buang "Kurang tenaga" ────
DELETE FROM psy_reaksi_item
WHERE kumpulan = 'Emosi & Tenaga' AND label = 'Kurang tenaga';

-- ──── Bengkak & Cecair (8 Okt 2026): tambah "Keradangan", buang "Edema" ────
INSERT INTO psy_reaksi_item (kumpulan, ikon, label, urutan)
SELECT 'Bengkak & Cecair', '💧', 'Keradangan', 535
WHERE NOT EXISTS (
  SELECT 1 FROM psy_reaksi_item WHERE kumpulan = 'Bengkak & Cecair' AND label = 'Keradangan'
);

DELETE FROM psy_reaksi_item
WHERE kumpulan = 'Bengkak & Cecair' AND label = 'Edema';

-- ──── Seed psy_reaksi_kategori — dijana dari kumpulan psy_reaksi_item ────
INSERT INTO psy_reaksi_kategori (nama, ikon, urutan)
SELECT kumpulan, MAX(COALESCE(ikon, '')), MIN(COALESCE(urutan, 100))
FROM psy_reaksi_item GROUP BY kumpulan
ON CONFLICT (nama) DO NOTHING;

-- ──── Seed contoh psy_reaksi_actions + pemetaan (Pencernaan + Jantung) ────
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
  SELECT id INTO s_berdebar FROM psy_reaksi_item WHERE kumpulan='Jantung' AND label='Berdebar-debar' LIMIT 1;

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

-- ════════════════════════════════════════════════════════════════
-- Reaksi Pemulihan — taksonomi 9 kumpulan penuh (ikut jadual reference
-- client, 20 Okt 2026). REPLACE 100%: item sedia ada yang padan DINAMA
-- SEMULA (ID + mapping tindakan psy_reaksi_action_map dikekalkan), item
-- yang TIADA dalam jadual reference DIBUANG terus (arahan eksplisit user
-- — "yang takde dalam gambar tu dan ada dalam sistem kira buang"), item
-- baharu DITAMBAH. Kumpulan baharu: Sistem kencing & saluran urinari
-- (tiada padanan lama langsung).
--
-- Pemetaan kumpulan lama → baharu:
--   Pencernaan                 → Pencernaan (nama kekal, item diselaraskan)
--   Jantung                    → Jantung & Peredaran darah
--   Otot & Saraf                → Otot, sendi & saraf
--   Detoksifikasi               → Kulit & Perubahan badan
--   Emosi & Tenaga               → Emosi, tidur & tenaga
--   Pernafasan                  → Sistem pernafasan
--   Bengkak & Cecair              → Bengkak & perubahan cecair
--   Wanita                      → Kesihatan wanita
--   (tiada)                     → Sistem kencing & saluran urinari (BAHARU)
--
-- Nota: tahap_risiko/markah_risiko/boleh_pilih_teruk/is_emergency item
-- BAHARU kekal nilai default (rendah) — staff perlu tetapkan sendiri
-- tahap risiko (terutama item berkaitan darah: Najis Berdarah, Batuk
-- berdarah, Kencing berdarah, Pendarahan selepas menopaus, dll) di
-- reaksi-item.html selepas migration ni jalan.
-- ════════════════════════════════════════════════════════════════

-- ──── FASA A: Nama semula label (kekal ID + mapping tindakan) ────
UPDATE psy_reaksi_item SET label='Perut Kembung' WHERE kumpulan='Pencernaan' AND label='Kembung perut';
UPDATE psy_reaksi_item SET label='Banyak angin (kentut)' WHERE kumpulan='Pencernaan' AND label='Banyak angin';
UPDATE psy_reaksi_item SET label='Kerap sendawa' WHERE kumpulan='Pencernaan' AND label='Banyak sendawa';
UPDATE psy_reaksi_item SET label='Kerap buang air besar' WHERE kumpulan='Pencernaan' AND label='Banyak membuang air besar';
UPDATE psy_reaksi_item SET label='Cirit birit' WHERE kumpulan='Pencernaan' AND label='Cirit-birit';
UPDATE psy_reaksi_item SET label='Tiada masalah' WHERE kumpulan='Pencernaan' AND label='Tiada simptom';
UPDATE psy_reaksi_item SET label='Najis Berdarah' WHERE kumpulan='Pencernaan' AND label='Najis berdarah';
UPDATE psy_reaksi_item SET label='Buasir semakin pulih' WHERE kumpulan='Pencernaan' AND label='Buasir dah pulih';

UPDATE psy_reaksi_item SET label='Jantung berdebar-debar' WHERE kumpulan='Jantung' AND label='Berdebar-debar';
UPDATE psy_reaksi_item SET label='Tiada Masalah' WHERE kumpulan='Jantung' AND label='Tiada simptom';

UPDATE psy_reaksi_item SET label='Kejang otot' WHERE kumpulan='Otot & Saraf' AND label='Kejang';
UPDATE psy_reaksi_item SET label='Tiada Masalah' WHERE kumpulan='Otot & Saraf' AND label='Tiada simptom';

UPDATE psy_reaksi_item SET label='Jerawat muncul' WHERE kumpulan='Detoksifikasi' AND label='Jerawat keluar';
UPDATE psy_reaksi_item SET label='Ruam muncul' WHERE kumpulan='Detoksifikasi' AND label='Ruam';
UPDATE psy_reaksi_item SET label='Badan terasa panas' WHERE kumpulan='Detoksifikasi' AND label='Badan panas';
UPDATE psy_reaksi_item SET label='Badan terasa sejuk' WHERE kumpulan='Detoksifikasi' AND label='Badan sejuk';
UPDATE psy_reaksi_item SET label='Tiada Masalah' WHERE kumpulan='Detoksifikasi' AND label='Tiada simptom';

UPDATE psy_reaksi_item SET label='Susah tidur' WHERE kumpulan='Emosi & Tenaga' AND label='Susah nak tidur (insomnia)';
UPDATE psy_reaksi_item SET label='Mudah sebak/menangis' WHERE kumpulan='Emosi & Tenaga' AND label='Mudah sebak';
UPDATE psy_reaksi_item SET label='Tiada masalah' WHERE kumpulan='Emosi & Tenaga' AND label='Tiada simptom';

UPDATE psy_reaksi_item SET label='Semput/nafas berbunyi' WHERE kumpulan='Pernafasan' AND label='Semput';
UPDATE psy_reaksi_item SET label='Tiada masalah' WHERE kumpulan='Pernafasan' AND label='Tiada simptom';

UPDATE psy_reaksi_item SET label='Kawasan badan merah, panas atau bengkak' WHERE kumpulan='Bengkak & Cecair' AND label='Keradangan';
UPDATE psy_reaksi_item SET label='Tiada masalah' WHERE kumpulan='Bengkak & Cecair' AND label='Tiada simptom';

UPDATE psy_reaksi_item SET label='Keputihan' WHERE kumpulan='Wanita' AND label='Keputihan (discharge)';
UPDATE psy_reaksi_item SET label='Haid lewat datang' WHERE kumpulan='Wanita' AND label='Period lambat datang';
UPDATE psy_reaksi_item SET label='Haid lebih lama dari biasa' WHERE kumpulan='Wanita' AND label='Tempoh haid lama';
UPDATE psy_reaksi_item SET label='Keluar ketulan darah ketika haid' WHERE kumpulan='Wanita' AND label='Keluar ketulan darah';
UPDATE psy_reaksi_item SET label='Keluar cecair dari puting payudara' WHERE kumpulan='Wanita' AND label='Keluar lendir/darah/air di payudara';
UPDATE psy_reaksi_item SET label='Pendarahan selepas menopaus' WHERE kumpulan='Wanita' AND label='Keluar darah selepas menopaus';
UPDATE psy_reaksi_item SET label='Tiada Masalah' WHERE kumpulan='Wanita' AND label='Tiada simptom';

-- ──── FASA B: Buang item yang TIADA dalam jadual reference ────
DELETE FROM psy_reaksi_item WHERE kumpulan='Pencernaan' AND label NOT IN (
  'Perut Kembung','Banyak angin (kentut)','Kerap sendawa','Sakit perut','Sakit bahagian kanan atas perut',
  'Batu hempedu','Hilang selera makan','Kerap buang air besar','Loya','Muntah','Sembelit','Cirit birit',
  'Najis hitam','Najis Berdarah','Buasir semakin pulih','Lendir keluar bersama najis','Pedih ulu hati','Buasir','Tiada masalah');

DELETE FROM psy_reaksi_item WHERE kumpulan='Jantung' AND label NOT IN (
  'Tekanan darah tinggi','Tekanan darah rendah','Jantung berdebar-debar','Sakit dada',
  'Pening/hampir pengsan','Pengsan','Denyutan jantung tidak teratur','Tiada Masalah');

DELETE FROM psy_reaksi_item WHERE kumpulan='Otot & Saraf' AND label NOT IN (
  'Sakit badan','Sakit sendi','Sakit otot','Sakit belikat','Sakit tengkuk','Sakit pinggang','Sakit belakang',
  'Kejang otot','Kebas','Sakit lutut','Sakit bahu','Rasa mencucuk-cucuk','Lemah anggota badan','Tiada Masalah');

DELETE FROM psy_reaksi_item WHERE kumpulan='Detoksifikasi' AND label NOT IN (
  'Gatal-gatal','Jerawat muncul','Ruam muncul','Kulit mengelupas','Kulit menjadi lebih sensitif',
  'Kulit kemerahan','Kulit kering','Badan terasa panas','Badan terasa sejuk','Tiada Masalah');

DELETE FROM psy_reaksi_item WHERE kumpulan='Emosi & Tenaga' AND label NOT IN (
  'Susah tidur','Mengantuk luar biasa','Cepat letih','Lemah badan','Mudah sebak/menangis','Gelisah',
  'Badan terasa berat','Mudah marah','Sukar fokus','Tidur lebih baik','Tenaga bertambah baik','Emosi lebih stabil','Tiada masalah');

DELETE FROM psy_reaksi_item WHERE kumpulan='Pernafasan' AND label NOT IN (
  'Hidung berair/banyak hingus','Hidung tersumbat','Batuk','Batuk berkahak','Batuk berdarah',
  'Sesak nafas','Semput/nafas berbunyi','Tercungap-cungap','Tiada masalah');

DELETE FROM psy_reaksi_item WHERE kumpulan='Bengkak & Cecair' AND label NOT IN (
  'Bengkak kaki','Bengkak tangan','Bengkak muka','Bengkak sekitar mata','Perut membengkak',
  'Kawasan badan merah, panas atau bengkak','Bengkak semakin berkurang','Tiada masalah');

DELETE FROM psy_reaksi_item WHERE kumpulan='Wanita' AND label NOT IN (
  'Keputihan','Haid lewat datang','Haid lebih lama dari biasa','Keluar ketulan darah ketika haid',
  'Keluar cecair dari puting payudara','Keluar darah dari puting payudara','Senggugut',
  'Pendarahan selepas menopaus','Darah haid terlalu banyak','Tiada Masalah');

-- ──── FASA C: Nama semula kumpulan (kategori) ────
UPDATE psy_reaksi_item SET kumpulan='Jantung & Peredaran darah' WHERE kumpulan='Jantung';
UPDATE psy_reaksi_item SET kumpulan='Otot, sendi & saraf' WHERE kumpulan='Otot & Saraf';
UPDATE psy_reaksi_item SET kumpulan='Kulit & Perubahan badan' WHERE kumpulan='Detoksifikasi';
UPDATE psy_reaksi_item SET kumpulan='Emosi, tidur & tenaga' WHERE kumpulan='Emosi & Tenaga';
UPDATE psy_reaksi_item SET kumpulan='Sistem pernafasan' WHERE kumpulan='Pernafasan';
UPDATE psy_reaksi_item SET kumpulan='Bengkak & perubahan cecair' WHERE kumpulan='Bengkak & Cecair';
UPDATE psy_reaksi_item SET kumpulan='Kesihatan wanita' WHERE kumpulan='Wanita';

-- ──── FASA D: Tambah item baharu + selaras urutan/ikon SEMUA item (sedia ada + baharu) ────
-- Nota: SENGAJA guna WITH...AS(VALUES...) inline (bukan TEMP TABLE) — sesetengah
-- runner SQL (cth Supabase SQL editor/MCP) laksana setiap statement pada sambungan
-- berasingan, jadi TEMP TABLE hilang antara statement ("relation does not exist").
-- Senarai sama diulang 2x (INSERT + UPDATE) supaya setiap statement berdiri sendiri.
INSERT INTO psy_reaksi_item (kumpulan, ikon, label, urutan)
SELECT t.kumpulan, t.ikon, t.label, t.urutan FROM (VALUES
  ('Pencernaan','Perut Kembung',10,'🍽️'),
  ('Pencernaan','Banyak angin (kentut)',20,'🍽️'),
  ('Pencernaan','Kerap sendawa',30,'🍽️'),
  ('Pencernaan','Sakit perut',40,'🍽️'),
  ('Pencernaan','Sakit bahagian kanan atas perut',50,'🍽️'),
  ('Pencernaan','Batu hempedu',60,'🍽️'),
  ('Pencernaan','Hilang selera makan',70,'🍽️'),
  ('Pencernaan','Kerap buang air besar',80,'🍽️'),
  ('Pencernaan','Loya',90,'🍽️'),
  ('Pencernaan','Muntah',100,'🍽️'),
  ('Pencernaan','Sembelit',110,'🍽️'),
  ('Pencernaan','Cirit birit',120,'🍽️'),
  ('Pencernaan','Najis hitam',130,'🍽️'),
  ('Pencernaan','Najis Berdarah',140,'🍽️'),
  ('Pencernaan','Buasir semakin pulih',150,'🍽️'),
  ('Pencernaan','Lendir keluar bersama najis',160,'🍽️'),
  ('Pencernaan','Pedih ulu hati',170,'🍽️'),
  ('Pencernaan','Buasir',180,'🍽️'),
  ('Pencernaan','Tiada masalah',190,'🍽️'),

  ('Jantung & Peredaran darah','Tekanan darah tinggi',1010,'❤️'),
  ('Jantung & Peredaran darah','Tekanan darah rendah',1020,'❤️'),
  ('Jantung & Peredaran darah','Jantung berdebar-debar',1030,'❤️'),
  ('Jantung & Peredaran darah','Sakit dada',1040,'❤️'),
  ('Jantung & Peredaran darah','Pening/hampir pengsan',1050,'❤️'),
  ('Jantung & Peredaran darah','Pengsan',1060,'❤️'),
  ('Jantung & Peredaran darah','Denyutan jantung tidak teratur',1070,'❤️'),
  ('Jantung & Peredaran darah','Tiada Masalah',1080,'❤️'),

  ('Otot, sendi & saraf','Sakit badan',2010,'💪'),
  ('Otot, sendi & saraf','Sakit sendi',2020,'💪'),
  ('Otot, sendi & saraf','Sakit otot',2030,'💪'),
  ('Otot, sendi & saraf','Sakit belikat',2040,'💪'),
  ('Otot, sendi & saraf','Sakit tengkuk',2050,'💪'),
  ('Otot, sendi & saraf','Sakit pinggang',2060,'💪'),
  ('Otot, sendi & saraf','Sakit belakang',2070,'💪'),
  ('Otot, sendi & saraf','Kejang otot',2080,'💪'),
  ('Otot, sendi & saraf','Kebas',2090,'💪'),
  ('Otot, sendi & saraf','Sakit lutut',2100,'💪'),
  ('Otot, sendi & saraf','Sakit bahu',2110,'💪'),
  ('Otot, sendi & saraf','Rasa mencucuk-cucuk',2120,'💪'),
  ('Otot, sendi & saraf','Lemah anggota badan',2130,'💪'),
  ('Otot, sendi & saraf','Tiada Masalah',2140,'💪'),

  ('Kulit & Perubahan badan','Gatal-gatal',3010,'🧴'),
  ('Kulit & Perubahan badan','Jerawat muncul',3020,'🧴'),
  ('Kulit & Perubahan badan','Ruam muncul',3030,'🧴'),
  ('Kulit & Perubahan badan','Kulit mengelupas',3040,'🧴'),
  ('Kulit & Perubahan badan','Kulit menjadi lebih sensitif',3050,'🧴'),
  ('Kulit & Perubahan badan','Kulit kemerahan',3060,'🧴'),
  ('Kulit & Perubahan badan','Kulit kering',3070,'🧴'),
  ('Kulit & Perubahan badan','Badan terasa panas',3080,'🧴'),
  ('Kulit & Perubahan badan','Badan terasa sejuk',3090,'🧴'),
  ('Kulit & Perubahan badan','Tiada Masalah',3100,'🧴'),

  ('Emosi, tidur & tenaga','Susah tidur',4010,'⚡'),
  ('Emosi, tidur & tenaga','Mengantuk luar biasa',4020,'⚡'),
  ('Emosi, tidur & tenaga','Cepat letih',4030,'⚡'),
  ('Emosi, tidur & tenaga','Lemah badan',4040,'⚡'),
  ('Emosi, tidur & tenaga','Mudah sebak/menangis',4050,'⚡'),
  ('Emosi, tidur & tenaga','Gelisah',4060,'⚡'),
  ('Emosi, tidur & tenaga','Badan terasa berat',4070,'⚡'),
  ('Emosi, tidur & tenaga','Mudah marah',4080,'⚡'),
  ('Emosi, tidur & tenaga','Sukar fokus',4090,'⚡'),
  ('Emosi, tidur & tenaga','Tidur lebih baik',4100,'⚡'),
  ('Emosi, tidur & tenaga','Tenaga bertambah baik',4110,'⚡'),
  ('Emosi, tidur & tenaga','Emosi lebih stabil',4120,'⚡'),
  ('Emosi, tidur & tenaga','Tiada masalah',4130,'⚡'),

  ('Sistem pernafasan','Hidung berair/banyak hingus',5010,'🫁'),
  ('Sistem pernafasan','Hidung tersumbat',5020,'🫁'),
  ('Sistem pernafasan','Batuk',5030,'🫁'),
  ('Sistem pernafasan','Batuk berkahak',5040,'🫁'),
  ('Sistem pernafasan','Batuk berdarah',5050,'🫁'),
  ('Sistem pernafasan','Sesak nafas',5060,'🫁'),
  ('Sistem pernafasan','Semput/nafas berbunyi',5070,'🫁'),
  ('Sistem pernafasan','Tercungap-cungap',5080,'🫁'),
  ('Sistem pernafasan','Tiada masalah',5090,'🫁'),

  ('Bengkak & perubahan cecair','Bengkak kaki',6010,'💧'),
  ('Bengkak & perubahan cecair','Bengkak tangan',6020,'💧'),
  ('Bengkak & perubahan cecair','Bengkak muka',6030,'💧'),
  ('Bengkak & perubahan cecair','Bengkak sekitar mata',6040,'💧'),
  ('Bengkak & perubahan cecair','Perut membengkak',6050,'💧'),
  ('Bengkak & perubahan cecair','Kawasan badan merah, panas atau bengkak',6060,'💧'),
  ('Bengkak & perubahan cecair','Bengkak semakin berkurang',6070,'💧'),
  ('Bengkak & perubahan cecair','Tiada masalah',6080,'💧'),

  ('Kesihatan wanita','Keputihan',7010,'🌸'),
  ('Kesihatan wanita','Haid lewat datang',7020,'🌸'),
  ('Kesihatan wanita','Haid lebih lama dari biasa',7030,'🌸'),
  ('Kesihatan wanita','Keluar ketulan darah ketika haid',7040,'🌸'),
  ('Kesihatan wanita','Keluar cecair dari puting payudara',7050,'🌸'),
  ('Kesihatan wanita','Keluar darah dari puting payudara',7060,'🌸'),
  ('Kesihatan wanita','Senggugut',7070,'🌸'),
  ('Kesihatan wanita','Pendarahan selepas menopaus',7080,'🌸'),
  ('Kesihatan wanita','Darah haid terlalu banyak',7090,'🌸'),
  ('Kesihatan wanita','Tiada Masalah',7100,'🌸'),

  ('Sistem kencing & saluran urinari','Kerap kencing',8010,'🚰'),
  ('Sistem kencing & saluran urinari','Kerap bangun malam untuk kencing',8020,'🚰'),
  ('Sistem kencing & saluran urinari','Sukar kencing',8030,'🚰'),
  ('Sistem kencing & saluran urinari','Kencing tidak lawas',8040,'🚰'),
  ('Sistem kencing & saluran urinari','Kencing berbuih',8050,'🚰'),
  ('Sistem kencing & saluran urinari','Kencing berpasir',8060,'🚰'),
  ('Sistem kencing & saluran urinari','Keluar ketulan seperti batu ketika kencing',8070,'🚰'),
  ('Sistem kencing & saluran urinari','Pedih atau sakit ketika kencing',8080,'🚰'),
  ('Sistem kencing & saluran urinari','Kencing berdarah',8090,'🚰'),
  ('Sistem kencing & saluran urinari','Air kencing keruh',8100,'🚰'),
  ('Sistem kencing & saluran urinari','Air kencing berbau kuat',8110,'🚰'),
  ('Sistem kencing & saluran urinari','Kencing sedikit daripada biasa',8120,'🚰'),
  ('Sistem kencing & saluran urinari','Tidak boleh kencing',8130,'🚰'),
  ('Sistem kencing & saluran urinari','Tidak dapat menahan kencing',8140,'🚰'),
  ('Sistem kencing & saluran urinari','Sakit di bahagian tepi pinggang',8150,'🚰'),
  ('Sistem kencing & saluran urinari','Tiada masalah',8160,'🚰')
) AS t(kumpulan, label, urutan, ikon)
WHERE NOT EXISTS (
  SELECT 1 FROM psy_reaksi_item i WHERE i.kumpulan = t.kumpulan AND i.label = t.label
);

-- Selaraskan urutan + ikon semua item (sedia ada + baharu) ikut susunan jadual reference
UPDATE psy_reaksi_item i SET urutan = t.urutan, ikon = t.ikon
FROM (VALUES
  ('Pencernaan','Perut Kembung',10,'🍽️'),
  ('Pencernaan','Banyak angin (kentut)',20,'🍽️'),
  ('Pencernaan','Kerap sendawa',30,'🍽️'),
  ('Pencernaan','Sakit perut',40,'🍽️'),
  ('Pencernaan','Sakit bahagian kanan atas perut',50,'🍽️'),
  ('Pencernaan','Batu hempedu',60,'🍽️'),
  ('Pencernaan','Hilang selera makan',70,'🍽️'),
  ('Pencernaan','Kerap buang air besar',80,'🍽️'),
  ('Pencernaan','Loya',90,'🍽️'),
  ('Pencernaan','Muntah',100,'🍽️'),
  ('Pencernaan','Sembelit',110,'🍽️'),
  ('Pencernaan','Cirit birit',120,'🍽️'),
  ('Pencernaan','Najis hitam',130,'🍽️'),
  ('Pencernaan','Najis Berdarah',140,'🍽️'),
  ('Pencernaan','Buasir semakin pulih',150,'🍽️'),
  ('Pencernaan','Lendir keluar bersama najis',160,'🍽️'),
  ('Pencernaan','Pedih ulu hati',170,'🍽️'),
  ('Pencernaan','Buasir',180,'🍽️'),
  ('Pencernaan','Tiada masalah',190,'🍽️'),

  ('Jantung & Peredaran darah','Tekanan darah tinggi',1010,'❤️'),
  ('Jantung & Peredaran darah','Tekanan darah rendah',1020,'❤️'),
  ('Jantung & Peredaran darah','Jantung berdebar-debar',1030,'❤️'),
  ('Jantung & Peredaran darah','Sakit dada',1040,'❤️'),
  ('Jantung & Peredaran darah','Pening/hampir pengsan',1050,'❤️'),
  ('Jantung & Peredaran darah','Pengsan',1060,'❤️'),
  ('Jantung & Peredaran darah','Denyutan jantung tidak teratur',1070,'❤️'),
  ('Jantung & Peredaran darah','Tiada Masalah',1080,'❤️'),

  ('Otot, sendi & saraf','Sakit badan',2010,'💪'),
  ('Otot, sendi & saraf','Sakit sendi',2020,'💪'),
  ('Otot, sendi & saraf','Sakit otot',2030,'💪'),
  ('Otot, sendi & saraf','Sakit belikat',2040,'💪'),
  ('Otot, sendi & saraf','Sakit tengkuk',2050,'💪'),
  ('Otot, sendi & saraf','Sakit pinggang',2060,'💪'),
  ('Otot, sendi & saraf','Sakit belakang',2070,'💪'),
  ('Otot, sendi & saraf','Kejang otot',2080,'💪'),
  ('Otot, sendi & saraf','Kebas',2090,'💪'),
  ('Otot, sendi & saraf','Sakit lutut',2100,'💪'),
  ('Otot, sendi & saraf','Sakit bahu',2110,'💪'),
  ('Otot, sendi & saraf','Rasa mencucuk-cucuk',2120,'💪'),
  ('Otot, sendi & saraf','Lemah anggota badan',2130,'💪'),
  ('Otot, sendi & saraf','Tiada Masalah',2140,'💪'),

  ('Kulit & Perubahan badan','Gatal-gatal',3010,'🧴'),
  ('Kulit & Perubahan badan','Jerawat muncul',3020,'🧴'),
  ('Kulit & Perubahan badan','Ruam muncul',3030,'🧴'),
  ('Kulit & Perubahan badan','Kulit mengelupas',3040,'🧴'),
  ('Kulit & Perubahan badan','Kulit menjadi lebih sensitif',3050,'🧴'),
  ('Kulit & Perubahan badan','Kulit kemerahan',3060,'🧴'),
  ('Kulit & Perubahan badan','Kulit kering',3070,'🧴'),
  ('Kulit & Perubahan badan','Badan terasa panas',3080,'🧴'),
  ('Kulit & Perubahan badan','Badan terasa sejuk',3090,'🧴'),
  ('Kulit & Perubahan badan','Tiada Masalah',3100,'🧴'),

  ('Emosi, tidur & tenaga','Susah tidur',4010,'⚡'),
  ('Emosi, tidur & tenaga','Mengantuk luar biasa',4020,'⚡'),
  ('Emosi, tidur & tenaga','Cepat letih',4030,'⚡'),
  ('Emosi, tidur & tenaga','Lemah badan',4040,'⚡'),
  ('Emosi, tidur & tenaga','Mudah sebak/menangis',4050,'⚡'),
  ('Emosi, tidur & tenaga','Gelisah',4060,'⚡'),
  ('Emosi, tidur & tenaga','Badan terasa berat',4070,'⚡'),
  ('Emosi, tidur & tenaga','Mudah marah',4080,'⚡'),
  ('Emosi, tidur & tenaga','Sukar fokus',4090,'⚡'),
  ('Emosi, tidur & tenaga','Tidur lebih baik',4100,'⚡'),
  ('Emosi, tidur & tenaga','Tenaga bertambah baik',4110,'⚡'),
  ('Emosi, tidur & tenaga','Emosi lebih stabil',4120,'⚡'),
  ('Emosi, tidur & tenaga','Tiada masalah',4130,'⚡'),

  ('Sistem pernafasan','Hidung berair/banyak hingus',5010,'🫁'),
  ('Sistem pernafasan','Hidung tersumbat',5020,'🫁'),
  ('Sistem pernafasan','Batuk',5030,'🫁'),
  ('Sistem pernafasan','Batuk berkahak',5040,'🫁'),
  ('Sistem pernafasan','Batuk berdarah',5050,'🫁'),
  ('Sistem pernafasan','Sesak nafas',5060,'🫁'),
  ('Sistem pernafasan','Semput/nafas berbunyi',5070,'🫁'),
  ('Sistem pernafasan','Tercungap-cungap',5080,'🫁'),
  ('Sistem pernafasan','Tiada masalah',5090,'🫁'),

  ('Bengkak & perubahan cecair','Bengkak kaki',6010,'💧'),
  ('Bengkak & perubahan cecair','Bengkak tangan',6020,'💧'),
  ('Bengkak & perubahan cecair','Bengkak muka',6030,'💧'),
  ('Bengkak & perubahan cecair','Bengkak sekitar mata',6040,'💧'),
  ('Bengkak & perubahan cecair','Perut membengkak',6050,'💧'),
  ('Bengkak & perubahan cecair','Kawasan badan merah, panas atau bengkak',6060,'💧'),
  ('Bengkak & perubahan cecair','Bengkak semakin berkurang',6070,'💧'),
  ('Bengkak & perubahan cecair','Tiada masalah',6080,'💧'),

  ('Kesihatan wanita','Keputihan',7010,'🌸'),
  ('Kesihatan wanita','Haid lewat datang',7020,'🌸'),
  ('Kesihatan wanita','Haid lebih lama dari biasa',7030,'🌸'),
  ('Kesihatan wanita','Keluar ketulan darah ketika haid',7040,'🌸'),
  ('Kesihatan wanita','Keluar cecair dari puting payudara',7050,'🌸'),
  ('Kesihatan wanita','Keluar darah dari puting payudara',7060,'🌸'),
  ('Kesihatan wanita','Senggugut',7070,'🌸'),
  ('Kesihatan wanita','Pendarahan selepas menopaus',7080,'🌸'),
  ('Kesihatan wanita','Darah haid terlalu banyak',7090,'🌸'),
  ('Kesihatan wanita','Tiada Masalah',7100,'🌸'),

  ('Sistem kencing & saluran urinari','Kerap kencing',8010,'🚰'),
  ('Sistem kencing & saluran urinari','Kerap bangun malam untuk kencing',8020,'🚰'),
  ('Sistem kencing & saluran urinari','Sukar kencing',8030,'🚰'),
  ('Sistem kencing & saluran urinari','Kencing tidak lawas',8040,'🚰'),
  ('Sistem kencing & saluran urinari','Kencing berbuih',8050,'🚰'),
  ('Sistem kencing & saluran urinari','Kencing berpasir',8060,'🚰'),
  ('Sistem kencing & saluran urinari','Keluar ketulan seperti batu ketika kencing',8070,'🚰'),
  ('Sistem kencing & saluran urinari','Pedih atau sakit ketika kencing',8080,'🚰'),
  ('Sistem kencing & saluran urinari','Kencing berdarah',8090,'🚰'),
  ('Sistem kencing & saluran urinari','Air kencing keruh',8100,'🚰'),
  ('Sistem kencing & saluran urinari','Air kencing berbau kuat',8110,'🚰'),
  ('Sistem kencing & saluran urinari','Kencing sedikit daripada biasa',8120,'🚰'),
  ('Sistem kencing & saluran urinari','Tidak boleh kencing',8130,'🚰'),
  ('Sistem kencing & saluran urinari','Tidak dapat menahan kencing',8140,'🚰'),
  ('Sistem kencing & saluran urinari','Sakit di bahagian tepi pinggang',8150,'🚰'),
  ('Sistem kencing & saluran urinari','Tiada masalah',8160,'🚰')
) AS t(kumpulan, label, urutan, ikon)
WHERE i.kumpulan = t.kumpulan AND i.label = t.label;

-- ──── FASA E: Selaras psy_reaksi_kategori (nama kumpulan + kumpulan baharu) ────
UPDATE psy_reaksi_kategori SET nama='Jantung & Peredaran darah' WHERE nama='Jantung';
UPDATE psy_reaksi_kategori SET nama='Otot, sendi & saraf' WHERE nama='Otot & Saraf';
UPDATE psy_reaksi_kategori SET nama='Kulit & Perubahan badan', ikon='🧴' WHERE nama='Detoksifikasi';
UPDATE psy_reaksi_kategori SET nama='Emosi, tidur & tenaga' WHERE nama='Emosi & Tenaga';
UPDATE psy_reaksi_kategori SET nama='Sistem pernafasan' WHERE nama='Pernafasan';
UPDATE psy_reaksi_kategori SET nama='Bengkak & perubahan cecair' WHERE nama='Bengkak & Cecair';
UPDATE psy_reaksi_kategori SET nama='Kesihatan wanita' WHERE nama='Wanita';

INSERT INTO psy_reaksi_kategori (nama, ikon, urutan)
SELECT 'Sistem kencing & saluran urinari', '🚰', 950
WHERE NOT EXISTS (SELECT 1 FROM psy_reaksi_kategori WHERE nama='Sistem kencing & saluran urinari');

-- Kategori yang mungkin belum ada langsung (DB lama belum pernah run seed psy_reaksi_kategori
-- penuh) — jana dari kumpulan psy_reaksi_item terkini sebagai jaring keselamatan.
INSERT INTO psy_reaksi_kategori (nama, ikon, urutan)
SELECT kumpulan, MAX(COALESCE(ikon, '')), MIN(COALESCE(urutan, 100))
FROM psy_reaksi_item GROUP BY kumpulan
ON CONFLICT (nama) DO NOTHING;

-- ════════════════════════════════════════════════════════════════
-- FASA F (20 Okt 2026, susulan) — "Biasa/Teruk wajib ada dekat semua jawapan"
-- (arahan management). Togol "Benarkan pesakit tanda Biasa/Teruk" dibuang drpd
-- borang reaksi-item.html (staff tak boleh matikan lagi); CHECK di DB kunci
-- supaya tiada laluan lain (import/SQL terus) boleh set false pada masa depan.
-- Guard ni perlu utk jadual sedia ada (CREATE TABLE IF NOT EXISTS di atas tak
-- tambah constraint baharu pada jadual yang dah wujud).
-- ════════════════════════════════════════════════════════════════
UPDATE psy_reaksi_item SET boleh_pilih_teruk = true WHERE boleh_pilih_teruk IS DISTINCT FROM true;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_reaksi_item_pilih_teruk_wajib') THEN
    ALTER TABLE psy_reaksi_item ADD CONSTRAINT chk_reaksi_item_pilih_teruk_wajib CHECK (boleh_pilih_teruk = true);
  END IF;
END $$;
