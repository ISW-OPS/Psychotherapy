-- ISW System — master_migration.sql
-- DIJANA AUTOMATIK daripada database/schema/*.sql — JANGAN edit fail ini terus.
-- Edit fail domain dalam database/schema/, kemudian jalankan: python database/_generate_master.py
-- Generated: 2026-07-31T06:27:58.488224Z
-- Jumlah fail: 27
-- Selamat dijalankan pada projek Supabase kosong (SQL Editor).


-- ════════════════════════════════════════════════════════════════
-- schema/02_profiles_staff.sql
-- ════════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════════
-- ISW System — Skema Domain: Profil Pengguna & Peranan Staf
-- Jadual: psy_profiles
-- Termasuk: trigger auth.users → handle_new_user, polisi storage staf
-- ═══════════════════════════════════════════════════════════════════

-- ──── psy_profiles ────
-- Profil semua pengguna (pesakit & staf). id = auth.users.id.
-- staff_role bebas (tiada CHECK) supaya peranan custom boleh ditambah via UI.

CREATE TABLE IF NOT EXISTS psy_profiles (
  id              UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name       TEXT NOT NULL,
  role            TEXT NOT NULL CHECK (role IN ('patient','staff')),
  staff_role      TEXT,
  phone           TEXT,
  email           TEXT,
  avatar_url      TEXT,
  registration_no TEXT,
  specialization  TEXT,
  is_active       BOOLEAN DEFAULT true,
  birth_date      DATE,
  gender          TEXT CHECK (gender IN ('lelaki','perempuan')),
  language        TEXT,
  marital_status  TEXT CHECK (marital_status IN ('bujang','berkahwin','bercerai','duda','janda')),
  department      TEXT,
  signature_url   TEXT,
  created_at      TIMESTAMPTZ DEFAULT now(),
  updated_at      TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_psy_profiles_role ON psy_profiles(role);

ALTER TABLE psy_profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Read all profiles authenticated" ON psy_profiles;
CREATE POLICY "Read all profiles authenticated" ON psy_profiles
  FOR SELECT USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Update own profile" ON psy_profiles;
CREATE POLICY "Update own profile" ON psy_profiles
  FOR UPDATE USING (auth.uid() = id);

DROP POLICY IF EXISTS "Insert own profile" ON psy_profiles;
CREATE POLICY "Insert own profile" ON psy_profiles
  FOR INSERT WITH CHECK (auth.uid() = id OR auth.role() = 'service_role');

-- Staf boleh kemas kini profil pesakit (guna helper public.isw_is_staff())
DROP POLICY IF EXISTS "Staff update patient profiles" ON psy_profiles;
CREATE POLICY "Staff update patient profiles" ON psy_profiles
  FOR UPDATE
  USING (role = 'patient' AND public.isw_is_staff())
  WITH CHECK (role = 'patient');

COMMENT ON COLUMN psy_profiles.birth_date     IS 'Tarikh lahir staff (untuk paparan profil)';
COMMENT ON COLUMN psy_profiles.gender         IS 'Jantina: lelaki / perempuan';
COMMENT ON COLUMN psy_profiles.language       IS 'Bahasa utama yang digunakan';
COMMENT ON COLUMN psy_profiles.marital_status IS 'Status perkahwinan staff';
COMMENT ON COLUMN psy_profiles.department     IS 'Jabatan / Unit kerja';
COMMENT ON COLUMN psy_profiles.signature_url  IS
  'URL signature image staff. Embed dalam surat rasmi yang di-sign.';

-- ──── auto-cipta profil bila auth user baru didaftar ────
-- Staf baru dapat staff_role dari metadata (default 'coach').

CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.psy_profiles (id, full_name, role, email, staff_role)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', split_part(NEW.email, '@', 1)),
    COALESCE(NEW.raw_user_meta_data->>'role', 'patient'),
    NEW.email,
    CASE
      WHEN COALESCE(NEW.raw_user_meta_data->>'role', 'patient') = 'staff'
      THEN COALESCE(NEW.raw_user_meta_data->>'staff_role', 'coach')
      ELSE NULL
    END
  );
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE LOG 'Error creating profile: %', SQLERRM;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- Nota: trigger trg_new_patient_profile (auto-cipta rekod pesakit) berada
-- dalam 04_patients.sql bersama fungsinya handle_new_patient_profile().

-- Nota: semua polisi storage (medical-reports, kob, wa-outbox, referral-docs
-- dll.) diselenggara berpusat dalam 24_storage.sql.


-- ════════════════════════════════════════════════════════════════
-- schema/03_rbac_security.sql
-- ════════════════════════════════════════════════════════════════

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


-- ════════════════════════════════════════════════════════════════
-- schema/04_patients.sql
-- ════════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════════
-- 04_patients.sql — Domain Pesakit
-- Jadual: psy_patients, psy_kyc_submissions, psy_patient_notes,
--         psy_patient_documents
-- Fungsi/Trigger: MRN autogen, referral code, KYC→patient sync,
--                 updated_at, auto-inactive, stub pesakit self-register
-- Nota kebergantungan: psy_profiles (01), psy_treatment_plans /
--   psy_plan_weekly_progress (plan), fungsi assign_referral_code
--   (didefinisi dalam domain referral).
-- ═══════════════════════════════════════════════════════════════════

-- ────────────────────────────────────────────────
-- psy_patients — rekod induk pesakit
-- ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS psy_patients (
  id                              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id                         UUID REFERENCES psy_profiles(id) ON DELETE CASCADE,
  mrn                             TEXT UNIQUE,
  full_name                       TEXT,
  phone                           TEXT,
  email                           TEXT,
  ic_number                       TEXT,
  date_of_birth                   DATE,
  gender                          TEXT CHECK (gender IN ('M','F')),
  marital_status                  TEXT,
  occupation                      TEXT,
  company                         TEXT,
  address                         TEXT,
  home_address                    TEXT,
  city                            TEXT,
  state                           TEXT,
  emergency_contact_name          TEXT,
  emergency_contact_phone         TEXT,
  emergency_contact_ic            TEXT,
  emergency_contact_relationship  TEXT,
  emergency_contact_email         TEXT,
  insurance_provider              TEXT,
  insurance_policy                TEXT,
  referral_source                 TEXT,
  medical_condition               TEXT,
  condition_duration              TEXT,
  medical_notes                   TEXT,
  height_cm                       NUMERIC,
  active_package_id               TEXT,
  active_package_name             TEXT,
  package_purchased_at            TIMESTAMPTZ,
  package_expires_at              TIMESTAMPTZ,
  next_package_id                 TEXT,
  next_package_name               TEXT,
  daily_schedule                  JSONB,
  status                          TEXT DEFAULT 'active',
  kob_status                      TEXT NOT NULL DEFAULT 'paid',
  outcome_status                  TEXT,
  outcome_status_at               TIMESTAMPTZ,
  outcome_status_notes            TEXT,
  coach_id                        UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  assigned_at                     TIMESTAMPTZ,
  created_by_staff                BOOLEAN DEFAULT false,
  reference_code                  TEXT,
  documents                       JSONB DEFAULT '{}',
  referral_code                   TEXT,
  referred_by_code                TEXT,
  referred_by_patient_id          UUID REFERENCES psy_patients(id) ON DELETE SET NULL,
  created_at                      TIMESTAMPTZ DEFAULT now(),
  updated_at                      TIMESTAMPTZ DEFAULT now(),
  CONSTRAINT psy_patients_user_id_unique UNIQUE (user_id),
  CONSTRAINT psy_patients_status_check CHECK (status IN (
    'pending_kyc','active','inactive','rejected','deleted',
    'unregistered','archived','deceased'
  )),
  CONSTRAINT psy_patients_kob_status_check CHECK (kob_status IN (
    'pending_payment',      -- Patient baru daftar, belum bayar
    'paid',                 -- Sudah bayar (bayaran luaran/GHL), KYC belum hantar
    'kyc_done',             -- KYC selesai, belum book slot KOB
    'booked',               -- Slot KOB ditempah
    'hadir',                -- Doktor tekan Hadir (sesi sedang berlangsung)
    'package_recommended',  -- Doktor pilih pakej, pesakit perlu bayar
    'package_paid',         -- Pesakit sudah bayar pakej
    'completed',            -- KOB selesai → pakej unlocked
    'na'                    -- Not applicable (staff-created / grandfathered)
  )),
  CONSTRAINT psy_patients_outcome_status_check CHECK (
    outcome_status IN ('otw','berhenti','meninggal','completed')
  )
);

-- ──── indeks psy_patients ────
CREATE INDEX IF NOT EXISTS idx_psy_patients_user  ON psy_patients(user_id);
CREATE INDEX IF NOT EXISTS idx_psy_patients_mrn   ON psy_patients(mrn);
CREATE INDEX IF NOT EXISTS idx_psy_patients_coach ON psy_patients(coach_id);
CREATE INDEX IF NOT EXISTS idx_psy_patients_email ON psy_patients(email);
CREATE INDEX IF NOT EXISTS idx_psy_patients_full_name ON psy_patients(full_name);
CREATE INDEX IF NOT EXISTS idx_psy_patients_phone     ON psy_patients(phone);
CREATE INDEX IF NOT EXISTS idx_patients_state         ON psy_patients(state);

CREATE INDEX IF NOT EXISTS idx_psy_patients_outcome_status
  ON psy_patients (outcome_status) WHERE outcome_status IS NOT NULL;

-- Untuk auto-link query (cari unlinked staff-created patients ikut IC)
CREATE INDEX IF NOT EXISTS idx_psy_patients_created_by_staff
  ON psy_patients(created_by_staff)
  WHERE created_by_staff = true AND user_id IS NULL;

-- Kod rujukan mesti unik (NULL dibenarkan berbilang)
CREATE UNIQUE INDEX IF NOT EXISTS idx_psy_patients_referral_code
  ON psy_patients (referral_code) WHERE referral_code IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_psy_patients_referred_by
  ON psy_patients (referred_by_patient_id) WHERE referred_by_patient_id IS NOT NULL;

-- ──── RLS psy_patients ────
ALTER TABLE psy_patients ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff manage patients" ON psy_patients;
CREATE POLICY "Staff manage patients" ON psy_patients FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "Patients read own record" ON psy_patients;
CREATE POLICY "Patients read own record" ON psy_patients FOR SELECT
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Patients update own record" ON psy_patients;
CREATE POLICY "Patients update own record" ON psy_patients FOR UPDATE
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Patients insert own record" ON psy_patients;
CREATE POLICY "Patients insert own record" ON psy_patients FOR INSERT
  WITH CHECK (user_id = auth.uid());

-- ──── trigger: auto-update updated_at ────
CREATE OR REPLACE FUNCTION set_patients_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_set_patients_updated_at ON psy_patients;
CREATE TRIGGER trg_set_patients_updated_at
  BEFORE UPDATE ON psy_patients
  FOR EACH ROW
  EXECUTE FUNCTION set_patients_updated_at();

-- ──── trigger: auto-jana MRN unik bila tidak dibekalkan ────
-- Client tak boleh query MRN tertinggi sebab RLS — jadi jana di DB.
CREATE OR REPLACE FUNCTION assign_patient_mrn()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  next_num INT;
  candidate TEXT;
BEGIN
  -- Kalau MRN dah diset client, biar je (mungkin migration / staff create)
  IF NEW.mrn IS NOT NULL AND NEW.mrn != '' THEN
    RETURN NEW;
  END IF;

  -- Ambil nombor tertinggi dari MRN format 'P-NNN'
  SELECT COALESCE(MAX(CAST(regexp_replace(mrn, '\D', '', 'g') AS INT)), 0)
  INTO next_num
  FROM psy_patients
  WHERE mrn LIKE 'P-%';

  -- Loop sampai dapat MRN yang unik (handle race condition)
  LOOP
    next_num := next_num + 1;
    candidate := 'P-' || LPAD(next_num::TEXT, 3, '0');
    EXIT WHEN NOT EXISTS (SELECT 1 FROM psy_patients WHERE mrn = candidate);
  END LOOP;

  NEW.mrn := candidate;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_assign_patient_mrn ON psy_patients;
CREATE TRIGGER trg_assign_patient_mrn
  BEFORE INSERT ON psy_patients
  FOR EACH ROW
  EXECUTE FUNCTION assign_patient_mrn();

-- Nota: trigger trg_assign_referral_code (auto-jana referral code) berada
-- dalam 20_referrals.sql bersama fungsinya assign_referral_code().

-- ──── fungsi + trigger: auto-create stub pesakit untuk self-register ────
-- Flow: signup → email confirm → login → KYC → KOB → ...
CREATE OR REPLACE FUNCTION handle_new_patient_profile()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NEW.role = 'patient' THEN
    IF NOT EXISTS (SELECT 1 FROM psy_patients WHERE user_id = NEW.id) THEN
      INSERT INTO psy_patients (user_id, full_name, status, kob_status, created_by_staff)
      VALUES (NEW.id, NEW.full_name, 'pending_kyc', 'paid', false);
    END IF;
  END IF;
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE LOG 'handle_new_patient_profile error: %', SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_new_patient_profile ON psy_profiles;
CREATE TRIGGER trg_new_patient_profile
  AFTER INSERT ON psy_profiles
  FOR EACH ROW
  EXECUTE FUNCTION handle_new_patient_profile();

-- ──── fungsi: auto-tandai pesakit Tidak Aktif bila rawatan selesai ────
-- Dicetus bila mana-mana sesi ditanda hadir/consultation_done (trigger pada
-- psy_plan_weekly_progress — didefinisi dalam domain plan). Pelan TIDAK
-- auto-tutup selagi ada minggu sambungan (continuity, extension_for_week=0)
-- yang sudah dibayar tetapi belum selesai.
CREATE OR REPLACE FUNCTION fn_auto_inactive_on_session_done()
RETURNS TRIGGER AS $$
DECLARE
  v_patient_id   UUID;
  v_pstatus      TEXT;
  v_pkg_expired  BOOLEAN;
  v_all_done     BOOLEAN;
  v_has_core     BOOLEAN;
BEGIN
  IF NEW.status NOT IN ('hadir','consultation_done') THEN
    RETURN NEW;
  END IF;
  IF TG_OP = 'UPDATE' AND OLD.status = NEW.status THEN
    RETURN NEW;
  END IF;

  SELECT patient_id INTO v_patient_id FROM psy_treatment_plans WHERE id = NEW.plan_id;
  IF v_patient_id IS NULL THEN RETURN NEW; END IF;

  -- v_has_core : ada sekurang-kurangnya satu sesi teras.
  -- v_all_done : tiada baris "menghalang" yang belum selesai, iaitu
  --   (a) sesi teras (is_extension=false) yang belum selesai, ATAU
  --   (b) minggu continuity BERBAYAR (extension_for_week = 0, bukan pending bayaran) yang belum selesai.
  SELECT
    EXISTS (SELECT 1 FROM psy_plan_weekly_progress
            WHERE plan_id = NEW.plan_id AND COALESCE(is_extension,false) = false),
    NOT EXISTS (
      SELECT 1 FROM psy_plan_weekly_progress
      WHERE plan_id = NEW.plan_id
        AND status NOT IN ('hadir','consultation_done')
        AND (
          COALESCE(is_extension,false) = false
          OR (COALESCE(extension_for_week, -1) = 0 AND status <> 'extension_pending_payment')
        )
    )
    INTO v_has_core, v_all_done;

  SELECT status, (package_expires_at IS NOT NULL AND package_expires_at < now())
    INTO v_pstatus, v_pkg_expired
    FROM psy_patients WHERE id = v_patient_id;

  -- Sudah tak aktif → jangan ganggu
  IF v_pstatus IN ('inactive','archived','deceased','deleted') THEN
    RETURN NEW;
  END IF;

  IF (v_has_core AND v_all_done) OR v_pkg_expired THEN
    UPDATE psy_patients
      SET status = 'inactive',
          outcome_status = CASE WHEN outcome_status IS NULL OR outcome_status = ''
                                THEN 'completed' ELSE outcome_status END,
          outcome_status_at = CASE WHEN outcome_status IS NULL OR outcome_status = ''
                                   THEN now() ELSE outcome_status_at END
      WHERE id = v_patient_id;
    UPDATE psy_treatment_plans SET status = 'completed'
      WHERE id = NEW.plan_id AND status <> 'completed';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ──── komen psy_patients ────
COMMENT ON COLUMN psy_patients.kob_status IS
  'KOB lifecycle. Payment external (GHL). New self-registered patient starts at paid → kyc_done → booked → hadir → completed. Staff-created can be na (grandfathered).';

COMMENT ON COLUMN psy_patients.outcome_status IS
  'Clinical outcome: otw=On-going Treatment, berhenti=stopped, meninggal=passed away, completed=selesai rawatan';

COMMENT ON COLUMN psy_patients.daily_schedule IS
  'Patient-customized daily schedule. NULL = inherit from active package template. Array = patient has overridden.';

COMMENT ON COLUMN psy_patients.created_by_staff IS
  'TRUE = pesakit didaftarkan oleh staff (bukan self-signup). Akan bypass KOB flow (kob_status=na) dan tunggu auto-link bila pesakit signup sendiri guna IC sama.';

COMMENT ON COLUMN psy_patients.full_name IS
  'Nama pesakit. Bila ada user_id, biasanya match dgn psy_profiles.full_name. Snapshot untuk staff-created tanpa user_id.';

COMMENT ON COLUMN psy_patients.phone IS
  'Nombor telefon utama pesakit. Boleh berbeza dari psy_profiles.phone (cth: kalau staff tukar di sini).';

COMMENT ON COLUMN psy_patients.emergency_contact_email IS
  'Email kenalan kecemasan / waris.';

COMMENT ON COLUMN psy_patients.emergency_contact_relationship IS
  'Hubungan waris dengan pesakit (Suami, Isteri, Ibu, Bapa, Anak, dll).';

COMMENT ON COLUMN psy_patients.updated_at IS
  'Masa kemaskini terakhir rekod pesakit (auto dari trigger).';

COMMENT ON COLUMN psy_patients.home_address IS
  'Alamat kediaman pesakit (berbeza dari address yang digunakan untuk surat-menyurat / mailing).';

COMMENT ON COLUMN psy_patients.city  IS 'Bandar (sebahagian dari alamat kediaman).';

COMMENT ON COLUMN psy_patients.state IS 'Negeri (Selangor, Johor, dll.).';

COMMENT ON COLUMN psy_patients.referral_code IS
  'Kod rujukan unik pesakit ini untuk dikongsi (auto-jana dari nama/MRN).';

COMMENT ON COLUMN psy_patients.referred_by_code IS
  'Kod rujukan perujuk yang dimasukkan semasa pesakit ini mendaftar.';

COMMENT ON COLUMN psy_patients.referred_by_patient_id IS
  'Pesakit perujuk yang telah diselesaikan dari referred_by_code.';

COMMENT ON COLUMN psy_patients.next_package_id IS
  'Pakej sambungan (continuity) yang sudah dibayar & beratur; auto-aktif bila pakej semasa selesai (step93).';

-- ────────────────────────────────────────────────
-- psy_kyc_submissions — borang KYC pesakit
-- ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS psy_kyc_submissions (
  id                              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id                         UUID REFERENCES psy_profiles(id) ON DELETE CASCADE,
  patient_name                    TEXT NOT NULL,
  ic_number                       TEXT,
  date_of_birth                   DATE,
  gender                          TEXT,
  phone                           TEXT,
  email                           TEXT,
  address                         TEXT,
  marital_status                  TEXT,
  occupation                      TEXT,
  company                         TEXT,
  emergency_contact               TEXT,
  emergency_contact_name          TEXT,
  emergency_contact_phone         TEXT,
  emergency_contact_ic            TEXT,
  emergency_contact_relationship  TEXT,
  emergency_contact_email         TEXT,
  medical_condition               TEXT,
  condition_duration              TEXT,
  medical_notes                   TEXT,
  insurance_info                  JSONB,
  documents                       JSONB DEFAULT '{}',
  consent_data_processing         BOOLEAN DEFAULT false,
  consent_health_records          BOOLEAN DEFAULT false,
  consent_research                BOOLEAN DEFAULT false,
  consent_marketing               BOOLEAN DEFAULT false,
  referral_source                 TEXT,
  submitted_by_proxy              BOOLEAN NOT NULL DEFAULT false,
  status                          TEXT DEFAULT 'pending'
                                  CHECK (status IN ('pending','approved','rejected','needs_docs')),
  reviewed_by                     UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  review_notes                    TEXT,
  created_at                      TIMESTAMPTZ DEFAULT now()
);

-- ──── RLS psy_kyc_submissions ────
ALTER TABLE psy_kyc_submissions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff manage KYC" ON psy_kyc_submissions;
CREATE POLICY "Staff manage KYC" ON psy_kyc_submissions FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "Patients read own KYC" ON psy_kyc_submissions;
CREATE POLICY "Patients read own KYC" ON psy_kyc_submissions FOR SELECT
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Patients insert own KYC" ON psy_kyc_submissions;
CREATE POLICY "Patients insert own KYC" ON psy_kyc_submissions FOR INSERT
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Patients update own KYC" ON psy_kyc_submissions;
CREATE POLICY "Patients update own KYC" ON psy_kyc_submissions FOR UPDATE
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Staff can read all kyc" ON psy_kyc_submissions;
CREATE POLICY "Staff can read all kyc"
  ON psy_kyc_submissions FOR SELECT
  USING (
    auth.uid() IN (SELECT id FROM psy_profiles WHERE role = 'staff')
    OR auth.uid() = user_id
  );

-- ──── trigger: auto-sync KYC → patient bila KYC diluluskan ────
-- Menjamin tiada desync walaupun patient row tak wujud masa KYC approved.
CREATE OR REPLACE FUNCTION sync_kyc_to_patient()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  -- Hanya sync bila status berubah jadi 'approved'
  IF NEW.status = 'approved' AND (OLD.status IS NULL OR OLD.status != 'approved') THEN
    UPDATE psy_patients
    SET
      status                  = 'active',
      full_name               = COALESCE(NULLIF(full_name, ''), NEW.patient_name),
      phone                   = COALESCE(NULLIF(phone, ''), NEW.phone),
      ic_number               = COALESCE(NULLIF(ic_number, ''), NEW.ic_number),
      date_of_birth           = COALESCE(date_of_birth, NEW.date_of_birth),
      gender                  = COALESCE(NULLIF(gender, ''), NEW.gender),
      address                 = COALESCE(NULLIF(address, ''), NEW.address),
      emergency_contact_name  = COALESCE(NULLIF(emergency_contact_name, ''), NEW.emergency_contact_name),
      emergency_contact_phone = COALESCE(NULLIF(emergency_contact_phone, ''), NEW.emergency_contact_phone),
      referral_source         = COALESCE(NULLIF(referral_source, ''), NEW.referral_source),
      medical_condition       = COALESCE(NULLIF(medical_condition, ''), NEW.medical_condition),
      condition_duration      = COALESCE(NULLIF(condition_duration, ''), NEW.condition_duration),
      medical_notes           = COALESCE(NULLIF(medical_notes, ''), NEW.medical_notes)
    WHERE user_id = NEW.user_id;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_kyc_to_patient ON psy_kyc_submissions;
CREATE TRIGGER trg_sync_kyc_to_patient
  AFTER INSERT OR UPDATE ON psy_kyc_submissions
  FOR EACH ROW
  EXECUTE FUNCTION sync_kyc_to_patient();

-- ──── komen psy_kyc_submissions ────
COMMENT ON COLUMN psy_kyc_submissions.submitted_by_proxy IS
  'true = wakil/keluarga isi borang ini (info mesti tepat & boleh disahkan dengan pesakit sebenar)';

-- ────────────────────────────────────────────────
-- psy_patient_notes — catatan pesakit (staff)
-- ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS psy_patient_notes (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id   UUID NOT NULL REFERENCES psy_patients(id) ON DELETE CASCADE,
  note_type    TEXT NOT NULL DEFAULT 'general'
               CHECK (note_type IN ('general','coach','sesi','checkin','vitals','medical','dna','peringatan')),
  content      TEXT NOT NULL,
  related_session_id UUID,
  related_report_id  UUID,
  actor_id     UUID,
  actor_name   TEXT,
  actor_role   TEXT,
  is_pinned    BOOLEAN DEFAULT false,
  visibility   TEXT DEFAULT 'staff'
               CHECK (visibility IN ('staff','patient','both')),
  created_at   TIMESTAMPTZ DEFAULT now(),
  updated_at   TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_patient_notes_patient ON psy_patient_notes(patient_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_patient_notes_type    ON psy_patient_notes(note_type);

ALTER TABLE psy_patient_notes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "staff_notes_all" ON psy_patient_notes;
CREATE POLICY "staff_notes_all" ON psy_patient_notes FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "patient_notes_read" ON psy_patient_notes;
CREATE POLICY "patient_notes_read" ON psy_patient_notes FOR SELECT
  USING (visibility IN ('patient','both') AND
         patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

-- ────────────────────────────────────────────────
-- psy_patient_documents — dokumen pesakit
--   plan_id NULL + week_number NULL -> dokumen umum (Patient Hub)
--   plan_id + week_number diisi     -> dokumen khusus minggu (plan-week)
-- ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS psy_patient_documents (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id   UUID NOT NULL REFERENCES psy_patients(id) ON DELETE CASCADE,
  doc_type     TEXT NOT NULL DEFAULT 'other'
               CHECK (doc_type IN ('kyc','ic','passport','persetujuan','laporan_perubatan','gambar','surat_rasmi','resit','other')),
  doc_label    TEXT NOT NULL,
  description  TEXT,
  file_name    TEXT,
  file_path    TEXT,
  file_url     TEXT,
  file_size    INT,
  status       TEXT DEFAULT 'pending'
               CHECK (status IN ('pending','disahkan','disemak','tertunggak','ditolak')),
  uploaded_by  UUID,
  uploaded_by_name TEXT,
  uploaded_at  TIMESTAMPTZ DEFAULT now(),
  approved_by  UUID,
  approved_at  TIMESTAMPTZ,
  plan_id      UUID,  -- FK → psy_treatment_plans (dipasang di hujung 07_treatment_plans.sql)
  week_number  INT
);

CREATE INDEX IF NOT EXISTS idx_patient_docs_patient ON psy_patient_documents(patient_id, uploaded_at DESC);
CREATE INDEX IF NOT EXISTS idx_patient_docs_type    ON psy_patient_documents(doc_type);

CREATE INDEX IF NOT EXISTS idx_patient_docs_plan_week
  ON psy_patient_documents (plan_id, week_number)
  WHERE plan_id IS NOT NULL;

ALTER TABLE psy_patient_documents ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "staff_docs_all" ON psy_patient_documents;
CREATE POLICY "staff_docs_all" ON psy_patient_documents FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "patient_docs_read_own" ON psy_patient_documents;
CREATE POLICY "patient_docs_read_own" ON psy_patient_documents FOR SELECT
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "patient_docs_insert_own" ON psy_patient_documents;
CREATE POLICY "patient_docs_insert_own" ON psy_patient_documents FOR INSERT
  WITH CHECK (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

COMMENT ON COLUMN psy_patient_documents.plan_id IS
  'Jika diisi, dokumen ini dilampirkan pada plan rawatan tertentu (skop minggu).';

COMMENT ON COLUMN psy_patient_documents.week_number IS
  'Nombor minggu plan untuk dokumen ini (NULL = dokumen umum pesakit).';

-- Nota: polisi storage pesakit (medical-reports, kob-signatures, kob-documents)
-- diselenggara berpusat dalam 24_storage.sql.

-- ────────────────────────────────────────────────
-- Realtime — status pesakit / kehadiran auto-tolak ke UI
-- (Realtime hormati RLS)
-- ────────────────────────────────────────────────
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'psy_patients'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE psy_patients;
  END IF;
END $$;
-- (realtime psy_plan_weekly_progress: lihat 07_treatment_plans.sql)


-- ════════════════════════════════════════════════════════════════
-- schema/05_packages.sql
-- ════════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════════
-- SKEMA: PAKEJ & TAWARAN PAKEJ
-- Jadual: psy_packages, psy_package_purchases, psy_package_categories,
--         psy_continuity_offers
-- ═══════════════════════════════════════════════════════════════════

-- ──────────────────────────────────────────────────────────────
-- psy_packages — definisi pakej rawatan
-- ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS psy_packages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  package_id TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  description TEXT,
  price NUMERIC(10,2) DEFAULT 0,
  duration TEXT,
  duration_unit TEXT DEFAULT 'week',
  duration_weeks INT DEFAULT 12,
  icon TEXT DEFAULT '📦',
  bg_color TEXT DEFAULT 'bg-cream',
  tier TEXT,
  is_active BOOLEAN DEFAULT true,
  products JSONB DEFAULT '[]',
  bimbingan JSONB DEFAULT '[]',
  inclusions JSONB DEFAULT '[]',
  coaching_schedule JSONB DEFAULT '[]',
  phases JSONB,
  sort_order INT DEFAULT 0,
  -- jadual madu & kunci sesi online
  madu_frequency_per_day INT,
  madu_schedule_label TEXT,
  allow_online_full_duration BOOLEAN NOT NULL DEFAULT false,
  online_lock_from_week INT NOT NULL DEFAULT 3,
  -- konfigurasi mingguan
  weekly_supplies JSONB DEFAULT '[]',
  weekly_content JSONB DEFAULT '[]',
  weekly_message JSONB DEFAULT '[]',
  -- perjanjian (kontrak) pakej
  agreement_pdf TEXT,
  agreement_clauses JSONB DEFAULT '[]',
  agreement_version TEXT,
  agreement_title TEXT DEFAULT 'Kontrak Pelaburan Kesihatan',
  -- rutin harian & jadual sesi fleksibel
  daily_schedule JSONB DEFAULT '[]'::jsonb,
  sessions_per_week INT DEFAULT 1
    CHECK (sessions_per_week BETWEEN 1 AND 7),
  session_days_options JSONB DEFAULT '[]',
  -- lain-lain
  extension_price_per_week NUMERIC(10,2) DEFAULT 50,
  meet_link TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_psy_packages_active ON psy_packages(is_active);
CREATE INDEX IF NOT EXISTS idx_psy_packages_sort ON psy_packages(sort_order);

ALTER TABLE psy_packages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone read active packages" ON psy_packages;
CREATE POLICY "Anyone read active packages" ON psy_packages
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "Staff manage packages" ON psy_packages;
CREATE POLICY "Staff manage packages" ON psy_packages FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
  WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

COMMENT ON COLUMN psy_packages.madu_frequency_per_day IS
  'Frekuensi peminuman madu sehari. Examples: 10 (12-minggu), 8 (3-bulan), 4 (3-bulan-sekali). NULL = no madu schedule.';

COMMENT ON COLUMN psy_packages.madu_schedule_label IS
  'Human-readable label for madu schedule, e.g. "10x sehari (12 minggu)"';

COMMENT ON COLUMN psy_packages.allow_online_full_duration IS
  'true = online sessions allowed throughout (OBD1/OBDX1/OBDY1/OBP1/OBPX1/OBPY1). false = lock to f2f after online_lock_from_week.';

COMMENT ON COLUMN psy_packages.online_lock_from_week IS
  'Week number from which online sessions are locked (must use f2f). Default 3.';

COMMENT ON COLUMN psy_packages.weekly_supplies IS
  'Array of {week, items: [{product_id, qty, name}]} — bekalan auto-deduct per week';

COMMENT ON COLUMN psy_packages.weekly_content IS
  'Array of {week, content_ids: []} — library content unlock per week';

COMMENT ON COLUMN psy_packages.weekly_message IS
  'Array of {week, message} — WhatsApp template per week';

COMMENT ON COLUMN psy_packages.agreement_pdf IS
  'Filename of agreement PDF in shared/documents/agreements/ (relative path). NULL = use default agreement.pdf';

COMMENT ON COLUMN psy_packages.agreement_clauses IS
  'Array of {title, body} clauses for the patient agreement. Supports variables like {{patient_name}}.';

COMMENT ON COLUMN psy_packages.agreement_version IS
  'Version label, e.g. ISW.SOP OB KOB FORM 03 CONTRACT 250711';

COMMENT ON COLUMN psy_packages.agreement_title IS
  'Title shown at top of agreement (default: Kontrak Pelaburan Kesihatan)';

COMMENT ON COLUMN psy_packages.daily_schedule IS
  'Array of {time:"HH:MM", activity:"text"} — default daily routine for patients on this package.';

COMMENT ON COLUMN psy_packages.sessions_per_week IS
  'Bilangan sesi seminggu untuk pakej ini. 1 = sekali (OBG), 2 = dua kali (OB/NLC). Pakej per-hari (777) guna duration_unit=day, biarkan field ini = 1.';

COMMENT ON COLUMN psy_packages.session_days_options IS
  'Pilihan variant hari sesi yang patient boleh pilih. Format: array of array of int (1=Mon, 7=Sun). Cth OB: [[5,6],[6,7]] = pilihan Jum+Sab ATAU Sab+Ahd. OBG: [[6]] = Sabtu sahaja.';

COMMENT ON COLUMN psy_packages.extension_price_per_week IS
  'Harga (RM) untuk tambah satu minggu rawatan bila patient miss sesi. Default RM 50.';

COMMENT ON COLUMN psy_packages.meet_link IS
  'Pautan Gmeet recurring untuk pakej. Dipaparkan kepada patient bila minggu semasa adalah online/both.';

-- ──────────────────────────────────────────────────────────────
-- psy_package_purchases — pembelian pakej oleh pesakit
-- ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS psy_package_purchases (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id UUID REFERENCES psy_patients(id) ON DELETE CASCADE NOT NULL,
  package_id TEXT NOT NULL,
  package_name TEXT NOT NULL,
  price NUMERIC(10,2) NOT NULL,
  purchased_at TIMESTAMPTZ DEFAULT now(),
  expires_at TIMESTAMPTZ,
  status TEXT DEFAULT 'pending_payment' CHECK (status IN ('pending_payment','paid','active','expired','cancelled')),
  payment_method TEXT,
  ghl_order_id TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_psy_purchases_patient ON psy_package_purchases(patient_id);

ALTER TABLE psy_package_purchases ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Patients manage own purchases" ON psy_package_purchases;
CREATE POLICY "Patients manage own purchases" ON psy_package_purchases FOR ALL
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()))
  WITH CHECK (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Staff read all purchases" ON psy_package_purchases;
CREATE POLICY "Staff read all purchases" ON psy_package_purchases FOR SELECT
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "Staff update purchases" ON psy_package_purchases;
CREATE POLICY "Staff update purchases" ON psy_package_purchases FOR UPDATE
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- ──────────────────────────────────────────────────────────────
-- psy_package_categories — kategori pakej dinamik (CRUD dari UI)
-- ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS psy_package_categories (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug        TEXT NOT NULL UNIQUE,
  label       TEXT NOT NULL,
  badge_color TEXT,
  sort_order  INTEGER NOT NULL DEFAULT 100,
  is_active   BOOLEAN NOT NULL DEFAULT true,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE psy_package_categories ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone read categories" ON psy_package_categories;
CREATE POLICY "Anyone read categories" ON psy_package_categories
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "Staff manage categories" ON psy_package_categories;
CREATE POLICY "Staff manage categories" ON psy_package_categories
  FOR ALL USING (
    EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff')
  );

COMMENT ON TABLE psy_package_categories IS 'Senarai kategori pakej (dahulu hardcoded: standard/free/vip). Slug disimpan dalam psy_packages.tier.';
COMMENT ON COLUMN psy_package_categories.slug IS 'Stored value in psy_packages.tier (e.g. standard, free, vip, detox)';
COMMENT ON COLUMN psy_package_categories.badge_color IS 'Tailwind color suffix for badge (e.g. gold, green, navy) — null = no badge';

-- ──────────────────────────────────────────────────────────────
-- psy_continuity_offers — cadangan pakej sambungan oleh coach
-- package_uuid = psy_packages.id (UUID yg app guna sbg active_package_id)
-- ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS psy_continuity_offers (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id       UUID,  -- FK → psy_treatment_plans (dipasang di hujung 07_treatment_plans.sql)
  patient_id    UUID NOT NULL REFERENCES psy_patients(id) ON DELETE CASCADE,
  suggested_by  UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  package_uuid  UUID,
  package_name  TEXT,
  price         NUMERIC(10,2),
  note          TEXT,
  status        TEXT DEFAULT 'sent' CHECK (status IN ('sent','viewed','accepted','declined','cancelled')),
  created_at    TIMESTAMPTZ DEFAULT now(),
  responded_at  TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_psy_continuity_offers_patient
  ON psy_continuity_offers(patient_id, status, created_at DESC);

ALTER TABLE psy_continuity_offers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff manage continuity offers" ON psy_continuity_offers;
CREATE POLICY "Staff manage continuity offers" ON psy_continuity_offers FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "Patients read own continuity offers" ON psy_continuity_offers;
CREATE POLICY "Patients read own continuity offers" ON psy_continuity_offers FOR SELECT
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Patients respond own continuity offers" ON psy_continuity_offers;
CREATE POLICY "Patients respond own continuity offers" ON psy_continuity_offers FOR UPDATE
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

COMMENT ON TABLE psy_continuity_offers IS
  'Cadangan pakej sambungan oleh coach utk pesakit baki ≤4 minggu. Terima → pembayaran.';

-- ══════════════════════════════════════════════════════════════
-- DATA RUJUKAN (SEED)
-- ══════════════════════════════════════════════════════════════

-- ──── kategori pakej ────
INSERT INTO psy_package_categories (slug, label, badge_color, sort_order)
VALUES
  ('standard', 'Program Intensif', NULL,    10),
  ('free',     'Pakej Percuma',    'green', 20),
  ('vip',      'VIP / Premium',    'gold',  30)
ON CONFLICT (slug) DO NOTHING;

-- ──── konfigurasi pakej OB-direct: online dibenarkan sepanjang tempoh ────
UPDATE psy_packages
  SET allow_online_full_duration = true
  WHERE LOWER(package_id) IN ('obd1','obdx1','obdy1','obp1','obpx1','obpy1');

-- ──── pemetaan PDF perjanjian per pakej (hanya jika belum ditetapkan) ────
UPDATE psy_packages SET agreement_pdf = 'ELIXIR_EOL_CONTRACT_[TEMPLATE].pdf'
  WHERE LOWER(package_id) IN ('pkg-eol','eol') AND agreement_pdf IS NULL;

UPDATE psy_packages SET agreement_pdf = 'ELIXIR_EOL+_CONTRACT_[TEMPLATE].pdf'
  WHERE LOWER(package_id) IN ('pkg-eol-plus','pkg-eolplus','eol+','eol-plus') AND agreement_pdf IS NULL;

UPDATE psy_packages SET agreement_pdf = 'ELIXIR__JUMPSTART_CONTRACT_[TEMPLATE].pdf'
  WHERE LOWER(package_id) IN ('pkg-jumpstart','pkg-js','js','jumpstart') AND agreement_pdf IS NULL;

UPDATE psy_packages SET agreement_pdf = 'ELIXIR__JUMPSTART+_CONTRACT_[TEMPLATE].pdf'
  WHERE LOWER(package_id) IN ('pkg-jumpstart-plus','pkg-jsplus','js+','jumpstart+') AND agreement_pdf IS NULL;

UPDATE psy_packages SET agreement_pdf = 'OBD1_-_CONTRACT_[TEMPLATE].pdf'
  WHERE LOWER(package_id) IN ('pkg-obd1','obd1') AND agreement_pdf IS NULL;

UPDATE psy_packages SET agreement_pdf = 'OBDX1_-_CONTRACT_[TEMPLATE].pdf'
  WHERE LOWER(package_id) IN ('pkg-obdx1','obdx1') AND agreement_pdf IS NULL;

UPDATE psy_packages SET agreement_pdf = 'OBDY1_-_CONTRACT_[TEMPLATE].pdf'
  WHERE LOWER(package_id) IN ('pkg-obdy1','obdy1') AND agreement_pdf IS NULL;

UPDATE psy_packages SET agreement_pdf = 'OBG_(NLC)_-_CONTRACT_[TEMPLATE].pdf'
  WHERE LOWER(package_id) IN ('pkg-obg-nlc','pkg-obg','obg','obg-nlc') AND agreement_pdf IS NULL;

UPDATE psy_packages SET agreement_pdf = 'OBP1_-_CONTRACT_[TEMPLATE].pdf'
  WHERE LOWER(package_id) IN ('pkg-obp1','obp1') AND agreement_pdf IS NULL;

UPDATE psy_packages SET agreement_pdf = 'OBPX1_-_CONTRACT_[TEMPLATE].pdf'
  WHERE LOWER(package_id) IN ('pkg-obpx1','obpx1') AND agreement_pdf IS NULL;

UPDATE psy_packages SET agreement_pdf = 'OBPY1_-_CONTRACT_[TEMPLATE].pdf'
  WHERE LOWER(package_id) IN ('pkg-obpy1','obpy1') AND agreement_pdf IS NULL;

-- ──── klausa perjanjian lalai (hanya jika masih kosong) ────
UPDATE psy_packages
SET
  agreement_clauses = '[
    {"title": "1. Tanggungjawab Maklumat", "body": "Saya mengambil tanggungjawab sepenuhnya terhadap kesihatan saya dan telah mengisi borang ini dengan sukarela dengan memberikan maklumat kesihatan saya kepada Ibnu Sina Wellness."},
    {"title": "2. Khidmat Nasihat", "body": "Saya berpuas hati dengan khidmat nasihat kesihatan yang diberikan oleh perawat Ibnu Sina Wellness."},
    {"title": "3. Bukan Rawatan Medikal", "body": "Saya faham dengan sepenuhnya bahawa ia bukan diagnosis medikal atau rawatan medikal atau substitut untuk diagnosis medikal atau rawatan medikal."},
    {"title": "4. Penyakit Mental & Sihir", "body": "Saya faham bahawa sekiranya saya mempunyai masalah mental atau sihir dan saka, saya harus dirawat terlebih dahulu sebelum memulakan program {{package_name}} di Ibnu Sina Wellness."},
    {"title": "5. Rawatan Alternatif", "body": "Saya faham bahawa program {{package_name}} di Ibnu Sina Wellness adalah rawatan alternatif dan ia tidak menggantikan perubatan hospital maka saya akan meneruskan pengambilan ubat, perubatan dan pemeriksaan hospital."},
    {"title": "6. Komitmen Harian", "body": "Saya faham bagi mencapai hasil yang baik, saya perlu amalkan secara komited setiap hari segala tatacara yang disusun dan diajarkan oleh Ibnu Sina Wellness secara sepenuhnya."},
    {"title": "7. Gaya Pemikiran Fitrah", "body": "Saya komited untuk mengikuti program {{package_name}} bagi menukar kepada Gaya Pemikiran Follow Fitrah sebagai tahap asas untuk mencapai kesihatan yang sihat."},
    {"title": "8. Penyembuhan Di Tangan Allah", "body": "Saya faham penyembuhan penyakit adalah di tangan Allah SWT dan jangkamasa penyembuhan bergantung kepada keizinan Allah."},
    {"title": "9. Penerangan Pakej", "body": "Saya telah diberi penerangan penuh pakej program {{package_name}} dengan jelas oleh Ibnu Sina Wellness."},
    {"title": "10. Reaksi Pemulihan", "body": "Ibnu Sina Wellness telah memaklumkan tentang reaksi pemulihan dan gejala prosedur, yang boleh termasuk, tetapi tidak terhad kepada: pening atau loya, sakit-sakit badan, flu, lebam, perubahan warna kulit, dan kemungkinan risiko lain yang tidak dijangka. Dalam sesetengah kes, simptom saya mungkin bertambah buat sementara waktu sebelum ia mula beransur baik. Saya akan menanggung segala risiko yang terlibat dengan prosedur saya."},
    {"title": "11. Kecemasan Hospital", "body": "Saya faham saya perlu ke hospital untuk kecemasan. Saya juga akan segera ke hospital sekiranya saya sakit atau mengalami reaksi pemulihan yang teruk seperti yang tertera di buku Sains di Sebalik {{package_name}} atau seperti yang dinasihatkan oleh perawat dan coach Ibnu Sina Wellness."},
    {"title": "12. Tiada Jaminan Keputusan", "body": "Saya faham bahawa tiada jaminan keputusan untuk sebarang prosedur yang sedang dijalani. Prosedur kesihatan alternatif dan holistik selalunya tidak akan menunjukkan hasil rawatan dengan serta merta."},
    {"title": "13. Tempoh Hasil", "body": "Tempoh untuk mencapai hasil serta keputusan bergantung pada tahap kesihatan saya, disiplin serta komitmen saya mengamalkan kaedah program {{package_name}} di Ibnu Sina Wellness."},
    {"title": "14. Tiada Paksa Tanggungjawab", "body": "Saya tidak akan memaksa Ibnu Sina Wellness untuk bertanggungjawab ke atas sebarang kekurangan hasil program {{package_name}}."},
    {"title": "15. Kerosakan Peralatan", "body": "Saya faham bahawa sekiranya terdapat sebarang kerosakan terhadap peralatan rawatan Ibnu Sina Wellness disebabkan oleh kecuaian atau kegagalan untuk bertindak sewajarnya dari diri saya sendiri, saya akan membayar pampasan kepada pihak Ibnu Sina Wellness kos yang munasabah untuk membaiki kerosakan peralatan rawatan tersebut berdasarkan permintaan Ibnu Sina Wellness."},
    {"title": "16. Pilihan Sendiri", "body": "Dengan rela hati saya sendiri membuat keputusan untuk mengikuti program {{package_name}} Ibnu Sina Wellness dan telah dimaklumkan tentang risiko serta manfaatnya."},
    {"title": "17. Pembebasan Tanggungjawab", "body": "Saya membebaskan pihak Ibnu Sina Wellness, herba-herba yang digunakan, peralatan yang digunakan, fasiliti, perawat, strategist, pekerja Ibnu Sina Wellness, pesakit yang memberi testimoni serta kesemua produksi media Ibnu Sina Wellness dari sebarang tindakan dan kerugian selamanya."},
    {"title": "18. Barang Peribadi", "body": "Saya faham bahawa semua barang peribadi di dalam fasiliti Ibnu Sina Wellness adalah di bawah tanggungjawab saya sendiri dan pihak Ibnu Sina Wellness tidak akan bertanggungjawab pada sebarang kerosakan atau kecurian atau penyelewengan barang peribadi saya."},
    {"title": "19. Rakaman Laporan Progres", "body": "19.1 Saya dengan ini mengesahkan persetujuan yang diberikan kepada Ibnu Sina Wellness berkenaan dengan fotografi, rakaman video, penggambaran, atau rakaman audio bagi tujuan penyimpanan rekod pesakit, informasi, pembelajaran atau promosi.\n\n19.2 Saya sedia maklum bahawa maklumat yang diberikan kepada Ibnu Sina Wellness akan digunakan, diedarkan atau dikongsikan kepada mana-mana pihak ketiga berkenaan dengan fotografi, rakaman video, penggambaran, atau rakaman audio untuk siaran - langsung atau pre-rakaman."},
    {"title": "20. Pembatalan Program", "body": "Saya akan memberi notis bertulis tempoh 7 hari sekiranya saya ingin membatalkan program {{package_name}}."},
    {"title": "21. Pemulangan Wang", "body": "Saya faham tiada pemulangan wang secara tunai ke atas pembayaran yang dilakukan. Lebihan wang yang telah dibayar akan digantikan dengan mana-mana perkhidmatan dan/atau produk Ibnu Sina Wellness yang lain."},
    {"title": "22. Hari Rawatan", "body": "22.1 Hari rawatan ialah pada hari Jumaat, Sabtu dan Ahad.\n\n22.2 Saya faham bahawa jika rawatan di luar waktu dan hari yang dinyatakan, akan ada cas \"on-call\" RM50/sejam.\n\n22.3 Saya faham bahawa ISW berhak untuk menukar waktu dan hari rawatan atas apa-apa sebab dan tiada cas \"on-call\" akan dikenakan."},
    {"title": "23. Pembayaran Ansuran", "body": "Saya bertanggungjawab untuk melunaskan bayaran mengikut tarikh dan jumlah yang telah ditetapkan mengikut Pelan Pelaburan Ansuran."},
    {"title": "24. Kegagalan Ansuran", "body": "Saya faham jika saya gagal menunaikan pembayaran mengikut Pelan Pelaburan Ansuran, yuran pakej saya akan berbalik ke yuran asal."},
    {"title": "25. Tindakan Undang-undang", "body": "Saya juga sedar kegagalan mematuhi bayaran mengikut tarikh dan jumlah yang telah ditetapkan akan menyebabkan kes saya dirujuk untuk tindakan undang-undang."},
    {"title": "26. Persetujuan Hutang", "body": "Saya bersetuju untuk menjalani program {{package_name}} sepenuhnya di Ibnu Sina Wellness secara berhutang."},
    {"title": "27. Janji Pembayaran", "body": "Saya berjanji untuk melangsaikan semua bayaran mengikut Pelan Pelaburan Ansuran."},
    {"title": "28. Tiada Refund", "body": "Saya faham tiada pemulangan wang akan diberikan atas bayaran yang telah dibuat. Lebihan wang yang telah dibayar boleh digantikan dengan mana-mana perkhidmatan dan/atau produk Ibnu Sina Wellness yang lain, tertakluk pada pengurusan Ibnu Sina Wellness."},
    {"title": "29. Bayaran Online Transfer", "body": "Untuk bayaran online transfer, saya hanya akan buat bayaran ke akaun di bawah:\n\nIBNU SINA WELLNESS SDN BHD - CIMB BANK - 8605794539\nWA SCREENSHOT BAYARAN KE COACH DI 0389663702"}
  ]'::jsonb,
  agreement_version = 'ISW.SOP OB KOB FORM 03 CONTRACT 250711',
  agreement_title = 'Kontrak Pelaburan Kesihatan'
WHERE agreement_clauses = '[]' OR agreement_clauses IS NULL;

-- ──── jadual harian lalai per pakej (hanya jika masih kosong) ────
UPDATE psy_packages
SET daily_schedule = CASE
  WHEN LOWER(package_id) IN (
    'obd1','obdx1','obdy1','obp1','obpx1','obpy1',
    'pkg-obd1','pkg-obdx1','pkg-obdy1','pkg-obp1','pkg-obpx1','pkg-obpy1'
  ) THEN '[
    {"time":"06:15","activity":"Zikir bersanad"},
    {"time":"06:30","activity":"Minum madu LTHPG"},
    {"time":"07:30","activity":"Minum madu LTH"},
    {"time":"07:45","activity":"Berjemur cahaya matahari pagi & terapi bumi & pernafasan fitrah (10 minit)"},
    {"time":"08:15","activity":"Makan breakfast (Yogurt dan buah)"},
    {"time":"09:15","activity":"Minum madu LTHPG"},
    {"time":"10:15","activity":"Minum madu LTH"},
    {"time":"11:15","activity":"Minum madu LTHPG"},
    {"time":"12:15","activity":"Minum madu LTH"},
    {"time":"12:30","activity":"Lunch & minum air kelapa"},
    {"time":"13:15","activity":"Solat Zohor & pernafasan fitrah (5 minit)"},
    {"time":"14:15","activity":"Minum madu LTHPG"},
    {"time":"15:15","activity":"Minum madu LTH"},
    {"time":"16:15","activity":"Minum madu LTHPG"},
    {"time":"16:40","activity":"Solat Asar & pernafasan fitrah (5 minit)"},
    {"time":"17:00","activity":"Berkebun @ Terapi bumi"},
    {"time":"18:30","activity":"Makan malam"},
    {"time":"19:30","activity":"Solat Maghrib & Zikir bersanad"},
    {"time":"20:30","activity":"Solat Isyak & Pernafasan Fitrah (5 minit)"},
    {"time":"21:00","activity":"Minum madu LTH"},
    {"time":"21:30","activity":"Pernafasan fitrah (5 minit) & Tidur"}
  ]'::jsonb
  WHEN LOWER(package_id) IN (
    'eol','pkg-eol','eol-plus','eol+','pkg-eol-plus','pkg-eolplus',
    'js','jumpstart','js+','jumpstart+','pkg-js','pkg-jumpstart','pkg-jumpstart-plus','pkg-jsplus'
  ) THEN '[
    {"time":"06:30","activity":"Zikir pagi & pernafasan fitrah"},
    {"time":"07:00","activity":"Minum air Afiyah"},
    {"time":"08:00","activity":"Sarapan ringan"},
    {"time":"10:00","activity":"Sesi bimbingan terapi (online/F2F)"},
    {"time":"13:00","activity":"Solat Zohor & rehat"},
    {"time":"14:00","activity":"Makan tengahari"},
    {"time":"17:00","activity":"Berkebun atau aktiviti luar"},
    {"time":"19:30","activity":"Solat Maghrib & Zikir bersanad"},
    {"time":"21:30","activity":"Tidur awal"}
  ]'::jsonb
  ELSE daily_schedule
END
WHERE LOWER(package_id) IN (
  'obd1','obdx1','obdy1','obp1','obpx1','obpy1',
  'pkg-obd1','pkg-obdx1','pkg-obdy1','pkg-obp1','pkg-obpx1','pkg-obpy1',
  'eol','pkg-eol','eol-plus','eol+','pkg-eol-plus','pkg-eolplus',
  'js','jumpstart','js+','jumpstart+','pkg-js','pkg-jumpstart','pkg-jumpstart-plus','pkg-jsplus'
)
AND (daily_schedule IS NULL OR daily_schedule = '[]'::jsonb);


-- ════════════════════════════════════════════════════════════════
-- schema/06_payments.sql
-- ════════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════════
-- SKEMA: PEMBAYARAN & PESANAN
-- Jadual: psy_payments, psy_orders
-- Gateway bayaran provider-agnostic (HitPay/Fiuu) via kolum gateway_*.
-- ═══════════════════════════════════════════════════════════════════

-- ──────────────────────────────────────────────────────────────
-- psy_payments — rekod bayaran (manual + gateway)
-- ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS psy_payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  receipt_ref TEXT UNIQUE NOT NULL,
  patient_id UUID REFERENCES psy_patients(id),
  user_id UUID REFERENCES psy_profiles(id) ON DELETE CASCADE,
  items JSONB DEFAULT '[]',
  subtotal NUMERIC(10,2) DEFAULT 0,
  service_charge NUMERIC(10,2) DEFAULT 0,
  sst NUMERIC(10,2) DEFAULT 0,
  total NUMERIC(10,2) NOT NULL,
  payment_method TEXT CHECK (payment_method IN ('fpx','card','transfer','ghl','manual','gateway')),
  status TEXT DEFAULT 'completed' CHECK (status IN ('pending','completed','refunded','failed')),
  ghl_transaction_id TEXT,
  notes TEXT,
  -- gateway bayaran (HitPay/Fiuu) — pending row dicipta sebelum redirect,
  -- webhook padankan gateway_ref & jalankan fulfillment ikut intent
  gateway_provider TEXT,                      -- 'hitpay' | 'fiuu' | NULL (manual)
  gateway_ref      TEXT,                      -- id rujukan dari gateway
  gateway_status   TEXT,                      -- status mentah dari gateway
  intent           JSONB DEFAULT '{}'::jsonb, -- niat bayaran utk fulfillment
  fulfilled_at     TIMESTAMPTZ,               -- bila fulfillment benar-benar jalan
  paid_at TIMESTAMPTZ DEFAULT now(),
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_psy_payments_patient ON psy_payments(patient_id);
CREATE INDEX IF NOT EXISTS idx_psy_payments_receipt ON psy_payments(receipt_ref);
CREATE INDEX IF NOT EXISTS idx_psy_payments_gateway_ref ON psy_payments (gateway_ref);

ALTER TABLE psy_payments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Patients read own payments" ON psy_payments;
CREATE POLICY "Patients read own payments" ON psy_payments FOR SELECT
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

-- pesakit hanya boleh insert baris bayaran MILIK SENDIRI
DROP POLICY IF EXISTS "Patients insert own payments" ON psy_payments;
CREATE POLICY "Patients insert own payments" ON psy_payments
  FOR INSERT WITH CHECK (
    patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid())
  );

DROP POLICY IF EXISTS "Staff manage all payments" ON psy_payments;
CREATE POLICY "Staff manage all payments" ON psy_payments FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

COMMENT ON COLUMN psy_payments.intent IS
  'Snapshot pendingItems + konteks bayaran; dibaca oleh payments-webhook untuk fulfillment idempotent selepas gateway sahkan.';

-- ──────────────────────────────────────────────────────────────
-- psy_orders — pesanan produk pesakit (penghantaran bekalan)
-- ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS psy_orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_ref TEXT UNIQUE NOT NULL,
  patient_id UUID NOT NULL,
  items JSONB NOT NULL DEFAULT '[]',
  total NUMERIC(10,2) DEFAULT 0,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending','paid','packed','shipped','delivered','cancelled')),
  delivery_method TEXT DEFAULT 'pos' CHECK (delivery_method IN ('pickup','pos')),
  delivery_address TEXT,
  courier TEXT,
  tracking_number TEXT,
  tracking_photo_url TEXT,
  notes TEXT,
  paid_at TIMESTAMPTZ,
  packed_at TIMESTAMPTZ,
  shipped_at TIMESTAMPTZ,
  delivered_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE psy_orders ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Patient view own orders" ON psy_orders;
CREATE POLICY "Patient view own orders" ON psy_orders FOR SELECT
  USING (patient_id = auth.uid());

DROP POLICY IF EXISTS "Patient insert own orders" ON psy_orders;
CREATE POLICY "Patient insert own orders" ON psy_orders FOR INSERT
  WITH CHECK (patient_id = auth.uid());

DROP POLICY IF EXISTS "Patient confirm delivery" ON psy_orders;
CREATE POLICY "Patient confirm delivery" ON psy_orders FOR UPDATE
  USING (patient_id = auth.uid() AND status = 'shipped')
  WITH CHECK (status = 'delivered');

DROP POLICY IF EXISTS "Staff manage orders" ON psy_orders;
CREATE POLICY "Staff manage orders" ON psy_orders FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- Nota trigger pada psy_orders (diletak bersama fungsi masing-masing):
--   trg_psy_order_deduct_inventory → 14_products_inventory.sql
--   trg_notify_staff_new_order     → 18_notifications_automations.sql

-- ──── psy_notifications: benarkan type 'payment' ────
-- GOTCHA (rujuk 27_affiliate.sql): jangan tulis semula senarai type inline
-- dalam CREATE TABLE — kekalkan semua nilai sedia ada + tambah 'payment'.
-- Dipakai oleh payments-webhook (notifyStaffPaymentReceived) supaya coach
-- + admin/manager dapat notifikasi loceng bila pesakit bayar apa-apa jenis
-- (pakej/KOB/temujanji/sambungan minggu), bukan sekadar shop_order.
DO $$
DECLARE
  v_types TEXT;
BEGIN
  SELECT COALESCE(string_agg(DISTINCT quote_literal(type), ','), '') INTO v_types
  FROM psy_notifications;

  IF v_types = '' THEN
    v_types := quote_literal('system');
  END IF;
  IF position('payment' in v_types) = 0 THEN
    v_types := v_types || ',' || quote_literal('payment');
  END IF;

  ALTER TABLE psy_notifications DROP CONSTRAINT IF EXISTS psy_notifications_type_check;
  EXECUTE format(
    'ALTER TABLE psy_notifications ADD CONSTRAINT psy_notifications_type_check CHECK (type IN (%s))',
    v_types
  );
END $$;


-- ════════════════════════════════════════════════════════════════
-- schema/07_treatment_plans.sql
-- ════════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════════════════
-- 07 — PELAN RAWATAN
-- Jadual: psy_treatment_plans, psy_plan_weekly_progress, psy_plan_check_ins,
--         psy_plan_compliance, psy_plan_week_overrides, psy_supply_disbursements
-- Fungsi: fn_auto_inactive_on_session_done, fn_complete_expired_treatments
-- ═══════════════════════════════════════════════════════════════════════════

-- ──────────────────────────────────────────────────────────────
-- psy_treatment_plans — pelan rawatan utama setiap pesakit
-- ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS psy_treatment_plans (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id          UUID NOT NULL REFERENCES psy_patients(id),
  doctor_id           UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  name                TEXT NOT NULL,
  template            TEXT,
  duration_unit       TEXT DEFAULT 'week',
  duration_weeks      INT DEFAULT 13,
  current_week        INT DEFAULT 1,
  coaching_schedule   JSONB DEFAULT '[]',
  status              TEXT DEFAULT 'active' CHECK (status IN ('draft','active','completed','paused')),
  -- jadual pilihan pesakit (wizard setup)
  preferred_pair      TEXT,                     -- legacy: fri_sat / sat_sun (tiada CHECK lagi)
  preferred_time_day1 TIME,                     -- jam sesi hari pertama
  preferred_time_day2 TIME,                     -- jam sesi hari kedua
  preferred_days      JSONB DEFAULT NULL,       -- [dow JS 0-6] ikut turutan sesi
  sessions_per_week   INT   DEFAULT NULL,       -- disalin dari pakej masa setup
  schedule_setup_at   TIMESTAMPTZ,
  start_date          DATE,                     -- anchor sebenar Minggu 1
  created_at          TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE psy_treatment_plans ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff manage plans" ON psy_treatment_plans;
CREATE POLICY "Staff manage plans" ON psy_treatment_plans FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "Patients read own plans" ON psy_treatment_plans;
CREATE POLICY "Patients read own plans" ON psy_treatment_plans FOR SELECT
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Patients insert own plans" ON psy_treatment_plans;
CREATE POLICY "Patients insert own plans" ON psy_treatment_plans FOR INSERT
  WITH CHECK (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

-- Patient boleh update plan sendiri untuk setup jadual sahaja
DROP POLICY IF EXISTS "Patients update own plan setup" ON psy_treatment_plans;
CREATE POLICY "Patients update own plan setup" ON psy_treatment_plans FOR UPDATE
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()))
  WITH CHECK (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Staff can read all treatment plans" ON psy_treatment_plans;
CREATE POLICY "Staff can read all treatment plans" ON psy_treatment_plans FOR SELECT
  USING (
    auth.uid() IN (SELECT id FROM psy_profiles WHERE role = 'staff')
    OR auth.uid() IN (SELECT user_id FROM psy_patients WHERE id = patient_id)
  );

COMMENT ON COLUMN psy_treatment_plans.start_date IS
  'Tarikh sebenar program bermula (anchor Minggu 1). NULL = fallback ke created_at. '
  'Guna untuk pesakit yang dimasukkan lewat / mid-program (cth dah di week 7/12) supaya '
  'semua tarikh sesi dikira dari tarikh sebenar, bukan tarikh plan dicipta.';

COMMENT ON COLUMN psy_treatment_plans.preferred_pair IS
  'Pasangan hari pilihan patient: fri_sat (Jumaat+Sabtu) atau sat_sun (Sabtu+Ahad).';

COMMENT ON COLUMN psy_treatment_plans.preferred_time_day1 IS
  'Jam pilihan hari pertama dalam pair (Jumaat untuk fri_sat, Sabtu untuk sat_sun).';

COMMENT ON COLUMN psy_treatment_plans.preferred_time_day2 IS
  'Jam pilihan hari kedua dalam pair (Sabtu untuk fri_sat, Ahad untuk sat_sun).';

COMMENT ON COLUMN psy_treatment_plans.schedule_setup_at IS
  'Bila patient siap setup jadual. NULL = belum setup, tunjuk wizard.';

COMMENT ON COLUMN psy_treatment_plans.preferred_days IS
  'Hari sesi terpilih dalam nombor getDay() JS (0=Ahad..6=Sabtu), ikut turutan sesi. Cth [5,6]=Jum+Sab, [6]=Sab sahaja. Sumber kebenaran baharu; fallback ke preferred_pair utk plan lama.';

COMMENT ON COLUMN psy_treatment_plans.sessions_per_week IS
  'Bilangan sesi/minggu (1-2) disalin dari pakej masa setup jadual.';

-- ──────────────────────────────────────────────────────────────
-- psy_plan_weekly_progress — rekod sesi mingguan (1 baris per sesi)
-- ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS psy_plan_weekly_progress (
  id                       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id                  UUID NOT NULL REFERENCES psy_treatment_plans(id) ON DELETE CASCADE,
  patient_id               UUID NOT NULL REFERENCES psy_patients(id) ON DELETE CASCADE,
  week_number              INT NOT NULL,
  session_day              INT DEFAULT 1
                             CONSTRAINT psy_plan_weekly_progress_session_day_check
                             CHECK (session_day BETWEEN 1 AND 7),
  status                   TEXT NOT NULL
                             CONSTRAINT psy_plan_weekly_progress_status_check
                             CHECK (status IN (
                               'pending','booked','hadir','reschedule','cancel','consultation_done',
                               'extension_pending_payment','extension_paid'
                             )),
  session_type             TEXT NOT NULL DEFAULT 'f2f' CHECK (session_type IN ('f2f','online')),
  session_date             TIMESTAMPTZ,
  meet_link                TEXT,
  score                    INT CHECK (score BETWEEN 0 AND 10),
  -- nota sesi coach (single source of truth)
  notes                    TEXT,
  mood_before              INT,
  mood_after               INT,
  goals_discussed          TEXT[],
  homework_given           TEXT[],
  coach_id                 UUID REFERENCES auth.users(id),
  coach_name               TEXT,
  substitute_coach_id      UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  coaching_checks          JSONB DEFAULT '{}',
  reaksi_pemulihan         JSONB DEFAULT '{}',  -- checklist Reaksi Pemulihan diisi coach masa sesi
  appointment_id           UUID,  -- FK → psy_appointments (dipasang di hujung 08_sessions_scheduling.sql)
  -- extension (minggu tambahan berbayar)
  is_extension             BOOLEAN DEFAULT false,
  extension_for_week       INT,
  extension_price          NUMERIC(10,2),
  extension_paid_at        TIMESTAMPTZ,
  absence_reason           TEXT,
  -- pengesahan kehadiran pesakit
  patient_confirmed        BOOLEAN DEFAULT NULL,
  patient_absence_reason   TEXT DEFAULT NULL,
  patient_confirmed_at     TIMESTAMPTZ DEFAULT NULL,
  confirm_reminder_sent_at TIMESTAMPTZ,  -- dedup peringatan (per sesi)
  confirm_escalated_at     TIMESTAMPTZ,  -- dedup escalation coach (per sesi)
  -- tandatangan pesakit (pilihan; path dalam bucket medical-reports)
  patient_signature_path   TEXT DEFAULT NULL,
  patient_signed_at        TIMESTAMPTZ DEFAULT NULL,
  patient_signed_name      TEXT DEFAULT NULL,
  updated_by               UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  updated_by_name          TEXT,
  created_at               TIMESTAMPTZ DEFAULT now(),
  updated_at               TIMESTAMPTZ DEFAULT now(),
  CONSTRAINT psy_plan_weekly_progress_plan_week_day_key UNIQUE (plan_id, week_number, session_day)
);

CREATE INDEX IF NOT EXISTS idx_psy_weekly_plan ON psy_plan_weekly_progress(plan_id);

CREATE INDEX IF NOT EXISTS idx_psy_weekly_patient ON psy_plan_weekly_progress(patient_id);

-- Index bantu enjin cari sesi belum-sahkan dalam tetingkap
CREATE INDEX IF NOT EXISTS idx_pwp_confirm_window
  ON psy_plan_weekly_progress (session_date)
  WHERE status = 'booked' AND patient_confirmed IS NULL;

ALTER TABLE psy_plan_weekly_progress ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff manage weekly progress" ON psy_plan_weekly_progress;
CREATE POLICY "Staff manage weekly progress" ON psy_plan_weekly_progress FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "Patients read own progress" ON psy_plan_weekly_progress;
CREATE POLICY "Patients read own progress" ON psy_plan_weekly_progress FOR SELECT
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Patients insert own progress" ON psy_plan_weekly_progress;
CREATE POLICY "Patients insert own progress" ON psy_plan_weekly_progress FOR INSERT
  WITH CHECK (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Patients update own progress" ON psy_plan_weekly_progress;
CREATE POLICY "Patients update own progress" ON psy_plan_weekly_progress FOR UPDATE
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Staff can read all weekly progress" ON psy_plan_weekly_progress;
CREATE POLICY "Staff can read all weekly progress" ON psy_plan_weekly_progress FOR SELECT
  USING (
    auth.uid() IN (SELECT id FROM psy_profiles WHERE role = 'staff')
    OR auth.uid() IN (SELECT user_id FROM psy_patients WHERE id = patient_id)
  );

COMMENT ON COLUMN psy_plan_weekly_progress.session_day IS
  '1 = sesi pertama dalam minggu (Jum/Sab), 2 = sesi kedua (Sab/Ahad). Default 1 untuk backward compat.';

COMMENT ON COLUMN psy_plan_weekly_progress.is_extension IS
  'true = minggu tambahan (extension) selepas miss sesi. Perlu bayar sebelum tempah.';

COMMENT ON COLUMN psy_plan_weekly_progress.extension_for_week IS
  'Refer minggu asal yang miss, untuk audit trail.';

COMMENT ON COLUMN psy_plan_weekly_progress.absence_reason IS
  'Sebab pesakit tidak hadir, diisi semasa pesakit menjadual semula (reschedule) sesi yang tertinggal. Dipaparkan kepada staff.';

COMMENT ON COLUMN psy_plan_weekly_progress.substitute_coach_id IS
  'Coach ganti untuk sesi ini sahaja — patient kekal bawah coach asal.';

COMMENT ON COLUMN psy_plan_weekly_progress.reaksi_pemulihan IS
  'Checklist Reaksi Pemulihan diisi coach masa sesi (tracking sahaja, tiada skor). Format: {item_key: true}';

-- Nota: trigger trg_notify_patient_new_week berada dalam
-- 18_notifications_automations.sql bersama fungsinya.

-- ──────────────────────────────────────────────────────────────
-- Fungsi: selesai semua sesi / pakej tamat → auto-complete pelan;
-- pakej sambungan (continuity) beratur di-auto-aktif, jika tiada
-- → pesakit ditanda inactive + outcome completed.
-- ──────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION fn_auto_inactive_on_session_done()
RETURNS TRIGGER AS $$
DECLARE
  v_patient_id    UUID;
  v_pstatus       TEXT;
  v_pkg_expired   BOOLEAN;
  v_all_done      BOOLEAN;
  v_has_core      BOOLEAN;
  v_next_pkg      TEXT;
  v_next_name     TEXT;
BEGIN
  IF NEW.status NOT IN ('hadir','consultation_done') THEN
    RETURN NEW;
  END IF;
  IF TG_OP = 'UPDATE' AND OLD.status = NEW.status THEN
    RETURN NEW;
  END IF;

  SELECT patient_id INTO v_patient_id FROM psy_treatment_plans WHERE id = NEW.plan_id;
  IF v_patient_id IS NULL THEN RETURN NEW; END IF;

  -- v_all_done: tiada sesi teras belum selesai + tiada minggu continuity BERBAYAR belum selesai.
  -- Minggu continuity ditanda extension_for_week = 0; absen (extension_for_week >= 1) tak menghalang.
  SELECT
    EXISTS (SELECT 1 FROM psy_plan_weekly_progress
            WHERE plan_id = NEW.plan_id AND COALESCE(is_extension,false) = false),
    NOT EXISTS (
      SELECT 1 FROM psy_plan_weekly_progress
      WHERE plan_id = NEW.plan_id
        AND status NOT IN ('hadir','consultation_done')
        AND (
          COALESCE(is_extension,false) = false
          OR (COALESCE(extension_for_week, -1) = 0 AND status <> 'extension_pending_payment')
        )
    )
    INTO v_has_core, v_all_done;

  SELECT status, (package_expires_at IS NOT NULL AND package_expires_at < now()),
         next_package_id, next_package_name
    INTO v_pstatus, v_pkg_expired, v_next_pkg, v_next_name
    FROM psy_patients WHERE id = v_patient_id;

  IF v_pstatus IN ('inactive','archived','deceased','deleted') THEN
    RETURN NEW;
  END IF;

  IF (v_has_core AND v_all_done) OR v_pkg_expired THEN
    -- Pelan lama SELESAI (kekal di History — tiada data dipadam).
    UPDATE psy_treatment_plans SET status = 'completed'
      WHERE id = NEW.plan_id AND status <> 'completed';

    IF v_next_pkg IS NOT NULL AND v_next_pkg <> '' THEN
      -- ── Ada pakej sambungan beratur → AUTO-AKTIF, pesakit KEKAL aktif ──
      UPDATE psy_patients
        SET active_package_id    = v_next_pkg,
            active_package_name  = COALESCE(v_next_name, active_package_name),
            package_purchased_at = now(),
            package_expires_at   = now() + interval '3 months',
            next_package_id      = NULL,
            next_package_name    = NULL,
            status               = 'active'
        WHERE id = v_patient_id;

      -- Purchase beratur → aktif (tempoh 3 bulan bermula dari pengaktifan).
      UPDATE psy_package_purchases
        SET status = 'active', expires_at = now() + interval '3 months'
        WHERE patient_id = v_patient_id AND package_id = v_next_pkg AND status = 'queued';

      -- Cipta pelan baru dari pakej sambungan (jika belum wujud). Baris mingguan dijana
      -- kemudian bila pesakit set jadual (sama seperti pakej baru biasa).
      INSERT INTO psy_treatment_plans
        (patient_id, name, template, duration_unit, duration_weeks, current_week, coaching_schedule, status)
      SELECT v_patient_id, COALESCE(pk.name,'Pakej') || ' Treatment Plan', pk.package_id,
             COALESCE(pk.duration_unit,'week'), COALESCE(pk.duration_weeks,12), 1,
             COALESCE(pk.coaching_schedule, '[]'::jsonb), 'active'
      FROM psy_packages pk
      WHERE pk.package_id = v_next_pkg
        AND NOT EXISTS (
          SELECT 1 FROM psy_treatment_plans
          WHERE patient_id = v_patient_id AND template = v_next_pkg AND status = 'active'
        );
    ELSE
      -- ── Tiada sambungan → pesakit inactive + outcome completed ──
      UPDATE psy_patients
        SET status = 'inactive',
            outcome_status = CASE WHEN outcome_status IS NULL OR outcome_status = ''
                                  THEN 'completed' ELSE outcome_status END,
            outcome_status_at = CASE WHEN outcome_status IS NULL OR outcome_status = ''
                                     THEN now() ELSE outcome_status_at END
        WHERE id = v_patient_id;
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_auto_inactive ON psy_plan_weekly_progress;

CREATE TRIGGER trg_auto_inactive
  AFTER UPDATE ON psy_plan_weekly_progress
  FOR EACH ROW
  EXECUTE FUNCTION fn_auto_inactive_on_session_done();

-- ──────────────────────────────────────────────────────────────
-- psy_plan_check_ins — check-in matlamat pillar (bio/psycho/social/spiritual)
-- ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS psy_plan_check_ins (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id      UUID NOT NULL REFERENCES psy_treatment_plans(id) ON DELETE CASCADE,
  patient_id   UUID NOT NULL REFERENCES psy_patients(id) ON DELETE CASCADE,
  pillar       TEXT NOT NULL CHECK (pillar IN ('bio','psycho','social','spiritual')),
  goal_index   INT NOT NULL,
  goal_text    TEXT,
  completed_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (plan_id, pillar, goal_index)
);

ALTER TABLE psy_plan_check_ins ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Patients manage own check-ins" ON psy_plan_check_ins;
CREATE POLICY "Patients manage own check-ins" ON psy_plan_check_ins FOR ALL
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()))
  WITH CHECK (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Staff read check-ins" ON psy_plan_check_ins;
CREATE POLICY "Staff read check-ins" ON psy_plan_check_ins FOR SELECT
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- ──────────────────────────────────────────────────────────────
-- psy_plan_compliance — kepatuhan rawatan per minggu per sesi
-- ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS psy_plan_compliance (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id     UUID NOT NULL REFERENCES psy_treatment_plans(id) ON DELETE CASCADE,
  patient_id  UUID NOT NULL REFERENCES psy_patients(id) ON DELETE CASCADE,
  week_number INT NOT NULL,
  session_day INT NOT NULL DEFAULT 1,
  madu_sudu   INT,
  nafas_kali  INT,
  bumi_minit  INT,
  berjemur    BOOLEAN,
  pantang     BOOLEAN,
  kelapa_kali INT,
  kolon_kali  INT,
  notes       TEXT,
  created_at  TIMESTAMPTZ DEFAULT now(),
  updated_at  TIMESTAMPTZ DEFAULT now(),
  CONSTRAINT psy_plan_compliance_plan_week_session_key UNIQUE (plan_id, week_number, session_day)
);

CREATE INDEX IF NOT EXISTS idx_psy_compliance_plan ON psy_plan_compliance(plan_id, week_number);

CREATE INDEX IF NOT EXISTS idx_psy_compliance_plan_week_sess
  ON psy_plan_compliance (plan_id, week_number, session_day);

ALTER TABLE psy_plan_compliance ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff manage compliance" ON psy_plan_compliance;
CREATE POLICY "Staff manage compliance" ON psy_plan_compliance FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "Patients manage own compliance" ON psy_plan_compliance;
CREATE POLICY "Patients manage own compliance" ON psy_plan_compliance FOR ALL
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()))
  WITH CHECK (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Staff can read all compliance" ON psy_plan_compliance;
CREATE POLICY "Staff can read all compliance" ON psy_plan_compliance FOR SELECT
  USING (
    auth.uid() IN (SELECT id FROM psy_profiles WHERE role = 'staff')
    OR auth.uid() IN (SELECT user_id FROM psy_patients WHERE id = patient_id)
  );

COMMENT ON COLUMN psy_plan_compliance.session_day IS
  'Sesi dalam minggu (1 atau 2) untuk kepatuhan ini. Default 1.';

-- ──────────────────────────────────────────────────────────────
-- psy_plan_week_overrides — pengecualian per-pesakit per-minggu
-- (bekalan, sesi, hari-sesi, bimbingan, aktiviti). Templat pakej = DEFAULT;
-- logik baca di UI: override ?? default_pakej.
-- ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS psy_plan_week_overrides (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id               UUID NOT NULL REFERENCES psy_treatment_plans(id) ON DELETE CASCADE,
  week_number           INT  NOT NULL,
  patient_id            UUID REFERENCES psy_patients(id) ON DELETE CASCADE,
  sessions_override     INT
                          CONSTRAINT psy_plan_week_overrides_sessions_override_check
                          CHECK (sessions_override BETWEEN 1 AND 7),
  supplies_override     JSONB,  -- NULL=ikut pakej; []=tiada bekalan; [..]=ganti penuh
  session_days_override JSONB,
  guidance_override     JSONB,
  aktiviti_override     JSONB,
  note                  TEXT,
  updated_by            UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  updated_at            TIMESTAMPTZ DEFAULT now(),
  CONSTRAINT psy_plan_week_overrides_plan_id_week_number_key UNIQUE (plan_id, week_number)
);

CREATE INDEX IF NOT EXISTS idx_psy_plan_week_overrides_plan
  ON psy_plan_week_overrides(plan_id, week_number);

ALTER TABLE psy_plan_week_overrides ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff manage week overrides" ON psy_plan_week_overrides;
CREATE POLICY "Staff manage week overrides" ON psy_plan_week_overrides FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "Patients read own week overrides" ON psy_plan_week_overrides;
CREATE POLICY "Patients read own week overrides" ON psy_plan_week_overrides FOR SELECT
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

COMMENT ON TABLE psy_plan_week_overrides IS
  'Pengecualian bekalan/sesi per-pesakit per-minggu. Kalau tiada baris = ikut default pakej sepenuhnya.';

COMMENT ON COLUMN psy_plan_week_overrides.session_days_override IS
  'Hari-sesi aktif minggu ini untuk pesakit ini. NULL=ikut pakej; [1,2]/[1]/[2].';

COMMENT ON COLUMN psy_plan_week_overrides.guidance_override IS
  'Bimbingan/Calling khas pesakit ini per-sesi. {"1":[...],"2":[...]}. NULL=ikut pakej; []=tiada.';

COMMENT ON COLUMN psy_plan_week_overrides.aktiviti_override IS
  'Aktiviti khas pesakit ini per-sesi. {"1":[...],"2":[...]}. NULL=ikut pakej; []=tiada.';

-- ──────────────────────────────────────────────────────────────
-- psy_supply_disbursements — barang diberi kepada pesakit dari stok inventori
-- ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS psy_supply_disbursements (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id    UUID NOT NULL REFERENCES psy_patients(id) ON DELETE CASCADE,
  item_id       UUID,  -- FK → psy_inventory_items (dipasang di hujung 14_products_inventory.sql)
  item_name     TEXT NOT NULL,
  unit          TEXT,
  qty           NUMERIC(10,2) NOT NULL,
  notes         TEXT,
  given_by      UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  given_by_name TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE psy_supply_disbursements ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "supply_disb_staff" ON psy_supply_disbursements;
CREATE POLICY "supply_disb_staff" ON psy_supply_disbursements FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- ──────────────────────────────────────────────────────────────
-- Fungsi: auto-complete pelan bila pakej pesakit tamat tempoh
-- (panggil manual atau via pg_cron harian)
-- ──────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION fn_complete_expired_treatments()
RETURNS TABLE (patient_id UUID, plan_id UUID, action TEXT) AS $$
BEGIN
  RETURN QUERY
  WITH expired_patients AS (
    SELECT p.id AS pat_id, p.user_id, p.active_package_name
    FROM psy_patients p
    WHERE p.active_package_id IS NOT NULL
      AND p.package_expires_at IS NOT NULL
      AND p.package_expires_at < now()
      AND (p.outcome_status IS NULL OR p.outcome_status <> 'completed')
  ),
  plan_updates AS (
    UPDATE psy_treatment_plans tp
       SET status = 'completed'
      FROM expired_patients ep
     WHERE tp.patient_id = ep.pat_id
       AND tp.status = 'active'
    RETURNING tp.id, tp.patient_id
  ),
  patient_updates AS (
    UPDATE psy_patients p
       SET outcome_status = 'completed'
      FROM expired_patients ep
     WHERE p.id = ep.pat_id
    RETURNING p.id
  ),
  notif_inserts AS (
    INSERT INTO psy_notifications (user_id, type, title, body, link, is_read)
    SELECT ep.user_id, 'plan',
           'Rawatan Anda Telah Tamat 🎉',
           'Tahniah atas penyelesaian rawatan ' || COALESCE(ep.active_package_name, 'anda') || '. Sila kongsi maklum balas anda.',
           'feedback.html',
           false
      FROM expired_patients ep
      WHERE NOT EXISTS (
        SELECT 1 FROM psy_notifications n
         WHERE n.user_id = ep.user_id
           AND n.type = 'plan'
           AND n.title LIKE 'Rawatan Anda Telah Tamat%'
      )
    RETURNING user_id
  )
  SELECT ep.pat_id, pu.id, 'completed'::TEXT
    FROM expired_patients ep
    LEFT JOIN plan_updates pu ON pu.patient_id = ep.pat_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION fn_complete_expired_treatments() IS
  'Auto-mark treatment plans + patient outcome_status sebagai completed bila pakej tamat. Insert notifikasi feedback. Boleh dipanggil manual atau via pg_cron.';

-- ──────────────────────────────────────────────────────────────
-- Pautan silang domain (jadual dari fail 04/05 yang rujuk pelan;
-- FK hanya boleh dipasang selepas psy_treatment_plans wujud)
-- ──────────────────────────────────────────────────────────────
ALTER TABLE psy_patient_documents DROP CONSTRAINT IF EXISTS psy_patient_documents_plan_id_fkey;
ALTER TABLE psy_patient_documents ADD CONSTRAINT psy_patient_documents_plan_id_fkey
  FOREIGN KEY (plan_id) REFERENCES psy_treatment_plans(id) ON DELETE CASCADE;

ALTER TABLE psy_continuity_offers DROP CONSTRAINT IF EXISTS psy_continuity_offers_plan_id_fkey;
ALTER TABLE psy_continuity_offers ADD CONSTRAINT psy_continuity_offers_plan_id_fkey
  FOREIGN KEY (plan_id) REFERENCES psy_treatment_plans(id) ON DELETE CASCADE;

-- Realtime — kehadiran mingguan auto-tolak ke UI (RLS dihormati)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'psy_plan_weekly_progress'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE psy_plan_weekly_progress;
  END IF;
END $$;


-- ════════════════════════════════════════════════════════════════
-- schema/08_sessions_scheduling.sql
-- ════════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════════
-- 08 — SESI & PENJADUALAN
-- Jadual: psy_appointments, psy_coaching_sessions, psy_clinic_closures,
--         psy_slot_date_overrides, psy_coaching_catalog, psy_services
-- Nota: psy_soap_notes telah DIBUANG (migrasi 20260626_remove_soap_consultation)
--       dan TIDAK dicipta semula di sini.
-- ═══════════════════════════════════════════════════════════════════

-- ──── psy_appointments ────
CREATE TABLE IF NOT EXISTS psy_appointments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id UUID REFERENCES psy_patients(id),
  staff_id UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  patient_name TEXT,
  staff_name TEXT,
  service TEXT NOT NULL,
  appointment_time TIMESTAMPTZ NOT NULL,
  duration_min INT DEFAULT 30,
  status TEXT DEFAULT 'scheduled' CHECK (status IN ('scheduled','checked_in','in_progress','completed','no_show','cancelled')),
  room TEXT,
  notes TEXT,
  ghl_booking_id TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_psy_appointments_time ON psy_appointments(appointment_time);
CREATE INDEX IF NOT EXISTS idx_psy_appointments_patient ON psy_appointments(patient_id);

ALTER TABLE psy_appointments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff manage appointments" ON psy_appointments;
CREATE POLICY "Staff manage appointments" ON psy_appointments FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "Patients read own appointments" ON psy_appointments;
CREATE POLICY "Patients read own appointments" ON psy_appointments FOR SELECT
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Patients insert own appointments" ON psy_appointments;
CREATE POLICY "Patients insert own appointments" ON psy_appointments FOR INSERT
  WITH CHECK (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Patients update own appointments" ON psy_appointments;
CREATE POLICY "Patients update own appointments" ON psy_appointments FOR UPDATE
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

-- ──── psy_coaching_sessions ────
CREATE TABLE IF NOT EXISTS psy_coaching_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id UUID REFERENCES psy_patients(id) ON DELETE CASCADE NOT NULL,
  coach_id UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  patient_name TEXT,
  pillar TEXT CHECK (pillar IN ('bio','psycho','social','spiritual')),
  session_date TIMESTAMPTZ DEFAULT now(),
  duration_min INT DEFAULT 60,
  mood_pre INT CHECK (mood_pre BETWEEN 1 AND 10),
  mood_post INT CHECK (mood_post BETWEEN 1 AND 10),
  notes TEXT,
  goals_discussed JSONB DEFAULT '[]',
  homework JSONB DEFAULT '[]',
  status TEXT DEFAULT 'completed' CHECK (status IN ('completed','no_show','cancelled')),
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_psy_coaching_patient ON psy_coaching_sessions(patient_id, session_date DESC);

ALTER TABLE psy_coaching_sessions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff manage coaching sessions" ON psy_coaching_sessions;
CREATE POLICY "Staff manage coaching sessions" ON psy_coaching_sessions FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "Patients read own coaching sessions" ON psy_coaching_sessions;
CREATE POLICY "Patients read own coaching sessions" ON psy_coaching_sessions FOR SELECT
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

-- ──── psy_clinic_closures ────
-- Kunci kalendar untuk cuti umum, Hari Raya & penutupan klinik ad-hoc.
CREATE TABLE IF NOT EXISTS psy_clinic_closures (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  closure_date DATE NOT NULL,
  label       TEXT NOT NULL,
  category    TEXT NOT NULL DEFAULT 'public_holiday'
              CHECK (category IN ('public_holiday','hari_raya','clinic_closed','training','other')),
  is_recurring BOOLEAN NOT NULL DEFAULT false,  -- ulangan tahunan pada MM-DD sama
  notes       TEXT,
  created_by  UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at  TIMESTAMPTZ DEFAULT now(),
  updated_at  TIMESTAMPTZ DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS uniq_clinic_closure_date ON psy_clinic_closures (closure_date);
CREATE INDEX IF NOT EXISTS idx_clinic_closure_date ON psy_clinic_closures (closure_date);

ALTER TABLE psy_clinic_closures ENABLE ROW LEVEL SECURITY;

-- Semua pengguna sah (staf + pesakit) boleh baca — diguna oleh tempahan + dashboard pesakit
DROP POLICY IF EXISTS "Anyone read clinic closures" ON psy_clinic_closures;
CREATE POLICY "Anyone read clinic closures" ON psy_clinic_closures
  FOR SELECT USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "Admin manage clinic closures" ON psy_clinic_closures;
CREATE POLICY "Admin manage clinic closures" ON psy_clinic_closures FOR ALL
  USING (EXISTS (
    SELECT 1 FROM psy_profiles
    WHERE id = auth.uid() AND role = 'staff'
      AND staff_role IN ('admin','manager','doctor','super_admin')
  ))
  WITH CHECK (EXISTS (
    SELECT 1 FROM psy_profiles
    WHERE id = auth.uid() AND role = 'staff'
      AND staff_role IN ('admin','manager','doctor','super_admin')
  ));

-- ──── psy_slot_date_overrides ────
-- Override per-tarikh: staf kunci/tawar slot tertentu pada tarikh tertentu.
CREATE TABLE IF NOT EXISTS psy_slot_date_overrides (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slot_date   DATE NOT NULL,
  slot_type   TEXT NOT NULL CHECK (slot_type IN ('kob','rawatan')),
  slot_start  TIME NOT NULL,
  is_offered  BOOLEAN NOT NULL DEFAULT true,
  note        TEXT,
  created_by  UUID,
  created_at  TIMESTAMPTZ DEFAULT now(),
  updated_at  TIMESTAMPTZ DEFAULT now(),
  UNIQUE (slot_date, slot_type, slot_start)
);

CREATE INDEX IF NOT EXISTS idx_slot_overrides_date ON psy_slot_date_overrides(slot_date, slot_type);

ALTER TABLE psy_slot_date_overrides ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone read slot overrides" ON psy_slot_date_overrides;
CREATE POLICY "Anyone read slot overrides" ON psy_slot_date_overrides FOR SELECT
  USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "Staff manage slot overrides" ON psy_slot_date_overrides;
CREATE POLICY "Staff manage slot overrides" ON psy_slot_date_overrides FOR ALL
  USING (EXISTS (
    SELECT 1 FROM psy_profiles
    WHERE id = auth.uid() AND role = 'staff'
      AND staff_role IN ('admin','manager','doctor','super_admin')
  ))
  WITH CHECK (EXISTS (
    SELECT 1 FROM psy_profiles
    WHERE id = auth.uid() AND role = 'staff'
      AND staff_role IN ('admin','manager','doctor','super_admin')
  ));

-- ──── psy_coaching_catalog ────
-- Katalog master untuk Bimbingan/Calling & Aktiviti/Rawatan.
CREATE TABLE IF NOT EXISTS psy_coaching_catalog (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name          TEXT NOT NULL,
  type          TEXT NOT NULL CHECK (type IN ('bimbingan','aktiviti')),
  description   TEXT,
  category      TEXT,             -- pengelompokan pilihan (cth: 'Terapi', 'Herba')
  is_active     BOOLEAN DEFAULT true,
  sort_order    INT DEFAULT 0,
  created_by    UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  created_by_name TEXT,
  created_at    TIMESTAMPTZ DEFAULT now(),
  updated_at    TIMESTAMPTZ DEFAULT now(),
  UNIQUE (name, type)
);

CREATE INDEX IF NOT EXISTS idx_coaching_catalog_type ON psy_coaching_catalog(type, sort_order);
CREATE INDEX IF NOT EXISTS idx_coaching_catalog_active ON psy_coaching_catalog(is_active);

ALTER TABLE psy_coaching_catalog ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone read catalog" ON psy_coaching_catalog;
CREATE POLICY "Anyone read catalog" ON psy_coaching_catalog
  FOR SELECT USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "Staff manage catalog" ON psy_coaching_catalog;
CREATE POLICY "Staff manage catalog" ON psy_coaching_catalog FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
  WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- ──── psy_services ────
-- Senarai service (jenis temujanji) yang klinik tawarkan.
CREATE TABLE IF NOT EXISTS psy_services (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  service_id    TEXT UNIQUE NOT NULL,
  name          TEXT NOT NULL,
  description   TEXT,
  icon          TEXT DEFAULT '⚕',
  price         NUMERIC(10,2) DEFAULT 0,
  duration_min  INT DEFAULT 30,
  sort_order    INT DEFAULT 100,
  is_active     BOOLEAN DEFAULT true,
  supplies      JSONB DEFAULT '[]'::jsonb,
  created_at    TIMESTAMPTZ DEFAULT now(),
  updated_at    TIMESTAMPTZ DEFAULT now()
);

COMMENT ON COLUMN psy_services.supplies IS
  'Senarai item inventory yang diguna per session service. Format: [{item_id, item_name, qty}].';

ALTER TABLE psy_services ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff manage services" ON psy_services;
CREATE POLICY "Staff manage services" ON psy_services FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "All authenticated read services" ON psy_services;
CREATE POLICY "All authenticated read services" ON psy_services FOR SELECT
  USING (auth.uid() IS NOT NULL);

-- ──── data rujukan ────

-- Katalog bimbingan/aktiviti lalai
INSERT INTO psy_coaching_catalog (name, type, category, sort_order) VALUES
  ('Bimbingan Reaksi',              'bimbingan', 'Reaksi',     10),
  ('Bimbingan Terapi Peminuman IB', 'bimbingan', 'Terapi',     20),
  ('Bimbingan Terapi Zikir Bersanad','bimbingan', 'Terapi',    30),
  ('Bimbingan Senaman Pernafasan',  'bimbingan', 'Senaman',    40),
  ('Bimbingan Pemakanan',           'bimbingan', 'Diet',       50),
  ('Herba Thoharah',                'aktiviti',  'Herba',      10),
  ('Terapi Madu LTHPG',             'aktiviti',  'Terapi',     20),
  ('Sesi Bekam',                    'aktiviti',  'Rawatan',    30),
  ('Senaman Pernafasan',            'aktiviti',  'Senaman',    40),
  ('Konsultasi Doktor',             'aktiviti',  'Konsultasi', 50),
  ('Berjemur Matahari',             'aktiviti',  'Amalan',     60)
ON CONFLICT (name, type) DO NOTHING;

-- Service umum
INSERT INTO psy_services (service_id, name, description, icon, price, duration_min, sort_order)
VALUES
  ('dna_test',     'DNA Test',                  'Ujian genetik untuk profil kesihatan',  '🧬', 350.00, 45, 20),
  ('blood_test',   'Blood Test',                'Pemeriksaan darah asas',                '🩸', 120.00, 20, 30),
  ('kob',          'Kursus Orientasi Bestari',  'Kursus orientasi pesakit baru',         '🎓',   0.00, 90, 40)
ON CONFLICT (service_id) DO NOTHING;

-- ──────────────────────────────────────────────────────────────
-- Pautan silang domain: psy_plan_weekly_progress (fail 07) → temujanji
-- ──────────────────────────────────────────────────────────────
ALTER TABLE psy_plan_weekly_progress DROP CONSTRAINT IF EXISTS psy_plan_weekly_progress_appointment_id_fkey;
ALTER TABLE psy_plan_weekly_progress ADD CONSTRAINT psy_plan_weekly_progress_appointment_id_fkey
  FOREIGN KEY (appointment_id) REFERENCES psy_appointments(id) ON DELETE SET NULL;


-- ════════════════════════════════════════════════════════════════
-- schema/09_kob.sql
-- ════════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════════
-- 09 — KOB (KURSUS ORIENTASI BESTARI)
-- Jadual: psy_kob_sessions, psy_kob_agreements, psy_kob_slot_config
-- ═══════════════════════════════════════════════════════════════════

-- ──── psy_kob_sessions ────
-- Tempahan, kehadiran & nota sesi KOB.
CREATE TABLE IF NOT EXISTS psy_kob_sessions (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id          UUID NOT NULL REFERENCES psy_patients(id) ON DELETE CASCADE,
  scheduled_at        TIMESTAMPTZ NOT NULL,
  mode                TEXT NOT NULL DEFAULT 'f2f' CHECK (mode IN ('f2f','online')),
  meet_link           TEXT,
  status              TEXT NOT NULL DEFAULT 'booked'
                      CHECK (status IN ('booked','hadir','completed','reschedule','cancelled')),

  -- Doktor yang tanda kehadiran (mungkin berbeza dengan yang selesaikan)
  doctor_hadir_id     UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  doctor_hadir_name   TEXT,
  hadir_at            TIMESTAMPTZ,

  -- Doktor yang tanda selesai
  doctor_selesai_id   UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  doctor_selesai_name TEXT,
  selesai_at          TIMESTAMPTZ,

  -- Nota klinikal doktor
  notes               TEXT,
  -- Laporan / dokumen sokongan yang dimuat naik untuk KOB ini
  documents           JSONB DEFAULT '[]',

  -- Soal selidik berstruktur diisi doktor semasa sesi
  questionnaire       JSONB DEFAULT '{}',

  -- Cadangan pakej rawatan oleh doktor semasa KOB
  recommended_package_id    TEXT,
  recommended_package_name  TEXT,
  recommended_package_price NUMERIC(10,2),
  recommended_at            TIMESTAMPTZ,
  recommended_by            UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  recommended_by_name       TEXT,
  package_payment_status    TEXT DEFAULT 'pending'
                            CHECK (package_payment_status IN ('pending','paid','skipped','na')),
  package_paid_at           TIMESTAMPTZ,
  package_receipt_ref       TEXT,

  reschedule_count    INT NOT NULL DEFAULT 0,
  reschedule_reason   TEXT,

  created_at          TIMESTAMPTZ DEFAULT now(),
  updated_at          TIMESTAMPTZ DEFAULT now()
);

COMMENT ON COLUMN psy_kob_sessions.questionnaire IS
  'Structured Q&A captured during KOB. Keys: anak[], tidur{}, gaya_hidup{}, masalah_kesihatan{} — see kob-detail.html for shape.';

COMMENT ON COLUMN psy_kob_sessions.recommended_package_id IS
  'Package recommended by doctor during KOB. Patient must pay before agreement signing.';

CREATE INDEX IF NOT EXISTS idx_kob_patient ON psy_kob_sessions(patient_id);
CREATE INDEX IF NOT EXISTS idx_kob_scheduled ON psy_kob_sessions(scheduled_at);
CREATE INDEX IF NOT EXISTS idx_kob_status ON psy_kob_sessions(status);

ALTER TABLE psy_kob_sessions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Patient read own KOB" ON psy_kob_sessions;
CREATE POLICY "Patient read own KOB" ON psy_kob_sessions FOR SELECT
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Patient book own KOB" ON psy_kob_sessions;
CREATE POLICY "Patient book own KOB" ON psy_kob_sessions FOR INSERT
  WITH CHECK (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Patient reschedule own KOB" ON psy_kob_sessions;
CREATE POLICY "Patient reschedule own KOB" ON psy_kob_sessions FOR UPDATE
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Staff manage KOB sessions" ON psy_kob_sessions;
CREATE POLICY "Staff manage KOB sessions" ON psy_kob_sessions FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- ──── psy_kob_agreements ────
-- Rekod perjanjian yang ditandatangani pesakit.
CREATE TABLE IF NOT EXISTS psy_kob_agreements (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id        UUID NOT NULL REFERENCES psy_patients(id) ON DELETE CASCADE,
  kob_session_id    UUID REFERENCES psy_kob_sessions(id) ON DELETE SET NULL,
  agreement_version TEXT NOT NULL DEFAULT 'ISW.SOP OB KOB FORM 03 CONTRACT 250711',
  patient_name      TEXT NOT NULL,
  patient_ic        TEXT NOT NULL,
  signature_url     TEXT NOT NULL,   -- tandatangan PNG mentah dalam storage
  signed_pdf_url    TEXT,            -- PDF terjana dengan tandatangan tertanam
  signed_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
  ip_address        TEXT,
  user_agent        TEXT,
  created_at        TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_kob_agreements_patient ON psy_kob_agreements(patient_id);

ALTER TABLE psy_kob_agreements ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Patient read own agreement" ON psy_kob_agreements;
CREATE POLICY "Patient read own agreement" ON psy_kob_agreements FOR SELECT
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Patient sign own agreement" ON psy_kob_agreements;
CREATE POLICY "Patient sign own agreement" ON psy_kob_agreements FOR INSERT
  WITH CHECK (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Patient cancel own unfinalized agreement" ON psy_kob_agreements;
CREATE POLICY "Patient cancel own unfinalized agreement" ON psy_kob_agreements FOR DELETE
  USING (
    patient_id IN (
      SELECT id FROM psy_patients
      WHERE user_id = auth.uid()
        AND (kob_status IS NULL OR kob_status != 'completed')
    )
  );

DROP POLICY IF EXISTS "Staff read all agreements" ON psy_kob_agreements;
CREATE POLICY "Staff read all agreements" ON psy_kob_agreements FOR SELECT
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "Staff insert agreement on behalf of patient" ON psy_kob_agreements;
CREATE POLICY "Staff insert agreement on behalf of patient" ON psy_kob_agreements FOR INSERT
  WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "Staff update agreement" ON psy_kob_agreements;
CREATE POLICY "Staff update agreement" ON psy_kob_agreements FOR UPDATE
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- ──── psy_kob_slot_config ────
-- Templat slot tetap untuk KOB & Rawatan (Rabu-Ahad). Admin boleh on/off
-- setiap slot; tiada kapasiti per-pesakit.
CREATE TABLE IF NOT EXISTS psy_kob_slot_config (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slot_type    TEXT NOT NULL DEFAULT 'kob' CHECK (slot_type IN ('kob','rawatan')),
  day_of_week  INT NOT NULL CHECK (day_of_week IN (0, 3, 4, 5, 6)),  -- 0=Ahad, 3=Rabu, 4=Khamis, 5=Jumaat, 6=Sabtu
  slot_start   TIME NOT NULL,
  slot_end     TIME NOT NULL,
  is_active    BOOLEAN NOT NULL DEFAULT true,
  label        TEXT NOT NULL,         -- paparan cth "7-9 pg"
  sort_order   INT NOT NULL DEFAULT 0,
  note         TEXT,                  -- nota peringatan untuk slot
  created_at   TIMESTAMPTZ DEFAULT now(),
  updated_at   TIMESTAMPTZ DEFAULT now(),
  CONSTRAINT psy_kob_slot_config_unique UNIQUE (slot_type, day_of_week, slot_start)
);

CREATE INDEX IF NOT EXISTS idx_kob_slots_day ON psy_kob_slot_config(day_of_week, is_active);

ALTER TABLE psy_kob_slot_config ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone read kob slots" ON psy_kob_slot_config;
CREATE POLICY "Anyone read kob slots" ON psy_kob_slot_config
  FOR SELECT USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "Admin manage kob slots" ON psy_kob_slot_config;
CREATE POLICY "Admin manage kob slots" ON psy_kob_slot_config FOR ALL
  USING (EXISTS (
    SELECT 1 FROM psy_profiles
    WHERE id = auth.uid() AND role = 'staff'
      AND staff_role IN ('admin','manager','doctor','super_admin')
  ))
  WITH CHECK (EXISTS (
    SELECT 1 FROM psy_profiles
    WHERE id = auth.uid() AND role = 'staff'
      AND staff_role IN ('admin','manager','doctor','super_admin')
  ));

-- ──── data rujukan ────
-- Slot templat: 5 slot × 2 jenis (kob, rawatan) × 5 hari (Rabu-Ahad)
INSERT INTO psy_kob_slot_config (slot_type, day_of_week, slot_start, slot_end, label, sort_order, is_active)
SELECT
  t.slot_type,
  d.day_of_week,
  s.slot_start::time,
  s.slot_end::time,
  s.label,
  s.sort_order,
  true
FROM
  (VALUES ('kob'), ('rawatan')) AS t(slot_type),
  (VALUES (3), (4), (5), (6), (0)) AS d(day_of_week),
  (VALUES
    ('07:00', '09:00', '7-9 pg',          1),
    ('09:30', '11:30', '9.30-11.30 pg',   2),
    ('14:00', '16:00', '2-4 ptg',         3),
    ('14:30', '16:30', '2.30-4.30 ptg',   4),
    ('16:30', '18:30', '4.30-6.30 ptg',   5)
  ) AS s(slot_start, slot_end, label, sort_order)
ON CONFLICT ON CONSTRAINT psy_kob_slot_config_unique DO NOTHING;


-- ════════════════════════════════════════════════════════════════
-- schema/10_vitals.sql
-- ════════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════════
-- SKEMA: VITALS (Bacaan Klinikal Pesakit)
-- Jadual: psy_vitals
-- Bacaan vital (BP, HR, SpO2, berat, gula, HbA1c dll.) direkod oleh
-- staff di klinik atau oleh pesakit sendiri; boleh diikat pada plan
-- rawatan + minggu, dengan tarikh & masa bacaan (berbilang sehari).
-- ═══════════════════════════════════════════════════════════════════

-- ──── psy_vitals ────
CREATE TABLE IF NOT EXISTS psy_vitals (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id       UUID REFERENCES psy_patients(id) ON DELETE CASCADE NOT NULL,
  recorded_by      UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  recorded_by_name TEXT,
  bp_systolic      INT,
  bp_diastolic     INT,
  heart_rate       INT,
  spo2             NUMERIC(5,2),
  temperature      NUMERIC(4,1),
  weight           NUMERIC(5,2),
  height           NUMERIC(5,1),
  bmi              NUMERIC(4,1),
  waist_cm         NUMERIC(5,1),
  rbs              NUMERIC(6,2),
  hba1c            NUMERIC(4,2),
  phq2_score       INT,
  medications      TEXT,
  notes            TEXT,
  source           TEXT NOT NULL DEFAULT 'staff' CHECK (source IN ('staff','patient_self')),
  plan_id          UUID REFERENCES psy_treatment_plans(id) ON DELETE SET NULL,
  week_number      INT,
  reading_date     DATE,
  reading_time     TIME,
  created_at       TIMESTAMPTZ DEFAULT now()
);

-- Indeks
CREATE INDEX IF NOT EXISTS idx_psy_vitals_patient ON psy_vitals(patient_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_vitals_plan_week
  ON psy_vitals(plan_id, week_number) WHERE plan_id IS NOT NULL;

-- RLS
ALTER TABLE psy_vitals ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff manage vitals" ON psy_vitals;
CREATE POLICY "Staff manage vitals" ON psy_vitals FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "Patients read own vitals" ON psy_vitals;
CREATE POLICY "Patients read own vitals" ON psy_vitals FOR SELECT
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

-- Pesakit hanya boleh masuk/edit bacaan sendiri (source = patient_self)
DROP POLICY IF EXISTS "Patients insert own vitals" ON psy_vitals;
CREATE POLICY "Patients insert own vitals" ON psy_vitals FOR INSERT
  WITH CHECK (
    source = 'patient_self'
    AND patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid())
  );

DROP POLICY IF EXISTS "Patients update own vitals" ON psy_vitals;
CREATE POLICY "Patients update own vitals" ON psy_vitals FOR UPDATE
  USING (
    source = 'patient_self'
    AND patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid())
  )
  WITH CHECK (
    source = 'patient_self'
    AND patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid())
  );

-- Komen
COMMENT ON COLUMN psy_vitals.hba1c IS 'HbA1c % (e.g. 6.5 = 6.5%)';
COMMENT ON COLUMN psy_vitals.source IS 'Who entered the reading: staff at clinic, or patient self-reported';
COMMENT ON COLUMN psy_vitals.reading_date IS 'Date the reading was actually taken (may differ from created_at for back-dated entries)';
COMMENT ON COLUMN psy_vitals.plan_id IS
  'Refer treatment plan masa vitals direkod. NULL kalau direkod luar konteks plan.';
COMMENT ON COLUMN psy_vitals.week_number IS
  'Minggu rawatan ke berapa bila vitals direkod. NULL kalau tiada plan aktif.';
COMMENT ON COLUMN psy_vitals.reading_time IS
  'Masa bacaan (HH:MM). Staff boleh rekod beberapa bacaan sehari — masa bezakan setiap satu.';


-- ════════════════════════════════════════════════════════════════
-- schema/11_checkins_kepatuhan.sql
-- ════════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════════
-- SKEMA: CATATAN HARIAN & KEPATUHAN
-- Jadual: psy_daily_checkins, psy_daily_completions,
--         psy_kepatuhan_item, psy_kepatuhan_log, psy_kepatuhan_weekly
-- Daily check-in pesakit (mood/emosi/tidur/madu), checklist aktiviti
-- harian, dan modul Kepatuhan (item config per fasa, log harian,
-- kelas A/B/C mingguan auto + override coach).
-- ═══════════════════════════════════════════════════════════════════

-- ──── psy_daily_checkins ────
CREATE TABLE IF NOT EXISTS psy_daily_checkins (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id     UUID REFERENCES psy_patients(id) ON DELETE CASCADE NOT NULL,
  checkin_date   DATE DEFAULT CURRENT_DATE NOT NULL,
  mood_score     INT CHECK (mood_score BETWEEN 1 AND 10),
  energy_score   INT CHECK (energy_score BETWEEN 1 AND 10),
  sleep_quality  INT CHECK (sleep_quality BETWEEN 1 AND 10),
  sleep_hours    NUMERIC(3,1),
  symptoms       JSONB DEFAULT '[]',
  activities     JSONB DEFAULT '[]',
  emotions       JSONB DEFAULT '[]',   -- senarai emosi dipilih
  sleep_time     TEXT,                 -- tidur pukul (HH:MM)
  wake_time      TEXT,                 -- bangun pukul (HH:MM)
  activity_level TEXT,                 -- tahap gangguan aktiviti harian
  madu_count     INT NOT NULL DEFAULT 0,
  notes          TEXT,
  created_at     TIMESTAMPTZ DEFAULT now(),
  UNIQUE (patient_id, checkin_date)
);

CREATE INDEX IF NOT EXISTS idx_psy_checkins_patient ON psy_daily_checkins(patient_id);

ALTER TABLE psy_daily_checkins ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Patients manage daily check-ins" ON psy_daily_checkins;
CREATE POLICY "Patients manage daily check-ins" ON psy_daily_checkins FOR ALL
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()))
  WITH CHECK (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Staff read daily check-ins" ON psy_daily_checkins;
CREATE POLICY "Staff read daily check-ins" ON psy_daily_checkins FOR SELECT
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "Staff can read all checkins" ON psy_daily_checkins;
CREATE POLICY "Staff can read all checkins"
  ON psy_daily_checkins FOR SELECT
  USING (
    auth.uid() IN (SELECT id FROM psy_profiles WHERE role = 'staff')
    OR auth.uid() IN (SELECT user_id FROM psy_patients WHERE id = patient_id)
  );

-- Staff isi Catatan Harian bagi pihak pesakit (mod staff borang kepatuhan)
DROP POLICY IF EXISTS "Staff manage daily checkins" ON psy_daily_checkins;
CREATE POLICY "Staff manage daily checkins" ON psy_daily_checkins FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
  WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

COMMENT ON COLUMN psy_daily_checkins.madu_count IS
  'Bilangan kali pesakit minum madu hari ini. Target dari psy_packages.madu_frequency_per_day.';

-- ──── psy_daily_completions ────
-- Checklist aktiviti harian pesakit: 1 baris per item ditanda per hari.
CREATE TABLE IF NOT EXISTS psy_daily_completions (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id   UUID NOT NULL REFERENCES psy_patients(id) ON DELETE CASCADE,
  log_date     DATE NOT NULL DEFAULT CURRENT_DATE,
  item_time    TEXT NOT NULL,      -- 'HH:MM' dari jadual
  activity     TEXT NOT NULL,      -- snapshot nama aktiviti
  completed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(patient_id, log_date, item_time)
);

CREATE INDEX IF NOT EXISTS idx_daily_completions_patient_date
  ON psy_daily_completions(patient_id, log_date);

ALTER TABLE psy_daily_completions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Patient manage own completions" ON psy_daily_completions;
CREATE POLICY "Patient manage own completions"
  ON psy_daily_completions FOR ALL
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()))
  WITH CHECK (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Staff read completions" ON psy_daily_completions;
CREATE POLICY "Staff read completions"
  ON psy_daily_completions FOR SELECT
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- ──── psy_kepatuhan_item ────
-- Config soalan checklist per fasa (coach boleh edit).
-- Kelas: A >= 85%, B 50-84%, C < 50% (cutoff lalai).
CREATE TABLE IF NOT EXISTS psy_kepatuhan_item (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  fasa        TEXT NOT NULL CHECK (fasa IN ('week1','week2_4','week5_12','fasa2','fasa3')),
  item_key    TEXT NOT NULL,
  label       TEXT NOT NULL,
  nota        TEXT,                       -- keterangan (cth singkatan LTH/IB)
  jenis_input TEXT NOT NULL DEFAULT 'pilih_satu'
              CHECK (jenis_input IN ('kiraan','pilih_satu','pilih_banyak')),
  period      TEXT NOT NULL DEFAULT 'harian'
              CHECK (period IN ('harian','mingguan','bulanan')),
  options     JSONB NOT NULL DEFAULT '[]', -- [{value,label,mata}] ; 'mata' = markah
  meta        JSONB NOT NULL DEFAULT '{}', -- cth {"target":3} utk item kiraan (madu)
  berskor     BOOLEAN NOT NULL DEFAULT true, -- false = tracking sahaja
  urutan      INT NOT NULL DEFAULT 0,
  aktif       BOOLEAN NOT NULL DEFAULT true,
  created_at  TIMESTAMPTZ DEFAULT now(),
  updated_at  TIMESTAMPTZ DEFAULT now(),
  UNIQUE (fasa, item_key)
);

CREATE INDEX IF NOT EXISTS idx_kepatuhan_item_fasa ON psy_kepatuhan_item(fasa, urutan);

ALTER TABLE psy_kepatuhan_item ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "kepatuhan_item_staff_all" ON psy_kepatuhan_item;
CREATE POLICY "kepatuhan_item_staff_all" ON psy_kepatuhan_item FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
  WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "kepatuhan_item_patient_read" ON psy_kepatuhan_item;
CREATE POLICY "kepatuhan_item_patient_read" ON psy_kepatuhan_item FOR SELECT
  USING (aktif = true);

-- ──── psy_kepatuhan_log ────
-- Jawapan pesakit, 1 baris / hari.
CREATE TABLE IF NOT EXISTS psy_kepatuhan_log (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id  UUID REFERENCES psy_patients(id) ON DELETE CASCADE NOT NULL,
  log_date    DATE NOT NULL DEFAULT CURRENT_DATE,
  fasa        TEXT NOT NULL CHECK (fasa IN ('week1','week2_4','week5_12','fasa2','fasa3')),
  jawapan     JSONB NOT NULL DEFAULT '{}', -- {item_key: value | [values]}
  skor_harian NUMERIC(5,2),                -- % markah hari itu (item berskor sahaja)
  created_at  TIMESTAMPTZ DEFAULT now(),
  updated_at  TIMESTAMPTZ DEFAULT now(),
  UNIQUE (patient_id, log_date)
);

CREATE INDEX IF NOT EXISTS idx_kepatuhan_log_patient ON psy_kepatuhan_log(patient_id, log_date);

ALTER TABLE psy_kepatuhan_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "kepatuhan_log_patient_all" ON psy_kepatuhan_log;
CREATE POLICY "kepatuhan_log_patient_all" ON psy_kepatuhan_log FOR ALL
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()))
  WITH CHECK (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "kepatuhan_log_staff_read" ON psy_kepatuhan_log;
CREATE POLICY "kepatuhan_log_staff_read" ON psy_kepatuhan_log FOR SELECT
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- Staff boleh upsert log bagi pihak pesakit (kepatuhan-fill.html / mod staff)
DROP POLICY IF EXISTS "kepatuhan_log_staff_write" ON psy_kepatuhan_log;
CREATE POLICY "kepatuhan_log_staff_write" ON psy_kepatuhan_log FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
  WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "Staff manage kepatuhan log" ON psy_kepatuhan_log;
CREATE POLICY "Staff manage kepatuhan log" ON psy_kepatuhan_log FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
  WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- ──── psy_kepatuhan_weekly ────
-- Kelas A/B/C dikira mingguan (auto + coach override).
CREATE TABLE IF NOT EXISTS psy_kepatuhan_weekly (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id     UUID REFERENCES psy_patients(id) ON DELETE CASCADE NOT NULL,
  minggu_mula    DATE NOT NULL,             -- tarikh Isnin minggu berkenaan
  fasa           TEXT,
  skor           NUMERIC(5,2),              -- % mingguan (purata item berskor)
  bil_hari_isi   INT DEFAULT 0,             -- berapa hari pesakit isi minggu itu
  kelas          CHAR(1) CHECK (kelas IN ('A','B','C')),           -- auto
  override_kelas CHAR(1) CHECK (override_kelas IN ('A','B','C')),  -- coach pinda
  override_by    UUID REFERENCES psy_profiles(id),
  override_at    TIMESTAMPTZ,
  nota_coach     TEXT,
  created_at     TIMESTAMPTZ DEFAULT now(),
  updated_at     TIMESTAMPTZ DEFAULT now(),
  UNIQUE (patient_id, minggu_mula)
);

CREATE INDEX IF NOT EXISTS idx_kepatuhan_weekly_patient ON psy_kepatuhan_weekly(patient_id, minggu_mula);

ALTER TABLE psy_kepatuhan_weekly ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "kepatuhan_weekly_patient_read" ON psy_kepatuhan_weekly;
CREATE POLICY "kepatuhan_weekly_patient_read" ON psy_kepatuhan_weekly FOR SELECT
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "kepatuhan_weekly_staff_all" ON psy_kepatuhan_weekly;
CREATE POLICY "kepatuhan_weekly_staff_all" ON psy_kepatuhan_weekly FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
  WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "kepatuhan_weekly_staff_write" ON psy_kepatuhan_weekly;
CREATE POLICY "kepatuhan_weekly_staff_write" ON psy_kepatuhan_weekly FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
  WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- ═══════════════════════════════════════════════════════════════════
-- SEED — item checklist kepatuhan WEEK 1
-- Set PENUH (11 item aktif) — sepadan checklist manual GForm asal.
-- Fasa lain (week2_4/week5_12/fasa2/fasa3) sengaja dibiar kosong;
-- roles/patient/kepatuhan.html carry-forward ke week1 bila fasa
-- semasa tiada item, jadi set ni terpakai sepanjang rawatan tanpa
-- perlu pecah ikut minggu/fasa (keputusan user 21 Jul 2026).
-- Madu (jenis kiraan) guna mata bertingkat: Tidak=0, 2x=1, 3x=2,
-- 4x=3, 5x=4, Lebih 5x=4 (maks 4 mata/item).
-- ═══════════════════════════════════════════════════════════════════
INSERT INTO psy_kepatuhan_item (fasa, item_key, label, nota, jenis_input, period, options, meta, berskor, urutan, aktif) VALUES
('week1','madu_lth_ib','Minum Madu (LTH / IB)','LTH: Lote Tree Honey · IB: Immune Booster Honey','kiraan','harian',
 '[{"value":"tidak","label":"Tidak minum","mata":0},{"value":"1","label":"1x","mata":1},{"value":"2","label":"2x","mata":2},{"value":"3","label":"3x","mata":3},{"value":"4","label":"4x","mata":4},{"value":"5","label":"5x","mata":5}]',
 '{"target":3}', true, 1, true),

('week1','madu_lthpg_yhpg','Minum Madu (LTHPG / YHPG)','LTHPG: Lote Tree Honey Pearl Garlic · YHPG: Young & Healthy Pearl Garlic','kiraan','harian',
 '[{"value":"tidak","label":"Tidak minum","mata":0},{"value":"1","label":"1x","mata":1},{"value":"2","label":"2x","mata":2},{"value":"3","label":"3x","mata":3},{"value":"4","label":"4x","mata":4},{"value":"5","label":"5x","mata":5}]',
 '{"target":3}', true, 2, true),

('week1','pernafasan_fitrah','Pernafasan Fitrah 30 Minit',NULL,'pilih_satu','harian',
 '[{"value":"cukup_30","label":"Cukup 30 minit","mata":2},{"value":"10_20","label":"10-20 minit","mata":1},{"value":"bawah_10","label":"Kurang dari 10 minit","mata":0}]',
 '{}', true, 3, true),

('week1','zikir_bersanad','Zikir Bersanad Subuh & Maghrib',NULL,'pilih_satu','harian',
 '[{"value":"subuh_maghrib","label":"Buat waktu Subuh & Maghrib","mata":2},{"value":"subuh","label":"Hanya waktu Subuh","mata":1},{"value":"maghrib","label":"Hanya waktu Maghrib","mata":1},{"value":"tidak","label":"Tidak buat","mata":0}]',
 '{}', true, 4, true),

('week1','terapi_bumi','Terapi Bumi',NULL,'pilih_satu','harian',
 '[{"value":"20_30","label":"20-30 minit","mata":2},{"value":"10_20","label":"10-20 minit","mata":1},{"value":"tidak","label":"Tidak buat","mata":0}]',
 '{}', true, 5, true),

('week1','berjemur','Berjemur Matahari',NULL,'pilih_satu','harian',
 '[{"value":"20_30","label":"20-30 minit","mata":2},{"value":"10_20","label":"10-20 minit","mata":1},{"value":"tidak","label":"Tidak buat","mata":0},{"value":"other","label":"Other","mata":1}]',
 '{}', true, 6, true),

('week1','air_kelapa','Air Kelapa',NULL,'pilih_satu','harian',
 '[{"value":"minum","label":"Minum","mata":2},{"value":"tidak","label":"Tidak minum","mata":0}]',
 '{}', true, 7, true),

('week1','yogurt','Yogurt',NULL,'pilih_satu','harian',
 '[{"value":"ambil","label":"Ambil","mata":2},{"value":"tidak","label":"Tidak ambil","mata":0}]',
 '{}', true, 8, true),

('week1','pantang_makan','Pantang Makan',NULL,'pilih_satu','harian',
 '[{"value":"baik","label":"Menjaga pantang dengan baik","mata":2},{"value":"separa","label":"Pantang tapi tak sepenuhnya","mata":1},{"value":"tidak","label":"Tidak menjaga pantang","mata":0}]',
 '{}', true, 9, true),

('week1','terapi_kolon','Terapi Kolon',NULL,'pilih_satu','harian',
 '[{"value":"buat","label":"Buat","mata":2},{"value":"tidak","label":"Tidak buat","mata":0}]',
 '{}', true, 10, true),

('week1','reaksi_pemulihan','Reaksi Pemulihan','Tracking sahaja — tidak dikira dalam skor','pilih_banyak','harian',
 '[{"value":"kerap_kencing","label":"Kerap Kencing"},{"value":"kerap_bab","label":"Kerap Buang Air Besar"},{"value":"gatal","label":"Gatal"},{"value":"selera","label":"Berubah selera makan"},{"value":"bp_naik","label":"Tekanan darah naik"},{"value":"bp_turun","label":"Tekanan darah turun"},{"value":"haid","label":"Haid banyak"},{"value":"kembung","label":"Perut berangin atau kembung"},{"value":"sakit_kepala","label":"Sakit kepala"},{"value":"resdung","label":"Resdung"},{"value":"mencucuk","label":"Rasa sakit mencucuk"},{"value":"radang","label":"Radang, bengkak, kebas, sakit urat"},{"value":"sakit_dada","label":"Sakit dada atau susah bernafas"},{"value":"demam","label":"Demam"},{"value":"lemah","label":"Lemah"},{"value":"mengantuk","label":"Mengantuk"},{"value":"batuk","label":"Batuk atau berkahak"},{"value":"tiada","label":"Tiada"}]',
 '{}', false, 11, true)

ON CONFLICT (fasa, item_key) DO UPDATE SET
  label       = EXCLUDED.label,
  nota        = EXCLUDED.nota,
  jenis_input = EXCLUDED.jenis_input,
  period      = EXCLUDED.period,
  options     = EXCLUDED.options,
  meta        = EXCLUDED.meta,
  berskor     = EXCLUDED.berskor,
  urutan      = EXCLUDED.urutan,
  aktif       = EXCLUDED.aktif,
  updated_at  = now();


-- ════════════════════════════════════════════════════════════════
-- schema/12_reaksi.sql
-- ════════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════════════════
-- REAKSI PEMULIHAN
-- Katalog simptom + kategori, engine saranan auto (Recovery Advice v2),
-- pemetaan simptom↔tindakan, log mesej WA berperingkat (queue + zon protokol),
-- dan laporan reaksi mingguan pesakit.
-- Jadual: psy_reaksi_item, psy_reaksi_kategori, psy_reaksi_actions,
--         psy_reaksi_action_map, psy_reaksi_advice_log, psy_patient_reaksi_reports
-- Nota: fungsi trigger trg_reaksi_advice_notify_emergency() dan
--       trg_patient_reaksi_notify_coach() ditakrif dalam fail skema notifikasi.
-- ═══════════════════════════════════════════════════════════════════════════

-- ──── psy_reaksi_item — katalog simptom reaksi pemulihan ────
-- Sumber tunggal reaksi pemulihan; diguna di checklist harian pesakit
-- (Catatan Harian item 5, grouped) + CRUD staff (kepatuhan.html).
CREATE TABLE IF NOT EXISTS psy_reaksi_item (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  kumpulan         TEXT NOT NULL,                     -- nama kumpulan, cth 'Pencernaan'
  ikon             TEXT,                              -- emoji kumpulan, cth '🍽️'
  label            TEXT NOT NULL,                     -- simptom, cth 'Kembung perut'
  urutan           INT  NOT NULL DEFAULT 0,           -- susunan global (kumpulan + item)
  aktif            BOOLEAN NOT NULL DEFAULT true,
  tahap_risiko     TEXT    NOT NULL DEFAULT 'rendah',
  boleh_pilih_teruk BOOLEAN NOT NULL DEFAULT true,  -- pesakit pilih Biasa/Teruk (Teruk→Merah terus); false = ikut tahap_risiko tetap
  markah_risiko    INT     NOT NULL DEFAULT 5,
  penerangan       TEXT,
  contoh           JSONB   NOT NULL DEFAULT '[]',
  perlu_pemantauan BOOLEAN NOT NULL DEFAULT false,
  tunjuk_ringkasan BOOLEAN NOT NULL DEFAULT true,
  notifikasi_coach BOOLEAN NOT NULL DEFAULT false,
  is_emergency     BOOLEAN NOT NULL DEFAULT false,
  created_at       TIMESTAMPTZ DEFAULT now(),
  updated_at       TIMESTAMPTZ DEFAULT now(),
  CONSTRAINT chk_reaksi_item_tahap CHECK (tahap_risiko IN ('rendah','sederhana','tinggi'))
);

CREATE INDEX IF NOT EXISTS idx_reaksi_item_tahap ON psy_reaksi_item(tahap_risiko);

ALTER TABLE psy_reaksi_item ENABLE ROW LEVEL SECURITY;

-- Semua staff boleh urus (tambah/edit/buang) senarai.
DROP POLICY IF EXISTS "Staff manage reaksi item" ON psy_reaksi_item;
CREATE POLICY "Staff manage reaksi item" ON psy_reaksi_item FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- Pesakit perlu BACA katalog reaksi utk wizard Catatan Harian (data rujukan sahaja)
DROP POLICY IF EXISTS "Authenticated boleh baca reaksi item" ON psy_reaksi_item;
CREATE POLICY "Authenticated boleh baca reaksi item" ON psy_reaksi_item FOR SELECT
  TO authenticated USING (true);

COMMENT ON COLUMN psy_reaksi_item.tahap_risiko  IS 'rendah (Green) / sederhana (Yellow) / tinggi (Red)';
COMMENT ON COLUMN psy_reaksi_item.boleh_pilih_teruk IS 'true = pesakit tanda Biasa/Teruk di Catatan Harian (Teruk→Merah terus, apa-apa tahap_risiko pun); false = tiada pilihan, terus ikut tahap_risiko';
COMMENT ON COLUMN psy_reaksi_item.markah_risiko IS 'Julat 1-100, semakin tinggi semakin berisiko';
COMMENT ON COLUMN psy_reaksi_item.contoh        IS 'Array string — contoh bagaimana simptom dirasai pesakit';
COMMENT ON COLUMN psy_reaksi_item.is_emergency  IS 'Simptom kecemasan: advice log ditanda emergency (tidak auto-hantar WA)';

-- ──── psy_reaksi_kategori — kategori/kumpulan reaksi ────
-- psy_reaksi_item.kumpulan kekal TEXT dan dipadankan dengan nama kategori.
CREATE TABLE IF NOT EXISTS psy_reaksi_kategori (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nama       TEXT NOT NULL UNIQUE,
  ikon       TEXT,
  penerangan TEXT,
  aktif      BOOLEAN NOT NULL DEFAULT true,
  urutan     INT NOT NULL DEFAULT 100,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE psy_reaksi_kategori ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff manage reaksi kategori" ON psy_reaksi_kategori;
CREATE POLICY "Staff manage reaksi kategori" ON psy_reaksi_kategori FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "Authenticated read reaksi kategori" ON psy_reaksi_kategori;
CREATE POLICY "Authenticated read reaksi kategori" ON psy_reaksi_kategori FOR SELECT
  USING (auth.uid() IS NOT NULL);

-- ──── psy_reaksi_actions — perpustakaan tindakan (Recovery Action) ────
-- Reusable merentasi simptom; doktor/admin kemaskini tanpa ubah kod.
CREATE TABLE IF NOT EXISTS psy_reaksi_actions (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title        TEXT NOT NULL,
  description  TEXT,
  priority     INT NOT NULL DEFAULT 100,   -- kecil = diutamakan/dipapar dulu
  is_emergency BOOLEAN NOT NULL DEFAULT false,
  aktif        BOOLEAN NOT NULL DEFAULT true,
  kategori     TEXT,
  jenis        TEXT NOT NULL DEFAULT 'am',
  panduan      TEXT,
  created_at   TIMESTAMPTZ DEFAULT now(),
  updated_at   TIMESTAMPTZ DEFAULT now(),
  CONSTRAINT chk_reaksi_actions_jenis CHECK (jenis IN ('am','pemakanan','gaya_hidup','terapi','pemerhatian','tindakan','kecemasan'))
);

ALTER TABLE psy_reaksi_actions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff manage reaksi actions" ON psy_reaksi_actions;
CREATE POLICY "Staff manage reaksi actions" ON psy_reaksi_actions FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "Authenticated read reaksi actions" ON psy_reaksi_actions;
CREATE POLICY "Authenticated read reaksi actions" ON psy_reaksi_actions FOR SELECT
  USING (auth.uid() IS NOT NULL);

COMMENT ON COLUMN psy_reaksi_actions.kategori IS 'Kategori bebas (biasanya kumpulan simptom, cth Pencernaan)';
COMMENT ON COLUMN psy_reaksi_actions.jenis    IS 'am/pemakanan/gaya_hidup/terapi/pemerhatian/tindakan/kecemasan';
COMMENT ON COLUMN psy_reaksi_actions.panduan  IS 'Panduan / cara penyediaan terperinci (teks; baris baharu dikekalkan)';

-- ──── psy_reaksi_action_map — pemetaan simptom ↔ tindakan (many-to-many) ────
CREATE TABLE IF NOT EXISTS psy_reaksi_action_map (
  symptom_id  UUID NOT NULL REFERENCES psy_reaksi_item(id)    ON DELETE CASCADE,
  action_id   UUID NOT NULL REFERENCES psy_reaksi_actions(id) ON DELETE CASCADE,
  created_at  TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (symptom_id, action_id)
);

CREATE INDEX IF NOT EXISTS idx_reaksi_action_map_symptom ON psy_reaksi_action_map(symptom_id);
CREATE INDEX IF NOT EXISTS idx_reaksi_action_map_action  ON psy_reaksi_action_map(action_id);

ALTER TABLE psy_reaksi_action_map ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff manage reaksi mapping" ON psy_reaksi_action_map;
CREATE POLICY "Staff manage reaksi mapping" ON psy_reaksi_action_map FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "Authenticated read reaksi mapping" ON psy_reaksi_action_map;
CREATE POLICY "Authenticated read reaksi mapping" ON psy_reaksi_action_map FOR SELECT
  USING (auth.uid() IS NOT NULL);

-- ──── psy_reaksi_advice_log — log mesej saranan (draf WA, satu baris = satu mesej) ────
-- Flow: pesakit submit Catatan Harian → client kumpul simptom ditanda →
-- padankan tindakan (psy_reaksi_action_map) → dedupe + susun ikut priority →
-- jana hingga 3 mesej (tindakan terus, gaya hidup +5 min, diet +10 min) →
-- queue send_after; cron reaksi-advice-send proses tiap 5 minit.
CREATE TABLE IF NOT EXISTS psy_reaksi_advice_log (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id       UUID NOT NULL REFERENCES psy_patients(id)     ON DELETE CASCADE,
  kepatuhan_log_id UUID REFERENCES psy_kepatuhan_log(id)         ON DELETE SET NULL,
  log_date         DATE NOT NULL DEFAULT CURRENT_DATE,
  symptoms         JSONB NOT NULL DEFAULT '[]',   -- ["Pencernaan::Kembung perut", ...]
  actions          JSONB NOT NULL DEFAULT '[]',   -- [{id,title,priority,is_emergency}] snapshot dijana
  message_text     TEXT NOT NULL,                 -- boleh diedit staff sebelum hantar
  is_emergency     BOOLEAN NOT NULL DEFAULT false,
  status           TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','sent','skipped')),
  msg_jenis        TEXT        NOT NULL DEFAULT 'tindakan',
  send_after       TIMESTAMPTZ NOT NULL DEFAULT now(),
  send_attempts    INT         NOT NULL DEFAULT 0,
  zon              TEXT,
  reviewed_by      UUID REFERENCES psy_profiles(id),
  reviewed_at      TIMESTAMPTZ,
  sent_by          UUID REFERENCES psy_profiles(id),
  sent_at          TIMESTAMPTZ,
  created_at       TIMESTAMPTZ DEFAULT now(),
  updated_at       TIMESTAMPTZ DEFAULT now(),
  CONSTRAINT chk_reaksi_advice_msg_jenis CHECK (msg_jenis IN ('tindakan','diet','gaya_hidup')),
  CONSTRAINT chk_reaksi_advice_zon       CHECK (zon IN ('hijau','kuning','merah'))
);

CREATE INDEX IF NOT EXISTS idx_reaksi_advice_log_status  ON psy_reaksi_advice_log(status, created_at);
CREATE INDEX IF NOT EXISTS idx_reaksi_advice_log_patient ON psy_reaksi_advice_log(patient_id, log_date);
CREATE INDEX IF NOT EXISTS idx_reaksi_advice_log_queue   ON psy_reaksi_advice_log(status, send_after);
CREATE INDEX IF NOT EXISTS idx_reaksi_advice_log_zon     ON psy_reaksi_advice_log(zon, log_date);

ALTER TABLE psy_reaksi_advice_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff manage advice log" ON psy_reaksi_advice_log;
CREATE POLICY "Staff manage advice log" ON psy_reaksi_advice_log FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "Patient insert own advice log" ON psy_reaksi_advice_log;
CREATE POLICY "Patient insert own advice log" ON psy_reaksi_advice_log FOR INSERT
  WITH CHECK (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

-- Pesakit perlu BACA baris sendiri (insert .select('id') utk auto-hantar WA)
DROP POLICY IF EXISTS "Patient read own advice log" ON psy_reaksi_advice_log;
CREATE POLICY "Patient read own advice log" ON psy_reaksi_advice_log FOR SELECT
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

-- Nota: trigger trg_reaksi_advice_notify_emergency (zon merah → notif coach)
-- berada dalam 18_notifications_automations.sql bersama fungsinya.

COMMENT ON COLUMN psy_reaksi_advice_log.msg_jenis     IS 'tindakan / diet / gaya_hidup — satu submission Poll Harian boleh jana hingga 3 mesej';
COMMENT ON COLUMN psy_reaksi_advice_log.send_after    IS 'Mesej hanya dihantar selepas waktu ini (queue; cron proses tiap 5 minit)';
COMMENT ON COLUMN psy_reaksi_advice_log.send_attempts IS 'Bilangan percubaan hantar gagal; cron berhenti cuba selepas 5';
COMMENT ON COLUMN psy_reaksi_advice_log.zon           IS 'hijau/kuning/merah — zon protokol dikira dari tahap_risiko tertinggi simptom submission ini';

-- ──── psy_patient_reaksi_reports — laporan reaksi mingguan pesakit ────
CREATE TABLE IF NOT EXISTS psy_patient_reaksi_reports (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id          UUID REFERENCES psy_treatment_plans(id) ON DELETE CASCADE NOT NULL,
  patient_id       UUID REFERENCES psy_patients(id)        ON DELETE CASCADE NOT NULL,
  week_number      INT  NOT NULL,
  reaksi_pemulihan JSONB DEFAULT '{}',
  submitted_at     TIMESTAMPTZ DEFAULT now(),
  updated_at       TIMESTAMPTZ DEFAULT now(),
  UNIQUE (plan_id, patient_id, week_number)
);

CREATE INDEX IF NOT EXISTS idx_patient_reaksi_plan_week
  ON psy_patient_reaksi_reports(plan_id, patient_id, week_number);

ALTER TABLE psy_patient_reaksi_reports ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Patient select own reaksi" ON psy_patient_reaksi_reports;
CREATE POLICY "Patient select own reaksi" ON psy_patient_reaksi_reports
  FOR SELECT USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Patient insert own reaksi" ON psy_patient_reaksi_reports;
CREATE POLICY "Patient insert own reaksi" ON psy_patient_reaksi_reports
  FOR INSERT WITH CHECK (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Patient update own reaksi" ON psy_patient_reaksi_reports;
CREATE POLICY "Patient update own reaksi" ON psy_patient_reaksi_reports
  FOR UPDATE USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Staff read reaksi reports" ON psy_patient_reaksi_reports;
CREATE POLICY "Staff read reaksi reports" ON psy_patient_reaksi_reports
  FOR SELECT USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- Nota: trigger trg_patient_reaksi_notify_coach berada dalam
-- 18_notifications_automations.sql bersama fungsinya.

-- ═══════════════════════════════════════════════════════════════════════════
-- DATA RUJUKAN (SEED)
-- ═══════════════════════════════════════════════════════════════════════════

-- ──── Seed psy_reaksi_item — 7 kumpulan / 48 simptom ────
-- (+ "Tiada simptom" setiap kumpulan; "Lain-lain" = free-text auto di UI).
-- Hanya seed bila jadual kosong supaya tak timpa tambahan staff (CRUD).
INSERT INTO psy_reaksi_item (kumpulan, ikon, label, urutan)
SELECT v.kumpulan, v.ikon, v.label, v.urutan
FROM (VALUES
  -- 1. Pencernaan
  ('Pencernaan','🍽️','Kembung perut',10),
  ('Pencernaan','🍽️','Banyak angin',20),
  ('Pencernaan','🍽️','Banyak sendawa',30),
  ('Pencernaan','🍽️','Sakit perut',40),
  ('Pencernaan','🍽️','Loya',50),
  ('Pencernaan','🍽️','Muntah',60),
  ('Pencernaan','🍽️','Hilang selera makan',70),
  ('Pencernaan','🍽️','Banyak membuang air besar',80),
  ('Pencernaan','🍽️','Cirit-birit',90),
  ('Pencernaan','🍽️','Sembelit',100),
  ('Pencernaan','🍽️','Najis hitam',110),
  ('Pencernaan','🍽️','Tiada simptom',120),
  -- 2. Peredaran Darah
  ('Peredaran Darah','🩸','Tekanan darah tinggi',130),
  ('Peredaran Darah','🩸','Tekanan darah rendah',140),
  ('Peredaran Darah','🩸','Berdebar-debar',150),
  ('Peredaran Darah','🩸','Tiada simptom',160),
  -- 3. Otot & Saraf
  ('Otot & Saraf','💪','Sakit badan',170),
  ('Otot & Saraf','💪','Sakit sendi',180),
  ('Otot & Saraf','💪','Sakit otot',190),
  ('Otot & Saraf','💪','Sakit pinggang',200),
  ('Otot & Saraf','💪','Sakit tengkuk',210),
  ('Otot & Saraf','💪','Sakit belikat',220),
  ('Otot & Saraf','💪','Kejang',230),
  ('Otot & Saraf','💪','Kebas',240),
  ('Otot & Saraf','💪','Tiada simptom',250),
  -- 4. Detoksifikasi
  ('Detoksifikasi','🧴','Mukus keluar',260),
  ('Detoksifikasi','🧴','Jerawat keluar',270),
  ('Detoksifikasi','🧴','Gatal-gatal',280),
  ('Detoksifikasi','🧴','Ruam',290),
  ('Detoksifikasi','🧴','Kulit mengelupas',300),
  ('Detoksifikasi','🧴','Kulit menjadi lebih sensitif',310),
  ('Detoksifikasi','🧴','Badan panas',320),
  ('Detoksifikasi','🧴','Badan sejuk',330),
  ('Detoksifikasi','🧴','Tiada simptom',340),
  -- 5. Emosi & Tenaga
  ('Emosi & Tenaga','⚡','Susah nak tidur (insomnia)',350),
  ('Emosi & Tenaga','⚡','Mengantuk luar biasa',360),
  ('Emosi & Tenaga','⚡','Kurang tenaga',370),
  ('Emosi & Tenaga','⚡','Cepat letih',380),
  ('Emosi & Tenaga','⚡','Lemah badan',390),
  ('Emosi & Tenaga','⚡','Mudah sebak',400),
  ('Emosi & Tenaga','⚡','Gelisah',410),
  ('Emosi & Tenaga','⚡','Badan terasa berat',420),
  ('Emosi & Tenaga','⚡','Tiada simptom',430),
  -- 6. Pernafasan
  ('Pernafasan','🫁','Sesak nafas',440),
  ('Pernafasan','🫁','Batuk',450),
  ('Pernafasan','🫁','Kahak',460),
  ('Pernafasan','🫁','Mukus',470),
  ('Pernafasan','🫁','Hidung berair',480),
  ('Pernafasan','🫁','Bersin',490),
  ('Pernafasan','🫁','Tiada simptom',500),
  -- 7. Bengkak & Cecair
  ('Bengkak & Cecair','💧','Bengkak kaki',510),
  ('Bengkak & Cecair','💧','Bengkak tangan',520),
  ('Bengkak & Cecair','💧','Bengkak muka',530),
  ('Bengkak & Cecair','💧','Edema',540),
  ('Bengkak & Cecair','💧','Tiada simptom',550)
) AS v(kumpulan, ikon, label, urutan)
WHERE NOT EXISTS (SELECT 1 FROM psy_reaksi_item);

-- ──── Seed psy_reaksi_kategori — dijana dari kumpulan psy_reaksi_item ────
INSERT INTO psy_reaksi_kategori (nama, ikon, urutan)
SELECT kumpulan, MAX(COALESCE(ikon, '')), MIN(COALESCE(urutan, 100))
FROM psy_reaksi_item GROUP BY kumpulan
ON CONFLICT (nama) DO NOTHING;

-- ──── Seed contoh psy_reaksi_actions + pemetaan (Pencernaan + Peredaran Darah) ────
-- Supaya engine boleh diuji serta-merta; staff tambah/kemaskini selebihnya
-- dari Staff Portal (bukan hardcode). Hanya jalan bila jadual masih kosong.
DO $$
DECLARE
  a_air_suam UUID; a_air_halia UUID; a_kurang_sukar UUID;
  a_elak_sejuk UUID; a_rehat UUID; a_elak_berminyak UUID; a_pernafasan UUID;
  s_kembung UUID; s_angin UUID; s_loya UUID; s_berdebar UUID;
BEGIN
  IF EXISTS (SELECT 1 FROM psy_reaksi_actions) THEN RETURN; END IF;

  INSERT INTO psy_reaksi_actions (title, priority) VALUES ('Minum air suam', 10) RETURNING id INTO a_air_suam;
  INSERT INTO psy_reaksi_actions (title, priority) VALUES ('Minum air halia', 20) RETURNING id INTO a_air_halia;
  INSERT INTO psy_reaksi_actions (title, priority) VALUES ('Kurangkan makanan sukar dihadam', 30) RETURNING id INTO a_kurang_sukar;
  INSERT INTO psy_reaksi_actions (title, priority) VALUES ('Elakkan minuman sejuk', 40) RETURNING id INTO a_elak_sejuk;
  INSERT INTO psy_reaksi_actions (title, priority) VALUES ('Rehat secukupnya', 50) RETURNING id INTO a_rehat;
  INSERT INTO psy_reaksi_actions (title, priority) VALUES ('Elakkan makanan berminyak', 60) RETURNING id INTO a_elak_berminyak;
  INSERT INTO psy_reaksi_actions (title, priority) VALUES ('Lakukan Pernafasan Fitrah', 70) RETURNING id INTO a_pernafasan;

  SELECT id INTO s_kembung  FROM psy_reaksi_item WHERE kumpulan='Pencernaan' AND label='Kembung perut' LIMIT 1;
  SELECT id INTO s_angin    FROM psy_reaksi_item WHERE kumpulan='Pencernaan' AND label='Banyak angin' LIMIT 1;
  SELECT id INTO s_loya     FROM psy_reaksi_item WHERE kumpulan='Pencernaan' AND label='Loya' LIMIT 1;
  SELECT id INTO s_berdebar FROM psy_reaksi_item WHERE kumpulan='Peredaran Darah' AND label='Berdebar-debar' LIMIT 1;

  IF s_kembung IS NOT NULL THEN
    INSERT INTO psy_reaksi_action_map (symptom_id, action_id) VALUES
      (s_kembung, a_air_suam), (s_kembung, a_air_halia), (s_kembung, a_kurang_sukar);
  END IF;
  IF s_angin IS NOT NULL THEN
    INSERT INTO psy_reaksi_action_map (symptom_id, action_id) VALUES
      (s_angin, a_air_halia), (s_angin, a_elak_sejuk);
  END IF;
  IF s_loya IS NOT NULL THEN
    INSERT INTO psy_reaksi_action_map (symptom_id, action_id) VALUES
      (s_loya, a_air_halia), (s_loya, a_rehat), (s_loya, a_elak_berminyak);
  END IF;
  IF s_berdebar IS NOT NULL THEN
    INSERT INTO psy_reaksi_action_map (symptom_id, action_id) VALUES
      (s_berdebar, a_pernafasan);
  END IF;
END $$;


-- ════════════════════════════════════════════════════════════════
-- schema/13_library_faq.sql
-- ════════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════════
-- SKEMA: Perpustakaan Kandungan & Soalan Lazim (Library + FAQ)
-- Jadual: psy_library_items, psy_library_bookmarks, psy_library_feedback,
--         psy_library_views, psy_library_categories,
--         psy_faq_sections, psy_faq_items
-- Fungsi: psy_library_bump_view (kiraan bacaan unik per pesakit)
-- ═══════════════════════════════════════════════════════════════════

-- ──── psy_library_items — kandungan perpustakaan ────

CREATE TABLE IF NOT EXISTS psy_library_items (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  item_id         TEXT UNIQUE,
  title           TEXT NOT NULL,
  description     TEXT,
  content_type    TEXT,
  content_url     TEXT,
  category        TEXT,
  icon            TEXT DEFAULT '📄',
  gradient        TEXT DEFAULT 'from-navy to-teal',
  content_body    TEXT,
  is_active       BOOLEAN DEFAULT true,
  sort_order      INT DEFAULT 0,
  thumbnail_url   TEXT,
  package_ids     TEXT[],
  media_type      TEXT,
  topic           TEXT,
  tags            TEXT[],
  duration        TEXT,
  attachment_url  TEXT,
  view_count      INT DEFAULT 0,
  created_by_name TEXT,
  status          TEXT,
  created_at      TIMESTAMPTZ DEFAULT now(),
  updated_at      TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_library_package_ids ON psy_library_items USING GIN (package_ids);
CREATE INDEX IF NOT EXISTS idx_library_media_type  ON psy_library_items(media_type);
CREATE INDEX IF NOT EXISTS idx_library_topic       ON psy_library_items(topic);
CREATE INDEX IF NOT EXISTS idx_library_tags        ON psy_library_items USING GIN (tags);

ALTER TABLE psy_library_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone read library" ON psy_library_items;
CREATE POLICY "Anyone read library" ON psy_library_items FOR SELECT USING (true);

DROP POLICY IF EXISTS "Staff manage library" ON psy_library_items;
CREATE POLICY "Staff manage library" ON psy_library_items FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

COMMENT ON COLUMN psy_library_items.package_ids IS
  'Package IDs (psy_packages.package_id) that can access this content. NULL/empty = public for all.';
COMMENT ON COLUMN psy_library_items.media_type IS
  'Jenis eksplisit: video | article | pdf | course | faq | image. Sumber tunggal untuk tab/KPI.';
COMMENT ON COLUMN psy_library_items.topic IS
  'Kategori topik (cth: Kesihatan Mental, Pemakanan). Berbeza dari category (warna kad).';
COMMENT ON COLUMN psy_library_items.tags IS 'Tag carian (max 5).';
COMMENT ON COLUMN psy_library_items.duration IS 'Tempoh video mm:ss (papar pada kad).';
COMMENT ON COLUMN psy_library_items.attachment_url IS 'Dokumen sokongan (PDF/DOC) opsional.';
COMMENT ON COLUMN psy_library_items.view_count IS 'Jumlah tontonan — increment bila pesakit buka library-detail.';
COMMENT ON COLUMN psy_library_items.created_by_name IS 'Nama staff yang cipta kandungan (Diterbitkan Oleh).';
COMMENT ON COLUMN psy_library_items.status IS
  'published | draft | inactive. is_active = (status=published). Pesakit nampak published sahaja.';

-- ──── psy_library_bookmarks — "Simpan" (bookmark) per pesakit ────

CREATE TABLE IF NOT EXISTS psy_library_bookmarks (
  user_id    UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  item_id    TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (user_id, item_id)
);

CREATE INDEX IF NOT EXISTS idx_lib_bookmark_user ON psy_library_bookmarks(user_id);

ALTER TABLE psy_library_bookmarks ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "own bookmarks" ON psy_library_bookmarks;
CREATE POLICY "own bookmarks" ON psy_library_bookmarks FOR ALL
  USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

-- ──── psy_library_feedback — "Adakah ini membantu?" 👍/👎 per pesakit ────

CREATE TABLE IF NOT EXISTS psy_library_feedback (
  user_id    UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  item_id    TEXT NOT NULL,
  helpful    BOOLEAN NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (user_id, item_id)
);

ALTER TABLE psy_library_feedback ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "own feedback" ON psy_library_feedback;
CREATE POLICY "own feedback" ON psy_library_feedback FOR ALL
  USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

-- ──── psy_library_views — log bacaan unik per (pesakit, kandungan) ────

CREATE TABLE IF NOT EXISTS psy_library_views (
  user_id    UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  item_id    TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (user_id, item_id)
);

ALTER TABLE psy_library_views ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "own views" ON psy_library_views;
CREATE POLICY "own views" ON psy_library_views FOR ALL
  USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

-- ──── psy_library_bump_view — increment view_count sekali per pesakit ────

CREATE OR REPLACE FUNCTION psy_library_bump_view(p_item_id TEXT)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_uid UUID := auth.uid();
BEGIN
  IF v_uid IS NULL THEN RETURN; END IF;             -- tak login → skip
  INSERT INTO psy_library_views(user_id, item_id)
    VALUES (v_uid, p_item_id)
    ON CONFLICT (user_id, item_id) DO NOTHING;
  IF FOUND THEN                                       -- baris baru = bacaan pertama
    UPDATE psy_library_items
      SET view_count = COALESCE(view_count,0) + 1
      WHERE item_id = p_item_id;
  END IF;
END $$;

GRANT EXECUTE ON FUNCTION psy_library_bump_view(TEXT) TO anon, authenticated;

-- ──── psy_library_categories — sumber tunggal kategori (content + faq) ────

CREATE TABLE IF NOT EXISTS psy_library_categories (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name        TEXT NOT NULL,
  sort_order  INT DEFAULT 0,
  is_active   BOOLEAN DEFAULT true,
  scope       TEXT DEFAULT 'content',
  created_at  TIMESTAMPTZ DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_library_cat_name ON psy_library_categories(lower(name));
CREATE UNIQUE INDEX IF NOT EXISTS uq_library_cat_scope_name
  ON psy_library_categories(scope, lower(name));

ALTER TABLE psy_library_categories ENABLE ROW LEVEL SECURITY;

-- Semua boleh baca (untuk dropdown/filter pesakit & staff)
DROP POLICY IF EXISTS "read_categories" ON psy_library_categories;
CREATE POLICY "read_categories" ON psy_library_categories FOR SELECT USING (true);

-- Staff urus
DROP POLICY IF EXISTS "staff_categories_all" ON psy_library_categories;
CREATE POLICY "staff_categories_all" ON psy_library_categories FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
  WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- ──── psy_faq_sections — bahagian FAQ ────

CREATE TABLE IF NOT EXISTS psy_faq_sections (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code       TEXT NOT NULL UNIQUE,
  title      TEXT NOT NULL,
  sort_order INT  NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE psy_faq_sections ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "faq_sections_staff_all" ON psy_faq_sections;
CREATE POLICY "faq_sections_staff_all" ON psy_faq_sections FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
  WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "faq_sections_public_read" ON psy_faq_sections;
CREATE POLICY "faq_sections_public_read" ON psy_faq_sections FOR SELECT USING (true);

-- ──── psy_faq_items — soal jawab individu dalam setiap bahagian ────

CREATE TABLE IF NOT EXISTS psy_faq_items (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  section_id UUID NOT NULL REFERENCES psy_faq_sections(id) ON DELETE CASCADE,
  soalan     TEXT NOT NULL,
  jawapan    TEXT NOT NULL,
  sort_order INT  NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_faq_items_section ON psy_faq_items(section_id, sort_order);

ALTER TABLE psy_faq_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "faq_items_staff_all" ON psy_faq_items;
CREATE POLICY "faq_items_staff_all" ON psy_faq_items FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
  WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "faq_items_public_read" ON psy_faq_items;
CREATE POLICY "faq_items_public_read" ON psy_faq_items FOR SELECT USING (true);

-- ═══════════════════════════════════════════════════════════════════
-- DATA RUJUKAN (SEED)
-- ═══════════════════════════════════════════════════════════════════

-- ──── Seed kandungan perpustakaan asas ────
INSERT INTO psy_library_items (item_id, title, description, content_type, category, icon, gradient, sort_order) VALUES
  ('bps-s-intro', 'Apa itu BPS-S model?', 'Dr. Hamzah menerangkan 4 pillar holistik Ibn Sina', 'Video · 8 min', 'navy', '🎥', 'from-navy to-teal', 1),
  ('santapan-panduan', 'Santapan Fitrah: Panduan Harian', 'Resipi + cara penyediaan untuk 7 hari pertama', 'Article · 5 min', 'green', '📝', 'from-green to-gold-dark', 2),
  ('zikir-syifa', 'Zikir Pagi Petang Syifa', 'Audio + transliterasi untuk amalan harian', 'Doa & Zikir', 'terracotta', '🕌', 'from-terracotta to-gold-dark', 3),
  ('breathing-muraqabah', 'Breathing & Muraqabah', 'Teknik pernafasan untuk ketenangan mental', 'Exercise · 15 min', 'gold', '🧘‍♀️', 'from-gold to-green', 4),
  ('faq-baru', '10 Soalan Lazim Pesakit Baru', 'Apa yang perlu anda tahu sebelum memulakan', 'FAQ', 'teal', '💬', 'from-teal to-navy', 5),
  ('mood-tracker', 'Mood & Progress Tracker', 'PDF printable untuk rekod harian', 'Worksheet', 'ink', '📊', 'from-navy to-terracotta', 6)
ON CONFLICT (item_id) DO NOTHING;

-- ──── Seed kategori kandungan (scope='content') ────
INSERT INTO psy_library_categories (name, sort_order)
SELECT v.name, v.ord FROM (VALUES
  ('Kesihatan Mental',1),('Pemakanan',2),('Kecergasan',3),('Gaya Hidup',4),
  ('Rawatan',5),('Spiritual',6),('Kewangan',7),('Tidur',8),('Lain-lain',99)
) AS v(name, ord)
WHERE NOT EXISTS (SELECT 1 FROM psy_library_categories c WHERE lower(c.name) = lower(v.name));

-- ──── Seed 13 kategori FAQ (scope='faq') ────
INSERT INTO psy_library_categories (name, scope, sort_order)
SELECT v.name, 'faq', v.ord FROM (VALUES
  ('Pendahuluan Rawatan Overhaul Body',1),
  ('Buku PET',2),
  ('Buku Sains Di Sebalik Overhaul Body',3),
  ('Sistem Perubatan Overhaul Body (Perubatan Herba)',4),
  ('Sistem Perubatan Overhaul Body (Perubatan Alami)',5),
  ('Sistem Perubatan Overhaul Body (Perubatan Minda)',6),
  ('Sistem Perubatan Overhaul Body (Perubatan Rohani)',7),
  ('5 Formula Rawatan Overhaul Body',8),
  ('Fasa Rawatan Overhaul Body (Fasa 1)',9),
  ('Fasa Rawatan Overhaul Body (Fasa 2)',10),
  ('Fasa Rawatan Overhaul Body (Fasa 3)',11),
  ('Diet dan Nutrisi',12),
  ('Laporan Progres Report',13)
) AS v(name, ord)
WHERE NOT EXISTS (
  SELECT 1 FROM psy_library_categories c
  WHERE c.scope = 'faq' AND lower(c.name) = lower(v.name)
);

-- ──── Seed bahagian FAQ asas ────
INSERT INTO psy_faq_sections (code, title, sort_order) VALUES
  ('umum',     'Soalan Umum',                1),
  ('rawatan',  'Tentang Rawatan',            2),
  ('pakej',    'Pakej & Pembayaran',         3),
  ('kepatuhan','Kepatuhan & Catatan Harian', 4),
  ('teknikal', 'Teknikal & Akaun',           5)
ON CONFLICT (code) DO NOTHING;


-- ════════════════════════════════════════════════════════════════
-- schema/14_products_inventory.sql
-- ════════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════════
-- SKEMA: PRODUK & INVENTORI
-- Jadual: psy_inventory_items, psy_inventory_requests, psy_products,
--         psy_procedure_kits, psy_bottle_returns
-- Katalog produk kedai (shop), inventori klinik dengan auto-request
-- bila stok rendah, kit prosedur, dan pulangan botol madu pesakit.
-- ═══════════════════════════════════════════════════════════════════

-- ──── psy_inventory_items ────
CREATE TABLE IF NOT EXISTS psy_inventory_items (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name                 TEXT NOT NULL,
  category             TEXT NOT NULL DEFAULT 'Bekalan Coaching',
  unit                 TEXT NOT NULL DEFAULT 'unit',
  qty_in_stock         NUMERIC(10,2) NOT NULL DEFAULT 0,
  min_qty              NUMERIC(10,2) NOT NULL DEFAULT 5,
  requires_approval    BOOLEAN NOT NULL DEFAULT false,
  notes                TEXT,
  max_qty              NUMERIC(10,2),
  auto_reorder_qty     NUMERIC(10,2),
  auto_reorder_enabled BOOLEAN DEFAULT false,
  last_auto_po_at      TIMESTAMPTZ,
  consumption_type     TEXT DEFAULT 'package'
                       CHECK (consumption_type IN ('package','service','general')),
  supplier_info        JSONB DEFAULT '{}'::jsonb,
  created_at           TIMESTAMPTZ DEFAULT now(),
  updated_at           TIMESTAMPTZ DEFAULT now()
);

-- RLS
ALTER TABLE psy_inventory_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff read inventory items" ON psy_inventory_items;
CREATE POLICY "Staff read inventory items" ON psy_inventory_items
  FOR SELECT USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "Admin manage inventory items" ON psy_inventory_items;
CREATE POLICY "Admin manage inventory items" ON psy_inventory_items
  FOR ALL USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff' AND staff_role IN ('admin','manager')));

-- Komen
COMMENT ON COLUMN psy_inventory_items.max_qty IS
  'Saiz stok penuh / target. Trigger auto-PO bila qty_in_stock <= 30% dari max_qty.';
COMMENT ON COLUMN psy_inventory_items.auto_reorder_qty IS
  'Kuantiti yang sistem cadang dalam auto-PO. Default: max_qty - qty_in_stock.';
COMMENT ON COLUMN psy_inventory_items.auto_reorder_enabled IS
  'true = auto-create purchase invoice bila stok rendah; false = manual sahaja.';
COMMENT ON COLUMN psy_inventory_items.last_auto_po_at IS
  'Tarikh auto-PO terakhir dijana — elak duplikat dalam tempoh pendek.';
COMMENT ON COLUMN psy_inventory_items.consumption_type IS
  'package = bekalan pakej (dynamic auto-calc); service = guna semasa service one-off; general = consumable umum (manual min sahaja).';
COMMENT ON COLUMN psy_inventory_items.supplier_info IS
  'Format: { name, cost_per_unit, lead_days, po_min, po_max }. Maklumat pembekal dan cadangan PO.';

-- ──── psy_inventory_requests ────
CREATE TABLE IF NOT EXISTS psy_inventory_requests (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  item_id           UUID REFERENCES psy_inventory_items(id) ON DELETE SET NULL,
  item_name         TEXT NOT NULL,
  qty_requested     NUMERIC(10,2) NOT NULL,
  unit_price        NUMERIC(10,2),
  total_amount      NUMERIC(10,2),
  reason            TEXT,
  status            TEXT NOT NULL DEFAULT 'pending_approval'
                    CHECK (status IN ('pending_approval','approved','rejected','purchased')),
  requested_by      UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  requested_by_name TEXT NOT NULL DEFAULT '',
  approved_by       UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  approved_at       TIMESTAMPTZ,
  rejected_reason   TEXT,
  purchased_at      TIMESTAMPTZ,
  is_auto_generated BOOLEAN DEFAULT false,
  created_at        TIMESTAMPTZ DEFAULT now(),
  updated_at        TIMESTAMPTZ DEFAULT now()
);

-- RLS
ALTER TABLE psy_inventory_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff read all requests" ON psy_inventory_requests;
CREATE POLICY "Staff read all requests" ON psy_inventory_requests
  FOR SELECT USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "Staff insert own requests" ON psy_inventory_requests;
CREATE POLICY "Staff insert own requests" ON psy_inventory_requests
  FOR INSERT WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "Manager admin update requests" ON psy_inventory_requests;
CREATE POLICY "Manager admin update requests" ON psy_inventory_requests
  FOR UPDATE USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff' AND staff_role IN ('admin','manager')));

COMMENT ON COLUMN psy_inventory_requests.is_auto_generated IS
  'true = dijana automatik bila stok ≤ 30%, false = manual request oleh staff.';

-- ──── Trigger: auto-request bila stok rendah ────
-- Threshold: 30% dari max_qty (fallback: min_qty). Hormat requires_approval,
-- duplicate guard (request pending/approved sedia ada) + cooldown 24 jam.
CREATE OR REPLACE FUNCTION psy_inventory_auto_request()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_threshold       NUMERIC;
  v_existing_count  INT;
  v_reorder_qty     NUMERIC;
  v_status          TEXT;
  v_target          NUMERIC;
BEGIN
  -- Hanya bertindak bila qty_in_stock benar-benar berubah & turun
  IF NEW.qty_in_stock IS NULL OR NEW.qty_in_stock = OLD.qty_in_stock THEN
    RETURN NEW;
  END IF;
  IF NEW.qty_in_stock > OLD.qty_in_stock THEN
    RETURN NEW;  -- stok naik (restock) — jangan trigger
  END IF;

  -- Kira threshold
  IF NEW.max_qty IS NOT NULL AND NEW.max_qty > 0 THEN
    v_threshold := NEW.max_qty * 0.30;
  ELSE
    v_threshold := COALESCE(NEW.min_qty, 0);
  END IF;

  IF v_threshold <= 0 THEN
    RETURN NEW;
  END IF;

  IF NEW.qty_in_stock > v_threshold THEN
    RETURN NEW;  -- masih di atas threshold
  END IF;

  -- Cooldown 24 jam
  IF NEW.last_auto_po_at IS NOT NULL
     AND NEW.last_auto_po_at > now() - INTERVAL '24 hours' THEN
    RETURN NEW;
  END IF;

  -- Duplicate guard
  SELECT COUNT(*) INTO v_existing_count
  FROM psy_inventory_requests
  WHERE item_id = NEW.id
    AND status IN ('pending_approval', 'approved');

  IF v_existing_count > 0 THEN
    RETURN NEW;
  END IF;

  -- Kira reorder qty
  IF NEW.max_qty IS NOT NULL AND NEW.max_qty > 0 THEN
    v_target := NEW.max_qty;
  ELSE
    v_target := COALESCE(NEW.min_qty, 0) * 3;
  END IF;

  v_reorder_qty := COALESCE(NEW.auto_reorder_qty,
                            GREATEST(1, v_target - NEW.qty_in_stock));

  -- Tentukan status ikut requires_approval
  v_status := CASE
                WHEN COALESCE(NEW.requires_approval, false) THEN 'pending_approval'
                ELSE 'approved'
              END;

  INSERT INTO psy_inventory_requests (
    item_id, item_name, qty_requested, unit_price, total_amount,
    reason, status, requested_by, requested_by_name, is_auto_generated
  ) VALUES (
    NEW.id,
    NEW.name,
    v_reorder_qty,
    NULL,
    NULL,
    format('Auto-trigger: stok %s%s ≤ threshold %s%s. Sila beli %s%s.',
           NEW.qty_in_stock, COALESCE(NEW.unit, ''),
           ROUND(v_threshold, 2), COALESCE(NEW.unit, ''),
           v_reorder_qty, COALESCE(NEW.unit, '')),
    v_status,
    NULL,
    'Sistem (Auto)',
    true
  );

  -- Tanda cooldown
  NEW.last_auto_po_at := now();

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_psy_inventory_auto_request ON psy_inventory_items;
CREATE TRIGGER trg_psy_inventory_auto_request
BEFORE UPDATE OF qty_in_stock ON psy_inventory_items
FOR EACH ROW
EXECUTE FUNCTION psy_inventory_auto_request();

COMMENT ON FUNCTION psy_inventory_auto_request() IS
  'Auto-cipta inventory_request bila stok turun ≤ 30% max_qty (atau ≤ min_qty kalau max_qty tiada). Hormat requires_approval untuk status.';

-- ──── psy_products ────
CREATE TABLE IF NOT EXISTS psy_products (
  id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id         TEXT UNIQUE NOT NULL,
  name               TEXT NOT NULL,
  description        TEXT,
  description_short  TEXT,
  category           TEXT,
  sku                TEXT,
  brand              TEXT,
  price              NUMERIC(10,2) DEFAULT 0,
  promo_price        NUMERIC(10,2),
  promo_until        DATE,
  stock              INT,
  min_stock          INT DEFAULT 5,
  unit               TEXT DEFAULT 'unit',
  track_inventory    BOOLEAN DEFAULT true,
  low_stock_alert    BOOLEAN DEFAULT true,
  inventory_item_id  UUID REFERENCES psy_inventory_items(id) ON DELETE SET NULL,
  icon               TEXT DEFAULT '📦',
  bg_color           TEXT DEFAULT 'bg-cream',
  image_url          TEXT,
  image_urls         JSONB DEFAULT '[]',
  weight_size        TEXT,
  supplier           TEXT,
  tags               JSONB DEFAULT '[]',
  notes              TEXT,
  status             TEXT DEFAULT 'active',
  is_active          BOOLEAN DEFAULT true,
  visible_in_shop    BOOLEAN DEFAULT true,
  featured           BOOLEAN DEFAULT false,
  online_purchase    BOOLEAN DEFAULT true,
  sort_order         INT DEFAULT 0,
  created_at         TIMESTAMPTZ DEFAULT now(),
  updated_at         TIMESTAMPTZ DEFAULT now()
);

-- RLS
ALTER TABLE psy_products ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone read products" ON psy_products;
CREATE POLICY "Anyone read products" ON psy_products FOR SELECT USING (true);

DROP POLICY IF EXISTS "Staff manage products" ON psy_products;
CREATE POLICY "Staff manage products" ON psy_products
  FOR ALL USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- Komen
COMMENT ON COLUMN psy_products.inventory_item_id IS
  'Link ke inventory item. Bila order status=paid, qty_in_stock auto-deduct ikut quantity dibeli.';
COMMENT ON COLUMN psy_products.image_url IS
  'URL gambar utama produk (single). Untuk gallery multi-gambar, guna image_urls (JSONB array).';

-- ──── Fungsi: auto-deduct inventori bila order paid ────
-- Trigger function untuk jadual order (items JSONB: [{product_id, qty, ...}]).
CREATE OR REPLACE FUNCTION psy_order_deduct_inventory()
RETURNS TRIGGER AS $$
DECLARE
  v_item       JSONB;
  v_product    psy_products%ROWTYPE;
  v_qty        NUMERIC;
BEGIN
  IF NEW.status = 'paid' AND (OLD.status IS DISTINCT FROM 'paid') THEN
    FOR v_item IN SELECT * FROM jsonb_array_elements(COALESCE(NEW.items, '[]'::jsonb))
    LOOP
      -- Match by product_id (text id) atau id (UUID) — support kedua-dua format
      SELECT * INTO v_product FROM psy_products
        WHERE product_id = v_item->>'product_id'
           OR id::text   = v_item->>'product_id'
        LIMIT 1;

      IF v_product.inventory_item_id IS NOT NULL THEN
        v_qty := COALESCE((v_item->>'qty')::numeric, (v_item->>'quantity')::numeric, 1);
        UPDATE psy_inventory_items
          SET qty_in_stock = GREATEST(0, qty_in_stock - v_qty),
              updated_at   = now()
          WHERE id = v_product.inventory_item_id;
      END IF;
    END LOOP;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger pada psy_orders (jadual dari 06_payments.sql) — diletak di sini
-- kerana fungsinya ditakrif di atas.
DROP TRIGGER IF EXISTS trg_psy_order_deduct_inventory ON psy_orders;
CREATE TRIGGER trg_psy_order_deduct_inventory
  AFTER UPDATE ON psy_orders
  FOR EACH ROW EXECUTE FUNCTION psy_order_deduct_inventory();

-- ──── psy_procedure_kits ────
-- Satu kit = set item inventori untuk satu prosedur (cth: IV Drip Setup).
CREATE TABLE IF NOT EXISTS psy_procedure_kits (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name         TEXT NOT NULL UNIQUE,
  description  TEXT,
  category     TEXT DEFAULT 'Umum',
  items        JSONB NOT NULL DEFAULT '[]'::jsonb,
  is_active    BOOLEAN DEFAULT true,
  created_by   UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  created_at   TIMESTAMPTZ DEFAULT now(),
  updated_at   TIMESTAMPTZ DEFAULT now()
);

COMMENT ON COLUMN psy_procedure_kits.items IS
  'Format: [{item_id, item_name, qty, unit}]. Senarai inventory item yang diperlukan per satu prosedur.';

-- RLS
ALTER TABLE psy_procedure_kits ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff manage kits" ON psy_procedure_kits;
CREATE POLICY "Staff manage kits" ON psy_procedure_kits FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- ──── psy_bottle_returns ────
-- Permohonan pulangan botol madu oleh pesakit.
CREATE TABLE IF NOT EXISTS psy_bottle_returns (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id           UUID REFERENCES psy_patients(id) ON DELETE CASCADE NOT NULL,
  patient_name         TEXT NOT NULL,
  qty                  INT NOT NULL CHECK (qty > 0),
  photo_urls           TEXT[] DEFAULT '{}',
  criteria_confirmed   JSONB NOT NULL DEFAULT '{}',
  notes                TEXT,
  status               TEXT NOT NULL DEFAULT 'pending'
                       CHECK (status IN ('pending','received','rejected')),
  reject_reason        TEXT,
  verified_by          UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  verified_by_name     TEXT,
  verified_at          TIMESTAMPTZ,
  created_at           TIMESTAMPTZ DEFAULT now(),
  updated_at           TIMESTAMPTZ DEFAULT now()
);

-- Indeks
CREATE INDEX IF NOT EXISTS idx_bottle_returns_patient ON psy_bottle_returns(patient_id);
CREATE INDEX IF NOT EXISTS idx_bottle_returns_status  ON psy_bottle_returns(status, created_at DESC);

-- RLS
ALTER TABLE psy_bottle_returns ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Patient manage own returns" ON psy_bottle_returns;
CREATE POLICY "Patient manage own returns" ON psy_bottle_returns
  FOR ALL USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()))
  WITH CHECK (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Staff read all returns" ON psy_bottle_returns;
CREATE POLICY "Staff read all returns" ON psy_bottle_returns
  FOR SELECT USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "Staff update returns" ON psy_bottle_returns;
CREATE POLICY "Staff update returns" ON psy_bottle_returns
  FOR UPDATE USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- Komen
COMMENT ON TABLE psy_bottle_returns IS
  'Permohonan pulangan botol madu patient. Chat thread guna psy_audit_log dengan meta.return_id.';
COMMENT ON COLUMN psy_bottle_returns.criteria_confirmed IS
  'JSONB: {tidak_berkarat, bersih, getah_ada, besi_kemas} - semua mesti true sebelum patient boleh submit.';
COMMENT ON COLUMN psy_bottle_returns.photo_urls IS
  'Array URL foto bukti botol (boleh upload multiple).';

-- ═══════════════════════════════════════════════════════════════════
-- DATA RUJUKAN (SEED)
-- ═══════════════════════════════════════════════════════════════════

-- ──── Seed: produk kedai ────
INSERT INTO psy_products (product_id, name, description, category, price, icon, bg_color, sort_order) VALUES
  ('madu-shifa-500g',  'Madu Shifa 500g',        'Pure raw honey · acacia',            'Madu',           85,  '🍯', 'bg-gold-light',       1),
  ('madu-kelulut',     'Madu Kelulut 400g',       'Stingless bee honey',                'Madu',          120,  '🍯', 'bg-gold-light',       2),
  ('jus-halia',        'Jus Halia Concentrate',   '250ml · 100% natural',               'Herba',          45,  '🌿', 'bg-green-light',      3),
  ('herba-zaitun',     'Minyak Zaitun Tulen',     '500ml · cold-pressed',               'Herba',          65,  '🫒', 'bg-green-light',      4),
  ('magnesium',        'Magnesium Glycinate',      '60 caps · 200mg',                    'Supplements',    55,  '💊', 'bg-navy-light',       5),
  ('vitamin-d',        'Vitamin D3 5000IU',        '90 softgels',                        'Supplements',    48,  '☀️', 'bg-gold-light',       6),
  ('santapan-fitrah',  'Santapan Fitrah Set',      '7-day starter pack',                 'Santapan Fitrah',220, '🌱', 'bg-terracotta-light', 7),
  ('rahsia-syifa',     'Rahsia Syifa Book',        'Ibn Sina & modern med',              'Books',          35,  '📖', 'bg-navy-light',       8),
  ('doa-syifa-book',   'Kitab Doa Syifa',          'Tafsir + transliterasi',             'Books',          28,  '📖', 'bg-terracotta-light', 9)
ON CONFLICT (product_id) DO NOTHING;

-- ──── Seed: item inventori lalai ISW (re-seed penuh) ────
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

-- ──── Seed: contoh kit prosedur ────
INSERT INTO psy_procedure_kits (name, description, category, items) VALUES
(
  'IV Drip Setup',
  'Set lengkap untuk satu sesi IV Saline Drip',
  'IV Therapy',
  '[
    {"item_id": null, "item_name": "IV Line",       "qty": 1, "unit": "unit"},
    {"item_id": null, "item_name": "Gloves",         "qty": 2, "unit": "pasang"},
    {"item_id": null, "item_name": "Alcohol Swab",   "qty": 3, "unit": "unit"},
    {"item_id": null, "item_name": "Cotton Ball",    "qty": 2, "unit": "unit"},
    {"item_id": null, "item_name": "Branula",        "qty": 1, "unit": "unit"},
    {"item_id": null, "item_name": "Plaster",        "qty": 2, "unit": "unit"},
    {"item_id": null, "item_name": "Scotch Tape",    "qty": 1, "unit": "unit"}
  ]'::jsonb
),
(
  'Blood Test Setup',
  'Set lengkap untuk pengambilan darah',
  'Diagnostik',
  '[
    {"item_id": null, "item_name": "Gloves",         "qty": 1, "unit": "pasang"},
    {"item_id": null, "item_name": "Alcohol Swab",   "qty": 2, "unit": "unit"},
    {"item_id": null, "item_name": "Cotton Ball",    "qty": 2, "unit": "unit"},
    {"item_id": null, "item_name": "Needle/Vacutainer","qty": 1, "unit": "unit"},
    {"item_id": null, "item_name": "Plaster",        "qty": 1, "unit": "unit"},
    {"item_id": null, "item_name": "Blood Tube",     "qty": 3, "unit": "tube"}
  ]'::jsonb
),
(
  'DNA Test Setup',
  'Set untuk pengambilan sampel DNA (buccal swab)',
  'Diagnostik',
  '[
    {"item_id": null, "item_name": "Gloves",         "qty": 1, "unit": "pasang"},
    {"item_id": null, "item_name": "DNA Swab",       "qty": 2, "unit": "unit"},
    {"item_id": null, "item_name": "DNA Collection Tube", "qty": 1, "unit": "unit"},
    {"item_id": null, "item_name": "Ziplock Bag",    "qty": 1, "unit": "unit"}
  ]'::jsonb
)
ON CONFLICT DO NOTHING;

-- ──────────────────────────────────────────────────────────────
-- Pautan silang domain: psy_supply_disbursements (fail 07) → item inventori
-- ──────────────────────────────────────────────────────────────
ALTER TABLE psy_supply_disbursements DROP CONSTRAINT IF EXISTS psy_supply_disbursements_item_id_fkey;
ALTER TABLE psy_supply_disbursements ADD CONSTRAINT psy_supply_disbursements_item_id_fkey
  FOREIGN KEY (item_id) REFERENCES psy_inventory_items(id) ON DELETE SET NULL;


-- ════════════════════════════════════════════════════════════════
-- schema/15_letters.sql
-- ════════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════════
-- SKEMA: SURAT (Sistem Surat Rasmi)
-- Jadual: psy_letter_templates, psy_letter_requests, psy_letter_issued,
--         psy_letter_auto_fields
-- Admin define template (body + placeholder fields + approver spesifik),
-- pesakit mohon surat, staff/approver approve & sign → surat dikeluarkan.
-- Auto-fields ([NAMA], [IC], ...) diisi automatik dari kolum DB.
-- RLS staff guna user_has_perm('communication', ...).
-- ═══════════════════════════════════════════════════════════════════

-- ──── psy_letter_templates ────
CREATE TABLE IF NOT EXISTS psy_letter_templates (
  id                         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name                       TEXT NOT NULL,
  description                TEXT,
  category                   TEXT NOT NULL DEFAULT 'patient'
                             CHECK (category IN ('patient','internal')),
  jenis_surat                TEXT,
  language                   TEXT DEFAULT 'ms',
  recipient                  TEXT,                 -- "Pengurus Besar, KWSP, ..."
  title                      TEXT,                 -- "PERMOHONAN PENGELUARAN AHLI KWSP"
  body                       TEXT NOT NULL,        -- plain text + [PLACEHOLDER]
  fields                     JSONB NOT NULL DEFAULT '[]',  -- [{key,label,type,autofill}]
  assigned_signer_id         UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  requires_specific_approver BOOLEAN DEFAULT false,
  is_active                  BOOLEAN DEFAULT true,
  created_by                 UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  created_by_name            TEXT,
  created_at                 TIMESTAMPTZ DEFAULT now(),
  updated_at                 TIMESTAMPTZ DEFAULT now()
);

-- Indeks
CREATE INDEX IF NOT EXISTS idx_letter_tpl_active ON psy_letter_templates(category, is_active);

-- RLS
ALTER TABLE psy_letter_templates ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone read templates" ON psy_letter_templates;
CREATE POLICY "Anyone read templates" ON psy_letter_templates
  FOR SELECT USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "Staff manage templates" ON psy_letter_templates;
CREATE POLICY "Staff manage templates" ON psy_letter_templates
  FOR ALL USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
  WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "tpl_select" ON psy_letter_templates;
CREATE POLICY "tpl_select" ON psy_letter_templates FOR SELECT
  USING (user_has_perm('communication','view'));

DROP POLICY IF EXISTS "tpl_insert" ON psy_letter_templates;
CREATE POLICY "tpl_insert" ON psy_letter_templates FOR INSERT
  WITH CHECK (user_has_perm('communication','create'));

DROP POLICY IF EXISTS "tpl_update" ON psy_letter_templates;
CREATE POLICY "tpl_update" ON psy_letter_templates FOR UPDATE
  USING (user_has_perm('communication','edit'))
  WITH CHECK (user_has_perm('communication','edit'));

DROP POLICY IF EXISTS "tpl_delete" ON psy_letter_templates;
CREATE POLICY "tpl_delete" ON psy_letter_templates FOR DELETE
  USING (user_has_perm('communication','delete'));

-- Komen
COMMENT ON COLUMN psy_letter_templates.jenis_surat IS
  'Sub-category template (cth: Tujuan Rawatan, KWSP, RELA). Boleh diisi bebas.';
COMMENT ON COLUMN psy_letter_templates.language IS
  'Bahasa default template: ms (Bahasa Melayu) atau en (English).';
COMMENT ON COLUMN psy_letter_templates.is_active IS
  'Template aktif boleh diguna pakai. Tak aktif = draft / disembunyikan dari list patient.';
COMMENT ON COLUMN psy_letter_templates.assigned_signer_id IS
  'Staff yang ditetapkan untuk sign template ini. NULL = mana-mana staff dengan permission boleh sign.';
COMMENT ON COLUMN psy_letter_templates.requires_specific_approver IS
  'true = HANYA assigned_signer (atau super_admin) boleh approve/sign. false = pilihan default sahaja.';

-- ──── psy_letter_requests ────
-- Permintaan surat dari patient.
CREATE TABLE IF NOT EXISTS psy_letter_requests (
  id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id         UUID REFERENCES psy_patients(id) ON DELETE CASCADE NOT NULL,
  patient_name       TEXT NOT NULL,
  template_code      TEXT NOT NULL,
  template_name      TEXT NOT NULL,
  reason             TEXT,
  field_values       JSONB DEFAULT '{}',
  status             TEXT NOT NULL DEFAULT 'pending'
                     CHECK (status IN ('pending','issued','rejected','cancelled')),
  reject_reason      TEXT,
  assigned_signer_id UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  approved_by        UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  approved_at        TIMESTAMPTZ,
  created_at         TIMESTAMPTZ DEFAULT now(),
  updated_at         TIMESTAMPTZ DEFAULT now()
);

-- Indeks
CREATE INDEX IF NOT EXISTS idx_letter_req_patient ON psy_letter_requests(patient_id);
CREATE INDEX IF NOT EXISTS idx_letter_req_status  ON psy_letter_requests(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_letter_req_signer  ON psy_letter_requests(assigned_signer_id, status);

-- RLS
ALTER TABLE psy_letter_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Patient manage own letter requests" ON psy_letter_requests;
CREATE POLICY "Patient manage own letter requests" ON psy_letter_requests
  FOR ALL USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()))
  WITH CHECK (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "req_staff_read" ON psy_letter_requests;
CREATE POLICY "req_staff_read" ON psy_letter_requests FOR SELECT
  USING (user_has_perm('communication','view'));

DROP POLICY IF EXISTS "req_staff_update" ON psy_letter_requests;
CREATE POLICY "req_staff_update" ON psy_letter_requests FOR UPDATE
  USING (user_has_perm('communication','edit'))
  WITH CHECK (user_has_perm('communication','edit'));

DROP POLICY IF EXISTS "req_staff_delete" ON psy_letter_requests;
CREATE POLICY "req_staff_delete" ON psy_letter_requests FOR DELETE
  USING (user_has_perm('communication','delete'));

-- Komen
COMMENT ON COLUMN psy_letter_requests.assigned_signer_id IS
  'Snapshot signer ID dari template masa request dicipta. Tak berubah walau template di-edit kemudian.';

-- ──── psy_letter_issued ────
-- Surat yang telah dikeluarkan & disign.
CREATE TABLE IF NOT EXISTS psy_letter_issued (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id      UUID REFERENCES psy_letter_requests(id) ON DELETE SET NULL,
  patient_id      UUID REFERENCES psy_patients(id) ON DELETE CASCADE,  -- nullable: NULL = internal document
  patient_name    TEXT NOT NULL,
  template_code   TEXT NOT NULL,
  template_name   TEXT NOT NULL,
  field_values    JSONB NOT NULL DEFAULT '{}',
  ref_number      TEXT,  -- cth: ISW/RELA/2026/0001
  signed_by       UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  signed_by_name  TEXT NOT NULL,
  signed_by_role  TEXT,
  signature_url   TEXT,  -- snapshot signature staff masa sign
  file_url        TEXT,
  file_name       TEXT,
  file_size       INT,
  signed_at       TIMESTAMPTZ DEFAULT now(),
  created_at      TIMESTAMPTZ DEFAULT now()
);

-- Indeks
CREATE INDEX IF NOT EXISTS idx_letter_issued_patient ON psy_letter_issued(patient_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_letter_issued_code    ON psy_letter_issued(template_code);

-- RLS
ALTER TABLE psy_letter_issued ENABLE ROW LEVEL SECURITY;

-- Patient hanya boleh baca surat sendiri
DROP POLICY IF EXISTS "issued_patient_read" ON psy_letter_issued;
CREATE POLICY "issued_patient_read" ON psy_letter_issued FOR SELECT
  USING (
    patient_id IS NOT NULL
    AND patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid())
  );

-- Staff dengan permission communication
DROP POLICY IF EXISTS "issued_staff_read" ON psy_letter_issued;
CREATE POLICY "issued_staff_read" ON psy_letter_issued FOR SELECT
  USING (user_has_perm('communication','view'));

DROP POLICY IF EXISTS "issued_staff_insert" ON psy_letter_issued;
CREATE POLICY "issued_staff_insert" ON psy_letter_issued FOR INSERT
  WITH CHECK (user_has_perm('communication','create'));

DROP POLICY IF EXISTS "issued_staff_update" ON psy_letter_issued;
CREATE POLICY "issued_staff_update" ON psy_letter_issued FOR UPDATE
  USING (user_has_perm('communication','edit'))
  WITH CHECK (user_has_perm('communication','edit'));

DROP POLICY IF EXISTS "issued_staff_delete" ON psy_letter_issued;
CREATE POLICY "issued_staff_delete" ON psy_letter_issued FOR DELETE
  USING (user_has_perm('communication','delete'));

-- Komen
COMMENT ON COLUMN psy_letter_issued.file_url IS
  'URL PDF/Word file lengkap yang dah disign (upload oleh staff).';

-- ──── psy_letter_auto_fields ────
-- Auto-field tambahan (cth [BMI], [PEKERJAAN]) — sistem ambil dari kolum DB.
CREATE TABLE IF NOT EXISTS psy_letter_auto_fields (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  key             TEXT UNIQUE NOT NULL,        -- "BMI" (akan jadi [BMI] dalam templat)
  label           TEXT NOT NULL,               -- "BMI Patient" (yang muncul dalam palette)
  source          TEXT NOT NULL CHECK (source IN ('patient','staff','system')),
  data_path       TEXT NOT NULL,               -- nama column dalam table (cth: 'bmi', 'address', 'phone')
  format_type     TEXT,                        -- optional: 'date' / 'currency' / null
  is_active       BOOLEAN DEFAULT true,
  is_default      BOOLEAN DEFAULT false,       -- true = pre-seeded; boleh delete tapi reset bawa balik
  sort_order      INT DEFAULT 0,
  created_by      UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  created_by_name TEXT,
  created_at      TIMESTAMPTZ DEFAULT now(),
  updated_at      TIMESTAMPTZ DEFAULT now()
);

-- RLS
ALTER TABLE psy_letter_auto_fields ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone read auto fields" ON psy_letter_auto_fields;
CREATE POLICY "Anyone read auto fields" ON psy_letter_auto_fields
  FOR SELECT USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "Staff manage auto fields" ON psy_letter_auto_fields;
CREATE POLICY "Staff manage auto fields" ON psy_letter_auto_fields
  FOR ALL USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
  WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- Komen
COMMENT ON TABLE psy_letter_auto_fields IS
  'Auto-fields untuk surat. Admin manage via UI. Sistem ambil value dari DB column yang ditentukan.';

-- ═══════════════════════════════════════════════════════════════════
-- DATA RUJUKAN (SEED)
-- ═══════════════════════════════════════════════════════════════════

-- ──── Seed: auto-fields lalai ────
INSERT INTO psy_letter_auto_fields (key, label, source, data_path, format_type, is_default, sort_order) VALUES
  ('NAMA',                'Nama Patient',          'patient', 'full_name',             NULL,       true, 10),
  ('IC',                  'No. K/P',                'patient', 'ic_number',             NULL,       true, 20),
  ('PHONE',               'No. Telefon',            'patient', 'phone',                 NULL,       true, 30),
  ('ALAMAT',              'Alamat Patient',         'patient', 'address',               NULL,       true, 40),
  ('TARIKH_LAHIR',        'Tarikh Lahir',           'patient', 'dob',                   'date',     true, 50),
  ('JANTINA',             'Jantina',                'patient', 'gender',                NULL,       true, 60),
  ('BANGSA',              'Bangsa',                 'patient', 'race',                  NULL,       true, 70),
  ('AGAMA',               'Agama',                  'patient', 'religion',              NULL,       true, 80),
  ('PEKERJAAN',           'Pekerjaan',              'patient', 'occupation',            NULL,       true, 90),
  ('PAKEJ',               'Pakej Aktif',            'patient', 'active_package_name',   NULL,       true, 100),
  ('TARIKH_MULA_RAWATAN', 'Tarikh Mula Rawatan',    'patient', 'package_purchased_at',  'date',     true, 110),
  ('STAFF_NAMA',          'Nama Staff',             'staff',   'full_name',             NULL,       true, 200),
  ('STAFF_JAWATAN',       'Jawatan Staff',          'staff',   'staff_role',            NULL,       true, 210),
  ('STAFF_REG_NO',        'No. Pendaftaran Staff',  'staff',   'registration_no',       NULL,       true, 220),
  ('STAFF_SPECIALIZATION','Pengkhususan Staff',     'staff',   'specialization',        NULL,       true, 230),
  ('TARIKH',              'Tarikh Hari Ini',        'system',  '__today__',             NULL,       true, 300),
  ('RUJUKAN',             'Nombor Rujukan',         'system',  '__ref_number__',        NULL,       true, 310)
ON CONFLICT (key) DO NOTHING;


-- ════════════════════════════════════════════════════════════════
-- schema/16_medical_records.sql
-- ════════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════════
-- SKEMA: Rekod Perubatan Pesakit (Medical Records)
-- Jadual: psy_medical_reports, psy_medical_report_comments
-- Nota: psy_dna_reports (legasi) telah dinamakan semula ke
--       psy_medical_reports — hanya nama akhir digunakan di sini.
-- ═══════════════════════════════════════════════════════════════════

-- ──── psy_medical_reports — laporan perubatan pesakit ────
-- Diupload oleh staff ATAU pesakit sendiri; mengalir ke patient-hub
-- doktor untuk semakan.

CREATE TABLE IF NOT EXISTS psy_medical_reports (
  id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id              UUID NOT NULL REFERENCES psy_patients(id) ON DELETE CASCADE,
  file_name               TEXT NOT NULL,
  file_path               TEXT NOT NULL,
  file_url                TEXT NOT NULL,
  notes                   TEXT,
  uploaded_by             UUID REFERENCES auth.users(id),
  uploaded_by_name        TEXT,
  uploaded_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  report_type             TEXT DEFAULT 'dna',
  title                   TEXT,
  status                  TEXT DEFAULT 'pending',
  sample_date             DATE,
  sample_type             TEXT,
  result_date             DATE,
  analysis_duration_days  INT,
  categories              JSONB DEFAULT '{}',
  summary                 TEXT,
  doctor_id               UUID,
  doctor_name             TEXT,
  doctor_review           TEXT,
  review_status           TEXT DEFAULT 'pending',
  reviewed_at             TIMESTAMPTZ,
  shared_with_patient     BOOLEAN DEFAULT false,
  shared_at               TIMESTAMPTZ,
  attached_files          JSONB DEFAULT '[]',
  source                  TEXT,
  file_size               BIGINT
);

CREATE INDEX IF NOT EXISTS idx_medical_reports_patient ON psy_medical_reports(patient_id, uploaded_at DESC);
CREATE INDEX IF NOT EXISTS idx_medical_reports_type    ON psy_medical_reports(report_type);

ALTER TABLE psy_medical_reports ENABLE ROW LEVEL SECURITY;

-- Staff urus semua laporan
DROP POLICY IF EXISTS "staff_medical_all" ON psy_medical_reports;
CREATE POLICY "staff_medical_all" ON psy_medical_reports FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- Pesakit baca laporan sendiri
DROP POLICY IF EXISTS "patient_medical_read" ON psy_medical_reports;
CREATE POLICY "patient_medical_read" ON psy_medical_reports FOR SELECT
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

-- Pesakit boleh INSERT laporan sendiri
DROP POLICY IF EXISTS "patient_medical_insert" ON psy_medical_reports;
CREATE POLICY "patient_medical_insert" ON psy_medical_reports FOR INSERT
  WITH CHECK (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

-- Pesakit boleh PADAM laporan yang dia upload sendiri (belum disemak)
DROP POLICY IF EXISTS "patient_medical_delete_own" ON psy_medical_reports;
CREATE POLICY "patient_medical_delete_own" ON psy_medical_reports FOR DELETE
  USING (
    uploaded_by = auth.uid()
    AND patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid())
    AND COALESCE(review_status,'pending') = 'pending'
  );

COMMENT ON COLUMN psy_medical_reports.report_type IS
  'dna | xray | ct | mri | ultrasound | blood | colonoscopy | endoscopy | other';
COMMENT ON COLUMN psy_medical_reports.status IS
  'pending | sampling | lab | ready | reviewed';
COMMENT ON COLUMN psy_medical_reports.review_status IS
  'pending | diluluskan | ditolak';

-- ──── psy_medical_report_comments — thread komen doktor ────
-- Banyak komen / banyak doktor per laporan.

CREATE TABLE IF NOT EXISTS psy_medical_report_comments (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  report_id   UUID NOT NULL REFERENCES psy_medical_reports(id) ON DELETE CASCADE,
  author_id   UUID,
  author_name TEXT,
  author_role TEXT,
  comment     TEXT NOT NULL,
  created_at  TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_med_comments_report ON psy_medical_report_comments(report_id, created_at);

ALTER TABLE psy_medical_report_comments ENABLE ROW LEVEL SECURITY;

-- Staff (doktor) urus semua komen
DROP POLICY IF EXISTS "staff_comments_all" ON psy_medical_report_comments;
CREATE POLICY "staff_comments_all" ON psy_medical_report_comments FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
  WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- Pesakit baca komen pada laporan sendiri
DROP POLICY IF EXISTS "patient_read_comments" ON psy_medical_report_comments;
CREATE POLICY "patient_read_comments" ON psy_medical_report_comments FOR SELECT
  USING (report_id IN (
    SELECT id FROM psy_medical_reports
    WHERE patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid())
  ));


-- ════════════════════════════════════════════════════════════════
-- schema/17_whatsapp.sql
-- ════════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════════
-- 17 — WHATSAPP INBOX (cache GHL Conversations)
-- ISW jadi muka depan; GHL Conversations API sumber sebenar.
-- Edge Function `ghl-inbox` (service role) yang tulis; staff hanya SELECT.
-- Jadual: psy_wa_conversations, psy_wa_messages
-- ═══════════════════════════════════════════════════════════════════

-- ──── psy_wa_conversations — satu baris per perbualan GHL ────
CREATE TABLE IF NOT EXISTS psy_wa_conversations (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ghl_conversation_id  TEXT UNIQUE NOT NULL,
  ghl_contact_id       TEXT,
  contact_name         TEXT,
  phone_e164           TEXT,
  wa_number            TEXT,                 -- nombor talian mana mesej masuk
  last_message         TEXT,
  last_message_at      TIMESTAMPTZ,
  unread               INT DEFAULT 0,
  patient_id           UUID REFERENCES psy_patients(id) ON DELETE SET NULL, -- diisi bila phone padan
  synced_at            TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_wa_conv_last      ON psy_wa_conversations(last_message_at DESC);
CREATE INDEX IF NOT EXISTS idx_wa_conv_phone     ON psy_wa_conversations(phone_e164);
CREATE INDEX IF NOT EXISTS idx_wa_conv_patient   ON psy_wa_conversations(patient_id);

ALTER TABLE psy_wa_conversations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "staff_wa_conv_read" ON psy_wa_conversations;
CREATE POLICY "staff_wa_conv_read" ON psy_wa_conversations FOR SELECT
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- ──── psy_wa_messages — satu baris per mesej ────
CREATE TABLE IF NOT EXISTS psy_wa_messages (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ghl_message_id       TEXT UNIQUE,
  ghl_conversation_id  TEXT NOT NULL,
  direction            TEXT,                 -- 'inbound' / 'outbound'
  body                 TEXT,
  msg_type             TEXT DEFAULT 'whatsapp',
  sent_by              UUID,                 -- staff id ISW kalau dihantar dari ISW
  sent_by_name         TEXT,
  created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_wa_msg_conv ON psy_wa_messages(ghl_conversation_id, created_at ASC);

ALTER TABLE psy_wa_messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "staff_wa_msg_read" ON psy_wa_messages;
CREATE POLICY "staff_wa_msg_read" ON psy_wa_messages FOR SELECT
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- ──── Realtime — mesej baru muncul sendiri + badge unread live ────
DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE psy_wa_messages;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE psy_wa_conversations;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- REPLICA IDENTITY FULL supaya payload UPDATE bawa nilai lama (untuk kira unread)
ALTER TABLE psy_wa_messages      REPLICA IDENTITY FULL;
ALTER TABLE psy_wa_conversations REPLICA IDENTITY FULL;


-- ════════════════════════════════════════════════════════════════
-- schema/18_notifications_automations.sql
-- ════════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════════
-- 18 — NOTIFIKASI & AUTOMASI
-- Notifikasi dalam-app, mesej automatik (template WhatsApp), builder
-- automasi + log, audience tersimpan, alert kepatuhan & risiko, task coach.
-- Jadual: psy_notifications, psy_auto_messages, psy_automations,
--         psy_notification_logs, psy_audiences, psy_adherence_alerts,
--         psy_risk_alerts, psy_emergency_alerts, psy_coach_tasks
-- ═══════════════════════════════════════════════════════════════════

-- ──── psy_notifications — notifikasi loceng dalam-app ────
CREATE TABLE IF NOT EXISTS psy_notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES psy_profiles(id) ON DELETE CASCADE NOT NULL,
  type TEXT DEFAULT 'system'
    CHECK (type IN ('appointment','order','plan','system','reaksi','kyc','referral','event')),
  title TEXT NOT NULL,
  body TEXT,
  link TEXT,
  is_read BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_psy_notifications_user ON psy_notifications(user_id, is_read, created_at DESC);

ALTER TABLE psy_notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users read own notifications" ON psy_notifications;
CREATE POLICY "Users read own notifications" ON psy_notifications FOR SELECT
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Users update own notifications" ON psy_notifications;
CREATE POLICY "Users update own notifications" ON psy_notifications FOR UPDATE
  USING (user_id = auth.uid());

-- INSERT dihadkan kepada staff sahaja; pesakit cetus notif via trigger SECURITY DEFINER
DROP POLICY IF EXISTS "Staff insert notifications" ON psy_notifications;
CREATE POLICY "Staff insert notifications" ON psy_notifications FOR INSERT
  WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- Nota: fn_complete_expired_treatments() ditakrif dalam 07_treatment_plans.sql
-- (domain rawatan); fungsi itu insert ke psy_notifications di atas.

-- ──── Fungsi trigger: notif pesakit bila coach buka minggu baru ────
CREATE OR REPLACE FUNCTION trg_notify_patient_new_week()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_user_id UUID;
BEGIN
  SELECT user_id INTO v_user_id FROM psy_patients WHERE id = NEW.patient_id;
  IF v_user_id IS NULL THEN RETURN NEW; END IF;

  -- Dedup: satu notifikasi per pesakit per plan+minggu
  IF EXISTS (
    SELECT 1 FROM psy_notifications
    WHERE user_id = v_user_id
      AND type = 'plan'
      AND link LIKE '%plan_id=' || NEW.plan_id::TEXT || '%week=' || NEW.week_number
    LIMIT 1
  ) THEN RETURN NEW; END IF;

  INSERT INTO psy_notifications (user_id, type, title, body, link)
  VALUES (
    v_user_id, 'plan',
    'Sila Hantar Laporan Reaksi — Minggu ' || NEW.week_number,
    'Minggu ' || NEW.week_number || ' rawatan anda bermula. Rekod simptom reaksi pemulihan yang anda alami.',
    'plan-week.html?plan_id=' || NEW.plan_id::TEXT || '&week=' || NEW.week_number
  );
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE LOG 'trg_notify_patient_new_week: %', SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_patient_new_week ON psy_plan_weekly_progress;
CREATE TRIGGER trg_notify_patient_new_week
  AFTER INSERT ON psy_plan_weekly_progress
  FOR EACH ROW EXECUTE FUNCTION trg_notify_patient_new_week();

-- ──── Fungsi trigger: notif coach bila pesakit hantar laporan reaksi ────
CREATE OR REPLACE FUNCTION trg_patient_reaksi_notify_coach()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_coach_id    UUID;
  v_patient_name TEXT;
BEGIN
  -- Hantar sekali sahaja pada INSERT, bukan UPDATE
  IF TG_OP != 'INSERT' THEN RETURN NEW; END IF;

  SELECT pr.full_name INTO v_patient_name
  FROM psy_patients pt
  JOIN psy_profiles pr ON pr.id = pt.user_id
  WHERE pt.id = NEW.patient_id;

  -- Coach dari psy_patients.coach_id dahulu
  SELECT coach_id INTO v_coach_id FROM psy_patients WHERE id = NEW.patient_id;

  -- Fallback: baris progres mingguan terkini untuk plan ini
  IF v_coach_id IS NULL THEN
    SELECT coach_id INTO v_coach_id FROM psy_plan_weekly_progress
    WHERE plan_id = NEW.plan_id AND patient_id = NEW.patient_id
    ORDER BY created_at DESC LIMIT 1;
  END IF;

  IF v_coach_id IS NOT NULL THEN
    INSERT INTO psy_notifications (user_id, type, title, body, link)
    VALUES (
      v_coach_id, 'reaksi',
      '🌀 Laporan Reaksi: ' || COALESCE(v_patient_name, 'Pesakit'),
      'Minggu ' || NEW.week_number || ' — ' || COALESCE(v_patient_name, 'Pesakit') || ' telah hantar laporan reaksi pemulihan.',
      'plan-week.html?plan_id=' || NEW.plan_id::TEXT || '&week=' || NEW.week_number
    );
  END IF;
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE LOG 'trg_patient_reaksi_notify_coach: %', SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_patient_reaksi_notify_coach ON psy_patient_reaksi_reports;
CREATE TRIGGER trg_patient_reaksi_notify_coach
  AFTER INSERT ON psy_patient_reaksi_reports
  FOR EACH ROW EXECUTE FUNCTION trg_patient_reaksi_notify_coach();

-- ──── Fungsi trigger: notif semua staff bila pesanan baru ────
CREATE OR REPLACE FUNCTION trg_notify_staff_new_order()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_patient_name TEXT;
  v_staff        RECORD;
BEGIN
  SELECT full_name INTO v_patient_name FROM psy_profiles WHERE id = NEW.patient_id;

  FOR v_staff IN SELECT id FROM psy_profiles WHERE role = 'staff' LOOP
    INSERT INTO psy_notifications (user_id, type, title, body, link)
    VALUES (
      v_staff.id, 'order',
      '📦 Pesanan Baru: ' || COALESCE(v_patient_name, 'Pesakit'),
      'Pesanan ' || COALESCE(NEW.order_ref, '') || ' diterima. Sila proses penghantaran.',
      'orders.html'
    );
  END LOOP;
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE LOG 'trg_notify_staff_new_order: %', SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_staff_new_order ON psy_orders;
CREATE TRIGGER trg_notify_staff_new_order
  AFTER INSERT ON psy_orders
  FOR EACH ROW EXECUTE FUNCTION trg_notify_staff_new_order();

-- ──── psy_emergency_alerts — Red Emergency Protocol (worklist zon merah/kuning) ────
-- Satu alert AKTIF (status <> 'resolved') per pesakit pada satu-satu masa
-- (dedup dlm trigger di bawah). Bukan gantian psy_risk_alerts (kekal, domain
-- lain) — khas utk worklist zon.
CREATE TABLE IF NOT EXISTS psy_emergency_alerts (
  id                       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id               UUID REFERENCES psy_patients(id) ON DELETE CASCADE NOT NULL,
  zon                      TEXT NOT NULL CHECK (zon IN ('kuning','merah')),
  symptoms                 JSONB DEFAULT '[]',   -- snapshot, sama bentuk dgn psy_reaksi_advice_log.symptoms
  -- source 'patient' ditambah 22 Jul 2026 via migration adaptif (20260722c) —
  -- pesakit lapor sendiri dari seksyen Protokol Kecemasan di roles/patient/dashboard.html
  -- (butang kecemasan; bukan lagi halaman berasingan — consolidated 22 Jul 2026).
  source                   TEXT DEFAULT 'auto' CHECK (source IN ('auto','manual','patient')),
  source_log_id            UUID REFERENCES psy_reaksi_advice_log(id) ON DELETE SET NULL,
  reported_at              TIMESTAMPTZ DEFAULT now(),
  response_target_minutes  INT NOT NULL,          -- 15 (merah) / 60 (kuning)
  assigned_to               UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,  -- default = coach_id pesakit
  status                    TEXT DEFAULT 'waiting_coach'
                             CHECK (status IN ('waiting_coach','contacted','waiting_vital','follow_up','resolved')),
  resolved_at                TIMESTAMPTZ,
  resolved_by                UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  notes                     TEXT,                 -- catatan terakhir (staff boleh kemaskini)
  created_by                 UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,  -- NULL = auto (trigger)
  created_at                TIMESTAMPTZ DEFAULT now(),
  updated_at                TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_emergency_alerts_status  ON psy_emergency_alerts(status, reported_at);
CREATE INDEX IF NOT EXISTS idx_emergency_alerts_patient ON psy_emergency_alerts(patient_id);

ALTER TABLE psy_emergency_alerts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff manage emergency alerts" ON psy_emergency_alerts;
CREATE POLICY "Staff manage emergency alerts" ON psy_emergency_alerts FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
  WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- Pesakit boleh BACA alert sendiri sahaja (papar status "Coach akan hubungi
-- anda" di seksyen Protokol Kecemasan, roles/patient/dashboard.html). INSERT/UPDATE
-- kekal staff-only — pesakit lapor sendiri via RPC SECURITY DEFINER fn_patient_report_emergency().
DROP POLICY IF EXISTS "Patient read own emergency alert" ON psy_emergency_alerts;
CREATE POLICY "Patient read own emergency alert" ON psy_emergency_alerts FOR SELECT
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

-- ──── Fungsi trigger: alert coach + worklist kecemasan bila advice log zon merah/kuning ────
-- Satu submission boleh insert hingga 3 baris mesej serentak; notifikasi
-- hanya utk BARIS PERTAMA (send_after ≈ created_at; baris 2/3 = +5/+10 min).
CREATE OR REPLACE FUNCTION trg_reaksi_advice_notify_emergency()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_coach_id     UUID;
  v_patient_name TEXT;
  v_first_row    BOOLEAN;
  v_zon          TEXT;
  v_target_min   INT;
  v_open_id      UUID;
  v_open_zon     TEXT;
BEGIN
  -- Baris pertama submission sahaja (elak notifikasi berganda 3x)
  v_first_row := (NEW.send_after IS NULL OR NEW.send_after <= NEW.created_at + interval '2 minutes');
  IF NOT v_first_row THEN RETURN NEW; END IF;

  IF NOT (NEW.is_emergency OR NEW.zon IN ('merah','kuning')) THEN RETURN NEW; END IF;

  SELECT pt.coach_id, COALESCE(pr.full_name, pt.full_name, 'Pesakit')
    INTO v_coach_id, v_patient_name
  FROM psy_patients pt
  LEFT JOIN psy_profiles pr ON pr.id = pt.user_id
  WHERE pt.id = NEW.patient_id;
  IF v_coach_id IS NULL THEN RETURN NEW; END IF;

  v_zon := CASE WHEN NEW.is_emergency THEN 'merah' ELSE NEW.zon END;
  v_target_min := CASE WHEN v_zon = 'merah' THEN 15 ELSE 60 END;

  IF v_zon = 'merah' THEN
    INSERT INTO psy_notifications (user_id, type, title, body, link)
    VALUES (
      v_coach_id, 'reaksi',
      '🔴 ZON MERAH: ' || v_patient_name,
      v_patient_name || ' melaporkan simptom tahap tinggi/kecemasan dalam Poll Harian. Pesakit dinasihatkan ke hospital & telah dihantar mesej kritikal — sila susul SEGERA.',
      'emergency.html?patient_id=' || NEW.patient_id::TEXT
    );
  ELSE
    INSERT INTO psy_notifications (user_id, type, title, body, link)
    VALUES (
      v_coach_id, 'reaksi',
      '🟡 Zon Kuning: ' || v_patient_name,
      v_patient_name || ' melaporkan simptom tahap sederhana dalam Poll Harian — perlukan perhatian coach. Sila semak dan susul pesakit.',
      'emergency.html?patient_id=' || NEW.patient_id::TEXT
    );
  END IF;

  -- Worklist: satu alert AKTIF per pesakit — kemaskini kalau dah ada, jangan gandakan.
  -- Taraf naik kuning→merah dibenarkan; JANGAN turun taraf merah→kuning.
  SELECT id, zon INTO v_open_id, v_open_zon
  FROM psy_emergency_alerts WHERE patient_id = NEW.patient_id AND status <> 'resolved'
  ORDER BY created_at DESC LIMIT 1;

  IF v_open_id IS NOT NULL THEN
    IF NOT (v_open_zon = 'merah' AND v_zon = 'kuning') THEN
      UPDATE psy_emergency_alerts
      SET zon = v_zon, symptoms = COALESCE(NEW.symptoms, symptoms),
          reported_at = now(), response_target_minutes = v_target_min, updated_at = now()
      WHERE id = v_open_id;
    END IF;
  ELSE
    INSERT INTO psy_emergency_alerts
      (patient_id, zon, symptoms, source, source_log_id, response_target_minutes, assigned_to)
    VALUES
      (NEW.patient_id, v_zon, COALESCE(NEW.symptoms, '[]'::jsonb), 'auto', NEW.id, v_target_min, v_coach_id);
  END IF;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE LOG 'trg_reaksi_advice_notify_emergency: %', SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_reaksi_advice_notify_emergency ON psy_reaksi_advice_log;
CREATE TRIGGER trg_reaksi_advice_notify_emergency
  AFTER INSERT ON psy_reaksi_advice_log
  FOR EACH ROW EXECUTE FUNCTION trg_reaksi_advice_notify_emergency();

-- ──── Fungsi RPC: pesakit tekan butang kecemasan (seksyen Protokol Kecemasan, roles/patient/dashboard.html) ────
-- Satu alert AKTIF per pesakit — dedup sama logic dgn trigger di atas. Taraf
-- sentiasa naik ke 'merah' (pesakit tekan butang kecemasan = tahap tertinggi),
-- tak pernah turun taraf. SECURITY DEFINER supaya pesakit tak perlu grant
-- INSERT/UPDATE terus ke psy_emergency_alerts (RLS kekal staff-only).
CREATE OR REPLACE FUNCTION fn_patient_report_emergency(p_channel TEXT DEFAULT 'unknown')
RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_patient_id   UUID;
  v_coach_id     UUID;
  v_patient_name TEXT;
  v_open_id      UUID;
  v_alert_id     UUID;
  v_note         TEXT;
BEGIN
  SELECT id, coach_id INTO v_patient_id, v_coach_id FROM psy_patients WHERE user_id = auth.uid() LIMIT 1;
  IF v_patient_id IS NULL THEN
    RAISE EXCEPTION 'Rekod pesakit tidak dijumpai';
  END IF;

  SELECT COALESCE(pr.full_name, pt.full_name, 'Pesakit') INTO v_patient_name
  FROM psy_patients pt LEFT JOIN psy_profiles pr ON pr.id = pt.user_id
  WHERE pt.id = v_patient_id;

  v_note := 'Pesakit tekan butang kecemasan (' || COALESCE(p_channel, 'unknown') || ') pada '
            || to_char(now(), 'DD Mon YYYY HH24:MI');

  SELECT id INTO v_open_id FROM psy_emergency_alerts
  WHERE patient_id = v_patient_id AND status <> 'resolved'
  ORDER BY created_at DESC LIMIT 1;

  IF v_open_id IS NOT NULL THEN
    UPDATE psy_emergency_alerts
    SET zon = 'merah', reported_at = now(), response_target_minutes = 15, updated_at = now(),
        notes = CASE WHEN notes IS NULL OR notes = '' THEN v_note ELSE notes || E'\n' || v_note END
    WHERE id = v_open_id
    RETURNING id INTO v_alert_id;
  ELSE
    INSERT INTO psy_emergency_alerts (patient_id, zon, source, response_target_minutes, assigned_to, notes)
    VALUES (v_patient_id, 'merah', 'patient', 15, v_coach_id, v_note)
    RETURNING id INTO v_alert_id;
  END IF;

  IF v_coach_id IS NOT NULL THEN
    INSERT INTO psy_notifications (user_id, type, title, body, link)
    VALUES (
      v_coach_id, 'reaksi',
      '🚨 Pesakit Tekan Butang Kecemasan: ' || v_patient_name,
      v_patient_name || ' menekan butang kecemasan (' || COALESCE(p_channel, 'unknown') || ') di Protokol Kecemasan. Sila hubungi SEGERA.',
      'emergency.html?patient_id=' || v_patient_id::TEXT
    );
  END IF;

  RETURN v_alert_id;
END;
$$;

GRANT EXECUTE ON FUNCTION fn_patient_report_emergency(TEXT) TO authenticated;

-- ──── psy_auto_messages — Mesej Automatik (template + masa + on/off) ────
-- Edge function (cth event-reminders) baca konfig dari sini; ubah di UI
-- auto-mesej.html = terus berkesan tanpa re-deploy.
create table if not exists psy_auto_messages (
  id uuid primary key default gen_random_uuid(),
  key text not null unique,               -- 'event_reminder', 'catatan_harian', ...
  name text not null,
  description text,
  channel text not null default 'whatsapp',
  trigger_type text not null,             -- before_event | before_session | daily_reminder | on_action | recurring_broadcast
  minutes_before int,                     -- untuk before_* (cth 15/30/60)
  send_at_time time,                      -- untuk daily_reminder (cth 20:00)
  days_of_week jsonb,                     -- [3,4,5] = Rab/Kha/Jum (0=Ahad .. 6=Sabtu)
  session_time time,                      -- masa sesi bermula (recurring_broadcast)
  audience jsonb default '["patient"]'::jsonb,
  package_ids jsonb default '[]'::jsonb,
  channels jsonb default '["whatsapp"]'::jsonb,  -- whatsapp | inapp | announcement | email
  link text,
  last_broadcast_at timestamptz,          -- dedup: kali terakhir dihantar
  rule jsonb,                             -- ambang utk alert berasaskan logik (cth kepatuhan)
  message_template text not null,
  placeholders jsonb default '[]'::jsonb, -- senarai placeholder sah (rujukan UI)
  category text,
  language text default 'ms',
  tags jsonb default '[]'::jsonb,
  created_by uuid references psy_profiles(id) on delete set null,
  is_active boolean default true,
  updated_by uuid references psy_profiles(id) on delete set null,
  updated_at timestamptz default now(),
  created_at timestamptz default now()
);

alter table psy_auto_messages enable row level security;

drop policy if exists "auto_msg staff read" on psy_auto_messages;
create policy "auto_msg staff read" on psy_auto_messages for select
  using (auth.uid() in (select id from psy_profiles where role = 'staff'));

drop policy if exists "auto_msg super manage" on psy_auto_messages;
create policy "auto_msg super manage" on psy_auto_messages for all
  using (auth.uid() in (select id from psy_profiles where staff_role = 'super_admin'))
  with check (auth.uid() in (select id from psy_profiles where staff_role = 'super_admin'));

-- Pesakit perlu BACA template reaksi sahaja (client jana mesej semasa submit
-- Poll Harian). Template auto-mesej lain kekal staff-only.
drop policy if exists "auto_msg patient read reaksi" on psy_auto_messages;
create policy "auto_msg patient read reaksi" on psy_auto_messages for select
  using (auth.uid() is not null and key like 'reaksi_%' and is_active = true);

comment on column psy_auto_messages.rule is
  'Peraturan/ambang untuk alert berasaskan logik. Cth kepatuhan: {"severity":"high","window_days":7,"email_from":"support@ibnusinawellness.com","checks":{"amalan":{"on":true,"min_days_short":3},"checklist":{"on":true,"min_days_missing":3},"skor":{"on":true,"min_score":80},"vitals":{"on":true,"min_days_since":7}}}';

-- ──── psy_automations — builder automasi (trigger + conditions + actions) ────
-- Enjin (Edge Function) baca automasi aktif → nilai syarat → laksana aksi →
-- tulis ke psy_notification_logs.
create table if not exists psy_automations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  is_active boolean default true,
  -- status bertiga (is_active disegerakkan: is_active = status='active')
  status text default 'draft',                -- draft | active | paused
  -- 1. TRIGGER
  trigger_category text not null,             -- appointment | payment | checkin | vitals | package | patient
  trigger_event text not null,                -- cth: session_reminder, payment_success, checkin_missed
  trigger_timing jsonb default '{}'::jsonb,   -- {when:'before'|'after'|'at'|'custom', value:1, unit:'day'}
  -- 2. CONDITIONS (AND) — pilihan
  conditions_enabled boolean default false,
  conditions jsonb default '[]'::jsonb,       -- [{field, op, value}]
  -- 3. ACTIONS
  actions jsonb default '[]'::jsonb,          -- ['whatsapp','inapp','email',...] + aksi lain
  -- 4. MESSAGE
  message_template text,                      -- teks inline (dgn {{placeholder}})
  message_channel text default 'whatsapp',
  -- Jadual jalan
  run_mode text default 'always',             -- always | scheduled
  run_days jsonb,                             -- [1,2,..] utk scheduled
  run_time time,
  -- Meta
  last_run_at timestamptz,
  created_by uuid references psy_profiles(id) on delete set null,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create index if not exists idx_psy_automations_active on psy_automations(is_active);
create index if not exists idx_psy_automations_trigger on psy_automations(trigger_category, trigger_event);

alter table psy_automations enable row level security;

-- Staff boleh baca; super_admin/manager urus automasi.
drop policy if exists "automations staff read" on psy_automations;
create policy "automations staff read" on psy_automations for select
  using (auth.uid() in (select id from psy_profiles where role = 'staff'));

drop policy if exists "automations mgr manage" on psy_automations;
create policy "automations mgr manage" on psy_automations for all
  using (auth.uid() in (select id from psy_profiles where staff_role in ('super_admin','manager')))
  with check (auth.uid() in (select id from psy_profiles where staff_role in ('super_admin','manager')));

-- ──── psy_notification_logs — log hantaran enjin automasi ────
create table if not exists psy_notification_logs (
  id uuid primary key default gen_random_uuid(),
  automation_id uuid references psy_automations(id) on delete set null,
  patient_id uuid,
  patient_name text,
  event text,
  channel text,
  status text default 'pending',              -- sent | pending | failed | cancelled
  message text,
  response text,
  error text,
  sent_at timestamptz,
  created_at timestamptz default now()
);

create index if not exists idx_psy_notif_logs_created on psy_notification_logs(created_at desc);
create index if not exists idx_psy_notif_logs_automation on psy_notification_logs(automation_id);

alter table psy_notification_logs enable row level security;

-- Log: staff baca; sistem (service_role) tulis dari Edge Function (bypass RLS).
drop policy if exists "notif_logs staff read" on psy_notification_logs;
create policy "notif_logs staff read" on psy_notification_logs for select
  using (auth.uid() in (select id from psy_profiles where role = 'staff'));

-- ──── psy_audiences — audience tersimpan (guna semula merentas automasi) ────
-- Bentuk conditions SAMA dengan psy_automations: [{field, op, value}]
--   field: patient_status | gender | has_whatsapp | package | state | age
--   op:    eq | in | between
create table if not exists psy_audiences (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  conditions jsonb default '[]'::jsonb,
  created_by uuid references psy_profiles(id) on delete set null,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

alter table psy_audiences enable row level security;

drop policy if exists "audiences staff read" on psy_audiences;
create policy "audiences staff read" on psy_audiences for select
  using (auth.uid() in (select id from psy_profiles where role = 'staff'));

drop policy if exists "audiences mgr manage" on psy_audiences;
create policy "audiences mgr manage" on psy_audiences for all
  using (auth.uid() in (select id from psy_profiles where staff_role in ('super_admin','manager')))
  with check (auth.uid() in (select id from psy_profiles where staff_role in ('super_admin','manager')));

-- ──── psy_adherence_alerts — alert kepatuhan pesakit (madu, dll) ────
-- Coach dapat notif bila patient kurang madu 4+ hari berturut.
CREATE TABLE IF NOT EXISTS psy_adherence_alerts (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id    UUID REFERENCES psy_patients(id) ON DELETE CASCADE NOT NULL,
  alert_type    TEXT NOT NULL,             -- 'madu_low_5days' / 'madu_low_4days'
  trigger_date  DATE NOT NULL,             -- tarikh alert dikira
  details       JSONB DEFAULT '{}',        -- snapshot: { target, days_below: [...], counts: {} }
  notified_coach_id UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  acknowledged_by   UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  acknowledged_at   TIMESTAMPTZ,
  created_at    TIMESTAMPTZ DEFAULT now(),
  UNIQUE (patient_id, alert_type, trigger_date)  -- elak duplicate sehari
);

CREATE INDEX IF NOT EXISTS idx_adherence_patient ON psy_adherence_alerts(patient_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_adherence_unack   ON psy_adherence_alerts(acknowledged_at) WHERE acknowledged_at IS NULL;

ALTER TABLE psy_adherence_alerts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Patient read own adherence" ON psy_adherence_alerts;
CREATE POLICY "Patient read own adherence" ON psy_adherence_alerts
  FOR SELECT USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Staff read all adherence" ON psy_adherence_alerts;
CREATE POLICY "Staff read all adherence" ON psy_adherence_alerts
  FOR SELECT USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "Staff manage adherence" ON psy_adherence_alerts;
CREATE POLICY "Staff manage adherence" ON psy_adherence_alerts
  FOR ALL USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
  WITH CHECK (auth.uid() IS NOT NULL);

-- Patient pun boleh insert (patient dashboard trigger check)
DROP POLICY IF EXISTS "Patient insert own adherence" ON psy_adherence_alerts;
CREATE POLICY "Patient insert own adherence" ON psy_adherence_alerts
  FOR INSERT WITH CHECK (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

-- ──── psy_risk_alerts — alert risiko pesakit ────
CREATE TABLE IF NOT EXISTS psy_risk_alerts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id UUID REFERENCES psy_patients(id) ON DELETE CASCADE NOT NULL,
  patient_name TEXT,
  created_by UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  created_by_name TEXT,
  severity TEXT DEFAULT 'medium' CHECK (severity IN ('low','medium','high','critical')),
  category TEXT,
  description TEXT,
  status TEXT DEFAULT 'open' CHECK (status IN ('open','acknowledged','resolved')),
  acknowledged_by UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  resolved_at TIMESTAMPTZ,
  resolution_notes TEXT,                    -- nota tindakan semasa resolve
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_psy_risk_patient ON psy_risk_alerts(patient_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_psy_risk_status ON psy_risk_alerts(status, created_at DESC);

ALTER TABLE psy_risk_alerts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff manage risk alerts" ON psy_risk_alerts;
CREATE POLICY "Staff manage risk alerts" ON psy_risk_alerts FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- ──── psy_coach_tasks — task harian peribadi coach (ClickUp-style) ────
CREATE TABLE IF NOT EXISTS psy_coach_tasks (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  coach_id     UUID NOT NULL REFERENCES psy_profiles(id) ON DELETE CASCADE,
  title        TEXT NOT NULL,
  notes        TEXT,
  task_date    DATE NOT NULL,
  status       TEXT DEFAULT 'belum_mula' CHECK (status IN ('belum_mula','dalam_proses','selesai')),
  priority     TEXT DEFAULT 'sederhana'  CHECK (priority IN ('rendah','sederhana','tinggi')),
  patient_id   UUID REFERENCES psy_patients(id) ON DELETE SET NULL,
  session_id   UUID REFERENCES psy_plan_weekly_progress(id) ON DELETE SET NULL,
  created_at   TIMESTAMPTZ DEFAULT now(),
  updated_at   TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_coach_tasks_coach_date ON psy_coach_tasks (coach_id, task_date);

ALTER TABLE psy_coach_tasks ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "coach_tasks_own" ON psy_coach_tasks;
CREATE POLICY "coach_tasks_own" ON psy_coach_tasks
  USING (coach_id = auth.uid())
  WITH CHECK (coach_id = auth.uid());

DROP POLICY IF EXISTS "coach_tasks_manager_read" ON psy_coach_tasks;
CREATE POLICY "coach_tasks_manager_read" ON psy_coach_tasks
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff' AND staff_role IN ('manager','admin'))
  );

-- ═══════════════════════════════════════════════════════════════════
-- SEED — template Mesej Automatik (psy_auto_messages)
-- ═══════════════════════════════════════════════════════════════════

-- Peringatan acara/kelas + Catatan Harian + hari jadi
insert into psy_auto_messages (key, name, description, trigger_type, minutes_before, send_at_time, days_of_week, audience, channels, message_template, placeholders, is_active) values
  ('event_reminder',
   'Peringatan Acara & Kelas',
   'Hantar peringatan kepada pesakit yang telah daftar, sebelum acara/kelas bermula.',
   'before_event', 30, null, null, '["patient"]'::jsonb, '["whatsapp"]'::jsonb,
   E'Salam {nama} 👋\n\nPeringatan: acara *{acara}* akan bermula lebih kurang {lead} lagi ({masa}).\n{pautan}\n\n— Ibnu Sina Wellness',
   '["{nama}","{acara}","{masa}","{lead}","{pautan}"]'::jsonb,
   true),

  ('catatan_harian',
   'Peringatan Catatan Harian',
   'Hantar WA kpd pesakit aktif yang belum isi Catatan Harian pada masa ditetapkan (cth 20:00). Dedup 1×/hari. Aktifkan di UI bila sedia.',
   'daily_reminder', null, '20:00', '[0,1,2,3,4,5,6]'::jsonb, '["patient"]'::jsonb, '["whatsapp"]'::jsonb,
   E'Salam {nama} 👋\n\nKami perasan anda belum isi *Catatan Harian* hari ini. Luangkan 2 minit untuk rekod amalan & perasaan anda — konsistensi setiap hari membantu pemulihan anda lebih cepat. 🌱\n\nIsi sekarang di aplikasi Ibnu Sina Wellness.\n\n— Ibnu Sina Wellness',
   '["{nama}"]'::jsonb,
   false),

  ('birthday',
   'Ucapan Hari Jadi',
   'Hantar ucapan pada tarikh lahir pesakit. Pencetus belum disambung.',
   'daily_reminder', null, '09:00', null, '["patient"]'::jsonb, '["whatsapp"]'::jsonb,
   E'Selamat Hari Jadi, {nama}! 🎂\n\nSemoga sihat sejahtera & dimurahkan rezeki. Kami doakan kesembuhan & kebahagiaan anda.\n\n— Ibnu Sina Wellness',
   '["{nama}"]'::jsonb,
   false)
on conflict (key) do nothing;

-- Broadcast berulang: Manzil Live (draf — staff lengkapkan link & aktifkan)
insert into psy_auto_messages
  (key, name, description, trigger_type, minutes_before, session_time, days_of_week, audience, package_ids, channels, link, message_template, placeholders, is_active)
values
  ('manzil_live',
   'Live Bacaan Manzil & Perubatan Alami',
   'Broadcast jemputan sesi Manzil live kepada pesakit, sebelum sesi bermula pada hari terpilih.',
   'recurring_broadcast', 30, '08:45', '[3,4,5]'::jsonb, '["patient"]'::jsonb, '[]'::jsonb,
   '["whatsapp","inapp","announcement"]'::jsonb, 'https://meet.google.com/xxx-xxxx-xxx',
   E'Salam {nama} 👋\n\n📿 *Sesi Rohani Eksklusif: Alunan Manzil*\nBersama Sheikh Fares Mohammed\n\nSesi akan bermula {lead} lagi (pukul {masa}). Jom sertai untuk ketenangan & perlindungan hari anda.\n\n📹 Sertai: {pautan}\n\n— Ibnu Sina Wellness',
   '["{nama}","{masa}","{lead}","{pautan}"]'::jsonb,
   false)
on conflict (key) do nothing;

-- Alert Coach — Kepatuhan Pesakit (gabungan multi-check, runner runKepatuhanAlerts)
insert into psy_auto_messages
  (key, name, description, trigger_type, send_at_time, days_of_week, audience, channels, rule, message_template, placeholders, is_active)
values
  ('kepatuhan_alert',
   'Alert Coach — Kepatuhan Pesakit',
   'Setiap malam, semak kepatuhan setiap pesakit aktif (amalan Catatan Harian tak dibuat/bawah sasaran, hari tak isi, skor rendah, tiada bacaan kesihatan). Gabung jadi SATU alert kepada COACH yang di-assign (papan pemuka + loceng + email) supaya boleh hubungi pesakit esok pagi. Dedup 1×/minggu/pesakit.',
   'daily_reminder',                 -- supaya UI papar pemilih masa harian
   '21:00',                          -- nilai hujung hari
   '[0,1,2,3,4,5,6]'::jsonb,          -- setiap hari (0=Ahad .. 6=Sabtu)
   '["coach"]'::jsonb,               -- sasaran = coach (bukan pesakit)
   '["inapp"]'::jsonb,               -- loceng dalam app sahaja (tambah "email" utk hidupkan via GHL)
   '{"severity":"high","window_days":7,"email_from":"support@ibnusinawellness.com","checks":{"amalan":{"on":true,"min_days_short":3},"checklist":{"on":true,"min_days_missing":3},"skor":{"on":true,"min_score":80},"vitals":{"on":true,"min_days_since":7}}}'::jsonb,
   E'Assalamualaikum Coach 👋\n\nPesakit {nama} memerlukan perhatian anda.\n\nBerikut perkara yang perlu diberi perhatian (7 hari lepas):\n{senarai}\n\nTindakan Disyorkan:\n📞 Hubungi pesakit untuk membuat semakan keadaan semasa dan memberikan sokongan agar rawatan dapat diteruskan dengan lebih konsisten.\n\nTerima kasih atas perhatian dan bimbingan anda.\n\n— Sistem Auto-Kepatuhan ISW',
   '["{nama}","{senarai}"]'::jsonb,
   false)
on conflict (key) do update set
   name = excluded.name, description = excluded.description, audience = excluded.audience,
   channels = excluded.channels, rule = excluded.rule, message_template = excluded.message_template,
   placeholders = excluded.placeholders;

-- Templat "Saranan Rujukan" (boleh-edit oleh staff; placeholder diganti oleh kod)
INSERT INTO psy_auto_messages (key, name, description, channel, trigger_type, channels, audience, message_template, placeholders, is_active)
VALUES (
  'referral_saranan',
  'Saranan Rujukan (WhatsApp)',
  'Mesej yang dihantar ke pesakit selepas konsultasi rujukan (butang "Hantar ke WhatsApp"). Boleh edit ayat & susun placeholder.',
  'whatsapp',
  'on_action',
  '["whatsapp"]'::jsonb,
  '["patient"]'::jsonb,
  E'Salam {nama}, \U0001F44B\nBerikut saranan daripada {pengesyor} (Ibnu Sina Wellness):\n\n{saranan}\n\n⏱️ Sila ikut selama *{tempoh} hari* bermula {tarikh}.\n\nTerima kasih & semoga cepat sihat. \U0001F33F',
  '["{nama}","{pengesyor}","{saranan}","{tempoh}","{tarikh}"]'::jsonb,
  true
)
ON CONFLICT (key) DO NOTHING;

-- Pengesahan Sesi Rawatan (session_confirm) — UPSERT dgn DO UPDATE supaya
-- run semula mengemaskini template/config; is_active TIDAK disentuh.
--   rule.lead_days      : berapa hari sebelum sesi peringatan dihantar (default 3)
--   rule.deadline_hours : had sahkan/tukar tarikh sebelum sesi (default 24)
--   rule.escalate       : alert coach bila lepas had & belum ditandakan sahkan
insert into psy_auto_messages
  (key, name, description, channel, trigger_type, send_at_time, message_template,
   placeholders, channels, rule, category, language, is_active)
values
  ('session_confirm',
   'Pengesahan Sesi Rawatan',
   'Sebelum sesi rawatan, WA minta pesakit balas teks utk sahkan kehadiran; staff tandakan di Kehadiran. Bila tinggal ≤ had jam & belum ditandakan, alert coach.',
   'whatsapp', 'before_session', '10:00',
   E'Salam {nama} 👋\n\nPeringatan sesi rawatan anda:\n📅 {sesi_akan_datang}\n🗓️ {tarikh_sesi} · {masa_sesi}\n\nBoleh hadir? Sila *balas mesej ini* untuk sahkan kehadiran 🙏\nJika perlu tukar tarikh, beritahu kami — pihak klinik akan bantu aturkan (selewat-lewatnya 24 jam sebelum sesi).\n\nJika tiada maklum balas, slot mungkin dilepaskan & caj tidak hadir boleh dikenakan.\n\n— {nama_klinik}',
   '["{nama}","{sesi_akan_datang}","{tarikh_sesi}","{masa_sesi}","{nama_klinik}"]'::jsonb,
   '["whatsapp","inapp"]'::jsonb,
   '{"lead_days":3,"deadline_hours":24,"escalate":{"on":true,"severity":"medium"}}'::jsonb,
   'temujanji', 'ms',
   false)
on conflict (key) do update set
  name             = excluded.name,
  description      = excluded.description,
  channel          = excluded.channel,
  trigger_type     = excluded.trigger_type,
  send_at_time     = excluded.send_at_time,
  message_template = excluded.message_template,
  placeholders     = excluded.placeholders,
  channels         = excluded.channels,
  rule             = excluded.rule,
  category         = excluded.category,
  language         = excluded.language,
  updated_at       = now();

-- Template Reaksi Pemulihan (pesakit boleh baca — policy 'reaksi_%')
-- reaksi_harian: mesej 1 (terus) — {{sections}} = blok per kategori,
-- tindakan sama disebut SEKALI sahaja (dedup global oleh klien).
INSERT INTO psy_auto_messages (key, name, description, trigger_type, message_template, placeholders, is_active) VALUES
  ('reaksi_harian',
   'Cadangan Reaksi Harian',
   'Mesej 1 (terus) selepas Poll Harian — reaksi & Cadangan Pemulihan dikumpulkan ikut kategori; tindakan sama disebut sekali sahaja.',
   'on_action',
   E'Assalamualaikum {{patient_name}},\n\nTerima kasih kerana melengkapkan Poll Harian hari ini.\n\nBerdasarkan jawapan anda, kami mengesan beberapa reaksi pemulihan.\n\n{{sections}}\n\nJika simptom menjadi semakin teruk atau berpanjangan, sila hubungi coach anda.\n\nSemoga Allah mempermudahkan urusan pemulihan anda.\n\nSalam kasih,\nPasukan Ibnu Sina Wellness 💚',
   '["{{patient_name}}","{{sections}}"]'::jsonb,
   true),
  ('reaksi_kritikal',
   'Cadangan Reaksi Kritikal',
   'Draf mesej untuk reaksi berisiko tinggi / kecemasan — TIDAK auto-hantar, staff semak & hantar dari halaman Semak & Hantar Mesej.',
   'on_action',
   E'Assalamualaikum {{patient_name}},\n\n🚨 PENTING: Berdasarkan Poll Harian anda, terdapat simptom yang memerlukan perhatian segera.\n\nReaksi yang dikesan:\n{{symptom_list}}\n\nTindakan disyorkan:\n{{action_list}}\n\nSila hubungi coach anda DENGAN SEGERA atau dapatkan rawatan di hospital berdekatan jika keadaan serius.\n\nPasukan Ibnu Sina Wellness',
   '["{{patient_name}}","{{symptom_list}}","{{action_list}}"]'::jsonb,
   true),
  ('reaksi_gaya_hidup',
   'Saranan Gaya Hidup Fitrah',
   'Mesej ke-2 selepas Poll Harian (+5 minit) — saranan gaya hidup fitrah berdasarkan reaksi dikesan (tindakan jenis "gaya_hidup").',
   'on_action',
   E'Assalamualaikum {{patient_name}},\n\n🌿 *Saranan Gaya Hidup Fitrah* untuk hari ini:\n\n{{lifestyle_list}}\n\nSedikit demi sedikit, secara istiqamah — insyaAllah membantu pemulihan anda.\n\nSalam kasih,\nPasukan Ibnu Sina Wellness 💚',
   '["{{patient_name}}","{{lifestyle_list}}"]'::jsonb,
   true),
  ('reaksi_diet',
   'Saranan Diet & Nutrisi',
   'Mesej ke-3 selepas Poll Harian (+10 minit) — saranan pemakanan berdasarkan reaksi dikesan (tindakan jenis "pemakanan").',
   'on_action',
   E'Assalamualaikum {{patient_name}},\n\n🍽️ *Saranan Diet & Nutrisi* untuk membantu pemulihan anda hari ini:\n\n{{diet_list}}\n\nAmalkan mengikut kemampuan dan secara konsisten, insyaAllah.\n\nSalam kasih,\nPasukan Ibnu Sina Wellness 💚',
   '["{{patient_name}}","{{diet_list}}"]'::jsonb,
   true)
ON CONFLICT (key) DO NOTHING;


-- ════════════════════════════════════════════════════════════════
-- schema/19_events_announcements.sql
-- ════════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════
-- ACARA & PENGUMUMAN
-- Jadual: psy_announcements, psy_events, psy_event_registrations,
--         psy_event_materials, psy_announcement_categories,
--         psy_announcement_types
-- ═══════════════════════════════════════════════════════════════

-- ──── psy_announcements ────
CREATE TABLE IF NOT EXISTS psy_announcements (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title       TEXT NOT NULL,
  body        TEXT,
  tag         TEXT,
  bg          TEXT DEFAULT 'from-navy to-green-dark',
  cta_label   TEXT,
  cta_url     TEXT,
  image_url   TEXT,
  is_active   BOOLEAN DEFAULT true,
  sort_order  INT DEFAULT 0,
  starts_at   TIMESTAMPTZ,
  ends_at     TIMESTAMPTZ,
  category    TEXT,
  content     TEXT,
  audience    JSONB DEFAULT '["patient"]'::jsonb,
  expires_at  TIMESTAMPTZ,
  package_ids JSONB DEFAULT '[]'::jsonb,
  created_at  TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE psy_announcements ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone read active announcements" ON psy_announcements;
CREATE POLICY "Anyone read active announcements" ON psy_announcements FOR SELECT
  USING (is_active = true);

DROP POLICY IF EXISTS "Staff manage announcements" ON psy_announcements;
CREATE POLICY "Staff manage announcements" ON psy_announcements FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- ──── psy_events (acara / kelas) ────
CREATE TABLE IF NOT EXISTS psy_events (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title                 TEXT NOT NULL,
  description           TEXT,
  type                  TEXT DEFAULT 'kelas',
  start_at              TIMESTAMPTZ NOT NULL,
  end_at                TIMESTAMPTZ,
  mode                  TEXT DEFAULT 'online',
  meet_link             TEXT,
  location              TEXT,
  address               TEXT,
  maps_url              TEXT,
  capacity              INT,
  registration_deadline TIMESTAMPTZ,
  cover_image           TEXT,
  tag                   TEXT,
  host                  TEXT,
  host_role             TEXT, -- Penceramah / Coach / Moderator
  price                 NUMERIC DEFAULT 0,
  status                TEXT DEFAULT 'published',
  recording_url         TEXT,
  audience              JSONB DEFAULT '["patient"]'::jsonb,
  package_ids           JSONB DEFAULT '[]'::jsonb,
  created_by            UUID,
  created_at            TIMESTAMPTZ DEFAULT now(),
  updated_at            TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE psy_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "events read" ON psy_events;
CREATE POLICY "events read" ON psy_events FOR SELECT USING (
  status = 'published' OR auth.uid() IN (SELECT id FROM psy_profiles WHERE role = 'staff'));

DROP POLICY IF EXISTS "events staff manage" ON psy_events;
CREATE POLICY "events staff manage" ON psy_events FOR ALL
  USING (auth.uid() IN (SELECT id FROM psy_profiles WHERE role = 'staff'))
  WITH CHECK (auth.uid() IN (SELECT id FROM psy_profiles WHERE role = 'staff'));

-- ──── psy_event_registrations (pendaftaran acara) ────
CREATE TABLE IF NOT EXISTS psy_event_registrations (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id         UUID REFERENCES psy_events(id) ON DELETE CASCADE,
  patient_id       UUID REFERENCES psy_patients(id) ON DELETE CASCADE,
  status           TEXT DEFAULT 'registered',
  reminder_sent_at TIMESTAMPTZ, -- penanda dedup peringatan WhatsApp 1 jam (Edge Function event-reminders)
  registered_at    TIMESTAMPTZ DEFAULT now(),
  UNIQUE (event_id, patient_id)
);

CREATE INDEX IF NOT EXISTS idx_event_regs_event   ON psy_event_registrations(event_id);
CREATE INDEX IF NOT EXISTS idx_event_regs_patient ON psy_event_registrations(patient_id);

ALTER TABLE psy_event_registrations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "regs read" ON psy_event_registrations;
CREATE POLICY "regs read" ON psy_event_registrations FOR SELECT USING (
  patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid())
  OR auth.uid() IN (SELECT id FROM psy_profiles WHERE role = 'staff'));

DROP POLICY IF EXISTS "regs patient insert" ON psy_event_registrations;
CREATE POLICY "regs patient insert" ON psy_event_registrations FOR INSERT WITH CHECK (
  patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "regs patient update" ON psy_event_registrations;
CREATE POLICY "regs patient update" ON psy_event_registrations FOR UPDATE USING (
  patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid())
  OR auth.uid() IN (SELECT id FROM psy_profiles WHERE role = 'staff'));

DROP POLICY IF EXISTS "regs staff delete" ON psy_event_registrations;
CREATE POLICY "regs staff delete" ON psy_event_registrations FOR DELETE USING (
  auth.uid() IN (SELECT id FROM psy_profiles WHERE role = 'staff'));

-- ──── psy_event_materials (bahan / rakaman acara) ────
CREATE TABLE IF NOT EXISTS psy_event_materials (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id   UUID REFERENCES psy_events(id) ON DELETE CASCADE,
  title      TEXT NOT NULL,
  type       TEXT DEFAULT 'pautan',
  url        TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_event_materials_event ON psy_event_materials(event_id);

ALTER TABLE psy_event_materials ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "materials read" ON psy_event_materials;
CREATE POLICY "materials read" ON psy_event_materials FOR SELECT USING (
  EXISTS (SELECT 1 FROM psy_events e WHERE e.id = event_id
          AND (e.status = 'published' OR auth.uid() IN (SELECT id FROM psy_profiles WHERE role = 'staff'))));

DROP POLICY IF EXISTS "materials staff manage" ON psy_event_materials;
CREATE POLICY "materials staff manage" ON psy_event_materials FOR ALL
  USING (auth.uid() IN (SELECT id FROM psy_profiles WHERE role = 'staff'))
  WITH CHECK (auth.uid() IN (SELECT id FROM psy_profiles WHERE role = 'staff'));

-- ──── psy_announcement_categories (kategori pengumuman — super admin CRUD) ────
CREATE TABLE IF NOT EXISTS psy_announcement_categories (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name       TEXT NOT NULL UNIQUE,
  sort_order INT DEFAULT 0,
  is_active  BOOLEAN DEFAULT true,
  created_by UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE psy_announcement_categories ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "ann_cat read" ON psy_announcement_categories;
CREATE POLICY "ann_cat read" ON psy_announcement_categories FOR SELECT USING (
  auth.uid() IN (SELECT id FROM psy_profiles WHERE role = 'staff'));

DROP POLICY IF EXISTS "ann_cat manage" ON psy_announcement_categories;
CREATE POLICY "ann_cat manage" ON psy_announcement_categories FOR ALL
  USING (auth.uid() IN (SELECT id FROM psy_profiles WHERE staff_role = 'super_admin'))
  WITH CHECK (auth.uid() IN (SELECT id FROM psy_profiles WHERE staff_role = 'super_admin'));

-- ──── psy_announcement_types (jenis pengumuman — super admin CRUD) ────
CREATE TABLE IF NOT EXISTS psy_announcement_types (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  key         TEXT NOT NULL UNIQUE,
  title       TEXT NOT NULL,
  description TEXT DEFAULT '',
  kind        TEXT NOT NULL DEFAULT 'announcement',
  mode        TEXT,
  etype       TEXT,
  label       TEXT,
  sort_order  INT DEFAULT 0,
  is_active   BOOLEAN DEFAULT true,
  created_by  UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  created_at  TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ann_types_sort ON psy_announcement_types(sort_order);

ALTER TABLE psy_announcement_types ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "ann_types read" ON psy_announcement_types;
CREATE POLICY "ann_types read" ON psy_announcement_types FOR SELECT USING (
  auth.uid() IN (SELECT id FROM psy_profiles WHERE role = 'staff'));

DROP POLICY IF EXISTS "ann_types manage" ON psy_announcement_types;
CREATE POLICY "ann_types manage" ON psy_announcement_types FOR ALL
  USING (auth.uid() IN (SELECT id FROM psy_profiles WHERE staff_role = 'super_admin'))
  WITH CHECK (auth.uid() IN (SELECT id FROM psy_profiles WHERE staff_role = 'super_admin'));

-- ──── data rujukan ────
INSERT INTO psy_announcements (title, body, tag, bg, cta_label, cta_url, sort_order) VALUES
  ('Kelas Mindfulness Percuma', 'Setiap Sabtu 9AM — Sertai sesi meditasi & pernafasan bersama Coach Izzah.', 'Kelas Minggu Ini', 'from-navy to-teal', 'Daftar Sekarang', 'https://wa.me/60123456789', 1),
  ('Program Detox Digital', 'Cabaran 7 hari kurangkan screen time untuk kesejahteraan mental anda.', 'Challenge Baru', 'from-green-dark to-teal', 'Sertai Cabaran', null, 2),
  ('Pakej Ramadan Khas', 'Rawatan holistik dengan fokus spiritual — promosi sehingga hujung bulan.', 'Promosi', 'from-navy to-green-dark', 'Lihat Pakej', 'pakej.html', 3)
ON CONFLICT DO NOTHING;


-- ════════════════════════════════════════════════════════════════
-- schema/20_referrals.sql
-- ════════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════
-- RUJUKAN
-- Jadual: psy_referrals (ganjaran rujukan pesakit-ke-pesakit),
--         psy_clinical_referrals (coach/staff rujuk pesakit kpd
--         doctor / coach lain / manager)
-- Fungsi: assign_referral_code (trigger fn), check_referral_code (RPC)
-- ═══════════════════════════════════════════════════════════════

-- ──── assign_referral_code (auto-jana kod rujukan pesakit) ────
-- Client (JS) akan set kod cantik (nama+MRN) sebelum insert; jika
-- masih NULL, fungsi trigger ini jamin satu kod unik tetap wujud.
-- Nota: trigger MRN (trg_assign_patient_mrn) berjalan dulu ikut abjad
-- nama, jadi NEW.mrn sudah diisi bila trigger ini berjalan.
CREATE OR REPLACE FUNCTION assign_referral_code()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  base      TEXT;
  candidate TEXT;
  n         INT := 1;
BEGIN
  -- Kod sudah diset client — normalkan ke huruf besar & biarkan
  IF NEW.referral_code IS NOT NULL AND length(trim(NEW.referral_code)) > 0 THEN
    NEW.referral_code := upper(trim(NEW.referral_code));
    RETURN NEW;
  END IF;

  -- Fallback: 'ISW' + digit MRN (cth P-019 -> ISW019)
  base := 'ISW' || regexp_replace(COALESCE(NEW.mrn, ''), '\D', '', 'g');
  IF base = 'ISW' THEN
    base := 'ISW' || to_char((random() * 9000 + 1000)::int, 'FM0000');
  END IF;

  candidate := base;
  WHILE EXISTS (SELECT 1 FROM psy_patients WHERE referral_code = candidate) LOOP
    n := n + 1;
    candidate := base || n;
  END LOOP;

  NEW.referral_code := candidate;
  RETURN NEW;
END;
$$;

-- Trigger pada psy_patients (jadual dari 04_patients.sql) — diletak di sini
-- kerana fungsinya ditakrif di atas.
DROP TRIGGER IF EXISTS trg_assign_referral_code ON psy_patients;
CREATE TRIGGER trg_assign_referral_code
  BEFORE INSERT ON psy_patients
  FOR EACH ROW
  EXECUTE FUNCTION assign_referral_code();

-- ──── check_referral_code (RPC) ────
-- Semak sama ada kod rujukan wujud. SECURITY DEFINER supaya pesakit
-- baru boleh semak tanpa RLS.
CREATE OR REPLACE FUNCTION check_referral_code(p_code TEXT)
RETURNS TABLE (valid BOOLEAN, referrer_name TEXT)
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  RETURN QUERY
  SELECT TRUE, p.full_name
  FROM psy_patients p
  WHERE upper(trim(p.referral_code)) = upper(trim(p_code))
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN QUERY SELECT FALSE, NULL::TEXT;
  END IF;
END;
$$;

-- ──── psy_referrals (lejar ganjaran rujukan pesakit-ke-pesakit) ────
CREATE TABLE IF NOT EXISTS psy_referrals (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  referrer_patient_id UUID REFERENCES psy_patients(id) ON DELETE CASCADE,
  referee_patient_id  UUID REFERENCES psy_patients(id) ON DELETE CASCADE,
  code_used           TEXT,
  -- pending   = pesakit baru dah daftar, belum bayar
  -- qualified = pesakit baru dah buat bayaran pertama (ganjaran layak)
  -- rewarded  = staf dah beri baucar (kedua-dua pihak)
  -- void      = dibatalkan (cth rujukan palsu)
  status              TEXT DEFAULT 'pending'
                        CHECK (status IN ('pending','qualified','rewarded','void')),
  qualified_at        TIMESTAMPTZ,
  reward_note         TEXT,
  rewarded_at         TIMESTAMPTZ,
  rewarded_by         UUID REFERENCES psy_profiles(id),
  created_at          TIMESTAMPTZ DEFAULT now(),
  -- Satu pesakit baru hanya boleh dirujuk sekali
  UNIQUE (referee_patient_id)
);

CREATE INDEX IF NOT EXISTS idx_psy_referrals_referrer ON psy_referrals (referrer_patient_id);
CREATE INDEX IF NOT EXISTS idx_psy_referrals_status   ON psy_referrals (status);

ALTER TABLE psy_referrals ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff manage referrals" ON psy_referrals;
CREATE POLICY "Staff manage referrals" ON psy_referrals FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "Patients read own referrals" ON psy_referrals;
CREATE POLICY "Patients read own referrals" ON psy_referrals FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM psy_patients pp
    WHERE pp.id IN (psy_referrals.referrer_patient_id, psy_referrals.referee_patient_id)
      AND pp.user_id = auth.uid()
  ));

-- ──── psy_clinical_referrals (rujukan klinikal pesakit) ────
-- Coach/staff rujuk pesakit kepada doctor / coach lain / manager
-- (Hakeem/Hakeema). Sasaran dipilih secara spesifik (target_id).
-- Notifikasi guna psy_notifications type 'referral'.
CREATE TABLE IF NOT EXISTS psy_clinical_referrals (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id        UUID NOT NULL REFERENCES psy_patients(id) ON DELETE CASCADE,
  referred_by       UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  referred_by_name  TEXT,
  target_role       TEXT NOT NULL CHECK (target_role IN ('doctor','coach','manager')),
  target_id         UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  target_name       TEXT,
  reason            TEXT NOT NULL,
  meet_date         DATE,                       -- tarikh pesakit perlu jumpa (dari jadual rawatan)
  priority          TEXT NOT NULL DEFAULT 'sederhana'
                      CHECK (priority IN ('rendah','sederhana','tinggi')),
  status            TEXT NOT NULL DEFAULT 'pending'
                      CHECK (status IN ('pending','accepted','resolved','declined')),
  resolution_note   TEXT,
  consultation_note TEXT,                       -- nota sesi rujukan (Hakeem/doctor/coach)
  consultation      JSONB DEFAULT '{}'::jsonb,  -- borang konsultasi berstruktur
  attachments       JSONB DEFAULT '[]'::jsonb,  -- transkrip/dokumen: [{name,path,uploaded_at}]
  -- Sesi 1:1 auto-jana dari week plan (cth Hakeema 1:1 minggu 6/11) — plan_id+week_number
  -- kekal NULL utk rujukan manual biasa. source='plan_1on1' + unique index elak duplicate.
  plan_id           UUID REFERENCES psy_treatment_plans(id) ON DELETE SET NULL,
  week_number       INT,
  source            TEXT NOT NULL DEFAULT 'manual' CHECK (source IN ('manual','plan_1on1')),
  created_at        TIMESTAMPTZ DEFAULT now(),
  updated_at        TIMESTAMPTZ DEFAULT now(),
  resolved_at       TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_psy_clinical_referrals_target  ON psy_clinical_referrals(target_id, status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_psy_clinical_referrals_patient ON psy_clinical_referrals(patient_id, created_at DESC);
CREATE UNIQUE INDEX IF NOT EXISTS uq_psy_clinical_referrals_plan_1on1
  ON psy_clinical_referrals(plan_id, week_number) WHERE source = 'plan_1on1';

ALTER TABLE psy_clinical_referrals ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff manage clinical referrals" ON psy_clinical_referrals;
CREATE POLICY "Staff manage clinical referrals" ON psy_clinical_referrals FOR ALL
  USING      (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
  WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));


-- ════════════════════════════════════════════════════════════════
-- schema/21_feedback.sql
-- ════════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════
-- MAKLUM BALAS
-- Jadual: psy_feedback (mingguan per-sesi + keseluruhan rawatan),
--         psy_weekly_feedback (rating mingguan ringkas per pelan)
-- ═══════════════════════════════════════════════════════════════

-- ──── psy_feedback ────
CREATE TABLE IF NOT EXISTS psy_feedback (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id    UUID REFERENCES psy_patients(id) ON DELETE CASCADE,
  user_id       UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  patient_name  TEXT,
  feedback_type TEXT NOT NULL DEFAULT 'overall'
                  CHECK (feedback_type IN ('weekly','overall')),
  week_number   INT,
  plan_id       UUID REFERENCES psy_treatment_plans(id) ON DELETE SET NULL,
  coach_id      UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  coach_name    TEXT,
  rating        INT CHECK (rating BETWEEN 1 AND 5),
  coach_rating  INT CHECK (coach_rating BETWEEN 1 AND 5),
  supply_rating INT CHECK (supply_rating BETWEEN 1 AND 5),
  comment       TEXT,
  helpful_tags  JSONB DEFAULT '[]',
  created_at    TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_feedback_type_patient
  ON psy_feedback(patient_id, feedback_type);

CREATE INDEX IF NOT EXISTS idx_feedback_coach
  ON psy_feedback(coach_id) WHERE coach_id IS NOT NULL;

ALTER TABLE psy_feedback ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Patients manage own feedback" ON psy_feedback;
CREATE POLICY "Patients manage own feedback" ON psy_feedback FOR ALL
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()))
  WITH CHECK (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Staff read all feedback" ON psy_feedback;
CREATE POLICY "Staff read all feedback" ON psy_feedback FOR SELECT
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

COMMENT ON COLUMN psy_feedback.feedback_type IS
  '"weekly" = per-session feedback (rates coach + supplies); "overall" = end-of-treatment review';

-- ──── psy_weekly_feedback ────
CREATE TABLE IF NOT EXISTS psy_weekly_feedback (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id     UUID REFERENCES psy_treatment_plans(id) ON DELETE CASCADE NOT NULL,
  patient_id  UUID REFERENCES psy_patients(id) ON DELETE CASCADE NOT NULL,
  week_number INT NOT NULL,
  rating      INT CHECK (rating BETWEEN 1 AND 5),
  comment     TEXT,
  created_at  TIMESTAMPTZ DEFAULT now(),
  UNIQUE (plan_id, week_number)
);

CREATE INDEX IF NOT EXISTS idx_psy_feedback_plan ON psy_weekly_feedback(plan_id, week_number);

ALTER TABLE psy_weekly_feedback ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Patients manage own weekly feedback" ON psy_weekly_feedback;
CREATE POLICY "Patients manage own weekly feedback" ON psy_weekly_feedback FOR ALL
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()))
  WITH CHECK (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Staff read all weekly feedback" ON psy_weekly_feedback;
CREATE POLICY "Staff read all weekly feedback" ON psy_weekly_feedback FOR SELECT
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));


-- ════════════════════════════════════════════════════════════════
-- schema/22_knowledge_base.sql
-- ════════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════════
-- SKEMA: KNOWLEDGE BASE (Knowledge Hub — Pusat Rujukan Dalaman Staff)
-- Jadual: psy_kb_categories, psy_kb_resources, psy_kb_versions,
--         psy_kb_bookmarks, psy_kb_views, psy_kb_note_folders,
--         psy_kb_notes, psy_kb_trainings, psy_kb_training_progress,
--         psy_kb_certificates
-- Modul rujukan dalaman: SOP, garis panduan klinikal, latihan, borang,
-- template, video, pautan. Termasuk bookmark, nota peribadi, versioning
-- dan pusat latihan (training center). Fail disimpan dalam bucket
-- 'kb-media' (lihat 24_storage.sql).
-- ═══════════════════════════════════════════════════════════════════

-- ──── fungsi helper: adakah auth.uid() seorang staff? ────
CREATE OR REPLACE FUNCTION kb_is_staff() RETURNS BOOLEAN AS $$
  SELECT EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff');
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- ──── fungsi: sentuh updated_at ────
CREATE OR REPLACE FUNCTION kb_touch_updated_at() RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END; $$ LANGUAGE plpgsql;

-- ──── psy_kb_categories ────
CREATE TABLE IF NOT EXISTS psy_kb_categories (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name        TEXT NOT NULL,
  slug        TEXT UNIQUE NOT NULL,
  description TEXT,
  icon        TEXT DEFAULT '📁',
  color       TEXT DEFAULT 'navy',     -- token warna ISW: navy|green|gold|terracotta|teal|grey
  sort_order  INT  DEFAULT 100,
  is_active   BOOLEAN DEFAULT true,
  created_at  TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE psy_kb_categories ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "kb_cat_read" ON psy_kb_categories;
CREATE POLICY "kb_cat_read"  ON psy_kb_categories FOR SELECT USING (kb_is_staff());
DROP POLICY IF EXISTS "kb_cat_write" ON psy_kb_categories;
CREATE POLICY "kb_cat_write" ON psy_kb_categories FOR ALL    USING (kb_is_staff()) WITH CHECK (kb_is_staff());

-- ──── psy_kb_resources ────
CREATE TABLE IF NOT EXISTS psy_kb_resources (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title         TEXT NOT NULL,
  description   TEXT,
  category_id   UUID REFERENCES psy_kb_categories(id) ON DELETE SET NULL,
  res_type      TEXT NOT NULL DEFAULT 'pdf'
                CHECK (res_type IN ('pdf','document','spreadsheet','presentation','video','image','link')),
  file_url      TEXT,          -- untuk fail yang dimuat naik (bucket kb-media)
  external_url  TEXT,          -- untuk res_type='link' atau pautan luar (GDrive/YouTube)
  file_size     BIGINT,        -- bait
  file_ext      TEXT,          -- pdf/docx/xlsx/pptx/mp4/png…
  tags          TEXT[] DEFAULT '{}',
  department    TEXT,          -- Clinical/Coaching/Medical/Admin/HR/Counselling/Education…
  visibility    TEXT NOT NULL DEFAULT 'public'
                CHECK (visibility IN ('public','department','role','user','private')),
  allowed_roles TEXT[] DEFAULT '{}',   -- bila visibility='role'
  allowed_users UUID[] DEFAULT '{}',   -- bila visibility='user' (kongsi kepada staf tertentu)
  version       TEXT DEFAULT 'v1.0',
  source        TEXT,
  language      TEXT DEFAULT 'ms',
  expiry_date   DATE,
  view_count    INT DEFAULT 0,
  is_archived   BOOLEAN DEFAULT false,
  uploaded_by   UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  created_at    TIMESTAMPTZ DEFAULT now(),
  updated_at    TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_kb_res_category ON psy_kb_resources(category_id);
CREATE INDEX IF NOT EXISTS idx_kb_res_type     ON psy_kb_resources(res_type);
CREATE INDEX IF NOT EXISTS idx_kb_res_archived ON psy_kb_resources(is_archived);
CREATE INDEX IF NOT EXISTS idx_kb_res_tags     ON psy_kb_resources USING GIN(tags);

ALTER TABLE psy_kb_resources ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "kb_res_read" ON psy_kb_resources;
CREATE POLICY "kb_res_read"  ON psy_kb_resources  FOR SELECT USING (kb_is_staff());
DROP POLICY IF EXISTS "kb_res_write" ON psy_kb_resources;
CREATE POLICY "kb_res_write" ON psy_kb_resources  FOR ALL    USING (kb_is_staff()) WITH CHECK (kb_is_staff());

DROP TRIGGER IF EXISTS trg_kb_res_touch ON psy_kb_resources;
CREATE TRIGGER trg_kb_res_touch BEFORE UPDATE ON psy_kb_resources
  FOR EACH ROW EXECUTE FUNCTION kb_touch_updated_at();

-- ──── psy_kb_versions (sejarah versi) ────
CREATE TABLE IF NOT EXISTS psy_kb_versions (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  resource_id     UUID NOT NULL REFERENCES psy_kb_resources(id) ON DELETE CASCADE,
  version         TEXT NOT NULL,
  file_url        TEXT,
  external_url    TEXT,
  file_size       BIGINT,
  changes_summary TEXT,
  is_current      BOOLEAN DEFAULT false,
  uploaded_by     UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  created_at      TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_kb_ver_resource ON psy_kb_versions(resource_id);

ALTER TABLE psy_kb_versions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "kb_ver_read" ON psy_kb_versions;
CREATE POLICY "kb_ver_read"  ON psy_kb_versions   FOR SELECT USING (kb_is_staff());
DROP POLICY IF EXISTS "kb_ver_write" ON psy_kb_versions;
CREATE POLICY "kb_ver_write" ON psy_kb_versions   FOR ALL    USING (kb_is_staff()) WITH CHECK (kb_is_staff());

-- ──── psy_kb_bookmarks (bookmark / pinned per-user) ────
CREATE TABLE IF NOT EXISTS psy_kb_bookmarks (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES psy_profiles(id) ON DELETE CASCADE,
  resource_id UUID NOT NULL REFERENCES psy_kb_resources(id) ON DELETE CASCADE,
  is_pinned   BOOLEAN DEFAULT false,
  created_at  TIMESTAMPTZ DEFAULT now(),
  UNIQUE (user_id, resource_id)
);

CREATE INDEX IF NOT EXISTS idx_kb_bm_user ON psy_kb_bookmarks(user_id);

ALTER TABLE psy_kb_bookmarks ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "kb_bm_own" ON psy_kb_bookmarks;
CREATE POLICY "kb_bm_own"    ON psy_kb_bookmarks         FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

-- ──── psy_kb_views (recently viewed per-user) ────
CREATE TABLE IF NOT EXISTS psy_kb_views (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES psy_profiles(id) ON DELETE CASCADE,
  resource_id UUID NOT NULL REFERENCES psy_kb_resources(id) ON DELETE CASCADE,
  viewed_at   TIMESTAMPTZ DEFAULT now(),
  UNIQUE (user_id, resource_id)
);

CREATE INDEX IF NOT EXISTS idx_kb_views_user ON psy_kb_views(user_id, viewed_at DESC);

ALTER TABLE psy_kb_views ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "kb_views_own" ON psy_kb_views;
CREATE POLICY "kb_views_own" ON psy_kb_views             FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

-- ──── psy_kb_note_folders (folder nota per-user) ────
CREATE TABLE IF NOT EXISTS psy_kb_note_folders (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID NOT NULL REFERENCES psy_profiles(id) ON DELETE CASCADE,
  name       TEXT NOT NULL,
  color      TEXT DEFAULT 'navy',
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_kb_folders_user ON psy_kb_note_folders(user_id);

ALTER TABLE psy_kb_note_folders ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "kb_fold_own" ON psy_kb_note_folders;
CREATE POLICY "kb_fold_own"  ON psy_kb_note_folders      FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

-- ──── psy_kb_notes (nota peribadi per-user) ────
CREATE TABLE IF NOT EXISTS psy_kb_notes (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES psy_profiles(id) ON DELETE CASCADE,
  folder_id   UUID REFERENCES psy_kb_note_folders(id) ON DELETE SET NULL,
  resource_id UUID REFERENCES psy_kb_resources(id) ON DELETE SET NULL,  -- "Add to My Notes"
  title       TEXT NOT NULL,
  body        TEXT,
  label       TEXT,          -- Checklist/Clinical Notes/Communication/Ideas/To-Do/Reference/Template/Meeting Notes/Plan/Reminder
  is_pinned   BOOLEAN DEFAULT false,
  created_at  TIMESTAMPTZ DEFAULT now(),
  updated_at  TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_kb_notes_user ON psy_kb_notes(user_id, updated_at DESC);

ALTER TABLE psy_kb_notes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "kb_notes_own" ON psy_kb_notes;
CREATE POLICY "kb_notes_own" ON psy_kb_notes             FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

DROP TRIGGER IF EXISTS trg_kb_notes_touch ON psy_kb_notes;
CREATE TRIGGER trg_kb_notes_touch BEFORE UPDATE ON psy_kb_notes
  FOR EACH ROW EXECUTE FUNCTION kb_touch_updated_at();

-- ──── psy_kb_trainings (Training Center) ────
CREATE TABLE IF NOT EXISTS psy_kb_trainings (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title         TEXT NOT NULL,
  description   TEXT,
  category      TEXT,          -- System/Clinical/Communication/Compliance/General Knowledge
  duration_min  INT DEFAULT 0,
  thumbnail_url TEXT,
  content_url   TEXT,          -- video / dokumen / resource pautan
  resource_id   UUID REFERENCES psy_kb_resources(id) ON DELETE SET NULL,
  sort_order    INT DEFAULT 100,
  is_active     BOOLEAN DEFAULT true,
  created_at    TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE psy_kb_trainings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "kb_train_read" ON psy_kb_trainings;
CREATE POLICY "kb_train_read"  ON psy_kb_trainings FOR SELECT USING (kb_is_staff());
DROP POLICY IF EXISTS "kb_train_write" ON psy_kb_trainings;
CREATE POLICY "kb_train_write" ON psy_kb_trainings FOR ALL    USING (kb_is_staff()) WITH CHECK (kb_is_staff());

-- ──── psy_kb_training_progress ────
CREATE TABLE IF NOT EXISTS psy_kb_training_progress (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID NOT NULL REFERENCES psy_profiles(id) ON DELETE CASCADE,
  training_id   UUID NOT NULL REFERENCES psy_kb_trainings(id) ON DELETE CASCADE,
  status        TEXT DEFAULT 'not_started' CHECK (status IN ('not_started','in_progress','completed')),
  progress_pct  INT DEFAULT 0,
  last_accessed TIMESTAMPTZ,
  completed_at  TIMESTAMPTZ,
  UNIQUE (user_id, training_id)
);

CREATE INDEX IF NOT EXISTS idx_kb_tprog_user ON psy_kb_training_progress(user_id);

ALTER TABLE psy_kb_training_progress ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "kb_tprog_own" ON psy_kb_training_progress;
CREATE POLICY "kb_tprog_own" ON psy_kb_training_progress FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

-- ──── psy_kb_certificates ────
CREATE TABLE IF NOT EXISTS psy_kb_certificates (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES psy_profiles(id) ON DELETE CASCADE,
  training_id UUID REFERENCES psy_kb_trainings(id) ON DELETE SET NULL,
  title       TEXT NOT NULL,
  cert_url    TEXT,
  earned_at   TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_kb_cert_user ON psy_kb_certificates(user_id);

ALTER TABLE psy_kb_certificates ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "kb_cert_own" ON psy_kb_certificates;
CREATE POLICY "kb_cert_own"  ON psy_kb_certificates      FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

-- ──── fungsi: view_count increment (RPC, elak race + patuh RLS) ────
CREATE OR REPLACE FUNCTION kb_bump_view(res UUID) RETURNS void AS $$
  UPDATE psy_kb_resources SET view_count = view_count + 1 WHERE id = res;
$$ LANGUAGE sql SECURITY DEFINER;

-- ──── seed: kategori (11) ────
INSERT INTO psy_kb_categories (name, slug, description, icon, color, sort_order) VALUES
  ('SOP',                  'sop',                  'Standard Operating Procedures dan arahan kerja.',       '📄', 'navy',       10),
  ('Clinical Guidelines',  'clinical-guidelines',  'Garis panduan klinikal, protokol dan amalan terbaik.',  '🩺', 'green',      20),
  ('Training Materials',   'training-materials',   'Modul latihan, slaid pembentangan dan bahan belajar.',  '🎓', 'gold',       30),
  ('Video Tutorials',      'video-tutorials',      'Panduan video langkah demi langkah.',                    '🎬', 'terracotta', 40),
  ('Forms & Templates',    'forms-templates',      'Template borang dan dokumen.',                           '📋', 'teal',       50),
  ('Medication References','medication-references','Maklumat ubat, interaksi dan rujukan.',                 '💊', 'navy',       60),
  ('Psychotherapy Modules','psychotherapy-modules','Modul terapi, teknik dan pendekatan rawatan.',          '🧠', 'teal',       70),
  ('FAQ',                  'faq',                  'Soalan lazim dan jawapan.',                              '❓', 'gold',       80),
  ('Policies & Procedures','policies-procedures',  'Dasar syarikat dan prosedur pentadbiran.',              '🛡️', 'navy',       90),
  ('Announcements',        'kb-announcements',     'Pengumuman dan notis penting.',                          '📢', 'green',     100),
  ('Other Resources',      'other-resources',      'Sumber dan rujukan lain yang berguna.',                  '📦', 'grey',      110)
ON CONFLICT (slug) DO NOTHING;


-- ════════════════════════════════════════════════════════════════
-- schema/23_settings.sql
-- ════════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════════
-- SKEMA: TETAPAN SISTEM (System Settings — konfigurasi global)
-- Jadual: psy_settings
-- Simpanan key/value (JSONB) untuk tetapan peringkat sistem: nama app,
-- zon masa, deadline pengesahan sesi, mod gateway pembayaran, slot masa
-- jadual, dsb. Kunci API rahsia TIDAK disimpan di sini — ia kekal di
-- env Edge Function.
-- Akses: BACA → semua staff; TULIS → super_admin sahaja.
-- ═══════════════════════════════════════════════════════════════════

-- ──── psy_settings ────
CREATE TABLE IF NOT EXISTS psy_settings (
  key        TEXT PRIMARY KEY,
  value      JSONB,
  updated_at TIMESTAMPTZ DEFAULT now(),
  updated_by UUID REFERENCES psy_profiles(id) ON DELETE SET NULL
);

ALTER TABLE psy_settings ENABLE ROW LEVEL SECURITY;

-- Semua staff boleh baca tetapan (untuk pakai nilai global di halaman lain).
DROP POLICY IF EXISTS "settings_read_staff" ON psy_settings;
CREATE POLICY "settings_read_staff" ON psy_settings
  FOR SELECT USING (settings_is_staff());

-- Pesakit turut perlu BACA sebahagian tetapan (cth clinic_phone — fallback no.
-- panggilan di seksyen Protokol Kecemasan bila coach tiada/tiada no. telefon).
-- Selamat dibuka: jadual ni TIDAK simpan kunci API rahsia (lihat nota atas).
DROP POLICY IF EXISTS "settings_read_authenticated" ON psy_settings;
CREATE POLICY "settings_read_authenticated" ON psy_settings
  FOR SELECT USING (auth.role() = 'authenticated');

-- Hanya super_admin boleh cipta / kemaskini / padam.
DROP POLICY IF EXISTS "settings_write_sa" ON psy_settings;
CREATE POLICY "settings_write_sa" ON psy_settings
  FOR ALL USING (settings_is_super_admin()) WITH CHECK (settings_is_super_admin());

-- ──── fungsi + trigger: sentuh updated_at ────
CREATE OR REPLACE FUNCTION settings_touch() RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END; $$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_settings_touch ON psy_settings;
CREATE TRIGGER trg_settings_touch BEFORE UPDATE ON psy_settings
  FOR EACH ROW EXECUTE FUNCTION settings_touch();

-- ──── seed: nilai default ────
-- Setiap baris = satu tetapan. value disimpan sebagai JSONB (skalar pun boleh).
INSERT INTO psy_settings (key, value) VALUES
  -- Umum
  ('app_name',        to_jsonb('Ibnu Sina Wellness CMS'::text)),
  ('app_version',     to_jsonb('1.0.0'::text)),
  ('language',        to_jsonb('ms'::text)),
  ('date_format',     to_jsonb('DD/MM/YYYY'::text)),
  ('timezone',        to_jsonb('Asia/Kuala_Lumpur'::text)),
  ('currency',        to_jsonb('MYR'::text)),
  -- Klinik
  ('clinic_name',     to_jsonb('Ibnu Sina Wellness'::text)),
  ('clinic_phone',    to_jsonb(''::text)),
  ('clinic_email',    to_jsonb(''::text)),
  ('clinic_address',  to_jsonb(''::text)),
  ('operating_hours', to_jsonb('9:00 pagi - 6:00 petang'::text)),
  ('session_confirm_deadline_hours', to_jsonb(24)),
  ('session_escalation_hours',       to_jsonb(12)),
  ('absence_reschedule_enabled',     to_jsonb(true)),
  -- Notifikasi (togol peringkat sistem)
  ('notif_event_reminder', to_jsonb(true)),
  ('notif_daily_checkin',  to_jsonb(false)),
  ('notif_birthday',       to_jsonb(false)),
  -- Integrasi (config BUKAN rahsia; kunci API kekal di env Edge Function)
  ('payment_provider',  to_jsonb('hitpay'::text)),
  ('payment_mode',      to_jsonb('sandbox'::text)),
  ('whatsapp_provider', to_jsonb('ghl'::text))
ON CONFLICT (key) DO NOTHING;

-- Slot masa global default untuk jadual rawatan (jika belum wujud)
INSERT INTO psy_settings (key, value) VALUES
  ('schedule_time_slots',
   '[{"value":"09:00","label":"9:00 AM"},{"value":"10:00","label":"10:00 AM"},{"value":"14:00","label":"2:00 PM"},{"value":"15:00","label":"3:00 PM"},{"value":"16:00","label":"4:00 PM"}]'::jsonb)
ON CONFLICT (key) DO NOTHING;


-- ════════════════════════════════════════════════════════════════
-- schema/24_storage.sql
-- ════════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════════
-- 24 — STORAGE (Supabase Storage)
-- Semua bucket + polisi storage.objects sistem dalam satu fail.
-- Bucket: medical-reports, kob-documents, kob-signatures, agreement-templates,
--         pakej-rujukan, wa-outbox, avatars, referral-docs, kb-media
-- Nota: polisi merujuk jadual/fungsi domain lain (psy_profiles, psy_patients,
--       kb_is_staff) — fail ini mesti dijalankan paling akhir.
-- ═══════════════════════════════════════════════════════════════════

-- ---- Buckets ----

INSERT INTO storage.buckets (id, name, public)
  VALUES ('medical-reports', 'medical-reports', false)
  ON CONFLICT (id) DO NOTHING;

INSERT INTO storage.buckets (id, name, public)
  VALUES ('kob-documents', 'kob-documents', false)
ON CONFLICT (id) DO NOTHING;

INSERT INTO storage.buckets (id, name, public)
  VALUES ('kob-signatures', 'kob-signatures', false)
ON CONFLICT (id) DO NOTHING;

INSERT INTO storage.buckets (id, name, public)
  VALUES ('agreement-templates', 'agreement-templates', false)
ON CONFLICT (id) DO NOTHING;

INSERT INTO storage.buckets (id, name, public)
  VALUES ('pakej-rujukan', 'pakej-rujukan', false)
ON CONFLICT (id) DO NOTHING;

INSERT INTO storage.buckets (id, name, public)
VALUES ('wa-outbox', 'wa-outbox', true)
ON CONFLICT (id) DO UPDATE SET public = true;

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('avatars', 'avatars', true, 5242880, ARRAY['image/png','image/jpeg','image/jpg','image/webp','image/gif'])
ON CONFLICT (id) DO UPDATE
  SET public = EXCLUDED.public,
      file_size_limit = EXCLUDED.file_size_limit,
      allowed_mime_types = EXCLUDED.allowed_mime_types;

INSERT INTO storage.buckets (id, name, public) VALUES ('referral-docs', 'referral-docs', false) ON CONFLICT DO NOTHING;

INSERT INTO storage.buckets (id, name, public) VALUES ('kb-media', 'kb-media', true)
ON CONFLICT (id) DO NOTHING;

-- Peristiwa Pesakit (lampiran dokumen/gambar) — staff sahaja
INSERT INTO storage.buckets (id, name, public) VALUES ('event-docs', 'event-docs', false)
ON CONFLICT (id) DO NOTHING;

-- DNA Test (gambar sample/barcode + 3 laporan PDF ATGC) — staff sahaja
INSERT INTO storage.buckets (id, name, public) VALUES ('dna-test', 'dna-test', false)
ON CONFLICT (id) DO NOTHING;


-- ---- Polisi storage.objects ----

DROP POLICY IF EXISTS "Staff can upload medical reports" ON storage.objects;
CREATE POLICY "Staff can upload medical reports" ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'medical-reports' AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "Staff can read all medical reports" ON storage.objects;
CREATE POLICY "Staff can read all medical reports" ON storage.objects
    FOR SELECT TO authenticated
    USING (bucket_id = 'medical-reports' AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "Patients can upload own medical reports" ON storage.objects;
CREATE POLICY "Patients can upload own medical reports" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'medical-reports'
    AND (storage.foldername(name))[1] = 'patient'
    AND EXISTS (
      SELECT 1 FROM psy_patients
      WHERE user_id = auth.uid() AND id::text = (storage.foldername(name))[2]
    )
  );

DROP POLICY IF EXISTS "Patients can read own medical reports" ON storage.objects;
CREATE POLICY "Patients can read own medical reports" ON storage.objects
    FOR SELECT TO authenticated
    USING (bucket_id = 'medical-reports' AND EXISTS (SELECT 1 FROM psy_patients WHERE user_id = auth.uid() AND id::text = (storage.foldername(name))[2]));

DROP POLICY IF EXISTS "Authenticated read agreement templates" ON storage.objects;
CREATE POLICY "Authenticated read agreement templates"
    ON storage.objects FOR SELECT
    USING (bucket_id = 'agreement-templates' AND auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "Staff manage agreement templates" ON storage.objects;
CREATE POLICY "Staff manage agreement templates"
    ON storage.objects FOR ALL
    USING (
      bucket_id = 'agreement-templates'
      AND EXISTS (
        SELECT 1 FROM psy_profiles
        WHERE id = auth.uid()
        AND role = 'staff'
        AND staff_role IN ('admin','manager','doctor')
      )
    );

DROP POLICY IF EXISTS "Patient upload own signature" ON storage.objects;
CREATE POLICY "Patient upload own signature"
    ON storage.objects FOR INSERT
    WITH CHECK (
      bucket_id = 'kob-signatures'
      AND auth.uid() IS NOT NULL
      AND (storage.foldername(name))[1] IN (
        SELECT id::text FROM psy_patients WHERE user_id = auth.uid()
      )
    );

DROP POLICY IF EXISTS "Patient read own signature" ON storage.objects;
CREATE POLICY "Patient read own signature"
    ON storage.objects FOR SELECT
    USING (
      bucket_id = 'kob-signatures'
      AND auth.uid() IS NOT NULL
      AND (storage.foldername(name))[1] IN (
        SELECT id::text FROM psy_patients WHERE user_id = auth.uid()
      )
    );

DROP POLICY IF EXISTS "Staff read all signatures" ON storage.objects;
CREATE POLICY "Staff read all signatures"
    ON storage.objects FOR SELECT
    USING (
      bucket_id = 'kob-signatures'
      AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff')
    );

DROP POLICY IF EXISTS "Staff manage kob documents" ON storage.objects;
CREATE POLICY "Staff manage kob documents"
    ON storage.objects FOR ALL
    USING (
      bucket_id = 'kob-documents'
      AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff')
    );

DROP POLICY IF EXISTS "Patient read own kob documents" ON storage.objects;
CREATE POLICY "Patient read own kob documents"
    ON storage.objects FOR SELECT
    USING (
      bucket_id = 'kob-documents'
      AND auth.uid() IS NOT NULL
      AND (storage.foldername(name))[1] IN (
        SELECT id::text FROM psy_patients WHERE user_id = auth.uid()
      )
    );

DROP POLICY IF EXISTS "Staff read pakej rujukan" ON storage.objects;
CREATE POLICY "Staff read pakej rujukan"
    ON storage.objects FOR SELECT
    USING (
      bucket_id = 'pakej-rujukan'
      AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff')
    );

DROP POLICY IF EXISTS "Staff manage pakej rujukan" ON storage.objects;
CREATE POLICY "Staff manage pakej rujukan"
    ON storage.objects FOR ALL
    USING (
      bucket_id = 'pakej-rujukan'
      AND EXISTS (
        SELECT 1 FROM psy_profiles
        WHERE id = auth.uid()
        AND role = 'staff'
        AND staff_role IN ('admin','manager','doctor')
      )
    );

DROP POLICY IF EXISTS "medical_upload" ON storage.objects;
CREATE POLICY "medical_upload" ON storage.objects FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'medical-reports');

DROP POLICY IF EXISTS "medical_read_own" ON storage.objects;
CREATE POLICY "medical_read_own" ON storage.objects FOR SELECT TO authenticated
    USING (bucket_id = 'medical-reports' AND owner = auth.uid());

DROP POLICY IF EXISTS "medical_read_staff" ON storage.objects;
CREATE POLICY "medical_read_staff" ON storage.objects FOR SELECT TO authenticated
    USING (bucket_id = 'medical-reports'
           AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "medical_delete_own" ON storage.objects;
CREATE POLICY "medical_delete_own" ON storage.objects FOR DELETE TO authenticated
    USING (bucket_id = 'medical-reports' AND owner = auth.uid());

DROP POLICY IF EXISTS "wa_outbox_staff_insert" ON storage.objects;
CREATE POLICY "wa_outbox_staff_insert" ON storage.objects FOR INSERT
    WITH CHECK (
      bucket_id = 'wa-outbox'
      AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff')
    );

DROP POLICY IF EXISTS "wa_outbox_public_read" ON storage.objects;
CREATE POLICY "wa_outbox_public_read" ON storage.objects FOR SELECT
    USING (bucket_id = 'wa-outbox');

DROP POLICY IF EXISTS "wa_outbox_staff_delete" ON storage.objects;
CREATE POLICY "wa_outbox_staff_delete" ON storage.objects FOR DELETE
    USING (
      bucket_id = 'wa-outbox'
      AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff')
    );

DROP POLICY IF EXISTS "avatars_public_read" ON storage.objects;
CREATE POLICY "avatars_public_read" ON storage.objects FOR SELECT
    USING (bucket_id = 'avatars');

DROP POLICY IF EXISTS "avatars_authenticated_upload" ON storage.objects;
CREATE POLICY "avatars_authenticated_upload" ON storage.objects FOR INSERT
    WITH CHECK (bucket_id = 'avatars' AND auth.role() = 'authenticated');

DROP POLICY IF EXISTS "avatars_owner_update" ON storage.objects;
CREATE POLICY "avatars_owner_update" ON storage.objects FOR UPDATE
    USING (bucket_id = 'avatars' AND auth.uid()::text = (storage.foldername(name))[1])
    WITH CHECK (bucket_id = 'avatars' AND auth.uid()::text = (storage.foldername(name))[1]);

DROP POLICY IF EXISTS "avatars_owner_delete" ON storage.objects;
CREATE POLICY "avatars_owner_delete" ON storage.objects FOR DELETE
    USING (bucket_id = 'avatars' AND auth.uid()::text = (storage.foldername(name))[1]);

DROP POLICY IF EXISTS "Staff upload referral docs" ON storage.objects;
CREATE POLICY "Staff upload referral docs" ON storage.objects FOR INSERT
    WITH CHECK (bucket_id = 'referral-docs' AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "Staff read referral docs" ON storage.objects;
CREATE POLICY "Staff read referral docs" ON storage.objects FOR SELECT
    USING (bucket_id = 'referral-docs' AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "Staff delete referral docs" ON storage.objects;
CREATE POLICY "Staff delete referral docs" ON storage.objects FOR DELETE
    USING (bucket_id = 'referral-docs' AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "kb_media_staff_write" ON storage.objects;
CREATE POLICY "kb_media_staff_write" ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'kb-media' AND kb_is_staff());

DROP POLICY IF EXISTS "kb_media_staff_update" ON storage.objects;
CREATE POLICY "kb_media_staff_update" ON storage.objects
    FOR UPDATE TO authenticated
    USING (bucket_id = 'kb-media' AND kb_is_staff());

DROP POLICY IF EXISTS "kb_media_staff_delete" ON storage.objects;
CREATE POLICY "kb_media_staff_delete" ON storage.objects
    FOR DELETE TO authenticated
    USING (bucket_id = 'kb-media' AND kb_is_staff());

DROP POLICY IF EXISTS "kb_media_public_read" ON storage.objects;
CREATE POLICY "kb_media_public_read" ON storage.objects
    FOR SELECT USING (bucket_id = 'kb-media');

DROP POLICY IF EXISTS "event_docs_staff_all" ON storage.objects;
CREATE POLICY "event_docs_staff_all" ON storage.objects
    FOR ALL TO authenticated
    USING (bucket_id = 'event-docs' AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
    WITH CHECK (bucket_id = 'event-docs' AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "dna_test_staff_all" ON storage.objects;
CREATE POLICY "dna_test_staff_all" ON storage.objects
    FOR ALL TO authenticated
    USING (bucket_id = 'dna-test' AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
    WITH CHECK (bucket_id = 'dna-test' AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "dna_test_patient_read_own" ON storage.objects;
CREATE POLICY "dna_test_patient_read_own" ON storage.objects
    FOR SELECT TO authenticated
    USING (
      bucket_id = 'dna-test'
      AND (storage.foldername(name))[1] IN (
        SELECT id::text FROM psy_patients WHERE user_id = auth.uid()
      )
    );

DROP POLICY IF EXISTS "Patients can upload own medical reports" ON storage.objects;
CREATE POLICY "Patients can upload own medical reports" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'medical-reports'
    AND (storage.foldername(name))[1] = 'patient'
    AND EXISTS (
      SELECT 1 FROM psy_patients
      WHERE user_id = auth.uid() AND id::text = (storage.foldername(name))[2]
    )
  );


-- ════════════════════════════════════════════════════════════════
-- schema/25_patient_events.sql
-- ════════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════════
-- 25 — PERISTIWA PESAKIT (Patient Events)
-- Rekod kejadian kritikal pesakit: masuk wad, ICU, temujanji doktor,
-- pembedahan, kecemasan, kematian, discaj, rehat rumah — dengan
-- notifikasi automatik kepada staff + penjejakan lawatan (visit).
-- Jadual: psy_patient_events, psy_patient_event_visits,
--         psy_patient_event_logs, psy_patient_event_docs
-- Trigger: notifikasi staff (loceng), auto-lockdown kematian
--          (status pesakit → deceased, automasi terhenti), log timeline.
-- Nota: bucket storage 'event-docs' didaftar dalam 24_storage.sql.
-- ═══════════════════════════════════════════════════════════════════

-- ──── psy_patient_events — jadual induk peristiwa ────
-- event_type (tiada CHECK — fleksibel utk jenis baru):
--   warded | icu | temujanji_doktor | pembedahan | kecemasan |
--   kematian | discaj | rehat_rumah
CREATE TABLE IF NOT EXISTS psy_patient_events (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id            UUID NOT NULL REFERENCES psy_patients(id) ON DELETE CASCADE,
  event_type            TEXT NOT NULL,
  priority              TEXT DEFAULT 'medium' CHECK (priority IN ('critical','high','medium','low')),
  status                TEXT DEFAULT 'open'   CHECK (status IN ('open','closed')),
  event_date            DATE NOT NULL,
  event_time            TIME,
  expected_discharge    DATE,
  hospital_name         TEXT,
  ward_room             TEXT,
  bed_unit              TEXT,
  doctor_in_charge      TEXT,
  diagnosis             TEXT,
  reference_no          TEXT,
  emergency_contact_name         TEXT,
  emergency_contact_phone        TEXT,
  emergency_contact_relationship TEXT,
  need_visit            BOOLEAN DEFAULT false,
  visit_priority        TEXT CHECK (visit_priority IS NULL OR visit_priority IN ('high','medium','low')),
  expected_visit_date   DATE,
  assigned_to           UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  notify_roles          JSONB DEFAULT '["manager","coach"]'::jsonb,
  notes                 TEXT,
  reported_by           UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  closed_by             UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  closed_at             TIMESTAMPTZ,
  created_at            TIMESTAMPTZ DEFAULT now(),
  updated_at            TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_pe_patient  ON psy_patient_events(patient_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_pe_status   ON psy_patient_events(status, event_date DESC);
CREATE INDEX IF NOT EXISTS idx_pe_type     ON psy_patient_events(event_type);
CREATE INDEX IF NOT EXISTS idx_pe_assigned ON psy_patient_events(assigned_to) WHERE assigned_to IS NOT NULL;

ALTER TABLE psy_patient_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "pe staff manage" ON psy_patient_events;
CREATE POLICY "pe staff manage" ON psy_patient_events FOR ALL
  USING (isw_is_staff()) WITH CHECK (isw_is_staff());

-- ──── psy_patient_event_visits — rekod lawatan / susulan ────
CREATE TABLE IF NOT EXISTS psy_patient_event_visits (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id          UUID NOT NULL REFERENCES psy_patient_events(id) ON DELETE CASCADE,
  patient_id        UUID REFERENCES psy_patients(id) ON DELETE CASCADE,
  visit_date        DATE NOT NULL,
  visit_time        TIME,
  visit_type        TEXT DEFAULT 'hospital' CHECK (visit_type IN ('hospital','rumah','klinik','panggilan')),
  visited_by        UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  status            TEXT DEFAULT 'pending' CHECK (status IN ('pending','in_progress','completed','cancelled')),
  patient_condition TEXT CHECK (patient_condition IS NULL OR patient_condition IN
                      ('sangat_lemah','lemah','stabil','beransur_baik','sangat_baik')),
  location          TEXT,
  ward_room         TEXT,
  person_met        TEXT,
  relationship      TEXT,
  notes             TEXT,
  vitals            JSONB DEFAULT '{}'::jsonb,   -- {bp, hr, temp, spo2, sugar}
  next_visit_date   DATE,
  next_visit_time   TIME,
  next_visit_type   TEXT,
  completed_at      TIMESTAMPTZ,
  created_by        UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  created_at        TIMESTAMPTZ DEFAULT now(),
  updated_at        TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_pev_event   ON psy_patient_event_visits(event_id, visit_date);
CREATE INDEX IF NOT EXISTS idx_pev_status  ON psy_patient_event_visits(status, visit_date);
CREATE INDEX IF NOT EXISTS idx_pev_visitor ON psy_patient_event_visits(visited_by) WHERE visited_by IS NOT NULL;

ALTER TABLE psy_patient_event_visits ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "pev staff manage" ON psy_patient_event_visits;
CREATE POLICY "pev staff manage" ON psy_patient_event_visits FOR ALL
  USING (isw_is_staff()) WITH CHECK (isw_is_staff());

-- ──── psy_patient_event_logs — timeline + nota peristiwa ────
-- action: created | updated | notified | assigned | visit_scheduled |
--         visit_completed | note | doc_uploaded | closed | reopened
CREATE TABLE IF NOT EXISTS psy_patient_event_logs (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id   UUID NOT NULL REFERENCES psy_patient_events(id) ON DELETE CASCADE,
  visit_id   UUID REFERENCES psy_patient_event_visits(id) ON DELETE SET NULL,
  actor_id   UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  actor_name TEXT,
  action     TEXT NOT NULL,
  detail     TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_pel_event ON psy_patient_event_logs(event_id, created_at);

ALTER TABLE psy_patient_event_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "pel staff manage" ON psy_patient_event_logs;
CREATE POLICY "pel staff manage" ON psy_patient_event_logs FOR ALL
  USING (isw_is_staff()) WITH CHECK (isw_is_staff());

-- ──── psy_patient_event_docs — lampiran dokumen / gambar ────
CREATE TABLE IF NOT EXISTS psy_patient_event_docs (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id         UUID NOT NULL REFERENCES psy_patient_events(id) ON DELETE CASCADE,
  visit_id         UUID REFERENCES psy_patient_event_visits(id) ON DELETE SET NULL,
  name             TEXT NOT NULL,
  path             TEXT NOT NULL,              -- path dalam bucket event-docs
  size_kb          INT,
  mime             TEXT,
  uploaded_by      UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  uploaded_by_name TEXT,
  created_at       TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ped_event ON psy_patient_event_docs(event_id);

ALTER TABLE psy_patient_event_docs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "ped staff manage" ON psy_patient_event_docs;
CREATE POLICY "ped staff manage" ON psy_patient_event_docs FOR ALL
  USING (isw_is_staff()) WITH CHECK (isw_is_staff());

-- ──── Fungsi trigger: updated_at ────
CREATE OR REPLACE FUNCTION pe_touch_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END; $$;

DROP TRIGGER IF EXISTS trg_pe_touch ON psy_patient_events;
CREATE TRIGGER trg_pe_touch BEFORE UPDATE ON psy_patient_events
  FOR EACH ROW EXECUTE FUNCTION pe_touch_updated_at();

DROP TRIGGER IF EXISTS trg_pev_touch ON psy_patient_event_visits;
CREATE TRIGGER trg_pev_touch BEFORE UPDATE ON psy_patient_event_visits
  FOR EACH ROW EXECUTE FUNCTION pe_touch_updated_at();

-- ──── Fungsi trigger: notifikasi loceng staff bila peristiwa baru ────
-- Penerima = coach pesakit (jika 'coach' dlm notify_roles) + semua staff
-- dgn staff_role dalam notify_roles + staff yang ditugaskan (assigned_to).
-- Dedup penerima; notifikasi type='event' → peristiwa-detail.html.
CREATE OR REPLACE FUNCTION trg_patient_event_notify()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_patient_name TEXT;
  v_coach        UUID;
  v_roles        JSONB;
  v_recipients   UUID[] := '{}';
  v_uid          UUID;
  v_title        TEXT;
  v_body         TEXT;
  v_type_lbl     TEXT;
BEGIN
  SELECT COALESCE(pr.full_name, pt.full_name, pt.mrn, 'Pesakit'), pt.coach_id
    INTO v_patient_name, v_coach
  FROM psy_patients pt
  LEFT JOIN psy_profiles pr ON pr.id = pt.user_id
  WHERE pt.id = NEW.patient_id;

  v_roles := COALESCE(NEW.notify_roles, '["manager","coach"]'::jsonb);

  IF v_roles ? 'coach' AND v_coach IS NOT NULL THEN
    v_recipients := array_append(v_recipients, v_coach);
  END IF;

  FOR v_uid IN
    SELECT id FROM psy_profiles
    WHERE role = 'staff'
      AND staff_role IN (SELECT jsonb_array_elements_text(v_roles))
      AND staff_role <> 'coach'
  LOOP
    v_recipients := array_append(v_recipients, v_uid);
  END LOOP;

  IF NEW.assigned_to IS NOT NULL THEN
    v_recipients := array_append(v_recipients, NEW.assigned_to);
  END IF;

  v_type_lbl := CASE NEW.event_type
    WHEN 'warded'           THEN 'Masuk Wad'
    WHEN 'icu'              THEN 'ICU'
    WHEN 'temujanji_doktor' THEN 'Temujanji Doktor'
    WHEN 'pembedahan'       THEN 'Pembedahan'
    WHEN 'kecemasan'        THEN 'Kecemasan'
    WHEN 'kematian'         THEN 'Meninggal Dunia'
    WHEN 'discaj'           THEN 'Discaj'
    WHEN 'rehat_rumah'      THEN 'Rehat di Rumah'
    ELSE NEW.event_type END;

  IF NEW.event_type = 'kematian' THEN
    v_title := '🕊️ Kematian: ' || v_patient_name;
    v_body  := 'Salam takziah. ' || v_patient_name || ' telah dilaporkan meninggal dunia'
               || COALESCE(' di ' || NEW.hospital_name, '') || ' pada '
               || to_char(NEW.event_date, 'DD/MM/YYYY')
               || '. Semua automasi & mesej kepada pesakit ini dihentikan secara automatik.';
  ELSIF NEW.priority = 'critical' THEN
    v_title := '🚨 KRITIKAL — ' || v_type_lbl || ': ' || v_patient_name;
    v_body  := v_patient_name || ' — ' || v_type_lbl
               || COALESCE(' di ' || NEW.hospital_name, '')
               || ' (' || to_char(NEW.event_date, 'DD/MM/YYYY') || ').'
               || CASE WHEN NEW.need_visit THEN ' Perlu lawatan — sila atur & maklum manager.' ELSE '' END;
  ELSE
    v_title := '🏥 ' || v_type_lbl || ': ' || v_patient_name;
    v_body  := v_patient_name || ' — ' || v_type_lbl
               || COALESCE(' di ' || NEW.hospital_name, '')
               || ' (' || to_char(NEW.event_date, 'DD/MM/YYYY') || ').'
               || CASE WHEN NEW.need_visit THEN ' Perlu lawatan.' ELSE '' END;
  END IF;

  FOR v_uid IN SELECT DISTINCT u FROM unnest(v_recipients) u LOOP
    INSERT INTO psy_notifications (user_id, type, title, body, link)
    VALUES (v_uid, 'event', v_title, v_body, 'peristiwa-detail.html?id=' || NEW.id);
  END LOOP;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE LOG 'trg_patient_event_notify: %', SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_patient_event_notify ON psy_patient_events;
CREATE TRIGGER trg_patient_event_notify
  AFTER INSERT ON psy_patient_events
  FOR EACH ROW EXECUTE FUNCTION trg_patient_event_notify();

-- ──── Fungsi trigger: auto-lockdown bila peristiwa KEMATIAN ────
-- status pesakit → 'deceased' + outcome 'meninggal'. Kesan: semua automasi/
-- mesej auto (WA, peringatan, birthday) skip pesakit ini kerana penapis
-- status='active'; tawaran sambungan pakej yang pending dibatalkan.
CREATE OR REPLACE FUNCTION trg_patient_event_kematian()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NEW.event_type <> 'kematian' THEN RETURN NEW; END IF;

  UPDATE psy_patients SET
    status            = 'deceased',
    outcome_status    = 'meninggal',
    outcome_status_at = now(),
    outcome_status_notes = COALESCE(outcome_status_notes,
      'Direkod melalui modul Peristiwa Pesakit (' || to_char(NEW.event_date,'DD/MM/YYYY') || ')')
  WHERE id = NEW.patient_id;

  -- Batal tawaran sambungan pakej yang belum diterima (jika modul wujud)
  BEGIN
    IF to_regclass('public.psy_continuity_offers') IS NOT NULL THEN
      EXECUTE 'UPDATE psy_continuity_offers SET status = ''cancelled''
               WHERE patient_id = $1 AND status = ''pending''' USING NEW.patient_id;
    END IF;
  EXCEPTION WHEN OTHERS THEN
    RAISE LOG 'trg_patient_event_kematian (continuity): %', SQLERRM;
  END;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE LOG 'trg_patient_event_kematian: %', SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_patient_event_kematian ON psy_patient_events;
CREATE TRIGGER trg_patient_event_kematian
  AFTER INSERT ON psy_patient_events
  FOR EACH ROW EXECUTE FUNCTION trg_patient_event_kematian();

-- ──── Fungsi trigger: log 'created' automatik ke timeline ────
CREATE OR REPLACE FUNCTION trg_patient_event_log_created()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_name TEXT;
BEGIN
  SELECT full_name INTO v_name FROM psy_profiles WHERE id = NEW.reported_by;
  INSERT INTO psy_patient_event_logs (event_id, actor_id, actor_name, action, detail)
  VALUES (NEW.id, NEW.reported_by, v_name, 'created',
          'Peristiwa direkodkan' || COALESCE(' oleh ' || v_name, ''));
  INSERT INTO psy_patient_event_logs (event_id, action, detail)
  VALUES (NEW.id, 'notified',
          'Notifikasi dihantar kepada: ' ||
          COALESCE((SELECT string_agg(x, ', ') FROM jsonb_array_elements_text(
            COALESCE(NEW.notify_roles,'["manager","coach"]'::jsonb)) x), '-'));
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE LOG 'trg_patient_event_log_created: %', SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_patient_event_log_created ON psy_patient_events;
CREATE TRIGGER trg_patient_event_log_created
  AFTER INSERT ON psy_patient_events
  FOR EACH ROW EXECUTE FUNCTION trg_patient_event_log_created();


-- ════════════════════════════════════════════════════════════════
-- schema/26_dna_test.sql
-- ════════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════════
-- 26 — DNA TEST (OH MY GENE / ATGC)
-- Proses ujian DNA per-pesakit: Sample Collection → Barcode & Packaging
-- → Activate Kit (ATGC) → Muat Naik Laporan → Consultation → Completed.
-- Jadual: psy_dna_test_process (satu baris = satu proses ujian DNA).
-- Nota: bucket storage 'dna-test' didaftar dalam 24_storage.sql.
-- Nota: Consultation (Step 5) reuse psy_appointments sedia ada
--       (service='DNA Test Consultation'), rujuk via appointment_id.
-- ═══════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS psy_dna_test_process (
  id                              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id                      UUID NOT NULL REFERENCES psy_patients(id) ON DELETE CASCADE,
  coach_id                        UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  current_step                    INT NOT NULL DEFAULT 1 CHECK (current_step BETWEEN 1 AND 6),
  status                          TEXT NOT NULL DEFAULT 'in_progress'
                                    CHECK (status IN ('in_progress','completed','cancelled')),

  -- Step 1: Sample Collection
  kit_received_at                 DATE,       -- tarikh pesakit terima DNA Test Kit
  sample_checklist                JSONB DEFAULT '{}'::jsonb,
  sample_notes                    TEXT,
  sample_collected_at             TIMESTAMPTZ,
  sample_collected_by             UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,

  -- Step 2: Barcode & Packaging
  barcode_number                  TEXT,
  packaging_checklist             JSONB DEFAULT '{}'::jsonb,
  sample_photo_path               TEXT,
  packaging_notes                 TEXT,
  packaging_completed_at          TIMESTAMPTZ,
  sample_sent_to_lab_at           DATE,       -- tarikh sample dihantar ke makmal

  -- Step 3: Activate Kit (ATGC — portal luar, dikemaskini manual)
  atgc_status                     TEXT DEFAULT 'not_activated' CHECK (atgc_status IN ('not_activated','activated')),
  atgc_activated_at               TIMESTAMPTZ,
  atgc_activated_by               UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,

  -- Step 4: Muat Naik Laporan DNA (dari portal ATGC — boleh >1 fail setiap kategori)
  -- report_files: {"plant_based": ["path1","path2"], "health_risk": [...], "carrier_drug": [...]}
  report_files                    JSONB DEFAULT '{}'::jsonb,
  report_notes                    TEXT,
  reports_uploaded_at              TIMESTAMPTZ,
  lab_report_issued_at            DATE,       -- tarikh laporan dikeluarkan oleh lab (bukan tarikh upload)
  reports_emailed_at              TIMESTAMPTZ, -- tarikh laporan dihantar ke pesakit via emel

  -- Step 5: Consultation (reuse psy_appointments)
  appointment_id                  UUID REFERENCES psy_appointments(id) ON DELETE SET NULL,
  consultation_prep_checklist     JSONB DEFAULT '{}'::jsonb,
  consultation_notes              TEXT,
  consultation_marked_ready_at    TIMESTAMPTZ,
  consultation_attachments        JSONB DEFAULT '[]'::jsonb,  -- lampiran bebas (skrip/nota/dll) khusus proses ni

  -- Step 6: Completed
  completed_at                    TIMESTAMPTZ,
  completed_by                    UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,

  created_by                      UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  created_at                      TIMESTAMPTZ DEFAULT now(),
  updated_at                      TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_dna_test_patient ON psy_dna_test_process(patient_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_dna_test_status  ON psy_dna_test_process(status);

ALTER TABLE psy_dna_test_process ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "dna_test staff manage" ON psy_dna_test_process;
CREATE POLICY "dna_test staff manage" ON psy_dna_test_process FOR ALL
  USING (isw_is_staff()) WITH CHECK (isw_is_staff());

DROP POLICY IF EXISTS "dna_test patient read own" ON psy_dna_test_process;
CREATE POLICY "dna_test patient read own" ON psy_dna_test_process FOR SELECT
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

-- ──── Fungsi trigger: updated_at ────
CREATE OR REPLACE FUNCTION dna_test_touch_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END; $$;

DROP TRIGGER IF EXISTS trg_dna_test_touch ON psy_dna_test_process;
CREATE TRIGGER trg_dna_test_touch BEFORE UPDATE ON psy_dna_test_process
  FOR EACH ROW EXECUTE FUNCTION dna_test_touch_updated_at();

COMMENT ON COLUMN psy_dna_test_process.atgc_status IS
  'ATGC = portal lab luar (ohmygene). Diaktifkan manual oleh coach di luar sistem, status dikemaskini manual selepas itu.';


-- ════════════════════════════════════════════════════════════════
-- schema/27_affiliate.sql
-- ════════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════════
-- 27 — AFFILIATE (KOMISEN RUJUKAN PESAKIT + PAYOUT)
-- Extend fasa 1 rujukan (20_referrals.sql, psy_referrals): ganjaran kini
-- boleh jadi komisen RM sebenar (bukan sekadar baucar manual), kadar
-- boleh beza ikut pakej (psy_affiliate_commission_rules), dan staff boleh
-- proses bayaran keluar (psy_affiliate_payouts). Skop: pesakit sedia ada
-- sahaja (guna psy_patients.referral_code + psy_referrals yang dah wujud)
-- — bukan affiliate luar/influencer dengan login berasingan.
--
-- Payout guna bank transfer MANUAL dahulu (staff proses & tandakan
-- dibayar). Kolum `method` sengaja termasuk 'hitpay' sebagai tempat letak
-- masa depan — automasi HitPay Payout/Send API belum disambung (perlu
-- akses/approval berasingan yang belum disahkan).
-- ═══════════════════════════════════════════════════════════════════

-- ──── psy_affiliate_commission_rules — kadar komisen per pakej ────
CREATE TABLE IF NOT EXISTS psy_affiliate_commission_rules (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  package_id       UUID REFERENCES psy_packages(id) ON DELETE CASCADE, -- NULL = kadar lalai (pakej lain)
  commission_type  TEXT NOT NULL DEFAULT 'fixed' CHECK (commission_type IN ('fixed','percent')),
  amount           NUMERIC(10,2),  -- RM tetap (bila commission_type='fixed')
  rate_percent     NUMERIC(5,2),   -- % (bila commission_type='percent')
  cap_amount       NUMERIC(10,2),  -- had maksimum RM utk 'percent' (NULL = tiada had)
  is_active        BOOLEAN DEFAULT true,
  created_at       TIMESTAMPTZ DEFAULT now(),
  updated_at       TIMESTAMPTZ DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_psy_affiliate_commission_rules_package
  ON psy_affiliate_commission_rules (package_id)
  WHERE package_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS uq_psy_affiliate_commission_rules_default
  ON psy_affiliate_commission_rules ((1))
  WHERE package_id IS NULL;

ALTER TABLE psy_affiliate_commission_rules ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff manage commission rules" ON psy_affiliate_commission_rules;
CREATE POLICY "Staff manage commission rules" ON psy_affiliate_commission_rules FOR ALL
  USING      (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
  WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- Kadar lalai (package_id NULL) — wajib wujud supaya pakej tanpa rule
-- khusus tetap dapat komisen asas RM50.
INSERT INTO psy_affiliate_commission_rules (package_id, commission_type, amount)
SELECT NULL, 'fixed', 50.00
WHERE NOT EXISTS (SELECT 1 FROM psy_affiliate_commission_rules WHERE package_id IS NULL);

-- ──── psy_patients — maklumat bank (untuk payout) ────
ALTER TABLE psy_patients ADD COLUMN IF NOT EXISTS bank_name TEXT;
ALTER TABLE psy_patients ADD COLUMN IF NOT EXISTS bank_account_no TEXT;
ALTER TABLE psy_patients ADD COLUMN IF NOT EXISTS bank_account_holder TEXT;

-- ──── psy_referrals — tambah kolum komisen ────
ALTER TABLE psy_referrals ADD COLUMN IF NOT EXISTS qualifying_payment_id UUID REFERENCES psy_payments(id) ON DELETE SET NULL;
ALTER TABLE psy_referrals ADD COLUMN IF NOT EXISTS qualifying_package_id UUID REFERENCES psy_packages(id) ON DELETE SET NULL;
ALTER TABLE psy_referrals ADD COLUMN IF NOT EXISTS commission_amount NUMERIC(10,2) DEFAULT 0;
ALTER TABLE psy_referrals ADD COLUMN IF NOT EXISTS payout_id UUID; -- FK ditambah di bawah (selepas psy_affiliate_payouts wujud)

-- ──── psy_affiliate_payouts — lejar bayaran keluar (batch per pesakit) ────
CREATE TABLE IF NOT EXISTS psy_affiliate_payouts (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id    UUID NOT NULL REFERENCES psy_patients(id) ON DELETE CASCADE,
  amount        NUMERIC(10,2) NOT NULL,
  status        TEXT NOT NULL DEFAULT 'processing' CHECK (status IN ('pending','processing','paid','rejected')),
  method        TEXT NOT NULL DEFAULT 'bank_transfer' CHECK (method IN ('bank_transfer','hitpay')),
  bank_snapshot JSONB DEFAULT '{}'::jsonb, -- salinan bank_name/account_no/holder masa payout dicipta
  payout_ref    TEXT,                      -- rujukan transaksi (manual, atau HitPay txn id kelak)
  note          TEXT,
  requested_at  TIMESTAMPTZ DEFAULT now(),
  processed_at  TIMESTAMPTZ,
  processed_by  UUID REFERENCES psy_profiles(id)
);

CREATE INDEX IF NOT EXISTS idx_psy_affiliate_payouts_patient ON psy_affiliate_payouts(patient_id, status);

ALTER TABLE psy_affiliate_payouts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Patients view own payouts" ON psy_affiliate_payouts;
CREATE POLICY "Patients view own payouts" ON psy_affiliate_payouts FOR SELECT
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

-- Payout dicipta oleh STAFF sahaja (staff proses & cetuskan bayaran, cth
-- sekali sebulan) — pesakit tak "mohon", cuma tengok status di profile.
DROP POLICY IF EXISTS "Staff manage payouts" ON psy_affiliate_payouts;
CREATE POLICY "Staff manage payouts" ON psy_affiliate_payouts FOR ALL
  USING      (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
  WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- FK psy_referrals.payout_id → psy_affiliate_payouts (jadual sasaran kini wujud)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE constraint_name = 'fk_psy_referrals_payout' AND table_name = 'psy_referrals'
  ) THEN
    ALTER TABLE psy_referrals
      ADD CONSTRAINT fk_psy_referrals_payout FOREIGN KEY (payout_id)
      REFERENCES psy_affiliate_payouts(id) ON DELETE SET NULL;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_psy_referrals_payout ON psy_referrals(payout_id);

-- ──── psy_notifications: benarkan type 'affiliate' ────
-- GOTCHA (dah pernah berlaku): ADD CONSTRAINT hardcode senarai 'type' boleh
-- gagal/mengecilkan liputan di PROD sebab constraint sebenar mungkin dah
-- melencong dari senarai inline dalam CREATE TABLE (banyak jenis notif
-- ditambah oleh modul lain, cth 'emergency'/'patient_event', tanpa
-- constraint fail ini diselaraskan). Jadi kita kekalkan SEMUA nilai type
-- sedia ada dalam jadual + tambah 'affiliate', bukan tulis semula senarai.
DO $$
DECLARE
  v_types TEXT;
BEGIN
  SELECT COALESCE(string_agg(DISTINCT quote_literal(type), ','), '') INTO v_types
  FROM psy_notifications;

  IF v_types = '' THEN
    v_types := quote_literal('system');
  END IF;
  IF position('affiliate' in v_types) = 0 THEN
    v_types := v_types || ',' || quote_literal('affiliate');
  END IF;

  ALTER TABLE psy_notifications DROP CONSTRAINT IF EXISTS psy_notifications_type_check;
  EXECUTE format(
    'ALTER TABLE psy_notifications ADD CONSTRAINT psy_notifications_type_check CHECK (type IN (%s))',
    v_types
  );
END $$;

-- ──── fn: kelayakan & kira komisen bila bayaran pesakit selesai ────
CREATE OR REPLACE FUNCTION trg_referral_qualify_on_payment()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_ref_id    UUID;
  v_pkg_text  TEXT;
  v_pkg_id    UUID;
  v_rule      RECORD;
  v_amount    NUMERIC(10,2);
  v_referrer_patient_id UUID;
  v_referrer_user_id    UUID;
BEGIN
  IF NEW.status IS DISTINCT FROM 'completed' OR NEW.patient_id IS NULL THEN
    RETURN NEW;
  END IF;
  IF TG_OP = 'UPDATE' AND OLD.status = 'completed' THEN
    RETURN NEW; -- elak kira dua kali
  END IF;

  SELECT id, referrer_patient_id INTO v_ref_id, v_referrer_patient_id FROM psy_referrals
  WHERE referee_patient_id = NEW.patient_id AND status = 'pending'
  LIMIT 1;
  IF v_ref_id IS NULL THEN
    RETURN NEW;
  END IF;

  -- Cuba kesan pakej dari baris pertama items[] (teks kod ATAU UUID —
  -- ikut ketidakkonsistenan active_package_id yang direkod dlm memory).
  BEGIN
    v_pkg_text := NEW.items -> 0 ->> 'packageId';
  EXCEPTION WHEN OTHERS THEN
    v_pkg_text := NULL;
  END;

  IF v_pkg_text IS NOT NULL THEN
    SELECT id INTO v_pkg_id FROM psy_packages
    WHERE id::text = v_pkg_text OR package_id = v_pkg_text
    LIMIT 1;
  END IF;

  SELECT * INTO v_rule FROM psy_affiliate_commission_rules
  WHERE package_id = v_pkg_id AND is_active LIMIT 1;

  IF NOT FOUND THEN
    SELECT * INTO v_rule FROM psy_affiliate_commission_rules
    WHERE package_id IS NULL AND is_active LIMIT 1;
  END IF;

  IF v_rule.id IS NOT NULL THEN
    IF v_rule.commission_type = 'fixed' THEN
      v_amount := COALESCE(v_rule.amount, 0);
    ELSE
      v_amount := ROUND(COALESCE(NEW.total, 0) * COALESCE(v_rule.rate_percent, 0) / 100, 2);
      IF v_rule.cap_amount IS NOT NULL THEN
        v_amount := LEAST(v_amount, v_rule.cap_amount);
      END IF;
    END IF;
  ELSE
    v_amount := 0;
  END IF;

  UPDATE psy_referrals SET
    status = 'qualified',
    qualified_at = now(),
    qualifying_payment_id = NEW.id,
    qualifying_package_id = v_pkg_id,
    commission_amount = v_amount
  WHERE id = v_ref_id;

  INSERT INTO psy_notifications (user_id, type, title, body, link)
  SELECT id, 'affiliate',
    '💰 Komisen Affiliate Layak',
    'Satu rujukan pesakit layak komisen RM ' || v_amount::text || '.',
    'affiliate.html'
  FROM psy_profiles WHERE role = 'staff';

  -- Bagitahu pesakit perujuk juga (kalau ada akaun) — supaya dia tahu
  -- serta-merta tanpa perlu check Profile secara manual.
  IF v_amount > 0 THEN
    SELECT user_id INTO v_referrer_user_id FROM psy_patients WHERE id = v_referrer_patient_id;
    IF v_referrer_user_id IS NOT NULL THEN
      INSERT INTO psy_notifications (user_id, type, title, body, link)
      VALUES (
        v_referrer_user_id, 'affiliate',
        '🎉 Kawan Anda Dah Daftar!',
        'Anda layak komisen RM ' || v_amount::text || ' dari rujukan anda.',
        'profile.html'
      );
    END IF;
  END IF;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE LOG 'trg_referral_qualify_on_payment: %', SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_referral_qualify_on_payment ON psy_payments;
CREATE TRIGGER trg_referral_qualify_on_payment
  AFTER INSERT OR UPDATE ON psy_payments
  FOR EACH ROW EXECUTE FUNCTION trg_referral_qualify_on_payment();


-- ════════════════════════════════════════════════════════════════
-- schema/28_rewards.sql
-- ════════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════════
-- 28 — GANJARAN (REWARD/VOUCHER — GENERIK)
-- Jadual: psy_vouchers — lejar baucar RM generik, boleh dijana oleh
-- PELBAGAI jenis peraturan ganjaran (source_type) yang akan bertambah
-- dari semasa ke semasa (cth 'referral_signup' sekarang, akan datang:
-- 'spend_threshold', 'checkin_streak', dll). Setiap peraturan cuma
-- perlu INSERT satu baris ke jadual ni bila syarat dipenuhi — logik
-- redeem (tolak dari total checkout) ditulis SEKALI dalam
-- payments-initiate & terpakai untuk semua jenis ganjaran selamanya.
-- ═══════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS psy_vouchers (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id        UUID NOT NULL REFERENCES psy_patients(id) ON DELETE CASCADE,
  source_type       TEXT NOT NULL,      -- 'referral_signup' | 'spend_threshold' | 'checkin_streak' | 'manual' | ...
  source_ref        UUID,               -- rujukan longgar ke rekod asal (cth psy_referrals.id) — tiada FK sebab jadual sumber berbeza ikut source_type
  amount            NUMERIC(10,2) NOT NULL CHECK (amount > 0),
  status            TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active','used','expired','void')),
  note              TEXT,
  expires_at        TIMESTAMPTZ,        -- NULL = tiada tarikh luput
  used_at           TIMESTAMPTZ,
  used_in_payment_id UUID REFERENCES psy_payments(id) ON DELETE SET NULL,
  created_at        TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_psy_vouchers_patient_active
  ON psy_vouchers(patient_id, status, created_at);

ALTER TABLE psy_vouchers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Patients view own vouchers" ON psy_vouchers;
CREATE POLICY "Patients view own vouchers" ON psy_vouchers FOR SELECT
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Staff manage vouchers" ON psy_vouchers;
CREATE POLICY "Staff manage vouchers" ON psy_vouchers FOR ALL
  USING      (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
  WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- ──── Peraturan #1: baucar untuk pesakit yang DIRUJUK (referee) ────
-- Bila rekod psy_referrals baru dicipta (status='pending', masa KYC
-- diluluskan), terus jana SATU baucar aktif untuk pesakit yang dirujuk
-- (referee) — layak digunakan pada pembelian PAKEJ PERTAMA dia.
-- Kadar RM boleh diubah staff di Tetapan → Affiliate (psy_settings
-- key 'referral_signup_voucher_amount'), lalai RM30.
CREATE OR REPLACE FUNCTION trg_create_referral_signup_voucher()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_amount NUMERIC(10,2);
BEGIN
  IF NEW.referee_patient_id IS NULL THEN RETURN NEW; END IF;

  SELECT (value #>> '{}')::numeric INTO v_amount
  FROM psy_settings WHERE key = 'referral_signup_voucher_amount';
  v_amount := COALESCE(v_amount, 30);

  INSERT INTO psy_vouchers (patient_id, source_type, source_ref, amount, note)
  VALUES (
    NEW.referee_patient_id, 'referral_signup', NEW.id, v_amount,
    'Baucar pendaftaran — guna kod rujukan ' || COALESCE(NEW.code_used, '')
  );

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE LOG 'trg_create_referral_signup_voucher: %', SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_create_referral_signup_voucher ON psy_referrals;
CREATE TRIGGER trg_create_referral_signup_voucher
  AFTER INSERT ON psy_referrals
  FOR EACH ROW EXECUTE FUNCTION trg_create_referral_signup_voucher();

-- ──── Redeem: tandakan baucar 'used' bila bayaran yang memakainya selesai ────
-- payments-initiate simpan voucherId dalam psy_payments.intent bila baucar
-- diguna pakai (total dah ditolak). Trigger ni sahkan bayaran itu betul-
-- betul SELESAI sebelum kunci baucar (elak bayaran gagal/dibatal "makan"
-- baucar orang).
CREATE OR REPLACE FUNCTION trg_voucher_mark_used_on_payment()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_voucher_id UUID;
BEGIN
  IF NEW.status IS DISTINCT FROM 'completed' THEN RETURN NEW; END IF;
  IF TG_OP = 'UPDATE' AND OLD.status = 'completed' THEN RETURN NEW; END IF;

  v_voucher_id := (NEW.intent ->> 'voucherId')::uuid;
  IF v_voucher_id IS NULL THEN RETURN NEW; END IF;

  UPDATE psy_vouchers SET status = 'used', used_at = now(), used_in_payment_id = NEW.id
  WHERE id = v_voucher_id AND status = 'active';

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE LOG 'trg_voucher_mark_used_on_payment: %', SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_voucher_mark_used_on_payment ON psy_payments;
CREATE TRIGGER trg_voucher_mark_used_on_payment
  AFTER INSERT OR UPDATE ON psy_payments
  FOR EACH ROW EXECUTE FUNCTION trg_voucher_mark_used_on_payment();
