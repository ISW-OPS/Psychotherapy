-- ============================================================
-- SEED PACKAGES
-- Run selepas step5_packages.sql
-- ============================================================

DELETE FROM psy_packages;

-- 777 FREE
INSERT INTO psy_packages (package_id, name, description, price, duration, duration_weeks, icon, bg_color, tier, is_active, sort_order,
  products, bimbingan, inclusions, bio_goals, psycho_goals, social_goals, spiritual_goals
) VALUES (
  'pkg-777-free', '777 FREE', '7 hari starter · percuma', 0, '7 Hari', 1, '🎁', 'bg-cream', 'free', true, 1,
  '[]'::jsonb,
  '["Webinar 7 hari","Whatsapp Group Support"]'::jsonb,
  '["7 Hari Webinar (Diet, Rohani, Ripple)","7 Gaya Hidup Fitrah","7 Resepi Fitrah","Whatsapp Group Support"]'::jsonb,
  '["Amalkan 7 Resepi Fitrah","Minum air 2L sehari","Pantau berat badan"]'::jsonb,
  '["Tonton Webinar Diet harian","Journaling ringkas (5 min)"]'::jsonb,
  '["Sertai Whatsapp Group Support","Kenali ahli group"]'::jsonb,
  '["Tonton Webinar Rohani harian","Amalkan 7 Gaya Hidup Fitrah"]'::jsonb
);

-- 777 VIP
INSERT INTO psy_packages (package_id, name, description, price, duration, duration_weeks, icon, bg_color, tier, is_active, sort_order,
  products, bimbingan, inclusions, bio_goals, psycho_goals, social_goals, spiritual_goals
) VALUES (
  'pkg-777-vip', '777 VIP', '7 hari VIP · coaching & support', 999, '7 Hari', 1, '⭐', 'bg-gold-light', 'vip', true, 2,
  '["Kurma Ajwa 49 Biji","Barley 500g"]'::jsonb,
  '["Webinar 7 hari","Daily Workbook","Perubatan Rohani Sheikh Fares","1:1 Coaching Diet/Nutrisi","Video Series Hakeema","Whatsapp Group Support VIP"]'::jsonb,
  '["7 Hari Webinar (Diet, Rohani, Ripple)","7 Gaya Hidup Fitrah","7 Resepi Fitrah","Whatsapp Group Support 777 VIP","Daily Workbook","Perubatan Rohani Bersama Sheikh Fares","1:1 Coaching Diet / Nutrisi 1x Sebulan","Video Series Hakeema","Kurma Ajwa 49 Biji","Barley 500g"]'::jsonb,
  '["Amalkan 7 Resepi Fitrah","Kurma Ajwa 3 biji setiap pagi","Barley drink setiap petang","Minum air 2L sehari"]'::jsonb,
  '["Siapkan Daily Workbook harian","Tonton Video Series Hakeema","1:1 Coaching Diet/Nutrisi (ikut jadual)"]'::jsonb,
  '["Aktif dalam Whatsapp Group 777 VIP","Tonton Webinar Ripple"]'::jsonb,
  '["Perubatan Rohani bersama Sheikh Fares","Tonton Webinar Rohani harian","Amalkan 7 Gaya Hidup Fitrah"]'::jsonb
);

-- EOL
INSERT INTO psy_packages (package_id, name, description, price, duration, duration_weeks, icon, bg_color, is_active, sort_order,
  products, bimbingan, inclusions, bio_goals, psycho_goals, social_goals, spiritual_goals
) VALUES (
  'pkg-eol', 'EOL', 'Entry-level · 4 minggu · 1 madu + coaching', 299, '4 Minggu', 4, '🍯', 'bg-navy-light', true, 3,
  '["1 (500G) Young & Healthy Honey"]'::jsonb,
  '["Whatsapp Group Support","Akses Portal ISW","1 Sesi Konsultasi Coach Online","Perubatan Rohani Sheikh Fares"]'::jsonb,
  '["1 (500G) Young & Healthy Honey","Whatsapp Group Support","Akses Portal ISW","1 Sesi Konsultasi bersama Coach secara Online","Perubatan Rohani bersama Sheikh Fares"]'::jsonb,
  '["Young & Healthy Honey 1 sudu besar setiap pagi","Minum air 2.5L sehari","Pantau berat & BP mingguan"]'::jsonb,
  '["Mood tracker harian","Journaling (3 perkara syukur)"]'::jsonb,
  '["Aktif dalam Whatsapp Group Support","Hadir 1 Sesi Konsultasi Coach Online"]'::jsonb,
  '["Perubatan Rohani bersama Sheikh Fares","Zikir pagi petang","Solat penuh 5 waktu"]'::jsonb
);

-- EOL+
INSERT INTO psy_packages (package_id, name, description, price, duration, duration_weeks, icon, bg_color, is_active, sort_order,
  products, bimbingan, inclusions, bio_goals, psycho_goals, social_goals, spiritual_goals
) VALUES (
  'pkg-eol-plus', 'EOL+', 'Enhanced · 4 minggu · 2 madu + coaching', 499, '4 Minggu', 4, '🍯', 'bg-navy-light', true, 4,
  '["2 (500G) Young & Healthy Honey"]'::jsonb,
  '["Whatsapp Group Support","Akses Portal ISW","1 Sesi Konsultasi Coach Online","Perubatan Rohani Sheikh Fares"]'::jsonb,
  '["2 (500G) Young & Healthy Honey","Whatsapp Group Support","Akses Portal ISW","1 Sesi Konsultasi bersama Coach secara Online","Perubatan Rohani bersama Sheikh Fares"]'::jsonb,
  '["Young & Healthy Honey 1 sudu besar 2x/hari","Minum air 2.5L sehari","Pantau berat & BP mingguan","Jalan kaki 20 min/hari"]'::jsonb,
  '["Mood tracker harian","Journaling (3 perkara syukur)","Breathing exercise 4-7-8"]'::jsonb,
  '["Aktif dalam Whatsapp Group Support","Hadir 1 Sesi Konsultasi Coach Online","Family wellness sharing"]'::jsonb,
  '["Perubatan Rohani bersama Sheikh Fares","Zikir pagi petang","Solat penuh 5 waktu","Tadarus Al-Quran harian"]'::jsonb
);

-- OBP 1
INSERT INTO psy_packages (package_id, name, description, price, duration, duration_weeks, icon, bg_color, is_active, sort_order,
  products, bimbingan, inclusions, bio_goals, psycho_goals, social_goals, spiritual_goals
) VALUES (
  'pkg-obp1', 'OBP 1', '12 minggu · 6 KG IB + full terapi', 2999, '12 Minggu', 12, '💎', 'bg-navy-light', true, 5,
  '["6 KG IB","6 KG YHPG","Starter Kit","12 Botol Air Afiyah","7 Botol Air Za''afaran","1 Set Herba Kolon","1 Set Enema Kit","1 Set Mesin Ozon","4 Set IV Saline Drip","1 Set DNA Test Kit"]'::jsonb,
  '["20 Sesi Herba Thoharah","6 Kelas Online New Life Challenge","Bimbingan Terapi Peminuman IB, YHPG","Bimbingan Terapi Zikir Bersanad","Bimbingan Terapi Diet dan Nutrisi","Bimbingan Terapi Gaya Hidup Fitrah","Bimbingan Terapi Herba Thoharah","Bimbingan Terapi IV Saline Drip","Bimbingan Terapi Air Afiyah, Air Za''afaran dan Terapi Penyucian Aura","Bimbingan Terapi Reaksi Pemulihan","Bimbingan Terapi Herba Kolon","Konsultasi DNA bersama Coach","Pemantauan Coach","Konsultasi Bersama Hakeema","Perubatan Rohani Online bersama Coach Fares","Perubatan Alami Online bersama Nutritionist","Sesi Soal Jawab bersama Nutritionist"]'::jsonb,
  '["6 KG IB","6 KG YHPG","Starter Kit","12 Botol Air Afiyah","7 Botol Air Za''afaran","1 Set Herba Kolon","1 Set Enema Kit","1 Set Mesin Ozon","4 Set IV Saline Drip","20 Sesi Herba Thoharah","1 Set DNA Test Kit","6 Kelas Online New Life Challenge","Bimbingan Terapi Peminuman IB, YHPG","Bimbingan Terapi Zikir Bersanad","Bimbingan Terapi Diet dan Nutrisi","Bimbingan Terapi Gaya Hidup Fitrah","Bimbingan Terapi Herba Thoharah","Bimbingan Terapi IV Saline Drip","Bimbingan Terapi Air Afiyah, Air Za''afaran dan Terapi Penyucian Aura","Bimbingan Terapi Reaksi Pemulihan","Bimbingan Terapi Herba Kolon","Konsultasi DNA bersama Coach","Pemantauan Coach","Konsultasi Bersama Hakeema","Perubatan Rohani secara Online bersama Coach Fares","Perubatan Alami secara Online bersama Nutritionist","Sesi Soal Jawab bersama Nutritionist"]'::jsonb,
  '["Peminuman IB mengikut jadual harian","Peminuman YHPG mengikut jadual","Air Afiyah 1 botol setiap hari","Air Za''afaran mengikut jadual","Herba Thoharah (20 sesi)","IV Saline Drip (4 set)","Herba Kolon mengikut arahan","Enema mengikut jadual","Terapi Mesin Ozon","DNA Test","Pantau vitals mingguan"]'::jsonb,
  '["Bimbingan Terapi Reaksi Pemulihan","Bimbingan Terapi Diet dan Nutrisi","Bimbingan Terapi Gaya Hidup Fitrah","6 Kelas Online New Life Challenge","Mood tracker harian","Journaling harian","Konsultasi DNA bersama Coach"]'::jsonb,
  '["Pemantauan Coach berterusan","Konsultasi Bersama Hakeema","Sesi Soal Jawab bersama Nutritionist","Perubatan Alami Online bersama Nutritionist"]'::jsonb,
  '["Bimbingan Terapi Zikir Bersanad","Bimbingan Terapi Penyucian Aura","Perubatan Rohani Online bersama Coach Fares","Solat hajat mingguan","Doa syifa harian"]'::jsonb
);

-- OBPX 1
INSERT INTO psy_packages (package_id, name, description, price, duration, duration_weeks, icon, bg_color, is_active, sort_order,
  products, bimbingan, inclusions, bio_goals, psycho_goals, social_goals, spiritual_goals
) VALUES (
  'pkg-obpx1', 'OBPX 1', '12 minggu + 3 bulan ext · 12 KG IB', 5499, '12 Minggu + 3 Bulan (1 kali) + 3 Bulan (1 kali)', 24, '💎', 'bg-teal/10', true, 6,
  '["12 KG IB","12 KG YHPG","Starter Kit","21 Botol Air Afiyah","7 Botol Air Za''afaran","4 Set Herba Kolon","1 Set Enema Kit","1 Set Mesin Ozon","4 Set IV Saline Drip","1 Set DNA Test Kit"]'::jsonb,
  '["26 Sesi Herba Thoharah","6 Kelas Online New Life Challenge","Bimbingan Terapi Peminuman IB, YHPG","Bimbingan Terapi Zikir Bersanad","Bimbingan Terapi Diet dan Nutrisi","Bimbingan Terapi Gaya Hidup Fitrah","Bimbingan Terapi Herba Thoharah","Bimbingan Terapi IV Saline Drip","Bimbingan Terapi Air Afiyah, Air Za''afaran dan Terapi Penyucian Aura","Bimbingan Terapi Reaksi Pemulihan","Bimbingan Terapi Herba Kolon","Konsultasi DNA bersama Coach","Pemantauan Coach","Konsultasi Bersama Hakeema","Perubatan Rohani Online bersama Coach Fares","Perubatan Alami Online bersama Nutritionist","Sesi Soal Jawab bersama Nutritionist"]'::jsonb,
  '["12 KG IB","12 KG YHPG","Starter Kit","21 Botol Air Afiyah","7 Botol Air Za''afaran","4 Set Herba Kolon","1 Set Enema Kit","1 Set Mesin Ozon","4 Set IV Saline Drip","26 Sesi Herba Thoharah","1 Set DNA Test Kit","6 Kelas Online New Life Challenge"]'::jsonb,
  '["Peminuman IB mengikut jadual (12 KG)","Peminuman YHPG mengikut jadual (12 KG)","Air Afiyah 1 botol setiap hari (21 botol)","Herba Thoharah (26 sesi)","IV Saline Drip (4 set)","Herba Kolon 4 set","Enema mengikut jadual","Terapi Mesin Ozon","DNA Test","Pantau vitals mingguan"]'::jsonb,
  '["Bimbingan Terapi Reaksi Pemulihan","Bimbingan Terapi Diet dan Nutrisi","Bimbingan Terapi Gaya Hidup Fitrah","6 Kelas Online New Life Challenge","Mood tracker harian","Konsultasi DNA bersama Coach"]'::jsonb,
  '["Pemantauan Coach berterusan","Konsultasi Bersama Hakeema","Sesi Soal Jawab bersama Nutritionist","Perubatan Alami Online bersama Nutritionist"]'::jsonb,
  '["Bimbingan Terapi Zikir Bersanad","Bimbingan Terapi Penyucian Aura","Perubatan Rohani Online bersama Coach Fares","Solat hajat mingguan","Doa syifa harian"]'::jsonb
);

-- OBPY 1
INSERT INTO psy_packages (package_id, name, description, price, duration, duration_weeks, icon, bg_color, is_active, sort_order,
  products, bimbingan, inclusions, bio_goals, psycho_goals, social_goals, spiritual_goals
) VALUES (
  'pkg-obpy1', 'OBPY 1', '12 minggu + multi ext · 21 KG IB elite', 8999, '12 Minggu + 3 Bulan (1 kali) + 3 Bulan (3 bulan sekali) + 6 Bulan (3 bulan sekali)', 48, '👑', 'bg-gold-light', true, 7,
  '["21 KG IB","21 KG YHPG","Starter Kit","33 Botol Air Afiyah","7 Botol Air Za''afaran","7 Set Herba Kolon","1 Set Enema Kit","1 Set Mesin Ozon","4 Set IV Saline Drip","1 Set DNA Test Kit"]'::jsonb,
  '["32 Sesi Herba Thoharah","6 Kelas Online New Life Challenge","Bimbingan Terapi Peminuman IB, YHPG","Bimbingan Terapi Zikir Bersanad","Bimbingan Terapi Diet dan Nutrisi","Bimbingan Terapi Gaya Hidup Fitrah","Bimbingan Terapi Herba Thoharah","Bimbingan Terapi IV Saline Drip","Bimbingan Terapi Air Afiyah, Air Za''afaran dan Terapi Penyucian Aura","Bimbingan Terapi Reaksi Pemulihan","Bimbingan Terapi Herba Kolon","Konsultasi DNA bersama Coach","Pemantauan Coach","Konsultasi Bersama Hakeema","Perubatan Rohani Online bersama Coach Fares","Perubatan Alami Online bersama Nutritionist","Sesi Soal Jawab bersama Nutritionist"]'::jsonb,
  '["21 KG IB","21 KG YHPG","Starter Kit","33 Botol Air Afiyah","7 Botol Air Za''afaran","7 Set Herba Kolon","1 Set Enema Kit","1 Set Mesin Ozon","4 Set IV Saline Drip","32 Sesi Herba Thoharah","1 Set DNA Test Kit","6 Kelas Online New Life Challenge"]'::jsonb,
  '["Peminuman IB mengikut jadual (21 KG)","Peminuman YHPG mengikut jadual (21 KG)","Air Afiyah 1 botol setiap hari (33 botol)","Herba Thoharah (32 sesi)","IV Saline Drip (4 set)","Herba Kolon 7 set","Enema mengikut jadual","Terapi Mesin Ozon","DNA Test","Pantau vitals mingguan"]'::jsonb,
  '["Bimbingan Terapi Reaksi Pemulihan","Bimbingan Terapi Diet dan Nutrisi","Bimbingan Terapi Gaya Hidup Fitrah","6 Kelas Online New Life Challenge","Mood tracker harian","Konsultasi DNA bersama Coach"]'::jsonb,
  '["Pemantauan Coach berterusan","Konsultasi Bersama Hakeema","Sesi Soal Jawab bersama Nutritionist","Perubatan Alami Online bersama Nutritionist"]'::jsonb,
  '["Bimbingan Terapi Zikir Bersanad","Bimbingan Terapi Penyucian Aura","Perubatan Rohani Online bersama Coach Fares","Solat hajat mingguan","Doa syifa harian"]'::jsonb
);

-- OBD 1
INSERT INTO psy_packages (package_id, name, description, price, duration, duration_weeks, icon, bg_color, is_active, sort_order,
  products, bimbingan, inclusions, bio_goals, psycho_goals, social_goals, spiritual_goals
) VALUES (
  'pkg-obd1', 'OBD 1', '12 minggu · 6 KG LTH detox', 1999, '12 Minggu', 12, '🌱', 'bg-terracotta-light', true, 8,
  '["6 KG LTH","6 KG LTHPG","Starter Kit","12 Botol Air Afiyah","7 Botol Air Za''afaran","1 Set Herba Kolon","1 Set Enema Kit","1 Set Mesin Ozon","4 Set IV Saline Drip","1 Set DNA Test Kit"]'::jsonb,
  '["20 Sesi Herba Thoharah","6 Kelas Online New Life Challenge","Bimbingan Terapi Peminuman LTH, LTHPG","Bimbingan Terapi Zikir Bersanad","Bimbingan Terapi Diet dan Nutrisi","Bimbingan Terapi Gaya Hidup Fitrah","Bimbingan Terapi Herba Thoharah","Bimbingan Terapi IV Saline Drip","Bimbingan Terapi Air Afiyah, Air Za''afaran dan Terapi Penyucian Aura","Bimbingan Terapi Reaksi Pemulihan","Bimbingan Terapi Herba Kolon","Konsultasi DNA bersama Coach","Pemantauan Coach","Konsultasi Bersama Hakeema","Perubatan Rohani Online bersama Coach Fares","Perubatan Alami Online bersama Nutritionist","Sesi Soal Jawab bersama Nutritionist"]'::jsonb,
  '["6 KG LTH","6 KG LTHPG","Starter Kit","12 Botol Air Afiyah","7 Botol Air Za''afaran","1 Set Herba Kolon","1 Set Enema Kit","1 Set Mesin Ozon","4 Set IV Saline Drip","20 Sesi Herba Thoharah","1 Set DNA Test Kit","6 Kelas Online New Life Challenge"]'::jsonb,
  '["Peminuman LTH mengikut jadual harian","Peminuman LTHPG mengikut jadual","Air Afiyah 1 botol setiap hari","Herba Thoharah (20 sesi)","IV Saline Drip (4 set)","Herba Kolon mengikut arahan","Enema","Terapi Mesin Ozon","DNA Test","Pantau vitals mingguan"]'::jsonb,
  '["Bimbingan Terapi Reaksi Pemulihan","Bimbingan Terapi Diet dan Nutrisi","Bimbingan Terapi Gaya Hidup Fitrah","6 Kelas Online New Life Challenge","Mood tracker","Konsultasi DNA bersama Coach"]'::jsonb,
  '["Pemantauan Coach berterusan","Konsultasi Bersama Hakeema","Sesi Soal Jawab bersama Nutritionist","Perubatan Alami Online bersama Nutritionist"]'::jsonb,
  '["Bimbingan Terapi Zikir Bersanad","Bimbingan Terapi Penyucian Aura","Perubatan Rohani Online bersama Coach Fares","Solat hajat mingguan","Doa syifa harian"]'::jsonb
);

-- OBDX 1 & OBDY 1
INSERT INTO psy_packages (package_id, name, description, price, duration, duration_weeks, icon, bg_color, is_active, sort_order, products, bimbingan, inclusions, bio_goals, psycho_goals, social_goals, spiritual_goals) VALUES
('pkg-obdx1', 'OBDX 1', '12 minggu + 3 bulan ext · 12 KG LTH', 3499, '12 Minggu + 3 Bulan (1 kali) + 3 Bulan (1 kali)', 24, '🌱', 'bg-gold-light', true, 9,
  '["12 KG LTH","12 KG LTHPG","Starter Kit","21 Botol Air Afiyah","7 Botol Air Za''afaran","4 Set Herba Kolon","1 Set Enema Kit","1 Set Mesin Ozon","4 Set IV Saline Drip","1 Set DNA Test Kit"]'::jsonb,
  '["26 Sesi Herba Thoharah","6 Kelas Online New Life Challenge","Bimbingan Terapi Peminuman LTH, LTHPG","Bimbingan Terapi Zikir Bersanad","Bimbingan Terapi Diet dan Nutrisi"]'::jsonb,
  '["12 KG LTH","12 KG LTHPG","Starter Kit","21 Botol Air Afiyah","7 Botol Air Za''afaran"]'::jsonb,
  '["Peminuman LTH mengikut jadual (12 KG)","Peminuman LTHPG mengikut jadual","Air Afiyah 1 botol/hari","Herba Thoharah (26 sesi)","Pantau vitals"]'::jsonb,
  '["Bimbingan Terapi Reaksi Pemulihan","Mood tracker","Kelas New Life Challenge"]'::jsonb,
  '["Pemantauan Coach","Konsultasi Hakeema","Perubatan Alami Online"]'::jsonb,
  '["Zikir Bersanad","Perubatan Rohani","Solat hajat"]'::jsonb),

('pkg-obdy1', 'OBDY 1', '12 minggu + multi ext · 21 KG LTH elite', 5999, '12 Minggu + multi extension', 48, '🌱', 'bg-gold-light', true, 10,
  '["21 KG LTH","21 KG LTHPG","Starter Kit","33 Botol Air Afiyah","7 Botol Air Za''afaran","7 Set Herba Kolon"]'::jsonb,
  '["32 Sesi Herba Thoharah","6 Kelas Online New Life Challenge","Bimbingan Terapi lengkap"]'::jsonb,
  '["21 KG LTH","21 KG LTHPG","Starter Kit","33 Botol Air Afiyah"]'::jsonb,
  '["Peminuman LTH (21 KG)","Air Afiyah harian","Herba Thoharah (32 sesi)","Pantau vitals"]'::jsonb,
  '["Bimbingan Terapi Reaksi Pemulihan","Mood tracker","Kelas New Life Challenge"]'::jsonb,
  '["Pemantauan Coach","Konsultasi Hakeema","Perubatan Alami Online"]'::jsonb,
  '["Zikir Bersanad","Perubatan Rohani","Solat hajat"]'::jsonb);

-- OBG
INSERT INTO psy_packages (package_id, name, description, price, duration, duration_weeks, icon, bg_color, is_active, sort_order, products, bimbingan, inclusions, bio_goals, psycho_goals, social_goals, spiritual_goals) VALUES
('pkg-obg', 'OBG', '22 minggu · comprehensive cleansing', 1499, '22 Minggu', 22, '🌿', 'bg-green-light', true, 11,
  '["10 KG IB","8 KG YHPG","Starter Kit","12 Botol Air Afiyah","7 Botol Air Za''afaran","1 Set Herba Kolon","1 Set Enema Kit","1 Set Mesin Ozon","4 Set IV Saline Drip","1 Set DNA Test Kit"]'::jsonb,
  '["20 Sesi Herba Thoharah","6 Kelas Online New Life Challenge","Bimbingan Terapi lengkap"]'::jsonb,
  '["10 KG IB","8 KG YHPG","Starter Kit","12 Botol Air Afiyah","7 Botol Air Za''afaran"]'::jsonb,
  '["Peminuman IB mengikut jadual (10 KG)","Peminuman YHPG (8 KG)","Air Afiyah harian","Herba Thoharah (20 sesi)","Pantau vitals"]'::jsonb,
  '["Bimbingan Terapi Reaksi Pemulihan","Mood tracker","Kelas New Life Challenge"]'::jsonb,
  '["Pemantauan Coach","Konsultasi Hakeema"]'::jsonb,
  '["Zikir Bersanad","Perubatan Rohani","Solat hajat"]'::jsonb);

-- Jump Start
INSERT INTO psy_packages (package_id, name, description, price, duration, duration_weeks, icon, bg_color, is_active, sort_order, products, bimbingan, inclusions, bio_goals, psycho_goals, social_goals, spiritual_goals, phases) VALUES
('pkg-js', 'Jump Start (JS)', 'Program berfasa · Ripple → Spark → Light Up', 799, 'Berfasa (3 fasa × 3 program)', 4, '🚀', 'bg-terracotta-light', true, 12,
  '["Young & Healthy Honey"]'::jsonb,
  '["4 Video Mingguan","Workbook Refleksi","Latihan Kesedaran Emosi","Latihan Fitrah Harian","Coaching Online Mingguan","Pantauan Kaunselor","Group sokongan Jump Start","1 Sesi kaunseling"]'::jsonb,
  '["4 Video Mingguan","Workbook Refleksi","Latihan Kesedaran Emosi","Latihan Fitrah Harian","Coaching Online Mingguan","Young & Healthy Honey"]'::jsonb,
  '["Young & Healthy Honey mengikut coaching","Latihan Fitrah Harian","1 sesi konsultasi fizikal"]'::jsonb,
  '["4 Video Mingguan","Workbook Refleksi","Latihan Kesedaran Emosi","Coaching Online Mingguan"]'::jsonb,
  '["Group sokongan Jump Start","Pantauan Kaunselor"]'::jsonb,
  '["Latihan Fitrah Harian","Latihan Neuropsikologi & Kerohanian","1 Sesi kaunseling bersama Kaunselor Berdaftar"]'::jsonb,
  '["Ripple","Spark","Light Up"]'::jsonb),

('pkg-js-plus', 'Jump Start+ (JS+)', 'JS + Portal VIP + kaunseling extra', 1299, 'Berfasa (3 fasa × 3 program)', 4, '⭐', 'bg-gold-light', true, 13,
  '["Young & Healthy Honey"]'::jsonb,
  '["4 Video Mingguan","Workbook Refleksi","Coaching Online Mingguan","Akses Portal VIP (3 Bulan)","Kaunseling"]'::jsonb,
  '["4 Video Mingguan","Workbook Refleksi","Akses Portal VIP","Young & Healthy Honey"]'::jsonb,
  '["Young & Healthy Honey","Latihan Fitrah Harian","Konsultasi fizikal"]'::jsonb,
  '["Workbook Refleksi","Coaching Online"]'::jsonb,
  '["Group sokongan Jump Start","Pantauan Kaunselor","Akses Portal VIP"]'::jsonb,
  '["Latihan Neuropsikologi & Kerohanian","Kaunseling berdaftar"]'::jsonb,
  '["Ripple","Spark","Light Up"]'::jsonb);

SELECT COUNT(*) AS total_packages FROM psy_packages;
