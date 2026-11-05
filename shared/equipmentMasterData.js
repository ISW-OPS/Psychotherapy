// Senarai piawai Equipment Category & Storage Location — guna konsisten
// merentas equipment-add.html (borang) supaya tiada percanggahan label.
// equipment-list.html punya filter Category baca terus dari data sedia ada
// (DISTINCT), bukan senarai ni — jadi senarai ni auto diikuti bila item baharu
// didaftar guna kategori baharu.
window.ISW_EQUIPMENT_CATEGORIES = [
  'Clinical Equipment', 'General Equipment', 'Event Equipment', 'Office Equipment', 'Other Equipment',
];

window.ISW_EQUIPMENT_LOCATIONS = [
  'Clinical Store', 'General Store', 'Consultation Room', 'Event Store', 'Other Location',
];
