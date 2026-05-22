-- ============================================================
-- SEED: psy_coaching_catalog — Bimbingan items dari Syafa Checklist
-- Source: docs/Syafa_Checklist_Audit (OVERHAUL BODY + NEW LIFE CHALLENGE)
-- Dedupe: item yang sama merentas pakej hanya 1 row
-- ============================================================

INSERT INTO psy_coaching_catalog (name, type, category, sort_order, is_active)
VALUES
  -- Peminuman & Nutrisi
  ('Bimbingan Peminuman LTH, LTHPG @ IB, YHPG',                                 'bimbingan', 'Peminuman & Nutrisi',   10, true),
  ('Bimbingan Peminuman IB',                                                    'bimbingan', 'Peminuman & Nutrisi',   11, true),
  ('Bimbingan Diet dan Nutrisi',                                                'bimbingan', 'Peminuman & Nutrisi',   12, true),
  ('Bimbingan Diet Vegan',                                                      'bimbingan', 'Peminuman & Nutrisi',   13, true),
  ('Bimbingan Kepentingan Madu Asli dan Kombinasi Herba untuk sokongan Jasad',  'bimbingan', 'Peminuman & Nutrisi',   14, true),
  ('Bimbingan Khasiat Bawang Putih',                                            'bimbingan', 'Peminuman & Nutrisi',   15, true),
  ('Bimbingan Kebaikan Minyak Kelapa Dara',                                     'bimbingan', 'Peminuman & Nutrisi',   16, true),
  ('Bimbingan Kebaikan Air Kelapa',                                             'bimbingan', 'Peminuman & Nutrisi',   17, true),

  -- Rohani
  ('Bimbingan Zikir bersanad',                                                  'bimbingan', 'Rohani',                20, true),
  ('Bimbingan Kepentingan Bersedekah dan Overhaul Body',                        'bimbingan', 'Rohani',                21, true),

  -- Herba & Terapi
  ('Bimbingan Herba Thoharah',                                                  'bimbingan', 'Herba & Terapi',        30, true),
  ('Bimbingan Air Afiyah, Air Za''afaran, Penyucian Aura',                      'bimbingan', 'Herba & Terapi',        31, true),
  ('Bimbingan Terapi Kolon',                                                    'bimbingan', 'Herba & Terapi',        32, true),

  -- Reaksi & Pemulihan
  ('Bimbingan Reaksi Pemulihan',                                                'bimbingan', 'Reaksi & Pemulihan',    40, true),
  ('Bimbingan Manual Reaksi Pemulihan (Healing Crisis)',                        'bimbingan', 'Reaksi & Pemulihan',    41, true),
  ('Bimbingan Hapuskan Longgokan Toksin dan Rasai Perubahan Kesihatan',         'bimbingan', 'Reaksi & Pemulihan',    42, true),
  ('Bimbingan Kepentingan On Healing Machine dan Hormon Bahagia',               'bimbingan', 'Reaksi & Pemulihan',    43, true),

  -- Mikrobiota & Perut
  ('Bimbingan Kepentingan Prebiotik dan Probiotik kepada pemulihan perut',      'bimbingan', 'Mikrobiota & Perut',    50, true),
  ('Bimbingan tentang Prebiotik dan Probiotik',                                 'bimbingan', 'Mikrobiota & Perut',    51, true),
  ('Bimbingan Bakteria perut',                                                  'bimbingan', 'Mikrobiota & Perut',    52, true),
  ('Bimbingan Keseimbangan Mikrobiota Meningkatkan Pemulihan Perut',            'bimbingan', 'Mikrobiota & Perut',    53, true),

  -- Protein & Pankreas
  ('Bimbingan Pemulihan tanpa Protein Haiwan',                                  'bimbingan', 'Protein & Pankreas',    60, true),
  ('Bimbingan Bila protein jadi beban',                                         'bimbingan', 'Protein & Pankreas',    61, true),
  ('Bimbingan Hidupkan Pankreas, Makanan ''Panas'' dan ''Sejuk''',              'bimbingan', 'Protein & Pankreas',    62, true),

  -- Gaya Hidup & Makanan
  ('Bimbingan Gaya Hidup Fitrah',                                               'bimbingan', 'Gaya Hidup & Makanan',  70, true),
  ('Bimbingan Keburukan makanan Berproses',                                     'bimbingan', 'Gaya Hidup & Makanan',  71, true),
  ('Bimbingan Lemak: Musuh atau Kawan',                                         'bimbingan', 'Gaya Hidup & Makanan',  72, true),

  -- Follow Up
  ('Sesi follow up',                                                            'bimbingan', 'Follow Up',             80, true)
ON CONFLICT DO NOTHING;
