-- ============================================================
-- 20260629_kepatuhan_week1_basic_set.sql
-- Week 1 checklist = set asas GForm biasa (5 item) buat masa ini.
--
-- Aktif: madu LTH/IB, madu LTHPG/YHPG, zikir bersanad, pantang makan,
--        reaksi pemulihan (multi-pilih, tracking sahaja).
-- Dinyahaktif buat sementara: pernafasan fitrah, terapi bumi, berjemur,
--        air kelapa, yogurt — akan diaktifkan balik bila set penuh diguna.
--
-- NOTA UI: bahagian Daily Check-in (mood/perasaan, reaksi severity,
--   tidur, aktiviti) disembunyi di roles/patient/kepatuhan.html
--   (flag SHOW_CHECKIN=false). Pesakit isi 5 item checklist sahaja.
-- ============================================================

UPDATE psy_kepatuhan_item SET aktif = false
  WHERE item_key IN ('pernafasan_fitrah','terapi_bumi','berjemur','air_kelapa','yogurt');

UPDATE psy_kepatuhan_item SET aktif = true,  urutan = 5 WHERE item_key = 'reaksi_pemulihan';
UPDATE psy_kepatuhan_item SET urutan = 3 WHERE item_key = 'zikir_bersanad';
UPDATE psy_kepatuhan_item SET urutan = 4 WHERE item_key = 'pantang_makan';

SELECT urutan, item_key, label, berskor, aktif
FROM psy_kepatuhan_item
WHERE fasa = 'week1' AND aktif = true
ORDER BY urutan;
