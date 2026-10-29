// Senarai unit ukuran piawai — guna konsisten merentas Products (item-form),
// Stock In dan pemberian bekalan kepada pesakit, supaya tiada percanggahan unit
// antara sistem (cth "botol" vs "bottle" vs "Botol").
// "Paket" dibuang 29 Okt 2026 — pertindihan dgn "Pek" (dua-dua terjemah "Pack"
// dlm EN, nampak sama dlm dropdown). Nilai "Paket" lama pada item sedia ada
// masih disuntik semula sbg option "(lama)" oleh item-form.html populateForm().
window.ISW_UNITS = [
  'Biji (pcs)', 'Botol', 'Kotak', 'Pek', 'Tiub', 'Tablet', 'Kapsul',
  'Set', 'Gulung', 'Beg', 'Pasang', 'Unit', 'Gram', 'Kg', 'Naskhah', 'Gelas',
  'Liter (L)', 'Mililiter (ml)', 'Inci (inch)', 'Sentimeter (cm)', 'Milimeter (mm)',
];
