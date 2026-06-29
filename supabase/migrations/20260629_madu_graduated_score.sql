-- ============================================================
-- 20260629_madu_graduated_score.sql
-- Madu (jenis 'kiraan') — mata bertingkat + pilihan "Tidak minum".
--
-- Sebelum: 2x=1, 3x/4x/5x=2, Other=1, TIADA pilihan 0.
--   → minimum terpaksa 1 mata (tak boleh rekod langsung tak minum),
--     dan 5x tak dibeza dengan 3x.
-- Selepas: Tidak=0, 2x=1, 3x=2, 4x=3, 5x=4, Lebih 5x=4 (maks 4 mata/item).
--
-- NOTA: maks mata madu kini 4 (bukan 2) → madu jadi 2x lebih berat.
--   Logik skor JS (computeSkor / itemPct) telah dikemas kini supaya
--   pembahagi ikut mata maksimum sebenar setiap item, bukan tetap 2.
--   Skor harian LAMA (psy_kepatuhan_log.skor_harian) tidak ditulis semula;
--   hanya catatan baru guna skala baharu.
-- ============================================================

UPDATE psy_kepatuhan_item
SET options = '[{"value":"tidak","label":"Tidak minum","mata":0},{"value":"2","label":"2x","mata":1},{"value":"3","label":"3x","mata":2},{"value":"4","label":"4x","mata":3},{"value":"5","label":"5x","mata":4},{"value":"other","label":"Lebih 5x","mata":4}]'::jsonb
WHERE item_key IN ('madu_lth_ib','madu_lthpg_yhpg');

SELECT 'OK — madu graduated score applied'   AS status,
       count(*)                               AS items_updated
FROM psy_kepatuhan_item
WHERE item_key IN ('madu_lth_ib','madu_lthpg_yhpg');
