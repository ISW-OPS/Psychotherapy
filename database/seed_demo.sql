-- ============================================================
-- SEED DEMO DATA — ISW System Management
-- Jalankan dalam Supabase SQL Editor
-- ============================================================
-- LOGIN DEMO:
--   Patient 1 (Siti Aminah)  :  demo.patient@isw.my  /  Demo@1234
--   Patient 2-4              :  hafizuddin@demo.isw   /  Demo@1234
--                               rashidah@demo.isw     /  Demo@1234
--                               khalid@demo.isw       /  Demo@1234
-- ============================================================


-- ── STEP 0: PADAM SEMUA DATA (kecuali staff) ─────────────────

DELETE FROM psy_weekly_feedback;
DELETE FROM psy_plan_compliance;
DELETE FROM psy_plan_weekly_progress;
DELETE FROM psy_plan_check_ins;
DELETE FROM psy_coaching_sessions;
DELETE FROM psy_vitals;
DELETE FROM psy_risk_alerts;
DELETE FROM psy_daily_checkins;
DELETE FROM psy_notifications;
DELETE FROM psy_appointments;
DELETE FROM psy_payments;
DELETE FROM psy_orders;
DELETE FROM psy_treatment_plans;

DELETE FROM auth.users
WHERE id IN (SELECT id FROM psy_profiles WHERE role = 'patient');
DELETE FROM psy_profiles WHERE role = 'patient';
DELETE FROM psy_patients;

DELETE FROM psy_announcements;
DELETE FROM psy_inventory_items;
DELETE FROM psy_library_items;
DELETE FROM psy_products;
DELETE FROM psy_packages;


-- ── STEP 1: PAKEJ RAWATAN ────────────────────────────────────

INSERT INTO psy_packages (
  package_id, name, description, price, duration, duration_weeks,
  icon, bg_color, tier, is_active, sort_order,
  products, bimbingan, inclusions, bio_goals, psycho_goals, social_goals, spiritual_goals
) VALUES
('pkg-777-free', '777 FREE', '7 hari starter · percuma', 0, '7 Hari', 1, '🎁', 'bg-cream', 'free', true, 1,
  '[]'::jsonb,
  '["Webinar 7 hari","Whatsapp Group Support"]'::jsonb,
  '["7 Hari Webinar (Diet, Rohani, Ripple)","7 Gaya Hidup Fitrah","7 Resepi Fitrah","Whatsapp Group Support"]'::jsonb,
  '["Amalkan 7 Resepi Fitrah","Minum air 2L sehari","Pantau berat badan"]'::jsonb,
  '["Tonton Webinar Diet harian","Journaling ringkas (5 min)"]'::jsonb,
  '["Sertai Whatsapp Group Support","Kenali ahli group"]'::jsonb,
  '["Tonton Webinar Rohani harian","Amalkan 7 Gaya Hidup Fitrah"]'::jsonb),
('pkg-777-vip', '777 VIP', '7 hari VIP · coaching & support', 999, '7 Hari', 1, '⭐', 'bg-gold-light', 'vip', true, 2,
  '["Kurma Ajwa 49 Biji","Barley 500g"]'::jsonb,
  '["Webinar 7 hari","Daily Workbook","Perubatan Rohani Sheikh Fares","1:1 Coaching Diet/Nutrisi","Video Series Hakeema","Whatsapp Group Support VIP"]'::jsonb,
  '["7 Hari Webinar (Diet, Rohani, Ripple)","7 Gaya Hidup Fitrah","7 Resepi Fitrah","Whatsapp Group Support 777 VIP","Daily Workbook","Perubatan Rohani Bersama Sheikh Fares","1:1 Coaching Diet / Nutrisi 1x Sebulan","Video Series Hakeema","Kurma Ajwa 49 Biji","Barley 500g"]'::jsonb,
  '["Amalkan 7 Resepi Fitrah","Kurma Ajwa 3 biji setiap pagi","Barley drink setiap petang","Minum air 2L sehari"]'::jsonb,
  '["Siapkan Daily Workbook harian","Tonton Video Series Hakeema","1:1 Coaching Diet/Nutrisi (ikut jadual)"]'::jsonb,
  '["Aktif dalam Whatsapp Group 777 VIP","Tonton Webinar Ripple"]'::jsonb,
  '["Perubatan Rohani bersama Sheikh Fares","Tonton Webinar Rohani harian","Amalkan 7 Gaya Hidup Fitrah"]'::jsonb),
('pkg-eol', 'EOL', 'Entry-level · 4 minggu · 1 madu + coaching', 299, '4 Minggu', 4, '🍯', 'bg-navy-light', null, true, 3,
  '["1 (500G) Young & Healthy Honey"]'::jsonb,
  '["Whatsapp Group Support","Akses Portal ISW","1 Sesi Konsultasi Coach Online","Perubatan Rohani Sheikh Fares"]'::jsonb,
  '["1 (500G) Young & Healthy Honey","Whatsapp Group Support","Akses Portal ISW","1 Sesi Konsultasi bersama Coach secara Online","Perubatan Rohani bersama Sheikh Fares"]'::jsonb,
  '["Young & Healthy Honey 1 sudu besar setiap pagi","Minum air 2.5L sehari","Pantau berat & BP mingguan"]'::jsonb,
  '["Mood tracker harian","Journaling (3 perkara syukur)"]'::jsonb,
  '["Aktif dalam Whatsapp Group Support","Hadir 1 Sesi Konsultasi Coach Online"]'::jsonb,
  '["Perubatan Rohani bersama Sheikh Fares","Zikir pagi petang","Solat penuh 5 waktu"]'::jsonb),
('pkg-eol-plus', 'EOL+', 'Enhanced · 4 minggu · 2 madu + coaching', 499, '4 Minggu', 4, '🍯', 'bg-navy-light', null, true, 4,
  '["2 (500G) Young & Healthy Honey"]'::jsonb,
  '["Whatsapp Group Support","Akses Portal ISW","1 Sesi Konsultasi Coach Online","Perubatan Rohani Sheikh Fares"]'::jsonb,
  '["2 (500G) Young & Healthy Honey","Whatsapp Group Support","Akses Portal ISW","1 Sesi Konsultasi bersama Coach secara Online","Perubatan Rohani bersama Sheikh Fares"]'::jsonb,
  '["Young & Healthy Honey 1 sudu besar 2x/hari","Minum air 2.5L sehari","Pantau berat & BP mingguan","Jalan kaki 20 min/hari"]'::jsonb,
  '["Mood tracker harian","Journaling (3 perkara syukur)","Breathing exercise 4-7-8"]'::jsonb,
  '["Aktif dalam Whatsapp Group Support","Hadir 1 Sesi Konsultasi Coach Online","Family wellness sharing"]'::jsonb,
  '["Perubatan Rohani bersama Sheikh Fares","Zikir pagi petang","Solat penuh 5 waktu","Tadarus Al-Quran harian"]'::jsonb),
('pkg-obp1', 'OBP 1', '12 minggu · 6 KG IB + full terapi', 2999, '12 Minggu', 12, '💎', 'bg-navy-light', null, true, 5,
  '["6 KG IB","6 KG YHPG","Starter Kit","12 Botol Air Afiyah","7 Botol Air Za''afaran","1 Set Herba Kolon","1 Set Enema Kit","1 Set Mesin Ozon","4 Set IV Saline Drip","1 Set DNA Test Kit"]'::jsonb,
  '["20 Sesi Herba Thoharah","6 Kelas Online New Life Challenge","Bimbingan Terapi Peminuman IB, YHPG","Bimbingan Terapi Zikir Bersanad","Bimbingan Terapi Diet dan Nutrisi","Bimbingan Terapi Gaya Hidup Fitrah","Pemantauan Coach","Konsultasi Bersama Hakeema","Perubatan Rohani Online bersama Coach Fares","Perubatan Alami Online bersama Nutritionist"]'::jsonb,
  '["6 KG IB","6 KG YHPG","Starter Kit","12 Botol Air Afiyah","7 Botol Air Za''afaran","1 Set Herba Kolon","1 Set Enema Kit","1 Set Mesin Ozon","4 Set IV Saline Drip","20 Sesi Herba Thoharah","1 Set DNA Test Kit","6 Kelas Online New Life Challenge"]'::jsonb,
  '["Peminuman IB mengikut jadual harian","Air Afiyah 1 botol setiap hari","Herba Thoharah (20 sesi)","IV Saline Drip (4 set)","DNA Test","Pantau vitals mingguan"]'::jsonb,
  '["Bimbingan Terapi Reaksi Pemulihan","Bimbingan Terapi Diet dan Nutrisi","6 Kelas Online New Life Challenge","Mood tracker harian"]'::jsonb,
  '["Pemantauan Coach berterusan","Konsultasi Bersama Hakeema","Sesi Soal Jawab bersama Nutritionist"]'::jsonb,
  '["Bimbingan Terapi Zikir Bersanad","Bimbingan Terapi Penyucian Aura","Perubatan Rohani Online bersama Coach Fares"]'::jsonb),
('pkg-obpx1', 'OBPX 1', '12 minggu + 3 bulan ext · 12 KG IB', 5499, '12 Minggu + 3 Bulan (1 kali) + 3 Bulan (1 kali)', 24, '💎', 'bg-teal/10', null, true, 6,
  '["12 KG IB","12 KG YHPG","Starter Kit","21 Botol Air Afiyah","7 Botol Air Za''afaran","4 Set Herba Kolon","1 Set Enema Kit","1 Set Mesin Ozon","4 Set IV Saline Drip","1 Set DNA Test Kit"]'::jsonb,
  '["26 Sesi Herba Thoharah","6 Kelas Online New Life Challenge","Bimbingan Terapi lengkap","Pemantauan Coach","Konsultasi Hakeema","Perubatan Rohani Coach Fares"]'::jsonb,
  '["12 KG IB","12 KG YHPG","Starter Kit","21 Botol Air Afiyah","7 Botol Air Za''afaran","4 Set Herba Kolon","26 Sesi Herba Thoharah","1 Set DNA Test Kit","6 Kelas Online New Life Challenge"]'::jsonb,
  '["Peminuman IB mengikut jadual (12 KG)","Air Afiyah 1 botol/hari (21 botol)","Herba Thoharah (26 sesi)","IV Saline Drip (4 set)","Herba Kolon 4 set","DNA Test"]'::jsonb,
  '["Bimbingan Terapi Reaksi Pemulihan","6 Kelas Online New Life Challenge","Mood tracker harian"]'::jsonb,
  '["Pemantauan Coach berterusan","Konsultasi Hakeema","Perubatan Alami Online"]'::jsonb,
  '["Zikir Bersanad","Bimbingan Terapi Penyucian Aura","Perubatan Rohani Coach Fares"]'::jsonb),
('pkg-obd1', 'OBD 1', '12 minggu · 6 KG LTH detox', 1999, '12 Minggu', 12, '🌱', 'bg-terracotta-light', null, true, 7,
  '["6 KG LTH","6 KG LTHPG","Starter Kit","12 Botol Air Afiyah","7 Botol Air Za''afaran","1 Set Herba Kolon","1 Set Enema Kit","1 Set Mesin Ozon","4 Set IV Saline Drip","1 Set DNA Test Kit"]'::jsonb,
  '["20 Sesi Herba Thoharah","6 Kelas Online New Life Challenge","Bimbingan Terapi Peminuman LTH, LTHPG","Bimbingan Terapi Zikir Bersanad","Bimbingan Terapi Diet dan Nutrisi","Pemantauan Coach","Konsultasi Hakeema"]'::jsonb,
  '["6 KG LTH","6 KG LTHPG","Starter Kit","12 Botol Air Afiyah","7 Botol Air Za''afaran","1 Set Herba Kolon","20 Sesi Herba Thoharah","1 Set DNA Test Kit","6 Kelas Online New Life Challenge"]'::jsonb,
  '["Peminuman LTH mengikut jadual harian","Air Afiyah 1 botol setiap hari","Herba Thoharah (20 sesi)","IV Saline Drip (4 set)","Herba Kolon mengikut arahan","Enema","DNA Test"]'::jsonb,
  '["Bimbingan Terapi Reaksi Pemulihan","Bimbingan Terapi Diet dan Nutrisi","6 Kelas Online New Life Challenge","Mood tracker"]'::jsonb,
  '["Pemantauan Coach berterusan","Konsultasi Hakeema","Sesi Soal Jawab Nutritionist","Perubatan Alami Online"]'::jsonb,
  '["Zikir Bersanad","Bimbingan Terapi Penyucian Aura","Perubatan Rohani Coach Fares","Solat hajat mingguan"]'::jsonb),
('pkg-js', 'Jump Start (JS)', 'Program berfasa · Ripple → Spark → Light Up', 799, 'Berfasa (3 fasa × 3 program)', 4, '🚀', 'bg-terracotta-light', null, true, 8,
  '["Young & Healthy Honey"]'::jsonb,
  '["4 Video Mingguan","Workbook Refleksi","Latihan Kesedaran Emosi","Latihan Fitrah Harian","Coaching Online Mingguan","Pantauan Kaunselor","Group sokongan Jump Start","1 Sesi kaunseling"]'::jsonb,
  '["4 Video Mingguan","Workbook Refleksi","Latihan Kesedaran Emosi","Latihan Fitrah Harian","Coaching Online Mingguan","Young & Healthy Honey"]'::jsonb,
  '["Young & Healthy Honey mengikut coaching","Latihan Fitrah Harian","1 sesi konsultasi fizikal"]'::jsonb,
  '["4 Video Mingguan","Workbook Refleksi","Latihan Kesedaran Emosi","Coaching Online Mingguan"]'::jsonb,
  '["Group sokongan Jump Start","Pantauan Kaunselor"]'::jsonb,
  '["Latihan Fitrah Harian","Latihan Neuropsikologi & Kerohanian","1 Sesi kaunseling bersama Kaunselor Berdaftar"]'::jsonb)
ON CONFLICT (package_id) DO UPDATE SET
  name = EXCLUDED.name, price = EXCLUDED.price, is_active = EXCLUDED.is_active;


-- ── STEP 2: PRODUK ───────────────────────────────────────────

INSERT INTO psy_products (product_id, name, description, category, price, stock, icon, bg_color, is_active, sort_order) VALUES
('madu-yhh-500g',    'Young & Healthy Honey 500g',   'Madu tulen premium ISW · penggunaan harian',         'Madu',         95,  50, '🍯', 'bg-gold-light',       true, 1),
('madu-yhh-1kg',     'Young & Healthy Honey 1kg',    'Saiz keluarga · nilai lebih jimat',                  'Madu',        175,  30, '🍯', 'bg-gold-light',       true, 2),
('kurma-ajwa-500g',  'Kurma Ajwa 500g',              'Kurma ajwa premium · sunnah Nabi SAW',               'Madu',        150,  60, '🌴', 'bg-gold-light',       true, 3),
('ib-1kg',           'IB 1kg',                       'Ibu Bumi (IB) · bahan asas program OBP',             'Herba',       180,  35, '🌿', 'bg-green-light',      true, 4),
('yhpg-1kg',         'YHPG 1kg',                     'Young Healthy Plus Green · detox hijau',              'Herba',       170,  35, '🌿', 'bg-green-light',      true, 5),
('lth-1kg',          'LTH 1kg',                      'Lebah Thoharah · bahan asas program OBD',            'Herba',       160,  30, '🌿', 'bg-green-light',      true, 6),
('herba-kolon',      'Herba Kolon Set',              '1 set · pembersih kolon semulajadi',                 'Herba',       120,  20, '🌿', 'bg-green-light',      true, 7),
('barley-500g',      'Barley Premium 500g',          'Bijirin barli organik · serat tinggi',               'Herba',        55,  50, '🌾', 'bg-green-light',      true, 8),
('air-afiyah-1btl',  'Air Afiyah 1 Botol',           'Air Afiyah tulen · terapi spiritual',                'Air Terapi',   40, 100, '💧', 'bg-navy-light',       true, 9),
('air-afiyah-12btl', 'Air Afiyah 12 Botol',          'Pack 12 botol · jimat untuk program 12 minggu',     'Air Terapi',  440,  15, '💧', 'bg-navy-light',       true, 10),
('air-zaafaran-1btl','Air Za''afaran 1 Botol',        'Air za''afaran premium · terapi rohani',             'Air Terapi',   60,  80, '💧', 'bg-navy-light',       true, 11),
('magnesium',        'Magnesium Glycinate 60 caps',  '200mg · untuk tidur & relaksasi otot',              'Supplements',  55,  60, '💊', 'bg-navy-light',       true, 12),
('vitamin-d',        'Vitamin D3 5000IU 90 softgels','Untuk imuniti & tulang kuat',                       'Supplements',  48,  70, '☀️', 'bg-gold-light',       true, 13),
('omega-3',          'Omega-3 Fish Oil 60 caps',     '1000mg · jantung & otak sihat',                     'Supplements',  65,  55, '🐟', 'bg-navy-light',       true, 14),
('starter-kit',      'Starter Kit ISW',              'Kit permulaan program · semua yang perlu',           'Santapan Fitrah', 350, 15, '🎒', 'bg-terracotta-light', true, 15),
('enema-kit',        'Enema Kit Set',                'Kit enema lengkap · pembersihan kolon',              'Peralatan',   280,  10, '🏥', 'bg-cream',            true, 16),
('mesin-ozon',       'Mesin Ozon Terapi',            'Terapi ozon rumah · air & udara',                   'Peralatan',   850,   8, '⚡', 'bg-cream',            true, 17),
('iv-saline-set',    'IV Saline Drip Set (1 set)',   '1 set IV saline · untuk terapi drip',               'Peralatan',   120,  12, '💉', 'bg-cream',            true, 18),
('dna-test-kit',     'DNA Test Kit',                 'Kit ujian DNA · analisis kesihatan genetik',         'Peralatan',   450,   5, '🧬', 'bg-cream',            true, 19),
('workbook-js',      'Workbook Jump Start',          'Workbook refleksi program Jump Start · 60 halaman', 'Books',        30,  40, '📓', 'bg-gold-light',       true, 20)
ON CONFLICT (product_id) DO UPDATE SET
  name = EXCLUDED.name, price = EXCLUDED.price, stock = EXCLUDED.stock;


-- ── STEP 3: SELF-HELP LIBRARY ────────────────────────────────

INSERT INTO psy_library_items (item_id, title, description, content_type, category, icon, gradient, sort_order) VALUES
('bps-s-intro',        'Apa itu BPS-S Model?',                    'Dr. Hamzah menerangkan 4 pillar holistik Ibn Sina',           'Video · 8 min',    'navy',      '🎥', 'from-navy to-teal',             1),
('gaya-hidup-fitrah',  '7 Gaya Hidup Fitrah',                     '7 amalan harian untuk keseimbangan bio-psiko-sosio-spiritual','Article · 10 min', 'green',     '📝', 'from-green to-gold-dark',       2),
('faq-baru',           '10 Soalan Lazim Pesakit Baru',            'Apa yang perlu anda tahu sebelum memulakan program',          'FAQ',              'teal',      '💬', 'from-teal to-navy',             3),
('santapan-panduan',   'Santapan Fitrah: Panduan Harian',         'Resipi + cara penyediaan untuk 7 hari pertama',               'Article · 5 min',  'green',     '📝', 'from-green to-gold-dark',       4),
('air-terapi-panduan', 'Panduan Air Afiyah & Za''afaran',          'Cara penggunaan, jadual & dos yang betul',                   'Article · 6 min',  'navy',      '💧', 'from-navy to-teal',             5),
('zikir-syifa',        'Zikir Pagi Petang Syifa',                 'Audio + transliterasi untuk amalan harian penyembuhan',       'Doa & Zikir',      'terracotta','🕌', 'from-terracotta to-gold-dark',  6),
('doa-syifa-panduan',  'Panduan Doa Syifa Lengkap',               '40 doa penyembuhan dari Al-Quran & Hadis sahih',             'Doa & Zikir',      'terracotta','🤲', 'from-terracotta to-gold-dark',  7),
('breathing-muraqabah','Breathing & Muraqabah',                   'Teknik pernafasan untuk ketenangan mental & fokus',           'Exercise · 15 min','gold',      '🧘‍♀️','from-gold to-green',            8),
('mood-tracker',       'Mood & Progress Tracker',                 'PDF printable untuk rekod emosi harian',                     'Worksheet',        'ink',       '📊', 'from-navy to-terracotta',       9),
('journaling-panduan', 'Panduan Journaling Fitrah',               'Teknik menulis jurnal untuk kesihatan emosi & mental',       'Worksheet',        'ink',       '✍️', 'from-navy to-teal',             10),
('stres-urus',         'Urus Stres dengan Cara Islam',            'Teknik CBT + perspektif Islam untuk kawal tekanan',          'Article · 10 min', 'teal',      '🧠', 'from-teal to-navy',             11),
('senaman-fitrah',     'Senaman Fitrah Harian',                   '15 minit senaman ringan yang sesuai untuk semua umur',       'Exercise · 15 min','green',     '🏃', 'from-green to-gold-dark',       12),
('detoks-jadual',      'Jadual Detoks 12 Minggu',                 'Pelan lengkap detoks untuk program OBP & OBD',              'Worksheet',        'ink',       '📅', 'from-navy to-terracotta',       13),
('panduan-obp',        'Panduan Lengkap Program OBP',             'Cara gunakan IB, YHPG, Air Afiyah & semua terapi OBP',      'Article · 15 min', 'navy',      '💎', 'from-navy to-teal',             14),
('reaksi-pemulihan',   'Memahami Reaksi Pemulihan (Herxheimer)',  'Normal atau tidak? Panduan lengkap reaksi detoks',           'FAQ',              'terracotta','❓', 'from-terracotta to-navy',       15),
('vitals-pantau',      'Cara Pantau Vital Signs di Rumah',        'BP, berat badan, suhu — bila perlu ambil & rekod',          'Article · 5 min',  'ink',       '📏', 'from-navy to-terracotta',       16),
('tidur-sihat',        'Panduan Tidur Sihat (Sleep Hygiene)',     'Kesan tidur pada kesihatan & cara tidur yang berkualiti',   'Article · 7 min',  'navy',      '🌙', 'from-navy to-teal',             17),
('progress-tracker',   'Tracker Kemajuan 12 Minggu',             'Worksheet printable untuk pantau kemajuan seluruh program', 'Worksheet',        'ink',       '📈', 'from-navy to-teal',             18)
ON CONFLICT (item_id) DO UPDATE SET
  title = EXCLUDED.title, sort_order = EXCLUDED.sort_order;


-- ── STEP 4: INVENTORI ────────────────────────────────────────

INSERT INTO psy_inventory_items (name, category, unit, qty_in_stock, min_qty, requires_approval, notes) VALUES
('Young & Healthy Honey (YHH)',     'Madu',         'kg',     45.0,  5.0,  false, 'Madu utama program EOL, 777 VIP & Jump Start'),
('Ibu Bumi (IB)',                   'Herba',        'kg',     72.0, 10.0,  false, 'Bahan asas program OBP — stok perlu sentiasa mencukupi'),
('Young Healthy Plus Green (YHPG)', 'Herba',        'kg',     68.0, 10.0,  false, 'Pasangan IB dalam program OBP'),
('Lebah Thoharah (LTH)',            'Herba',        'kg',     55.0, 10.0,  false, 'Bahan asas program OBD'),
('LTH Plus Green (LTHPG)',          'Herba',        'kg',     50.0, 10.0,  false, 'Pasangan LTH dalam program OBD'),
('Air Afiyah',                      'Air Terapi',   'botol', 180.0, 20.0,  false, '1 botol = 1.5L · bekalan untuk semua program aktif'),
('Air Za''afaran',                  'Air Terapi',   'botol',  95.0, 10.0,  false, 'Untuk sesi Perubatan Rohani & terapi penyucian'),
('Herba Kolon',                     'Herba',        'set',    28.0,  5.0,  false, '1 set = 1 kursus rawatan kolon'),
('Barley Organik',                  'Herba',        'kg',     60.0, 10.0,  false, 'Bekalan minuman barley harian pesakit'),
('Kurma Ajwa',                      'Herba',        'biji',  980.0,100.0,  false, '49 biji/pesakit 777 VIP · semak stok sebelum enrol baru'),
('Enema Kit',                       'Peralatan',    'set',    12.0,  3.0,  true,  'Perlu kelulusan untuk beli — harga tinggi'),
('Mesin Ozon',                      'Peralatan',    'unit',    5.0,  1.0,  true,  'Peralatan mahal · rekod nombor siri setiap unit'),
('IV Saline Drip Set',              'Peralatan',    'set',    38.0,  8.0,  true,  '1 set = 1 sesi IV drip · perlu kelulusan perubatan'),
('DNA Test Kit',                    'Peralatan',    'set',     8.0,  2.0,  true,  'Kit ujian DNA · perlu hantar ke lab luar'),
('Starter Kit ISW',                 'Pakej',        'set',    15.0,  3.0,  false, 'Kandungan: buku panduan, tracker, botol air, beg'),
('Workbook Refleksi Harian',        'Alat Bantu',   'naskhah',80.0, 15.0,  false, 'Untuk semua program · diedarkan masa mula program'),
('Jadual Terapi 12 Minggu',         'Alat Bantu',   'naskhah',45.0, 10.0,  false, 'Jadual pelan rawatan peribadi pesakit'),
('Magnesium Glycinate 60 caps',     'Supplements',  'botol',  25.0,  5.0,  false, NULL),
('Vitamin D3 5000IU',               'Supplements',  'botol',  30.0,  5.0,  false, NULL),
('Omega-3 Fish Oil',                'Supplements',  'botol',  20.0,  5.0,  false, NULL),
('Spirulina',                       'Supplements',  'botol',  18.0,  3.0,  false, NULL),
('Rahsia Syifa',                    'Buku',         'naskhah',25.0,  5.0,  false, NULL),
('Kitab Doa Syifa',                 'Buku',         'naskhah',30.0,  5.0,  false, NULL),
('Buku Gaya Hidup Fitrah',          'Buku',         'naskhah',20.0,  5.0,  false, NULL);


-- ── STEP 5: PENGUMUMAN ───────────────────────────────────────

INSERT INTO psy_announcements (title, body, tag, bg, cta_label, cta_url, sort_order) VALUES
('Kelas New Life Challenge — Minggu 3',
 'Sesi khas bersama Coach untuk peserta OBP dan OBPX. Topik: Terapi Diet & Reaksi Pemulihan. Wajib hadir untuk pesakit aktif.',
 'Kelas Minggu Ini', 'from-navy to-teal', 'Daftar Sekarang', 'https://wa.me/60123456789', 1),
('Promosi Pakej EOL+ — Diskaun 20%',
 'Pakej EOL+ kini dengan diskaun 20% sehingga hujung bulan. Termasuk 2 botol madu + 1 sesi coaching percuma.',
 'Promosi', 'from-green-dark to-teal', 'Lihat Pakej', 'pakej.html', 2),
('Peringatan: Pantau Vitals Mingguan',
 'Sila rekod tekanan darah, berat badan dan suhu badan anda pada setiap Isnin pagi. Log masuk ke portal untuk isi borang vitals.',
 'Peringatan', 'from-navy to-green-dark', 'Rekod Vitals', null, 3),
('Webinar Rohani — Bersama Sheikh Fares',
 'Sesi Perubatan Rohani online bersama Sheikh Fares setiap Khamis 9PM. Sertai pautan Zoom yang dihantar ke WhatsApp group anda.',
 'Rohani', 'from-terracotta to-gold-dark', 'Info Lanjut', null, 4);


-- ── STEP 6: PATIENT DATA (DO block untuk handle UUIDs) ────────

DO $$
DECLARE
  -- Staff references
  v_coach_id   UUID;
  v_coach_name TEXT;
  v_staff_id   UUID;
  v_staff_name TEXT;

  -- Patient auth UIDs (= psy_profiles.id)
  v_siti_uid     UUID := gen_random_uuid();
  v_hafiz_uid    UUID := gen_random_uuid();
  v_rashidah_uid UUID := gen_random_uuid();
  v_khalid_uid   UUID := gen_random_uuid();

  -- Patient record IDs (psy_patients.id)
  v_siti_pid     UUID := gen_random_uuid();
  v_hafiz_pid    UUID := gen_random_uuid();
  v_rashidah_pid UUID := gen_random_uuid();
  v_khalid_pid   UUID := gen_random_uuid();

  -- Treatment plan IDs
  v_siti_plan    UUID := gen_random_uuid();
  v_hafiz_plan   UUID := gen_random_uuid();
  v_rashidah_plan UUID := gen_random_uuid();
  v_khalid_plan  UUID := gen_random_uuid();

BEGIN

  -- ── Ambil coach & staff ─────────────────────────────────────
  SELECT id, full_name INTO v_coach_id, v_coach_name
  FROM psy_profiles WHERE role = 'staff' AND staff_role = 'coach'
  ORDER BY created_at LIMIT 1;

  SELECT id, full_name INTO v_staff_id, v_staff_name
  FROM psy_profiles WHERE role = 'staff'
  ORDER BY created_at LIMIT 1;

  -- Fallback jika tiada coach
  IF v_coach_id IS NULL THEN
    v_coach_id := v_staff_id;
    v_coach_name := v_staff_name;
  END IF;


  -- ── AUTH.USERS ──────────────────────────────────────────────
  INSERT INTO auth.users (
    id, instance_id, aud, role, email, encrypted_password,
    email_confirmed_at, created_at, updated_at,
    raw_app_meta_data, raw_user_meta_data,
    is_super_admin, confirmation_token, recovery_token,
    email_change_token_new, email_change
  ) VALUES
  (
    v_siti_uid, '00000000-0000-0000-0000-000000000000',
    'authenticated', 'authenticated', 'demo.patient@isw.my',
    crypt('Demo@1234', gen_salt('bf')),
    now() - interval '12 weeks', now() - interval '12 weeks', now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"full_name":"Siti Aminah binti Ahmad"}'::jsonb,
    false, '', '', '', ''
  ),
  (
    v_hafiz_uid, '00000000-0000-0000-0000-000000000000',
    'authenticated', 'authenticated', 'hafizuddin@demo.isw',
    crypt('Demo@1234', gen_salt('bf')),
    now() - interval '8 months', now() - interval '8 months', now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"full_name":"Encik Hafizuddin bin Rashid"}'::jsonb,
    false, '', '', '', ''
  ),
  (
    v_rashidah_uid, '00000000-0000-0000-0000-000000000000',
    'authenticated', 'authenticated', 'rashidah@demo.isw',
    crypt('Demo@1234', gen_salt('bf')),
    now() - interval '3 days', now() - interval '3 days', now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"full_name":"Puan Rashidah binti Yusof"}'::jsonb,
    false, '', '', '', ''
  ),
  (
    v_khalid_uid, '00000000-0000-0000-0000-000000000000',
    'authenticated', 'authenticated', 'khalid@demo.isw',
    crypt('Demo@1234', gen_salt('bf')),
    now() - interval '4 months', now() - interval '4 months', now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"full_name":"Ustaz Khalid bin Ibrahim"}'::jsonb,
    false, '', '', '', ''
  );


  -- ── PSY_PROFILES ────────────────────────────────────────────
  -- ON CONFLICT sebab Supabase trigger auto-create profile bila auth.user dicipta
  INSERT INTO psy_profiles (id, full_name, email, role, created_at) VALUES
  (v_siti_uid,     'Siti Aminah binti Ahmad',    'demo.patient@isw.my', 'patient', now() - interval '12 weeks'),
  (v_hafiz_uid,    'Encik Hafizuddin bin Rashid','hafizuddin@demo.isw',  'patient', now() - interval '8 months'),
  (v_rashidah_uid, 'Puan Rashidah binti Yusof',  'rashidah@demo.isw',   'patient', now() - interval '3 days'),
  (v_khalid_uid,   'Ustaz Khalid bin Ibrahim',   'khalid@demo.isw',     'patient', now() - interval '4 months')
  ON CONFLICT (id) DO UPDATE SET
    full_name = EXCLUDED.full_name,
    email     = EXCLUDED.email,
    role      = EXCLUDED.role;


  -- ── PSY_PATIENTS ────────────────────────────────────────────
  -- Pesakit 1: Siti Aminah — OBP1, Minggu 3 (pesakit demo boleh login)
  INSERT INTO psy_patients (
    id, user_id, mrn, ic_number, date_of_birth, gender, address,
    emergency_contact_name, emergency_contact_phone,
    medical_condition, condition_duration, medical_notes,
    active_package_id, active_package_name,
    package_purchased_at, package_expires_at,
    status, marital_status, occupation, company, coach_id
  ) VALUES (
    v_siti_pid, v_siti_uid, 'ISW-2024-001', '901215-14-5678',
    '1990-12-15', 'F',
    'No. 12, Jalan Bahagia 3, Taman Maju, 68000 Ampang, Selangor',
    'Ahmad bin Hassan', '0123456789',
    'Obesiti, Tekanan Darah Tinggi', '3 tahun',
    'Pesakit mula rawatan OBP1 untuk detoks dan penurunan berat badan. BP awal 142/92. Berat awal 83.5kg. BMI 31.2. Tiada alahan dikenalpasti.',
    'pkg-obp1', 'OBP 1',
    now() - interval '2 weeks',
    now() + interval '10 weeks',
    'active', 'Berkahwin', 'Guru Sekolah', 'SMK Taman Maju', v_coach_id
  );

  -- Pesakit 2: Hafizuddin — OBPX1, Minggu 8 (pesakit lama)
  INSERT INTO psy_patients (
    id, user_id, mrn, ic_number, date_of_birth, gender, address,
    emergency_contact_name, emergency_contact_phone,
    medical_condition, condition_duration, medical_notes,
    active_package_id, active_package_name,
    package_purchased_at, package_expires_at,
    status, marital_status, occupation, company, coach_id
  ) VALUES (
    v_hafiz_pid, v_hafiz_uid, 'ISW-2023-007', '750820-10-3345',
    '1975-08-20', 'M',
    'No. 45, Jalan Kenari 7, Bandar Baru Bangi, 43000 Kajang, Selangor',
    'Rashid bin Mohd', '0198765432',
    'Diabetes Jenis 2, Kolesterol Tinggi', '7 tahun',
    'Pesakit lama dengan rekod rawatan yang baik. Gula darah dalam kawalan. Berat turun 5.8kg dari berat awal 92kg. Konsisten dengan jadual peminuman.',
    'pkg-obpx1', 'OBPX 1',
    now() - interval '7 weeks',
    now() + interval '17 weeks',
    'active', 'Berkahwin', 'Jurutera', 'Syarikat Teknik Sdn Bhd', v_coach_id
  );

  -- Pesakit 3: Rashidah — EOL+, Minggu 1 (pesakit baru)
  INSERT INTO psy_patients (
    id, user_id, mrn, ic_number, date_of_birth, gender, address,
    emergency_contact_name, emergency_contact_phone,
    medical_condition, condition_duration, medical_notes,
    active_package_id, active_package_name,
    package_purchased_at, package_expires_at,
    status, marital_status, occupation, company, coach_id
  ) VALUES (
    v_rashidah_pid, v_rashidah_uid, 'ISW-2024-012', '850303-08-7890',
    '1985-03-03', 'F',
    'No. 8, Jalan Dahlia 2, Taman Bunga, 41000 Klang, Selangor',
    'Yusof bin Hamid', '0112223344',
    'Anxiety, Insomnia', '1 tahun',
    'Pesakit baru. Masalah tidur dan tekanan kerja. Berat 68kg, BMI 27. Disyorkan program EOL+ untuk mulakan rawatan holistik.',
    'pkg-eol-plus', 'EOL+',
    now() - interval '2 days',
    now() + interval '26 days',
    'active', 'Bujang', 'Peguam', 'Firma Undang-Undang Rashidah & Co', v_coach_id
  );

  -- Pesakit 4: Khalid — OBP1, selesai (pesakit tamat program)
  INSERT INTO psy_patients (
    id, user_id, mrn, ic_number, date_of_birth, gender, address,
    emergency_contact_name, emergency_contact_phone,
    medical_condition, condition_duration, medical_notes,
    active_package_id, active_package_name,
    package_purchased_at, package_expires_at,
    status, marital_status, occupation, company, coach_id
  ) VALUES (
    v_khalid_pid, v_khalid_uid, 'ISW-2023-003', '680112-06-4432',
    '1968-01-12', 'M',
    'No. 3, Lorong Masjid, Kampung Baru, 50300 Kuala Lumpur',
    'Ibrahim bin Ali', '0134455667',
    'Gout, Sakit Sendi', '5 tahun',
    'Program tamat. Keputusan cemerlang — berat turun 9.2kg dari 88kg ke 78.8kg. BP normal. Gout berkurangan 80%. Disyorkan untuk maintenance dengan pakej 777 VIP.',
    'pkg-obp1', 'OBP 1',
    now() - interval '14 weeks',
    now() - interval '2 weeks',
    'active', 'Berkahwin', 'Ustaz / Pendakwah', 'Masjid Al-Falah KL', v_coach_id
  );


  -- ── TREATMENT PLANS ─────────────────────────────────────────
  -- Plan 1: Siti Aminah — OBP1, Minggu 3
  INSERT INTO psy_treatment_plans (
    id, patient_id, doctor_id, name, template,
    duration_weeks, current_week, status,
    bio_goals, psycho_goals, social_goals, spiritual_goals,
    coaching_schedule, created_at
  ) VALUES (
    v_siti_plan, v_siti_pid, v_staff_id,
    'OBP1 — Siti Aminah', 'pkg-obp1',
    12, 3, 'active',
    '["Peminuman IB mengikut jadual harian","Air Afiyah 1 botol setiap hari","Herba Thoharah (20 sesi)","IV Saline Drip (4 set)","Pantau vitals mingguan"]'::jsonb,
    '["Bimbingan Terapi Reaksi Pemulihan","Bimbingan Terapi Diet dan Nutrisi","Mood tracker harian","6 Kelas Online New Life Challenge"]'::jsonb,
    '["Pemantauan Coach berterusan","Konsultasi Bersama Hakeema"]'::jsonb,
    '["Bimbingan Terapi Zikir Bersanad","Perubatan Rohani Online bersama Coach Fares"]'::jsonb,
    '[
      {"week":1,"title":"Pengenalan & Peminuman IB Pertama","tasks":["Minum IB 50ml pagi","Minum Air Afiyah","Timbang berat","Rekod BP"]},
      {"week":2,"title":"Adaptasi & Pemantauan Reaksi","tasks":["Minum IB 50ml 2x/hari","Air Afiyah 1 botol","Herba Thoharah sesi 1","Log mood harian"]},
      {"week":3,"title":"Tingkat Dos & Semakan Progress","tasks":["Minum IB 100ml/hari","Pantau vitals","Sesi coaching","Journaling"]},
      {"week":4,"title":"Stabilisasi & Detoks Lanjutan","tasks":["IB 100ml/hari","IV Saline Drip sesi 1","Semak DNA Test"]},
      {"week":5,"title":"Pertengahan Program","tasks":["IB 100ml/hari","Herba Thoharah sesi 5","Semak semula matlamat"]},
      {"week":6,"title":"Semakan Tengah Program","tasks":["Konsultasi Hakeema","Timbang berat","Semak BP"]},
      {"week":7,"title":"Intensif Detoks","tasks":["IB 150ml/hari","Air Afiyah 2 botol","Enema Kit sesi 1"]},
      {"week":8,"title":"Pemulihan & Recharge","tasks":["IB 100ml/hari","Kelas NLC sesi 4","Semak kemajuan"]},
      {"week":9,"title":"Pra-Tamat","tasks":["Kurangkan IB ke 50ml","Pantau vitals akhir"]},
      {"week":10,"title":"Program Akhir","tasks":["IB 50ml/hari","Semua rekod vitals"]},
      {"week":11,"title":"Penutup Program","tasks":["Laporan akhir","Semak DNA result"]},
      {"week":12,"title":"Graduation & Maintenance Plan","tasks":["Sesi penutup","Rancang maintenance","Cadangan pakej lanjutan"]}
    ]'::jsonb,
    now() - interval '2 weeks'
  );

  -- Plan 2: Hafizuddin — OBPX1, Minggu 8
  INSERT INTO psy_treatment_plans (
    id, patient_id, doctor_id, name, template,
    duration_weeks, current_week, status,
    bio_goals, psycho_goals, social_goals, spiritual_goals,
    coaching_schedule, created_at
  ) VALUES (
    v_hafiz_plan, v_hafiz_pid, v_staff_id,
    'OBPX1 — Hafizuddin', 'pkg-obpx1',
    24, 8, 'active',
    '["Peminuman IB mengikut jadual (12 KG)","Air Afiyah 1 botol/hari","Herba Thoharah (26 sesi)","IV Saline Drip (4 set)","Herba Kolon 4 set","DNA Test"]'::jsonb,
    '["Bimbingan Terapi Reaksi Pemulihan","6 Kelas Online New Life Challenge","Mood tracker harian"]'::jsonb,
    '["Pemantauan Coach berterusan","Konsultasi Hakeema"]'::jsonb,
    '["Zikir Bersanad","Bimbingan Terapi Penyucian Aura","Perubatan Rohani Coach Fares"]'::jsonb,
    '[{"week":1,"title":"Permulaan OBPX1"},{"week":2,"title":"Adaptasi"},{"week":3,"title":"Detoks Fasa 1"},
     {"week":4,"title":"IV Drip Sesi 1"},{"week":5,"title":"Pertengahan"},{"week":6,"title":"Semakan"},
     {"week":7,"title":"Intensif"},{"week":8,"title":"Lanjutan"},{"week":9,"title":"Stabilisasi"},
     {"week":10,"title":"Fasa 2 Mula"},{"week":11,"title":"Fasa 2"},{"week":12,"title":"Tamat Fasa 1"}]'::jsonb,
    now() - interval '7 weeks'
  );

  -- Plan 3: Rashidah — EOL+, Minggu 1
  INSERT INTO psy_treatment_plans (
    id, patient_id, doctor_id, name, template,
    duration_weeks, current_week, status,
    bio_goals, psycho_goals, social_goals, spiritual_goals,
    coaching_schedule, created_at
  ) VALUES (
    v_rashidah_plan, v_rashidah_pid, v_staff_id,
    'EOL+ — Rashidah', 'pkg-eol-plus',
    4, 1, 'active',
    '["Young & Healthy Honey 1 sudu besar 2x/hari","Minum air 2.5L sehari","Pantau berat & BP mingguan","Jalan kaki 20 min/hari"]'::jsonb,
    '["Mood tracker harian","Journaling (3 perkara syukur)","Breathing exercise 4-7-8"]'::jsonb,
    '["Aktif dalam Whatsapp Group Support","Hadir 1 Sesi Konsultasi Coach Online","Family wellness sharing"]'::jsonb,
    '["Perubatan Rohani bersama Sheikh Fares","Zikir pagi petang","Solat penuh 5 waktu","Tadarus Al-Quran harian"]'::jsonb,
    '[{"week":1,"title":"Pengenalan & Mulakan Madu"},{"week":2,"title":"Adaptasi & Pemantauan"},
     {"week":3,"title":"Konsultasi Coach"},{"week":4,"title":"Penutup & Penilaian"}]'::jsonb,
    now() - interval '2 days'
  );

  -- Plan 4: Khalid — OBP1, Selesai
  INSERT INTO psy_treatment_plans (
    id, patient_id, doctor_id, name, template,
    duration_weeks, current_week, status,
    bio_goals, psycho_goals, social_goals, spiritual_goals,
    coaching_schedule, created_at
  ) VALUES (
    v_khalid_plan, v_khalid_pid, v_staff_id,
    'OBP1 — Khalid (Selesai)', 'pkg-obp1',
    12, 12, 'completed',
    '["Peminuman IB selesai","Semua sesi Herba Thoharah selesai"]'::jsonb,
    '["Program lengkap — mood stabil"]'::jsonb,
    '["Semua sesi coaching selesai"]'::jsonb,
    '["Zikir bersanad diamalkan"]'::jsonb,
    '[]'::jsonb,
    now() - interval '14 weeks'
  );


  -- ── APPOINTMENTS ────────────────────────────────────────────
  -- Siti: W1 selesai, W2 selesai, W3 akan datang
  INSERT INTO psy_appointments (patient_id, staff_id, patient_name, staff_name, service, appointment_time, duration_min, status, room, notes) VALUES
  (v_siti_pid, v_coach_id, 'Siti Aminah binti Ahmad', v_coach_name,
   'Sesi Coaching OBP1 — Minggu 1',
   now() - interval '2 weeks' + interval '2 days', 60, 'completed', 'Bilik 1',
   'Sesi pertama berjalan lancar. Pesakit faham cara peminuman IB. Semak berat awal 83.5kg, BP 142/92.'),
  (v_siti_pid, v_coach_id, 'Siti Aminah binti Ahmad', v_coach_name,
   'Sesi Coaching OBP1 — Minggu 2',
   now() - interval '1 week' + interval '2 days', 60, 'completed', 'Bilik 1',
   'Reaksi pemulihan ringan — kepenatan. Coach explain adalah normal. Berat turun 1.2kg. BP 138/88.'),
  (v_siti_pid, v_coach_id, 'Siti Aminah binti Ahmad', v_coach_name,
   'Sesi Coaching OBP1 — Minggu 3',
   now() + interval '2 days', 60, 'scheduled', 'Bilik 1',
   NULL);

  -- Hafiz: W8 akan datang
  INSERT INTO psy_appointments (patient_id, staff_id, patient_name, staff_name, service, appointment_time, duration_min, status, room, notes) VALUES
  (v_hafiz_pid, v_coach_id, 'Encik Hafizuddin bin Rashid', v_coach_name,
   'Sesi Coaching OBPX1 — Minggu 8',
   now() + interval '3 days', 60, 'scheduled', 'Bilik 2',
   NULL);

  -- Rashidah: W1 scheduled
  INSERT INTO psy_appointments (patient_id, staff_id, patient_name, staff_name, service, appointment_time, duration_min, status, room, notes) VALUES
  (v_rashidah_pid, v_coach_id, 'Puan Rashidah binti Yusof', v_coach_name,
   'Sesi Coaching EOL+ — Minggu 1',
   now() + interval '5 days', 45, 'scheduled', 'Online',
   'Sesi pertama via Google Meet. Hantar link ke email pesakit.');


  -- ── PLAN WEEKLY PROGRESS ────────────────────────────────────
  -- Siti: W1 + W2 selesai
  INSERT INTO psy_plan_weekly_progress (plan_id, patient_id, week_number, status, score, notes, updated_by, updated_by_name, session_date) VALUES
  (v_siti_plan, v_siti_pid, 1, 'hadir', 7,
   'Pesakit positif dan bersemangat. Peminuman IB lancar. Sedikit rasa loya hari ke-3 — explain reaksi pemulihan normal. Berat turun 1.2kg.',
   v_coach_id, v_coach_name, now() - interval '2 weeks' + interval '2 days'),
  (v_siti_plan, v_siti_pid, 2, 'hadir', 8,
   'Reaksi pemulihan berlalu. Tenaga meningkat. BP turun ke 138/88 dari 142/92. Konsisten dengan jadual minum. Mood lebih baik, tidur lena.',
   v_coach_id, v_coach_name, now() - interval '1 week' + interval '2 days');

  -- Hafiz: W1-W7 selesai
  INSERT INTO psy_plan_weekly_progress (plan_id, patient_id, week_number, status, score, notes, updated_by, updated_by_name, session_date) VALUES
  (v_hafiz_plan, v_hafiz_pid, 1, 'hadir', 8, 'Sesi pertama sangat baik. Pesakit berpengalaman, mudah faham arahan.', v_coach_id, v_coach_name, now() - interval '7 weeks'),
  (v_hafiz_plan, v_hafiz_pid, 2, 'hadir', 7, 'Gula darah mula stabil. Konsisten dengan peminuman IB.', v_coach_id, v_coach_name, now() - interval '6 weeks'),
  (v_hafiz_plan, v_hafiz_pid, 3, 'hadir', 9, 'Berat turun 2.1kg. Tenaga meningkat. Gout berkurangan.', v_coach_id, v_coach_name, now() - interval '5 weeks'),
  (v_hafiz_plan, v_hafiz_pid, 4, 'cancel', NULL, 'Pesakit ada urusan luar negara — dibatalkan. Reschedule minggu depan.', v_coach_id, v_coach_name, now() - interval '4 weeks'),
  (v_hafiz_plan, v_hafiz_pid, 5, 'hadir', 8, 'Pulih sepenuhnya dari perjalanan. Rekod vitals semua baik.', v_coach_id, v_coach_name, now() - interval '3 weeks'),
  (v_hafiz_plan, v_hafiz_pid, 6, 'hadir', 9, 'Konsultasi Hakeema selesai. Sangat positif dengan perkembangan.', v_coach_id, v_coach_name, now() - interval '2 weeks'),
  (v_hafiz_plan, v_hafiz_pid, 7, 'hadir', 8, 'IV Drip sesi 2 selesai. Berat total turun 5.8kg dari berat awal.', v_coach_id, v_coach_name, now() - interval '1 week');

  -- Khalid: Semua 12 minggu selesai
  INSERT INTO psy_plan_weekly_progress (plan_id, patient_id, week_number, status, score, notes, updated_by, updated_by_name, session_date) VALUES
  (v_khalid_plan, v_khalid_pid,  1, 'hadir', 8, 'Permulaan yang cemerlang.', v_coach_id, v_coach_name, now() - interval '13 weeks'),
  (v_khalid_plan, v_khalid_pid,  2, 'hadir', 7, 'Reaksi pemulihan ringan.', v_coach_id, v_coach_name, now() - interval '12 weeks'),
  (v_khalid_plan, v_khalid_pid,  3, 'hadir', 8, 'Gout berkurangan.', v_coach_id, v_coach_name, now() - interval '11 weeks'),
  (v_khalid_plan, v_khalid_pid,  4, 'hadir', 9, 'Berat turun 3kg.', v_coach_id, v_coach_name, now() - interval '10 weeks'),
  (v_khalid_plan, v_khalid_pid,  5, 'hadir', 8, 'Mood sangat baik.', v_coach_id, v_coach_name, now() - interval '9 weeks'),
  (v_khalid_plan, v_khalid_pid,  6, 'reschedule', 6, 'Tangguh seminggu kerana urusan dakwah.', v_coach_id, v_coach_name, now() - interval '8 weeks'),
  (v_khalid_plan, v_khalid_pid,  7, 'hadir', 9, 'Kembali semangat. Rekod terbaik.', v_coach_id, v_coach_name, now() - interval '7 weeks'),
  (v_khalid_plan, v_khalid_pid,  8, 'hadir', 9, 'BP normal 120/80. Gout hampir hilang.', v_coach_id, v_coach_name, now() - interval '6 weeks'),
  (v_khalid_plan, v_khalid_pid,  9, 'hadir', 8, 'Berat turun 7kg dari awal.', v_coach_id, v_coach_name, now() - interval '5 weeks'),
  (v_khalid_plan, v_khalid_pid, 10, 'hadir', 9, 'Hampir sempurna — konsisten luar biasa.', v_coach_id, v_coach_name, now() - interval '4 weeks'),
  (v_khalid_plan, v_khalid_pid, 11, 'hadir', 9, 'DNA result: peningkatan ketara.', v_coach_id, v_coach_name, now() - interval '3 weeks'),
  (v_khalid_plan, v_khalid_pid, 12, 'hadir', 10, 'Program tamat! Berat akhir 78.8kg (-9.2kg). BP 118/76. Tiada gout. Graduation.', v_coach_id, v_coach_name, now() - interval '2 weeks');


  -- ── VITALS ──────────────────────────────────────────────────
  -- Siti: Vitals W1 (mula & akhir) + W2 (mula & akhir)
  INSERT INTO psy_vitals (patient_id, recorded_by, recorded_by_name, bp_systolic, bp_diastolic, heart_rate, spo2, temperature, weight, height, bmi, waist_cm, rbs, phq2_score, notes, created_at) VALUES
  -- W1 Mula (masuk program)
  (v_siti_pid, v_staff_id, v_staff_name, 142, 92, 84, 97.5, 36.8, 83.5, 158.0, 33.5, 98.0, 6.8, 3,
   'Rekod awal masuk program OBP1. BP tinggi, berat 83.5kg. Disyorkan kurangkan gula.', now() - interval '14 days'),
  -- W1 Akhir
  (v_siti_pid, v_coach_id, v_coach_name, 138, 90, 80, 98.0, 36.7, 82.3, 158.0, 33.0, 96.5, 6.4, 2,
   'Akhir Minggu 1. Berat turun 1.2kg. BP mula turun sedikit. Reaksi pemulihan sudah berlalu.', now() - interval '7 days' - interval '12 hours'),
  -- W2 Mula
  (v_siti_pid, v_coach_id, v_coach_name, 136, 88, 78, 98.0, 36.6, 82.3, 158.0, 33.0, 96.5, 6.2, 2,
   'Mula Minggu 2. Pesakit lebih cergas.', now() - interval '7 days'),
  -- W2 Akhir
  (v_siti_pid, v_coach_id, v_coach_name, 134, 86, 76, 98.5, 36.5, 81.0, 158.0, 32.5, 95.0, 5.9, 1,
   'Akhir Minggu 2. Berat turun lagi 1.3kg. BP 134/86 — peningkatan baik. PHQ2 berkurangan.', now() - interval '1 day');

  -- Hafiz: Vitals mingguan W1-W7
  INSERT INTO psy_vitals (patient_id, recorded_by, recorded_by_name, bp_systolic, bp_diastolic, heart_rate, spo2, temperature, weight, height, bmi, waist_cm, rbs, notes, created_at) VALUES
  (v_hafiz_pid, v_staff_id, v_staff_name, 138, 88, 82, 97.8, 36.9, 92.0, 172.0, 31.1, 102.0, 7.8, 'Rekod awal OBPX1. Gula darah masih tinggi.', now() - interval '7 weeks'),
  (v_hafiz_pid, v_coach_id, v_coach_name, 136, 86, 80, 98.0, 36.8, 91.2, 172.0, 30.8, 101.0, 7.4, 'Minggu 2. Gula turun sedikit.', now() - interval '6 weeks'),
  (v_hafiz_pid, v_coach_id, v_coach_name, 132, 84, 78, 98.2, 36.7, 89.9, 172.0, 30.4, 100.0, 7.1, 'Minggu 3. Berat turun 2.1kg. Gout berkurangan.', now() - interval '5 weeks'),
  (v_hafiz_pid, v_coach_id, v_coach_name, 130, 82, 76, 98.5, 36.6, 89.9, 172.0, 30.4,  99.5, 6.9, 'Minggu 5 (W4 skip). BP terus baik.', now() - interval '3 weeks'),
  (v_hafiz_pid, v_coach_id, v_coach_name, 128, 80, 74, 98.5, 36.5, 88.5, 172.0, 29.9,  98.0, 6.6, 'Minggu 6. Sangat konsisten.', now() - interval '2 weeks'),
  (v_hafiz_pid, v_coach_id, v_coach_name, 126, 78, 72, 98.8, 36.4, 86.8, 172.0, 29.3,  97.0, 6.3, 'Minggu 7. Berat turun 5.2kg total. BP hampir normal.', now() - interval '1 week');


  -- ── PLAN COMPLIANCE ─────────────────────────────────────────
  -- Siti W1 & W2
  INSERT INTO psy_plan_compliance (plan_id, patient_id, week_number, madu_sudu, nafas_kali, bumi_minit, berjemur, pantang, kelapa_kali, kolon_kali, notes) VALUES
  (v_siti_plan, v_siti_pid, 1, 7, 30, 20, true,  true,  3, 0, 'Minggu pertama: konsisten dengan madu 1 sudu, berjemur 20 minit pagi. Pantang makanan manis dipatuhi.'),
  (v_siti_plan, v_siti_pid, 2, 7, 35, 25, true,  true,  4, 1, 'Minggu 2: nafas bertambah baik. Mula kolon 1x. Pantang dikekalkan sepenuhnya.');

  -- Hafiz W1-W7
  INSERT INTO psy_plan_compliance (plan_id, patient_id, week_number, madu_sudu, nafas_kali, bumi_minit, berjemur, pantang, kelapa_kali, kolon_kali, notes) VALUES
  (v_hafiz_plan, v_hafiz_pid, 1, 7, 40, 30, true,  true,  5, 0, 'Konsisten dari hari pertama.'),
  (v_hafiz_plan, v_hafiz_pid, 2, 7, 40, 30, true,  true,  5, 0, 'Tiada masalah.'),
  (v_hafiz_plan, v_hafiz_pid, 3, 7, 45, 30, true,  true,  7, 1, 'Tambah kelapa & mula kolon.'),
  (v_hafiz_plan, v_hafiz_pid, 4, 0,  0,  0, false, false, 0, 0, 'CANCEL — luar negara. Tiada rekod.'),
  (v_hafiz_plan, v_hafiz_pid, 5, 7, 40, 30, true,  true,  5, 1, 'Kembali konsisten.'),
  (v_hafiz_plan, v_hafiz_pid, 6, 7, 45, 35, true,  true,  7, 1, 'Terbaik minggu ini.'),
  (v_hafiz_plan, v_hafiz_pid, 7, 7, 50, 35, true,  true,  7, 2, 'Kolon 2x minggu ini. Sangat baik.');


  -- ── COACHING SESSIONS ───────────────────────────────────────
  -- Siti W1 & W2
  INSERT INTO psy_coaching_sessions (patient_id, coach_id, patient_name, pillar, session_date, duration_min, mood_pre, mood_post, notes, goals_discussed, homework, status) VALUES
  (v_siti_pid, v_coach_id, 'Siti Aminah binti Ahmad', 'bio',
   now() - interval '13 days', 60, 5, 7,
   'Sesi Bio Minggu 1: Semak peminuman IB, terang cara Air Afiyah, bincang reaksi pemulihan yang mungkin berlaku.',
   '["Cara betul minum IB","Jadual Air Afiyah","Makanan pantang"]'::jsonb,
   '["Log berat badan setiap pagi","Minum 2.5L air sehari","Elakkan gula & tepung"]'::jsonb,
   'completed'),
  (v_siti_pid, v_coach_id, 'Siti Aminah binti Ahmad', 'psycho',
   now() - interval '12 days', 45, 5, 8,
   'Sesi Psikologi Minggu 1: Perbincangan tentang motivasi, set matlamat, dan teknik journaling untuk rekod kemajuan.',
   '["Matlamat program","Motivasi dalaman","Teknik journaling"]'::jsonb,
   '["Tulis 3 perkara syukur setiap malam","Rekod mood harian dalam app","Tonton video BPS-S"]'::jsonb,
   'completed'),
  (v_siti_pid, v_coach_id, 'Siti Aminah binti Ahmad', 'bio',
   now() - interval '6 days', 60, 7, 9,
   'Sesi Bio Minggu 2: Semak rekod vitals, bincang reaksi pemulihan yang telah berlalu, tingkatkan dos IB ke 100ml.',
   '["Semakan vitals W1","Tingkat dos IB","Herba Thoharah sesi 1"]'::jsonb,
   '["Minum IB 100ml/hari","Herba Thoharah minggu ini","Rekod BP setiap hari"]'::jsonb,
   'completed'),
  (v_siti_pid, v_coach_id, 'Siti Aminah binti Ahmad', 'spiritual',
   now() - interval '5 days', 30, 7, 9,
   'Sesi Rohani Minggu 2: Ajar zikir syifa pagi petang, bincang kaitan iman dan proses penyembuhan.',
   '["Zikir Syifa","Solat sebagai ubat","Tawakkal dalam pemulihan"]'::jsonb,
   '["Amalkan zikir pagi petang","Solat sunat syukur","Baca surah Al-Fatihah 7x selepas Subuh"]'::jsonb,
   'completed');

  -- Hafiz W1-W7 summary sessions
  INSERT INTO psy_coaching_sessions (patient_id, coach_id, patient_name, pillar, session_date, duration_min, mood_pre, mood_post, notes, goals_discussed, homework, status) VALUES
  (v_hafiz_pid, v_coach_id, 'Encik Hafizuddin bin Rashid', 'bio', now() - interval '7 weeks', 60, 6, 8, 'Sesi 1: Orientasi program OBPX1.', '["Cara peminuman","Jadual 24 minggu"]'::jsonb, '["Mula peminuman IB"]'::jsonb, 'completed'),
  (v_hafiz_pid, v_coach_id, 'Encik Hafizuddin bin Rashid', 'bio', now() - interval '6 weeks', 60, 7, 8, 'Sesi 2: Gula darah mula turun.', '["Monitor RBS","Diet gula rendah"]'::jsonb, '["Pantau RBS 2x/hari"]'::jsonb, 'completed'),
  (v_hafiz_pid, v_coach_id, 'Encik Hafizuddin bin Rashid', 'bio', now() - interval '5 weeks', 60, 8, 9, 'Sesi 3: Gout berkurangan ketara.', '["Sebab gout berkurangan","Kesan IB pada asid urik"]'::jsonb, '["Elakkan makanan purin tinggi"]'::jsonb, 'completed'),
  (v_hafiz_pid, v_coach_id, 'Encik Hafizuddin bin Rashid', 'bio', now() - interval '3 weeks', 60, 7, 9, 'Sesi 5: Kembali selepas perjalanan luar negara.', '["Pengurusan program semasa travel"]'::jsonb, '["Sambung jadual biasa"]'::jsonb, 'completed'),
  (v_hafiz_pid, v_coach_id, 'Encik Hafizuddin bin Rashid', 'psycho', now() - interval '2 weeks', 45, 8, 9, 'Sesi 6: Konsultasi Hakeema. Pesakit sangat puas.', '["Semakan psikologi","Strategi kekalkan motivasi"]'::jsonb, '["Journaling weekly"]'::jsonb, 'completed'),
  (v_hafiz_pid, v_coach_id, 'Encik Hafizuddin bin Rashid', 'bio', now() - interval '1 week', 60, 8, 9, 'Sesi 7: IV Drip sesi 2 selesai. Rekod sangat baik.', '["Rekod 7 minggu","Target 8-24 minggu"]'::jsonb, '["Teruskan jadual","Sedia IV Drip sesi 3"]'::jsonb, 'completed');


  -- ── DAILY CHECK-INS ─────────────────────────────────────────
  -- Siti: 14 hari (W1 + W2)
  INSERT INTO psy_daily_checkins (patient_id, checkin_date, mood_score, energy_score, sleep_quality, sleep_hours, symptoms, activities, notes) VALUES
  (v_siti_pid, CURRENT_DATE - 13, 5, 4, 6, 6.5, '["Loya ringan","Sakit kepala"]'::jsonb, '["Minum IB","Zikir pagi"]'::jsonb, 'Hari pertama minum IB. Rasa sedikit loya tapi teruskan.'),
  (v_siti_pid, CURRENT_DATE - 12, 5, 5, 6, 7.0, '["Loya ringan"]'::jsonb, '["Minum IB","Jalan kaki 20 min","Zikir pagi"]'::jsonb, 'Loya berkurangan. Tidur lebih baik malam tadi.'),
  (v_siti_pid, CURRENT_DATE - 11, 6, 5, 7, 7.0, '[]'::jsonb, '["Minum IB","Air Afiyah","Senaman fitrah","Zikir pagi petang"]'::jsonb, 'Rasa lebih baik hari ini. Tiada loya.'),
  (v_siti_pid, CURRENT_DATE - 10, 7, 6, 7, 7.5, '[]'::jsonb, '["Minum IB","Air Afiyah","Jalan kaki","Journaling"]'::jsonb, 'Tenaga mula meningkat. Berat turun 0.5kg.'),
  (v_siti_pid, CURRENT_DATE -  9, 7, 7, 8, 8.0, '[]'::jsonb, '["Minum IB","Air Afiyah","Berjemur 20 min","Zikir"]'::jsonb, 'Tidur lena. Rasa segar pagi ini.'),
  (v_siti_pid, CURRENT_DATE -  8, 7, 7, 8, 7.5, '[]'::jsonb, '["Minum IB","Air Afiyah","Senaman","Zikir","Journaling"]'::jsonb, 'Konsisten dengan semua aktiviti. Mood baik.'),
  (v_siti_pid, CURRENT_DATE -  7, 8, 7, 8, 8.0, '[]'::jsonb, '["Minum IB","Air Afiyah","Berjemur","Zikir","Jalan kaki 30 min"]'::jsonb, 'Sesi coaching W1 hari ini. Coach cakap perkembangan sangat baik!'),
  (v_siti_pid, CURRENT_DATE -  6, 8, 8, 8, 8.0, '[]'::jsonb, '["Minum IB 100ml","Air Afiyah","Senaman fitrah","Zikir pagi petang"]'::jsonb, 'Mula dos baru 100ml. Rasa lebih bertenaga.'),
  (v_siti_pid, CURRENT_DATE -  5, 8, 8, 9, 8.0, '[]'::jsonb, '["Minum IB","Air Afiyah","Herba Thoharah","Berjemur","Journaling"]'::jsonb, 'Herba Thoharah sesi pertama dengan coach. Sangat baik!'),
  (v_siti_pid, CURRENT_DATE -  4, 8, 8, 8, 8.0, '[]'::jsonb, '["Minum IB","Air Afiyah","Jalan kaki 30 min","Zikir"]'::jsonb, 'BP tadi 134/85 — bagus! Berat 81.5kg.'),
  (v_siti_pid, CURRENT_DATE -  3, 9, 8, 9, 8.5, '[]'::jsonb, '["Minum IB","Air Afiyah","Senaman","Zikir","Tadarus Quran"]'::jsonb, 'Rasa sangat sihat dan tenang. Tidur terbaik sepanjang program.'),
  (v_siti_pid, CURRENT_DATE -  2, 8, 8, 8, 8.0, '[]'::jsonb, '["Minum IB","Air Afiyah","Berjemur","Zikir","Journaling"]'::jsonb, 'Konsisten. Pakaian dah rasa longgar!'),
  (v_siti_pid, CURRENT_DATE -  1, 8, 9, 9, 8.0, '[]'::jsonb, '["Minum IB","Air Afiyah","Jalan kaki 40 min","Zikir pagi petang","Journaling"]'::jsonb, 'Semalam sesi coaching W2 — result bagus. Berat 81kg!'),
  (v_siti_pid, CURRENT_DATE,     8, 8, 8, 7.5, '[]'::jsonb, '["Minum IB","Air Afiyah","Senaman fitrah","Zikir"]'::jsonb, 'Hari pertama Minggu 3. Sedia untuk sesi coaching Rabu ini!');

  -- Rashidah: 2 hari check-in baru
  INSERT INTO psy_daily_checkins (patient_id, checkin_date, mood_score, energy_score, sleep_quality, sleep_hours, symptoms, activities, notes) VALUES
  (v_rashidah_pid, CURRENT_DATE - 1, 5, 5, 4, 5.0, '["Susah tidur","Bimbang"]'::jsonb, '["Minum madu pagi"]'::jsonb, 'Hari pertama program. Sedikit anxious tapi excited nak cuba.'),
  (v_rashidah_pid, CURRENT_DATE,     6, 5, 5, 5.5, '["Sedikit bimbang"]'::jsonb, '["Minum madu pagi","Jalan kaki 15 min","Breathing exercise"]'::jsonb, 'Lebih baik dari semalam. Cuba breathing 4-7-8, rasa tenang sikit.');


  -- ── PAYMENTS ────────────────────────────────────────────────
  INSERT INTO psy_payments (receipt_ref, patient_id, user_id, items, subtotal, service_charge, sst, total, payment_method, status, notes, paid_at) VALUES
  ('RCP-2024-001', v_siti_pid, v_siti_uid,
   '[{"name":"OBP 1 (12 Minggu)","qty":1,"price":2999}]'::jsonb,
   2999, 0, 0, 2999, 'transfer', 'completed',
   'Bayaran pakej OBP1. Transfer bank. Disahkan oleh admin.', now() - interval '2 weeks'),
  ('RCP-2024-002', v_siti_pid, v_siti_uid,
   '[{"name":"Starter Kit ISW","qty":1,"price":350},{"name":"Air Afiyah 12 Botol","qty":1,"price":440}]'::jsonb,
   790, 0, 0, 790, 'fpx', 'completed',
   'Produk tambahan untuk program OBP1.', now() - interval '13 days'),
  ('RCP-2023-007', v_hafiz_pid, v_hafiz_uid,
   '[{"name":"OBPX 1 (24 Minggu)","qty":1,"price":5499}]'::jsonb,
   5499, 0, 0, 5499, 'transfer', 'completed',
   'Bayaran pakej OBPX1. Pesakit VIP.', now() - interval '7 weeks'),
  ('RCP-2024-012', v_rashidah_pid, v_rashidah_uid,
   '[{"name":"EOL+ (4 Minggu)","qty":1,"price":499}]'::jsonb,
   499, 0, 0, 499, 'card', 'completed',
   'Bayaran pakej EOL+. Pesakit baru.', now() - interval '2 days'),
  ('RCP-2023-003', v_khalid_pid, v_khalid_uid,
   '[{"name":"OBP 1 (12 Minggu)","qty":1,"price":2999}]'::jsonb,
   2999, 0, 0, 2999, 'transfer', 'completed',
   'Bayaran pakej OBP1. Program sudah selesai.', now() - interval '14 weeks');


  -- ── ORDERS ──────────────────────────────────────────────────
  INSERT INTO psy_orders (order_ref, patient_id, items, total, status, delivery_method, delivery_address, shipped_at, delivered_at) VALUES
  ('ORD-2024-001', v_siti_uid,
   '[{"product_id":"starter-kit","name":"Starter Kit ISW","qty":1,"price":350},{"product_id":"air-afiyah-12btl","name":"Air Afiyah 12 Botol","qty":1,"price":440}]'::jsonb,
   790, 'delivered', 'pos',
   'No. 12, Jalan Bahagia 3, Taman Maju, 68000 Ampang, Selangor',
   now() - interval '11 days', now() - interval '9 days'),
  ('ORD-2023-007', v_hafiz_uid,
   '[{"product_id":"ib-1kg","name":"IB 1kg","qty":6,"price":1080},{"product_id":"air-afiyah-12btl","name":"Air Afiyah 12 Botol","qty":1,"price":440}]'::jsonb,
   1520, 'delivered', 'pos',
   'No. 45, Jalan Kenari 7, Bandar Baru Bangi, 43000 Kajang, Selangor',
   now() - interval '6 weeks' + interval '3 days', now() - interval '6 weeks' + interval '5 days'),
  ('ORD-2024-012', v_rashidah_uid,
   '[{"product_id":"madu-yhh-500g","name":"Young & Healthy Honey 500g","qty":2,"price":190}]'::jsonb,
   190, 'shipped', 'pos',
   'No. 8, Jalan Dahlia 2, Taman Bunga, 41000 Klang, Selangor',
   now() - interval '1 day', NULL);


  -- ── WEEKLY FEEDBACK ─────────────────────────────────────────
  -- Siti: feedback W1 & W2
  INSERT INTO psy_weekly_feedback (plan_id, patient_id, week_number, rating, comment) VALUES
  (v_siti_plan, v_siti_pid, 1, 4,
   'Alhamdulillah, minggu pertama berjalan baik walaupun ada sedikit loya. Coach sangat membantu dan sabar menjawab soalan saya. Rasa lebih tenang dan yakin dengan program ini.'),
  (v_siti_plan, v_siti_pid, 2, 5,
   'Minggu 2 jauh lebih baik! Tenaga bertambah, tidur lena dan BP sudah turun. Berat turun 2.5kg total — saya sangat happy! Terima kasih Coach.');

  -- Hafiz: feedback W1-W7
  INSERT INTO psy_weekly_feedback (plan_id, patient_id, week_number, rating, comment) VALUES
  (v_hafiz_plan, v_hafiz_pid, 1, 5, 'Sesi pertama sangat informatif. Saya dah berpengalaman dengan cara hidup sihat jadi mudah adapt.'),
  (v_hafiz_plan, v_hafiz_pid, 2, 4, 'Gula darah mula turun! Saya amat gembira dengan perkembangan ini.'),
  (v_hafiz_plan, v_hafiz_pid, 3, 5, 'Gout dah berkurangan 60%. Ini yang saya tunggu-tunggu!'),
  (v_hafiz_plan, v_hafiz_pid, 5, 4, 'Kembali dari perjalanan dan terus sambung. Coach sangat understanding.'),
  (v_hafiz_plan, v_hafiz_pid, 6, 5, 'Konsultasi Hakeema sangat bermakna. Saya rasa dipedulikan.'),
  (v_hafiz_plan, v_hafiz_pid, 7, 5, 'Berat turun 5.8kg! Target 8kg dalam 12 minggu nampaknya boleh capai.');

  -- Khalid: feedback semua 12 minggu
  INSERT INTO psy_weekly_feedback (plan_id, patient_id, week_number, rating, comment) VALUES
  (v_khalid_plan, v_khalid_pid,  1, 5, 'Permulaan yang sangat baik.'),
  (v_khalid_plan, v_khalid_pid,  2, 4, 'Ada reaksi pemulihan tapi semua explain dengan jelas.'),
  (v_khalid_plan, v_khalid_pid,  3, 5, 'Gout dah berkurangan!'),
  (v_khalid_plan, v_khalid_pid,  4, 5, 'Berat turun 3kg — alhamdulillah.'),
  (v_khalid_plan, v_khalid_pid,  5, 5, 'Tenaga luar biasa.'),
  (v_khalid_plan, v_khalid_pid,  6, 3, 'Terpaksa reschedule kerana urusan dakwah. Faham coach.'),
  (v_khalid_plan, v_khalid_pid,  7, 5, 'Kembali dengan lebih semangat!'),
  (v_khalid_plan, v_khalid_pid,  8, 5, 'BP 120/80 — doktor pun terkejut!'),
  (v_khalid_plan, v_khalid_pid,  9, 5, 'Berat turun 7kg. Subhanallah.'),
  (v_khalid_plan, v_khalid_pid, 10, 5, 'Konsisten dan gembira.'),
  (v_khalid_plan, v_khalid_pid, 11, 5, 'DNA result keluar — peningkatan ketara!'),
  (v_khalid_plan, v_khalid_pid, 12, 5, 'Program SELESAI! Berat turun 9.2kg. Gout hilang. Terima kasih ISW, Coach dan semua team. Saya akan recommend kepada semua!');


  -- ── RISK ALERTS ─────────────────────────────────────────────
  -- Khalid: alert lama dah resolved
  INSERT INTO psy_risk_alerts (patient_id, patient_name, created_by, created_by_name, severity, category, description, status, resolved_at) VALUES
  (v_khalid_pid, 'Ustaz Khalid bin Ibrahim', v_staff_id, v_staff_name,
   'low', 'Compliance', 'Pesakit reschedule 1 sesi pada Minggu 6 kerana urusan kerja. Perlu monitor kesinambungan.',
   'resolved', now() - interval '7 weeks');

  RAISE NOTICE 'Seed demo selesai. 4 pesakit berjaya dicipta.';
  RAISE NOTICE 'Login demo: demo.patient@isw.my / Demo@1234';

END $$;


-- ── SEMAK KEPUTUSAN ──────────────────────────────────────────

SELECT '== PESAKIT ==' AS label, COUNT(*) AS jumlah FROM psy_patients
UNION ALL SELECT '== PLAN ==',       COUNT(*) FROM psy_treatment_plans
UNION ALL SELECT '== VITALS ==',     COUNT(*) FROM psy_vitals
UNION ALL SELECT '== CHECKINS ==',   COUNT(*) FROM psy_daily_checkins
UNION ALL SELECT '== PROGRESS ==',   COUNT(*) FROM psy_plan_weekly_progress
UNION ALL SELECT '== COMPLIANCE ==', COUNT(*) FROM psy_plan_compliance
UNION ALL SELECT '== COACHING ==',   COUNT(*) FROM psy_coaching_sessions
UNION ALL SELECT '== FEEDBACK ==',   COUNT(*) FROM psy_weekly_feedback
UNION ALL SELECT '== PAYMENTS ==',   COUNT(*) FROM psy_payments
UNION ALL SELECT '== ORDERS ==',     COUNT(*) FROM psy_orders
UNION ALL SELECT '== PAKEJ ==',      COUNT(*) FROM psy_packages
UNION ALL SELECT '== PRODUK ==',     COUNT(*) FROM psy_products
UNION ALL SELECT '== INVENTORI ==',  COUNT(*) FROM psy_inventory_items;
