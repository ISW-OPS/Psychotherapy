-- ============================================================
-- Seed Malaysia 2026 federal public holidays + Hari Raya for clinic closure.
-- State-specific holidays not included — add manually if relevant to clinic location.
-- Verify Islamic-calendar dates against official gazette before relying on.
-- ============================================================

INSERT INTO psy_clinic_closures (closure_date, label, category, is_recurring) VALUES
  ('2026-01-01', 'Tahun Baru',                       'public_holiday', false),
  ('2026-01-29', 'Israk dan Mikraj',                 'public_holiday', false),
  ('2026-02-01', 'Hari Wilayah Persekutuan',         'public_holiday', false),
  ('2026-02-17', 'Tahun Baru Cina',                  'public_holiday', false),
  ('2026-02-18', 'Tahun Baru Cina (Hari Kedua)',     'public_holiday', false),
  ('2026-02-19', 'Awal Ramadan',                     'public_holiday', false),
  ('2026-03-20', 'Hari Raya Aidilfitri',             'hari_raya',      false),
  ('2026-03-21', 'Hari Raya Aidilfitri (Hari Kedua) / Nuzul Al-Quran', 'hari_raya', false),
  ('2026-05-01', 'Hari Pekerja / Hari Wesak',        'public_holiday', false),
  ('2026-05-27', 'Hari Raya Aidiladha',              'hari_raya',      false),
  ('2026-06-01', 'Hari Keputeraan Yang di-Pertuan Agong', 'public_holiday', false),
  ('2026-06-17', 'Awal Muharram (Maal Hijrah)',      'public_holiday', false),
  ('2026-08-25', 'Hari Kebangsaan',                  'public_holiday', false),
  ('2026-08-26', 'Maulidur Rasul',                   'public_holiday', false),
  ('2026-09-16', 'Hari Malaysia',                    'public_holiday', false),
  ('2026-11-08', 'Deepavali',                        'public_holiday', false),
  ('2026-12-25', 'Hari Krismas',                     'public_holiday', false)
ON CONFLICT (closure_date) DO NOTHING;
