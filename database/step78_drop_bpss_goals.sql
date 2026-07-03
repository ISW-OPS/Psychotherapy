-- step78_drop_bpss_goals.sql
-- Buang matlamat BPS-S (Bio/Psycho/Social/Spiritual) sepenuhnya dari sistem.
-- Ciri ini tidak lagi dipapar/diedit di mana-mana UI (editor + paparan pesakit dibuang).
-- ⚠️  DESTRUKTIF & TAK BOLEH UNDO: kolum + data digugurkan. Jalankan di TESTING dahulu,
--     kemudian PROD (xmvqvq) secara manual selepas sahkan tiada isu.

ALTER TABLE psy_treatment_plans
  DROP COLUMN IF EXISTS bio_goals,
  DROP COLUMN IF EXISTS psycho_goals,
  DROP COLUMN IF EXISTS social_goals,
  DROP COLUMN IF EXISTS spiritual_goals;

ALTER TABLE psy_packages
  DROP COLUMN IF EXISTS bio_goals,
  DROP COLUMN IF EXISTS psycho_goals,
  DROP COLUMN IF EXISTS social_goals,
  DROP COLUMN IF EXISTS spiritual_goals;
