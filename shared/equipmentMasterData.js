// Senarai piawai Equipment Category & Storage Location — guna konsisten
// merentas equipment-add.html (borang) supaya tiada percanggahan label.
// equipment-list.html punya filter Category baca terus dari data sedia ada
// (DISTINCT), bukan senarai ni — jadi senarai ni auto diikuti bila item baharu
// didaftar guna kategori baharu.
window.ISW_EQUIPMENT_CATEGORIES = [
  'Clinical Equipment', 'Treatment Equipment', 'Therapy Equipment', 'Diagnostic Equipment',
  'Monitoring Equipment', 'Medical Support Equipment', 'General Equipment', 'Office Equipment',
  'IT Equipment', 'Electrical Equipment', 'Furniture & Fixtures', 'Cleaning Equipment',
  'Safety Equipment', 'Event Equipment', 'Audio Visual Equipment', 'Kitchen Equipment',
  'Storage Equipment', 'Other Equipment',
];

window.ISW_EQUIPMENT_LOCATIONS = [
  'Reception Area', 'Consultation Room', 'Treatment Room', 'Therapy Room', 'Clinical Room',
  'Patient Area', 'Waiting Area', 'Office', 'Admin Room', 'Manager Room', 'Meeting Room',
  'IT Room', 'Training Room', 'Coaching Room', 'Kitchen / Pantry', 'Staff Room',
  'General Store', 'Equipment Store', 'Clinical Store', 'Event Store', 'Maintenance Room',
  'Outdoor Area', 'Other Location',
];
