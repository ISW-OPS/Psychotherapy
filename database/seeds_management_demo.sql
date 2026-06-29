-- ============================================================
-- seeds_management_demo.sql
-- Data demo untuk DASHBOARD MANAGER (roles/staff/dashboard.html → manager-view).
-- Mengisi blok yang biasanya kosong di env testing supaya dashboard kelihatan
-- lengkap: Pesakit Tamat, KYC pending, Risk Alerts, Adherence, Feedback negatif, Isu.
--
-- SELAMAT DIJALANKAN SEMULA (idempotent): setiap kategori dipadam dahulu
-- berdasarkan penanda demo ([SEED] / SEED_DEMO / meta.seed='demo') sebelum
-- diisi semula. TIDAK menyentuh data sebenar.
--
-- Sasaran: projek TESTING (ISW Data Centre / ipmemyizigwgivccytcu).
-- JANGAN jalankan di PROD.
-- ============================================================

BEGIN;

-- ── 0. Bersih baris demo lama (re-runnable) ────────────────────────────────
DELETE FROM psy_kyc_submissions  WHERE review_notes = 'SEED_DEMO';
DELETE FROM psy_risk_alerts       WHERE description LIKE '%[SEED]%';
DELETE FROM psy_adherence_alerts  WHERE details->>'seed' = 'demo';
DELETE FROM psy_feedback          WHERE comment LIKE '%[SEED]%';
DELETE FROM psy_audit_log         WHERE action IN ('issue.reported','issue.closed') AND meta->>'seed' = 'demo';
UPDATE psy_patients SET outcome_status = NULL, outcome_status_at = NULL, outcome_status_notes = NULL
  WHERE outcome_status_notes = 'SEED_DEMO';

-- ── Senarai pesakit aktif bernombor (untuk pautan FK) ──────────────────────
-- rn 1-3 → risk, 4-5 → adherence, 6-8 → feedback
CREATE TEMP TABLE _seed_pts ON COMMIT DROP AS
SELECT p.id,
       COALESCE(pr.full_name, p.mrn) AS pname,
       row_number() OVER (ORDER BY p.created_at) AS rn
FROM psy_patients p
LEFT JOIN psy_profiles pr ON pr.id = p.user_id
WHERE p.status = 'active';

-- ── 1. Pesakit Tamat (outcome_status = completed) ──────────────────────────
UPDATE psy_patients
SET outcome_status = 'completed', outcome_status_at = now(), outcome_status_notes = 'SEED_DEMO'
WHERE id IN (
  SELECT id FROM psy_patients
  WHERE status <> 'active' AND (outcome_status IS NULL OR outcome_status <> 'completed')
  ORDER BY created_at LIMIT 3
);

-- ── 2. KYC pending (perlu kelulusan manager) ───────────────────────────────
INSERT INTO psy_kyc_submissions (patient_name, ic_number, phone, medical_condition, status, review_notes, created_at)
VALUES
  ('Nurul Aina binti Rahman',  '990201-10-5566', '0123456789', 'Sakit lutut kronik',      'pending', 'SEED_DEMO', now() - interval '6 hours'),
  ('Ahmad Firdaus bin Salleh', '880512-14-3321', '0198765432', 'Tekanan darah tinggi',     'pending', 'SEED_DEMO', now() - interval '1 day 4 hours'),
  ('Tan Mei Ling',             '010707-08-1122', '0167788990', 'Sakit belakang berpanjangan','pending', 'SEED_DEMO', now() - interval '3 days');

-- ── 3. Risk Alerts (open, high/critical) ───────────────────────────────────
INSERT INTO psy_risk_alerts (patient_id, patient_name, severity, category, description, status, created_by_name)
SELECT s.id, s.pname, v.sev, v.cat, v.descr || ' [SEED]', 'open', 'Sistem (Demo)'
FROM _seed_pts s
JOIN (VALUES
  (1, 'critical', 'Kesihatan',  'Pesakit lapor sakit dada berterusan — perlu rujukan segera'),
  (2, 'high',     'Kepatuhan',  'Tiga sesi berturut-turut tidak hadir tanpa notis'),
  (3, 'high',     'Emosi',      'Pesakit nampak tertekan & sebut mahu berhenti rawatan')
) v(rn, sev, cat, descr) ON s.rn = v.rn;

-- ── 4. Adherence Alerts (belum diakui) ─────────────────────────────────────
INSERT INTO psy_adherence_alerts (patient_id, alert_type, trigger_date, details)
SELECT s.id, 'madu_low_5days', current_date,
       jsonb_build_object('seed','demo','target',3,'days_below',5)
FROM _seed_pts s
WHERE s.rn IN (4, 5);

-- ── 5. Feedback negatif (≤2★, 30 hari) ─────────────────────────────────────
INSERT INTO psy_feedback (patient_id, patient_name, rating, comment, feedback_type, created_at)
SELECT s.id, s.pname, v.rating, v.comment || ' [SEED]', 'overall', now() - (v.days_ago || ' days')::interval
FROM _seed_pts s
JOIN (VALUES
  (6, 1, 'Khidmat lambat & staf kurang mesra',          2),
  (7, 2, 'Produk tak sampai ikut masa dijanji',          7),
  (8, 2, 'Sesi kerap ditangguh tanpa notis awal',        12)
) v(rn, rating, comment, days_ago) ON s.rn = v.rn;

-- ── 6. Isu dilaporkan (terbuka — tiada issue.closed sepadan) ───────────────
INSERT INTO psy_audit_log (actor_name, actor_role, action, target, meta, created_at)
VALUES
  ('Coach Aqilah', 'staff', 'issue.reported', 'Sistem tempahan slot tergantung bila pilih tarikh',
     jsonb_build_object('seed','demo','issue_id', gen_random_uuid()), now() - interval '2 days'),
  ('Coach Izzah',  'staff', 'issue.reported', 'Pesakit tak terima notifikasi WhatsApp peringatan',
     jsonb_build_object('seed','demo','issue_id', gen_random_uuid()), now() - interval '20 hours');

COMMIT;

-- ── Semakan ────────────────────────────────────────────────────────────────
SELECT
  (SELECT count(*) FROM psy_patients WHERE outcome_status='completed')                       AS completed,
  (SELECT count(*) FROM psy_kyc_submissions WHERE status='pending')                          AS kyc_pending,
  (SELECT count(*) FROM psy_inventory_requests WHERE status='pending_approval')              AS inv_pending,
  (SELECT count(*) FROM psy_risk_alerts WHERE status='open')                                 AS risk_open,
  (SELECT count(*) FROM psy_adherence_alerts WHERE acknowledged_at IS NULL)                  AS adherence_unack,
  (SELECT count(*) FROM psy_feedback WHERE rating<=2 AND created_at >= now()-interval '30 days') AS neg_feedback,
  (SELECT count(*) FROM psy_audit_log WHERE action='issue.reported')                         AS issues_open;
