-- ISW System — seeds.sql
Reference / default data (not demo/test data).
Run AFTER master_migration.sql.
-- Generated: 2026-06-12T04:04:17.882279Z
-- Total files: 3
-- Run this entire file in Supabase SQL Editor (new project).


-- ════════════════════════════════════════════════════════════════
-- seed_default_agreement_clauses.sql
-- ════════════════════════════════════════════════════════════════

-- ============================================================
-- SEED: Default agreement clauses untuk SEMUA pakej
-- Source: Agreement/agreement.pdf (Kontrak Pelaburan Kesihatan, OB KOB FORM 03 250711)
-- Update SEMUA pakej yang agreement_clauses kosong/NULL — staff masih boleh override per-pakej
-- ============================================================

UPDATE psy_packages
SET
  agreement_title   = COALESCE(NULLIF(agreement_title, ''), 'Kontrak Pelaburan Kesihatan'),
  agreement_version = COALESCE(NULLIF(agreement_version, ''), 'ISW.SOP OB KOB FORM 03 250711'),
  agreement_clauses = '[
    {"title":"1. Tanggungjawab terhadap kesihatan","body":"Saya mengambil tanggungjawab sepenuhnya terhadap kesihatan saya dan telah mengisi borang ini dengan sukarela dengan memberikan maklumat kesihatan saya kepada Ibnu Sina Wellness."},
    {"title":"2. Berpuas hati dengan khidmat","body":"Saya berpuas hati dengan khidmat nasihat kesihatan yang diberikan oleh perawat Ibnu Sina Wellness."},
    {"title":"3. Bukan diagnosis medikal","body":"Saya faham dengan sepenuhnya bahawa ia bukan diagnosis medikal atau rawatan medikal atau substitut untuk diagnosis medikal atau rawatan medikal."},
    {"title":"4. Masalah mental / sihir & saka","body":"Saya faham bahawa sekiranya saya mempunyai masalah mental atau sihir dan saka, saya harus dirawat terlebih dahulu sebelum memulakan program Jumpstart / New Life Challenge / Overhaul Body di Ibnu Sina Wellness."},
    {"title":"5. Rawatan alternatif","body":"Saya faham bahawa program Jumpstart / New Life Challenge / Overhaul Body di Ibnu Sina Wellness adalah rawatan alternatif dan ia tidak menggantikan perubatan hospital maka saya akan meneruskan pengambilan ubat, perubatan dan pemeriksaan hospital."},
    {"title":"6. Komited setiap hari","body":"Saya faham bagi mencapai hasil yang baik, saya perlu amalkan secara komited setiap hari segala tatacara yang disusun dan diajarkan oleh Ibnu Sina Wellness secara sepenuhnya."},
    {"title":"7. Gaya Pemikiran Follow Fitrah","body":"Saya komited untuk mengikuti program Jumpstart / New Life Challenge / Overhaul Body bagi menukar kepada Gaya Pemikiran Follow Fitrah sebagai tahap asas untuk mencapai kesihatan yang sihat."},
    {"title":"8. Penyembuhan di tangan Allah SWT","body":"Saya faham penyembuhan penyakit adalah di tangan Allah SWT dan jangkamasa penyembuhan bergantung kepada keizinan Allah."},
    {"title":"9. Penerangan penuh pakej","body":"Saya telah diberi penerangan penuh pakej program Jumpstart / New Life Challenge / Overhaul Body, dengan jelas oleh Ibnu Sina Wellness."},
    {"title":"10. Reaksi pemulihan & risiko","body":"Ibnu Sina Wellness telah memaklumkan tentang reaksi pemulihan dan gejala prosedur, yang boleh termasuk, tetapi tidak terhad kepada: pening atau loya, sakit-sakit badan, flu, lebam, perubahan warna kulit, dan kemungkinan risiko lain yang tidak dijangka. Dalam sesetengah kes, simptom saya mungkin bertambah buat sementara waktu sebelum ia mula beransur baik. Saya akan menanggung segala risiko yang terlibat dengan prosedur saya."},
    {"title":"11. Ke hospital untuk kecemasan","body":"Saya faham saya perlu ke hospital untuk kecemasan. Saya juga akan segera ke hospital sekiranya saya sakit atau mengalami reaksi pemulihan yang teruk seperti yang tertera di buku Sains di Sebalik Overhaul Body atau seperti yang dinasihatkan oleh perawat dan coach Ibnu Sina Wellness."},
    {"title":"12. Tiada jaminan keputusan","body":"Saya faham bahawa tiada jaminan keputusan untuk sebarang prosedur yang sedang dijalani. Prosedur kesihatan alternatif dan holistik selalunya tidak akan menunjukkan hasil rawatan dengan serta merta."},
    {"title":"13. Tempoh hasil bergantung kepada disiplin","body":"Tempoh untuk mencapai hasil serta keputusan bergantung pada tahap kesihatan saya, disiplin serta komitmen saya mengamalkan kaedah program Jumpstart / New Life Challenge / Overhaul Body di Ibnu Sina Wellness."},
    {"title":"14. Tidak memaksa ISW bertanggungjawab","body":"Saya tidak akan memaksa Ibnu Sina Wellness untuk bertanggungjawab ke atas sebarang kekurangan hasil program Jumpstart / New Life Challenge / Overhaul Body."},
    {"title":"15. Kerosakan peralatan","body":"Saya faham bahawa sekiranya terdapat sebarang kerosakan terhadap peralatan rawatan Ibnu Sina Wellness disebabkan oleh kecuaian atau kegagalan untuk bertindak sewajarnya dari diri saya sendiri, saya akan membayar pampasan kepada pihak Ibnu Sina Wellness kos yang munasabah untuk membaiki kerosakan peralatan rawatan tersebut berdasarkan permintaan Ibnu Sina Wellness."},
    {"title":"16. Keputusan rela hati","body":"Dengan rela hati saya sendiri membuat keputusan untuk mengikuti program Jumpstart / New Life Challenge / Overhaul Body Ibnu Sina Wellness dan telah dimaklumkan tentang risiko serta manfaatnya."},
    {"title":"17. Pembebasan tanggungjawab","body":"Saya membebaskan pihak Ibnu Sina Wellness, herba-herba yang digunakan, peralatan yang digunakan, fasiliti, perawat, strategist, pekerja Ibnu Sina Wellness, pesakit yang memberi testimoni serta kesemua produksi media Ibnu Sina Wellness dari sebarang tindakan dan kerugian selamanya."},
    {"title":"18. Barang-barang peribadi","body":"Saya faham bahawa semua barang peribadi di dalam fasiliti Ibnu Sina Wellness adalah di bawah tanggungjawab saya sendiri dan pihak Ibnu Sina Wellness tidak akan bertanggungjawab pada sebarang kerosakan atau kecurian atau penyelewengan barang peribadi saya."},
    {"title":"19. Rakaman Laporan Progres","body":"19.1. Saya dengan ini mengesahkan persetujuan yang diberikan kepada Ibnu Sina Wellness berkenaan dengan fotografi, rakaman video, penggambaran, atau rakaman audio bagi tujuan penyimpanan rekod pesakit, informasi, pembelajaran atau promosi.\n\n19.2. Saya sedia maklum bahawa maklumat yang diberikan kepada Ibnu Sina Wellness akan digunakan, diedarkan atau dikongsikan kepada mana-mana pihak ketiga berkenaan dengan fotografi, rakaman video, penggambaran, atau rakaman audio untuk siaran langsung atau pre-rakaman."},
    {"title":"20. Notis pembatalan 7 hari","body":"Saya akan memberi notis bertulis tempoh 7 hari sekiranya saya ingin membatalkan program Jumpstart / New Life Challenge / Overhaul Body."},
    {"title":"21. Pemulangan wang","body":"Saya faham tiada pemulangan wang secara tunai ke atas pembayaran yang dilakukan. Lebihan wang yang telah dibayar akan digantikan dengan mana-mana perkhidmatan dan/atau produk Ibnu Sina Wellness yang lain."},
    {"title":"22. Hari Rawatan","body":"22.1. Hari rawatan ialah pada hari Jumaat, Sabtu dan Ahad.\n\n22.2. Saya faham bahawa jika rawatan di luar waktu dan hari yang dinyatakan, akan ada cas \"on-call\" RM50/sejam.\n\n22.3. Saya faham bahawa ISW berhak untuk menukar waktu dan hari rawatan atas apa-apa sebab dan tiada cas \"on-call\" akan dikenakan."},
    {"title":"23. Bayaran ikut Pelan Pelaburan Ansuran","body":"Saya bertanggungjawab untuk melunaskan bayaran mengikut tarikh dan jumlah yang telah ditetapkan mengikut Pelan Pelaburan Ansuran."},
    {"title":"24. Gagal bayar — yuran kembali asal","body":"Saya faham jika saya gagal menunaikan pembayaran mengikut Pelan Pelaburan Ansuran, yuran pakej saya akan berbalik ke yuran asal."},
    {"title":"25. Tindakan undang-undang","body":"Saya juga sedar kegagalan mematuhi bayaran mengikut tarikh dan jumlah yang telah ditetapkan akan menyebabkan kes saya dirujuk untuk tindakan undang-undang."},
    {"title":"26. Bersetuju berhutang","body":"Saya bersetuju untuk menjalani program Jumpstart / New Life Challenge / Overhaul Body sepenuhnya di Ibnu Sina Wellness secara berhutang."},
    {"title":"27. Janji lunas bayaran","body":"Saya berjanji untuk melangsaikan semua bayaran mengikut Pelan Pelaburan Ansuran."},
    {"title":"28. Tiada pemulangan wang","body":"Saya faham tiada pemulangan wang akan diberikan atas bayaran yang telah dibuat.\n\n28.1. Lebihan wang yang telah dibayar boleh digantikan dengan mana-mana perkhidmatan dan/atau produk Ibnu Sina Wellness yang lain, tertakluk pada pengurusan Ibnu Sina Wellness."},
    {"title":"29. Akaun bayaran online","body":"Untuk bayaran online transfer, saya hanya akan buat bayaran ke akaun di bawah:\n\nIBNU SINA WELLNESS SDN BHD\nCIMB BANK — 8605794539\n\nWA screenshot bayaran ke Coach di 03-8966 3702."}
  ]'::jsonb
WHERE agreement_clauses IS NULL
   OR jsonb_typeof(agreement_clauses) <> 'array'
   OR jsonb_array_length(agreement_clauses) = 0;

NOTIFY pgrst, 'reload schema';

SELECT 'Default agreement clauses applied — ' || COUNT(*)::text || ' pakej updated' AS status
FROM psy_packages
WHERE agreement_clauses IS NOT NULL
  AND jsonb_array_length(agreement_clauses) >= 29;


-- ════════════════════════════════════════════════════════════════
-- seed_coaching_catalog_bimbingan.sql
-- ════════════════════════════════════════════════════════════════

-- ============================================================
-- SEED: psy_coaching_catalog — Bimbingan items dari Syafa Checklist
-- Source: docs/Syafa_Checklist_Audit (OVERHAUL BODY + NEW LIFE CHALLENGE)
-- Dedupe: item yang sama merentas pakej hanya 1 row
-- ============================================================

INSERT INTO psy_coaching_catalog (name, type, category, sort_order, is_active)
VALUES
  -- Peminuman & Nutrisi
  ('Bimbingan Peminuman LTH, LTHPG @ IB, YHPG',                                 'bimbingan', 'Peminuman & Nutrisi',   10, true),
  ('Bimbingan Peminuman IB',                                                    'bimbingan', 'Peminuman & Nutrisi',   11, true),
  ('Bimbingan Diet dan Nutrisi',                                                'bimbingan', 'Peminuman & Nutrisi',   12, true),
  ('Bimbingan Diet Vegan',                                                      'bimbingan', 'Peminuman & Nutrisi',   13, true),
  ('Bimbingan Kepentingan Madu Asli dan Kombinasi Herba untuk sokongan Jasad',  'bimbingan', 'Peminuman & Nutrisi',   14, true),
  ('Bimbingan Khasiat Bawang Putih',                                            'bimbingan', 'Peminuman & Nutrisi',   15, true),
  ('Bimbingan Kebaikan Minyak Kelapa Dara',                                     'bimbingan', 'Peminuman & Nutrisi',   16, true),
  ('Bimbingan Kebaikan Air Kelapa',                                             'bimbingan', 'Peminuman & Nutrisi',   17, true),

  -- Rohani
  ('Bimbingan Zikir bersanad',                                                  'bimbingan', 'Rohani',                20, true),
  ('Bimbingan Kepentingan Bersedekah dan Overhaul Body',                        'bimbingan', 'Rohani',                21, true),

  -- Herba & Terapi
  ('Bimbingan Herba Thoharah',                                                  'bimbingan', 'Herba & Terapi',        30, true),
  ('Bimbingan Air Afiyah, Air Za''afaran, Penyucian Aura',                      'bimbingan', 'Herba & Terapi',        31, true),
  ('Bimbingan Terapi Kolon',                                                    'bimbingan', 'Herba & Terapi',        32, true),

  -- Reaksi & Pemulihan
  ('Bimbingan Reaksi Pemulihan',                                                'bimbingan', 'Reaksi & Pemulihan',    40, true),
  ('Bimbingan Manual Reaksi Pemulihan (Healing Crisis)',                        'bimbingan', 'Reaksi & Pemulihan',    41, true),
  ('Bimbingan Hapuskan Longgokan Toksin dan Rasai Perubahan Kesihatan',         'bimbingan', 'Reaksi & Pemulihan',    42, true),
  ('Bimbingan Kepentingan On Healing Machine dan Hormon Bahagia',               'bimbingan', 'Reaksi & Pemulihan',    43, true),

  -- Mikrobiota & Perut
  ('Bimbingan Kepentingan Prebiotik dan Probiotik kepada pemulihan perut',      'bimbingan', 'Mikrobiota & Perut',    50, true),
  ('Bimbingan tentang Prebiotik dan Probiotik',                                 'bimbingan', 'Mikrobiota & Perut',    51, true),
  ('Bimbingan Bakteria perut',                                                  'bimbingan', 'Mikrobiota & Perut',    52, true),
  ('Bimbingan Keseimbangan Mikrobiota Meningkatkan Pemulihan Perut',            'bimbingan', 'Mikrobiota & Perut',    53, true),

  -- Protein & Pankreas
  ('Bimbingan Pemulihan tanpa Protein Haiwan',                                  'bimbingan', 'Protein & Pankreas',    60, true),
  ('Bimbingan Bila protein jadi beban',                                         'bimbingan', 'Protein & Pankreas',    61, true),
  ('Bimbingan Hidupkan Pankreas, Makanan ''Panas'' dan ''Sejuk''',              'bimbingan', 'Protein & Pankreas',    62, true),

  -- Gaya Hidup & Makanan
  ('Bimbingan Gaya Hidup Fitrah',                                               'bimbingan', 'Gaya Hidup & Makanan',  70, true),
  ('Bimbingan Keburukan makanan Berproses',                                     'bimbingan', 'Gaya Hidup & Makanan',  71, true),
  ('Bimbingan Lemak: Musuh atau Kawan',                                         'bimbingan', 'Gaya Hidup & Makanan',  72, true),

  -- Follow Up
  ('Sesi follow up',                                                            'bimbingan', 'Follow Up',             80, true)
ON CONFLICT DO NOTHING;


-- ════════════════════════════════════════════════════════════════
-- seed_daily_schedule.sql
-- ════════════════════════════════════════════════════════════════

-- Rawatan OB — jadual harian standard
-- Hanya update pakej yang belum ada jadual (daily_schedule kosong/null)
UPDATE psy_packages
SET daily_schedule = '[
  {"time":"06:15","activity":"Zikir bersanad"},
  {"time":"06:30","activity":"Minum madu LTHPG"},
  {"time":"07:30","activity":"Minum madu LTH"},
  {"time":"07:45","activity":"Berjemur cahaya matahari pagi & terapi bumi & pernafasan fitrah (10 minit)"},
  {"time":"08:15","activity":"Makan breakfast (Yogurt dan buah)"},
  {"time":"09:15","activity":"Minum madu LTHPG"},
  {"time":"10:15","activity":"Minum madu LTH"},
  {"time":"11:15","activity":"Minum madu LTHPG"},
  {"time":"12:15","activity":"Minum madu LTH"},
  {"time":"12:30","activity":"Lunch & minum air kelapa"},
  {"time":"13:15","activity":"Solat Zohor & pernafasan fitrah (5 minit)"},
  {"time":"14:15","activity":"Minum madu LTHPG"},
  {"time":"15:15","activity":"Minum madu LTH"},
  {"time":"16:15","activity":"Minum madu LTHPG"},
  {"time":"16:40","activity":"Solat Asar & pernafasan fitrah (5 minit)"},
  {"time":"17:00","activity":"Berkebun @ Terapi bumi"},
  {"time":"18:30","activity":"Makan malam"},
  {"time":"19:30","activity":"Solat Maghrib & Zikir bersanad"},
  {"time":"20:30","activity":"Solat Isyak & Pernafasan Fitrah (5 minit)"},
  {"time":"21:00","activity":"Minum madu LTH"},
  {"time":"21:30","activity":"Pernafasan fitrah (5 minit) & Tidur"}
]'::jsonb
WHERE daily_schedule IS NULL OR daily_schedule = '[]'::jsonb;

SELECT 'Jadual harian default seeded — ' || COUNT(*)::text || ' pakej updated' AS status
FROM psy_packages
WHERE jsonb_array_length(COALESCE(daily_schedule,'[]'::jsonb)) > 0;


-- ════════════════════════════════════════════════════════════════
-- seed_letter_templates.sql
-- ════════════════════════════════════════════════════════════════

-- ============================================================
-- SEED LETTER TEMPLATES
-- 6 template surat common untuk klinik (boleh edit/buang via UI)
-- ============================================================

-- Buang seed lama (kalau dah ada) supaya idempotent
DELETE FROM psy_letter_templates
WHERE name IN (
  'Surat untuk KWSP',
  'Surat Pengesahan Rawatan',
  'Surat untuk PERKESO',
  'Surat untuk RELA',
  'Surat Tidak Hadir Kerja',
  'Surat Sokongan Rawatan'
);

-- ── 1. KWSP ──
INSERT INTO psy_letter_templates (
  name, category, jenis_surat, description, is_active,
  recipient, title, body, fields
) VALUES (
  'Surat untuk KWSP',
  'patient',
  'KWSP',
  'Surat sokongan pengeluaran KWSP atas sebab kesihatan.',
  true,
  E'Pengurus Besar,\nKumpulan Wang Simpanan Pekerja (KWSP),\nJalan Raja Laut,\n50350 Kuala Lumpur.',
  'SURAT SOKONGAN PENGELUARAN KWSP ATAS SEBAB KESIHATAN',
  E'Tuan/Puan,\n\nAdalah disahkan bahawa [NAMA] (No. K/P: [IC]) telah menerima rawatan di Ibnu Sina Wellness bermula [TARIKH_MULA_RAWATAN] sehingga kini.\n\nPesakit memerlukan rawatan berterusan bagi mengurus [DIAGNOSIS]. Anggaran kos rawatan keseluruhan adalah [KOS_RAWATAN].\n\nKami memohon pertimbangan pihak Tuan/Puan untuk meluluskan permohonan pengeluaran KWSP atas sebab kesihatan pesakit.\n\nSekian, terima kasih.',
  '[{"key":"DIAGNOSIS","label":"Diagnosis Pesakit","type":"text"},{"key":"KOS_RAWATAN","label":"Anggaran Kos Rawatan (RM)","type":"text"}]'::jsonb
);

-- ── 2. Pengesahan Rawatan ──
INSERT INTO psy_letter_templates (
  name, category, jenis_surat, description, is_active,
  recipient, title, body, fields
) VALUES (
  'Surat Pengesahan Rawatan',
  'patient',
  'Pengesahan',
  'Surat pengesahan pesakit sedang dalam rawatan di klinik.',
  true,
  E'Kepada sesiapa yang berkenaan,',
  'SURAT PENGESAHAN RAWATAN',
  E'Tuan/Puan,\n\nDengan ini disahkan bahawa [NAMA] (No. K/P: [IC]) merupakan pesakit di Ibnu Sina Wellness.\n\nPesakit telah memulakan rawatan pada [TARIKH_MULA_RAWATAN] di bawah pakej [PAKEJ].\n\nSurat ini dikeluarkan atas permohonan pesakit untuk tujuan [TUJUAN].\n\nSekian, terima kasih.',
  '[{"key":"TUJUAN","label":"Tujuan Surat","type":"text"}]'::jsonb
);

-- ── 3. PERKESO ──
INSERT INTO psy_letter_templates (
  name, category, jenis_surat, description, is_active,
  recipient, title, body, fields
) VALUES (
  'Surat untuk PERKESO',
  'patient',
  'PERKESO',
  'Surat sokongan tuntutan SOCSO/PERKESO bagi pekerja.',
  true,
  E'Pengurus Besar,\nPertubuhan Keselamatan Sosial (PERKESO),\nMenara PERKESO,\n50777 Kuala Lumpur.',
  'SURAT SOKONGAN TUNTUTAN PERKESO',
  E'Tuan/Puan,\n\nAdalah disahkan bahawa [NAMA] (No. K/P: [IC]) telah menerima rawatan di Ibnu Sina Wellness berkaitan [JENIS_KECEDERAAN].\n\nTempoh rawatan: dari [TARIKH_MULA] hingga [TARIKH_TAMAT].\n\nSurat ini dikeluarkan untuk tujuan tuntutan PERKESO. Sila pertimbangkan dengan sewajarnya.\n\nSekian, terima kasih.',
  '[{"key":"JENIS_KECEDERAAN","label":"Jenis Kecederaan/Penyakit","type":"text"},{"key":"TARIKH_MULA","label":"Tarikh Mula Rawatan","type":"date"},{"key":"TARIKH_TAMAT","label":"Tarikh Tamat Rawatan","type":"date"}]'::jsonb
);

-- ── 4. RELA ──
INSERT INTO psy_letter_templates (
  name, category, jenis_surat, description, is_active,
  recipient, title, body, fields
) VALUES (
  'Surat untuk RELA',
  'patient',
  'RELA',
  'Surat permohonan pengecualian tugas RELA atas sebab kesihatan.',
  true,
  E'Pengarah,\nIkatan Relawan Rakyat Malaysia (RELA),\nIbu Pejabat RELA,\nPutrajaya.',
  'PERMOHONAN PENGECUALIAN TUGAS RELA',
  E'Tuan/Puan,\n\nMerujuk perkara di atas, adalah disahkan bahawa [NAMA] (No. K/P: [IC]) sedang menerima rawatan di Ibnu Sina Wellness.\n\nKeadaan kesihatan pesakit tidak membenarkan beliau menjalankan tugas berat. Disarankan beliau diberi pengecualian tugas berat selama [TEMPOH] bermula [TARIKH_MULA].\n\nKami memohon pertimbangan pihak Tuan/Puan.\n\nSekian, terima kasih.',
  '[{"key":"TEMPOH","label":"Tempoh Pengecualian","type":"text"},{"key":"TARIKH_MULA","label":"Tarikh Mula","type":"date"}]'::jsonb
);

-- ── 5. MC / Tidak Hadir Kerja ──
INSERT INTO psy_letter_templates (
  name, category, jenis_surat, description, is_active,
  recipient, title, body, fields
) VALUES (
  'Surat Tidak Hadir Kerja',
  'patient',
  'MC',
  'Surat pengesahan tidak hadir kerja atas sebab kesihatan.',
  true,
  E'Kepada Majikan,',
  'SIJIL CUTI SAKIT',
  E'Tuan/Puan,\n\nDengan ini disahkan bahawa [NAMA] (No. K/P: [IC]) telah menerima rawatan di Ibnu Sina Wellness.\n\nBeliau dinasihatkan untuk berehat dan tidak hadir bekerja dari [TARIKH_MULA_MC] hingga [TARIKH_TAMAT_MC] ([JUMLAH_HARI] hari).\n\nSekian, terima kasih.',
  '[{"key":"TARIKH_MULA_MC","label":"Tarikh Mula Cuti","type":"date"},{"key":"TARIKH_TAMAT_MC","label":"Tarikh Tamat Cuti","type":"date"},{"key":"JUMLAH_HARI","label":"Jumlah Hari","type":"number"}]'::jsonb
);

-- ── 6. Surat Sokongan Rawatan (internal/general) ──
INSERT INTO psy_letter_templates (
  name, category, jenis_surat, description, is_active,
  recipient, title, body, fields
) VALUES (
  'Surat Sokongan Rawatan',
  'patient',
  'Sokongan',
  'Surat sokongan umum untuk pelbagai tujuan (insurance, biasiswa, dll).',
  true,
  E'Kepada sesiapa yang berkenaan,',
  'SURAT SOKONGAN RAWATAN',
  E'Tuan/Puan,\n\nMerujuk perkara di atas, adalah dimaklumkan bahawa [NAMA] (No. K/P: [IC]) adalah pesakit di Ibnu Sina Wellness sejak [TARIKH_MULA_RAWATAN].\n\nPesakit memerlukan sokongan untuk [TUJUAN_SOKONGAN].\n\nSegala kerjasama pihak Tuan/Puan amat dihargai.\n\nSekian, terima kasih.',
  '[{"key":"TUJUAN_SOKONGAN","label":"Tujuan Sokongan","type":"textarea"}]'::jsonb
);

-- ── Verifikasi ──
SELECT name, category, jenis_surat, is_active
FROM psy_letter_templates
WHERE name LIKE 'Surat%'
ORDER BY name;

SELECT COUNT(*) || ' template seeded' AS status
FROM psy_letter_templates
WHERE jenis_surat IS NOT NULL;


-- ════════════════════════════════════════════════════════════════
-- Pengumuman — kategori & jenis lalai (Jun 2026)
-- Run AFTER master_migration.sql (table mesti wujud dulu).
-- ════════════════════════════════════════════════════════════════
insert into psy_announcement_categories (name, sort_order) values
  ('Promosi',1),('Info',2),('Kesihatan',3),('Kelas & Acara',4),
  ('Komuniti',5),('Webinar',6),('Bacaan Manzil',7),('Kemaskini Sistem',8)
on conflict (name) do nothing;

insert into psy_announcement_types (key, title, description, kind, mode, etype, label, sort_order) values
  ('makluman',  'Makluman',            'Makluman umum, notis dan pengumuman biasa.',                'announcement', null,     null,      null,                        1),
  ('event_f2f', 'Event Fizikal (F2F)', 'Program atau acara yang dijalankan secara bersemuka.',      'event',        'f2f',    'kelas',   'Maklumat Event (Fizikal)',  2),
  ('webinar',   'Webinar / Online',    'Program atau sesi yang dijalankan secara online.',          'event',        'online', 'webinar', 'Maklumat Webinar (Online)', 3),
  ('manzil',    'Bacaan Manzil',       'Sesi bacaan manzil secara berkumpulan.',                    'event',        'online', 'manzil',  'Maklumat Sesi Manzil',      4),
  ('survey',    'Survey / Tindakan',   'Tindakan atau maklum balas daripada pengguna.',             'announcement', null,     null,      null,                        5),
  ('sistem',    'Kemaskini Sistem',    'Makluman berkaitan kemaskini atau penyelenggaraan sistem.', 'announcement', null,     null,      null,                        6)
on conflict (key) do nothing;

SELECT 'Pengumuman categories + types seeded' AS status;
