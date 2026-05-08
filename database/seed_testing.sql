-- ============================================================
-- SEED DATA UNTUK TESTING
-- Pakej Rawatan · Produk · Self-Help Library
--
-- Jalankan dalam Supabase SQL Editor
-- NOTA: seed_packages.sql sudah ada pakej rawatan penuh
--       Fail ini tambah seed untuk Products & Library
-- ============================================================


-- ============================================================
-- BAHAGIAN 1: PAKEJ RAWATAN (psy_packages)
-- Sama seperti seed_packages.sql — skip jika dah run
-- ============================================================

-- Uncomment baris bawah jika nak reset pakej:
-- DELETE FROM psy_packages;

INSERT INTO psy_packages (
  package_id, name, description, price, duration, duration_weeks,
  icon, bg_color, tier, is_active, sort_order,
  products, bimbingan, inclusions, bio_goals, psycho_goals, social_goals, spiritual_goals
) VALUES

-- 777 FREE
('pkg-777-free', '777 FREE', '7 hari starter · percuma', 0, '7 Hari', 1, '🎁', 'bg-cream', 'free', true, 1,
  '[]'::jsonb,
  '["Webinar 7 hari","Whatsapp Group Support"]'::jsonb,
  '["7 Hari Webinar (Diet, Rohani, Ripple)","7 Gaya Hidup Fitrah","7 Resepi Fitrah","Whatsapp Group Support"]'::jsonb,
  '["Amalkan 7 Resepi Fitrah","Minum air 2L sehari","Pantau berat badan"]'::jsonb,
  '["Tonton Webinar Diet harian","Journaling ringkas (5 min)"]'::jsonb,
  '["Sertai Whatsapp Group Support","Kenali ahli group"]'::jsonb,
  '["Tonton Webinar Rohani harian","Amalkan 7 Gaya Hidup Fitrah"]'::jsonb),

-- 777 VIP
('pkg-777-vip', '777 VIP', '7 hari VIP · coaching & support', 999, '7 Hari', 1, '⭐', 'bg-gold-light', 'vip', true, 2,
  '["Kurma Ajwa 49 Biji","Barley 500g"]'::jsonb,
  '["Webinar 7 hari","Daily Workbook","Perubatan Rohani Sheikh Fares","1:1 Coaching Diet/Nutrisi","Video Series Hakeema","Whatsapp Group Support VIP"]'::jsonb,
  '["7 Hari Webinar (Diet, Rohani, Ripple)","7 Gaya Hidup Fitrah","7 Resepi Fitrah","Whatsapp Group Support 777 VIP","Daily Workbook","Perubatan Rohani Bersama Sheikh Fares","1:1 Coaching Diet / Nutrisi 1x Sebulan","Video Series Hakeema","Kurma Ajwa 49 Biji","Barley 500g"]'::jsonb,
  '["Amalkan 7 Resepi Fitrah","Kurma Ajwa 3 biji setiap pagi","Barley drink setiap petang","Minum air 2L sehari"]'::jsonb,
  '["Siapkan Daily Workbook harian","Tonton Video Series Hakeema","1:1 Coaching Diet/Nutrisi (ikut jadual)"]'::jsonb,
  '["Aktif dalam Whatsapp Group 777 VIP","Tonton Webinar Ripple"]'::jsonb,
  '["Perubatan Rohani bersama Sheikh Fares","Tonton Webinar Rohani harian","Amalkan 7 Gaya Hidup Fitrah"]'::jsonb),

-- EOL
('pkg-eol', 'EOL', 'Entry-level · 4 minggu · 1 madu + coaching', 299, '4 Minggu', 4, '🍯', 'bg-navy-light', null, true, 3,
  '["1 (500G) Young & Healthy Honey"]'::jsonb,
  '["Whatsapp Group Support","Akses Portal ISW","1 Sesi Konsultasi Coach Online","Perubatan Rohani Sheikh Fares"]'::jsonb,
  '["1 (500G) Young & Healthy Honey","Whatsapp Group Support","Akses Portal ISW","1 Sesi Konsultasi bersama Coach secara Online","Perubatan Rohani bersama Sheikh Fares"]'::jsonb,
  '["Young & Healthy Honey 1 sudu besar setiap pagi","Minum air 2.5L sehari","Pantau berat & BP mingguan"]'::jsonb,
  '["Mood tracker harian","Journaling (3 perkara syukur)"]'::jsonb,
  '["Aktif dalam Whatsapp Group Support","Hadir 1 Sesi Konsultasi Coach Online"]'::jsonb,
  '["Perubatan Rohani bersama Sheikh Fares","Zikir pagi petang","Solat penuh 5 waktu"]'::jsonb),

-- EOL+
('pkg-eol-plus', 'EOL+', 'Enhanced · 4 minggu · 2 madu + coaching', 499, '4 Minggu', 4, '🍯', 'bg-navy-light', null, true, 4,
  '["2 (500G) Young & Healthy Honey"]'::jsonb,
  '["Whatsapp Group Support","Akses Portal ISW","1 Sesi Konsultasi Coach Online","Perubatan Rohani Sheikh Fares"]'::jsonb,
  '["2 (500G) Young & Healthy Honey","Whatsapp Group Support","Akses Portal ISW","1 Sesi Konsultasi bersama Coach secara Online","Perubatan Rohani bersama Sheikh Fares"]'::jsonb,
  '["Young & Healthy Honey 1 sudu besar 2x/hari","Minum air 2.5L sehari","Pantau berat & BP mingguan","Jalan kaki 20 min/hari"]'::jsonb,
  '["Mood tracker harian","Journaling (3 perkara syukur)","Breathing exercise 4-7-8"]'::jsonb,
  '["Aktif dalam Whatsapp Group Support","Hadir 1 Sesi Konsultasi Coach Online","Family wellness sharing"]'::jsonb,
  '["Perubatan Rohani bersama Sheikh Fares","Zikir pagi petang","Solat penuh 5 waktu","Tadarus Al-Quran harian"]'::jsonb),

-- OBP 1
('pkg-obp1', 'OBP 1', '12 minggu · 6 KG IB + full terapi', 2999, '12 Minggu', 12, '💎', 'bg-navy-light', null, true, 5,
  '["6 KG IB","6 KG YHPG","Starter Kit","12 Botol Air Afiyah","7 Botol Air Za''afaran","1 Set Herba Kolon","1 Set Enema Kit","1 Set Mesin Ozon","4 Set IV Saline Drip","1 Set DNA Test Kit"]'::jsonb,
  '["20 Sesi Herba Thoharah","6 Kelas Online New Life Challenge","Bimbingan Terapi Peminuman IB, YHPG","Bimbingan Terapi Zikir Bersanad","Bimbingan Terapi Diet dan Nutrisi","Bimbingan Terapi Gaya Hidup Fitrah","Pemantauan Coach","Konsultasi Bersama Hakeema","Perubatan Rohani Online bersama Coach Fares","Perubatan Alami Online bersama Nutritionist"]'::jsonb,
  '["6 KG IB","6 KG YHPG","Starter Kit","12 Botol Air Afiyah","7 Botol Air Za''afaran","1 Set Herba Kolon","1 Set Enema Kit","1 Set Mesin Ozon","4 Set IV Saline Drip","20 Sesi Herba Thoharah","1 Set DNA Test Kit","6 Kelas Online New Life Challenge"]'::jsonb,
  '["Peminuman IB mengikut jadual harian","Air Afiyah 1 botol setiap hari","Herba Thoharah (20 sesi)","IV Saline Drip (4 set)","DNA Test","Pantau vitals mingguan"]'::jsonb,
  '["Bimbingan Terapi Reaksi Pemulihan","Bimbingan Terapi Diet dan Nutrisi","6 Kelas Online New Life Challenge","Mood tracker harian"]'::jsonb,
  '["Pemantauan Coach berterusan","Konsultasi Bersama Hakeema","Sesi Soal Jawab bersama Nutritionist"]'::jsonb,
  '["Bimbingan Terapi Zikir Bersanad","Bimbingan Terapi Penyucian Aura","Perubatan Rohani Online bersama Coach Fares"]'::jsonb),

-- OBPX 1
('pkg-obpx1', 'OBPX 1', '12 minggu + 3 bulan ext · 12 KG IB', 5499, '12 Minggu + 3 Bulan (1 kali) + 3 Bulan (1 kali)', 24, '💎', 'bg-teal/10', null, true, 6,
  '["12 KG IB","12 KG YHPG","Starter Kit","21 Botol Air Afiyah","7 Botol Air Za''afaran","4 Set Herba Kolon","1 Set Enema Kit","1 Set Mesin Ozon","4 Set IV Saline Drip","1 Set DNA Test Kit"]'::jsonb,
  '["26 Sesi Herba Thoharah","6 Kelas Online New Life Challenge","Bimbingan Terapi lengkap","Pemantauan Coach","Konsultasi Hakeema","Perubatan Rohani Coach Fares"]'::jsonb,
  '["12 KG IB","12 KG YHPG","Starter Kit","21 Botol Air Afiyah","7 Botol Air Za''afaran","4 Set Herba Kolon","26 Sesi Herba Thoharah","1 Set DNA Test Kit","6 Kelas Online New Life Challenge"]'::jsonb,
  '["Peminuman IB mengikut jadual (12 KG)","Air Afiyah 1 botol/hari (21 botol)","Herba Thoharah (26 sesi)","IV Saline Drip (4 set)","Herba Kolon 4 set","DNA Test"]'::jsonb,
  '["Bimbingan Terapi Reaksi Pemulihan","6 Kelas Online New Life Challenge","Mood tracker harian"]'::jsonb,
  '["Pemantauan Coach berterusan","Konsultasi Hakeema","Perubatan Alami Online"]'::jsonb,
  '["Zikir Bersanad","Bimbingan Terapi Penyucian Aura","Perubatan Rohani Coach Fares"]'::jsonb),

-- OBPY 1
('pkg-obpy1', 'OBPY 1', '12 minggu + multi ext · 21 KG IB elite', 8999, '12 Minggu + 3 Bulan (1 kali) + 3 Bulan (3 bulan sekali) + 6 Bulan (3 bulan sekali)', 48, '👑', 'bg-gold-light', null, true, 7,
  '["21 KG IB","21 KG YHPG","Starter Kit","33 Botol Air Afiyah","7 Botol Air Za''afaran","7 Set Herba Kolon","1 Set Enema Kit","1 Set Mesin Ozon","4 Set IV Saline Drip","1 Set DNA Test Kit"]'::jsonb,
  '["32 Sesi Herba Thoharah","6 Kelas Online New Life Challenge","Bimbingan Terapi lengkap","Pemantauan Coach","Konsultasi Hakeema","Perubatan Rohani Coach Fares","Perubatan Alami Nutritionist"]'::jsonb,
  '["21 KG IB","21 KG YHPG","Starter Kit","33 Botol Air Afiyah","7 Botol Air Za''afaran","7 Set Herba Kolon","32 Sesi Herba Thoharah","1 Set DNA Test Kit","6 Kelas Online New Life Challenge"]'::jsonb,
  '["Peminuman IB mengikut jadual (21 KG)","Air Afiyah 1 botol/hari (33 botol)","Herba Thoharah (32 sesi)","IV Saline Drip (4 set)","Herba Kolon 7 set","DNA Test"]'::jsonb,
  '["Bimbingan Terapi Reaksi Pemulihan","6 Kelas Online New Life Challenge","Mood tracker harian","Konsultasi DNA bersama Coach"]'::jsonb,
  '["Pemantauan Coach berterusan","Konsultasi Hakeema","Perubatan Alami Online"]'::jsonb,
  '["Zikir Bersanad","Bimbingan Terapi Penyucian Aura","Perubatan Rohani Coach Fares","Solat hajat mingguan"]'::jsonb),

-- OBD 1
('pkg-obd1', 'OBD 1', '12 minggu · 6 KG LTH detox', 1999, '12 Minggu', 12, '🌱', 'bg-terracotta-light', null, true, 8,
  '["6 KG LTH","6 KG LTHPG","Starter Kit","12 Botol Air Afiyah","7 Botol Air Za''afaran","1 Set Herba Kolon","1 Set Enema Kit","1 Set Mesin Ozon","4 Set IV Saline Drip","1 Set DNA Test Kit"]'::jsonb,
  '["20 Sesi Herba Thoharah","6 Kelas Online New Life Challenge","Bimbingan Terapi Peminuman LTH, LTHPG","Bimbingan Terapi Zikir Bersanad","Bimbingan Terapi Diet dan Nutrisi","Pemantauan Coach","Konsultasi Hakeema"]'::jsonb,
  '["6 KG LTH","6 KG LTHPG","Starter Kit","12 Botol Air Afiyah","7 Botol Air Za''afaran","1 Set Herba Kolon","20 Sesi Herba Thoharah","1 Set DNA Test Kit","6 Kelas Online New Life Challenge"]'::jsonb,
  '["Peminuman LTH mengikut jadual harian","Air Afiyah 1 botol setiap hari","Herba Thoharah (20 sesi)","IV Saline Drip (4 set)","Herba Kolon mengikut arahan","Enema","DNA Test"]'::jsonb,
  '["Bimbingan Terapi Reaksi Pemulihan","Bimbingan Terapi Diet dan Nutrisi","6 Kelas Online New Life Challenge","Mood tracker"]'::jsonb,
  '["Pemantauan Coach berterusan","Konsultasi Hakeema","Sesi Soal Jawab Nutritionist","Perubatan Alami Online"]'::jsonb,
  '["Zikir Bersanad","Bimbingan Terapi Penyucian Aura","Perubatan Rohani Coach Fares","Solat hajat mingguan"]'::jsonb),

-- OBDX 1
('pkg-obdx1', 'OBDX 1', '12 minggu + 3 bulan ext · 12 KG LTH', 3499, '12 Minggu + 3 Bulan (1 kali) + 3 Bulan (1 kali)', 24, '🌱', 'bg-gold-light', null, true, 9,
  '["12 KG LTH","12 KG LTHPG","Starter Kit","21 Botol Air Afiyah","7 Botol Air Za''afaran","4 Set Herba Kolon","1 Set Enema Kit","1 Set Mesin Ozon","4 Set IV Saline Drip","1 Set DNA Test Kit"]'::jsonb,
  '["26 Sesi Herba Thoharah","6 Kelas Online New Life Challenge","Bimbingan Terapi Peminuman LTH, LTHPG","Bimbingan Terapi Zikir Bersanad","Bimbingan Terapi Diet dan Nutrisi"]'::jsonb,
  '["12 KG LTH","12 KG LTHPG","Starter Kit","21 Botol Air Afiyah","7 Botol Air Za''afaran"]'::jsonb,
  '["Peminuman LTH mengikut jadual (12 KG)","Air Afiyah 1 botol/hari","Herba Thoharah (26 sesi)","Pantau vitals"]'::jsonb,
  '["Bimbingan Terapi Reaksi Pemulihan","Mood tracker","Kelas New Life Challenge"]'::jsonb,
  '["Pemantauan Coach","Konsultasi Hakeema","Perubatan Alami Online"]'::jsonb,
  '["Zikir Bersanad","Perubatan Rohani","Solat hajat"]'::jsonb),

-- OBDY 1
('pkg-obdy1', 'OBDY 1', '12 minggu + multi ext · 21 KG LTH elite', 5999, '12 Minggu + multi extension', 48, '🌱', 'bg-gold-light', null, true, 10,
  '["21 KG LTH","21 KG LTHPG","Starter Kit","33 Botol Air Afiyah","7 Botol Air Za''afaran","7 Set Herba Kolon"]'::jsonb,
  '["32 Sesi Herba Thoharah","6 Kelas Online New Life Challenge","Bimbingan Terapi lengkap"]'::jsonb,
  '["21 KG LTH","21 KG LTHPG","Starter Kit","33 Botol Air Afiyah"]'::jsonb,
  '["Peminuman LTH (21 KG)","Air Afiyah harian","Herba Thoharah (32 sesi)","Pantau vitals"]'::jsonb,
  '["Bimbingan Terapi Reaksi Pemulihan","Mood tracker","Kelas New Life Challenge"]'::jsonb,
  '["Pemantauan Coach","Konsultasi Hakeema","Perubatan Alami Online"]'::jsonb,
  '["Zikir Bersanad","Perubatan Rohani","Solat hajat"]'::jsonb),

-- OBG
('pkg-obg', 'OBG', '22 minggu · comprehensive cleansing', 1499, '22 Minggu', 22, '🌿', 'bg-green-light', null, true, 11,
  '["10 KG IB","8 KG YHPG","Starter Kit","12 Botol Air Afiyah","7 Botol Air Za''afaran","1 Set Herba Kolon","1 Set Enema Kit","1 Set Mesin Ozon","4 Set IV Saline Drip","1 Set DNA Test Kit"]'::jsonb,
  '["20 Sesi Herba Thoharah","6 Kelas Online New Life Challenge","Bimbingan Terapi lengkap"]'::jsonb,
  '["10 KG IB","8 KG YHPG","Starter Kit","12 Botol Air Afiyah","7 Botol Air Za''afaran"]'::jsonb,
  '["Peminuman IB mengikut jadual (10 KG)","Peminuman YHPG (8 KG)","Air Afiyah harian","Herba Thoharah (20 sesi)","Pantau vitals"]'::jsonb,
  '["Bimbingan Terapi Reaksi Pemulihan","Mood tracker","Kelas New Life Challenge"]'::jsonb,
  '["Pemantauan Coach","Konsultasi Hakeema"]'::jsonb,
  '["Zikir Bersanad","Perubatan Rohani","Solat hajat"]'::jsonb),

-- Jump Start
('pkg-js', 'Jump Start (JS)', 'Program berfasa · Ripple → Spark → Light Up', 799, 'Berfasa (3 fasa × 3 program)', 4, '🚀', 'bg-terracotta-light', null, true, 12,
  '["Young & Healthy Honey"]'::jsonb,
  '["4 Video Mingguan","Workbook Refleksi","Latihan Kesedaran Emosi","Latihan Fitrah Harian","Coaching Online Mingguan","Pantauan Kaunselor","Group sokongan Jump Start","1 Sesi kaunseling"]'::jsonb,
  '["4 Video Mingguan","Workbook Refleksi","Latihan Kesedaran Emosi","Latihan Fitrah Harian","Coaching Online Mingguan","Young & Healthy Honey"]'::jsonb,
  '["Young & Healthy Honey mengikut coaching","Latihan Fitrah Harian","1 sesi konsultasi fizikal"]'::jsonb,
  '["4 Video Mingguan","Workbook Refleksi","Latihan Kesedaran Emosi","Coaching Online Mingguan"]'::jsonb,
  '["Group sokongan Jump Start","Pantauan Kaunselor"]'::jsonb,
  '["Latihan Fitrah Harian","Latihan Neuropsikologi & Kerohanian","1 Sesi kaunseling bersama Kaunselor Berdaftar"]'::jsonb),

-- Jump Start+
('pkg-js-plus', 'Jump Start+ (JS+)', 'JS + Portal VIP + kaunseling extra', 1299, 'Berfasa (3 fasa × 3 program)', 4, '⭐', 'bg-gold-light', null, true, 13,
  '["Young & Healthy Honey"]'::jsonb,
  '["4 Video Mingguan","Workbook Refleksi","Coaching Online Mingguan","Akses Portal VIP (3 Bulan)","Kaunseling"]'::jsonb,
  '["4 Video Mingguan","Workbook Refleksi","Akses Portal VIP","Young & Healthy Honey"]'::jsonb,
  '["Young & Healthy Honey","Latihan Fitrah Harian","Konsultasi fizikal"]'::jsonb,
  '["Workbook Refleksi","Coaching Online"]'::jsonb,
  '["Group sokongan Jump Start","Pantauan Kaunselor","Akses Portal VIP"]'::jsonb,
  '["Latihan Neuropsikologi & Kerohanian","Kaunseling berdaftar"]'::jsonb)

ON CONFLICT (package_id) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  price = EXCLUDED.price,
  duration = EXCLUDED.duration,
  duration_weeks = EXCLUDED.duration_weeks,
  icon = EXCLUDED.icon,
  bg_color = EXCLUDED.bg_color,
  is_active = EXCLUDED.is_active,
  sort_order = EXCLUDED.sort_order,
  products = EXCLUDED.products,
  bimbingan = EXCLUDED.bimbingan,
  inclusions = EXCLUDED.inclusions,
  bio_goals = EXCLUDED.bio_goals,
  psycho_goals = EXCLUDED.psycho_goals,
  social_goals = EXCLUDED.social_goals,
  spiritual_goals = EXCLUDED.spiritual_goals;

SELECT COUNT(*) AS total_pakej FROM psy_packages;


-- ============================================================
-- BAHAGIAN 2: PRODUK (psy_products)
-- ============================================================

INSERT INTO psy_products (product_id, name, description, category, price, stock, icon, bg_color, is_active, sort_order) VALUES

-- MADU
('madu-yhh-500g',     'Young & Healthy Honey 500g',  'Madu tulen premium ISW · penggunaan harian',           'Madu',            95,  50,  '🍯', 'bg-gold-light',       true, 1),
('madu-yhh-1kg',      'Young & Healthy Honey 1kg',   'Saiz keluarga · nilai lebih jimat',                    'Madu',           175,  30,  '🍯', 'bg-gold-light',       true, 2),
('madu-shifa-500g',   'Madu Shifa 500g',             'Pure raw honey · acacia · khasiat tinggi',             'Madu',            85,  40,  '🍯', 'bg-gold-light',       true, 3),
('madu-kelulut-400g', 'Madu Kelulut 400g',           'Stingless bee honey · anti-radang',                    'Madu',           120,  25,  '🍯', 'bg-gold-light',       true, 4),
('kurma-ajwa-500g',   'Kurma Ajwa 500g',             'Kurma ajwa premium · sunnah Nabi SAW',                 'Madu',           150,  60,  '🌴', 'bg-gold-light',       true, 5),

-- HERBA
('ib-1kg',            'IB 1kg',                      'Ibu Bumi (IB) · bahan asas program OBP',               'Herba',          180,  35,  '🌿', 'bg-green-light',      true, 6),
('yhpg-1kg',          'YHPG 1kg',                    'Young Healthy Plus Green · detox hijau',                'Herba',          170,  35,  '🌿', 'bg-green-light',      true, 7),
('lth-1kg',           'LTH 1kg',                     'Lebah Thoharah · bahan asas program OBD',              'Herba',          160,  30,  '🌿', 'bg-green-light',      true, 8),
('lthpg-1kg',         'LTHPG 1kg',                   'LTH Plus Green · detox variant LTH',                   'Herba',          155,  30,  '🌿', 'bg-green-light',      true, 9),
('herba-kolon',       'Herba Kolon Set',             '1 set · pembersih kolon semulajadi',                   'Herba',          120,  20,  '🌿', 'bg-green-light',      true, 10),
('jus-halia',         'Jus Halia Concentrate 250ml', '100% natural · anti-radang & penghadaman',             'Herba',           45,  45,  '🌿', 'bg-green-light',      true, 11),
('herba-zaitun',      'Minyak Zaitun Tulen 500ml',   'Cold-pressed · pelbagai kegunaan',                     'Herba',           65,  40,  '🫒', 'bg-green-light',      true, 12),
('barley-500g',       'Barley Premium 500g',         'Bijirin barli organik · serat tinggi',                 'Herba',           55,  50,  '🌾', 'bg-green-light',      true, 13),

-- AIR AFIYAH & ZA''AFARAN
('air-afiyah-1btl',   'Air Afiyah 1 Botol',          'Air Afiyah tulen · terapi spiritual',                  'Air Terapi',      40,  100, '💧', 'bg-navy-light',       true, 14),
('air-afiyah-12btl',  'Air Afiyah 12 Botol',         'Pack 12 botol · jimat untuk program 12 minggu',        'Air Terapi',     440,  15,  '💧', 'bg-navy-light',       true, 15),
('air-zaafaran-1btl', 'Air Za''afaran 1 Botol',       'Air za''afaran premium · terapi rohani',               'Air Terapi',      60,  80,  '💧', 'bg-navy-light',       true, 16),

-- SUPPLEMENTS
('magnesium',         'Magnesium Glycinate 60 caps',  '200mg · untuk tidur & relaksasi otot',                'Supplements',    55,  60,  '💊', 'bg-navy-light',       true, 17),
('vitamin-d',         'Vitamin D3 5000IU 90 softgels','Untuk imuniti & tulang kuat',                         'Supplements',    48,  70,  '☀️', 'bg-gold-light',       true, 18),
('omega-3',           'Omega-3 Fish Oil 60 caps',     '1000mg · jantung & otak sihat',                       'Supplements',    65,  55,  '🐟', 'bg-navy-light',       true, 19),
('probiotik',         'Probiotik Advanced 30 caps',   '10 billion CFU · kesihatan usus',                     'Supplements',    72,  40,  '💊', 'bg-green-light',      true, 20),
('spirulina',         'Spirulina Organik 200 tabs',   'Superfood · protein & antioksidan tinggi',             'Supplements',    58,  45,  '💊', 'bg-green-light',      true, 21),

-- SANTAPAN FITRAH
('santapan-fitrah',   'Santapan Fitrah Set',         '7-day starter pack · diet holistik ISW',               'Santapan Fitrah',220,  20,  '🌱', 'bg-terracotta-light', true, 22),
('starter-kit',       'Starter Kit ISW',             'Kit permulaan program · semua yang perlu',              'Santapan Fitrah',350,  15,  '🎒', 'bg-terracotta-light', true, 23),

-- PERALATAN TERAPI
('enema-kit',         'Enema Kit Set',               'Kit enema lengkap · pembersihan kolon',                'Peralatan',      280,  10,  '🏥', 'bg-cream',            true, 24),
('mesin-ozon',        'Mesin Ozon Terapi',           'Terapi ozon rumah · air & udara',                      'Peralatan',      850,   8,  '⚡', 'bg-cream',            true, 25),
('iv-saline-set',     'IV Saline Drip Set (1 set)',  '1 set IV saline · untuk terapi drip',                  'Peralatan',      120,  12,  '💉', 'bg-cream',            true, 26),
('dna-test-kit',      'DNA Test Kit',                'Kit ujian DNA · analisis kesihatan genetik',            'Peralatan',      450,   5,  '🧬', 'bg-cream',            true, 27),

-- BUKU
('rahsia-syifa',      'Rahsia Syifa',                'Ibn Sina & perubatan moden · panduan kesihatan',       'Books',           35,  30,  '📖', 'bg-navy-light',       true, 28),
('doa-syifa-book',    'Kitab Doa Syifa',             'Tafsir + transliterasi · doa penyembuhan',             'Books',           28,  35,  '📖', 'bg-terracotta-light', true, 29),
('gaya-hidup-fitrah', 'Buku Gaya Hidup Fitrah',      '7 prinsip hidup sihat Islam · panduan lengkap',        'Books',           42,  25,  '📖', 'bg-green-light',      true, 30),
('workbook-js',       'Workbook Jump Start',         'Workbook refleksi program Jump Start · 60 halaman',    'Books',           30,  40,  '📓', 'bg-gold-light',       true, 31)

ON CONFLICT (product_id) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  price = EXCLUDED.price,
  stock = EXCLUDED.stock,
  icon = EXCLUDED.icon,
  bg_color = EXCLUDED.bg_color,
  is_active = EXCLUDED.is_active,
  sort_order = EXCLUDED.sort_order;

SELECT COUNT(*) AS total_produk FROM psy_products;


-- ============================================================
-- BAHAGIAN 3: SELF-HELP LIBRARY (psy_library_items)
-- ============================================================

INSERT INTO psy_library_items (item_id, title, description, content_type, category, icon, gradient, sort_order) VALUES

-- PENGENALAN & ASAS
('bps-s-intro',          'Apa itu BPS-S Model?',                       'Dr. Hamzah menerangkan 4 pillar holistik Ibn Sina',              'Video · 8 min',     'navy',      '🎥', 'from-navy to-teal',              1),
('isw-pengenalan',       'Pengenalan kepada ISW',                       'Sejarah & filosofi ISW · pendekatan holistik Islam',             'Video · 12 min',    'navy',      '🎥', 'from-navy to-teal',              2),
('gaya-hidup-fitrah-lib','7 Gaya Hidup Fitrah',                         '7 amalan harian untuk keseimbangan bio-psiko-sosio-spiritual',   'Article · 10 min',  'green',     '📝', 'from-green to-gold-dark',        3),
('faq-baru',             '10 Soalan Lazim Pesakit Baru',               'Apa yang perlu anda tahu sebelum memulakan program',             'FAQ',               'teal',      '💬', 'from-teal to-navy',              4),

-- DIET & NUTRISI
('santapan-panduan',     'Santapan Fitrah: Panduan Harian',            'Resipi + cara penyediaan untuk 7 hari pertama',                  'Article · 5 min',   'green',     '📝', 'from-green to-gold-dark',        5),
('resepi-fitrah-7',      '7 Resepi Fitrah ISW',                         '7 resepi mudah berkhasiat tinggi untuk kesihatan optimum',       'Article · 8 min',   'green',     '🍽️', 'from-green to-teal',             6),
('diet-islamic',         'Diet Menurut Perspektif Islam',               'Halal, tayyib & berkat — asas pemakanan holistik',               'Article · 7 min',   'gold',      '📝', 'from-gold to-green',             7),
('air-terapi-panduan',   'Panduan Air Afiyah & Za''afaran',             'Cara penggunaan, jadual & dos yang betul',                       'Article · 6 min',   'navy',      '💧', 'from-navy to-teal',              8),
('puasa-syifa',          'Puasa sebagai Terapi Penyembuhan',            'Khasiat puasa untuk detoks fizikal & rohani',                    'Article · 9 min',   'terracotta','📝', 'from-terracotta to-gold-dark',   9),

-- ROHANI & SPIRITUAL
('zikir-syifa',          'Zikir Pagi Petang Syifa',                    'Audio + transliterasi untuk amalan harian penyembuhan',          'Doa & Zikir',       'terracotta','🕌', 'from-terracotta to-gold-dark',  10),
('doa-syifa-panduan',    'Panduan Doa Syifa Lengkap',                  '40 doa penyembuhan dari Al-Quran & Hadis sahih',                 'Doa & Zikir',       'terracotta','🤲', 'from-terracotta to-gold-dark',  11),
('ruqyah-asas',          'Asas Ruqyah Syar''iyyah',                    'Panduan ruqyah yang betul & selamat mengikut sunnah',            'Doa & Zikir',       'terracotta','📖', 'from-terracotta to-navy',       12),
('solat-syifa',          'Solat sebagai Ubat Jiwa',                    'Kesan solat pada kesihatan mental dan fizikal',                  'Article · 8 min',   'gold',      '🕌', 'from-gold to-terracotta',       13),
('tawakkal-sabar',       'Tawakkal & Sabar dalam Pemulihan',           'Kekuatan spiritual untuk melalui proses rawatan',               'Article · 6 min',   'gold',      '✨', 'from-gold to-terracotta',       14),

-- PSIKOLOGI & MENTAL
('breathing-muraqabah',  'Breathing & Muraqabah',                      'Teknik pernafasan untuk ketenangan mental & fokus',              'Exercise · 15 min', 'gold',      '🧘‍♀️','from-gold to-green',            15),
('mood-tracker',         'Mood & Progress Tracker',                    'PDF printable untuk rekod emosi harian',                         'Worksheet',         'ink',       '📊', 'from-navy to-terracotta',       16),
('journaling-panduan',   'Panduan Journaling Fitrah',                  'Teknik menulis jurnal untuk kesihatan emosi & mental',           'Worksheet',         'ink',       '✍️', 'from-navy to-teal',             17),
('kesedaran-emosi',      'Latihan Kesedaran Emosi',                    '5 latihan mudah untuk kenal & kawal emosi dengan sihat',         'Exercise · 20 min', 'gold',      '🧠', 'from-gold to-green',            18),
('stres-urus',           'Urus Stres dengan Cara Islam',               'Teknik CBT + perspektif Islam untuk kawal tekanan',              'Article · 10 min',  'teal',      '🧠', 'from-teal to-navy',             19),
('tidur-sihat',          'Panduan Tidur Sihat (Sleep Hygiene)',         'Kesan tidur pada kesihatan & cara tidur yang berkualiti',        'Article · 7 min',   'navy',      '🌙', 'from-navy to-teal',             20),

-- FIZIKAL & SENAMAN
('senaman-fitrah',       'Senaman Fitrah Harian',                      '15 minit senaman ringan yang sesuai untuk semua peringkat umur', 'Exercise · 15 min', 'green',     '🏃', 'from-green to-gold-dark',       21),
('jalan-kaki-terapi',    'Jalan Kaki sebagai Terapi',                  'Manfaat & cara berjalan kaki untuk kesihatan optimum',           'Article · 5 min',   'green',     '🚶', 'from-green to-teal',            22),
('detoks-jadual',        'Jadual Detoks 12 Minggu',                    'Pelan lengkap detoks untuk program OBP & OBD',                  'Worksheet',         'ink',       '📅', 'from-navy to-terracotta',       23),

-- SOSIAL & KELUARGA
('keluarga-sihat',       'Membina Keluarga yang Sihat',                'Peranan keluarga dalam proses pemulihan pesakit',                'Article · 8 min',   'teal',      '👨‍👩‍👧', 'from-teal to-navy',             24),
('sokongan-sosial',      'Kepentingan Sokongan Sosial',                'Bagaimana jaringan sokongan membantu proses sembuh',             'Article · 6 min',   'teal',      '🤝', 'from-teal to-green',            25),

-- PROGRAM SPESIFIK
('panduan-obp',          'Panduan Lengkap Program OBP',                'Cara gunakan IB, YHPG, Air Afiyah & semua terapi OBP',          'Article · 15 min',  'navy',      '💎', 'from-navy to-teal',             26),
('panduan-obd',          'Panduan Lengkap Program OBD',                'Cara gunakan LTH, LTHPG & semua terapi OBD',                    'Article · 15 min',  'green',     '🌱', 'from-green to-teal',            27),
('panduan-777',          'Panduan Program 777',                        'Maksud 7 hari, 7 resepi, 7 gaya hidup fitrah',                  'Article · 10 min',  'gold',      '🌟', 'from-gold to-terracotta',       28),
('panduan-js',           'Panduan Jump Start: Ripple Spark Light Up',  '3 fasa program psikologi — apa yang berlaku di setiap fasa',    'Article · 12 min',  'terracotta','🚀', 'from-terracotta to-gold-dark',  29),
('herba-thoharah-cara',  'Cara Herba Thoharah yang Betul',             'Langkah demi langkah sesi Herba Thoharah bersama coach',        'Video · 10 min',    'green',     '🌿', 'from-green to-gold-dark',       30),

-- FAQ & REAKSI PEMULIHAN
('reaksi-pemulihan',     'Memahami Reaksi Pemulihan (Herxheimer)',      'Normal atau tidak? Panduan lengkap reaksi detoks',               'FAQ',               'terracotta','❓', 'from-terracotta to-navy',       31),
('faq-produk',           'FAQ Produk & Cara Penggunaan',               'Soalan lazim tentang semua produk ISW',                          'FAQ',               'teal',      '💬', 'from-teal to-navy',             32),
('vitals-pantau',        'Cara Pantau Vital Signs di Rumah',           'BP, berat badan, suhu — bila perlu ambil & rekod',              'Article · 5 min',   'ink',       '📏', 'from-navy to-terracotta',       33),
('progress-tracker',     'Tracker Kemajuan 12 Minggu',                 'Worksheet printable untuk pantau kemajuan seluruh program',      'Worksheet',         'ink',       '📈', 'from-navy to-teal',             34)

ON CONFLICT (item_id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  content_type = EXCLUDED.content_type,
  category = EXCLUDED.category,
  icon = EXCLUDED.icon,
  gradient = EXCLUDED.gradient,
  sort_order = EXCLUDED.sort_order;

SELECT COUNT(*) AS total_library FROM psy_library_items;


-- ============================================================
-- BAHAGIAN 4: INVENTORI (psy_inventory_items)
-- ============================================================

INSERT INTO psy_inventory_items (name, category, unit, qty_in_stock, min_qty, requires_approval, notes) VALUES

-- MADU & PRODUK ASAS
('Young & Healthy Honey (YHH)',      'Madu',            'kg',    45.0,   5.0,  false, 'Madu utama program EOL, 777 VIP & Jump Start'),
('Ibu Bumi (IB)',                    'Herba',           'kg',    72.0,  10.0,  false, 'Bahan asas program OBP — stok perlu sentiasa mencukupi'),
('Young Healthy Plus Green (YHPG)',  'Herba',           'kg',    68.0,  10.0,  false, 'Pasangan IB dalam program OBP'),
('Lebah Thoharah (LTH)',             'Herba',           'kg',    55.0,  10.0,  false, 'Bahan asas program OBD'),
('LTH Plus Green (LTHPG)',           'Herba',           'kg',    50.0,  10.0,  false, 'Pasangan LTH dalam program OBD'),

-- AIR TERAPI
('Air Afiyah',                       'Air Terapi',      'botol',180.0,  20.0,  false, '1 botol = 1.5L · bekalan untuk semua program aktif'),
('Air Za''afaran',                   'Air Terapi',      'botol', 95.0,  10.0,  false, 'Untuk sesi Perubatan Rohani & terapi penyucian'),

-- HERBA TAMBAHAN
('Herba Kolon',                      'Herba',           'set',   28.0,   5.0,  false, '1 set = 1 kursus rawatan kolon'),
('Barley Organik',                   'Herba',           'kg',    60.0,  10.0,  false, 'Bekalan minuman barley harian pesakit'),
('Kurma Ajwa',                       'Herba',           'biji', 980.0, 100.0,  false, '49 biji/pesakit 777 VIP · semak stok sebelum enrol baru'),
('Madu Kelulut',                     'Madu',            'botol', 22.0,   5.0,  false, 'Produk jualan & terapi'),
('Minyak Zaitun Tulen',              'Herba',           'botol', 35.0,   5.0,  false, 'Untuk kegunaan dalaman & luaran'),
('Spirulina',                        'Supplements',     'botol', 18.0,   3.0,  false, NULL),

-- PERALATAN TERAPI
('Enema Kit',                        'Peralatan',       'set',   12.0,   3.0,  true,  'Perlu kelulusan untuk beli — harga tinggi'),
('Mesin Ozon',                       'Peralatan',       'unit',   5.0,   1.0,  true,  'Peralatan mahal · rekod nombor siri setiap unit'),
('IV Saline Drip Set',               'Peralatan',       'set',   38.0,   8.0,  true,  '1 set = 1 sesi IV drip · perlu kelulusan perubatan'),
('DNA Test Kit',                     'Peralatan',       'set',    8.0,   2.0,  true,  'Kit ujian DNA · perlu hantar ke lab luar'),

-- STARTER KIT & PAKEJ
('Starter Kit ISW',                  'Pakej',           'set',   15.0,   3.0,  false, 'Kandungan: buku panduan, tracker, botol air, beg'),
('Santapan Fitrah Set (7-hari)',     'Pakej',           'set',   10.0,   2.0,  false, '7-day starter pack lengkap'),

-- ALAT TULIS & WORKSHEET
('Workbook Jump Start',              'Alat Bantu',      'naskhah',60.0, 10.0,  false, 'Workbook refleksi 60 halaman untuk peserta JS/JS+'),
('Workbook Refleksi Harian',         'Alat Bantu',      'naskhah',80.0, 15.0,  false, 'Untuk semua program · diedarkan masa mula program'),
('Mood Tracker Printable',           'Alat Bantu',      'naskhah',120.0,20.0,  false, 'PDF cetak · rekod emosi & kemajuan harian'),
('Jadual Terapi 12 Minggu',          'Alat Bantu',      'naskhah',45.0, 10.0,  false, 'Jadual pelan rawatan peribadi pesakit'),

-- SUPPLEMENTS
('Magnesium Glycinate 60 caps',      'Supplements',     'botol', 25.0,   5.0,  false, NULL),
('Vitamin D3 5000IU',                'Supplements',     'botol', 30.0,   5.0,  false, NULL),
('Omega-3 Fish Oil',                 'Supplements',     'botol', 20.0,   5.0,  false, NULL),
('Probiotik Advanced',               'Supplements',     'botol', 15.0,   3.0,  false, NULL),

-- BUKU
('Rahsia Syifa',                     'Buku',            'naskhah',25.0,  5.0,  false, NULL),
('Kitab Doa Syifa',                  'Buku',            'naskhah',30.0,  5.0,  false, NULL),
('Buku Gaya Hidup Fitrah',           'Buku',            'naskhah',20.0,  5.0,  false, NULL);

SELECT COUNT(*) AS total_inventori FROM psy_inventory_items;


-- ============================================================
-- SEMAK KEPUTUSAN
-- ============================================================

SELECT 'PAKEJ RAWATAN' AS bahagian, COUNT(*) AS jumlah FROM psy_packages WHERE is_active = true
UNION ALL
SELECT 'PRODUK',    COUNT(*) FROM psy_products     WHERE is_active = true
UNION ALL
SELECT 'LIBRARY',   COUNT(*) FROM psy_library_items WHERE is_active = true
UNION ALL
SELECT 'INVENTORI', COUNT(*) FROM psy_inventory_items;
