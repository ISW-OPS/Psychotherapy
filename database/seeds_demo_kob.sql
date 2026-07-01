-- ============================================================
-- seeds_demo_kob.sql — Seed sesi KOB demo (TESTING sahaja)
-- Sasaran: ISW Data Centre / ipmemyizigwgivccytcu
-- Lengkapkan kob-list.html / kob-detail.html dgn data utk pembentangan:
--   4 booked (hari ini + akan datang) · 2 hadir (sedang berlangsung) · 3 completed (+ cadangan pakej)
-- Re-runnable: buang seed lama (id a0b00000... / notes [demo-seed]) dahulu.
-- Mode mesti 'f2f'|'online' · status booked|hadir|completed|reschedule|cancelled
-- package_payment_status pending|paid|skipped|na
-- ============================================================

DELETE FROM psy_kob_sessions WHERE notes LIKE '%[demo-seed]%' OR id::text LIKE 'a0b00000%';

WITH doc AS (
  SELECT (SELECT id FROM psy_profiles WHERE email='nornajihah@ibnusinawellness.com') AS dr1_id,
         'DR Nornajihah'::text AS dr1_name
),
pick AS (
  SELECT id AS patient_id,
         row_number() OVER (ORDER BY (active_package_id IS NULL) DESC, created_at DESC) AS rn
  FROM psy_patients LIMIT 9
)
INSERT INTO psy_kob_sessions
  (id, patient_id, scheduled_at, mode, meet_link, status,
   doctor_hadir_id, doctor_hadir_name, hadir_at,
   doctor_selesai_id, doctor_selesai_name, selesai_at,
   notes, reschedule_count,
   recommended_package_id, recommended_package_name, recommended_package_price, recommended_at, recommended_by, recommended_by_name,
   package_payment_status, created_at)
SELECT
  ('a0b00000-0000-4000-8000-00000000000'||p.rn)::uuid, p.patient_id,
  CASE p.rn
    WHEN 1 THEN date_trunc('day',now())+interval '10 hours' WHEN 2 THEN date_trunc('day',now())+interval '14 hours'
    WHEN 3 THEN now()+interval '2 days'+interval '11 hours' WHEN 4 THEN now()+interval '5 days'+interval '15 hours'
    WHEN 5 THEN date_trunc('day',now())+interval '9 hours' WHEN 6 THEN now()-interval '1 day'+interval '10 hours'
    WHEN 7 THEN now()-interval '3 days'+interval '11 hours' WHEN 8 THEN now()-interval '10 days'+interval '14 hours'
    ELSE now()-interval '20 days'+interval '10 hours' END,
  CASE WHEN p.rn % 2 = 0 THEN 'f2f' ELSE 'online' END,
  CASE WHEN p.rn % 2 = 1 THEN 'https://meet.google.com/demo-isw-kob' END,
  CASE WHEN p.rn IN (1,2,3,4) THEN 'booked' WHEN p.rn IN (5,6) THEN 'hadir' ELSE 'completed' END,
  CASE WHEN p.rn IN (5,6,7,8,9) THEN d.dr1_id END, CASE WHEN p.rn IN (5,6,7,8,9) THEN d.dr1_name END,
  CASE WHEN p.rn=5 THEN now()-interval '20 minutes' WHEN p.rn=6 THEN now()-interval '1 day'+interval '10 hours'
       WHEN p.rn IN (7,8,9) THEN (CASE p.rn WHEN 7 THEN now()-interval '3 days' WHEN 8 THEN now()-interval '10 days' ELSE now()-interval '20 days' END)+interval '10 hours' END,
  CASE WHEN p.rn IN (7,8,9) THEN d.dr1_id END, CASE WHEN p.rn IN (7,8,9) THEN d.dr1_name END,
  CASE WHEN p.rn=7 THEN now()-interval '3 days'+interval '12 hours' WHEN p.rn=8 THEN now()-interval '10 days'+interval '15 hours' WHEN p.rn=9 THEN now()-interval '20 days'+interval '11 hours' END,
  '[demo-seed] Sesi KOB demo untuk pembentangan', 0,
  CASE WHEN p.rn=7 THEN 'ff6cdc4b-c417-40c1-b997-5a49df8783f6' WHEN p.rn=9 THEN 'b57bd4f8-ec6a-444e-9f4f-1f9e4af4b4c6' END,
  CASE WHEN p.rn=7 THEN 'OBPX 1' WHEN p.rn=9 THEN 'VIP Premium' END,
  CASE WHEN p.rn=7 THEN 40000 WHEN p.rn=9 THEN 2999 END,
  CASE WHEN p.rn IN (7,9) THEN (CASE p.rn WHEN 7 THEN now()-interval '3 days' ELSE now()-interval '20 days' END)+interval '12 hours' END,
  CASE WHEN p.rn IN (7,9) THEN d.dr1_id END, CASE WHEN p.rn IN (7,9) THEN d.dr1_name END,
  CASE WHEN p.rn=7 THEN 'paid' WHEN p.rn=8 THEN 'skipped' END,
  now()-interval '25 days'
FROM pick p CROSS JOIN doc d;

-- Semakan
SELECT status, count(*) AS bil, string_agg(DISTINCT mode,'/') AS modes
FROM psy_kob_sessions GROUP BY status ORDER BY status;
