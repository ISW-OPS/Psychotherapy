-- Kepatuhan checklist — kembalikan set PENUH (11 item) + Terapi Kolon baharu.
-- Keputusan user 21 Jul 2026: abaikan pecahan ikut fasa/minggu — cukup
-- lengkapkan 'week1' sebab roles/patient/kepatuhan.html carry-forward
-- item week1 utk semua fasa lain bila fasa semasa tiada item sendiri.
--
-- Aktifkan balik: pernafasan_fitrah, terapi_bumi, berjemur, air_kelapa, yogurt
-- Tambah baharu: terapi_kolon
-- Susun semula urutan ikut checklist manual (LTH, LTHPG, Pernafasan Fitrah,
-- Zikir Bersanad, Terapi Bumi, Berjemur, Air Kelapa, Yogurt, Pantang Makan,
-- Terapi Kolon, Reaksi Pemulihan)

UPDATE psy_kepatuhan_item SET aktif = true, urutan = 3 WHERE fasa='week1' AND item_key='pernafasan_fitrah';
UPDATE psy_kepatuhan_item SET urutan = 4 WHERE fasa='week1' AND item_key='zikir_bersanad';
UPDATE psy_kepatuhan_item SET aktif = true, urutan = 5 WHERE fasa='week1' AND item_key='terapi_bumi';
UPDATE psy_kepatuhan_item SET aktif = true, urutan = 6 WHERE fasa='week1' AND item_key='berjemur';
UPDATE psy_kepatuhan_item SET aktif = true, urutan = 7 WHERE fasa='week1' AND item_key='air_kelapa';
UPDATE psy_kepatuhan_item SET aktif = true, urutan = 8 WHERE fasa='week1' AND item_key='yogurt';
UPDATE psy_kepatuhan_item SET urutan = 9 WHERE fasa='week1' AND item_key='pantang_makan';
UPDATE psy_kepatuhan_item SET urutan = 11 WHERE fasa='week1' AND item_key='reaksi_pemulihan';

INSERT INTO psy_kepatuhan_item (fasa, item_key, label, nota, jenis_input, period, options, meta, berskor, urutan, aktif)
VALUES (
  'week1','terapi_kolon','Terapi Kolon',NULL,'pilih_satu','harian',
  '[{"value":"buat","label":"Buat","mata":2},{"value":"tidak","label":"Tidak buat","mata":0}]',
  '{}', true, 10, true
)
ON CONFLICT (fasa, item_key) DO UPDATE SET
  label       = EXCLUDED.label,
  jenis_input = EXCLUDED.jenis_input,
  period      = EXCLUDED.period,
  options     = EXCLUDED.options,
  meta        = EXCLUDED.meta,
  berskor     = EXCLUDED.berskor,
  urutan      = EXCLUDED.urutan,
  aktif       = EXCLUDED.aktif,
  updated_at  = now();
