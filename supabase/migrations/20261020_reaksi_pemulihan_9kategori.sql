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
-- ════════════════════════════════════════════════════════════════
UPDATE psy_reaksi_item SET boleh_pilih_teruk = true WHERE boleh_pilih_teruk IS DISTINCT FROM true;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_reaksi_item_pilih_teruk_wajib') THEN
    ALTER TABLE psy_reaksi_item ADD CONSTRAINT chk_reaksi_item_pilih_teruk_wajib CHECK (boleh_pilih_teruk = true);
  END IF;
END $$;

-- ════════════════════════════════════════════════════════════════
-- FASA G (20 Okt 2026, susulan #2) — Kunci Harga di KOB. Staff klik "Kunci
-- Harga" di Langkah 3 (kob-detail.html) supaya harga Now/Today bayaran sesi
-- KOB ni TAK berubah lagi walaupun harga pakej diedit kemudian di pakej-edit.html.
-- locked_price_amount snapshot harga sebenar masa dikunci. NULL = belum dikunci
-- (default — tak jejas sesi KOB sedia ada langsung).
-- ════════════════════════════════════════════════════════════════
ALTER TABLE psy_kob_sessions ADD COLUMN IF NOT EXISTS locked_price_tier TEXT;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'psy_kob_sessions_locked_price_tier_check') THEN
    ALTER TABLE psy_kob_sessions ADD CONSTRAINT psy_kob_sessions_locked_price_tier_check CHECK (locked_price_tier IN ('now','today'));
  END IF;
END $$;
ALTER TABLE psy_kob_sessions ADD COLUMN IF NOT EXISTS locked_price_amount NUMERIC(12,2);
ALTER TABLE psy_kob_sessions ADD COLUMN IF NOT EXISTS locked_at TIMESTAMPTZ;
ALTER TABLE psy_kob_sessions ADD COLUMN IF NOT EXISTS locked_by UUID REFERENCES psy_profiles(id) ON DELETE SET NULL;
ALTER TABLE psy_kob_sessions ADD COLUMN IF NOT EXISTS locked_by_name TEXT;

COMMENT ON COLUMN psy_kob_sessions.locked_price_tier IS
  'Staff-locked price tier (now/today) for this KOB payment, set via "Kunci Harga" button in
   kob-detail.html Langkah 3. When set, overrides wizPayTier in UI + payments-kob-initiate tier
   param, and keeps working even if the package price changes afterwards (snapshot in
   locked_price_amount). NULL = not locked, staff can still freely switch tiers.';

-- ════════════════════════════════════════════════════════════════
-- FASA H (20 Okt 2026, susulan #3) — BAIKI rujukan item_id "YATIM" di Bekalan Pakej.
--
-- PUNCA: database/schema/14_products_inventory.sql ada "DELETE FROM psy_inventory_items;"
-- tanpa skop, diikuti INSERT ~35 item hardcode TANPA id tetap (gen_random_uuid() lalai).
-- Setiap kali schema/master_migration ni di-run, SEMUA item Inventori sedia ada dipadam
-- & diganti SEMULA dgn UUID RAWAK baharu — memecahkan SEMUA rujukan item_id yg disimpan
-- sbg snapshot di psy_treatment_plans.coaching_schedule, psy_packages.coaching_schedule,
-- psy_plan_week_overrides.supplies_override & psy_procedure_kits.items. Disahkan 20 Okt
-- 2026 via Supabase MCP: 100% (45/45) rujukan item_id unik dlm sistem jadi yatim — tiada
-- pergerakan stok "out" PERNAH berjaya utk Bekalan Pakej sejak awal. Punca dah dibetulkan
-- (14_products_inventory.sql kini idempoten, TAK PERNAH padam baris sedia ada lagi — lihat
-- [[project_inventory_seed_destructive_delete]]) — FASA ni BAIKI DATA sedia ada.
--
-- PENDEKATAN: (1) cipta 17 item Inventori baharu utk produk yg langsung tiada padanan
-- sekarang (Tier C — disahkan user), (2) ganti SEMUA id lama ke id btul (sedia ada ATAU
-- baharu) merentas 4 jadual, guna replace() teks jsonb (SELAMAT — UUID rentetan unik,
-- tak mungkin lencong padan data lain). Padanan Tier B (nama/saiz berbeza tapi disahkan
-- produk sama oleh user) turut disertakan.
-- ════════════════════════════════════════════════════════════════

-- (1) Cipta item Inventori baharu — Tier C, langsung tiada dalam katalog sekarang.
INSERT INTO psy_inventory_items (name, category, unit, qty_in_stock, min_qty, requires_approval, notes)
SELECT v.name, v.category, v.unit, 0, v.min_qty, v.requires_approval, v.notes
FROM (VALUES
  ('Akses Portal ISW', 'Starter Kit', 'Unit', 10, false, 'Dicipta semula 20 Okt 2026 — item_id asal yatim drpd Inventori (lihat FASA H)'),
  ('Alcohol Swab', 'Peralatan Klinik', 'Pek', 10, false, 'Dicipta semula 20 Okt 2026 — item_id asal yatim drpd Inventori'),
  ('Biopsychosocial-Spiritual (BPS-S)', 'Buku & Bahan Cetak', 'Naskhah', 10, false, 'Dicipta semula 20 Okt 2026 — item_id asal yatim drpd Inventori'),
  ('BNP & NSS Pesakit Gastrik, Gerd, Radang Usus, Sembelit', 'Starter Kit', 'Unit', 5, false, 'Dicipta semula 20 Okt 2026 — item_id asal yatim drpd Inventori'),
  ('Cotton Ball', 'Peralatan Klinik', 'Pek', 10, false, 'Dicipta semula 20 Okt 2026 — item_id asal yatim drpd Inventori'),
  ('Intravenous (IV) Infusion Set', 'Peralatan Klinik', 'Set', 5, false, 'Dicipta semula 20 Okt 2026 — item_id asal yatim drpd Inventori'),
  ('Normal Saline (NS)', 'Peralatan Klinik', 'Botol', 5, false, 'Dicipta semula 20 Okt 2026 — item_id asal yatim drpd Inventori'),
  ('P101 Jilid 1', 'Buku & Bahan Cetak', 'Naskhah', 10, false, 'Dicipta semula 20 Okt 2026 — item_id asal yatim drpd Inventori'),
  ('P101 Jilid 2', 'Buku & Bahan Cetak', 'Naskhah', 10, false, 'Dicipta semula 20 Okt 2026 — item_id asal yatim drpd Inventori'),
  ('P101 Jilid 3', 'Buku & Bahan Cetak', 'Naskhah', 10, false, 'Dicipta semula 20 Okt 2026 — item_id asal yatim drpd Inventori'),
  ('P101 Jilid 4', 'Buku & Bahan Cetak', 'Naskhah', 10, false, 'Dicipta semula 20 Okt 2026 — item_id asal yatim drpd Inventori'),
  ('P101 Jilid 5', 'Buku & Bahan Cetak', 'Naskhah', 10, false, 'Dicipta semula 20 Okt 2026 — item_id asal yatim drpd Inventori'),
  ('P101 Jilid 6', 'Buku & Bahan Cetak', 'Naskhah', 10, false, 'Dicipta semula 20 Okt 2026 — item_id asal yatim drpd Inventori'),
  ('P101 Jilid 7', 'Buku & Bahan Cetak', 'Naskhah', 10, false, 'Dicipta semula 20 Okt 2026 — item_id asal yatim drpd Inventori'),
  ('Panduan Peminuman Madu (IB & YHPG)', 'Buku & Bahan Cetak', 'Naskhah', 10, false, 'Dicipta semula 20 Okt 2026 — item_id asal yatim drpd Inventori'),
  ('Panduan Peminuman Madu (LTH & LTHPG)', 'Buku & Bahan Cetak', 'Naskhah', 10, false, 'Dicipta semula 20 Okt 2026 — item_id asal yatim drpd Inventori'),
  ('Panduan Pengamalan Zikir Bersanad', 'Buku & Bahan Cetak', 'Naskhah', 10, false, 'Dicipta semula 20 Okt 2026 — item_id asal yatim drpd Inventori')
) AS v(name, category, unit, min_qty, requires_approval, notes)
WHERE NOT EXISTS (SELECT 1 FROM psy_inventory_items existing WHERE existing.name = v.name);

-- (2) Ganti SEMUA rujukan item_id lama (yatim) → id betul (sedia ada/baharu), merentas
-- SEMUA jadual yg simpan snapshot item_id dalam JSONB. Guna CTE utk selesaikan id baharu
-- (dari INSERT di atas) & id sedia ada (Tier A/B, padanan nama) dalam SATU jadual mapping,
-- lepas tu replace() teks jsonb berjujukan (idempoten — lepas run sekali, id lama dah tak
-- wujud dlm teks, replace seterusnya jadi no-op selamat).
DO $$
DECLARE
  m RECORD;
  new_id UUID;
BEGIN
  FOR m IN SELECT * FROM (VALUES
    -- Tier A — nama jelas sama (eja/Brochure vs Brosur sahaja)
    ('4230596e-7413-42e7-b76e-eaeb0108eaef', 'Air Afiyah'),
    ('91e88c83-6322-42ec-abaf-d30b4d603d95', 'Air Za''afaran'),
    ('61b712c4-b517-4ffd-83c4-78c95d4a1e9e', 'BNP'),
    ('6952718e-dd28-4279-975e-4364013fb77c', 'Brochure ISW'),
    ('fa385232-7670-44c9-8207-e73c451c4066', 'Brochure OB'),
    ('98190809-0aca-403b-88cc-8b934c453c8f', 'Buku Gaya Hidup Fitrah'),
    ('11477fc9-4647-41bf-894b-2896f1c917ba', 'GHF'),
    ('603ede96-8105-475e-b056-67958c06b5cc', 'Herba Kolon'),
    ('2fee174d-97cb-489b-aa80-82aca604787c', 'Jadual Terapi Mingguan'),
    ('e270bc74-acd0-41a8-9ac8-b591c02ad186', 'List Pantang'),
    ('09456229-bd9c-47fb-924e-de0586b63a07', 'Mesin Ozon'),
    ('2f33119b-4ca8-42e3-8494-0bc21d4f5743', 'NSS'),
    ('0eb505ff-2ec4-4fa4-9d82-bf7466a02f1c', 'Peta OB'),
    ('63ff8bb2-efa1-4391-83a4-3abd042e53a7', 'Resepi Superenergi'),
    ('0622e67e-f7a6-4cb3-9af2-6d1d2718faae', 'Resepi Superimun'),
    ('4797d035-ad0d-4a86-8ce1-159fa4ddb05d', 'SDS OB'),
    ('04645201-fd4c-4aba-8e3c-e4dcad47e423', 'Voucher Konsultasi'),
    ('6f88519d-4890-4811-8ea4-5734dec604c2', 'DNA Test Kit'),
    ('c8f49e92-d5b8-4940-bbec-8185c17c4ff5', 'Enema Kit'),
    -- Tier B — produk sama disahkan user, nama/saiz berbeza
    ('5d86d796-81bf-43c4-97ed-6c08a976e7e7', 'Brochure Madu'),
    ('372b70c9-68d4-4b22-a6b2-548a16d1c953', 'Lebah Thoharah (LTH)'),
    ('e04db28e-d264-4b4f-bfe7-9c109ae44dde', 'Lebah Thoharah (LTH)'),
    ('e142aad7-c823-48aa-a965-91e6a634ae41', 'LTH Plus Green (LTHPG)'),
    ('d73ee889-7b41-498c-aa5e-75847542c142', 'Ibu Bumi (IB)'),
    ('85c994b6-049d-42c7-943f-a549e4443c6e', 'Ibu Bumi (IB)'),
    ('9e42bf82-3ed3-4ef9-bf9b-cc9a3abb25a4', 'Young & Healthy Plus Green (YHPG)'),
    ('8dc3e6cd-408f-49aa-852d-68d5101ca602', 'Young & Healthy Plus Green (YHPG)'),
    ('185dcfd8-83a7-4d0f-9e8b-567efd70a2aa', 'Young & Healthy Plus Green (YHPG)'),
    -- Tier C — item baharu dicipta di (1) atas, padan ikut NAMA PERSIS
    ('e5cd31ff-61a5-42f9-86bc-cce84fe29faa', 'Akses Portal ISW'),
    ('a7a59db8-0b05-4df8-96e3-aa9c0b156ebf', 'Alcohol Swab'),
    ('403cef31-4e3f-4f80-85ce-57394389162c', 'Biopsychosocial-Spiritual (BPS-S)'),
    ('74925977-99a5-4d40-8f3d-3dd785ff2206', 'BNP & NSS Pesakit Gastrik, Gerd, Radang Usus, Sembelit'),
    ('a395dce5-18d4-4df0-8609-dd638f5a35fb', 'Cotton Ball'),
    ('4b5d1e39-e29e-4918-8b30-1faa00b2e951', 'Intravenous (IV) Infusion Set'),
    ('44fb3caf-dcc5-4832-92ac-f9cb288fde93', 'Normal Saline (NS)'),
    ('72585ef1-1d7a-45c2-a847-f18f996df8f2', 'P101 Jilid 1'),
    ('6cbaffe4-9124-4cff-86c5-4b5f4ecf2675', 'P101 Jilid 2'),
    ('046f99c4-b346-4d60-84de-89ef4b698434', 'P101 Jilid 3'),
    ('79afb226-32ed-46ab-bfa9-67ac2510322a', 'P101 Jilid 4'),
    ('368e9d88-d2f9-4d74-a6e6-a239eb8b0ade', 'P101 Jilid 5'),
    ('7ed7b5f7-082c-4168-941c-7bc09ce7d8d2', 'P101 Jilid 6'),
    ('bf69ac8c-6a04-4759-ad6c-f200549f14a0', 'P101 Jilid 7'),
    ('8cb86aeb-34b8-4355-879e-265efa617d46', 'Panduan Peminuman Madu (IB & YHPG)'),
    ('5d474884-8cec-4ee2-8ae7-811de8e6a4d5', 'Panduan Peminuman Madu (LTH & LTHPG)'),
    ('9ac1fde0-57d5-4ddb-b494-9e5e7eebfa24', 'Panduan Pengamalan Zikir Bersanad')
  ) AS t(old_id, target_name)
  LOOP
    SELECT id INTO new_id FROM psy_inventory_items WHERE name = m.target_name LIMIT 1;
    IF new_id IS NULL THEN
      RAISE WARNING 'FASA H: tiada padanan Inventori utk % (old_id %), dilangkau', m.target_name, m.old_id;
      CONTINUE;
    END IF;
    IF new_id::text = m.old_id THEN CONTINUE; END IF;

    UPDATE psy_treatment_plans SET coaching_schedule = replace(coaching_schedule::text, m.old_id, new_id::text)::jsonb
      WHERE coaching_schedule::text LIKE '%' || m.old_id || '%';
    UPDATE psy_packages SET coaching_schedule = replace(coaching_schedule::text, m.old_id, new_id::text)::jsonb
      WHERE coaching_schedule::text LIKE '%' || m.old_id || '%';
    UPDATE psy_plan_week_overrides SET supplies_override = replace(supplies_override::text, m.old_id, new_id::text)::jsonb
      WHERE supplies_override::text LIKE '%' || m.old_id || '%';
    UPDATE psy_procedure_kits SET items = replace(items::text, m.old_id, new_id::text)::jsonb
      WHERE items::text LIKE '%' || m.old_id || '%';
  END LOOP;
END $$;

-- (3) Semakan pantas lepas run — patut pulangkan 0 baris (tiada lagi item_id yatim).
-- SELECT DISTINCT s->>'item_id' AS item_id, s->>'item_name' AS item_name
-- FROM psy_treatment_plans p, jsonb_array_elements(p.coaching_schedule) w,
--      jsonb_array_elements(coalesce(w->'supplies','[]'::jsonb) || coalesce(w->'supplies_2','[]'::jsonb)) s
-- WHERE s ? 'item_id' AND NOT EXISTS (SELECT 1 FROM psy_inventory_items i WHERE i.id::text = s->>'item_id');
