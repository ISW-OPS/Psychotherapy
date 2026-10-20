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
