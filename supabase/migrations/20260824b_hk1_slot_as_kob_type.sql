-- Rombak semula: Slot Sesi 1:1 (Hakeema/Hakeem/Dr) guna model SAMA macam Slot KOB/Rawatan
-- (jadual baris-per-blok + hari ON/OFF), bukan model generator pagi/petang+tempoh — user
-- rasa model generator tu mengelirukan ("apa maksud pagi mula pagi akhir ni susah la").
-- Buang jadual singleton psy_hk1_slot_config (baru RUN sekali, tak sempat dipakai sesiapa),
-- tambah 'sesi_1on1' sbg slot_type ketiga pada psy_kob_slot_config sedia ada (reuse penuh
-- UI+logik "+ Tambah Slot"/toggle ON-OFF/edit/padam kob-slots.html — cuma parameterized ikut
-- type, tiada perubahan besar diperlukan pada jadual/RLS sedia ada).

DROP TABLE IF EXISTS psy_hk1_slot_config;

ALTER TABLE psy_kob_slot_config DROP CONSTRAINT IF EXISTS psy_kob_slot_config_slot_type_check;
ALTER TABLE psy_kob_slot_config ADD CONSTRAINT psy_kob_slot_config_slot_type_check
  CHECK (slot_type IN ('kob', 'rawatan', 'sesi_1on1'));

-- Seed lalai — 2 blok (pagi/petang) x hari Rabu-Ahad, sama pattern KOB/Rawatan.
INSERT INTO psy_kob_slot_config (slot_type, day_of_week, slot_start, slot_end, label, sort_order, is_active)
SELECT
  'sesi_1on1',
  d.day_of_week,
  s.slot_start::time,
  s.slot_end::time,
  s.label,
  s.sort_order,
  true
FROM
  (VALUES (3), (4), (5), (6), (0)) AS d(day_of_week),
  (VALUES
    ('09:00', '12:00', '9-12 pg',  1),
    ('14:00', '17:00', '2-5 ptg',  2)
  ) AS s(slot_start, slot_end, label, sort_order)
ON CONFLICT ON CONSTRAINT psy_kob_slot_config_unique DO NOTHING;
