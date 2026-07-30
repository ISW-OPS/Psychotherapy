-- SEED DEMO — Dashboard Doktor (psy_kob_sessions + rujukan kepada doktor)
-- Tujuan: isi kad-kad dashboard doktor (Konsultasi KOB Hari Ini, Jadual Sesi,
-- Ringkasan KOB Bulan Ini, Reschedule/Batal Bulan Ini, Pakej Disyor Bulan Ini,
-- Rujukan Untuk Saya) dgn data sebenar utk uji, tanpa perlu isi borang KOB
-- satu-satu di kob-list.html.
-- Guna pesakit + pakej SEDIA ADA (tiada UUID hardcode). Idempotent (buang
-- rekod SEED lama dulu, semai semula) — boleh run berkali-kali. Boleh run di
-- TESTING sahaja.
-- Padam demo:
--   DELETE FROM psy_kob_sessions WHERE notes = 'SEED DEMO';
--   DELETE FROM psy_clinical_referrals WHERE referred_by_name = 'SEED DEMO';
-- ─────────────────────────────────────────────────────────────────────────

DELETE FROM psy_kob_sessions WHERE notes = 'SEED DEMO';
DELETE FROM psy_clinical_referrals WHERE referred_by_name = 'SEED DEMO';

DO $$
DECLARE
  pat_ids  UUID[];
  pkg_ids  TEXT[];
  pkg_nms  TEXT[];
  n_pat    INT;
  n_pkg    INT;
  doc      RECORD;
  p        UUID; -- helper
  k        UUID; -- helper pkg id
  nm       TEXT; -- helper pkg name
BEGIN
  SELECT array_agg(id) INTO pat_ids FROM (
    SELECT id FROM psy_patients WHERE status = 'active' ORDER BY created_at DESC LIMIT 6
  ) t;
  n_pat := COALESCE(array_length(pat_ids, 1), 0);
  IF n_pat = 0 THEN
    RAISE NOTICE 'Tiada pesakit aktif — seed doctor dashboard dibatalkan.';
    RETURN;
  END IF;

  SELECT array_agg(package_id), array_agg(name) INTO pkg_ids, pkg_nms FROM (
    SELECT package_id, name FROM psy_packages WHERE is_active = true ORDER BY name LIMIT 3
  ) t;
  n_pkg := COALESCE(array_length(pkg_ids, 1), 0);

  -- 1) HARI INI — satu booked (petang), satu hadir (belum syor pakej)
  INSERT INTO psy_kob_sessions (patient_id, scheduled_at, mode, status, notes) VALUES
    (pat_ids[((1-1) % n_pat) + 1], (CURRENT_DATE + TIME '15:00')::timestamptz, 'f2f',    'booked', 'SEED DEMO'),
    (pat_ids[((2-1) % n_pat) + 1], (CURRENT_DATE + TIME '10:00')::timestamptz, 'online', 'hadir',  'SEED DEMO');

  -- 2) SELESAI + PAKEJ DISYOR bulan ini (utk Ringkasan + donut Pakej Disyor)
  IF n_pkg > 0 THEN
    INSERT INTO psy_kob_sessions (patient_id, scheduled_at, mode, status, notes, recommended_package_id, recommended_package_name, recommended_at) VALUES
      (pat_ids[((3-1) % n_pat) + 1], (date_trunc('month', CURRENT_DATE) + interval '3 days' + TIME '09:00')::timestamptz, 'f2f',    'completed', 'SEED DEMO', pkg_ids[((1-1) % n_pkg) + 1], pkg_nms[((1-1) % n_pkg) + 1], now()),
      (pat_ids[((4-1) % n_pat) + 1], (date_trunc('month', CURRENT_DATE) + interval '5 days' + TIME '11:00')::timestamptz, 'f2f',    'completed', 'SEED DEMO', pkg_ids[((2-1) % n_pkg) + 1], pkg_nms[((2-1) % n_pkg) + 1], now()),
      (pat_ids[((5-1) % n_pat) + 1], (date_trunc('month', CURRENT_DATE) + interval '7 days' + TIME '14:00')::timestamptz, 'online', 'completed', 'SEED DEMO', pkg_ids[((1-1) % n_pkg) + 1], pkg_nms[((1-1) % n_pkg) + 1], now());
  END IF;

  -- 3) RESCHEDULE + BATAL bulan ini (utk kad Reschedule/Batal)
  INSERT INTO psy_kob_sessions (patient_id, scheduled_at, mode, status, notes, reschedule_reason) VALUES
    (pat_ids[((6-1) % n_pat) + 1], (date_trunc('month', CURRENT_DATE) + interval '9 days'  + TIME '10:00')::timestamptz, 'f2f', 'reschedule', 'SEED DEMO', 'Pesakit tak dapat hadir'),
    (pat_ids[((2-1) % n_pat) + 1], (date_trunc('month', CURRENT_DATE) + interval '11 days' + TIME '10:00')::timestamptz, 'f2f', 'cancelled',  'SEED DEMO', NULL);

  -- 4) AKAN DATANG bulan ini (utk titik kalendar)
  INSERT INTO psy_kob_sessions (patient_id, scheduled_at, mode, status, notes) VALUES
    (pat_ids[((3-1) % n_pat) + 1], (CURRENT_DATE + interval '3 days' + TIME '11:00')::timestamptz, 'f2f',    'booked', 'SEED DEMO'),
    (pat_ids[((4-1) % n_pat) + 1], (CURRENT_DATE + interval '6 days' + TIME '14:00')::timestamptz, 'online', 'booked', 'SEED DEMO');

  -- 5) RUJUKAN UNTUK SAYA — satu rekod untuk SETIAP doktor sedia ada
  FOR doc IN (SELECT id, full_name FROM psy_profiles WHERE role = 'staff' AND staff_role = 'doctor') LOOP
    INSERT INTO psy_clinical_referrals (
      patient_id, referred_by_name, target_role, target_id, target_name,
      reason, meet_date, priority, status, source
    ) VALUES (
      pat_ids[((1-1) % n_pat) + 1], 'SEED DEMO', 'doctor', doc.id, doc.full_name,
      'Perlu ulasan doktor — simptom tak lazim', CURRENT_DATE, 'tinggi', 'pending', 'manual'
    );
  END LOOP;
END $$;
