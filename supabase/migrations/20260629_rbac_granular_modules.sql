-- ════════════════════════════════════════════════════════════════
-- step71: RBAC Granular — satu modul per navbar item
-- Sebelum ini banyak navbar items berkongsi satu modul (contoh:
-- risk, kepatuhan, kyc semua bawah 'patient'). Kini setiap
-- navbar item mempunyai modul tersendiri supaya boleh dikontrol
-- secara berasingan dalam peranan.html.
-- ════════════════════════════════════════════════════════════════

-- ── 1) Tambah kolum scope jika belum ada ────────────────────────
ALTER TABLE psy_modules ADD COLUMN IF NOT EXISTS scope TEXT DEFAULT 'staff';

-- ── 2) Set scope = 'staff' untuk semua modul sedia ada ──────────
UPDATE psy_modules SET scope = 'staff' WHERE scope IS NULL;

-- ── 3) Tambah modul granular baru (satu per navbar item) ────────
--      sort_order ikut susunan navbar:
--      UTAMA(10-80) → OPERASI(90-140) → KOMUNIKASI(150-180)
--      → LAPORAN(190-220) → PENTADBIRAN(230-260) → SISTEM(270-290)
--      Modul broad/internal (coaching, communication, dll) → 300+
INSERT INTO psy_modules (code, label, icon, scope, sort_order) VALUES
  -- UTAMA (urutan 3,5,7,8 — dashboard=10, patient=20, schedule=40, kob=60 dah ada)
  ('kyc',              'KYC',                  '🆔', 'staff',  30),
  ('plan_week',        'Weekly Plan',           '📋', 'staff',  50),
  ('kepatuhan',        'Kepatuhan',             '📊', 'staff',  70),
  ('risk',             'Amaran Risiko',         '⚠️', 'staff',  80),

  -- OPERASI (products=100, pulangan=130, payment=140 — package=90, inventory=110, orders=120 dah ada)
  ('products',         'Produk',               '🛍️', 'staff', 100),
  ('pulangan',         'Pulangan Botol',       '🍯', 'staff', 130),
  ('payment',          'Pembayaran',           '💳', 'staff', 140),

  -- KOMUNIKASI
  ('announcements',    'Pengumuman',           '📢', 'staff', 150),
  ('events',           'Acara & Kelas',        '📅', 'staff', 160),
  ('auto_messages',    'Mesej Automatik',      '🤖', 'staff', 170),
  ('library',          'Library',              '📚', 'staff', 180),

  -- LAPORAN
  ('governance',       'Governance',           '📈', 'staff', 190),
  ('staff_stats',      'Statistik',            '📊', 'staff', 200),
  ('pakej_laporan',    'Laporan Pakej',        '📦', 'staff', 210),
  ('issue',            'Report Issue',         '⚠️', 'staff', 220),

  -- PENTADBIRAN (surat, closures, kob_slots — staff=260 dah ada)
  ('surat',            'Surat Rasmi',          '📜', 'staff', 230),
  ('closures',         'Penutupan Klinik',     '🚫', 'staff', 240),
  ('kob_slots',        'Slot Konsultasi',      '⏰', 'staff', 250),

  -- SISTEM (rbac=270 dah ada)
  ('audit_kebenaran',  'Audit Kebenaran',      '📋', 'staff', 280),
  ('audit',            'Audit Log',            '🔒', 'staff', 290)

ON CONFLICT (code) DO UPDATE SET
  label = EXCLUDED.label,
  icon  = EXCLUDED.icon,
  scope = EXCLUDED.scope,
  sort_order = EXCLUDED.sort_order;

-- ── 3b) Kemaskini sort_order modul sedia ada ikut susunan navbar ─
UPDATE psy_modules SET sort_order =  10 WHERE code = 'dashboard';
UPDATE psy_modules SET sort_order =  20 WHERE code = 'patient';
UPDATE psy_modules SET sort_order =  40 WHERE code = 'schedule';
UPDATE psy_modules SET sort_order =  60 WHERE code = 'kob';
UPDATE psy_modules SET sort_order =  90 WHERE code = 'package';
UPDATE psy_modules SET sort_order = 110 WHERE code = 'inventory';
UPDATE psy_modules SET sort_order = 120 WHERE code = 'orders';
UPDATE psy_modules SET sort_order = 260 WHERE code = 'staff';
UPDATE psy_modules SET sort_order = 270 WHERE code = 'rbac';
-- Modul broad/internal — letak selepas semua navbar items
UPDATE psy_modules SET sort_order = 300 WHERE code = 'coaching';
UPDATE psy_modules SET sort_order = 310 WHERE code = 'communication';
UPDATE psy_modules SET sort_order = 320 WHERE code = 'operations';
UPDATE psy_modules SET sort_order = 330 WHERE code = 'reports';

-- ── 4) Tambah action 'view' untuk semua modul baru ──────────────
INSERT INTO psy_module_actions (module_code, action_code)
SELECT code, 'view' FROM psy_modules
WHERE code IN (
  'kyc','plan_week','risk','kepatuhan',
  'products','payment','pulangan',
  'announcements','events','auto_messages','library',
  'governance','staff_stats','pakej_laporan','issue',
  'surat','closures','kob_slots',
  'audit','audit_kebenaran'
)
ON CONFLICT DO NOTHING;

-- ── 5) Default grants ikut role ─────────────────────────────────

-- super_admin: semua modul baru
INSERT INTO psy_role_module_actions (role_code, module_code, action_code)
SELECT 'super_admin', code, 'view' FROM psy_modules
WHERE code IN (
  'kyc','plan_week','risk','kepatuhan',
  'products','payment','pulangan',
  'announcements','events','auto_messages','library',
  'governance','staff_stats','pakej_laporan','issue',
  'surat','closures','kob_slots',
  'audit','audit_kebenaran'
)
ON CONFLICT DO NOTHING;

-- manager: semua kecuali audit_kebenaran
INSERT INTO psy_role_module_actions (role_code, module_code, action_code) VALUES
  ('manager','kyc','view'),
  ('manager','plan_week','view'),
  ('manager','risk','view'),
  ('manager','kepatuhan','view'),
  ('manager','products','view'),
  ('manager','payment','view'),
  ('manager','pulangan','view'),
  ('manager','announcements','view'),
  ('manager','events','view'),
  ('manager','auto_messages','view'),
  ('manager','library','view'),
  ('manager','governance','view'),
  ('manager','staff_stats','view'),
  ('manager','pakej_laporan','view'),
  ('manager','issue','view'),
  ('manager','surat','view'),
  ('manager','closures','view'),
  ('manager','kob_slots','view'),
  ('manager','audit','view')
ON CONFLICT DO NOTHING;

-- admin: operasi + klinikal, tiada governance/audit/auto_messages
INSERT INTO psy_role_module_actions (role_code, module_code, action_code) VALUES
  ('admin','kyc','view'),
  ('admin','plan_week','view'),
  ('admin','risk','view'),
  ('admin','kepatuhan','view'),
  ('admin','products','view'),
  ('admin','payment','view'),
  ('admin','pulangan','view'),
  ('admin','announcements','view'),
  ('admin','events','view'),
  ('admin','library','view'),
  ('admin','staff_stats','view'),
  ('admin','pakej_laporan','view'),
  ('admin','issue','view'),
  ('admin','surat','view'),
  ('admin','closures','view'),
  ('admin','kob_slots','view')
ON CONFLICT DO NOTHING;

-- doctor: klinikal sahaja
INSERT INTO psy_role_module_actions (role_code, module_code, action_code) VALUES
  ('doctor','kyc','view'),
  ('doctor','plan_week','view'),
  ('doctor','risk','view'),
  ('doctor','kepatuhan','view'),
  ('doctor','announcements','view'),
  ('doctor','events','view'),
  ('doctor','library','view'),
  ('doctor','issue','view'),
  ('doctor','surat','view'),
  ('doctor','kob_slots','view')
ON CONFLICT DO NOTHING;

-- coach: patient/coaching fokus
INSERT INTO psy_role_module_actions (role_code, module_code, action_code) VALUES
  ('coach','kyc','view'),
  ('coach','plan_week','view'),
  ('coach','risk','view'),
  ('coach','kepatuhan','view'),
  ('coach','pulangan','view'),
  ('coach','announcements','view'),
  ('coach','events','view'),
  ('coach','library','view'),
  ('coach','issue','view'),
  ('coach','surat','view')
ON CONFLICT DO NOTHING;

SELECT 'Step 71 OK — granular RBAC modules ready' AS status;
SELECT code, label, scope FROM psy_modules WHERE scope = 'staff' ORDER BY sort_order;
