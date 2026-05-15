-- ISW Default Inventory Items
-- Run this after step17_inventory.sql
-- Clears existing items and inserts fresh ISW defaults

DELETE FROM psy_inventory_items;

INSERT INTO psy_inventory_items (name, category, unit, qty_in_stock, min_qty, requires_approval, notes)
VALUES

-- ── MADU & PRODUK ─────────────────────────────────────────
('Lebah Thoharah (LTH)',            'Madu & Produk', 'kg',     0, 5,  false, 'Program NLC / JS / JS+ / EOL'),
('LTH Plus Green (LTHPG)',          'Madu & Produk', 'kg',     0, 5,  false, 'Program NLC / JS / JS+ / EOL'),
('Ibu Bumi (IB)',                   'Madu & Produk', 'kg',     0, 5,  false, 'Program OBD / OBP'),
('Young & Healthy Plus Green (YHPG)','Madu & Produk','kg',     0, 5,  false, 'Program OBD / OBP'),
('Madu Kelulut',                    'Madu & Produk', 'botol',  0, 3,  false, NULL),
('Minyak Zaitun Tulen',             'Madu & Produk', 'botol',  0, 3,  false, NULL),

-- ── STARTER KIT ───────────────────────────────────────────
('SDS OB',                          'Starter Kit',   'unit',   0, 5,  false, 'Starter kit OBD / OBP'),
('GHF',                             'Starter Kit',   'unit',   0, 5,  false, 'Starter kit OBD / OBP'),
('BNP',                             'Starter Kit',   'unit',   0, 5,  false, 'Bekalan pantang NLC / JS'),
('NSS',                             'Starter Kit',   'unit',   0, 5,  false, 'Bekalan pantang NLC / JS'),
('Voucher Konsultasi',              'Starter Kit',   'unit',   0, 10, false, 'Diedarkan semasa onboarding'),

-- ── SUPLEMEN & RESEPI ─────────────────────────────────────
('Resepi Superimun',                'Suplemen & Resepi', 'unit', 0, 5, false, 'Diberi semasa onboarding'),
('Resepi Superenergi',              'Suplemen & Resepi', 'unit', 0, 5, false, 'Diberi semasa onboarding'),
('Barley Organik',                  'Suplemen & Resepi', 'kg',   0, 5, false, NULL),
('Spirulina',                       'Suplemen & Resepi', 'botol',0, 3, false, NULL),
('Probiotik Advanced',              'Suplemen & Resepi', 'botol',0, 3, false, NULL),
('Magnesium Glycinate',             'Suplemen & Resepi', 'botol',0, 3, false, NULL),
('Vitamin D3',                      'Suplemen & Resepi', 'botol',0, 3, false, NULL),
('Omega-3 Fish Oil',                'Suplemen & Resepi', 'botol',0, 3, false, NULL),

-- ── BUKU & BAHAN CETAK ────────────────────────────────────
('Buku P101',                       'Buku & Bahan Cetak', 'naskhah', 0, 10, false, '7 buku per set starter kit'),
('List Pantang',                    'Buku & Bahan Cetak', 'naskhah', 0, 10, false, 'Diedarkan semasa onboarding'),
('Peta OB',                         'Buku & Bahan Cetak', 'naskhah', 0, 10, false, 'Diedarkan semasa onboarding OBD / OBP'),
('Workbook Refleksi Harian',        'Buku & Bahan Cetak', 'naskhah', 0, 10, false, NULL),
('Jadual Terapi Mingguan',          'Buku & Bahan Cetak', 'naskhah', 0, 10, false, NULL),
('Mood Tracker',                    'Buku & Bahan Cetak', 'naskhah', 0, 10, false, NULL),
('Buku Gaya Hidup Fitrah',          'Buku & Bahan Cetak', 'naskhah', 0,  5, false, NULL),
('Kitab Doa Syifa',                 'Buku & Bahan Cetak', 'naskhah', 0,  5, false, NULL),

-- ── BROSUR & MARKETING ────────────────────────────────────
('Brochure Madu',                   'Brosur & Marketing', 'unit', 0, 20, false, NULL),
('Brochure ISW',                    'Brosur & Marketing', 'unit', 0, 20, false, NULL),
('Brochure OB',                     'Brosur & Marketing', 'unit', 0, 20, false, NULL),

-- ── BEKALAN COACHING ──────────────────────────────────────
('Air Afiyah',                      'Bekalan Coaching', 'botol', 0, 10, false, '1 botol = 1.5L'),
('Air Za''afaran',                  'Bekalan Coaching', 'botol', 0,  5, false, 'Untuk sesi Perubatan Rohani'),
('Herba Kolon',                     'Bekalan Coaching', 'set',   0,  3, false, '1 set = 1 kursus rawatan'),
('Kurma Ajwa',                      'Bekalan Coaching', 'biji',  0, 50, false, '49 biji per pesakit 777 VIP'),

-- ── PERALATAN KLINIK ──────────────────────────────────────
('DNA Test Kit',                    'Peralatan Klinik', 'set',  0, 2, true,  'Perlu kelulusan · hantar ke lab luar'),
('Enema Kit',                       'Peralatan Klinik', 'set',  0, 3, true,  'Perlu kelulusan'),
('Mesin Ozon',                      'Peralatan Klinik', 'unit', 0, 1, true,  'Rekod nombor siri setiap unit')

;
