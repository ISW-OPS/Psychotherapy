-- Treatment plan "auto fallback" 1 sesi/minggu: hari alternatif (getDay() JS)
-- yang dicuba bila hari utama (preferred_days[0]) tutup. Dibaca oleh
-- computeChainedDateSafe() di plan-week.html. Lihat schema/07_treatment_plans.sql.
ALTER TABLE psy_treatment_plans ADD COLUMN IF NOT EXISTS schedule_auto_alt_day INT;

COMMENT ON COLUMN psy_treatment_plans.schedule_auto_alt_day IS
  'NULL = hari tetap biasa (preferred_days ikut betul-betul). Diisi (getDay() JS) bila plan disetup
   guna mod "auto fallback" 1 sesi/minggu (staff punya "Setup Jadual Rawatan", pakej tiada Pilihan
   Hari Sesi disetkan) — preferred_days[0] = hari UTAMA (cth Jumaat), lajur ni = hari ALTERNATIF
   (cth Sabtu) yang dicuba kalau hari utama tutup. Dibaca oleh computeChainedDateSafe() di
   plan-week.html supaya cascadeBookFutureWeeks() elak book atas hari yang tutup untuk plan jenis ni.';
