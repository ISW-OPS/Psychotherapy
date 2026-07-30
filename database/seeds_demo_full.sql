-- ============================================================
-- seeds_demo_full.sql  —  WIPE + RESEED data demo penuh
-- Sasaran: TESTING sahaja (ISW Data Centre / ipmemyizigwgivccytcu).
-- JANGAN jalankan di PROD.
--
-- Memadam semua data PESAKIT/TRANSAKSI, mengekalkan data rujukan/konfig
-- (staff, pakej, inventory items, coaching catalog, library, templates, dll).
-- Kemudian bina 14 pesakit demo dalam pelbagai keadaan + data sokongan
-- supaya setiap skrin (dashboard manager/admin/coach/doktor, pesakit, KYC,
-- appointment, order, bayaran, inventori, risiko, feedback, vitals, checkin)
-- ada data untuk pembentangan.
--
-- Re-runnable: wipe + insert UUID tetap. Boleh jalan berulang.
-- ============================================================

BEGIN;

-- ════════════════════════ 1. WIPE (data transaksi/pesakit) ════════════════════════
DELETE FROM psy_plan_weekly_progress;
DELETE FROM psy_plan_compliance;
DELETE FROM psy_plan_check_ins;
DELETE FROM psy_coaching_sessions;
DELETE FROM psy_coach_tasks;
DELETE FROM psy_treatment_plans;
DELETE FROM psy_appointments;
DELETE FROM psy_kob_sessions;
DELETE FROM psy_kob_agreements;
DELETE FROM psy_daily_checkins;
DELETE FROM psy_daily_completions;
DELETE FROM psy_kepatuhan_log;
DELETE FROM psy_kepatuhan_weekly;
DELETE FROM psy_vitals;
DELETE FROM psy_medical_report_comments;
DELETE FROM psy_medical_reports;
DELETE FROM psy_patient_documents;
DELETE FROM psy_patient_notes;
DELETE FROM psy_patient_reaksi_reports;
DELETE FROM psy_orders;
DELETE FROM psy_payments;
DELETE FROM psy_package_purchases;
DELETE FROM psy_bottle_returns;
DELETE FROM psy_kyc_submissions;
DELETE FROM psy_risk_alerts;
DELETE FROM psy_adherence_alerts;
DELETE FROM psy_feedback;
DELETE FROM psy_weekly_feedback;
DELETE FROM psy_letter_issued;
DELETE FROM psy_letter_requests;
DELETE FROM psy_referrals;
DELETE FROM psy_library_bookmarks;
DELETE FROM psy_library_views;
DELETE FROM psy_library_feedback;
DELETE FROM psy_event_registrations;
DELETE FROM psy_notifications;
DELETE FROM psy_inventory_requests;
DELETE FROM psy_wa_messages;
DELETE FROM psy_wa_conversations;
DELETE FROM psy_audit_log;
DELETE FROM psy_patients;
DELETE FROM psy_profiles WHERE role = 'patient';

-- ════════════════════════ 2. ROSTER pesakit demo ════════════════════════
CREATE TEMP TABLE _r (
  pid uuid, prof uuid, plan uuid, name text, gender text, dob date, ic text, phone text, email text,
  state text, city text, cond text, cond_dur text, status text, outcome text, kob text,
  pkg_id text, pkg_name text, pkg_price numeric, dur int, cur_week int,
  coach uuid, coach_name text, created_days int
) ON COMMIT DROP;

-- coach ids: Aqilah 349a4c79 / Izzah 6c723b61 / Tasnim 21c4417f / Fazirah ce8a1971 / Uweis 1480f4da
-- pkg ids:  OBPX1 ff6cdc4b (40000/14) | VIP b57bd4f8 (2999/16) | OBPY1 7054d0b4 (52000/18) | EOL+ a7f1ebb8 (698/4) | EOL d1f91f58 (399/4)
INSERT INTO _r VALUES
-- ── AKTIF (6) ──
('c0000000-0000-4000-8000-000000000001','d0000000-0000-4000-8000-000000000001','b0000000-0000-4000-8000-000000000001','Siti Aminah binti Hassan','F','1985-03-12','850312-10-5524','0123456701','siti.aminah@example.com','Selangor','Shah Alam','Diabetes jenis 2','3 tahun','active','otw','package_paid','ff6cdc4b-c417-40c1-b997-5a49df8783f6','OBPX 1',40000,14,6,'349a4c79-2051-4b5b-93d9-369b8464aa3e','Aqilah',38),
('c0000000-0000-4000-8000-000000000002','d0000000-0000-4000-8000-000000000002','b0000000-0000-4000-8000-000000000002','Mohd Faizal bin Aziz','M','1978-07-22','780722-14-5031','0123456702','faizal.aziz@example.com','Kuala Lumpur','Cheras','Tekanan darah tinggi','5 tahun','active','otw','package_paid','b57bd4f8-ec6a-444e-9f4f-1f9e4af4b4c6','VIP Premium',2999,16,10,'6c723b61-d010-4106-ba2f-800d7cd37c29','Coach Izzah',66),
('c0000000-0000-4000-8000-000000000003','d0000000-0000-4000-8000-000000000003','b0000000-0000-4000-8000-000000000003','Lim Wei Sheng','M','1990-11-05','901105-07-5119','0123456703','lim.ws@example.com','Pulau Pinang','George Town','Obesiti','2 tahun','active','otw','package_paid','7054d0b4-2488-421f-913c-e3617a20c37e','OBPY 1',52000,18,3,'21c4417f-e212-400b-be82-9958456122f5','Coach Tasnim',17),
('c0000000-0000-4000-8000-000000000004','d0000000-0000-4000-8000-000000000004','b0000000-0000-4000-8000-000000000004','Nurul Huda binti Ismail','F','1995-01-30','950130-01-5288','0123456704','nurul.huda@example.com','Johor','Johor Bahru','Sakit sendi kronik','1 tahun','active','otw','package_paid','a7f1ebb8-4e42-4ffe-9a28-0331bd9830ca','EOL +',698,4,2,'ce8a1971-04b7-44eb-a306-91a1c146cca8','Coach Fazirah',10),
('c0000000-0000-4000-8000-000000000005','d0000000-0000-4000-8000-000000000005','b0000000-0000-4000-8000-000000000005','Raj Kumar a/l Subramaniam','M','1982-09-17','820917-08-5077','0123456705','raj.kumar@example.com','Perak','Ipoh','Kolesterol tinggi','4 tahun','active','otw','package_paid','b57bd4f8-ec6a-444e-9f4f-1f9e4af4b4c6','VIP Premium',2999,16,12,'1480f4da-ec36-475a-9b63-7551a794cd10','Admin Uweis',80),
('c0000000-0000-4000-8000-000000000006','d0000000-0000-4000-8000-000000000006','b0000000-0000-4000-8000-000000000006','Fatimah binti Omar','F','1970-05-08','700508-10-5142','0123456706','fatimah.omar@example.com','Selangor','Klang','Masalah buah pinggang','6 tahun','active','otw','package_paid','ff6cdc4b-c417-40c1-b997-5a49df8783f6','OBPX 1',40000,14,8,'349a4c79-2051-4b5b-93d9-369b8464aa3e','Aqilah',52),
-- ── TUNGGU KYC (3) ──
('c0000000-0000-4000-8000-000000000007','d0000000-0000-4000-8000-000000000007',NULL,'Aisyah binti Kamal','F','1988-12-03','881203-04-5366','0123456707','aisyah.kamal@example.com','Melaka','Ayer Keroh','Migrain kronik','2 tahun','pending_kyc',NULL,'kyc_done',NULL,NULL,NULL,NULL,NULL,NULL,NULL,5),
('c0000000-0000-4000-8000-000000000008','d0000000-0000-4000-8000-000000000008',NULL,'Tan Chee Keong','M','1975-06-19','750619-10-5023','0123456708','tan.ck@example.com','Selangor','Subang Jaya','Gastrik kronik','3 tahun','pending_kyc',NULL,'kyc_done',NULL,NULL,NULL,NULL,NULL,NULL,NULL,3),
('c0000000-0000-4000-8000-000000000009','d0000000-0000-4000-8000-000000000009',NULL,'Zulkifli bin Ahmad','M','1992-02-25','920225-02-5411','0123456709','zulkifli.ahmad@example.com','Kedah','Alor Setar','Insomnia','1 tahun','pending_kyc',NULL,'pending_payment',NULL,NULL,NULL,NULL,NULL,NULL,NULL,1),
-- ── PAKEJ HABIS / TAMAT (2) ──
('c0000000-0000-4000-8000-000000000010','d0000000-0000-4000-8000-000000000010','b0000000-0000-4000-8000-000000000010','Hajah Rohani binti Yusof','F','1960-08-14','600814-06-5200','0123456710','rohani.yusof@example.com','Pahang','Kuantan','Sakit lutut (osteoartritis)','8 tahun','inactive','completed','completed','d1f91f58-2e13-434a-b2b9-d228dd6da4fe','EOL',399,4,4,'6c723b61-d010-4106-ba2f-800d7cd37c29','Coach Izzah',60),
('c0000000-0000-4000-8000-000000000011','d0000000-0000-4000-8000-000000000011','b0000000-0000-4000-8000-000000000011','Ganesh a/l Marimuthu','M','1983-04-09','830409-05-5099','0123456711','ganesh.m@example.com','Negeri Sembilan','Seremban','Asma','10 tahun','inactive','completed','completed','b57bd4f8-ec6a-444e-9f4f-1f9e4af4b4c6','VIP Premium',2999,16,16,'21c4417f-e212-400b-be82-9958456122f5','Coach Tasnim',180),
-- ── AKTIF TAPI MENINGGAL (1) ──
('c0000000-0000-4000-8000-000000000012','d0000000-0000-4000-8000-000000000012','b0000000-0000-4000-8000-000000000012','Abdullah bin Salleh','M','1955-10-01','551001-11-5033','0123456712','abdullah.salleh@example.com','Terengganu','Kuala Terengganu','Kanser kolon','2 tahun','deceased','meninggal','package_paid','7054d0b4-2488-421f-913c-e3617a20c37e','OBPY 1',52000,18,7,'1480f4da-ec36-475a-9b63-7551a794cd10','Admin Uweis',120),
-- ── BERHENTI / DROP (2) ──
('c0000000-0000-4000-8000-000000000013','d0000000-0000-4000-8000-000000000013','b0000000-0000-4000-8000-000000000013','Chong Mei Yee','F','1987-07-11','870711-14-5644','0123456713','chong.my@example.com','Kuala Lumpur','Wangsa Maju','Anxiety','2 tahun','archived','berhenti','package_paid','a7f1ebb8-4e42-4ffe-9a28-0331bd9830ca','EOL +',698,4,2,'ce8a1971-04b7-44eb-a306-91a1c146cca8','Coach Fazirah',95),
('c0000000-0000-4000-8000-000000000014','d0000000-0000-4000-8000-000000000014','b0000000-0000-4000-8000-000000000014','Syed Hassan bin Ali','M','1968-03-28','680328-10-5455','0123456714','syed.hassan@example.com','Selangor','Kajang','Arthritis','7 tahun','inactive','berhenti','package_paid','ff6cdc4b-c417-40c1-b997-5a49df8783f6','OBPX 1',40000,14,5,'349a4c79-2051-4b5b-93d9-369b8464aa3e','Aqilah',130);

-- ════════════════════════ 3. AUTH USERS + PROFIL + PESAKIT ════════════════════════
-- psy_profiles.id FK ke auth.users — cipta auth user minimal dahulu (demo, tiada login).
INSERT INTO auth.users (id, email, created_at, updated_at)
SELECT prof, email, now() - (created_days||' days')::interval, now() FROM _r
ON CONFLICT (id) DO NOTHING;

-- auth.users mungkin ada trigger auto-cipta psy_profiles → guna UPSERT.
INSERT INTO psy_profiles (id, full_name, role, phone, email, gender, is_active, created_at)
SELECT prof, name, 'patient', phone, email,
  (CASE WHEN gender='M' THEN 'lelaki' ELSE 'perempuan' END),
  true, now() - (created_days||' days')::interval FROM _r
ON CONFLICT (id) DO UPDATE SET
  full_name = EXCLUDED.full_name, role = 'patient', phone = EXCLUDED.phone,
  email = EXCLUDED.email, gender = EXCLUDED.gender, is_active = true;

INSERT INTO psy_patients (
  id, user_id, mrn, full_name, ic_number, date_of_birth, gender, phone, email,
  state, city, home_address, address, medical_condition, condition_duration,
  status, outcome_status, outcome_status_at, kob_status,
  active_package_id, active_package_name, package_purchased_at, package_expires_at,
  coach_id, assigned_at, referral_source, created_by_staff, created_at
)
SELECT pid, prof,
  'ISW-2026-'||lpad((row_number() over (order by created_days desc))::text,4,'0'),
  name, ic, dob, gender, phone, email,
  state, city, city||', '||state, city||', '||state, cond, cond_dur,
  status, outcome,
  CASE WHEN outcome IS NOT NULL THEN now() - ((created_days/4)||' days')::interval END, kob,
  pkg_id, pkg_name,
  CASE WHEN pkg_id IS NOT NULL THEN now() - (created_days||' days')::interval END,
  CASE WHEN pkg_id IS NOT NULL THEN now() - (created_days||' days')::interval + (dur||' weeks')::interval END,
  coach,
  CASE WHEN coach IS NOT NULL THEN now() - (created_days||' days')::interval END,
  'Demo seed', true, now() - (created_days||' days')::interval
FROM _r;

-- Trigger auth.users auto-cipta baris psy_patients (pending_kyc) bayang —
-- buang baris bayang demo, kekalkan baris kanonik c0000000 sahaja.
DELETE FROM psy_patients
WHERE user_id::text LIKE 'd0000000%' AND id::text NOT LIKE 'c0000000%';

-- ════════════════════════ 4. PELAN RAWATAN + PROGRES MINGGUAN ════════════════════════
INSERT INTO psy_treatment_plans (id, patient_id, doctor_id, name, template, duration_unit, duration_weeks, current_week, status, created_at)
SELECT plan, pid, '0cb188b0-f2e5-42d8-9071-81b331d88a59', pkg_name||' — Pelan Rawatan',
  (SELECT package_id FROM psy_packages WHERE id::text = _r.pkg_id),  -- template = package_id → tarik coaching_schedule (Bimbingan/Bekalan)
  'weeks', dur, cur_week,
  CASE WHEN status='active' THEN 'active' WHEN outcome='completed' THEN 'completed' ELSE 'paused' END,
  now() - (created_days||' days')::interval
FROM _r WHERE pkg_id IS NOT NULL;

-- Progres setiap minggu 1..cur_week. Sesi minggu terakhir pesakit AKTIF = akan datang (booked).
INSERT INTO psy_plan_weekly_progress (plan_id, patient_id, week_number, status, score, session_date, updated_by_name, created_at)
SELECT r.plan, r.pid, g.wk,
  CASE
    WHEN r.status='active' AND g.wk = r.cur_week THEN 'booked'
    WHEN r.status='active' THEN 'hadir'
    WHEN r.outcome='completed' THEN 'hadir'
    WHEN g.wk = r.cur_week THEN 'cancel'          -- meninggal/berhenti: sesi terakhir batal
    ELSE 'hadir'
  END,
  CASE WHEN g.wk < r.cur_week OR r.outcome='completed' THEN 6 + (g.wk % 4) END,
  (CASE
     WHEN r.status='active'        THEN now() + interval '3 days'
     WHEN r.outcome='completed'    THEN now() - interval '20 days'
     WHEN r.outcome='meninggal'    THEN now() - interval '30 days'
     ELSE now() - interval '25 days'
   END) - ((r.cur_week - g.wk) || ' weeks')::interval,
  r.coach_name,
  now() - (r.created_days||' days')::interval
FROM _r r JOIN LATERAL generate_series(1, r.cur_week) g(wk) ON true
WHERE r.pkg_id IS NOT NULL;

-- Pastikan pesakit AKTIF ada 1 sesi HADIR + 1 BOOKED dalam minggu semasa
-- (untuk KPI Kehadiran Minggu Ini & jadual akan datang).
WITH act AS (
  SELECT tp.id AS plan_id, tp.current_week
  FROM psy_treatment_plans tp JOIN psy_patients p ON p.id=tp.patient_id
  WHERE p.status='active'
)
UPDATE psy_plan_weekly_progress w
SET status='hadir', score=8, session_date = date_trunc('week', now()) + interval '10 hours'
FROM act WHERE w.plan_id=act.plan_id AND w.week_number = act.current_week - 1;

WITH act AS (
  SELECT tp.id AS plan_id, tp.current_week
  FROM psy_treatment_plans tp JOIN psy_patients p ON p.id=tp.patient_id
  WHERE p.status='active'
)
UPDATE psy_plan_weekly_progress w
SET status='booked', session_date = now() + interval '2 days' + interval '10 hours'
FROM act WHERE w.plan_id=act.plan_id AND w.week_number = act.current_week;

-- ════════════════════════ 5. APPOINTMENTS ════════════════════════
INSERT INTO psy_appointments (patient_id, staff_id, patient_name, staff_name, service, appointment_time, duration_min, status, room, created_at)
SELECT pid, coach, name, coach_name, 'Sesi Rawatan OB',
  now() + ((1 + (row_number() over (order by created_days)))||' days')::interval + interval '9 hours',
  60, 'scheduled', 'Bilik '||(1+(row_number() over (order by created_days))::int % 3), now()
FROM _r WHERE status='active'
UNION ALL
SELECT pid, coach, name, coach_name, 'Sesi Rawatan OB',
  now() - interval '7 days' + interval '10 hours', 60, 'completed', 'Bilik 1', now() - interval '8 days'
FROM _r WHERE status='active';

-- ════════════════════════ 6. VITALS ════════════════════════
INSERT INTO psy_vitals (patient_id, recorded_by, recorded_by_name, bp_systolic, bp_diastolic, heart_rate, spo2, temperature, weight, height, bmi, source, reading_date, created_at)
SELECT r.pid, r.coach, r.coach_name,
  118 + (g.n*6) + (r.cur_week % 5), 76 + (g.n*3), 70 + (g.n*4), 97 + g.n, 36.6 + (g.n*0.1)::numeric,
  72 + (r.cur_week % 12) - (g.n*2), 168, round((72.0/(1.68*1.68))::numeric,1),
  'staff', current_date - (g.n*14), now() - (g.n*14||' days')::interval
FROM _r r JOIN generate_series(0,1) g(n) ON true
WHERE r.status='active' OR r.outcome='completed';

-- ════════════════════════ 7. DAILY CHECK-INS (pesakit aktif, 10 hari) ════════════════════════
INSERT INTO psy_daily_checkins (patient_id, checkin_date, mood_score, energy_score, sleep_quality, sleep_hours, madu_count, notes, created_at)
SELECT r.pid, current_date - g.d, 3+(g.d%3), 3+((g.d+1)%3), 3+((g.d+2)%3), 6+(g.d%3), 8-(g.d%3),
  'Catatan harian demo', now() - (g.d||' days')::interval
FROM _r r JOIN generate_series(0,9) g(d) ON true
WHERE r.status='active';

-- ════════════════════════ 8. ORDERS ════════════════════════
-- NOTA: psy_orders.patient_id simpan AUTH/profile id (user_id), BUKAN psy_patients.id
-- (lihat payments-webhook: patient_id: intent.userId) — dashboard/orders.html cari nama
-- guna psy_profiles.id. Guna 'd0000...' (user_id), bukan 'c0000...' (psy_patients.id).
INSERT INTO psy_orders (order_ref, patient_id, items, total, status, created_at) VALUES
('ORD-2026-0101','d0000000-0000-4000-8000-000000000001','[{"name":"Madu LTH 500g","qty":2}]'::jsonb, 360, 'pending',   now() - interval '2 days'),
('ORD-2026-0102','d0000000-0000-4000-8000-000000000002','[{"name":"Herba Thoharah","qty":1}]'::jsonb, 180, 'paid',      now() - interval '4 days'),
('ORD-2026-0103','d0000000-0000-4000-8000-000000000005','[{"name":"Madu LTHPG","qty":3}]'::jsonb, 540, 'packed',        now() - interval '6 days'),
('ORD-2026-0104','d0000000-0000-4000-8000-000000000006','[{"name":"Minyak Kelapa Dara","qty":2}]'::jsonb, 120, 'delivered', now() - interval '12 days'),
('ORD-2026-0105','d0000000-0000-4000-8000-000000000003','[{"name":"Probiotik Sachet","qty":1},{"name":"Madu LTH 500g","qty":1}]'::jsonb, 300, 'pending', now() - interval '1 day');

-- ════════════════════════ 9. PAYMENTS (bayaran pakej) ════════════════════════
INSERT INTO psy_payments (receipt_ref, patient_id, items, subtotal, service_charge, sst, total, payment_method, status, paid_at, created_at) VALUES
('RCP-2026-0201','c0000000-0000-4000-8000-000000000001','[{"name":"Pakej OBPX 1"}]'::jsonb, 40000, 0, 0, 40000, 'transfer','completed', now()-interval '38 days', now()-interval '38 days'),
('RCP-2026-0202','c0000000-0000-4000-8000-000000000002','[{"name":"Pakej VIP Premium"}]'::jsonb, 2999, 0, 0, 2999, 'card','completed', now()-interval '66 days', now()-interval '66 days'),
('RCP-2026-0203','c0000000-0000-4000-8000-000000000005','[{"name":"Pakej VIP Premium"}]'::jsonb, 2999, 0, 0, 2999, 'transfer','completed', now()-interval '80 days', now()-interval '80 days'),
('RCP-2026-0204','c0000000-0000-4000-8000-000000000011','[{"name":"Pakej VIP Premium"}]'::jsonb, 2999, 0, 0, 2999, 'card','completed', now()-interval '180 days', now()-interval '180 days'),
('RCP-2026-0205','c0000000-0000-4000-8000-000000000010','[{"name":"Pakej EOL"}]'::jsonb, 399, 0, 0, 399, 'manual','completed', now()-interval '60 days', now()-interval '60 days');

-- ════════════════════════ 10. KYC (pesakit tunggu kelulusan) ════════════════════════
INSERT INTO psy_kyc_submissions (user_id, patient_name, ic_number, date_of_birth, gender, phone, medical_condition, status, created_at)
SELECT prof, name, ic, dob, gender, phone, cond, 'pending', now() - (created_days||' days')::interval
FROM _r WHERE status='pending_kyc';

-- ════════════════════════ 11. RISK ALERTS ════════════════════════
INSERT INTO psy_risk_alerts (patient_id, patient_name, severity, category, description, status, created_by_name, created_at) VALUES
('c0000000-0000-4000-8000-000000000002','Mohd Faizal bin Aziz','critical','Kesihatan','Tekanan darah sangat tinggi (180/110) — perlu rujukan doktor segera','open','Coach Izzah', now()-interval '1 day'),
('c0000000-0000-4000-8000-000000000005','Raj Kumar a/l Subramaniam','high','Kepatuhan','Kolesterol tidak terkawal & tidak hadir 2 sesi berturut','open','Admin Uweis', now()-interval '3 days'),
('c0000000-0000-4000-8000-000000000001','Siti Aminah binti Hassan','high','Kesihatan','Bacaan gula darah tinggi berterusan sepanjang minggu','open','Aqilah', now()-interval '2 days');

-- ════════════════════════ 12. ADHERENCE ALERTS ════════════════════════
INSERT INTO psy_adherence_alerts (patient_id, alert_type, trigger_date, details) VALUES
('c0000000-0000-4000-8000-000000000003','madu_low_5days', current_date, '{"seed":"demo","target":8,"days_below":5}'::jsonb),
('c0000000-0000-4000-8000-000000000006','madu_low_5days', current_date, '{"seed":"demo","target":8,"days_below":6}'::jsonb);

-- ════════════════════════ 13. FEEDBACK (positif + negatif) ════════════════════════
INSERT INTO psy_feedback (patient_id, patient_name, rating, comment, feedback_type, created_at) VALUES
('c0000000-0000-4000-8000-000000000010','Hajah Rohani binti Yusof',5,'Sangat berpuas hati, sakit lutut dah banyak berkurang.','overall', now()-interval '18 days'),
('c0000000-0000-4000-8000-000000000011','Ganesh a/l Marimuthu',4,'Asma bertambah baik, coach sangat membantu.','overall', now()-interval '25 days'),
('c0000000-0000-4000-8000-000000000002','Mohd Faizal bin Aziz',4,'Coach responsif dan program teratur.','overall', now()-interval '5 days'),
('c0000000-0000-4000-8000-000000000001','Siti Aminah binti Hassan',2,'Khidmat agak lambat, lama menunggu giliran.','overall', now()-interval '3 days'),
('c0000000-0000-4000-8000-000000000006','Fatimah binti Omar',1,'Produk lewat sampai dan kurang komunikasi.','overall', now()-interval '8 days');

-- ════════════════════════ 14. INVENTORY REQUESTS (pending kelulusan) ════════════════════════
INSERT INTO psy_inventory_requests (item_name, qty_requested, reason, status, requested_by_name, created_at) VALUES
('Madu LTH 500g',        20, 'Stok hampir habis untuk pesakit aktif', 'pending_approval', 'Aqilah',         now()-interval '1 day'),
('Herba Thoharah',       15, 'Permintaan tinggi minggu ini',           'pending_approval', 'Coach Izzah',    now()-interval '2 days'),
('Probiotik Sachet',     50, 'Restock bulanan',                        'pending_approval', 'Coach Tasnim',   now()-interval '3 hours'),
('Minyak Kelapa Dara',   30, 'Sokongan pakej OB',                      'pending_approval', 'Coach Fazirah',  now()-interval '5 days');

-- ════════════════════════ 15. ISU DILAPORKAN (audit log, terbuka) ════════════════════════
INSERT INTO psy_audit_log (actor_name, actor_role, action, target, meta, created_at) VALUES
('Aqilah','staff','issue.reported','Sistem tempahan slot tergantung bila pilih tarikh', '{"seed":"demo","severity":"high","issue_id":"e0000000-0000-4000-8000-000000000001"}'::jsonb, now()-interval '2 days'),
('Coach Izzah','staff','issue.reported','Notifikasi WhatsApp peringatan tak sampai ke pesakit', '{"seed":"demo","severity":"medium","issue_id":"e0000000-0000-4000-8000-000000000002"}'::jsonb, now()-interval '20 hours'),
('Admin Johor','staff','issue.reported','Stok Zaafaran tidak mencukupi di cawangan', '{"seed":"demo","severity":"medium","issue_id":"e0000000-0000-4000-8000-000000000003"}'::jsonb, now()-interval '3 days'),
('Coach Hakim','staff','issue.reported','Masalah penghantaran produk ke pesakit', '{"seed":"demo","severity":"low","issue_id":"e0000000-0000-4000-8000-000000000004"}'::jsonb, now()-interval '4 days');

-- ════════════════════════ 16. PERMOHONAN SURAT (pending — panel Kelulusan) ════════════════════════
INSERT INTO psy_letter_requests (patient_id, patient_name, template_code, template_name, reason, status, created_at) VALUES
('c0000000-0000-4000-8000-000000000001','Siti Aminah binti Hassan','KWSP','Surat untuk KWSP','Permohonan pengeluaran KWSP kesihatan','pending', now()-interval '1 day'),
('c0000000-0000-4000-8000-000000000002','Mohd Faizal bin Aziz','MC','Surat Tidak Hadir Kerja','Cuti sakit rawatan','pending', now()-interval '2 days'),
('c0000000-0000-4000-8000-000000000005','Raj Kumar a/l Subramaniam','Pengesahan','Surat Pengesahan Rawatan','Pengesahan untuk insurans','pending', now()-interval '3 days'),
('c0000000-0000-4000-8000-000000000006','Fatimah binti Omar','PERKESO','Surat untuk PERKESO','Tuntutan PERKESO','pending', now()-interval '4 days'),
('c0000000-0000-4000-8000-000000000010','Hajah Rohani binti Yusof','Sokongan','Surat Sokongan Rawatan','Sokongan biasiswa anak','pending', now()-interval '5 days');

-- ════════════════════════ 17. KEPATUHAN — log harian (6 minggu) + override mingguan ════════════════════════
-- Seed catatan harian checklist utk 6 pesakit AKTIF (fasa week1, 5 item aktif).
-- Setiap pesakit ada profil kepatuhan berbeza (A/B/C) supaya Laporan Kepatuhan,
-- heatmap, donut taburan, trend 6-minggu & alert "belum isi hari ini" ada data.
-- Jumaat tak dipoll (ikut jadual GForm). Skor konsisten dgn jawapan (max 12 mata).

-- Templat jawapan tetap (jawapan JSONB + skor_harian yang padan)
CREATE TEMP TABLE _tp (code text PRIMARY KEY, jawapan jsonb, skor numeric(5,2)) ON COMMIT DROP;
INSERT INTO _tp VALUES
('A100', '{"madu_lth_ib":"5","madu_lthpg_yhpg":"5","zikir_bersanad":"subuh_maghrib","pantang_makan":"baik","reaksi_pemulihan":["tiada"]}',                       100.00),
('A92',  '{"madu_lth_ib":"4","madu_lthpg_yhpg":"5","zikir_bersanad":"subuh_maghrib","pantang_makan":"baik","reaksi_pemulihan":["tiada"]}',                        91.67),
('B67',  '{"madu_lth_ib":"4","madu_lthpg_yhpg":"3","zikir_bersanad":"subuh_maghrib","pantang_makan":"separa","reaksi_pemulihan":["kembung","mengantuk"]}',        66.67),
('B50',  '{"madu_lth_ib":"3","madu_lthpg_yhpg":"3","zikir_bersanad":"subuh","pantang_makan":"separa","reaksi_pemulihan":["sakit_kepala"]}',                       50.00),
('C33',  '{"madu_lth_ib":"3","madu_lthpg_yhpg":"2","zikir_bersanad":"maghrib","pantang_makan":"tidak","reaksi_pemulihan":["lemah","mengantuk"]}',                 33.33),
('C17',  '{"madu_lth_ib":"2","madu_lthpg_yhpg":"2","zikir_bersanad":"tidak","pantang_makan":"tidak","reaksi_pemulihan":["batuk"]}',                               16.67);

-- Profil kepatuhan per pesakit aktif: templat hari-baik (hi) / hari-kurang (lo),
-- skip_mod (skip setiap ke-N hari dipoll; 99 = tiada skip tambahan), isi hari ini?
CREATE TEMP TABLE _kp (pid uuid, tmpl_hi text, tmpl_lo text, skip_mod int, fills_today boolean) ON COMMIT DROP;
INSERT INTO _kp VALUES
('c0000000-0000-4000-8000-000000000001','A100','A92', 99, true),   -- Siti  — cemerlang (A), rajin
('c0000000-0000-4000-8000-000000000002','B67', 'B50',  7, false),  -- Faizal— sederhana (B)
('c0000000-0000-4000-8000-000000000003','C33', 'C17',  3, false),  -- Lim   — rendah (C), banyak tercicir
('c0000000-0000-4000-8000-000000000004','A92', 'B50',  5, false),  -- Nurul — bercampur (A/B)
('c0000000-0000-4000-8000-000000000005','A92', 'B67', 99, true),   -- Raj   — baik (A/B), rajin
('c0000000-0000-4000-8000-000000000006','B67', 'C33',  4, false);  -- Fatimah— B/C, ada jurang

INSERT INTO psy_kepatuhan_log (patient_id, log_date, fasa, jawapan, skor_harian, created_at, updated_at)
SELECT k.pid, d.day::date, 'week1', t.jawapan, t.skor,
       d.day + interval '20 hours', d.day + interval '20 hours'
FROM _kp k
JOIN _r r ON r.pid = k.pid
CROSS JOIN LATERAL generate_series(
         (current_date - LEAST(41, GREATEST(r.created_days - 1, 0)))::timestamp,
         current_date::timestamp, interval '1 day'
       ) AS d(day)
CROSS JOIN LATERAL (
  SELECT CASE
    WHEN extract(dow FROM d.day) = 5 THEN NULL                                   -- Jumaat tak dipoll
    WHEN k.skip_mod < 90 AND (current_date - d.day::date) <> 0
         AND ((current_date - d.day::date) % k.skip_mod) = 0 THEN NULL           -- hari tercicir
    WHEN ((current_date - d.day::date) % 2) = 0 THEN k.tmpl_hi
    ELSE k.tmpl_lo
  END AS code
) pick
JOIN _tp t ON t.code = pick.code
WHERE pick.code IS NOT NULL
  AND (d.day::date < current_date OR k.fills_today);

-- Override mingguan (demo ciri coach pinda kelas + nota)
INSERT INTO psy_kepatuhan_weekly
  (patient_id, minggu_mula, fasa, skor, bil_hari_isi, kelas, override_kelas, override_by, override_at, nota_coach)
VALUES
-- Lim: auto C, coach naikkan ke B (usaha bertambah baik minggu lepas)
('c0000000-0000-4000-8000-000000000003', date_trunc('week', current_date - interval '7 days')::date, 'week1',
 26.00, 4, 'C', 'B', '21c4417f-e212-400b-be82-9958456122f5', now()-interval '2 days',
 'Kelas dinaikkan — pesakit mula konsisten minum madu & hadir sesi. Teruskan pemantauan.'),
-- Siti: auto A, nota pujian (tanpa override)
('c0000000-0000-4000-8000-000000000001', date_trunc('week', current_date - interval '7 days')::date, 'week1',
 95.83, 6, 'A', NULL, '349a4c79-2051-4b5b-93d9-369b8464aa3e', now()-interval '2 days',
 'Kepatuhan cemerlang sepanjang minggu. Syabas!');

COMMIT;

-- ════════════════════════ SEMAKAN ════════════════════════
SELECT
  (SELECT count(*) FROM psy_patients)                                                        AS patients,
  (SELECT count(*) FROM psy_patients WHERE status='active')                                  AS aktif,
  (SELECT count(*) FROM psy_patients WHERE status='pending_kyc')                             AS tunggu_kyc,
  (SELECT count(*) FROM psy_patients WHERE outcome_status='completed')                       AS tamat,
  (SELECT count(*) FROM psy_patients WHERE status='deceased')                                AS meninggal,
  (SELECT count(*) FROM psy_patients WHERE outcome_status='berhenti')                        AS berhenti,
  (SELECT count(*) FROM psy_treatment_plans)                                                 AS plans,
  (SELECT count(*) FROM psy_plan_weekly_progress)                                            AS sesi,
  (SELECT count(*) FROM psy_appointments)                                                    AS temujanji,
  (SELECT count(*) FROM psy_orders)                                                          AS orders,
  (SELECT count(*) FROM psy_payments)                                                        AS bayaran,
  (SELECT count(*) FROM psy_risk_alerts WHERE status='open')                                 AS risiko,
  (SELECT count(*) FROM psy_feedback)                                                        AS feedback,
  (SELECT count(*) FROM psy_inventory_requests WHERE status='pending_approval')              AS inv_req,
  (SELECT count(*) FROM psy_patients p WHERE p.active_package_id IS NOT NULL
     AND NOT EXISTS (SELECT 1 FROM psy_packages k WHERE k.id::text=p.active_package_id))     AS pakej_hantu;
