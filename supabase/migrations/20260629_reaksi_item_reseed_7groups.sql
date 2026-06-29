-- ============================================================
-- 20260629_reaksi_item_reseed_7groups.sql
-- Reseed psy_reaksi_item kepada struktur GABUNGAN 7 kumpulan / 48 simptom
-- (+ "Tiada simptom" setiap kumpulan; "Lain-lain" = free-text auto di UI).
-- Sumber tunggal untuk reaksi pemulihan — diguna di checklist harian
-- (patient/kepatuhan.html item 5, grouped) + staff CRUD (kepatuhan.html).
-- Borang reaksi MINGGUAN (plan-week patient & staff) dibuang.
-- ============================================================

DELETE FROM psy_reaksi_item;

INSERT INTO psy_reaksi_item (kumpulan, ikon, label, urutan) VALUES
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
('Bengkak & Cecair','💧','Tiada simptom',550);

SELECT kumpulan, count(*) AS bil FROM psy_reaksi_item GROUP BY kumpulan ORDER BY min(urutan);
