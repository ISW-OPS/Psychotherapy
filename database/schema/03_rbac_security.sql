-- ═══════════════════════════════════════════════════════════════════
-- SKEMA: KESELAMATAN & RBAC (Peranan, Kebenaran, Audit)
-- Jadual: psy_audit_log, psy_roles, psy_modules, psy_actions,
--         psy_module_actions, psy_role_module_actions,
--         psy_user_overrides, psy_permission_audit
-- View  : psy_user_effective_permissions
-- Fungsi: isw_is_staff, settings_is_staff, settings_is_super_admin,
--         user_has_perm
-- Model RBAC = Role × Module × Action matrix:
--   psy_roles (peranan) × psy_modules (modul app) × psy_actions (6 action
--   standard). psy_module_actions = cell yang boleh ditick;
--   psy_role_module_actions = grant default per role;
--   psy_user_overrides = grant/revoke tambahan per user.
--   Kebenaran akhir user diselesaikan oleh view psy_user_effective_permissions.
-- ═══════════════════════════════════════════════════════════════════

-- ──── fungsi helper keselamatan (dipakai oleh RLS fail lain juga) ────

-- Semak pengguna semasa ialah staff (SECURITY DEFINER — elak rekursi RLS
-- bila polisi ON psy_profiles perlu query psy_profiles).
CREATE OR REPLACE FUNCTION public.isw_is_staff()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.psy_profiles
    WHERE id = auth.uid() AND role = 'staff'
  );
$$;

GRANT EXECUTE ON FUNCTION public.isw_is_staff() TO authenticated;

-- Helper RLS untuk modul tetapan sistem (psy_settings dll.)
CREATE OR REPLACE FUNCTION settings_is_staff() RETURNS BOOLEAN AS $$
  SELECT EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff');
$$ LANGUAGE sql SECURITY DEFINER STABLE;

CREATE OR REPLACE FUNCTION settings_is_super_admin() RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM psy_profiles
    WHERE id = auth.uid() AND role = 'staff' AND staff_role = 'super_admin'
  );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- ──── psy_audit_log ────
-- Jejak audit umum sistem. Turut dipakai untuk:
--   • Google Review tracking (action='google_review.clicked', meta={rating:N})
--   • Report Issue pesakit (action='issue.reported'/'issue.followup'/'issue.responded')

CREATE TABLE IF NOT EXISTS psy_audit_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_id UUID,
  actor_name TEXT,
  actor_role TEXT,
  action TEXT NOT NULL,
  target TEXT,
  meta JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_psy_audit_created ON psy_audit_log(created_at);

ALTER TABLE psy_audit_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff read audit" ON psy_audit_log;
CREATE POLICY "Staff read audit" ON psy_audit_log FOR SELECT
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "All authenticated insert audit" ON psy_audit_log;
CREATE POLICY "All authenticated insert audit" ON psy_audit_log FOR INSERT
  WITH CHECK (true);

-- Pesakit boleh baca issue sendiri, balasan staff, dan follow-up sendiri.
DROP POLICY IF EXISTS "Patients read own issues" ON psy_audit_log;
CREATE POLICY "Patients read own issues" ON psy_audit_log FOR SELECT
  USING (
    (action IN ('issue.reported', 'issue.followup') AND actor_id = auth.uid())
    OR (action = 'issue.responded' AND target = auth.uid()::text)
  );

COMMENT ON TABLE psy_audit_log IS
  'Audit trail. Untuk Google Review tracking guna action=''google_review.clicked'', meta={rating: N}';

-- ──── psy_roles ────
-- Master list peranan (system roles + roles ciptaan UI peranan.html).

CREATE TABLE IF NOT EXISTS psy_roles (
  code        TEXT PRIMARY KEY,
  label       TEXT NOT NULL,
  description TEXT,
  color       TEXT DEFAULT 'navy',
  icon        TEXT DEFAULT '👤',
  is_active   BOOLEAN DEFAULT true,
  is_system   BOOLEAN DEFAULT false,
  sort_order  INT DEFAULT 100,
  created_at  TIMESTAMPTZ DEFAULT now(),
  updated_at  TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE psy_roles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "r_read_all" ON psy_roles;
CREATE POLICY "r_read_all" ON psy_roles FOR SELECT USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "r_write_sa" ON psy_roles;
CREATE POLICY "r_write_sa" ON psy_roles FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND staff_role = 'super_admin'))
  WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND staff_role = 'super_admin'));

-- ──── psy_modules ────
-- Master list modul aplikasi. scope='staff' (navbar staff) atau 'patient'
-- (portal pesakit, kod pat_*). sort_order ikut susunan navbar.

CREATE TABLE IF NOT EXISTS psy_modules (
  code        TEXT PRIMARY KEY,
  label       TEXT NOT NULL,
  icon        TEXT,
  scope       TEXT DEFAULT 'staff',
  sort_order  INT DEFAULT 100,
  is_active   BOOLEAN DEFAULT true
);

ALTER TABLE psy_modules ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "m_read_all" ON psy_modules;
CREATE POLICY "m_read_all" ON psy_modules FOR SELECT USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "m_write_sa" ON psy_modules;
CREATE POLICY "m_write_sa" ON psy_modules FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND staff_role = 'super_admin'))
  WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND staff_role = 'super_admin'));

-- ──── psy_actions ────
-- 6 action standard: Lihat / Tambah / Edit / Padam / Eksport / Tetapan.

CREATE TABLE IF NOT EXISTS psy_actions (
  code        TEXT PRIMARY KEY,
  label       TEXT NOT NULL,
  icon        TEXT,
  sort_order  INT DEFAULT 100
);

ALTER TABLE psy_actions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "a_read_all" ON psy_actions;
CREATE POLICY "a_read_all" ON psy_actions FOR SELECT USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "a_write_sa" ON psy_actions;
CREATE POLICY "a_write_sa" ON psy_actions FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND staff_role = 'super_admin'))
  WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND staff_role = 'super_admin'));

-- ──── psy_module_actions ────
-- Module × Action applicability — cell yang boleh ditick dalam matrix.

CREATE TABLE IF NOT EXISTS psy_module_actions (
  module_code TEXT NOT NULL REFERENCES psy_modules(code) ON DELETE CASCADE,
  action_code TEXT NOT NULL REFERENCES psy_actions(code) ON DELETE CASCADE,
  PRIMARY KEY (module_code, action_code)
);

ALTER TABLE psy_module_actions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "ma_read_all" ON psy_module_actions;
CREATE POLICY "ma_read_all" ON psy_module_actions FOR SELECT USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "ma_write_sa" ON psy_module_actions;
CREATE POLICY "ma_write_sa" ON psy_module_actions FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND staff_role = 'super_admin'))
  WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND staff_role = 'super_admin'));

-- ──── psy_role_module_actions ────
-- Grant default per role (cell "✓" dalam matrix peranan.html).

CREATE TABLE IF NOT EXISTS psy_role_module_actions (
  role_code   TEXT NOT NULL REFERENCES psy_roles(code) ON DELETE CASCADE,
  module_code TEXT NOT NULL,
  action_code TEXT NOT NULL,
  created_at  TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (role_code, module_code, action_code),
  FOREIGN KEY (module_code, action_code) REFERENCES psy_module_actions(module_code, action_code) ON DELETE CASCADE
);

ALTER TABLE psy_role_module_actions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "rma_read_all" ON psy_role_module_actions;
CREATE POLICY "rma_read_all" ON psy_role_module_actions FOR SELECT USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "rma_write_sa" ON psy_role_module_actions;
CREATE POLICY "rma_write_sa" ON psy_role_module_actions FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND staff_role = 'super_admin'))
  WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND staff_role = 'super_admin'));

-- ──── psy_user_overrides ────
-- Override per-user: grant tambahan atau revoke daripada default role.

CREATE TABLE IF NOT EXISTS psy_user_overrides (
  user_id     UUID NOT NULL REFERENCES psy_profiles(id) ON DELETE CASCADE,
  module_code TEXT NOT NULL,
  action_code TEXT NOT NULL,
  grant_type  TEXT NOT NULL CHECK (grant_type IN ('grant','revoke')),
  granted_by  UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  granted_at  TIMESTAMPTZ DEFAULT now(),
  reason      TEXT,
  PRIMARY KEY (user_id, module_code, action_code),
  FOREIGN KEY (module_code, action_code) REFERENCES psy_module_actions(module_code, action_code) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_user_overrides_user ON psy_user_overrides(user_id);

ALTER TABLE psy_user_overrides ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "uo_read_all" ON psy_user_overrides;
CREATE POLICY "uo_read_all" ON psy_user_overrides FOR SELECT USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "uo_write_sa" ON psy_user_overrides;
CREATE POLICY "uo_write_sa" ON psy_user_overrides FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND staff_role = 'super_admin'))
  WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND staff_role = 'super_admin'));

-- ──── psy_permission_audit ────
-- Log setiap perubahan permission (role/module/override). Bila staff
-- dipadam, actor_id jadi NULL — rekod kekal.

CREATE TABLE IF NOT EXISTS psy_permission_audit (
  id          BIGSERIAL PRIMARY KEY,
  actor_id    UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  actor_email TEXT,
  action      TEXT NOT NULL,
  target_type TEXT NOT NULL,
  target_id   TEXT NOT NULL,
  module_code TEXT,
  action_code TEXT,
  details     JSONB,
  created_at  TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_perm_audit_created ON psy_permission_audit(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_perm_audit_target  ON psy_permission_audit(target_type, target_id);

ALTER TABLE psy_permission_audit ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "au_read_all" ON psy_permission_audit;
CREATE POLICY "au_read_all" ON psy_permission_audit FOR SELECT USING (
  EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND staff_role = 'super_admin')
);

DROP POLICY IF EXISTS "au_write_sa" ON psy_permission_audit;
CREATE POLICY "au_write_sa" ON psy_permission_audit FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');

-- ──── view: psy_user_effective_permissions ────
-- Kebenaran akhir per user = (default role − revokes) UNION grants.

CREATE OR REPLACE VIEW psy_user_effective_permissions AS
SELECT p.id AS user_id, rma.module_code, rma.action_code
FROM psy_profiles p
JOIN psy_role_module_actions rma ON rma.role_code = p.staff_role
WHERE NOT EXISTS (
  SELECT 1 FROM psy_user_overrides uo
  WHERE uo.user_id = p.id
    AND uo.module_code = rma.module_code
    AND uo.action_code = rma.action_code
    AND uo.grant_type = 'revoke'
)
UNION
SELECT user_id, module_code, action_code
FROM psy_user_overrides WHERE grant_type = 'grant';

-- ──── fungsi: user_has_perm ────
-- Cek user semasa ada permission tertentu (dipakai dalam polisi RLS
-- jadual lain, cth surat: communication.edit / communication.delete).

CREATE OR REPLACE FUNCTION user_has_perm(p_module TEXT, p_action TEXT)
RETURNS BOOLEAN
LANGUAGE SQL STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM psy_user_effective_permissions
    WHERE user_id = auth.uid()
      AND module_code = p_module
      AND action_code = p_action
  );
$$;

-- ═══════════════════════════════════════════════════════════════════
-- DATA RUJUKAN (SEED)
-- ═══════════════════════════════════════════════════════════════════

-- ──── seed: actions (6 standard) ────
INSERT INTO psy_actions (code, label, icon, sort_order) VALUES
  ('view',     'Lihat',    '👁️',  10),
  ('create',   'Tambah',   '➕',  20),
  ('edit',     'Edit',     '✏️',  30),
  ('delete',   'Padam',    '🗑️',  40),
  ('export',   'Eksport',  '📤',  50),
  ('settings', 'Tetapan',  '⚙️',  60)
ON CONFLICT (code) DO UPDATE SET label=EXCLUDED.label, icon=EXCLUDED.icon, sort_order=EXCLUDED.sort_order;

-- ──── seed: modules ────
-- sort_order ikut susunan navbar staff:
--   UTAMA(10-80) → OPERASI(90-140) → KOMUNIKASI(150-185)
--   → LAPORAN(190-220) → PENTADBIRAN(230-260) → SISTEM(270-290)
--   Modul broad/internal (sub-page checks, bukan navbar item) → 300+
--   Modul portal pesakit (scope='patient') → kod pat_*

-- 'risk' (Amaran Risiko) DIBUANG 22 Jul 2026 — halaman risk.html dipadam
-- (data demo sahaja, tiada enjin sebenar), digantikan modul 'emergency'
-- (Red Emergency Protocol) di bawah. CASCADE buang grant lama sekali.
DELETE FROM psy_modules WHERE code = 'risk';

INSERT INTO psy_modules (code, label, icon, scope, sort_order) VALUES
  -- UTAMA
  ('dashboard',        'Dashboard',            '🏠', 'staff',  10),
  ('patient',          'Pesakit & KYC',        '👥', 'staff',  20),
  ('kyc',              'KYC',                  '🆔', 'staff',  30),
  ('schedule',         'Kalendar & Jadual',    '📅', 'staff',  40),
  ('plan_week',        'Weekly Plan',          '📋', 'staff',  50),
  ('kob',              'KOB',                  '🩺', 'staff',  60),
  ('kepatuhan',        'Kepatuhan',            '📊', 'staff',  70),
  ('reaksi',           'Reaksi & Tindakan',    '🩹', 'staff',  72),
  ('vitals',           'Bacaan Vitals',        '💓', 'staff',  75),
  ('rujukan',          'Rujukan',              '🔀', 'staff',  76),
  ('emergency',        'Red Emergency Protocol','🚨', 'staff',  80),
  ('patient_events',   'Peristiwa Pesakit',    '🏥', 'staff',  82),
  ('dna_test',         'DNA Test',             '🧬', 'staff',  84),
  -- OPERASI
  ('package',          'Pakej & Pembayaran',   '🗂️', 'staff',  90),
  ('products',         'Produk',               '🛍️', 'staff', 100),
  ('inventory',        'Inventori & Produk',   '🏭', 'staff', 110),
  ('orders',           'Orders & Tracking',    '📦', 'staff', 120),
  ('pulangan',         'Pulangan Botol',       '🍯', 'staff', 130),
  ('payment',          'Pembayaran',           '💳', 'staff', 140),
  ('affiliate',        'Affiliate',            '🤝', 'staff', 145),
  -- KOMUNIKASI
  ('announcements',    'Pengumuman',           '📢', 'staff', 150),
  ('events',           'Acara & Kelas',        '📅', 'staff', 160),
  ('auto_messages',    'Mesej Automatik',      '🤖', 'staff', 170),
  ('library',          'Library',              '📚', 'staff', 180),
  ('kb',               'Knowledge Base',       '📖', 'staff', 185),
  -- LAPORAN
  ('governance',       'Governance',           '📈', 'staff', 190),
  ('staff_stats',      'Statistik',            '📊', 'staff', 200),
  ('kehadiran',        'Laporan Kehadiran',    '📋', 'staff', 205),
  ('pakej_laporan',    'Laporan Pakej',        '📦', 'staff', 210),
  ('issue',            'Report Issue',         '⚠️', 'staff', 220),
  -- PENTADBIRAN
  ('surat',            'Surat Rasmi',          '📜', 'staff', 230),
  ('closures',         'Penutupan Klinik',     '🚫', 'staff', 240),
  ('kob_slots',        'Slot Konsultasi',      '⏰', 'staff', 250),
  ('staff',            'Manage Staff',         '👨‍⚕️','staff', 260),
  -- SISTEM
  ('rbac',             'Peranan & Kebenaran',  '🔐', 'staff', 270),
  ('audit_kebenaran',  'Audit Kebenaran',      '📋', 'staff', 280),
  ('audit',            'Audit Log',            '🔒', 'staff', 290),
  -- Modul broad/internal (internal action checks)
  ('coaching',         'Rawatan & Sesi',       '🧑‍🏫','staff', 300),
  ('communication',    'Komunikasi & Library', '📢', 'staff', 310),
  ('operations',       'Operasi Klinik',       '⚙️', 'staff', 320),
  ('reports',          'Laporan & Audit',      '📊', 'staff', 330),
  -- Portal pesakit
  ('pat_announcements','Pengumuman',           '📢', 'patient', 12),
  ('pat_events',       'Acara & Kelas',        '📅', 'patient', 15),
  ('pat_sejarah',      'Sejarah Pembayaran',   '🧾', 'patient', 95)
ON CONFLICT (code) DO UPDATE SET
  label = EXCLUDED.label,
  icon  = EXCLUDED.icon,
  scope = EXCLUDED.scope,
  sort_order = EXCLUDED.sort_order;

-- ──── seed: system roles ────
INSERT INTO psy_roles (code, label, description, color, icon, is_system, sort_order) VALUES
  ('super_admin', 'Super Admin', 'Akses penuh ke semua modul dan tetapan sistem.', 'purple', '🛡️', true, 10),
  ('manager',     'Manager',     'Pengurus klinik — operasi penuh + kewangan + governance.', 'navy', '👔', true, 20),
  ('admin',       'Admin',       'Admin operasi — urus pesakit, pakej, inventori, surat.', 'teal', '🧑‍💼', true, 30),
  ('doctor',      'Doctor',      'Doktor klinikal — pesakit, KYC, KOB, plan rawatan.', 'green', '🩺', true, 40),
  ('coach',       'Coach',       'Coach — pesakit ditugaskan, plan, sesi coaching.', 'gold', '🧑‍🏫', true, 50)
ON CONFLICT (code) DO UPDATE SET label=EXCLUDED.label, description=EXCLUDED.description, color=EXCLUDED.color, icon=EXCLUDED.icon, is_system=true;

-- Role 'patient' — diperlukan oleh grant modul pat_* (FK ke psy_roles).
INSERT INTO psy_roles (code, label, description, color, icon, is_system, sort_order) VALUES
  ('patient', 'Patient', 'Akses portal pesakit (modul pat_*).', 'green', '🧑', true, 60)
ON CONFLICT (code) DO NOTHING;

-- ──── seed: module × action ────
-- SEMUA action didaftar untuk SETIAP modul — tiada cell "—" (Tidak
-- Berkenaan) dalam peranan.html; semua kotak boleh di-toggle.
INSERT INTO psy_module_actions (module_code, action_code)
SELECT m.code, a.code
FROM psy_modules m
CROSS JOIN psy_actions a
ON CONFLICT DO NOTHING;

-- ──── seed: grant default per role ────

-- 1) Grant 'view' ikut liputan modul setiap role.
-- Super Admin: semua modul staff.
INSERT INTO psy_role_module_actions (role_code, module_code, action_code)
SELECT 'super_admin', code, 'view' FROM psy_modules WHERE scope = 'staff'
ON CONFLICT DO NOTHING;

-- Manager: semua modul staff kecuali audit_kebenaran.
INSERT INTO psy_role_module_actions (role_code, module_code, action_code)
SELECT 'manager', code, 'view' FROM psy_modules
WHERE scope = 'staff' AND code <> 'audit_kebenaran'
ON CONFLICT DO NOTHING;

-- Admin: operasi + klinikal; tiada governance/audit/audit_kebenaran/
-- auto_messages/rbac.
INSERT INTO psy_role_module_actions (role_code, module_code, action_code)
SELECT 'admin', code, 'view' FROM psy_modules
WHERE scope = 'staff'
  AND code NOT IN ('governance','audit','audit_kebenaran','auto_messages','rbac')
ON CONFLICT DO NOTHING;

-- Doctor: fokus klinikal.
INSERT INTO psy_role_module_actions (role_code, module_code, action_code)
SELECT 'doctor', m.code, 'view'
FROM (VALUES
  ('dashboard'),('patient'),('kyc'),('schedule'),('plan_week'),('kob'),
  ('kepatuhan'),('reaksi'),('vitals'),('rujukan'),('emergency'),('patient_events'),
  ('announcements'),('events'),('library'),('kb'),
  ('kehadiran'),('issue'),('surat'),('kob_slots'),
  ('coaching'),('inventory'),('communication'),('operations')
) AS m(code)
ON CONFLICT DO NOTHING;

-- Coach: pesakit ditugaskan + coaching.
INSERT INTO psy_role_module_actions (role_code, module_code, action_code)
SELECT 'coach', m.code, 'view'
FROM (VALUES
  ('dashboard'),('patient'),('kyc'),('schedule'),('plan_week'),
  ('kepatuhan'),('reaksi'),('vitals'),('rujukan'),('emergency'),('patient_events'),('pulangan'),('dna_test'),
  ('announcements'),('events'),('library'),('kb'),
  ('kehadiran'),('issue'),('surat'),
  ('coaching'),('inventory'),('communication'),('operations')
) AS m(code)
ON CONFLICT DO NOTHING;

-- 2) Grant 'settings' (Tetapan) — modul terpilih sahaja.
INSERT INTO psy_role_module_actions (role_code, module_code, action_code)
SELECT r.role, r.module, 'settings'
FROM (VALUES
  ('super_admin','patient'),('super_admin','schedule'),('super_admin','coaching'),
  ('super_admin','kob'),('super_admin','inventory'),('super_admin','orders'),
  ('super_admin','package'),('super_admin','communication'),('super_admin','operations'),
  ('super_admin','reports'),('super_admin','staff'),('super_admin','rbac'),
  ('super_admin','events'),('super_admin','auto_messages'),('super_admin','kb'),
  ('super_admin','patient_events'),('manager','patient_events'),
  ('manager','patient'),('manager','schedule'),('manager','coaching'),
  ('manager','kob'),('manager','inventory'),('manager','orders'),
  ('manager','package'),('manager','communication'),('manager','operations'),
  ('manager','reports'),('manager','staff'),
  ('manager','events'),('manager','kb'),
  ('admin','kob'),('admin','kb'),
  ('doctor','kob')
) AS r(role, module)
ON CONFLICT DO NOTHING;

-- 3) Kembangan view ⇒ create/edit/delete/export:
-- setiap (role, modul staff) yang ada 'view' turut diberi action lain
-- supaya semua butang boleh di-toggle OFF kemudian oleh admin.
INSERT INTO psy_role_module_actions (role_code, module_code, action_code)
SELECT rma.role_code, rma.module_code, a.code
FROM psy_role_module_actions rma
JOIN psy_modules m ON m.code = rma.module_code AND m.scope = 'staff'
CROSS JOIN psy_actions a
WHERE rma.action_code = 'view'
  AND a.code IN ('create','edit','delete','export')
  AND rma.role_code <> 'patient'
ON CONFLICT DO NOTHING;

-- 4) Grant portal pesakit (role 'patient').
INSERT INTO psy_role_module_actions (role_code, module_code, action_code) VALUES
  ('patient', 'pat_announcements', 'view'),
  ('patient', 'pat_events',        'view'),
  ('patient', 'pat_sejarah',       'view')
ON CONFLICT DO NOTHING;
