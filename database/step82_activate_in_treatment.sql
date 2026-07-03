-- step82_activate_in_treatment.sql
-- Set pesakit 'unregistered' (Belum Aktif) yang SEDANG DALAM RAWATAN (ada pakej aktif
-- belum tamat) → status 'active'. Penanda akaun kekal ikut user_id (badge "Belum Aktif"
-- sebelah nama) — jadi ubah status TAK jejas signup/claim akaun by IC.
-- Jalankan di TESTING dahulu, kemudian PRODUCTION (xmvqvq).

-- Semak dulu (berapa akan terjejas):
-- SELECT count(*) FROM psy_patients
--   WHERE status = 'unregistered' AND active_package_id IS NOT NULL
--     AND (package_expires_at IS NULL OR package_expires_at >= now());

UPDATE psy_patients
SET status = 'active'
WHERE status = 'unregistered'
  AND active_package_id IS NOT NULL
  AND (package_expires_at IS NULL OR package_expires_at >= now());

SELECT 'OK — pesakit dalam rawatan (unregistered) ditukar ke active' AS status;
