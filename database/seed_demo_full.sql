-- ============================================================
-- seed_demo_full.sql — DEMO DATASET
-- ============================================================
-- Comprehensive demo: 2 admin, 2 manager, 3 coach, 2 doctor,
-- 15 patient (semua state: baru, KYC, KOB, aktif, habis, lapsed)
-- + packages, products, plans, checkins, vitals, orders, KOB
--
-- AKAUN LOGIN (semua password sama):
--   Password: Demo@1234
--
--   Admin:    admin1@isw.demo / admin2@isw.demo
--   Manager:  manager1@isw.demo / manager2@isw.demo
--   Coach:    coach1@isw.demo / coach2@isw.demo / coach3@isw.demo
--   Doctor:   doctor1@isw.demo / doctor2@isw.demo
--   Patient:  patient1@isw.demo … patient15@isw.demo
-- ============================================================

-- ============================================================
-- ⚠️  0a. NUCLEAR WIPE — DELETE ALL PATIENT DATA
-- ============================================================
-- Ini akan delete SEMUA pesakit dalam sistem (bukan demo sahaja).
-- Staff/admin/coach/doctor accounts TIDAK terjejas.
-- Kalau nak skip, comment block ni (tukar /* ... */ atau buang)
-- ============================================================
DO $$
DECLARE
  uid  UUID;
  tbl  TEXT;
  tbls TEXT[] := ARRAY[
    'psy_daily_completions','psy_daily_checkins','psy_vitals',
    'psy_plan_weekly_progress','psy_plan_check_ins','psy_plan_compliance',
    'psy_treatment_plans','psy_kob_sessions','psy_kob_agreements',
    'psy_kyc_submissions','psy_dna_reports','psy_package_purchases',
    'psy_payments','psy_feedback','psy_feedback_weekly'
  ];
BEGIN
  -- Delete dari setiap table kalau wujud (skip kalau table takde)
  FOREACH tbl IN ARRAY tbls LOOP
    BEGIN
      EXECUTE format('DELETE FROM %I WHERE patient_id IN (SELECT id FROM psy_patients)', tbl);
    EXCEPTION
      WHEN undefined_table THEN NULL;
      WHEN undefined_column THEN
        BEGIN
          EXECUTE format('DELETE FROM %I', tbl);
        EXCEPTION WHEN OTHERS THEN NULL;
        END;
    END;
  END LOOP;

  BEGIN DELETE FROM psy_appointments WHERE patient_id IS NOT NULL;
  EXCEPTION WHEN undefined_table THEN NULL; END;

  -- Delete patient records + auth users
  FOR uid IN SELECT user_id FROM psy_patients WHERE user_id IS NOT NULL LOOP
    BEGIN DELETE FROM psy_audit_log     WHERE actor_id   = uid; EXCEPTION WHEN undefined_table THEN NULL; END;
    BEGIN DELETE FROM psy_notifications WHERE user_id    = uid; EXCEPTION WHEN undefined_table THEN NULL; END;
    BEGIN DELETE FROM psy_orders        WHERE patient_id = uid; EXCEPTION WHEN undefined_table THEN NULL; END;
    BEGIN DELETE FROM psy_profiles      WHERE id         = uid; EXCEPTION WHEN undefined_table THEN NULL; END;
    BEGIN DELETE FROM auth.users        WHERE id         = uid AND raw_user_meta_data->>'role' = 'patient';
    EXCEPTION WHEN OTHERS THEN NULL; END;
  END LOOP;

  DELETE FROM psy_patients;
  RAISE NOTICE 'Wipe completed — all patient data cleared';
END $$;

-- ── 0c. ENSURE all columns needed by seed exist (defensive) ──
ALTER TABLE psy_patients ADD COLUMN IF NOT EXISTS phone TEXT;
ALTER TABLE psy_patients ADD COLUMN IF NOT EXISTS daily_schedule JSONB;
ALTER TABLE psy_patients ADD COLUMN IF NOT EXISTS coach_id UUID;

-- ── 0b. CLEAN existing demo staff (safe — only emails ending @isw.demo) ──
DO $$
DECLARE uid UUID;
BEGIN
  FOR uid IN SELECT id FROM auth.users WHERE email LIKE '%@isw.demo' LOOP
    DELETE FROM psy_audit_log         WHERE actor_id = uid;
    DELETE FROM psy_notifications     WHERE user_id  = uid;
    DELETE FROM psy_profiles          WHERE id       = uid;
    DELETE FROM auth.users            WHERE id       = uid;
  END LOOP;
END $$;

-- ── 1. AUTH USERS (trigger handle_new_user akan auto-create psy_profiles) ──
-- Password hash sekali untuk semua: Demo@1234
DO $$
DECLARE
  pwd TEXT := crypt('Demo@1234', gen_salt('bf'));
  staff_meta JSONB;
  pt_meta    JSONB := '{"role":"patient"}'::jsonb;
BEGIN
  -- Admins
  INSERT INTO auth.users (id, email, encrypted_password, email_confirmed_at, raw_user_meta_data, role, aud, instance_id)
  VALUES
    ('a1111111-1111-1111-1111-111111111101', 'admin1@isw.demo', pwd, now(),
      '{"role":"staff","staff_role":"admin","full_name":"Aisyah Rahman"}'::jsonb,
      'authenticated','authenticated','00000000-0000-0000-0000-000000000000'),
    ('a1111111-1111-1111-1111-111111111102', 'admin2@isw.demo', pwd, now(),
      '{"role":"staff","staff_role":"admin","full_name":"Hafiz Ibrahim"}'::jsonb,
      'authenticated','authenticated','00000000-0000-0000-0000-000000000000');

  -- Managers
  INSERT INTO auth.users (id, email, encrypted_password, email_confirmed_at, raw_user_meta_data, role, aud, instance_id)
  VALUES
    ('a2222222-2222-2222-2222-222222222201', 'manager1@isw.demo', pwd, now(),
      '{"role":"staff","staff_role":"manager","full_name":"Nurul Huda Aziz"}'::jsonb,
      'authenticated','authenticated','00000000-0000-0000-0000-000000000000'),
    ('a2222222-2222-2222-2222-222222222202', 'manager2@isw.demo', pwd, now(),
      '{"role":"staff","staff_role":"manager","full_name":"Faizal Hassan"}'::jsonb,
      'authenticated','authenticated','00000000-0000-0000-0000-000000000000');

  -- Coaches
  INSERT INTO auth.users (id, email, encrypted_password, email_confirmed_at, raw_user_meta_data, role, aud, instance_id)
  VALUES
    ('a3333333-3333-3333-3333-333333333301', 'coach1@isw.demo', pwd, now(),
      '{"role":"staff","staff_role":"coach","full_name":"Coach Aina Salleh"}'::jsonb,
      'authenticated','authenticated','00000000-0000-0000-0000-000000000000'),
    ('a3333333-3333-3333-3333-333333333302', 'coach2@isw.demo', pwd, now(),
      '{"role":"staff","staff_role":"coach","full_name":"Coach Zafri Aziz"}'::jsonb,
      'authenticated','authenticated','00000000-0000-0000-0000-000000000000'),
    ('a3333333-3333-3333-3333-333333333303', 'coach3@isw.demo', pwd, now(),
      '{"role":"staff","staff_role":"coach","full_name":"Coach Maisarah Yusof"}'::jsonb,
      'authenticated','authenticated','00000000-0000-0000-0000-000000000000');

  -- Doctors
  INSERT INTO auth.users (id, email, encrypted_password, email_confirmed_at, raw_user_meta_data, role, aud, instance_id)
  VALUES
    ('a4444444-4444-4444-4444-444444444401', 'doctor1@isw.demo', pwd, now(),
      '{"role":"staff","staff_role":"doctor","full_name":"Dr. Ridzuan Bakar"}'::jsonb,
      'authenticated','authenticated','00000000-0000-0000-0000-000000000000'),
    ('a4444444-4444-4444-4444-444444444402', 'doctor2@isw.demo', pwd, now(),
      '{"role":"staff","staff_role":"doctor","full_name":"Dr. Siti Fatimah Omar"}'::jsonb,
      'authenticated','authenticated','00000000-0000-0000-0000-000000000000');

  -- Patients (15 total — various states)
  INSERT INTO auth.users (id, email, encrypted_password, email_confirmed_at, raw_user_meta_data, role, aud, instance_id)
  VALUES
    -- Brand new (just signed up)
    ('b0000001-0000-0000-0000-000000000001', 'patient1@isw.demo', pwd, now(), '{"role":"patient","full_name":"Ahmad Faris Rahim"}'::jsonb, 'authenticated','authenticated','00000000-0000-0000-0000-000000000000'),
    ('b0000002-0000-0000-0000-000000000002', 'patient2@isw.demo', pwd, now(), '{"role":"patient","full_name":"Nurin Sofea Adlin"}'::jsonb, 'authenticated','authenticated','00000000-0000-0000-0000-000000000000'),
    -- KYC submitted, pending approval
    ('b0000003-0000-0000-0000-000000000003', 'patient3@isw.demo', pwd, now(), '{"role":"patient","full_name":"Khairul Anwar Yatim"}'::jsonb, 'authenticated','authenticated','00000000-0000-0000-0000-000000000000'),
    -- KOB flow stages
    ('b0000004-0000-0000-0000-000000000004', 'patient4@isw.demo', pwd, now(), '{"role":"patient","full_name":"Siti Aminah Mohd"}'::jsonb, 'authenticated','authenticated','00000000-0000-0000-0000-000000000000'),
    ('b0000005-0000-0000-0000-000000000005', 'patient5@isw.demo', pwd, now(), '{"role":"patient","full_name":"Razif Hakim Suhaimi"}'::jsonb, 'authenticated','authenticated','00000000-0000-0000-0000-000000000000'),
    ('b0000006-0000-0000-0000-000000000006', 'patient6@isw.demo', pwd, now(), '{"role":"patient","full_name":"Maryam Iskandar"}'::jsonb, 'authenticated','authenticated','00000000-0000-0000-0000-000000000000'),
    -- Active treatment patients (various weeks)
    ('b0000007-0000-0000-0000-000000000007', 'patient7@isw.demo', pwd, now(), '{"role":"patient","full_name":"Hafsah Abdullah"}'::jsonb, 'authenticated','authenticated','00000000-0000-0000-0000-000000000000'),
    ('b0000008-0000-0000-0000-000000000008', 'patient8@isw.demo', pwd, now(), '{"role":"patient","full_name":"Iskandar Zulkarnain"}'::jsonb, 'authenticated','authenticated','00000000-0000-0000-0000-000000000000'),
    ('b0000009-0000-0000-0000-000000000009', 'patient9@isw.demo', pwd, now(), '{"role":"patient","full_name":"Zarith Sofiyya Rashid"}'::jsonb, 'authenticated','authenticated','00000000-0000-0000-0000-000000000000'),
    ('b0000010-0000-0000-0000-000000000010', 'patient10@isw.demo', pwd, now(), '{"role":"patient","full_name":"Adam Iskandar"}'::jsonb, 'authenticated','authenticated','00000000-0000-0000-0000-000000000000'),
    ('b0000011-0000-0000-0000-000000000011', 'patient11@isw.demo', pwd, now(), '{"role":"patient","full_name":"Liyana Diana Akmal"}'::jsonb, 'authenticated','authenticated','00000000-0000-0000-0000-000000000000'),
    -- Completed treatment
    ('b0000012-0000-0000-0000-000000000012', 'patient12@isw.demo', pwd, now(), '{"role":"patient","full_name":"Rosli Mansor"}'::jsonb, 'authenticated','authenticated','00000000-0000-0000-0000-000000000000'),
    ('b0000013-0000-0000-0000-000000000013', 'patient13@isw.demo', pwd, now(), '{"role":"patient","full_name":"Norhaslinda Yusoff"}'::jsonb, 'authenticated','authenticated','00000000-0000-0000-0000-000000000000'),
    -- Expired / lapsed package
    ('b0000014-0000-0000-0000-000000000014', 'patient14@isw.demo', pwd, now(), '{"role":"patient","full_name":"Mohd Rizal Bakhtiar"}'::jsonb, 'authenticated','authenticated','00000000-0000-0000-0000-000000000000'),
    -- Rejected KYC
    ('b0000015-0000-0000-0000-000000000015', 'patient15@isw.demo', pwd, now(), '{"role":"patient","full_name":"Nor Azlina Said"}'::jsonb, 'authenticated','authenticated','00000000-0000-0000-0000-000000000000');
END $$;

-- ── 2. Enrich psy_profiles (trigger created baseline; add phone, specialization, etc) ──
UPDATE psy_profiles SET phone='012-3456701', specialization='Pentadbiran Klinik', is_active=true WHERE id='a1111111-1111-1111-1111-111111111101';
UPDATE psy_profiles SET phone='012-3456702', specialization='Pentadbiran Klinik', is_active=true WHERE id='a1111111-1111-1111-1111-111111111102';
UPDATE psy_profiles SET phone='012-3456711', specialization='Operasi & Inventori', is_active=true WHERE id='a2222222-2222-2222-2222-222222222201';
UPDATE psy_profiles SET phone='012-3456712', specialization='Operasi & Inventori', is_active=true WHERE id='a2222222-2222-2222-2222-222222222202';
UPDATE psy_profiles SET phone='012-3456721', specialization='Coaching Bio-Psiko-Sosial', is_active=true WHERE id='a3333333-3333-3333-3333-333333333301';
UPDATE psy_profiles SET phone='012-3456722', specialization='Coaching Spiritual', is_active=true WHERE id='a3333333-3333-3333-3333-333333333302';
UPDATE psy_profiles SET phone='012-3456723', specialization='Coaching Pemulihan', is_active=true WHERE id='a3333333-3333-3333-3333-333333333303';
UPDATE psy_profiles SET phone='012-3456731', specialization='Perubatan Holistik', registration_no='MMC-12345', is_active=true WHERE id='a4444444-4444-4444-4444-444444444401';
UPDATE psy_profiles SET phone='012-3456732', specialization='Perubatan Komuniti', registration_no='MMC-67890', is_active=true WHERE id='a4444444-4444-4444-4444-444444444402';

UPDATE psy_profiles SET phone='011-1111111' WHERE id='b0000001-0000-0000-0000-000000000001';
UPDATE psy_profiles SET phone='011-2222222' WHERE id='b0000002-0000-0000-0000-000000000002';
UPDATE psy_profiles SET phone='011-3333333' WHERE id='b0000003-0000-0000-0000-000000000003';
UPDATE psy_profiles SET phone='011-4444444' WHERE id='b0000004-0000-0000-0000-000000000004';
UPDATE psy_profiles SET phone='011-5555555' WHERE id='b0000005-0000-0000-0000-000000000005';
UPDATE psy_profiles SET phone='011-6666666' WHERE id='b0000006-0000-0000-0000-000000000006';
UPDATE psy_profiles SET phone='011-7777777' WHERE id='b0000007-0000-0000-0000-000000000007';
UPDATE psy_profiles SET phone='011-8888888' WHERE id='b0000008-0000-0000-0000-000000000008';
UPDATE psy_profiles SET phone='011-9999999' WHERE id='b0000009-0000-0000-0000-000000000009';
UPDATE psy_profiles SET phone='012-1010101' WHERE id='b0000010-0000-0000-0000-000000000010';
UPDATE psy_profiles SET phone='012-1111121' WHERE id='b0000011-0000-0000-0000-000000000011';
UPDATE psy_profiles SET phone='012-1212121' WHERE id='b0000012-0000-0000-0000-000000000012';
UPDATE psy_profiles SET phone='012-1313131' WHERE id='b0000013-0000-0000-0000-000000000013';
UPDATE psy_profiles SET phone='012-1414141' WHERE id='b0000014-0000-0000-0000-000000000014';
UPDATE psy_profiles SET phone='012-1515151' WHERE id='b0000015-0000-0000-0000-000000000015';

-- ── 3. Sample Products ──
INSERT INTO psy_products (product_id, name, description, category, price, stock, icon, bg_color, is_active, sort_order) VALUES
  ('madu-yhh-500g',   'Madu YHH 500g',          'Madu asli untuk rawatan harian',           'Madu',  120.00, 50, '🍯', 'bg-gold/15',     true, 10),
  ('madu-yhh-1kg',    'Madu YHH 1kg',           'Saiz keluarga, jimat',                     'Madu',  220.00, 30, '🍯', 'bg-gold/15',     true, 20),
  ('herba-thoharah',  'Herba Thoharah',         'Campuran herba pemulihan',                 'Herba',  85.00, 40, '🌿', 'bg-green/15',    true, 30),
  ('minyak-zaitun',   'Minyak Zaitun Premium',  'Extra virgin olive oil 500ml',             'Minyak', 65.00, 25, '🫒', 'bg-green/15',    true, 40),
  ('botol-detoks',    'Botol Detoks Set',       'Set 3 botol untuk program detoks',         'Set',   180.00, 20, '💧', 'bg-navy/15',     true, 50),
  ('kapsul-kurma',    'Kapsul Sari Kurma',      'Suplemen sari kurma 60 kapsul',            'Suplemen', 55.00, 60, '💊', 'bg-terracotta/15', true, 60)
ON CONFLICT (product_id) DO UPDATE SET name=EXCLUDED.name, price=EXCLUDED.price, stock=EXCLUDED.stock;

-- ── 4. Sample Packages (jika belum ada) ──
INSERT INTO psy_packages (package_id, name, description, price, duration, duration_weeks, icon, bg_color, tier, is_active, sort_order)
VALUES
  ('pkg-free',     'HTO Free Trial',     '1 minggu pakej percubaan',                          0,    '1 Minggu',   1,  '🌱', 'bg-green/15',    'free',     true, 10),
  ('pkg-obp1',     'OBP 1 — Asas',       '4 minggu pakej asas untuk pemula',                  399,  '4 Minggu',   4,  '📗', 'bg-navy/15',     'standard', true, 20),
  ('pkg-obp2',     'OBP 2 — Pertengahan','8 minggu pakej pertengahan',                        799,  '8 Minggu',   8,  '📘', 'bg-navy/15',     'standard', true, 30),
  ('pkg-hto',      'HTO Intensive',      '12 minggu program intensif holistik',               1599, '12 Minggu',  12, '🌿', 'bg-green/15',    'standard', true, 40),
  ('pkg-vip',      'VIP Premium',        '16 minggu rawatan VIP dengan akses penuh',          2999, '16 Minggu',  16, '💎', 'bg-gold/15',     'vip',      true, 50)
ON CONFLICT (package_id) DO UPDATE SET name=EXCLUDED.name, price=EXCLUDED.price;

-- ── 5. PATIENTS — various states ──

-- Patient 1: BRAND NEW (no psy_patients record yet — auto-created on first login)
-- (Skip insert; system will create on dashboard load)

-- Patient 2: BRAND NEW (also no record)

-- Patient 3: KYC submitted, pending
INSERT INTO psy_patients (id, user_id, mrn, ic_number, status, kob_status) VALUES
  ('c0000003-0000-0000-0000-000000000003', 'b0000003-0000-0000-0000-000000000003', 'P-003', '950101-14-1003', 'pending_kyc', 'pending_payment');

INSERT INTO psy_kyc_submissions (user_id, patient_name, ic_number, phone, medical_condition, status, created_at) VALUES
  ('b0000003-0000-0000-0000-000000000003', 'Khairul Anwar Yatim', '950101-14-1003', '011-3333333',
   'Hipertensi peringkat awal, sakit kepala migrain berulang', 'pending', now() - interval '2 days');

-- Patient 4: KYC done, awaiting KOB booking
INSERT INTO psy_patients (id, user_id, mrn, ic_number, date_of_birth, gender, address, phone, medical_condition, emergency_contact_name, emergency_contact_phone, status, kob_status) VALUES
  ('c0000004-0000-0000-0000-000000000004', 'b0000004-0000-0000-0000-000000000004', 'P-004', '880515-10-2004', '1988-05-15', 'F', 'No 12, Jln Damai, 50000 Kuala Lumpur', '011-4444444',
   'Diabetes Type 2, BMI tinggi', 'Mohd Tahir', '019-4040404', 'pending_kyc', 'kyc_done');

INSERT INTO psy_kyc_submissions (user_id, patient_name, ic_number, phone, medical_condition, status, reviewed_by, created_at) VALUES
  ('b0000004-0000-0000-0000-000000000004', 'Siti Aminah Mohd', '880515-10-2004', '011-4444444',
   'Diabetes Type 2, BMI tinggi', 'approved', 'a4444444-4444-4444-4444-444444444401', now() - interval '8 days');

-- Patient 5: KOB booked
INSERT INTO psy_patients (id, user_id, mrn, ic_number, date_of_birth, gender, phone, medical_condition, status, kob_status) VALUES
  ('c0000005-0000-0000-0000-000000000005', 'b0000005-0000-0000-0000-000000000005', 'P-005', '920308-08-3005', '1992-03-08', 'M', '011-5555555',
   'Insomnia kronik, kebimbangan', 'pending_kyc', 'booked');

INSERT INTO psy_kob_sessions (patient_id, scheduled_at, mode, status, created_at) VALUES
  ('c0000005-0000-0000-0000-000000000005', now() + interval '3 days' + time '10:00', 'f2f', 'booked', now() - interval '5 days');

-- Patient 6: Package recommended (KOB done, awaiting payment)
INSERT INTO psy_patients (id, user_id, mrn, ic_number, date_of_birth, gender, phone, medical_condition, status, kob_status) VALUES
  ('c0000006-0000-0000-0000-000000000006', 'b0000006-0000-0000-0000-000000000006', 'P-006', '850920-12-4006', '1985-09-20', 'F', '011-6666666',
   'Stress, gangguan tidur, kolesterol tinggi', 'pending_kyc', 'package_recommended');

INSERT INTO psy_kob_sessions (patient_id, scheduled_at, mode, status, doctor_hadir_id, doctor_hadir_name, hadir_at, doctor_selesai_id, doctor_selesai_name, selesai_at, notes, recommended_package_id, recommended_package_name, recommended_package_price)
VALUES
  ('c0000006-0000-0000-0000-000000000006', now() - interval '7 days', 'f2f', 'completed',
   'a4444444-4444-4444-4444-444444444401', 'Dr. Ridzuan Bakar', now() - interval '7 days',
   'a4444444-4444-4444-4444-444444444401', 'Dr. Ridzuan Bakar', now() - interval '7 days' + interval '45 min',
   'Pesakit menunjukkan tanda-tanda stress kronik. Cadang HTO Intensive.',
   'pkg-hto', 'HTO Intensive', 1599);

-- Helper: pre-build daily_schedule once (used across patients)
-- ── 6. ACTIVE TREATMENT PATIENTS (Week 2, 5, 8, 11, 11) ──

-- Patient 7: Week 2 (just started — HTO Intensive)
INSERT INTO psy_patients (id, user_id, mrn, ic_number, date_of_birth, gender, phone, address, medical_condition, emergency_contact_name, emergency_contact_phone, status, kob_status, active_package_id, package_purchased_at, package_expires_at, coach_id, daily_schedule)
VALUES
  ('c0000007-0000-0000-0000-000000000007', 'b0000007-0000-0000-0000-000000000007', 'P-007', '900712-05-5007', '1990-07-12', 'F', '011-7777777', 'Jln Hijau 5, Shah Alam', 'Hipertensi, BMI tinggi', 'Abdullah', '019-7070707', 'active', 'completed', 'pkg-hto',
   now() - interval '14 days', now() + interval '70 days', 'a3333333-3333-3333-3333-333333333301',
   '[{"time":"06:30","activity":"Minum Madu","description":"2 sudu besar"},
     {"time":"07:00","activity":"Minum Yogurt","description":"Probiotik"},
     {"time":"08:00","activity":"Berjemur","description":"10-15 minit"},
     {"time":"09:30","activity":"Terapi Bumi","description":"30 minit"},
     {"time":"10:30","activity":"Pernafasan Fitrah","description":"10 minit"},
     {"time":"20:30","activity":"Zikir Bersanad","description":"10-15 minit"},
     {"time":"22:00","activity":"Rehat & Tidur Awal","description":"Sebelum 10:30"}]'::jsonb);

-- Patient 8: Week 5 (HTO Intensive)
INSERT INTO psy_patients (id, user_id, mrn, ic_number, date_of_birth, gender, phone, medical_condition, status, kob_status, active_package_id, package_purchased_at, package_expires_at, coach_id, daily_schedule)
VALUES
  ('c0000008-0000-0000-0000-000000000008', 'b0000008-0000-0000-0000-000000000008', 'P-008', '780428-03-6008', '1978-04-28', 'M', '011-8888888',
   'Diabetes Type 2, neuropathy ringan', 'active', 'completed', 'pkg-hto',
   now() - interval '35 days', now() + interval '49 days', 'a3333333-3333-3333-3333-333333333301',
   '[{"time":"06:30","activity":"Minum Madu"},{"time":"08:00","activity":"Berjemur"},{"time":"10:00","activity":"Terapi Bumi"},{"time":"22:00","activity":"Tidur Awal"}]'::jsonb);

-- Patient 9: Week 8 (OBP 2 — Pertengahan)
INSERT INTO psy_patients (id, user_id, mrn, ic_number, date_of_birth, gender, phone, medical_condition, status, kob_status, active_package_id, package_purchased_at, package_expires_at, coach_id, daily_schedule)
VALUES
  ('c0000009-0000-0000-0000-000000000009', 'b0000009-0000-0000-0000-000000000009', 'P-009', '950113-07-7009', '1995-01-13', 'F', '011-9999999',
   'Gangguan kecemasan, IBS', 'active', 'completed', 'pkg-obp2',
   now() - interval '56 days', now() + interval '0 days', 'a3333333-3333-3333-3333-333333333302',
   '[{"time":"07:00","activity":"Minum Madu"},{"time":"09:00","activity":"Berjemur"},{"time":"15:00","activity":"Pernafasan Fitrah"}]'::jsonb);

-- Patient 10: Week 11 of 12 (HTO Intensive — hampir habis)
INSERT INTO psy_patients (id, user_id, mrn, ic_number, date_of_birth, gender, phone, medical_condition, status, kob_status, active_package_id, package_purchased_at, package_expires_at, coach_id, daily_schedule)
VALUES
  ('c0000010-0000-0000-0000-000000000010', 'b0000010-0000-0000-0000-000000000010', 'P-010', '820606-06-8010', '1982-06-06', 'M', '012-1010101',
   'Hipertensi, kolesterol tinggi', 'active', 'completed', 'pkg-hto',
   now() - interval '77 days', now() + interval '7 days', 'a3333333-3333-3333-3333-333333333303',
   '[{"time":"06:30","activity":"Minum Madu"},{"time":"08:00","activity":"Berjemur"},{"time":"21:00","activity":"Zikir Bersanad"}]'::jsonb);

-- Patient 11: Week 2 (OBP 1 — Asas)
INSERT INTO psy_patients (id, user_id, mrn, ic_number, date_of_birth, gender, phone, medical_condition, status, kob_status, active_package_id, package_purchased_at, package_expires_at, coach_id, daily_schedule)
VALUES
  ('c0000011-0000-0000-0000-000000000011', 'b0000011-0000-0000-0000-000000000011', 'P-011', '990825-04-9011', '1999-08-25', 'F', '012-1111121',
   'Period tak teratur, jerawat hormone', 'active', 'completed', 'pkg-obp1',
   now() - interval '10 days', now() + interval '18 days', 'a3333333-3333-3333-3333-333333333302',
   '[{"time":"07:00","activity":"Minum Madu"},{"time":"09:00","activity":"Berjemur"}]'::jsonb);

-- Patient 12: COMPLETED treatment (HTO done)
INSERT INTO psy_patients (id, user_id, mrn, ic_number, date_of_birth, gender, phone, medical_condition, status, kob_status, active_package_id, package_purchased_at, package_expires_at, coach_id) VALUES
  ('c0000012-0000-0000-0000-000000000012', 'b0000012-0000-0000-0000-000000000012', 'P-012', '700315-01-1012', '1970-03-15', 'M', '012-1212121',
   'Hipertensi (sebelum) — sekarang normal', 'active', 'completed', 'pkg-hto',
   now() - interval '180 days', now() - interval '96 days', 'a3333333-3333-3333-3333-333333333301');

-- Patient 13: COMPLETED treatment (VIP done)
INSERT INTO psy_patients (id, user_id, mrn, ic_number, date_of_birth, gender, phone, medical_condition, status, kob_status, active_package_id, package_purchased_at, package_expires_at, coach_id) VALUES
  ('c0000013-0000-0000-0000-000000000013', 'b0000013-0000-0000-0000-000000000013', 'P-013', '750418-02-2013', '1975-04-18', 'F', '012-1313131',
   'Diabetes Type 2 (sebelum) — sekarang terkawal', 'active', 'completed', 'pkg-vip',
   now() - interval '200 days', now() - interval '88 days', 'a3333333-3333-3333-3333-333333333303');

-- Patient 14: EXPIRED / lapsed package
INSERT INTO psy_patients (id, user_id, mrn, ic_number, date_of_birth, gender, phone, medical_condition, status, kob_status, active_package_id, package_purchased_at, package_expires_at, coach_id) VALUES
  ('c0000014-0000-0000-0000-000000000014', 'b0000014-0000-0000-0000-000000000014', 'P-014', '870519-11-3014', '1987-05-19', 'M', '012-1414141',
   'Stress kerja, insomnia', 'active', 'completed', 'pkg-obp1',
   now() - interval '60 days', now() - interval '32 days', 'a3333333-3333-3333-3333-333333333302');

-- Patient 15: REJECTED KYC
INSERT INTO psy_patients (id, user_id, mrn, ic_number, status, kob_status) VALUES
  ('c0000015-0000-0000-0000-000000000015', 'b0000015-0000-0000-0000-000000000015', 'P-015', '960225-13-4015', 'rejected', 'pending_payment');

INSERT INTO psy_kyc_submissions (user_id, patient_name, ic_number, phone, medical_condition, status, reviewed_by, created_at) VALUES
  ('b0000015-0000-0000-0000-000000000015', 'Nor Azlina Said', '960225-13-4015', '012-1515151',
   'Tidak lengkap — perlu dokumen tambahan', 'rejected', 'a1111111-1111-1111-1111-111111111101', now() - interval '15 days');

-- ── 7. TREATMENT PLANS for active patients ──
INSERT INTO psy_treatment_plans (id, patient_id, doctor_id, name, template, duration_weeks, current_week, status, created_at) VALUES
  ('d0000007-0000-0000-0000-000000000007', 'c0000007-0000-0000-0000-000000000007', 'a4444444-4444-4444-4444-444444444401', 'HTO Intensive — Hafsah', 'pkg-hto', 12,  2, 'active', now() - interval '14 days'),
  ('d0000008-0000-0000-0000-000000000008', 'c0000008-0000-0000-0000-000000000008', 'a4444444-4444-4444-4444-444444444401', 'HTO Intensive — Iskandar', 'pkg-hto', 12, 5, 'active', now() - interval '35 days'),
  ('d0000009-0000-0000-0000-000000000009', 'c0000009-0000-0000-0000-000000000009', 'a4444444-4444-4444-4444-444444444402', 'OBP 2 — Zarith',   'pkg-obp2', 8,  8, 'active', now() - interval '56 days'),
  ('d0000010-0000-0000-0000-000000000010', 'c0000010-0000-0000-0000-000000000010', 'a4444444-4444-4444-4444-444444444401', 'HTO Intensive — Adam',  'pkg-hto', 12, 11, 'active', now() - interval '77 days'),
  ('d0000011-0000-0000-0000-000000000011', 'c0000011-0000-0000-0000-000000000011', 'a4444444-4444-4444-4444-444444444402', 'OBP 1 — Liyana',   'pkg-obp1', 4,  2, 'active', now() - interval '10 days'),
  ('d0000012-0000-0000-0000-000000000012', 'c0000012-0000-0000-0000-000000000012', 'a4444444-4444-4444-4444-444444444401', 'HTO Intensive — Rosli (completed)', 'pkg-hto', 12, 12, 'completed', now() - interval '180 days'),
  ('d0000013-0000-0000-0000-000000000013', 'c0000013-0000-0000-0000-000000000013', 'a4444444-4444-4444-4444-444444444402', 'VIP — Norhaslinda (completed)', 'pkg-vip', 16, 16, 'completed', now() - interval '200 days');

-- ── 8. PLAN WEEKLY PROGRESS — past sessions (hadir) + upcoming (booked) ──
-- Patient 7 (week 2): week 1 hadir, week 2 booked (this week), weeks 3-12 pending
INSERT INTO psy_plan_weekly_progress (plan_id, patient_id, week_number, status, session_date, score) VALUES
  ('d0000007-0000-0000-0000-000000000007', 'c0000007-0000-0000-0000-000000000007', 1, 'hadir', (now() - interval '7 days')::timestamptz + time '10:00',7),
  ('d0000007-0000-0000-0000-000000000007', 'c0000007-0000-0000-0000-000000000007', 2, 'booked', (now() + interval '0 days')::timestamptz + time '10:00',NULL),
  ('d0000007-0000-0000-0000-000000000007', 'c0000007-0000-0000-0000-000000000007', 3, 'booked', (now() + interval '7 days')::timestamptz + time '10:00',NULL);

-- Patient 8 (week 5): wks 1-4 hadir, 5 booked today
INSERT INTO psy_plan_weekly_progress (plan_id, patient_id, week_number, status, session_date, score) VALUES
  ('d0000008-0000-0000-0000-000000000008', 'c0000008-0000-0000-0000-000000000008', 1, 'hadir', (now() - interval '28 days')::timestamptz + time '14:00',6),
  ('d0000008-0000-0000-0000-000000000008', 'c0000008-0000-0000-0000-000000000008', 2, 'hadir', (now() - interval '21 days')::timestamptz + time '14:00',7),
  ('d0000008-0000-0000-0000-000000000008', 'c0000008-0000-0000-0000-000000000008', 3, 'hadir', (now() - interval '14 days')::timestamptz + time '14:00',7),
  ('d0000008-0000-0000-0000-000000000008', 'c0000008-0000-0000-0000-000000000008', 4, 'hadir', (now() - interval '7 days')::timestamptz + time '14:00',8),
  ('d0000008-0000-0000-0000-000000000008', 'c0000008-0000-0000-0000-000000000008', 5, 'booked', (now() + interval '1 days')::timestamptz + time '14:00',NULL),
  ('d0000008-0000-0000-0000-000000000008', 'c0000008-0000-0000-0000-000000000008', 6, 'booked', (now() + interval '8 days')::timestamptz + time '14:00',NULL);

-- Patient 9 (week 8 of 8 — last week)
INSERT INTO psy_plan_weekly_progress (plan_id, patient_id, week_number, status, session_date, score)
SELECT 'd0000009-0000-0000-0000-000000000009', 'c0000009-0000-0000-0000-000000000009', wk, 'hadir',
       (now() - interval '56 days' + (wk-1) * interval '7 days')::timestamptz + time '11:00',6 + (wk % 3)
FROM generate_series(1, 7) wk;
INSERT INTO psy_plan_weekly_progress (plan_id, patient_id, week_number, status, session_date)
VALUES ('d0000009-0000-0000-0000-000000000009', 'c0000009-0000-0000-0000-000000000009', 8, 'booked', (now() + interval '2 days')::timestamptz + time '11:00');

-- Patient 10 (week 11 of 12)
INSERT INTO psy_plan_weekly_progress (plan_id, patient_id, week_number, status, session_date, score)
SELECT 'd0000010-0000-0000-0000-000000000010', 'c0000010-0000-0000-0000-000000000010', wk, 'hadir',
       (now() - interval '77 days' + (wk-1) * interval '7 days')::timestamptz + time '15:00',5 + (wk % 4)
FROM generate_series(1, 10) wk;
INSERT INTO psy_plan_weekly_progress (plan_id, patient_id, week_number, status, session_date)
VALUES
  ('d0000010-0000-0000-0000-000000000010', 'c0000010-0000-0000-0000-000000000010', 11, 'booked', (now() + interval '0 days')::timestamptz + time '15:00'),
  ('d0000010-0000-0000-0000-000000000010', 'c0000010-0000-0000-0000-000000000010', 12, 'booked', (now() + interval '7 days')::timestamptz + time '15:00');

-- Patient 11 (week 2 of 4)
INSERT INTO psy_plan_weekly_progress (plan_id, patient_id, week_number, status, session_date, score) VALUES
  ('d0000011-0000-0000-0000-000000000011', 'c0000011-0000-0000-0000-000000000011', 1, 'hadir',  (now() - interval '3 days')::timestamptz + time '09:00',7),
  ('d0000011-0000-0000-0000-000000000011', 'c0000011-0000-0000-0000-000000000011', 2, 'booked', (now() + interval '4 days')::timestamptz + time '09:00',NULL),
  ('d0000011-0000-0000-0000-000000000011', 'c0000011-0000-0000-0000-000000000011', 3, 'booked', (now() + interval '11 days')::timestamptz + time '09:00',NULL);

-- Patient 12 (completed 12/12)
INSERT INTO psy_plan_weekly_progress (plan_id, patient_id, week_number, status, session_date, score)
SELECT 'd0000012-0000-0000-0000-000000000012', 'c0000012-0000-0000-0000-000000000012', wk, 'hadir',
       (now() - interval '180 days' + (wk-1) * interval '7 days')::timestamptz + time '10:00',6 + (wk % 4)
FROM generate_series(1, 12) wk;

-- Patient 13 (completed 16/16 VIP)
INSERT INTO psy_plan_weekly_progress (plan_id, patient_id, week_number, status, session_date, score)
SELECT 'd0000013-0000-0000-0000-000000000013', 'c0000013-0000-0000-0000-000000000013', wk, 'hadir',
       (now() - interval '200 days' + (wk-1) * interval '7 days')::timestamptz + time '14:00',7 + (wk % 3)
FROM generate_series(1, 16) wk;

-- ── 9. DAILY CHECK-INS (last 14 days) for active patients ──
INSERT INTO psy_daily_checkins (patient_id, checkin_date, mood_score, energy_score, sleep_hours)
SELECT pid, d::date, 5 + (random()*4)::int, 4 + (random()*5)::int, 5.5 + random()*3
FROM (VALUES
  ('c0000007-0000-0000-0000-000000000007'::uuid),
  ('c0000008-0000-0000-0000-000000000008'::uuid),
  ('c0000009-0000-0000-0000-000000000009'::uuid),
  ('c0000010-0000-0000-0000-000000000010'::uuid),
  ('c0000011-0000-0000-0000-000000000011'::uuid)
) p(pid),
generate_series(now() - interval '13 days', now() - interval '0 days', interval '1 day') d
ON CONFLICT (patient_id, checkin_date) DO NOTHING;

-- ── 10. DAILY COMPLETIONS (last 7 days, ~80% adherence) for active patients ──
INSERT INTO psy_daily_completions (patient_id, log_date, item_time, activity, completed_at)
SELECT p.pid, d::date, t.item_time, t.activity, d + (t.item_time || ':00')::time
FROM (VALUES
  ('c0000007-0000-0000-0000-000000000007'::uuid),
  ('c0000008-0000-0000-0000-000000000008'::uuid),
  ('c0000009-0000-0000-0000-000000000009'::uuid),
  ('c0000010-0000-0000-0000-000000000010'::uuid),
  ('c0000011-0000-0000-0000-000000000011'::uuid)
) p(pid)
CROSS JOIN generate_series(now() - interval '6 days', now() - interval '0 days', interval '1 day') d
CROSS JOIN (VALUES
  ('06:30','Minum Madu'),
  ('08:00','Berjemur'),
  ('10:30','Pernafasan Fitrah'),
  ('22:00','Tidur Awal')
) t(item_time, activity)
WHERE random() < 0.82  -- 82% adherence
ON CONFLICT (patient_id, log_date, item_time) DO NOTHING;

-- ── 11. VITALS — readings untuk active patients ──
INSERT INTO psy_vitals (patient_id, bp_systolic, bp_diastolic, hba1c, reading_date, source, created_at) VALUES
  ('c0000007-0000-0000-0000-000000000007', 142, 92, 6.8, (now() - interval '14 days')::date, 'staff', now() - interval '14 days'),
  ('c0000007-0000-0000-0000-000000000007', 135, 88, NULL, (now() - interval '7 days')::date, 'patient_self', now() - interval '7 days'),
  ('c0000008-0000-0000-0000-000000000008', 138, 90, 7.2, (now() - interval '30 days')::date, 'staff', now() - interval '30 days'),
  ('c0000008-0000-0000-0000-000000000008', 128, 82, 6.5, (now() - interval '7 days')::date, 'staff', now() - interval '7 days'),
  ('c0000009-0000-0000-0000-000000000009', 118, 76, NULL, (now() - interval '50 days')::date, 'staff', now() - interval '50 days'),
  ('c0000009-0000-0000-0000-000000000009', 115, 74, NULL, (now() - interval '7 days')::date, 'patient_self', now() - interval '7 days'),
  ('c0000010-0000-0000-0000-000000000010', 150, 95, 7.5, (now() - interval '75 days')::date, 'staff', now() - interval '75 days'),
  ('c0000010-0000-0000-0000-000000000010', 130, 85, 6.3, (now() - interval '7 days')::date, 'staff', now() - interval '7 days'),
  ('c0000011-0000-0000-0000-000000000011', 120, 78, NULL, (now() - interval '10 days')::date, 'patient_self', now() - interval '10 days'),
  ('c0000012-0000-0000-0000-000000000012', 145, 92, 7.8, (now() - interval '180 days')::date, 'staff', now() - interval '180 days'),
  ('c0000012-0000-0000-0000-000000000012', 122, 80, 5.9, (now() - interval '100 days')::date, 'staff', now() - interval '100 days'),
  ('c0000013-0000-0000-0000-000000000013', 138, 88, 8.2, (now() - interval '200 days')::date, 'staff', now() - interval '200 days'),
  ('c0000013-0000-0000-0000-000000000013', 120, 78, 6.0, (now() - interval '90 days')::date, 'staff', now() - interval '90 days');

-- ── 12. ORDERS ──
INSERT INTO psy_orders (order_ref, patient_id, items, total, status, delivery_method, courier, tracking_number, paid_at, created_at) VALUES
  ('ORD-DEMO-001', 'b0000007-0000-0000-0000-000000000007', '[{"product_id":"madu-yhh-500g","name":"Madu YHH 500g","qty":2,"price":120}]'::jsonb, 240, 'shipped', 'pos', 'PosLaju', 'PL123456789MY', now() - interval '3 days', now() - interval '5 days'),
  ('ORD-DEMO-002', 'b0000008-0000-0000-0000-000000000008', '[{"product_id":"madu-yhh-1kg","name":"Madu YHH 1kg","qty":1,"price":220},{"product_id":"herba-thoharah","name":"Herba Thoharah","qty":1,"price":85}]'::jsonb, 305, 'delivered', 'pos', 'PosLaju', 'PL987654321MY', now() - interval '10 days', now() - interval '12 days'),
  ('ORD-DEMO-003', 'b0000009-0000-0000-0000-000000000009', '[{"product_id":"kapsul-kurma","name":"Kapsul Sari Kurma","qty":3,"price":55}]'::jsonb, 165, 'paid', 'pos', NULL, NULL, now() - interval '1 day', now() - interval '1 day'),
  ('ORD-DEMO-004', 'b0000010-0000-0000-0000-000000000010', '[{"product_id":"botol-detoks","name":"Botol Detoks Set","qty":1,"price":180}]'::jsonb, 180, 'pending', 'pickup', NULL, NULL, NULL, now()),
  ('ORD-DEMO-005', 'b0000012-0000-0000-0000-000000000012', '[{"product_id":"madu-yhh-500g","name":"Madu YHH 500g","qty":1,"price":120}]'::jsonb, 120, 'delivered', 'pos', 'PosLaju', 'PL555444333MY', now() - interval '100 days', now() - interval '102 days');

-- ── 13. ANNOUNCEMENTS ──
INSERT INTO psy_announcements (title, body, tag, cta_label, cta_url, is_active, sort_order) VALUES
  ('Program Geng ALIVE Sesi 2', 'Sertai sesi sokongan pesakit pada 24 Mei 2026 (Sabtu), 9:00 AM di Dewan ISW.', 'BARU', 'Daftar', '#', true, 10),
  ('Kemaskini Waktu Operasi', 'Waktu operasi klinik ISW sepanjang Ramadan: 8:00 AM - 5:00 PM.', 'INFO', NULL, NULL, true, 20),
  ('Promo Bulan Mei: Madu YHH', 'Diskaun 15% untuk pembelian Madu YHH 1kg. Sah sehingga 31 Mei.', 'PROMO', 'Beli Sekarang', 'shop.html', true, 30);

-- ── 14. NOTIFICATIONS (sampel untuk patient aktif) ──
INSERT INTO psy_notifications (user_id, type, title, body, link, is_read, created_at) VALUES
  ('b0000007-0000-0000-0000-000000000007', 'plan',        'Sesi Coaching Esok',        'Sesi minggu ke-2 anda esok jam 10:00 AM',                  'plan.html', false, now() - interval '4 hours'),
  ('b0000007-0000-0000-0000-000000000007', 'order',       'Order Telah Dihantar',      'Order anda dalam perjalanan. Track: PL123456789MY',         'orders.html', false, now() - interval '3 days'),
  ('b0000008-0000-0000-0000-000000000008', 'appointment', 'Reminder: Check-in Hari Ini', 'Jangan lupa check-in harian',                              'checkin.html', true, now() - interval '1 day'),
  ('b0000010-0000-0000-0000-000000000010', 'plan',        'Rawatan Hampir Tamat',      'Anda di minggu ke-11 daripada 12. Tahniah!',                'plan.html', false, now() - interval '1 day'),
  ('b0000004-0000-0000-0000-000000000004', 'system',      'KYC Telah Diluluskan',      'Sila tempah slot KOB anda.',                                'kob.html', false, now() - interval '7 days');

-- ── 15. KOB QUESTIONNAIRES ──  (jika table ada — skip kalau error)
-- (Optional — di-skip kalau struktur tak match)

-- ── 16. MEDICAL REPORTS (psy_dna_reports renamed to psy_medical_reports in step_patient_hub_v2) ──
INSERT INTO psy_medical_reports (patient_id, file_name, file_path, file_url, uploaded_at, uploaded_by_name, report_type) VALUES
  ('c0000008-0000-0000-0000-000000000008', 'DNA_Iskandar_2026.pdf', 'dna/iskandar.pdf', 'https://placehold.co/dna-report.pdf', now() - interval '30 days', 'Dr. Ridzuan Bakar', 'dna'),
  ('c0000010-0000-0000-0000-000000000010', 'DNA_Adam_Genetics.pdf', 'dna/adam.pdf', 'https://placehold.co/dna-report.pdf', now() - interval '60 days', 'Dr. Ridzuan Bakar', 'dna'),
  ('c0000013-0000-0000-0000-000000000013', 'DNA_Norhaslinda_Full.pdf', 'dna/norhaslinda.pdf', 'https://placehold.co/dna-report.pdf', now() - interval '150 days', 'Dr. Siti Fatimah Omar', 'dna');

-- ── 17. APPOINTMENTS (KOB + walk-in samples) ──
INSERT INTO psy_appointments (patient_id, staff_id, patient_name, staff_name, service, appointment_time, status, room) VALUES
  ('c0000005-0000-0000-0000-000000000005', 'a4444444-4444-4444-4444-444444444401', 'Razif Hakim',     'Dr. Ridzuan Bakar',     'Konsultasi KOB', now() + interval '3 days' + time '10:00', 'scheduled',  'Ruang A'),
  ('c0000007-0000-0000-0000-000000000007', 'a3333333-3333-3333-3333-333333333301', 'Hafsah Abdullah', 'Coach Aina Salleh',     'Sesi Coaching Minggu 2', now() + time '10:00', 'scheduled', 'Ruang Coaching 1'),
  ('c0000008-0000-0000-0000-000000000008', 'a3333333-3333-3333-3333-333333333301', 'Iskandar Zulkarnain', 'Coach Aina Salleh', 'Sesi Coaching Minggu 5', now() + interval '1 day' + time '14:00', 'scheduled', 'Ruang Coaching 1');

-- ============================================================
-- SUMMARY
-- ============================================================
SELECT 'SEED DEMO COMPLETED' AS status;
SELECT 'Users created' AS metric, count(*) FROM auth.users WHERE email LIKE '%@isw.demo'
UNION ALL SELECT 'Profiles', count(*) FROM psy_profiles WHERE id IN (SELECT id FROM auth.users WHERE email LIKE '%@isw.demo')
UNION ALL SELECT 'Patients', count(*) FROM psy_patients WHERE user_id IN (SELECT id FROM auth.users WHERE email LIKE '%@isw.demo')
UNION ALL SELECT 'Treatment plans', count(*) FROM psy_treatment_plans WHERE patient_id IN (SELECT id FROM psy_patients WHERE user_id IN (SELECT id FROM auth.users WHERE email LIKE '%@isw.demo'))
UNION ALL SELECT 'Weekly progress rows', count(*) FROM psy_plan_weekly_progress WHERE patient_id IN (SELECT id FROM psy_patients WHERE user_id IN (SELECT id FROM auth.users WHERE email LIKE '%@isw.demo'))
UNION ALL SELECT 'Daily check-ins', count(*) FROM psy_daily_checkins WHERE patient_id IN (SELECT id FROM psy_patients WHERE user_id IN (SELECT id FROM auth.users WHERE email LIKE '%@isw.demo'))
UNION ALL SELECT 'Daily completions', count(*) FROM psy_daily_completions WHERE patient_id IN (SELECT id FROM psy_patients WHERE user_id IN (SELECT id FROM auth.users WHERE email LIKE '%@isw.demo'))
UNION ALL SELECT 'Vitals', count(*) FROM psy_vitals WHERE patient_id IN (SELECT id FROM psy_patients WHERE user_id IN (SELECT id FROM auth.users WHERE email LIKE '%@isw.demo'))
UNION ALL SELECT 'Orders', count(*) FROM psy_orders WHERE patient_id IN (SELECT id FROM auth.users WHERE email LIKE '%@isw.demo')
UNION ALL SELECT 'Announcements (total)', count(*) FROM psy_announcements
UNION ALL SELECT 'Notifications', count(*) FROM psy_notifications WHERE user_id IN (SELECT id FROM auth.users WHERE email LIKE '%@isw.demo');
