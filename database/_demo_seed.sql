-- ============================================================
-- DEMO SEED — ISW System (TESTING sahaja: ipmemyizigwgivccytcu)
-- Data lengkap+saling berkait utk demo pengurusan klinik: 15 pesakit
-- rekaan merentasi SEMUA modul utama (rawatan, KOB, bayaran/ansuran,
-- kepatuhan, vitals, peristiwa klinikal, Sesi 1:1, DNA test, surat,
-- feedback, inventori, pesanan, rujukan, promo, risk/emergency alert).
--
-- PENTING sebelum jalankan:
--  1) Jadual psy_patients & psy_kob_sessions ada trigger AFTER INSERT/UPDATE
--     (sync_ghl_patients / sync_ghl_kob_sessions) yg panggil webhook SEBENAR
--     ke Edge Function sync-ghl (ACTIVE, deployed). Insert 15 pesakit + sesi
--     KOB di bawah AKAN cuba sync ke GoHighLevel (akaun TESTING GHL sahaja,
--     tapi masih panggilan luar sebenar). Jika tidak mahu ini berlaku,
--     `ALTER TABLE psy_patients DISABLE TRIGGER sync_ghl_patients;` +
--     `ALTER TABLE psy_kob_sessions DISABLE TRIGGER sync_ghl_kob_sessions;`
--     dulu, lepas tu ENABLE balik selepas seed siap.
--  2) 14 daripada 15 pesakit guna psy_profiles SEDIA ADA (id d0000000-...-1
--     hingga -14, role='patient', ada auth.users juga) — akaun ni sudah
--     wujud sebelum wipe (bukan diwipe, sbb psy_profiles bukan dlm senarai
--     wipe). Kita hanya cipta rekod psy_patients baharu utk mereka.
--  3) active_package_id di psy_patients ialah TEXT & merujuk psy_packages
--     .package_id (kod cth 'pkg-obpy1'), BUKAN psy_packages.id (uuid) —
--     disahkan terus dari information_schema + data live TESTING ni.
--  4) Kolum harga baharu (installment_duration_months, today_price, dst)
--     dari 2 migration 20260826_* SUDAH wujud & berisi data utk pkg-obpx1 +
--     pkg-obpy1 di TESTING — tak perlu apply lagi, terus boleh dipakai.
--  5) mrn & referral_code psy_patients TIDAK diset di sini — dibiar trigger
--     trg_assign_patient_mrn / trg_assign_referral_code auto-jana (BEFORE
--     INSERT, dah wujud, jangan override).
-- ============================================================

BEGIN;

-- Matikan sync GHL sementara (elak webhook keluar sebenar dgn data demo/rekaan)
ALTER TABLE psy_patients DISABLE TRIGGER sync_ghl_patients;
ALTER TABLE psy_kob_sessions DISABLE TRIGGER sync_ghl_kob_sessions;

-- ────────────────────────────────────────────────────────────
-- SEKSYEN 1: PESAKIT (psy_patients) — 15 rekod
-- ────────────────────────────────────────────────────────────
-- Pesakit 1: Siti Aminah binti Hassan — Treatment SELESAI (pkg-EOL+), outcome positif
-- Pesakit 2: Mohd Faizal bin Aziz    — Treatment SELESAI (pkg-vip), perlu Surat Pengesahan
-- Pesakit 3: Lim Wei Sheng           — Ongoing minggu 2/18 (obpy1), ansuran baru mula
-- Pesakit 4: Nurul Huda binti Ismail — Ongoing minggu 6/18 (obpy1), Sesi 1:1 Hakeema, ansuran lunas
-- Pesakit 5: Raj Kumar a/l Subramaniam — Ongoing minggu 14/18 (obpy1), hampir tamat -> continuity offer
-- Pesakit 6: Fatimah binti Omar       — Ongoing minggu 6/18 (obpy1), kepatuhan MERAH + komplen + Sesi 1:1 Hakeem akan datang
-- Pesakit 7: Aisyah binti Kamal       — Plan DIJEDA (warded/hospital), risk+emergency alert
-- Pesakit 8: Tan Chee Keong           — Ongoing minggu 5/18 (obpy1), Rekod Klinikal Temujanji Doktor + lab report
-- Pesakit 9: Zulkifli bin Ahmad       — KOB tertangguh (booked, belum hadir), belum ada pakej
-- Pesakit 10: Hajah Rohani binti Yusof — Ongoing minggu 8/18 (obpy1), ANSURAN TERTUNGGAK, booking_blocked
-- Pesakit 11: Ganesh a/l Marimuthu    — Ongoing minggu 3/18 (obpy1), DNA test step 3 (in_progress)
-- Pesakit 12: Abdullah bin Salleh     — Ongoing minggu 8/16 (vip), DNA test step 6 (completed) + laporan DNA
-- Pesakit 13: Chong Mei Yee           — Ongoing minggu 3/4 (EOL), promo TEST digunakan, rujuk Pesakit 15
-- Pesakit 14: Syed Hassan bin Ali     — Ongoing minggu 9/18 (obpy1), pesanan produk + surat KWSP
-- Pesakit 15: Nor Aini binti Rashid   — Walk-in BAHARU (staff daftar, tiada akaun), KYC selesai, KOB belum tempah

INSERT INTO psy_patients (
  id, user_id, full_name, ic_number, date_of_birth, gender, phone, email,
  home_address, city, state, postcode, marital_status, occupation,
  medical_condition, condition_duration,
  active_package_id, active_package_name, package_purchased_at, package_expires_at,
  next_package_id, next_package_name,
  status, kob_status, outcome_status, outcome_status_at, outcome_status_notes,
  coach_id, assigned_at, created_by_staff, contact_preference,
  emergency_contact_name, emergency_contact_phone, emergency_contact_relationship,
  booking_blocked, booking_blocked_reason, booking_blocked_since,
  referred_by_patient_id, created_at
) VALUES
-- P1 Siti Aminah — selesai
('e1000000-0000-4000-8000-000000000001','d0000000-0000-4000-8000-000000000001','Siti Aminah binti Hassan','850312-14-5523','1985-03-12','F','019-3456701','siti.aminah@example.com',
 'No 12, Jalan Anggerik 3','Shah Alam','Selangor','40150','berkahwin','Guru',
 'Migrain kronik & gangguan tidur','2 tahun',
 'pkg-EOL+','EOL +', now() - interval '30 days', now() + interval '58 days',
 NULL, NULL,
 'active','completed','completed', now() - interval '2 days','Program EOL+ selesai penuh. Tenaga & kualiti tidur meningkat ketara, migrain jarang berulang.',
 '21c4417f-e212-400b-be82-9958456122f5', now() - interval '30 days', false, 'pesakit',
 'Hassan bin Omar','019-3456799','Suami',
 false, NULL, NULL,
 NULL, now() - interval '30 days'),
-- P2 Mohd Faizal — selesai
('e1000000-0000-4000-8000-000000000002','d0000000-0000-4000-8000-000000000002','Mohd Faizal bin Aziz','780625-08-6142','1978-06-25','M','019-3456702','faizal.aziz@example.com',
 'No 8, Lorong Kenanga 5','Petaling Jaya','Selangor','46000','berkahwin','Jurutera',
 'Obesiti & tekanan darah tinggi','5 tahun',
 'pkg-vip','VIP Premium', now() - interval '120 days', now() + interval '-8 days',
 NULL, NULL,
 'active','completed','completed', now() - interval '10 days','Program VIP Premium selesai. Berat turun 9kg, BP kini terkawal tanpa ubat tambahan.',
 'ce8a1971-04b7-44eb-a306-91a1c146cca8', now() - interval '120 days', false, 'pesakit',
 'Aziz bin Yaacob','019-3456798','Bapa',
 false, NULL, NULL,
 NULL, now() - interval '120 days'),
-- P3 Lim Wei Sheng — ongoing wk2
('e1000000-0000-4000-8000-000000000003','d0000000-0000-4000-8000-000000000003','Lim Wei Sheng','900110-10-3387','1990-01-10','M','017-5655704','lim.ws@example.com',
 'No 21, Jalan SS2/24','Petaling Jaya','Selangor','47300','bujang','Akauntan',
 'Kencing manis Jenis 2 (pra-diabetes)','1 tahun',
 'pkg-obpy1','OBPY 1', now() - interval '13 days', now() + interval '113 days',
 NULL, NULL,
 'active','completed','otw', NULL, NULL,
 '349a4c79-2051-4b5b-93d9-369b8464aa3e', now() - interval '13 days', false, 'pesakit',
 'Lim Ah Kow','019-3456697','Bapa',
 false, NULL, NULL,
 NULL, now() - interval '13 days'),
-- P4 Nurul Huda — ongoing wk6, Hakeema 1:1
('e1000000-0000-4000-8000-000000000004','d0000000-0000-4000-8000-000000000004','Nurul Huda binti Ismail','921205-06-4471','1992-12-05','F','019-3456704','nurul.huda@example.com',
 'No 5, Jalan Meranti 2','Ampang','Selangor','68000','berkahwin','Peniaga',
 'Kegelisahan (anxiety) & sakit sendi','3 tahun',
 'pkg-obpy1','OBPY 1', now() - interval '41 days', now() + interval '85 days',
 NULL, NULL,
 'active','completed','otw', NULL, NULL,
 '1480f4da-ec36-475a-9b63-7551a794cd10', now() - interval '41 days', false, 'pesakit',
 'Ismail bin Hashim','019-3456696','Bapa',
 false, NULL, NULL,
 NULL, now() - interval '41 days'),
-- P5 Raj Kumar — ongoing wk14, hampir tamat
('e1000000-0000-4000-8000-000000000005','d0000000-0000-4000-8000-000000000005','Raj Kumar a/l Subramaniam','830418-01-5560','1983-04-18','M','019-3456705','raj.kumar@example.com',
 'No 3, Jalan Pandan Utama','Kuala Lumpur','WP Kuala Lumpur','55100','berkahwin','Pengurus Jualan',
 'Kolesterol tinggi & keletihan kronik','4 tahun',
 'pkg-obpy1','OBPY 1', now() - interval '95 days', now() + interval '31 days',
 'pkg-obpy1','OBPY 1 (Sambungan)',
 'active','completed','otw', NULL, NULL,
 '6c723b61-d010-4106-ba2f-800d7cd37c29', now() - interval '95 days', false, 'pesakit',
 'Priya a/p Subramaniam','019-3456695','Isteri',
 false, NULL, NULL,
 NULL, now() - interval '95 days'),
-- P6 Fatimah — ongoing wk6, kepatuhan merah + komplen
('e1000000-0000-4000-8000-000000000006','d0000000-0000-4000-8000-000000000006','Fatimah binti Omar','950227-03-2298','1995-02-27','F','019-3456706','fatimah.omar@example.com',
 'No 17, Jalan Templer','Klang','Selangor','41200','bujang','Kerani',
 'Masalah pencernaan & gastrik','2 tahun',
 'pkg-obpy1','OBPY 1', now() - interval '39 days', now() + interval '87 days',
 NULL, NULL,
 'active','completed','otw', NULL, NULL,
 '21c4417f-e212-400b-be82-9958456122f5', now() - interval '39 days', false, 'pesakit',
 'Omar bin Ibrahim','019-3456694','Bapa',
 false, NULL, NULL,
 NULL, now() - interval '39 days'),
-- P7 Aisyah — plan dijeda (warded)
('e1000000-0000-4000-8000-000000000007','d0000000-0000-4000-8000-000000000007','Aisyah binti Kamal','880814-05-1179','1988-08-14','F','019-3456707','aisyah.kamal@example.com',
 'No 9, Jalan Bukit Bintang','Kuala Lumpur','WP Kuala Lumpur','55100','berkahwin','Suri Rumah',
 'Jantung (post-angioplasty) & darah tinggi','6 tahun',
 'pkg-obpy1','OBPY 1', now() - interval '33 days', now() + interval '93 days',
 NULL, NULL,
 'active','completed','otw', NULL, NULL,
 'ce8a1971-04b7-44eb-a306-91a1c146cca8', now() - interval '33 days', false, 'waris',
 'Kamal bin Yusof','019-3456693','Suami',
 false, NULL, NULL,
 NULL, now() - interval '33 days'),
-- P8 Tan Chee Keong — ongoing wk5, temujanji doktor
('e1000000-0000-4000-8000-000000000008','d0000000-0000-4000-8000-000000000008','Tan Chee Keong','910503-14-2260','1991-05-03','M','019-3456708','tan.ck@example.com',
 'No 33, Jalan Ipoh','Kuala Lumpur','WP Kuala Lumpur','51200','bujang','Peniaga Online',
 'Asma & alahan kulit','5 tahun',
 'pkg-obpy1','OBPY 1', now() - interval '34 days', now() + interval '92 days',
 NULL, NULL,
 'active','completed','otw', NULL, NULL,
 '349a4c79-2051-4b5b-93d9-369b8464aa3e', now() - interval '34 days', false, 'pesakit',
 'Tan Ah Meng','019-3456692','Bapa',
 false, NULL, NULL,
 NULL, now() - interval '34 days'),
-- P9 Zulkifli — KOB pending
('e1000000-0000-4000-8000-000000000009','d0000000-0000-4000-8000-000000000009','Zulkifli bin Ahmad','870920-06-3345','1987-09-20','M','019-3456709','zulkifli.ahmad@example.com',
 'No 4, Jalan Sungai Besi','Kuala Lumpur','WP Kuala Lumpur','57100','berkahwin','Pemandu Grab',
 'Sakit belakang kronik','1 tahun',
 NULL, NULL, NULL, NULL,
 NULL, NULL,
 'active','booked','otw', NULL, NULL,
 '1480f4da-ec36-475a-9b63-7551a794cd10', now() - interval '5 days', false, 'pesakit',
 'Ahmad bin Salleh','019-3456691','Bapa',
 false, NULL, NULL,
 NULL, now() - interval '6 days'),
-- P10 Hajah Rohani — ansuran tertunggak
('e1000000-0000-4000-8000-000000000010','d0000000-0000-4000-8000-000000000010','Hajah Rohani binti Yusof','651130-08-4412','1965-11-30','F','019-3456710','rohani.yusof@example.com',
 'No 6, Jalan Tun Razak','Kuala Lumpur','WP Kuala Lumpur','50400','balu','Pesara',
 'Osteoartritis lutut & kencing manis','8 tahun',
 'pkg-obpy1','OBPY 1', now() - interval '53 days', now() + interval '73 days',
 NULL, NULL,
 'active','completed','otw', NULL, NULL,
 '6c723b61-d010-4106-ba2f-800d7cd37c29', now() - interval '53 days', false, 'waris',
 'Yusof bin Ismail (anak)','019-3456690','Anak',
 true, 'Ansuran bulanan lewat >14 hari (checkpoint 2 belum dijelaskan)', now() - interval '10 days',
 NULL, now() - interval '53 days'),
-- P11 Ganesh — DNA test step 3
('e1000000-0000-4000-8000-000000000011','d0000000-0000-4000-8000-000000000011','Ganesh a/l Marimuthu','890615-10-5528','1989-06-15','M','019-3456711','ganesh.m@example.com',
 'No 15, Jalan Brickfields','Kuala Lumpur','WP Kuala Lumpur','50470','bujang','Jurujual',
 'Keletihan kronik & masalah tidur','2 tahun',
 'pkg-obpy1','OBPY 1', now() - interval '20 days', now() + interval '106 days',
 NULL, NULL,
 'active','completed','otw', NULL, NULL,
 '21c4417f-e212-400b-be82-9958456122f5', now() - interval '20 days', false, 'pesakit',
 'Marimuthu a/l Subra','019-3456689','Bapa',
 false, NULL, NULL,
 NULL, now() - interval '20 days'),
-- P12 Abdullah — DNA test step 6 selesai
('e1000000-0000-4000-8000-000000000012','d0000000-0000-4000-8000-000000000012','Abdullah bin Salleh','760222-01-6634','1976-02-22','M','019-3456712','abdullah.salleh@example.com',
 'No 2, Jalan Genting Klang','Kuala Lumpur','WP Kuala Lumpur','53300','berkahwin','Peniaga',
 'Darah tinggi & prestat','10 tahun',
 'pkg-vip','VIP Premium', now() - interval '55 days', now() + interval '57 days',
 NULL, NULL,
 'active','completed','otw', NULL, NULL,
 'ce8a1971-04b7-44eb-a306-91a1c146cca8', now() - interval '55 days', false, 'pesakit',
 'Salmah binti Yaacob','019-3456688','Isteri',
 false, NULL, NULL,
 NULL, now() - interval '55 days'),
-- P13 Chong Mei Yee — promo + rujuk P15
('e1000000-0000-4000-8000-000000000013','d0000000-0000-4000-8000-000000000013','Chong Mei Yee','930809-14-2251','1993-08-09','F','019-3456713','chong.my@example.com',
 'No 28, Jalan Kepong','Kuala Lumpur','WP Kuala Lumpur','52100','bujang','Pereka Grafik',
 'Jerawat & masalah kulit','1 tahun',
 'pkg-EOL','EOL', now() - interval '20 days', now() + interval '8 days',
 NULL, NULL,
 'active','completed','otw', NULL, NULL,
 '349a4c79-2051-4b5b-93d9-369b8464aa3e', now() - interval '20 days', false, 'pesakit',
 'Chong Ah Seng','019-3456687','Bapa',
 false, NULL, NULL,
 NULL, now() - interval '20 days'),
-- P14 Syed Hassan — pesanan produk + surat KWSP
('e1000000-0000-4000-8000-000000000014','d0000000-0000-4000-8000-000000000014','Syed Hassan bin Ali','820117-08-3396','1982-01-17','M','019-3456714','syed.hassan@example.com',
 'No 19, Jalan Cheras','Kuala Lumpur','WP Kuala Lumpur','56100','berkahwin','Pegawai KWSP',
 'Migrain & tekanan kerja','3 tahun',
 'pkg-obpy1','OBPY 1', now() - interval '62 days', now() + interval '64 days',
 NULL, NULL,
 'active','completed','otw', NULL, NULL,
 '1480f4da-ec36-475a-9b63-7551a794cd10', now() - interval '62 days', false, 'pesakit',
 'Sharifah binti Ahmad','019-3456686','Isteri',
 false, NULL, NULL,
 NULL, now() - interval '62 days'),
-- P15 Nor Aini — walk-in baharu, tiada akaun
('e1000000-0000-4000-8000-000000000015', NULL, 'Nor Aini binti Rashid','990605-14-1187','1999-06-05','F','019-8887715','norani.rashid@example.com',
 'No 41, Jalan Meru','Klang','Selangor','41050','bujang','Pembantu Kedai',
 'Berat badan berlebihan','1 tahun',
 NULL, NULL, NULL, NULL,
 NULL, NULL,
 'active','kyc_done','otw', NULL, NULL,
 NULL, NULL, true, 'pesakit',
 'Rashid bin Musa','019-8887799','Bapa',
 false, NULL, NULL,
 'e1000000-0000-4000-8000-000000000013', now() - interval '2 days');

-- ────────────────────────────────────────────────────────────
-- SEKSYEN 2: PELAN RAWATAN (psy_treatment_plans) — 13 pesakit
-- (P9 & P15 belum ada pelan — belum lengkap KOB/pakej)
-- ────────────────────────────────────────────────────────────
INSERT INTO psy_treatment_plans (
  id, patient_id, doctor_id, name, template, duration_weeks, current_week,
  bio_goals, psycho_goals, social_goals, spiritual_goals, coaching_schedule,
  status, start_date, sessions_per_week, schedule_setup_at
)
SELECT
  v.plan_id, v.patient_id, v.doctor_id, v.name, v.template, pkg.duration_weeks, v.current_week,
  pkg.bio_goals, pkg.psycho_goals, pkg.social_goals, pkg.spiritual_goals, pkg.coaching_schedule,
  v.status, v.start_date, pkg.sessions_per_week, v.start_date
FROM (VALUES
  ('e2000000-0000-4000-8000-000000000001'::uuid,'e1000000-0000-4000-8000-000000000001'::uuid,'0cb188b0-f2e5-42d8-9071-81b331d88a59'::uuid,'Pelan EOL+ — Siti Aminah','pkg-EOL+',4,(now() - interval '30 days')::date,'completed'),
  ('e2000000-0000-4000-8000-000000000002'::uuid,'e1000000-0000-4000-8000-000000000002'::uuid,'a55529b9-9a5b-488d-b339-3eaac596c75b'::uuid,'Pelan VIP — Mohd Faizal','pkg-vip',16,(now() - interval '120 days')::date,'completed'),
  ('e2000000-0000-4000-8000-000000000003'::uuid,'e1000000-0000-4000-8000-000000000003'::uuid,'0cb188b0-f2e5-42d8-9071-81b331d88a59'::uuid,'Pelan OBPY1 — Lim Wei Sheng','pkg-obpy1',2,(now() - interval '13 days')::date,'active'),
  ('e2000000-0000-4000-8000-000000000004'::uuid,'e1000000-0000-4000-8000-000000000004'::uuid,'a55529b9-9a5b-488d-b339-3eaac596c75b'::uuid,'Pelan OBPY1 — Nurul Huda','pkg-obpy1',6,(now() - interval '41 days')::date,'active'),
  ('e2000000-0000-4000-8000-000000000005'::uuid,'e1000000-0000-4000-8000-000000000005'::uuid,'0cb188b0-f2e5-42d8-9071-81b331d88a59'::uuid,'Pelan OBPY1 — Raj Kumar','pkg-obpy1',14,(now() - interval '95 days')::date,'active'),
  ('e2000000-0000-4000-8000-000000000006'::uuid,'e1000000-0000-4000-8000-000000000006'::uuid,'a55529b9-9a5b-488d-b339-3eaac596c75b'::uuid,'Pelan OBPY1 — Fatimah Omar','pkg-obpy1',6,(now() - interval '39 days')::date,'active'),
  ('e2000000-0000-4000-8000-000000000007'::uuid,'e1000000-0000-4000-8000-000000000007'::uuid,'0cb188b0-f2e5-42d8-9071-81b331d88a59'::uuid,'Pelan OBPY1 — Aisyah Kamal','pkg-obpy1',5,(now() - interval '33 days')::date,'paused'),
  ('e2000000-0000-4000-8000-000000000008'::uuid,'e1000000-0000-4000-8000-000000000008'::uuid,'a55529b9-9a5b-488d-b339-3eaac596c75b'::uuid,'Pelan OBPY1 — Tan Chee Keong','pkg-obpy1',5,(now() - interval '34 days')::date,'active'),
  ('e2000000-0000-4000-8000-000000000010'::uuid,'e1000000-0000-4000-8000-000000000010'::uuid,'0cb188b0-f2e5-42d8-9071-81b331d88a59'::uuid,'Pelan OBPY1 — Hajah Rohani','pkg-obpy1',8,(now() - interval '53 days')::date,'active'),
  ('e2000000-0000-4000-8000-000000000011'::uuid,'e1000000-0000-4000-8000-000000000011'::uuid,'a55529b9-9a5b-488d-b339-3eaac596c75b'::uuid,'Pelan OBPY1 — Ganesh Marimuthu','pkg-obpy1',3,(now() - interval '20 days')::date,'active'),
  ('e2000000-0000-4000-8000-000000000012'::uuid,'e1000000-0000-4000-8000-000000000012'::uuid,'0cb188b0-f2e5-42d8-9071-81b331d88a59'::uuid,'Pelan VIP — Abdullah Salleh','pkg-vip',8,(now() - interval '55 days')::date,'active'),
  ('e2000000-0000-4000-8000-000000000013'::uuid,'e1000000-0000-4000-8000-000000000013'::uuid,'a55529b9-9a5b-488d-b339-3eaac596c75b'::uuid,'Pelan EOL — Chong Mei Yee','pkg-EOL',3,(now() - interval '20 days')::date,'active'),
  ('e2000000-0000-4000-8000-000000000014'::uuid,'e1000000-0000-4000-8000-000000000014'::uuid,'0cb188b0-f2e5-42d8-9071-81b331d88a59'::uuid,'Pelan OBPY1 — Syed Hassan','pkg-obpy1',9,(now() - interval '62 days')::date,'active')
) AS v(plan_id, patient_id, doctor_id, name, template, current_week, start_date, status)
JOIN psy_packages pkg ON pkg.package_id = v.template;

-- ────────────────────────────────────────────────────────────
-- SEKSYEN 3: PROGRES MINGGUAN (psy_plan_weekly_progress)
-- Dijana ikut minggu×hari-sesi sebenar pakej, status auto ikut tarikh
-- (akan datang = booked, lepas = hadir dgn sedikit reschedule/cancel utk realistik)
-- ────────────────────────────────────────────────────────────
-- NOTA PENTING: session_day di psy_plan_weekly_progress ialah ORDINAL slot
-- dalam minggu (1 = sesi pertama, 2 = sesi kedua) — BUKAN hari-dalam-minggu.
-- UI (patient-hub.html ovSessionRow/sessionMap) cari rekod ikut kunci
-- `${week}_1` / `${week}_2` khusus; nilai lain (3,4,5...) akan tersembunyi
-- drpd paparan walaupun rekod wujud. day_offsets di bawah ialah offset
-- HARI SEBENAR (0-6) utk kira tarikh — diasingkan drpd session_day ordinal.
WITH plan_cfg(patient_id, plan_id, coach_id, coach_name, start_date, day_offsets, weeks_to_generate) AS (
  VALUES
  ('e1000000-0000-4000-8000-000000000001'::uuid,'e2000000-0000-4000-8000-000000000001'::uuid,'21c4417f-e212-400b-be82-9958456122f5'::uuid,'Coach Tasnim', (now() - interval '30 days')::date, ARRAY[1], 4),
  ('e1000000-0000-4000-8000-000000000002'::uuid,'e2000000-0000-4000-8000-000000000002'::uuid,'ce8a1971-04b7-44eb-a306-91a1c146cca8'::uuid,'Coach Fazirah', (now() - interval '120 days')::date, ARRAY[2], 16),
  ('e1000000-0000-4000-8000-000000000003'::uuid,'e2000000-0000-4000-8000-000000000003'::uuid,'349a4c79-2051-4b5b-93d9-369b8464aa3e'::uuid,'Aqilah', (now() - interval '13 days')::date, ARRAY[0,3], 2),
  ('e1000000-0000-4000-8000-000000000004'::uuid,'e2000000-0000-4000-8000-000000000004'::uuid,'1480f4da-ec36-475a-9b63-7551a794cd10'::uuid,'Admin Uweis', (now() - interval '41 days')::date, ARRAY[0,3], 6),
  ('e1000000-0000-4000-8000-000000000005'::uuid,'e2000000-0000-4000-8000-000000000005'::uuid,'6c723b61-d010-4106-ba2f-800d7cd37c29'::uuid,'Coach Izzah', (now() - interval '95 days')::date, ARRAY[1,4], 14),
  ('e1000000-0000-4000-8000-000000000006'::uuid,'e2000000-0000-4000-8000-000000000006'::uuid,'21c4417f-e212-400b-be82-9958456122f5'::uuid,'Coach Tasnim', (now() - interval '39 days')::date, ARRAY[0,3], 6),
  ('e1000000-0000-4000-8000-000000000007'::uuid,'e2000000-0000-4000-8000-000000000007'::uuid,'ce8a1971-04b7-44eb-a306-91a1c146cca8'::uuid,'Coach Fazirah', (now() - interval '33 days')::date, ARRAY[2,5], 5),
  ('e1000000-0000-4000-8000-000000000008'::uuid,'e2000000-0000-4000-8000-000000000008'::uuid,'349a4c79-2051-4b5b-93d9-369b8464aa3e'::uuid,'Aqilah', (now() - interval '34 days')::date, ARRAY[1,4], 5),
  ('e1000000-0000-4000-8000-000000000010'::uuid,'e2000000-0000-4000-8000-000000000010'::uuid,'6c723b61-d010-4106-ba2f-800d7cd37c29'::uuid,'Coach Izzah', (now() - interval '53 days')::date, ARRAY[0,3], 8),
  ('e1000000-0000-4000-8000-000000000011'::uuid,'e2000000-0000-4000-8000-000000000011'::uuid,'21c4417f-e212-400b-be82-9958456122f5'::uuid,'Coach Tasnim', (now() - interval '20 days')::date, ARRAY[1,4], 3),
  ('e1000000-0000-4000-8000-000000000012'::uuid,'e2000000-0000-4000-8000-000000000012'::uuid,'ce8a1971-04b7-44eb-a306-91a1c146cca8'::uuid,'Coach Fazirah', (now() - interval '55 days')::date, ARRAY[2], 8),
  ('e1000000-0000-4000-8000-000000000013'::uuid,'e2000000-0000-4000-8000-000000000013'::uuid,'349a4c79-2051-4b5b-93d9-369b8464aa3e'::uuid,'Aqilah', (now() - interval '20 days')::date, ARRAY[3], 3),
  ('e1000000-0000-4000-8000-000000000014'::uuid,'e2000000-0000-4000-8000-000000000014'::uuid,'1480f4da-ec36-475a-9b63-7551a794cd10'::uuid,'Admin Uweis', (now() - interval '62 days')::date, ARRAY[0,3], 9)
),
expanded AS (
  SELECT pc.*, gs AS week_number, ord::int AS session_day,
    (pc.start_date + ((gs-1)*7 + doff) * INTERVAL '1 day')::date AS session_date,
    random() AS r,
    (1 + floor(random()*5))::int AS note_pick,
    random() AS score_r,
    random() AS mood_r,
    random() AS online_r
  FROM plan_cfg pc
  CROSS JOIN LATERAL generate_series(1, pc.weeks_to_generate) AS gs
  CROSS JOIN LATERAL unnest(pc.day_offsets) WITH ORDINALITY AS u(doff, ord)
),
tagged AS (
  SELECT e.*,
    CASE
      WHEN e.session_date > CURRENT_DATE THEN 'booked'
      WHEN e.r < 0.06 THEN 'cancel'
      WHEN e.r < 0.16 THEN 'reschedule'
      ELSE 'hadir'
    END AS status
  FROM expanded e
)
INSERT INTO psy_plan_weekly_progress (
  id, plan_id, patient_id, week_number, status, score, notes, session_date, session_day,
  coach_id, coach_name, attended, session_type, mood_before, mood_after, patient_confirmed, created_at
)
SELECT
  gen_random_uuid(), t.plan_id, t.patient_id, t.week_number,
  t.status,
  CASE WHEN t.status = 'hadir' THEN (6 + floor(t.score_r*5))::int ELSE NULL END AS score,
  CASE t.status
    WHEN 'hadir' THEN (ARRAY[
      'Sesi berjalan lancar, pesakit aktif berbincang.',
      'Pesakit hadir tepat masa, progress memberangsangkan.',
      'Sesi berjalan baik, ada penambahbaikan berbanding minggu lepas.',
      'Hadir seperti dijadualkan, pesakit kongsi perkembangan positif.',
      'Sesi selesai lancar tanpa isu.'
    ])[1 + mod(t.note_pick-1, 5)]
    WHEN 'reschedule' THEN (ARRAY[
      'Pesakit minta tukar tarikh — kekangan kerja.',
      'Ditukar jadual atas permintaan pesakit, urusan keluarga.',
      'Coach tidak dapat hadir, sesi dijadualkan semula.',
      'Pesakit minta tunda — kurang sihat, belum kritikal.'
    ])[1 + mod(t.note_pick-1, 4)]
    WHEN 'cancel' THEN (ARRAY[
      'Sesi dibatalkan, pesakit tidak sihat.',
      'Dibatalkan atas sebab kecemasan keluarga.',
      'Pesakit tidak dapat dihubungi, sesi dibatalkan tanpa notis awal.'
    ])[1 + mod(t.note_pick-1, 3)]
    ELSE NULL
  END AS notes,
  t.session_date, t.session_day, t.coach_id, t.coach_name,
  (t.status = 'hadir') AS attended,
  CASE WHEN t.online_r < 0.35 THEN 'online' ELSE 'f2f' END AS session_type,
  CASE WHEN t.status = 'hadir' THEN (3 + floor(t.mood_r*4))::int ELSE NULL END AS mood_before,
  CASE WHEN t.status = 'hadir' THEN least(10, (3 + floor(t.mood_r*4))::int + 1 + floor(t.score_r*3)::int) ELSE NULL END AS mood_after,
  (t.status = 'hadir') AS patient_confirmed,
  t.session_date::timestamptz
FROM tagged t;

-- 3b. Betulkan pesakit "treatment selesai" (P1, P2) supaya 100% hadir — tiada
--     reschedule/cancel tercicir dalam rekod yang sepatutnya lengkap penuh.
UPDATE psy_plan_weekly_progress
SET status='hadir',
    attended=true,
    score = 7 + (week_number % 3),
    notes = 'Sesi berjalan lancar.',
    mood_before = 4 + (week_number % 4),
    mood_after = 6 + (week_number % 4),
    patient_confirmed = true
WHERE patient_id IN ('e1000000-0000-4000-8000-000000000001','e1000000-0000-4000-8000-000000000002')
  AND status <> 'hadir';

-- ────────────────────────────────────────────────────────────
-- SEKSYEN 4: SESI 1:1 (Hakeema/Hakeem/Dr) — psy_clinical_referrals (source='plan_1on1')
-- ────────────────────────────────────────────────────────────
-- P4 Nurul Huda: Sesi Hakeema minggu 6 — sudah selesai (resolved)
INSERT INTO psy_clinical_referrals (
  id, patient_id, referred_by, referred_by_name, target_role, target_id, target_name,
  reason, meet_date, priority, status, resolution_note, consultation_note, consultation,
  plan_id, week_number, source, session_type, created_at, resolved_at
) VALUES (
  gen_random_uuid(), 'e1000000-0000-4000-8000-000000000004', '1480f4da-ec36-475a-9b63-7551a794cd10','Admin Uweis',
  'manager', NULL, 'Hakeema',
  'Sesi 1:1 Hakeema Session', (now() - interval '6 days')::date, 'sederhana', 'resolved',
  'Sesi selesai, pesakit lebih tenang selepas bimbingan zikir & pernafasan.',
  'Pesakit kongsi tentang kegelisahan berkaitan kerja. Diberi panduan zikir bersanad & teknik pernafasan fitrah.',
  '{"scheduled_time":"10:00","duration_minutes":45,"purpose":"Bimbingan kegelisahan & sokongan emosi"}'::jsonb,
  'e2000000-0000-4000-8000-000000000004', 6, 'plan_1on1', 'hakeema',
  now() - interval '6 days', now() - interval '6 days'
);

-- P6 Fatimah Omar: Sesi Hakeem minggu 6 — akan datang (belum berlaku, susulan komplen)
INSERT INTO psy_clinical_referrals (
  id, patient_id, referred_by, referred_by_name, target_role, target_id, target_name,
  reason, meet_date, priority, status, consultation,
  plan_id, week_number, source, session_type, created_at
) VALUES (
  gen_random_uuid(), 'e1000000-0000-4000-8000-000000000006', '21c4417f-e212-400b-be82-9958456122f5','Coach Tasnim',
  'manager', NULL, 'Hakeem',
  'Sesi 1:1 Hakeem Session — susulan aduan bekalan & jadual', (now() + interval '3 days')::date, 'tinggi', 'pending',
  '{"scheduled_time":"14:00","duration_minutes":30,"purpose":"Susulan aduan kepatuhan rendah & bekalan lewat"}'::jsonb,
  'e2000000-0000-4000-8000-000000000006', 6, 'plan_1on1', 'hakeem',
  now() - interval '1 day'
);

-- ────────────────────────────────────────────────────────────
-- SEKSYEN 5: KOB — psy_kob_sessions, psy_kob_agreements, psy_package_purchases,
--             psy_payments, psy_kob_installment_checkpoints
-- ────────────────────────────────────────────────────────────

-- 5a. Sesi KOB (semua pesakit yg dah lalui KOB = P1-P8, P10-P14; P9 baru booked; P15 belum tempah)
INSERT INTO psy_kob_sessions (
  id, patient_id, scheduled_at, mode, status, doctor_hadir_id, doctor_hadir_name, hadir_at,
  doctor_selesai_id, doctor_selesai_name, selesai_at, recommended_package_id, recommended_package_name,
  recommended_package_price, recommended_at, recommended_by, recommended_by_name,
  package_payment_status, package_paid_at, package_receipt_ref, package_payment_mode, created_at
) VALUES
('e3000000-0000-4000-8000-000000000001','e1000000-0000-4000-8000-000000000001', now() - interval '31 days','f2f','completed','0cb188b0-f2e5-42d8-9071-81b331d88a59','DR Nornajihah', now() - interval '31 days','0cb188b0-f2e5-42d8-9071-81b331d88a59','DR Nornajihah', now() - interval '31 days','pkg-EOL+','EOL +',698.00, now() - interval '31 days','0cb188b0-f2e5-42d8-9071-81b331d88a59','DR Nornajihah','paid', now() - interval '30 days','RCPT-2026-1001','full', now() - interval '31 days'),
('e3000000-0000-4000-8000-000000000002','e1000000-0000-4000-8000-000000000002', now() - interval '121 days','f2f','completed','a55529b9-9a5b-488d-b339-3eaac596c75b','Khairil Arham', now() - interval '121 days','a55529b9-9a5b-488d-b339-3eaac596c75b','Khairil Arham', now() - interval '121 days','pkg-vip','VIP Premium',2999.00, now() - interval '121 days','a55529b9-9a5b-488d-b339-3eaac596c75b','Khairil Arham','paid', now() - interval '120 days','RCPT-2026-1002','full', now() - interval '121 days'),
('e3000000-0000-4000-8000-000000000003','e1000000-0000-4000-8000-000000000003', now() - interval '14 days','f2f','completed','0cb188b0-f2e5-42d8-9071-81b331d88a59','DR Nornajihah', now() - interval '14 days','0cb188b0-f2e5-42d8-9071-81b331d88a59','DR Nornajihah', now() - interval '14 days','pkg-obpy1','OBPY 1',42500.00, now() - interval '14 days','0cb188b0-f2e5-42d8-9071-81b331d88a59','DR Nornajihah','partial', now() - interval '13 days','RCPT-2026-1003','installment', now() - interval '14 days'),
('e3000000-0000-4000-8000-000000000004','e1000000-0000-4000-8000-000000000004', now() - interval '42 days','f2f','completed','a55529b9-9a5b-488d-b339-3eaac596c75b','Khairil Arham', now() - interval '42 days','a55529b9-9a5b-488d-b339-3eaac596c75b','Khairil Arham', now() - interval '42 days','pkg-obpy1','OBPY 1',42500.00, now() - interval '42 days','a55529b9-9a5b-488d-b339-3eaac596c75b','Khairil Arham','paid', now() - interval '41 days','RCPT-2026-1004','installment', now() - interval '42 days'),
('e3000000-0000-4000-8000-000000000005','e1000000-0000-4000-8000-000000000005', now() - interval '96 days','f2f','completed','0cb188b0-f2e5-42d8-9071-81b331d88a59','DR Nornajihah', now() - interval '96 days','0cb188b0-f2e5-42d8-9071-81b331d88a59','DR Nornajihah', now() - interval '96 days','pkg-obpy1','OBPY 1',42500.00, now() - interval '96 days','0cb188b0-f2e5-42d8-9071-81b331d88a59','DR Nornajihah','paid', now() - interval '95 days','RCPT-2026-1005','full', now() - interval '96 days'),
('e3000000-0000-4000-8000-000000000006','e1000000-0000-4000-8000-000000000006', now() - interval '40 days','f2f','completed','a55529b9-9a5b-488d-b339-3eaac596c75b','Khairil Arham', now() - interval '40 days','a55529b9-9a5b-488d-b339-3eaac596c75b','Khairil Arham', now() - interval '40 days','pkg-obpy1','OBPY 1',42500.00, now() - interval '40 days','a55529b9-9a5b-488d-b339-3eaac596c75b','Khairil Arham','paid', now() - interval '39 days','RCPT-2026-1006','full', now() - interval '40 days'),
('e3000000-0000-4000-8000-000000000007','e1000000-0000-4000-8000-000000000007', now() - interval '34 days','f2f','completed','0cb188b0-f2e5-42d8-9071-81b331d88a59','DR Nornajihah', now() - interval '34 days','0cb188b0-f2e5-42d8-9071-81b331d88a59','DR Nornajihah', now() - interval '34 days','pkg-obpy1','OBPY 1',42500.00, now() - interval '34 days','0cb188b0-f2e5-42d8-9071-81b331d88a59','DR Nornajihah','paid', now() - interval '33 days','RCPT-2026-1007','full', now() - interval '34 days'),
('e3000000-0000-4000-8000-000000000008','e1000000-0000-4000-8000-000000000008', now() - interval '35 days','f2f','completed','a55529b9-9a5b-488d-b339-3eaac596c75b','Khairil Arham', now() - interval '35 days','a55529b9-9a5b-488d-b339-3eaac596c75b','Khairil Arham', now() - interval '35 days','pkg-obpy1','OBPY 1',42500.00, now() - interval '35 days','a55529b9-9a5b-488d-b339-3eaac596c75b','Khairil Arham','paid', now() - interval '34 days','RCPT-2026-1008','full', now() - interval '35 days'),
('e3000000-0000-4000-8000-000000000009','e1000000-0000-4000-8000-000000000009', now() + interval '4 days','f2f','booked', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,'pending', NULL, NULL, NULL, now() - interval '5 days'),
('e3000000-0000-4000-8000-000000000010','e1000000-0000-4000-8000-000000000010', now() - interval '54 days','f2f','completed','0cb188b0-f2e5-42d8-9071-81b331d88a59','DR Nornajihah', now() - interval '54 days','0cb188b0-f2e5-42d8-9071-81b331d88a59','DR Nornajihah', now() - interval '54 days','pkg-obpy1','OBPY 1',42500.00, now() - interval '54 days','0cb188b0-f2e5-42d8-9071-81b331d88a59','DR Nornajihah','partial', now() - interval '53 days','RCPT-2026-1010','installment', now() - interval '54 days'),
('e3000000-0000-4000-8000-000000000011','e1000000-0000-4000-8000-000000000011', now() - interval '21 days','f2f','completed','a55529b9-9a5b-488d-b339-3eaac596c75b','Khairil Arham', now() - interval '21 days','a55529b9-9a5b-488d-b339-3eaac596c75b','Khairil Arham', now() - interval '21 days','pkg-obpy1','OBPY 1',42500.00, now() - interval '21 days','a55529b9-9a5b-488d-b339-3eaac596c75b','Khairil Arham','partial', now() - interval '20 days','RCPT-2026-1011','installment', now() - interval '21 days'),
('e3000000-0000-4000-8000-000000000012','e1000000-0000-4000-8000-000000000012', now() - interval '56 days','f2f','completed','0cb188b0-f2e5-42d8-9071-81b331d88a59','DR Nornajihah', now() - interval '56 days','0cb188b0-f2e5-42d8-9071-81b331d88a59','DR Nornajihah', now() - interval '56 days','pkg-vip','VIP Premium',2999.00, now() - interval '56 days','0cb188b0-f2e5-42d8-9071-81b331d88a59','DR Nornajihah','paid', now() - interval '55 days','RCPT-2026-1012','full', now() - interval '56 days'),
('e3000000-0000-4000-8000-000000000013','e1000000-0000-4000-8000-000000000013', now() - interval '21 days','online','completed','a55529b9-9a5b-488d-b339-3eaac596c75b','Khairil Arham', now() - interval '21 days','a55529b9-9a5b-488d-b339-3eaac596c75b','Khairil Arham', now() - interval '21 days','pkg-EOL','EOL',399.00, now() - interval '21 days','a55529b9-9a5b-488d-b339-3eaac596c75b','Khairil Arham','paid', now() - interval '20 days','RCPT-2026-1013','full', now() - interval '21 days'),
('e3000000-0000-4000-8000-000000000014','e1000000-0000-4000-8000-000000000014', now() - interval '63 days','f2f','completed','0cb188b0-f2e5-42d8-9071-81b331d88a59','DR Nornajihah', now() - interval '63 days','0cb188b0-f2e5-42d8-9071-81b331d88a59','DR Nornajihah', now() - interval '63 days','pkg-obpy1','OBPY 1',42500.00, now() - interval '63 days','0cb188b0-f2e5-42d8-9071-81b331d88a59','DR Nornajihah','paid', now() - interval '62 days','RCPT-2026-1014','full', now() - interval '63 days');

-- 5b. Perjanjian KOB ditandatangan (semua P1-P8,P10-P14)
INSERT INTO psy_kob_agreements (id, patient_id, kob_session_id, patient_name, patient_ic, signature_url, signed_pdf_url, signed_at)
SELECT gen_random_uuid(), p.id, k.id, p.full_name, p.ic_number,
  '/uploads/demo/ttd-' || p.id || '.png', '/uploads/demo/agreement-' || p.id || '.pdf', k.selesai_at
FROM psy_patients p JOIN psy_kob_sessions k ON k.patient_id = p.id
WHERE k.status = 'completed';

-- 5c. Pembelian pakej (psy_package_purchases)
INSERT INTO psy_package_purchases (id, patient_id, package_id, package_name, price, purchased_at, expires_at, status, payment_method) VALUES
('e5000000-0000-4000-8000-000000000001','e1000000-0000-4000-8000-000000000001','pkg-EOL+','EOL +',698.00, now() - interval '30 days', now() + interval '58 days','active','full'),
('e5000000-0000-4000-8000-000000000002','e1000000-0000-4000-8000-000000000002','pkg-vip','VIP Premium',2999.00, now() - interval '120 days', now() + interval '-8 days','expired','full'),
('e5000000-0000-4000-8000-000000000003','e1000000-0000-4000-8000-000000000003','pkg-obpy1','OBPY 1',42500.00, now() - interval '13 days', now() + interval '113 days','active','installment'),
('e5000000-0000-4000-8000-000000000004','e1000000-0000-4000-8000-000000000004','pkg-obpy1','OBPY 1',42500.00, now() - interval '41 days', now() + interval '85 days','active','installment'),
('e5000000-0000-4000-8000-000000000005','e1000000-0000-4000-8000-000000000005','pkg-obpy1','OBPY 1',42500.00, now() - interval '95 days', now() + interval '31 days','active','full'),
('e5000000-0000-4000-8000-000000000006','e1000000-0000-4000-8000-000000000006','pkg-obpy1','OBPY 1',42500.00, now() - interval '39 days', now() + interval '87 days','active','full'),
('e5000000-0000-4000-8000-000000000007','e1000000-0000-4000-8000-000000000007','pkg-obpy1','OBPY 1',42500.00, now() - interval '33 days', now() + interval '93 days','active','full'),
('e5000000-0000-4000-8000-000000000008','e1000000-0000-4000-8000-000000000008','pkg-obpy1','OBPY 1',42500.00, now() - interval '34 days', now() + interval '92 days','active','full'),
('e5000000-0000-4000-8000-000000000010','e1000000-0000-4000-8000-000000000010','pkg-obpy1','OBPY 1',42500.00, now() - interval '53 days', now() + interval '73 days','active','installment'),
('e5000000-0000-4000-8000-000000000011','e1000000-0000-4000-8000-000000000011','pkg-obpy1','OBPY 1',42500.00, now() - interval '20 days', now() + interval '106 days','active','installment'),
('e5000000-0000-4000-8000-000000000012','e1000000-0000-4000-8000-000000000012','pkg-vip','VIP Premium',2999.00, now() - interval '55 days', now() + interval '57 days','active','full'),
('e5000000-0000-4000-8000-000000000013','e1000000-0000-4000-8000-000000000013','pkg-EOL','EOL',399.00, now() - interval '20 days', now() + interval '8 days','active','full'),
('e5000000-0000-4000-8000-000000000014','e1000000-0000-4000-8000-000000000014','pkg-obpy1','OBPY 1',42500.00, now() - interval '62 days', now() + interval '64 days','active','full');

-- 5d. Bayaran (psy_payments) — bayaran penuh utk pesakit bukan-ansuran, deposit+bulanan utk ansuran
INSERT INTO psy_payments (id, receipt_ref, patient_id, total, payment_method, status, paid_at, invoice_number, notes) VALUES
('e6000000-0000-4000-8000-000000000001','RCPT-2026-1001','e1000000-0000-4000-8000-000000000001',698.00,'card','completed', now() - interval '30 days','INV-1001','Bayaran penuh pakej EOL+'),
('e6000000-0000-4000-8000-000000000002','RCPT-2026-1002','e1000000-0000-4000-8000-000000000002',2999.00,'transfer','completed', now() - interval '120 days','INV-1002','Bayaran penuh pakej VIP Premium'),
('e6000000-0000-4000-8000-000000000005','RCPT-2026-1005','e1000000-0000-4000-8000-000000000005',42500.00,'card','completed', now() - interval '95 days','INV-1005','Bayaran penuh pakej OBPY 1'),
('e6000000-0000-4000-8000-000000000006','RCPT-2026-1006','e1000000-0000-4000-8000-000000000006',42500.00,'transfer','completed', now() - interval '39 days','INV-1006','Bayaran penuh pakej OBPY 1'),
('e6000000-0000-4000-8000-000000000007','RCPT-2026-1007','e1000000-0000-4000-8000-000000000007',42500.00,'card','completed', now() - interval '33 days','INV-1007','Bayaran penuh pakej OBPY 1'),
('e6000000-0000-4000-8000-000000000008','RCPT-2026-1008','e1000000-0000-4000-8000-000000000008',42500.00,'card','completed', now() - interval '34 days','INV-1008','Bayaran penuh pakej OBPY 1'),
('e6000000-0000-4000-8000-000000000012','RCPT-2026-1012','e1000000-0000-4000-8000-000000000012',2999.00,'transfer','completed', now() - interval '55 days','INV-1012','Bayaran penuh pakej VIP Premium'),
('e6000000-0000-4000-8000-000000000013','RCPT-2026-1013','e1000000-0000-4000-8000-000000000013',359.10,'card','completed', now() - interval '20 days','INV-1013','Bayaran EOL selepas diskaun promo TEST (10%)'),
('e6000000-0000-4000-8000-000000000014','RCPT-2026-1014','e1000000-0000-4000-8000-000000000014',42500.00,'card','completed', now() - interval '62 days','INV-1014','Bayaran penuh pakej OBPY 1'),
-- Ansuran: P3 (deposit + 1 bulan dibayar, 2 baki)
('e6000000-0000-4000-8000-000000000031','RCPT-2026-1031','e1000000-0000-4000-8000-000000000003',21200.00,'card','completed', now() - interval '13 days','INV-1031','Deposit ansuran OBPY 1'),
('e6000000-0000-4000-8000-000000000032','RCPT-2026-1032','e1000000-0000-4000-8000-000000000003',13000.00,'fpx','completed', now() - interval '13 days','INV-1032','Ansuran bulan 1'),
-- Ansuran: P4 (deposit + 3 bulan penuh — lunas)
('e6000000-0000-4000-8000-000000000041','RCPT-2026-1041','e1000000-0000-4000-8000-000000000004',21200.00,'card','completed', now() - interval '41 days','INV-1041','Deposit ansuran OBPY 1'),
('e6000000-0000-4000-8000-000000000042','RCPT-2026-1042','e1000000-0000-4000-8000-000000000004',13000.00,'fpx','completed', now() - interval '30 days','INV-1042','Ansuran bulan 1'),
('e6000000-0000-4000-8000-000000000043','RCPT-2026-1043','e1000000-0000-4000-8000-000000000004',13000.00,'fpx','completed', now() - interval '10 days','INV-1043','Ansuran bulan 2 — LUNAS'),
-- Ansuran: P10 (deposit dibayar, bulan 1 dibayar, bulan 2 TERTUNGGAK)
('e6000000-0000-4000-8000-000000000101','RCPT-2026-1101','e1000000-0000-4000-8000-000000000010',21200.00,'card','completed', now() - interval '53 days','INV-1101','Deposit ansuran OBPY 1'),
('e6000000-0000-4000-8000-000000000102','RCPT-2026-1102','e1000000-0000-4000-8000-000000000010',13000.00,'fpx','completed', now() - interval '23 days','INV-1102','Ansuran bulan 1'),
-- Ansuran: P11 (deposit + bulan 1 dibayar, bulan 2 & 3 belum tiba giliran)
('e6000000-0000-4000-8000-000000000111','RCPT-2026-1111','e1000000-0000-4000-8000-000000000011',21200.00,'card','completed', now() - interval '20 days','INV-1111','Deposit ansuran OBPY 1'),
('e6000000-0000-4000-8000-000000000112','RCPT-2026-1112','e1000000-0000-4000-8000-000000000011',13000.00,'fpx','completed', now() - interval '5 days','INV-1112','Ansuran bulan 1');

-- 5e. Checkpoint ansuran (psy_kob_installment_checkpoints) — P3 (on-track), P4 (lunas), P10 (TERTUNGGAK), P11 (on-track)
INSERT INTO psy_kob_installment_checkpoints (id, kob_session_id, patient_id, seq, month_offset, due_date, target_cumulative, status, met_at, installment_reminder_sent_at) VALUES
-- P3: bulan1 met, bulan2 & 3 pending
('e7000000-0000-4000-8000-000000000031','e3000000-0000-4000-8000-000000000003','e1000000-0000-4000-8000-000000000003',1,1,(now() - interval '13 days' + interval '1 month')::date,34200.00,'met', now() - interval '13 days', NULL),
('e7000000-0000-4000-8000-000000000032','e3000000-0000-4000-8000-000000000003','e1000000-0000-4000-8000-000000000003',2,2,(now() - interval '13 days' + interval '2 month')::date,47200.00,'pending', NULL, NULL),
('e7000000-0000-4000-8000-000000000033','e3000000-0000-4000-8000-000000000003','e1000000-0000-4000-8000-000000000003',3,3,(now() - interval '13 days' + interval '3 month')::date,60200.00,'pending', NULL, NULL),
-- P4: kesemua 3 met (lunas)
('e7000000-0000-4000-8000-000000000041','e3000000-0000-4000-8000-000000000004','e1000000-0000-4000-8000-000000000004',1,1,(now() - interval '41 days' + interval '1 month')::date,34200.00,'met', now() - interval '30 days', NULL),
('e7000000-0000-4000-8000-000000000042','e3000000-0000-4000-8000-000000000004','e1000000-0000-4000-8000-000000000004',2,2,(now() - interval '41 days' + interval '2 month')::date,47200.00,'met', now() - interval '10 days', NULL),
('e7000000-0000-4000-8000-000000000043','e3000000-0000-4000-8000-000000000004','e1000000-0000-4000-8000-000000000004',3,3,(now() - interval '41 days' + interval '3 month')::date,60200.00,'met', now() - interval '2 days', NULL),
-- P10: bulan1 met, bulan2 OVERDUE, bulan3 pending
('e7000000-0000-4000-8000-000000000101','e3000000-0000-4000-8000-000000000010','e1000000-0000-4000-8000-000000000010',1,1,(now() - interval '53 days' + interval '1 month')::date,34200.00,'met', now() - interval '23 days', NULL),
('e7000000-0000-4000-8000-000000000102','e3000000-0000-4000-8000-000000000010','e1000000-0000-4000-8000-000000000010',2,2,(now() - interval '53 days' + interval '2 month')::date,47200.00,'overdue', NULL, now() - interval '9 days'),
('e7000000-0000-4000-8000-000000000103','e3000000-0000-4000-8000-000000000010','e1000000-0000-4000-8000-000000000010',3,3,(now() - interval '53 days' + interval '3 month')::date,60200.00,'pending', NULL, NULL),
-- P11: bulan1 met, bulan2 & 3 pending (belum sampai tarikh)
('e7000000-0000-4000-8000-000000000111','e3000000-0000-4000-8000-000000000011','e1000000-0000-4000-8000-000000000011',1,1,(now() - interval '20 days' + interval '1 month')::date,34200.00,'met', now() - interval '5 days', NULL),
('e7000000-0000-4000-8000-000000000112','e3000000-0000-4000-8000-000000000011','e1000000-0000-4000-8000-000000000011',2,2,(now() - interval '20 days' + interval '2 month')::date,47200.00,'pending', NULL, NULL),
('e7000000-0000-4000-8000-000000000113','e3000000-0000-4000-8000-000000000011','e1000000-0000-4000-8000-000000000011',3,3,(now() - interval '20 days' + interval '3 month')::date,60200.00,'pending', NULL, NULL);

-- ────────────────────────────────────────────────────────────
-- SEKSYEN 6: KYC SUBMISSIONS (rekod sejarah — Gate 1 auto-lulus)
-- ────────────────────────────────────────────────────────────
INSERT INTO psy_kyc_submissions (id, user_id, patient_name, ic_number, date_of_birth, gender, phone, email, address, status, reviewed_by, review_notes, created_at) VALUES
(gen_random_uuid(),'d0000000-0000-4000-8000-000000000009','Zulkifli bin Ahmad','870920-06-3345','1987-09-20','lelaki','019-3456709','zulkifli.ahmad@example.com','No 4, Jalan Sungai Besi, Kuala Lumpur','approved','419da34c-3ab9-47c2-9046-d8bd36d7c80c','Auto-lulus (Gate 1 dibuang) — semakan staf hanya rekod.', now() - interval '6 days'),
(gen_random_uuid(), NULL,'Nor Aini binti Rashid','990605-14-1187','1999-06-05','perempuan','019-8887715','norani.rashid@example.com','No 41, Jalan Meru, Klang','approved','419da34c-3ab9-47c2-9046-d8bd36d7c80c','Auto-lulus (Gate 1 dibuang) — didaftar staf semasa event walk-in.', now() - interval '2 days');

-- ────────────────────────────────────────────────────────────
-- SEKSYEN 7: REKOD KLINIKAL (psy_patient_events + visits)
-- ────────────────────────────────────────────────────────────
-- P7 Aisyah — Warded (jantung), perlu lawatan
INSERT INTO psy_patient_events (
  id, patient_id, event_type, priority, status, event_date, event_time, expected_discharge,
  hospital_name, ward_room, bed_unit, doctor_in_charge, diagnosis, reference_no,
  emergency_contact_name, emergency_contact_phone, emergency_contact_relationship,
  need_visit, visit_priority, expected_visit_date, assigned_to, notes, reported_by, created_at
) VALUES (
  'e9000000-0000-4000-8000-000000000001','e1000000-0000-4000-8000-000000000007','warded','high','open',
  (now() - interval '2 days')::date, '14:30', (now() + interval '3 days')::date,
  'Hospital Selayang','Wad Kardiologi 3B','Katil 12','Dr. Hafiz Rahman','Kambuh sakit dada, susulan post-angioplasty','HS-2026-88213',
  'Kamal bin Yusof','019-3456693','Suami',
  true,'high', (now() + interval '1 day')::date, 'ce8a1971-04b7-44eb-a306-91a1c146cca8',
  'Pesakit dimasukkan wad selepas mengadu sakit dada semasa sesi kepatuhan. Pelan rawatan dijeda sementara.',
  'ce8a1971-04b7-44eb-a306-91a1c146cca8', now() - interval '2 days'
);

INSERT INTO psy_patient_event_visits (
  id, event_id, patient_id, visit_date, visit_time, visit_type, visited_by, status,
  patient_condition, location, ward_room, person_met, relationship, notes, completed_at, created_by
) VALUES
('ea000000-0000-4000-8000-000000000001','e9000000-0000-4000-8000-000000000001','e1000000-0000-4000-8000-000000000007', (now() - interval '1 day')::date,'11:00','hospital','ce8a1971-04b7-44eb-a306-91a1c146cca8','completed',
 'stabil','Hospital Selayang','Wad Kardiologi 3B','Kamal bin Yusof','Suami','Pesakit stabil, sedang menerima rawatan. Waris dimaklumkan tentang jadual susulan.', now() - interval '1 day','ce8a1971-04b7-44eb-a306-91a1c146cca8'),
('ea000000-0000-4000-8000-000000000002','e9000000-0000-4000-8000-000000000001','e1000000-0000-4000-8000-000000000007', (now() + interval '1 day')::date,'11:00','hospital', NULL,'pending',
 NULL,'Hospital Selayang','Wad Kardiologi 3B', NULL, NULL,'Lawatan susulan dijadualkan.', NULL, 'ce8a1971-04b7-44eb-a306-91a1c146cca8');

-- P8 Tan Chee Keong — Temujanji Doktor (asma)
INSERT INTO psy_patient_events (
  id, patient_id, event_type, priority, status, event_date, event_time,
  hospital_name, doctor_in_charge, diagnosis, reference_no,
  emergency_contact_name, emergency_contact_phone, emergency_contact_relationship,
  need_visit, notes, reported_by, created_at
) VALUES (
  'e9000000-0000-4000-8000-000000000002','e1000000-0000-4000-8000-000000000008','temujanji_doktor','medium','closed',
  (now() - interval '4 days')::date, '09:30',
  'Klinik Pakar Paru KL','Dr. Suresh Nathan','Susulan asma & ujian fungsi paru','KP-2026-4471',
  'Tan Ah Meng','019-3456692','Bapa',
  false, 'Temujanji rutin susulan asma. Keputusan spirometri stabil.', '349a4c79-2051-4b5b-93d9-369b8464aa3e', now() - interval '4 days'
);

-- ────────────────────────────────────────────────────────────
-- SEKSYEN 8: DNA TEST PROCESS
-- ────────────────────────────────────────────────────────────
-- P11 Ganesh — step 3 (kit dibungkus, hantar ke lab belum)
INSERT INTO psy_dna_test_process (
  id, patient_id, coach_id, current_step, status, sample_checklist, sample_collected_at, sample_collected_by,
  barcode_number, packaging_checklist, packaging_completed_at, atgc_status, created_by, created_at
) VALUES (
  'eb000000-0000-4000-8000-000000000011','e1000000-0000-4000-8000-000000000011','21c4417f-e212-400b-be82-9958456122f5',3,'in_progress',
  '{"swab_taken":true,"consent_signed":true}'::jsonb, now() - interval '6 days','21c4417f-e212-400b-be82-9958456122f5',
  'ATGC-DNA-88231', '{"sealed":true,"labeled":true,"cooler_box":true}'::jsonb, now() - interval '4 days','not_activated',
  '21c4417f-e212-400b-be82-9958456122f5', now() - interval '7 days'
);

-- P12 Abdullah — step 6 (selesai, laporan sudah dihantar)
INSERT INTO psy_dna_test_process (
  id, patient_id, coach_id, current_step, status, sample_checklist, sample_collected_at, sample_collected_by,
  barcode_number, packaging_checklist, packaging_completed_at, atgc_status, atgc_activated_at, atgc_activated_by,
  report_notes, reports_uploaded_at, consultation_notes, consultation_marked_ready_at, completed_at, completed_by,
  kit_received_at, sample_sent_to_lab_at, lab_report_issued_at, reports_emailed_at, created_by, created_at
) VALUES (
  'eb000000-0000-4000-8000-000000000012','e1000000-0000-4000-8000-000000000012','ce8a1971-04b7-44eb-a306-91a1c146cca8',6,'completed',
  '{"swab_taken":true,"consent_signed":true}'::jsonb, now() - interval '45 days','ce8a1971-04b7-44eb-a306-91a1c146cca8',
  'ATGC-DNA-77120', '{"sealed":true,"labeled":true,"cooler_box":true}'::jsonb, now() - interval '43 days','activated', now() - interval '42 days','ce8a1971-04b7-44eb-a306-91a1c146cca8',
  'Keputusan menunjukkan kecenderungan metabolik & sensitiviti gluten sederhana.', now() - interval '20 days',
  'Konsultasi bersama Dr Nornajihah — cadangan penyesuaian diet & suplemen.', now() - interval '15 days', now() - interval '10 days','0cb188b0-f2e5-42d8-9071-81b331d88a59',
  (now() - interval '48 days')::date, (now() - interval '44 days')::date, (now() - interval '22 days')::date, now() - interval '20 days',
  'ce8a1971-04b7-44eb-a306-91a1c146cca8', now() - interval '48 days'
);

-- ────────────────────────────────────────────────────────────
-- SEKSYEN 9: LAPORAN PERUBATAN (psy_medical_reports)
-- ────────────────────────────────────────────────────────────
INSERT INTO psy_medical_reports (id, patient_id, file_name, file_path, file_url, notes, uploaded_by, uploaded_by_name, uploaded_at, report_type, title, status, doctor_id, doctor_name, doctor_review, review_status, shared_with_patient, source) VALUES
('ec000000-0000-4000-8000-000000000007','e1000000-0000-4000-8000-000000000007','xray-dada-aisyah.pdf','/uploads/demo/xray-dada-aisyah.pdf','/uploads/demo/xray-dada-aisyah.pdf','X-Ray dada semasa diwadkan.','ce8a1971-04b7-44eb-a306-91a1c146cca8','Coach Fazirah', now() - interval '1 day','xray','X-Ray Dada — Hospital Selayang','reviewed','0cb188b0-f2e5-42d8-9071-81b331d88a59','DR Nornajihah','Keputusan menunjukkan tiada kerosakan baharu, konsisten dengan riwayat post-angioplasty.','reviewed', true,'staff'),
('ec000000-0000-4000-8000-000000000008','e1000000-0000-4000-8000-000000000008','lab-spirometri-tan.pdf','/uploads/demo/lab-spirometri-tan.pdf','/uploads/demo/lab-spirometri-tan.pdf','Keputusan ujian fungsi paru (spirometri).','349a4c79-2051-4b5b-93d9-369b8464aa3e','Aqilah', now() - interval '4 days','lab','Ujian Fungsi Paru — Klinik Pakar Paru KL','reviewed','a55529b9-9a5b-488d-b339-3eaac596c75b','Khairil Arham','FEV1/FVC dalam julat normal, asma terkawal dengan baik.','reviewed', true,'staff'),
('ec000000-0000-4000-8000-000000000012','e1000000-0000-4000-8000-000000000012','dna-report-abdullah.pdf','/uploads/demo/dna-report-abdullah.pdf','/uploads/demo/dna-report-abdullah.pdf','Laporan penuh OH MY GENE / ATGC.','ce8a1971-04b7-44eb-a306-91a1c146cca8','Coach Fazirah', now() - interval '20 days','dna','Laporan DNA Test — ATGC','reviewed','0cb188b0-f2e5-42d8-9071-81b331d88a59','DR Nornajihah','Kecenderungan metabolik & sensitiviti gluten sederhana. Cadangan penyesuaian diet.','reviewed', true,'staff');

-- ────────────────────────────────────────────────────────────
-- SEKSYEN 10: KEPATUHAN (psy_kepatuhan_log + psy_kepatuhan_weekly)
-- Guna item_key sebenar dari psy_kepatuhan_item (fasa='week1', 10 item berskor + 1 reaksi_pemulihan)
-- ────────────────────────────────────────────────────────────
WITH kep_cfg(patient_id, band, week_start) AS (
  VALUES
  -- Hijau (A, >=85)
  ('e1000000-0000-4000-8000-000000000004'::uuid,'hijau', (now() - interval '6 days')::date),
  ('e1000000-0000-4000-8000-000000000005'::uuid,'hijau', (now() - interval '6 days')::date),
  -- Kuning (B, 50-84)
  ('e1000000-0000-4000-8000-000000000003'::uuid,'kuning', (now() - interval '6 days')::date),
  ('e1000000-0000-4000-8000-000000000013'::uuid,'kuning', (now() - interval '6 days')::date),
  -- Merah (C, <50)
  ('e1000000-0000-4000-8000-000000000006'::uuid,'merah', (now() - interval '6 days')::date),
  ('e1000000-0000-4000-8000-000000000010'::uuid,'merah', (now() - interval '6 days')::date)
),
hari AS (SELECT generate_series(0,6) AS d),
-- 3 varian harian setiap band (bukan sama rata setiap hari — macam manusia isi betul-betul)
jawapan_variant(band, variant, jawapan, skor) AS (VALUES
  ('hijau',0,'{"madu_lth_ib":"5","madu_lthpg_yhpg":"5","pernafasan_fitrah":"cukup_30","zikir_bersanad":"subuh_maghrib","terapi_bumi":"20_30","berjemur":"20_30","air_kelapa":"minum","yogurt":"ambil","pantang_makan":"baik","terapi_kolon":"buat","reaksi_pemulihan":[]}'::jsonb, 100),
  ('hijau',1,'{"madu_lth_ib":"5","madu_lthpg_yhpg":"4","pernafasan_fitrah":"cukup_30","zikir_bersanad":"subuh_maghrib","terapi_bumi":"20_30","berjemur":"10_20","air_kelapa":"minum","yogurt":"ambil","pantang_makan":"baik","terapi_kolon":"buat","reaksi_pemulihan":[]}'::jsonb, 91),
  ('hijau',2,'{"madu_lth_ib":"4","madu_lthpg_yhpg":"4","pernafasan_fitrah":"cukup_30","zikir_bersanad":"subuh","terapi_bumi":"10_20","berjemur":"20_30","air_kelapa":"minum","yogurt":"ambil","pantang_makan":"baik","terapi_kolon":"tidak","reaksi_pemulihan":["keletihan"]}'::jsonb, 86),
  ('kuning',0,'{"madu_lth_ib":"3","madu_lthpg_yhpg":"3","pernafasan_fitrah":"10_20","zikir_bersanad":"subuh","terapi_bumi":"10_20","berjemur":"10_20","air_kelapa":"tidak","yogurt":"ambil","pantang_makan":"separa","terapi_kolon":"tidak","reaksi_pemulihan":["kembung"]}'::jsonb, 54),
  ('kuning',1,'{"madu_lth_ib":"4","madu_lthpg_yhpg":"3","pernafasan_fitrah":"10_20","zikir_bersanad":"subuh_maghrib","terapi_bumi":"10_20","berjemur":"bawah_10","air_kelapa":"minum","yogurt":"ambil","pantang_makan":"separa","terapi_kolon":"tidak","reaksi_pemulihan":[]}'::jsonb, 68),
  ('kuning',2,'{"madu_lth_ib":"2","madu_lthpg_yhpg":"tidak","pernafasan_fitrah":"bawah_10","zikir_bersanad":"tidak","terapi_bumi":"tidak","berjemur":"10_20","air_kelapa":"tidak","yogurt":"tidak","pantang_makan":"tidak","terapi_kolon":"tidak","reaksi_pemulihan":["kembung","keletihan"]}'::jsonb, 39),
  ('merah',0,'{"madu_lth_ib":"1","madu_lthpg_yhpg":"tidak","pernafasan_fitrah":"bawah_10","zikir_bersanad":"tidak","terapi_bumi":"tidak","berjemur":"tidak","air_kelapa":"tidak","yogurt":"tidak","pantang_makan":"tidak","terapi_kolon":"tidak","reaksi_pemulihan":["sakit_kepala","lemah"]}'::jsonb, 4),
  ('merah',1,'{"madu_lth_ib":"1","madu_lthpg_yhpg":"tidak","pernafasan_fitrah":"tidak","zikir_bersanad":"tidak","terapi_bumi":"tidak","berjemur":"tidak","air_kelapa":"tidak","yogurt":"tidak","pantang_makan":"tidak","terapi_kolon":"tidak","reaksi_pemulihan":["sakit_kepala"]}'::jsonb, 0),
  ('merah',2,'{"madu_lth_ib":"2","madu_lthpg_yhpg":"tidak","pernafasan_fitrah":"bawah_10","zikir_bersanad":"tidak","terapi_bumi":"tidak","berjemur":"tidak","air_kelapa":"tidak","yogurt":"tidak","pantang_makan":"tidak","terapi_kolon":"tidak","reaksi_pemulihan":["lemah"]}'::jsonb, 13)
),
harian AS (
  SELECT kc.patient_id, kc.band, kc.week_start + h.d AS log_date,
    -- kebanyakan hari kekal varian utama (0), sekali-sekala tergelincir varian lain
    CASE WHEN random() < 0.7 THEN 0 WHEN random() < 0.85 THEN 1 ELSE 2 END AS variant
  FROM kep_cfg kc CROSS JOIN hari h
)
INSERT INTO psy_kepatuhan_log (id, patient_id, log_date, fasa, jawapan, skor_harian, created_at)
SELECT gen_random_uuid(), hr.patient_id, hr.log_date, 'week1', jv.jawapan, jv.skor, hr.log_date::timestamptz
FROM harian hr JOIN jawapan_variant jv ON jv.band = hr.band AND jv.variant = hr.variant;

INSERT INTO psy_kepatuhan_weekly (id, patient_id, minggu_mula, fasa, skor, bil_hari_isi, kelas, nota_coach)
VALUES
(gen_random_uuid(),'e1000000-0000-4000-8000-000000000004', (now() - interval '6 days')::date,'week1',100,7,'A','Pesakit sangat komited, teruskan!'),
(gen_random_uuid(),'e1000000-0000-4000-8000-000000000005', (now() - interval '6 days')::date,'week1',100,7,'A','Konsisten sepanjang program.'),
(gen_random_uuid(),'e1000000-0000-4000-8000-000000000003', (now() - interval '6 days')::date,'week1',54,7,'B','Boleh ditingkatkan — galakkan minum madu ikut jadual.'),
(gen_random_uuid(),'e1000000-0000-4000-8000-000000000013', (now() - interval '6 days')::date,'week1',54,7,'B','Perlu peringatan bekalan & pantang makan.'),
(gen_random_uuid(),'e1000000-0000-4000-8000-000000000006', (now() - interval '6 days')::date,'week1',4,7,'C','PERHATIAN: kepatuhan sangat rendah, susulan Hakeem dijadualkan.'),
(gen_random_uuid(),'e1000000-0000-4000-8000-000000000010', (now() - interval '6 days')::date,'week1',4,7,'C','Berkait dengan isu ansuran tertunggak — pesakit demotivasi.');

-- ────────────────────────────────────────────────────────────
-- SEKSYEN 11: VITALS (psy_vitals) — bacaan awal & terkini utk pesakit aktif
-- ────────────────────────────────────────────────────────────
INSERT INTO psy_vitals (id, patient_id, recorded_by, recorded_by_name, bp_systolic, bp_diastolic, heart_rate, spo2, temperature, weight, height, bmi, rbs, notes, source, reading_date) VALUES
(gen_random_uuid(),'e1000000-0000-4000-8000-000000000001','21c4417f-e212-400b-be82-9958456122f5','Coach Tasnim',128,84,76,98.0,36.6,68.5,160,26.8,5.6,'Bacaan awal program', 'staff', (now() - interval '30 days')::date),
(gen_random_uuid(),'e1000000-0000-4000-8000-000000000001','21c4417f-e212-400b-be82-9958456122f5','Coach Tasnim',118,78,72,98.5,36.5,65.0,160,25.4,5.2,'Bacaan akhir — peningkatan ketara', 'staff', (now() - interval '2 days')::date),
(gen_random_uuid(),'e1000000-0000-4000-8000-000000000003','349a4c79-2051-4b5b-93d9-369b8464aa3e','Aqilah',132,88,80,97.5,36.8,82.0,172,27.7,7.8,'Bacaan awal — pra-diabetes', 'staff', (now() - interval '13 days')::date),
(gen_random_uuid(),'e1000000-0000-4000-8000-000000000004','1480f4da-ec36-475a-9b63-7551a794cd10','Admin Uweis',122,80,74,98.0,36.6,58.0,158,23.2,5.1,'Bacaan minggu 3', 'staff', (now() - interval '20 days')::date),
(gen_random_uuid(),'e1000000-0000-4000-8000-000000000004','1480f4da-ec36-475a-9b63-7551a794cd10','Admin Uweis',118,76,70,98.5,36.5,56.5,158,22.6,4.9,'Bacaan minggu 6 — stabil', 'staff', (now() - interval '2 days')::date),
(gen_random_uuid(),'e1000000-0000-4000-8000-000000000005','6c723b61-d010-4106-ba2f-800d7cd37c29','Coach Izzah',148,92,82,97.0,36.7,88.0,170,30.4,6.2,'Kolesterol tinggi — bacaan awal', 'staff', (now() - interval '95 days')::date),
(gen_random_uuid(),'e1000000-0000-4000-8000-000000000005','6c723b61-d010-4106-ba2f-800d7cd37c29','Coach Izzah',126,82,72,98.0,36.6,79.0,170,27.3,5.5,'Minggu 14 — penurunan berat ketara', 'staff', (now() - interval '3 days')::date),
(gen_random_uuid(),'e1000000-0000-4000-8000-000000000006','21c4417f-e212-400b-be82-9958456122f5','Coach Tasnim',118,76,78,98.0,36.9,55.0,155,22.9,5.0,'Bacaan minggu 6', 'staff', (now() - interval '4 days')::date),
(gen_random_uuid(),'e1000000-0000-4000-8000-000000000011','21c4417f-e212-400b-be82-9958456122f5','Coach Tasnim',124,80,88,97.8,36.7,74.0,168,26.2,5.4,'Bacaan minggu 3 — keletihan kronik', 'staff', (now() - interval '5 days')::date),
(gen_random_uuid(),'e1000000-0000-4000-8000-000000000012','ce8a1971-04b7-44eb-a306-91a1c146cca8','Coach Fazirah',150,95,80,97.5,36.6,90.0,172,30.4,5.9,'Bacaan minggu 8 — darah tinggi masih tinggi, susulan doktor', 'staff', (now() - interval '3 days')::date),
(gen_random_uuid(),'e1000000-0000-4000-8000-000000000014','1480f4da-ec36-475a-9b63-7551a794cd10','Admin Uweis',134,86,76,98.0,36.6,79.0,175,25.8,5.3,'Bacaan minggu 9', 'staff', (now() - interval '4 days')::date);

-- ────────────────────────────────────────────────────────────
-- SEKSYEN 11B: POLL HARIAN (psy_daily_checkins) — 7 hari x 11 pesakit aktif,
-- mood/tenaga ikut senario masing-masing (macam manusia isi — variasi harian).
-- ────────────────────────────────────────────────────────────
WITH poll_cfg(patient_id, mood_c, energy_c, sleep_c) AS (VALUES
  ('e1000000-0000-4000-8000-000000000003'::uuid,7,7,7),
  ('e1000000-0000-4000-8000-000000000004'::uuid,8,8,7),
  ('e1000000-0000-4000-8000-000000000005'::uuid,8,7,7),
  ('e1000000-0000-4000-8000-000000000006'::uuid,4,4,5),
  ('e1000000-0000-4000-8000-000000000007'::uuid,3,3,4),
  ('e1000000-0000-4000-8000-000000000008'::uuid,7,6,6),
  ('e1000000-0000-4000-8000-000000000010'::uuid,4,5,5),
  ('e1000000-0000-4000-8000-000000000011'::uuid,6,5,6),
  ('e1000000-0000-4000-8000-000000000012'::uuid,6,5,6),
  ('e1000000-0000-4000-8000-000000000013'::uuid,6,6,6),
  ('e1000000-0000-4000-8000-000000000014'::uuid,6,5,6)
),
poll_hari AS (SELECT generate_series(0,6) AS d),
poll_rows AS (
  SELECT pc.patient_id, (CURRENT_DATE - h.d) AS checkin_date,
    greatest(1, least(10, pc.mood_c + (floor(random()*5)-2)::int)) AS mood_score,
    greatest(1, least(10, pc.energy_c + (floor(random()*5)-2)::int)) AS energy_score,
    greatest(1, least(10, pc.sleep_c + (floor(random()*5)-2)::int)) AS sleep_quality,
    round((5 + random()*3)::numeric, 1) AS sleep_hours,
    (2 + floor(random()*4))::int AS madu_count,
    random() AS r1, random() AS r2, random() AS r3, random() AS r4, random() AS r5
  FROM poll_cfg pc CROSS JOIN poll_hari h
)
INSERT INTO psy_daily_checkins (
  id, patient_id, checkin_date, mood_score, energy_score, sleep_quality, sleep_hours,
  symptoms, activities, notes, madu_count, emotions, sleep_time, wake_time, activity_level, created_at
)
SELECT
  gen_random_uuid(), r.patient_id, r.checkin_date, r.mood_score, r.energy_score, r.sleep_quality, r.sleep_hours,
  CASE
    WHEN r.mood_score <= 4 THEN (ARRAY['["keletihan","sakit_kepala"]','["loya","gastrik"]','["sengal_badan"]'])[1 + floor(r.r1*3)::int]::jsonb
    WHEN r.mood_score <= 6 THEN (ARRAY['["sedikit_letih"]','[]','["kembung"]'])[1 + floor(r.r1*3)::int]::jsonb
    ELSE '[]'::jsonb
  END AS symptoms,
  CASE
    WHEN r.energy_score >= 7 THEN (ARRAY['["senaman_ringan","kerja"]','["jalan_pagi","kerja"]'])[1 + floor(r.r2*2)::int]::jsonb
    ELSE (ARRAY['["rehat"]','["kerja"]'])[1 + floor(r.r2*2)::int]::jsonb
  END AS activities,
  CASE
    WHEN r.mood_score <= 4 THEN 'Rasa kurang sihat hari ini, badan lemah.'
    WHEN r.mood_score <= 6 THEN 'Okay je hari ni, biasa-biasa.'
    ELSE 'Rasa segar & bertenaga hari ini!'
  END AS notes,
  r.madu_count,
  CASE
    WHEN r.mood_score <= 4 THEN (ARRAY['["sedih","risau"]','["murung"]'])[1 + floor(r.r3*2)::int]::jsonb
    WHEN r.mood_score <= 6 THEN (ARRAY['["biasa"]','["tenang"]'])[1 + floor(r.r3*2)::int]::jsonb
    ELSE (ARRAY['["gembira","bersyukur"]','["bersemangat"]'])[1 + floor(r.r3*2)::int]::jsonb
  END AS emotions,
  (ARRAY['22:30','23:00','23:15','00:00'])[1 + floor(r.r4*4)::int] AS sleep_time,
  (ARRAY['06:00','06:30','07:00'])[1 + floor(r.r5*3)::int] AS wake_time,
  CASE WHEN r.energy_score >= 7 THEN 'aktif' WHEN r.energy_score >= 4 THEN 'sederhana' ELSE 'rendah' END AS activity_level,
  r.checkin_date::timestamptz
FROM poll_rows r;

-- ────────────────────────────────────────────────────────────
-- SEKSYEN 12: FEEDBACK
-- ────────────────────────────────────────────────────────────
INSERT INTO psy_feedback (id, patient_id, rating, comment, feedback_type, week_number, plan_id, coach_id, coach_name, coach_rating, supply_rating, patient_name) VALUES
(gen_random_uuid(),'e1000000-0000-4000-8000-000000000001',5,'Sangat berpuas hati, coach sentiasa follow-up dan bekalan tepat masa.','overall', NULL,'e2000000-0000-4000-8000-000000000001','21c4417f-e212-400b-be82-9958456122f5','Coach Tasnim',5,5,'Siti Aminah binti Hassan'),
(gen_random_uuid(),'e1000000-0000-4000-8000-000000000004',5,'Sesi Hakeema sangat membantu, terima kasih!','weekly',6,'e2000000-0000-4000-8000-000000000004','1480f4da-ec36-475a-9b63-7551a794cd10','Admin Uweis',5,4,'Nurul Huda binti Ismail'),
(gen_random_uuid(),'e1000000-0000-4000-8000-000000000006',2,'Bekalan Herba Kolon lewat 2 minggu, dan sukar hubungi coach utk susulan.','weekly',6,'e2000000-0000-4000-8000-000000000006','21c4417f-e212-400b-be82-9958456122f5','Coach Tasnim',2,1,'Fatimah binti Omar'),
(gen_random_uuid(),'e1000000-0000-4000-8000-000000000010',3,'Kekeliruan tentang jadual ansuran, harap ada peringatan lebih awal.','overall', NULL,'e2000000-0000-4000-8000-000000000010','6c723b61-d010-4106-ba2f-800d7cd37c29','Coach Izzah',3,4,'Hajah Rohani binti Yusof'),
(gen_random_uuid(),'e1000000-0000-4000-8000-000000000014',4,'Produk sampai dalam keadaan baik, cuma penghantaran agak lambat.','overall', NULL,'e2000000-0000-4000-8000-000000000014','1480f4da-ec36-475a-9b63-7551a794cd10','Admin Uweis',4,3,'Syed Hassan bin Ali');

-- ────────────────────────────────────────────────────────────
-- SEKSYEN 13: INVENTORI — psy_inventory_requests (rujuk psy_inventory_items sedia ada)
-- ────────────────────────────────────────────────────────────
INSERT INTO psy_inventory_requests (id, item_id, item_name, qty_requested, unit_price, total_amount, reason, status, requested_by, requested_by_name, approved_by, approved_at, purchased_at) VALUES
(gen_random_uuid(),'4dd93a0d-4327-4076-94d9-197763ddf797','Herba Kolon',30,25.00,750.00,'Stok habis, permintaan pesakit OBPY1 meningkat','pending_approval','21c4417f-e212-400b-be82-9958456122f5','Coach Tasnim', NULL, NULL, NULL),
(gen_random_uuid(),'87cc5e54-43f9-4454-8141-39c6ea55b77e','Air Afiyah',100,8.00,800.00,'Stok kosong utk sesi minggu depan','approved','349a4c79-2051-4b5b-93d9-369b8464aa3e','Aqilah','419da34c-3ab9-47c2-9046-d8bd36d7c80c', now() - interval '2 days', NULL),
(gen_random_uuid(),'23b1598b-56fe-46ad-a48f-40f5381a6653','DNA Test Kit',5,2000.00,10000.00,'Permintaan pesakit baharu program VIP','approved','ce8a1971-04b7-44eb-a306-91a1c146cca8','Coach Fazirah','1aa0e177-efe2-470b-8a37-3da7579f9f12', now() - interval '5 days', now() - interval '3 days'),
(gen_random_uuid(),'973372cd-9cc9-492f-bc73-c1fd99ccb1c5','Madu Kelulut',20,45.00,900.00,'Susulan aduan bekalan lewat','pending_approval','21c4417f-e212-400b-be82-9958456122f5','Coach Tasnim', NULL, NULL, NULL),
(gen_random_uuid(),'91e1d970-f3a3-4d6b-bec0-3092f62cb3cb','Enema Kit',3,150.00,450.00,'Ganti kit rosak','rejected','6c723b61-d010-4106-ba2f-800d7cd37c29','Coach Izzah','419da34c-3ab9-47c2-9046-d8bd36d7c80c', now() - interval '1 day', NULL);

-- ────────────────────────────────────────────────────────────
-- SEKSYEN 14: PESANAN PRODUK (psy_orders)
-- ────────────────────────────────────────────────────────────
INSERT INTO psy_orders (id, order_ref, patient_id, items, total, status, delivery_method, delivery_address, courier, tracking_number, paid_at, packed_at, shipped_at, delivered_at) VALUES
(gen_random_uuid(),'ORD-2026-3001','e1000000-0000-4000-8000-000000000003','[{"product_id":"vitamin-d","name":"Vitamin D3 5000IU","qty":2,"price":48.00}]'::jsonb,96.00,'pending','pos','No 21, Jalan SS2/24, Petaling Jaya', NULL, NULL, NULL, NULL, NULL, NULL),
(gen_random_uuid(),'ORD-2026-3002','e1000000-0000-4000-8000-000000000005','[{"product_id":"jus-halia","name":"Jus Halia Concentrate","qty":3,"price":45.00}]'::jsonb,135.00,'shipped','pos','No 3, Jalan Pandan Utama, Kuala Lumpur','J&T Express','JT2026887712', now() - interval '3 days', now() - interval '2 days', now() - interval '1 day', NULL),
(gen_random_uuid(),'ORD-2026-3003','e1000000-0000-4000-8000-000000000014','[{"product_id":"madu-shifa-500g","name":"Madu Shifa 500g","qty":1,"price":85.00},{"product_id":"magnesium","name":"Magnesium Glycinate","qty":1,"price":55.00}]'::jsonb,140.00,'delivered','pos','No 19, Jalan Cheras, Kuala Lumpur','Poslaju','PL2026991234', now() - interval '10 days', now() - interval '9 days', now() - interval '8 days', now() - interval '6 days'),
(gen_random_uuid(),'ORD-2026-3004','e1000000-0000-4000-8000-000000000011','[{"product_id":"santapan-fitrah","name":"Santapan Fitrah Set","qty":1,"price":220.00}]'::jsonb,220.00,'paid','pickup', NULL, NULL, NULL, now() - interval '2 days', NULL, NULL, NULL);

-- ────────────────────────────────────────────────────────────
-- SEKSYEN 15: RUJUKAN PESAKIT-KE-PESAKIT (psy_referrals)
-- ────────────────────────────────────────────────────────────
INSERT INTO psy_referrals (id, referrer_patient_id, referee_patient_id, code_used, status, qualified_at, reward_note, rewarded_at, rewarded_by) VALUES
(gen_random_uuid(),'e1000000-0000-4000-8000-000000000001','e1000000-0000-4000-8000-000000000003','ISW001','rewarded', now() - interval '12 days','Baucar RM50 diberi kepada kedua-dua pihak', now() - interval '10 days','419da34c-3ab9-47c2-9046-d8bd36d7c80c'),
(gen_random_uuid(),'e1000000-0000-4000-8000-000000000013','e1000000-0000-4000-8000-000000000015','ISW013','pending', NULL, NULL, NULL, NULL);

-- ────────────────────────────────────────────────────────────
-- SEKSYEN 16: PROMO (psy_promo_claims + psy_promo_redemptions) — kod TEST sedia ada
-- ────────────────────────────────────────────────────────────
INSERT INTO psy_promo_claims (id, patient_id, promo_id, code, discount_type, discount_value, min_subtotal, claimed_at, expires_at, status, used_at, used_in_payment_id)
SELECT gen_random_uuid(), 'e1000000-0000-4000-8000-000000000013', pc.id, pc.code, pc.discount_type, pc.discount_value, pc.min_subtotal,
  '2026-08-04 10:00:00+08'::timestamptz, '2026-08-05 23:59:59+08'::timestamptz, 'used', '2026-08-04 10:15:00+08'::timestamptz, 'e6000000-0000-4000-8000-000000000013'
FROM psy_promo_codes pc WHERE pc.code = 'TEST';

INSERT INTO psy_promo_redemptions (id, promo_id, patient_id, payment_id, discount_amount)
SELECT gen_random_uuid(), pc.id, 'e1000000-0000-4000-8000-000000000013', 'e6000000-0000-4000-8000-000000000013', 39.90
FROM psy_promo_codes pc WHERE pc.code = 'TEST';

-- ────────────────────────────────────────────────────────────
-- SEKSYEN 17: RISK ALERTS & EMERGENCY ALERTS (rendah risiko, demo sahaja)
-- ────────────────────────────────────────────────────────────
INSERT INTO psy_risk_alerts (id, patient_id, patient_name, created_by, created_by_name, severity, category, description, status, acknowledged_by) VALUES
(gen_random_uuid(),'e1000000-0000-4000-8000-000000000006','Fatimah binti Omar','21c4417f-e212-400b-be82-9958456122f5','Coach Tasnim','medium','kepatuhan_rendah','Kepatuhan merah 3 minggu berturut-turut + komplen bekalan/coach. Perlu susulan segera.','acknowledged','419da34c-3ab9-47c2-9046-d8bd36d7c80c'),
(gen_random_uuid(),'e1000000-0000-4000-8000-000000000010','Hajah Rohani binti Yusof','6c723b61-d010-4106-ba2f-800d7cd37c29','Coach Izzah','low','kewangan','Ansuran tertunggak menyebabkan pesakit demotivasi terhadap program.','open', NULL);

INSERT INTO psy_emergency_alerts (id, patient_id, zon, symptoms, source, reported_at, response_target_minutes, assigned_to, status, resolved_at, resolved_by, notes, created_by) VALUES
(gen_random_uuid(),'e1000000-0000-4000-8000-000000000007','merah','["sakit_dada","susah_bernafas"]'::jsonb,'patient', now() - interval '2 days',15,'ce8a1971-04b7-44eb-a306-91a1c146cca8','resolved', now() - interval '2 days' + interval '20 minutes','ce8a1971-04b7-44eb-a306-91a1c146cca8','Waris & 999 dihubungi, pesakit dimasukkan wad segera (rujuk Rekod Klinikal).','ce8a1971-04b7-44eb-a306-91a1c146cca8'),
(gen_random_uuid(),'e1000000-0000-4000-8000-000000000006','kuning','["sakit_kepala","lemah"]'::jsonb,'patient', now() - interval '4 days',60,'21c4417f-e212-400b-be82-9958456122f5','resolved', now() - interval '4 days' + interval '45 minutes','21c4417f-e212-400b-be82-9958456122f5','Coach hubungi pesakit, gejala reda selepas rehat & rehidrasi.','21c4417f-e212-400b-be82-9958456122f5');

-- ────────────────────────────────────────────────────────────
-- SEKSYEN 18: SURAT (psy_letter_requests + psy_letter_issued)
-- ────────────────────────────────────────────────────────────
INSERT INTO psy_letter_requests (id, patient_id, patient_name, template_code, template_name, reason, field_values, status, approved_by, approved_at) VALUES
('ee000000-0000-4000-8000-000000000001','e1000000-0000-4000-8000-000000000014','Syed Hassan bin Ali','KWSP','Surat untuk KWSP','Permohonan pengeluaran KWSP Akaun 2 — kos rawatan','{"DIAGNOSIS":"Migrain kronik & tekanan kerja","KOS_RAWATAN":"42500"}'::jsonb,'issued','1aa0e177-efe2-470b-8a37-3da7579f9f12', now() - interval '5 days'),
('ee000000-0000-4000-8000-000000000002','e1000000-0000-4000-8000-000000000002','Mohd Faizal bin Aziz','Pengesahan','Surat Pengesahan Rawatan','Pengesahan rawatan utk majikan','{"TUJUAN":"Pengesahan rawatan kesihatan untuk rekod majikan"}'::jsonb,'issued','1aa0e177-efe2-470b-8a37-3da7579f9f12', now() - interval '8 days'),
('ee000000-0000-4000-8000-000000000003','e1000000-0000-4000-8000-000000000008','Tan Chee Keong','MC','Surat Tidak Hadir Kerja', 'Tidak hadir kerja semasa temujanji doktor','{"TARIKH_MULA_MC":"2026-08-23","TARIKH_TAMAT_MC":"2026-08-23","JUMLAH_HARI":"1"}'::jsonb,'pending', NULL, NULL);

INSERT INTO psy_letter_issued (id, request_id, patient_id, patient_name, template_code, template_name, field_values, ref_number, signed_by, signed_by_name, signed_by_role, signed_at) VALUES
(gen_random_uuid(),'ee000000-0000-4000-8000-000000000001','e1000000-0000-4000-8000-000000000014','Syed Hassan bin Ali','KWSP','Surat untuk KWSP','{"DIAGNOSIS":"Migrain kronik & tekanan kerja","KOS_RAWATAN":"42500"}'::jsonb,'ISW/KWSP/2026/0041','0cb188b0-f2e5-42d8-9071-81b331d88a59','DR Nornajihah','doctor', now() - interval '5 days'),
(gen_random_uuid(),'ee000000-0000-4000-8000-000000000002','e1000000-0000-4000-8000-000000000002','Mohd Faizal bin Aziz','Pengesahan','Surat Pengesahan Rawatan','{"TUJUAN":"Pengesahan rawatan kesihatan untuk rekod majikan"}'::jsonb,'ISW/PGS/2026/0027','a55529b9-9a5b-488d-b339-3eaac596c75b','Khairil Arham','doctor', now() - interval '8 days');

-- ────────────────────────────────────────────────────────────
-- SEKSYEN 19: CONTINUITY OFFER (pesakit hampir tamat)
-- ────────────────────────────────────────────────────────────
INSERT INTO psy_continuity_offers (id, plan_id, patient_id, suggested_by, package_uuid, package_name, price, note, status)
SELECT gen_random_uuid(), 'e2000000-0000-4000-8000-000000000005','e1000000-0000-4000-8000-000000000005','6c723b61-d010-4106-ba2f-800d7cd37c29', pkg.id, 'OBPY 1 (Sambungan)', pkg.today_price,
  'Pesakit tunjuk hasil sangat baik — cadang sambung program OBPY 1 fasa 2 dengan harga istimewa.', 'sent'
FROM psy_packages pkg WHERE pkg.package_id = 'pkg-obpy1';

-- ────────────────────────────────────────────────────────────
-- SEKSYEN 20: TUGASAN COACH (psy_coach_tasks)
-- ────────────────────────────────────────────────────────────
INSERT INTO psy_coach_tasks (id, coach_id, title, notes, task_date, status, priority, patient_id) VALUES
(gen_random_uuid(),'21c4417f-e212-400b-be82-9958456122f5','Panggilan susulan — Fatimah Omar','Susulan komplen bekalan & kepatuhan rendah sebelum sesi Hakeem', (now() + interval '1 day')::date,'belum_mula','tinggi','e1000000-0000-4000-8000-000000000006'),
(gen_random_uuid(),'6c723b61-d010-4106-ba2f-800d7cd37c29','Peringatan ansuran — Hajah Rohani','Hubungi pesakit tentang checkpoint 2 tertunggak', (now())::date,'dalam_proses','tinggi','e1000000-0000-4000-8000-000000000010'),
(gen_random_uuid(),'21c4417f-e212-400b-be82-9958456122f5','Susulan sampel DNA — Ganesh Marimuthu','Pastikan sampel dihantar ke lab minggu ini', (now() + interval '2 days')::date,'belum_mula','sederhana','e1000000-0000-4000-8000-000000000011'),
(gen_random_uuid(),'349a4c79-2051-4b5b-93d9-369b8464aa3e','Sediakan borang KOB — Zulkifli Ahmad','Sesi KOB dijadualkan 4 hari lagi, sediakan borang & slip pakej', (now() + interval '3 days')::date,'belum_mula','sederhana','e1000000-0000-4000-8000-000000000009'),
(gen_random_uuid(),'ce8a1971-04b7-44eb-a306-91a1c146cca8','Semak progress Abdullah Salleh','Semak laporan DNA & sediakan nota konsultasi lanjutan', (now() - interval '1 day')::date,'selesai','rendah','e1000000-0000-4000-8000-000000000012');

-- ────────────────────────────────────────────────────────────
-- SEKSYEN 21: NOTA PESAKIT (psy_patient_notes)
-- ────────────────────────────────────────────────────────────
INSERT INTO psy_patient_notes (id, patient_id, note_type, content, actor_id, actor_name, actor_role, is_pinned, visibility) VALUES
(gen_random_uuid(),'e1000000-0000-4000-8000-000000000001','coach','Tahniah! Program EOL+ selesai dengan hasil cemerlang. Pesakit berpuas hati sepenuhnya.','21c4417f-e212-400b-be82-9958456122f5','Coach Tasnim','coach', true,'staff'),
(gen_random_uuid(),'e1000000-0000-4000-8000-000000000006','peringatan','Pesakit mengadu bekalan Herba Kolon lewat & sukar hubungi coach. Dinaikkan ke risk alert + Sesi Hakeem dijadualkan.','21c4417f-e212-400b-be82-9958456122f5','Coach Tasnim','coach', true,'staff'),
(gen_random_uuid(),'e1000000-0000-4000-8000-000000000010','peringatan','Checkpoint ansuran bulan 2 tertunggak >14 hari. booking_blocked diaktifkan sehingga bayaran dijelaskan.','419da34c-3ab9-47c2-9046-d8bd36d7c80c','Admin Customer','manager', true,'staff');

-- ────────────────────────────────────────────────────────────
-- SEKSYEN 22: TEMUJANJI (psy_appointments) — kalendar staf pelbagai jenis servis/status
-- ────────────────────────────────────────────────────────────
INSERT INTO psy_appointments (id, patient_id, staff_id, patient_name, staff_name, service, appointment_time, duration_min, status, room) VALUES
(gen_random_uuid(),'e1000000-0000-4000-8000-000000000009', '0cb188b0-f2e5-42d8-9071-81b331d88a59','Zulkifli bin Ahmad','DR Nornajihah','KOB Konsultasi', now() + interval '4 days','30','scheduled','Bilik Konsultasi 1'),
(gen_random_uuid(),'e1000000-0000-4000-8000-000000000004', '1480f4da-ec36-475a-9b63-7551a794cd10','Nurul Huda binti Ismail','Admin Uweis','Sesi Coaching Mingguan', now() + interval '2 days','60','scheduled','Bilik Coaching 2'),
(gen_random_uuid(),'e1000000-0000-4000-8000-000000000011', '21c4417f-e212-400b-be82-9958456122f5','Ganesh a/l Marimuthu','Coach Tasnim','Ambil Sampel DNA', now() - interval '6 days','20','completed','Bilik Klinik'),
(gen_random_uuid(),'e1000000-0000-4000-8000-000000000006', '419da34c-3ab9-47c2-9046-d8bd36d7c80c','Fatimah binti Omar','Admin Customer','Sesi Hakeem Session', now() + interval '3 days','30','scheduled','Bilik Konsultasi 2'),
(gen_random_uuid(),'e1000000-0000-4000-8000-000000000008', 'a55529b9-9a5b-488d-b339-3eaac596c75b','Tan Chee Keong','Khairil Arham','Temujanji Doktor Susulan', now() - interval '4 days','30','completed','Bilik Konsultasi 1'),
(gen_random_uuid(),'e1000000-0000-4000-8000-000000000010', '6c723b61-d010-4106-ba2f-800d7cd37c29','Hajah Rohani binti Yusof','Coach Izzah','Sesi Coaching Mingguan', now() - interval '1 day','60','no_show', 'Bilik Coaching 1'),
(gen_random_uuid(),'e1000000-0000-4000-8000-000000000003', '349a4c79-2051-4b5b-93d9-369b8464aa3e','Lim Wei Sheng','Aqilah','Sesi Coaching Mingguan', now() + interval '1 day','60','scheduled','Bilik Coaching 2'),
(gen_random_uuid(),'e1000000-0000-4000-8000-000000000015', '419da34c-3ab9-47c2-9046-d8bd36d7c80c','Nor Aini binti Rashid','Admin Customer','Tempahan Sesi KOB (belum disahkan)', now() + interval '5 days','30','scheduled','Bilik Konsultasi 1');

-- Hidupkan semula sync GHL
ALTER TABLE psy_patients ENABLE TRIGGER sync_ghl_patients;
ALTER TABLE psy_kob_sessions ENABLE TRIGGER sync_ghl_kob_sessions;

COMMIT;

SELECT 'Demo seed selesai: 15 pesakit + data merentasi semua modul utama.' AS status;
