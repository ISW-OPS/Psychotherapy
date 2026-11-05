// Senarai unit ukuran piawai — guna konsisten merentas Products (item-form),
// Stock In dan pemberian bekalan kepada pesakit, supaya tiada percanggahan unit
// antara sistem (cth "botol" vs "bottle" vs "Botol").
// "Paket" dibuang 29 Okt 2026 — pertindihan dgn "Pek" (dua-dua terjemah "Pack"
// dlm EN, nampak sama dlm dropdown). Nilai "Paket" lama pada item sedia ada
// masih disuntik semula sbg option "(lama)" oleh item-form.html populateForm().
//
// 5 Nov 2026 — diselaraskan ikut spec "Stock Unit" (Unit/Piece/Pack/Box/
// Bottle/Roll/Set/Pair/Bag/Carton/Kg/Gram/Liter/ml/Meter/cm/inch). Dibuang:
// Tiub/Tablet/Kapsul/Gelas/Milimeter (0 item guna — selamat). DIKEKALKAN
// Naskhah walau tiada dlm spec sbb 19 item sedia ada (bahan cetak) guna dia.
// Baharu: Karton (Carton), Meter (m).
window.ISW_UNITS = [
  'Pcs', 'Botol', 'Kotak', 'Pek', 'Set', 'Gulung', 'Beg', 'Karton', 'Pasang', 'Unit',
  'Gram', 'Kg', 'Naskhah',
  'Liter (L)', 'Mililiter (ml)', 'Meter (m)', 'Sentimeter (cm)', 'Inci (inch)',
];
