-- Minum Madu (LTH/IB & LTHPG/YHPG) — betulkan skala pilihan.
-- Keputusan user 21 Jul 2026: tambah "1x" (dulu tiada, jurang antara
-- "Tidak minum" dan "2x"), buang bucket "Lebih 5x"/Lain-lain, markah
-- kini linear ikut kekerapan — makin banyak sudu, markah makin tinggi.
-- tidak=0, 1x=1, 2x=2, 3x=3, 4x=4, 5x=5 (max naik dari 4 mata -> 5 mata/item).

UPDATE psy_kepatuhan_item
SET options = '[{"value":"tidak","label":"Tidak minum","mata":0},{"value":"1","label":"1x","mata":1},{"value":"2","label":"2x","mata":2},{"value":"3","label":"3x","mata":3},{"value":"4","label":"4x","mata":4},{"value":"5","label":"5x","mata":5}]',
    updated_at = now()
WHERE fasa = 'week1' AND item_key IN ('madu_lth_ib', 'madu_lthpg_yhpg');
