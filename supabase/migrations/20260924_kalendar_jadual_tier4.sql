-- Audit management 23 Sept 2026, Tier 4 batch 2 item IV (Kalendar & Jadual /
-- Pelan Mingguan #17, #27, #28, #30, #47) — hanya #47 (kapasiti slot) perlukan
-- migration; #17/#27/#28/#30 semuanya guna kod + enum status sedia ada.
-- Rujuk: database/schema/09_kob.sql

ALTER TABLE psy_kob_slot_config ADD COLUMN IF NOT EXISTS max_bookings INT;
