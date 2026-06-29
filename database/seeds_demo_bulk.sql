-- ============================================================
-- seeds_demo_bulk.sql — Skala pesakit demo ~+106 (jumlah ~120)
-- Taburan realistik (penyakit/negeri/pakej/umur/status berulang) supaya
-- carta Dashboard Manager nampak penuh. Run SELEPAS seeds_demo_full.sql.
-- TESTING sahaja (ipmemyizigwgivccytcu). Re-runnable (auth.users ON CONFLICT).
-- ============================================================
BEGIN;

CREATE TEMP TABLE _bulk ON COMMIT DROP AS
SELECT
  i,
  gen_random_uuid() AS pid, gen_random_uuid() AS prof, gen_random_uuid() AS plan,
  (CASE WHEN i%2=0 THEN 'M' ELSE 'F' END) AS gender,
  (CASE WHEN i%2=0
     THEN (ARRAY['Ahmad','Mohd','Hafiz','Faiz','Hakim','Idris','Naufal','Zaki','Rizal','Amir'])[1+(i%10)]||' bin '||(ARRAY['Abdullah','Hassan','Ismail','Yusof','Karim','Salleh','Aziz','Rahman'])[1+(i%8)]
     ELSE (ARRAY['Siti','Nur','Aisyah','Fatimah','Rohana','Aminah','Liyana','Farah','Halimah','Zaiton'])[1+(i%10)]||' binti '||(ARRAY['Abdullah','Hassan','Ismail','Yusof','Karim','Salleh','Aziz','Rahman'])[1+(i%8)]
   END) AS name,
  make_date((1952 + ((i*7)%48))::int, (1+(i%12))::int, (1+(i%27))::int) AS dob,
  (ARRAY['Diabetes jenis 2','Diabetes jenis 2','Diabetes jenis 2','Diabetes jenis 2','Tekanan darah tinggi','Tekanan darah tinggi','Tekanan darah tinggi','Obesiti','Obesiti','Sakit jantung','Sakit jantung','Masalah buah pinggang','Asma','Arthritis','Kolesterol tinggi','Gastrik kronik','Migrain kronik','Insomnia'])[1+(i%18)] AS cond,
  (ARRAY['Selangor','Selangor','Selangor','Selangor','Selangor','Johor','Johor','Johor','Kuala Lumpur','Kuala Lumpur','Kuala Lumpur','Pulau Pinang','Pulau Pinang','Perak','Perak','Kedah','Melaka','Negeri Sembilan','Pahang','Terengganu'])[1+(i%20)] AS state,
  (ARRAY['Shah Alam','Klang','Petaling Jaya','Subang Jaya','Kajang','Johor Bahru','Batu Pahat','Muar','Cheras','Kepong','Setapak','George Town','Bayan Lepas','Ipoh','Taiping','Alor Setar','Ayer Keroh','Seremban','Kuantan','Kuala Terengganu'])[1+(i%20)] AS city,
  (ARRAY['ff6cdc4b-c417-40c1-b997-5a49df8783f6','b57bd4f8-ec6a-444e-9f4f-1f9e4af4b4c6','7054d0b4-2488-421f-913c-e3617a20c37e','a7f1ebb8-4e42-4ffe-9a28-0331bd9830ca','d1f91f58-2e13-434a-b2b9-d228dd6da4fe'])[1+(i%5)] AS pkg_id,
  (ARRAY['OBPX 1','VIP Premium','OBPY 1','EOL +','EOL'])[1+(i%5)] AS pkg_name,
  (ARRAY[40000,2999,52000,698,399])[1+(i%5)] AS pkg_price,
  (ARRAY[14,16,18,4,4])[1+(i%5)] AS dur,
  (ARRAY['349a4c79-2051-4b5b-93d9-369b8464aa3e','6c723b61-d010-4106-ba2f-800d7cd37c29','21c4417f-e212-400b-be82-9958456122f5','ce8a1971-04b7-44eb-a306-91a1c146cca8','1480f4da-ec36-475a-9b63-7551a794cd10'])[1+(i%5)]::uuid AS coach,
  (ARRAY['Aqilah','Coach Izzah','Coach Tasnim','Coach Fazirah','Admin Uweis'])[1+(i%5)] AS coach_name,
  (ARRAY['active','active','active','active','active','active','active','active','active','active','active','inactive','inactive','inactive','archived','deceased'])[1+(i%16)] AS status,
  (ARRAY['otw','otw','otw','otw','otw','otw','otw','otw','otw','otw','otw','completed','completed','completed','berhenti','meninggal'])[1+(i%16)] AS outcome,
  (5 + (i%170)) AS created_days
FROM generate_series(1,106) i;

INSERT INTO auth.users (id, email, created_at, updated_at)
SELECT prof, 'bulk'||i||'@example.com', now()-(created_days||' days')::interval, now() FROM _bulk
ON CONFLICT (id) DO NOTHING;

INSERT INTO psy_profiles (id, full_name, role, email, gender, is_active, created_at)
SELECT prof, name, 'patient', 'bulk'||i||'@example.com', (CASE WHEN gender='M' THEN 'lelaki' ELSE 'perempuan' END), true, now()-(created_days||' days')::interval
FROM _bulk
ON CONFLICT (id) DO UPDATE SET full_name=EXCLUDED.full_name, role='patient', gender=EXCLUDED.gender, is_active=true;

INSERT INTO psy_patients (
  id, user_id, mrn, full_name, date_of_birth, gender, state, city, home_address, address,
  medical_condition, status, outcome_status, outcome_status_at, kob_status,
  active_package_id, active_package_name, package_purchased_at, package_expires_at,
  coach_id, assigned_at, referral_source, created_by_staff, created_at
)
SELECT pid, prof, 'ISW-B-'||lpad(i::text,4,'0'), name, dob, gender, state, city, city||', '||state, city||', '||state,
  cond, status, outcome,
  CASE WHEN outcome IN ('completed','berhenti','meninggal') THEN now()-((created_days/3)||' days')::interval END,
  'package_paid', pkg_id, pkg_name,
  now()-(created_days||' days')::interval, now()-(created_days||' days')::interval + (dur||' weeks')::interval,
  coach, now()-(created_days||' days')::interval, 'Demo bulk', true, now()-(created_days||' days')::interval
FROM _bulk;

DELETE FROM psy_patients WHERE user_id IN (SELECT prof FROM _bulk) AND referral_source IS NULL;

INSERT INTO psy_treatment_plans (id, patient_id, doctor_id, name, duration_unit, duration_weeks, current_week, status, created_at)
SELECT plan, pid, '0cb188b0-f2e5-42d8-9071-81b331d88a59', pkg_name||' — Pelan Rawatan', 'weeks', dur,
  CASE WHEN status='active' THEN LEAST(1+(i%12), dur) WHEN outcome='completed' THEN dur ELSE 1+(i%3) END,
  CASE WHEN status='active' THEN 'active' WHEN outcome='completed' THEN 'completed' ELSE 'paused' END,
  now()-(created_days||' days')::interval
FROM _bulk;

INSERT INTO psy_plan_weekly_progress (plan_id, patient_id, week_number, status, score, session_date, updated_by_name, created_at)
SELECT b.plan, b.pid, LEAST(1+(b.i%12), b.dur),
  CASE WHEN (b.i%11=0) THEN 'booked' WHEN (b.i%3=0) THEN 'hadir' ELSE 'booked' END,
  CASE WHEN (b.i%3=0) THEN 6+(b.i%4) END,
  CASE WHEN (b.i%11=0) THEN date_trunc('day',now())+interval '9 hours'+((b.i%7)||' hours')::interval
       ELSE date_trunc('month',now())+((b.i%25)||' days')::interval+interval '10 hours' END,
  b.coach_name, now()
FROM _bulk b WHERE b.status='active';

INSERT INTO psy_payments (receipt_ref, patient_id, items, subtotal, service_charge, sst, total, payment_method, status, paid_at, created_at)
SELECT 'RCP-B-'||lpad(i::text,4,'0'), pid, jsonb_build_object('name','Pakej '||pkg_name), pkg_price, 0, 0, pkg_price,
  (ARRAY['transfer','card','fpx','manual'])[1+(i%4)], 'completed',
  now()-((i%55)||' days')::interval, now()-((i%55)||' days')::interval
FROM _bulk WHERE status IN ('active','inactive');

COMMIT;
