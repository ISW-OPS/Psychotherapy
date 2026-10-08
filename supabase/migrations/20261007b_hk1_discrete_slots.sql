-- Jadual Slot Sesi 1:1 redesign (7 Okt 2026, ikut mockup "Jadual Slot Konsultasi") — blok
-- ("9-12 pg") kini boleh auto-pecah jadi slot diskret individu (2:00-2:30, 2:30-3:00, ...),
-- setiap satu = SATU janji temu, bukan sekadar kaunter kapasiti global. Rujuk database/schema/09_kob.sql.
-- Idempoten — selamat dijalankan berulang kali.

ALTER TABLE psy_kob_slot_config ADD COLUMN IF NOT EXISTS slot_duration_minutes INT;

COMMENT ON COLUMN psy_kob_slot_config.slot_duration_minutes IS
  'Tempoh seorang pesakit (minit) dlm blok ni — dipakai slot_type=sesi_1on1 sahaja utk auto-jana slot diskret (slot_start + i*duration, i=0..max_bookings-1). NULL = mod lama (blok utuh, max_bookings jadi kaunter kapasiti sahaja, tiada slot diskret). kob/rawatan tak guna medan ni.';
