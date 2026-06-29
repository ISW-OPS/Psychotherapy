-- Senarai induk Reaksi Pemulihan — kini boleh diurus dari UI (bukan hardcoded).
-- Coach tanda item ini masa sesi (plan-week.html). Jawapan disimpan di
-- psy_plan_weekly_progress.reaksi_pemulihan sebagai { "<item_id>": true } + lain-lain.

CREATE TABLE IF NOT EXISTS psy_reaksi_item (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  kumpulan    TEXT NOT NULL,                 -- nama kumpulan, cth 'Tenaga & Keletihan'
  ikon        TEXT,                          -- emoji kumpulan, cth '⚡'
  label       TEXT NOT NULL,                 -- simptom, cth 'Susah nak tidur (insomnia)'
  urutan      INT  NOT NULL DEFAULT 0,       -- susunan global (kumpulan + item)
  aktif       BOOLEAN NOT NULL DEFAULT true,
  created_at  TIMESTAMPTZ DEFAULT now(),
  updated_at  TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE psy_reaksi_item ENABLE ROW LEVEL SECURITY;
-- Semua staff boleh urus (tambah/edit/buang) senarai.
DO $$ BEGIN
  CREATE POLICY "Staff manage reaksi item" ON psy_reaksi_item FOR ALL
    USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Seed senarai sedia ada (hanya bila jadual masih kosong).
INSERT INTO psy_reaksi_item (kumpulan, ikon, label, urutan)
SELECT v.kumpulan, v.ikon, v.label, v.urutan
FROM (VALUES
  ('Tenaga & Keletihan','⚡','Susah nak tidur (insomnia)',10),
  ('Tenaga & Keletihan','⚡','Mengantuk luar biasa',20),
  ('Tenaga & Keletihan','⚡','Kurang tenaga',30),
  ('Tenaga & Keletihan','⚡','Cepat letih',40),
  ('Tenaga & Keletihan','⚡','Lemah badan',50),
  ('Sistem Pencernaan','🍽️','Kembung perut',60),
  ('Sistem Pencernaan','🍽️','Banyak angin',70),
  ('Sistem Pencernaan','🍽️','Banyak sendawa',80),
  ('Sistem Pencernaan','🍽️','Sakit perut',90),
  ('Sistem Pencernaan','🍽️','Loya',100),
  ('Sistem Pencernaan','🍽️','Muntah',110),
  ('Sistem Pencernaan','🍽️','Hilang selera makan',120),
  ('Sistem Pencernaan','🍽️','Banyak membuang air besar',130),
  ('Sistem Pencernaan','🍽️','Cirit-birit',140),
  ('Sistem Pencernaan','🍽️','Sembelit',150),
  ('Sistem Pernafasan','🫁','Batuk',160),
  ('Sistem Pernafasan','🫁','Kahak keluar',170),
  ('Sistem Pernafasan','🫁','Mukus keluar',180),
  ('Sistem Pernafasan','🫁','Hidung berair',190),
  ('Sistem Pernafasan','🫁','Bersin',200),
  ('Kulit','🧴','Jerawat keluar',210),
  ('Kulit','🧴','Gatal-gatal',220),
  ('Kulit','🧴','Ruam',230),
  ('Kulit','🧴','Kulit mengelupas',240),
  ('Kulit','🧴','Kulit menjadi lebih sensitif',250),
  ('Otot & Sendi','💪','Sakit badan',260),
  ('Otot & Sendi','💪','Sakit sendi',270),
  ('Otot & Sendi','💪','Sakit otot',280),
  ('Otot & Sendi','💪','Sakit pinggang',290),
  ('Otot & Sendi','💪','Sakit tengkuk',300),
  ('Otot & Sendi','💪','Sakit belikat',310),
  ('Otot & Sendi','💪','Kejang',320),
  ('Otot & Sendi','💪','Kebas',330),
  ('Otot & Sendi','💪','Badan terasa berat',340),
  ('Bengkak & Cecair','💧','Bengkak kaki',350),
  ('Bengkak & Cecair','💧','Bengkak tangan',360),
  ('Bengkak & Cecair','💧','Bengkak muka',370),
  ('Bengkak & Cecair','💧','Edema',380)
) AS v(kumpulan, ikon, label, urutan)
WHERE NOT EXISTS (SELECT 1 FROM psy_reaksi_item);
