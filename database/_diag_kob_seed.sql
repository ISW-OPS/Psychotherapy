-- Diagnostik: kenapa "SEED DEMO" psy_kob_sessions tak keluar di dashboard doktor
SELECT id, patient_id, scheduled_at, status, mode, recommended_package_name, notes
FROM psy_kob_sessions
WHERE notes = 'SEED DEMO'
ORDER BY scheduled_at;

-- Bandingkan dengan tarikh/jam SEKARANG ikut pandangan Postgres
SELECT now() AS db_now, current_date AS db_today;
