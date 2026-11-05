-- ISW System — master_migration.sql
-- DIJANA AUTOMATIK daripada database/schema/*.sql — JANGAN edit fail ini terus.
-- Edit fail domain dalam database/schema/, kemudian jalankan: python database/_generate_master.py
-- Generated: 2026-11-05T01:48:25.748590Z
-- Jumlah fail: 41
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

-- ──── seed: actions (8 standard) ────
-- 'reschedule' & 'complete' ditambah 8 Okt 2026 (audit management #101) — asalnya
-- Sesi 1:1 (modul 'rujukan') cuma guna 3 action generik create/edit/delete; kini
-- reschedule (tukar/batal tempahan) & complete (tandakan selesai) dipisah supaya
-- boleh diberi/ditarik kebenaran berasingan drpd "Edit nota" biasa. Action ni GLOBAL
-- (ikut corak sedia ada psy_actions × psy_modules penuh — tiada cell "—"), jadi akan
-- muncul jugak sbg togol utk modul lain dlm peranan.html walau tak semua modul pakai —
-- sama macam 'export'/'settings' sedia ada utk sesetengah modul yg tiada ciri eksport/tetapan.
INSERT INTO psy_actions (code, label, icon, sort_order) VALUES
  ('view',        'Lihat',             '👁️',  10),
  ('create',      'Tambah',            '➕',  20),
  ('edit',        'Edit',              '✏️',  30),
  ('reschedule',  'Jadual Semula',     '📅',  32),
  ('complete',    'Tandakan Selesai',  '✅',  34),
  ('delete',      'Padam',             '🗑️',  40),
  ('export',      'Eksport',           '📤',  50),
  ('settings',    'Tetapan',           '⚙️',  60)
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

-- 'direktori_cadangan' (Restoran & Tempat Makan) DIBUANG 7 Okt 2026 —
-- halaman direktori-cadangan.html dipadam, digabung terus ke modul
-- 'produk_bahan' (psy_recommended_products.item_type='kedai_makan').
-- CASCADE buang grant lama sekali.
DELETE FROM psy_modules WHERE code = 'direktori_cadangan';

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
  ('production_recordings', 'Jadual Rakaman Production', '🎥', 'staff', 86),
  -- OPERASI
  ('package',          'Pakej & Pembayaran',   '🗂️', 'staff',  90),
  ('products',         'Produk',               '🛍️', 'staff', 100),
  -- Modul baharu (audit management Tier 5, VI & VII) — 24 Sept 2026
  -- 'direktori_cadangan' DIBUANG 7 Okt 2026, digabung ke 'produk_bahan' (atas).
  ('produk_bahan',      'Produk & Bahan Luar',  '🧴', 'staff', 101),
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
  ('pat_payment',      'Pembayaran',           '💳', 'patient', 90),
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
  ('coach',       'Coach',       'Coach — pesakit ditugaskan, plan, sesi coaching.', 'gold', '🧑‍🏫', true, 50),
  ('telesale',    'Telesale',    'Telesale — urus lead & KOB (onboarding), pembayaran & slot konsultasi.', 'orange', '📞', true, 55)
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
  ('coaching'),('inventory'),('communication'),('operations'),
  ('produk_bahan'),
  -- Audit management batch 3 (30 Sept 2026): laporan pakej (siap/berhenti/
  -- meninggal per-pakej) mesti nampak utk doktor jugak, bukan admin sahaja.
  ('package'),('pakej_laporan')
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
  ('coaching'),('inventory'),('communication'),('operations'),
  ('produk_bahan'),
  -- Audit management batch 3 (30 Sept 2026): sama macam doktor di atas.
  ('package'),('pakej_laporan')
) AS m(code)
ON CONFLICT DO NOTHING;

-- Telesale: fokus KOB (onboarding) & lead — pesakit, pakej, pembayaran, slot.
INSERT INTO psy_role_module_actions (role_code, module_code, action_code)
SELECT 'telesale', m.code, 'view'
FROM (VALUES
  ('dashboard'),('patient'),('kyc'),('schedule'),
  ('kob'),('kob_slots'),('package'),('payment'),
  ('announcements'),('events'),
  ('communication'),('operations')
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

-- 3b) Grant 'reschedule' + 'complete' khusus modul 'rujukan' (Sesi 1:1) — audit #101.
-- TIDAK dikembangkan macam langkah 3 (yg auto-bagi create/edit/delete/export kpd
-- semua modul staff yg ada 'view'), sbb 2 action ni khusus Sesi 1:1 sahaja. Role yg
-- sebelum ni dah ada rujukan.edit/delete penuh (super_admin/manager/admin/doctor/coach)
-- diberi explicit di sini supaya kebenaran SEDIA ADA tak jadi lebih ketat drpd sebelum
-- pemisahan granular ni — cuma lebih terperinci skrg (boleh admin tarik balik ikut keperluan).
INSERT INTO psy_role_module_actions (role_code, module_code, action_code)
SELECT r.role_code, 'rujukan', a.action_code
FROM (VALUES ('super_admin'), ('manager'), ('admin'), ('doctor'), ('coach')) AS r(role_code)
CROSS JOIN (VALUES ('reschedule'), ('complete')) AS a(action_code)
ON CONFLICT DO NOTHING;

-- 3c) Modul "Jadual Rakaman Production" (audit 21 Okt 2026) — notifikasi WhatsApp
-- Team Production (luar sistem) bila pesakit capai milestone rakaman progress
-- report. Halaman ni LOG BACA-SAHAJA (lanjutan 21 Okt — tiada butang tindakan,
-- Team Production tiada akaun ISW & tiada staf ditugaskan follow-up balik),
-- jadi 'view' je yg bermakna utk semua role. Coach diberi eksplisit di sini
-- (SELEPAS langkah 3 sweep di atas) supaya tak ter-kembang; super_admin/manager/
-- admin pula dapat 'view' automatik (sweep scope='staff') — create/edit/delete/
-- export turut terkembang sekali ikut sweep tu tapi tiada UI guna pun, harmless.
INSERT INTO psy_role_module_actions (role_code, module_code, action_code)
VALUES ('coach', 'production_recordings', 'view')
ON CONFLICT DO NOTHING;

-- 4) Grant portal pesakit (role 'patient').
INSERT INTO psy_role_module_actions (role_code, module_code, action_code) VALUES
  ('patient', 'pat_announcements', 'view'),
  ('patient', 'pat_events',        'view'),
  ('patient', 'pat_payment',       'view'),
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
  postcode                        TEXT,
  city                            TEXT,
  state                           TEXT,
  emergency_contact_name          TEXT,
  emergency_contact_phone         TEXT,
  emergency_contact_ic            TEXT,
  emergency_contact_relationship  TEXT,
  emergency_contact_email         TEXT,
  contact_preference              TEXT DEFAULT 'pesakit' CHECK (contact_preference IN ('pesakit','waris')),
  -- Sejauh mana pendaftar (kalau bukan pesakit sendiri) terlibat isi borang.
  -- BEZA drpd contact_preference (siapa) — ni "sejauh mana" (urus penuh /
  -- bantu isi sahaja / sendiri). Sumber: GHL {{contact.anda_mengisi_borang_ini_sebagai}}.
  registrant_capacity             TEXT,
  -- ID dalaman contact GHL ({{contact.id}}) — rujukan pantas/debug & future
  -- API call terus ke GHL. TIDAK dipakai untuk padanan pesakit (kekal ikut
  -- telefon) — sekadar simpanan rujukan.
  ghl_contact_id                  TEXT,
  insurance_provider              TEXT,
  insurance_policy                TEXT,
  referral_source                 TEXT,
  medical_condition               TEXT,
  condition_duration              TEXT,
  medical_notes                   TEXT,
  -- Ditambah 8 Okt 2026 (audit #20) — flag eksplisit ditandakan staf (checkbox),
  -- BUKAN keyword-matching pada medical_condition free-text (terlalu fragile).
  -- Bila true, trigger trg_patient_kidney_alert_notify (bawah) amaran coach
  -- pasal kadar peminuman air & larangan suntikan/kolar vena di lengan akses
  -- dialisis. Banner amaran jugak papar di patient-hub.html bila profil dibuka.
  has_kidney_condition             BOOLEAN NOT NULL DEFAULT false,
  height_cm                       NUMERIC,
  active_package_id               TEXT,
  active_package_name             TEXT,
  package_purchased_at            TIMESTAMPTZ,
  package_expires_at              TIMESTAMPTZ,
  next_package_id                 TEXT,
  next_package_name               TEXT,
  daily_schedule                  JSONB,
  booking_blocked                 BOOLEAN NOT NULL DEFAULT false,
  booking_blocked_reason          TEXT,
  booking_blocked_since           TIMESTAMPTZ,
  status                          TEXT DEFAULT 'active',
  kob_status                      TEXT NOT NULL DEFAULT 'paid',
  outcome_status                  TEXT,
  outcome_status_at               TIMESTAMPTZ,
  outcome_status_notes            TEXT,
  coach_id                        UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  assigned_at                     TIMESTAMPTZ,
  created_by_staff                BOOLEAN DEFAULT false,
  reference_code                  TEXT,
  ghl_kob_code                    TEXT,  -- kod GHL "SU KOB Auto ID" (cth "KOB'26-000139"), diasingkan drpd full_name — LIHAT _shared/ghl-sync.ts. BUKAN reference_code (tu "Kod Pesakit", diisi lepas signup pakej OB).
  documents                       JSONB DEFAULT '{}',
  referral_code                   TEXT,
  referred_by_code                TEXT,
  referred_by_patient_id          UUID REFERENCES psy_patients(id) ON DELETE SET NULL,
  created_at                      TIMESTAMPTZ DEFAULT now(),
  updated_at                      TIMESTAMPTZ DEFAULT now(),
  CONSTRAINT psy_patients_user_id_unique UNIQUE (user_id),
  CONSTRAINT psy_patients_status_check CHECK (status IN (
    'pending_kyc','active','inactive','rejected','deleted',
    'unregistered','archived','deceased','warded'
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

-- ──── RPC: pesakit cari & claim rekod psy_patients belum-linked (staff/GHL) ────
-- RLS di atas (user_id = auth.uid()) sengaja block pesakit baca/kemaskini
-- rekod pesakit LAIN — termasuk stub kosong (user_id NULL) yang staff/GHL
-- dah isi SEBELUM pesakit signup sendiri. Tanpa laluan ni, borang Pendaftaran
-- pesakit (roles/patient/pendaftaran.html) tak boleh jumpa/padan rekod staff
-- langsung (query terus kena tapis RLS, senyap-senyap pulang 0 baris), dan
-- proses claim (pindah user_id) di submitKYC() turut gagal atas sebab sama.
-- Dua RPC SECURITY DEFINER ni bagi laluan terkawal & sempit: cari SATU rekod
-- belum-linked ikut phone/IC/emel (baca sahaja, utk prapapar borang), dan
-- pindah user_id ke rekod tu + padam stub lama bila pesakit hantar borang.
CREATE OR REPLACE FUNCTION find_unclaimed_patient(
  p_phone_key  TEXT DEFAULT NULL,   -- 9 digit terakhir no. telefon
  p_ic         TEXT DEFAULT NULL,
  p_email      TEXT DEFAULT NULL,
  p_exclude_id UUID DEFAULT NULL
)
RETURNS SETOF psy_patients
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_row psy_patients;
BEGIN
  IF p_phone_key IS NOT NULL AND p_phone_key <> '' THEN
    SELECT * INTO v_row FROM psy_patients
    WHERE user_id IS NULL AND (p_exclude_id IS NULL OR id <> p_exclude_id)
      AND (phone ILIKE '%' || p_phone_key OR emergency_contact_phone ILIKE '%' || p_phone_key)
    LIMIT 1;
    IF FOUND THEN RETURN NEXT v_row; RETURN; END IF;
  END IF;

  IF p_ic IS NOT NULL AND p_ic <> '' THEN
    SELECT * INTO v_row FROM psy_patients
    WHERE user_id IS NULL AND (p_exclude_id IS NULL OR id <> p_exclude_id)
      AND ic_number = p_ic
    LIMIT 1;
    IF FOUND THEN RETURN NEXT v_row; RETURN; END IF;
  END IF;

  IF p_email IS NOT NULL AND p_email <> '' THEN
    SELECT * INTO v_row FROM psy_patients
    WHERE user_id IS NULL AND (p_exclude_id IS NULL OR id <> p_exclude_id)
      AND email ILIKE p_email
    LIMIT 1;
    IF FOUND THEN RETURN NEXT v_row; RETURN; END IF;
  END IF;

  RETURN;
END;
$$;

GRANT EXECUTE ON FUNCTION find_unclaimed_patient(TEXT, TEXT, TEXT, UUID) TO authenticated;

CREATE OR REPLACE FUNCTION claim_unclaimed_patient(
  p_target_id UUID,
  p_stub_id   UUID DEFAULT NULL   -- stub kosong pesakit sendiri (auto-cipta masa signup) utk dipadam
)
RETURNS SETOF psy_patients
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF p_stub_id IS NOT NULL AND p_stub_id <> p_target_id THEN
    DELETE FROM psy_patients WHERE id = p_stub_id AND user_id = auth.uid();
  END IF;

  RETURN QUERY
  UPDATE psy_patients
  SET user_id = auth.uid(), created_by_staff = false
  WHERE id = p_target_id AND user_id IS NULL
  RETURNING *;
END;
$$;

GRANT EXECUTE ON FUNCTION claim_unclaimed_patient(UUID, UUID) TO authenticated;

-- ──── RPC: semak IC pesakit lain (dah linked ATAU belum) ikut IC ────
-- Sama sebab RLS macam di atas — "IC ini sudah didaftarkan" block di
-- pendaftaran.html (submitKYC/checkIcDuplicate) query rekod pesakit LAIN yang
-- boleh jadi dah linked ke akaun sebenar (user_id bukan NULL), yang
-- find_unclaimed_patient() sengaja tak cover (tu khas utk stub belum-linked
-- sahaja). Pulangkan hanya medan paparan minimum (bukan seluruh baris).
CREATE OR REPLACE FUNCTION find_duplicate_patient_by_ic(p_ic TEXT, p_exclude_id UUID DEFAULT NULL)
RETURNS TABLE (id UUID, mrn TEXT, full_name TEXT, user_id UUID)
LANGUAGE sql SECURITY DEFINER SET search_path = public
AS $$
  SELECT id, mrn, full_name, user_id FROM psy_patients
  WHERE ic_number = p_ic AND (p_exclude_id IS NULL OR id <> p_exclude_id)
  LIMIT 1;
$$;

GRANT EXECUTE ON FUNCTION find_duplicate_patient_by_ic(TEXT, UUID) TO authenticated;

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

-- ──── trigger: sepadankan status <-> outcome_status ────
-- status (akses akaun: active/inactive/deceased/...) & outcome_status
-- (outcome klinikal utk laporan: otw/berhenti/meninggal/completed) overlap
-- bila rekod maut/selesai rawatan. Staff kadang tukar salah satu je (cth
-- dropdown "Status Outcome Rawatan" di patient-form.html) — medan lain
-- tercicir, jadi automasi (tapis ikut status) & laporan (tapis ikut
-- outcome_status) boleh tak sepadan utk pesakit yang sama. Trigger ni
-- paksa kedua-dua medan sentiasa konsisten tanpa kena ubah setiap tempat
-- yang baca/tulis column ni.
CREATE OR REPLACE FUNCTION sync_patient_status_outcome()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.outcome_status = 'meninggal' THEN
    NEW.status := 'deceased';
  ELSIF NEW.status = 'deceased' THEN
    NEW.outcome_status := 'meninggal';
  END IF;

  IF NEW.outcome_status IN ('completed', 'berhenti') AND NEW.status = 'active' THEN
    NEW.status := 'inactive';
  END IF;

  -- Account bertukar tak-aktif (session selesai/pakej luput/staff arkib) tapi
  -- outcome masih 'otw' (atau kosong) — 'otw' bermaksud "sedang berjalan",
  -- jadi dah tak tepat lagi bila akaun dah tak aktif. Naikkan ke 'completed'
  -- supaya UI tak papar kombinasi mengelirukan macam "Tidak Aktif" + "Sedang
  -- Berjalan". Staff masih boleh override ke 'berhenti' selepas ni kalau perlu.
  IF NEW.status IN ('inactive', 'archived')
     AND (NEW.outcome_status IS NULL OR NEW.outcome_status IN ('', 'otw')) THEN
    NEW.outcome_status := 'completed';
  END IF;

  IF NEW.outcome_status IS DISTINCT FROM OLD.outcome_status
     AND NEW.outcome_status IS NOT NULL
     AND NEW.outcome_status_at IS NULL THEN
    NEW.outcome_status_at := now();
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_patient_status_outcome ON psy_patients;
CREATE TRIGGER trg_sync_patient_status_outcome
  BEFORE UPDATE ON psy_patients
  FOR EACH ROW
  EXECUTE FUNCTION sync_patient_status_outcome();

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

  -- Sudah tak aktif (atau sedang warded — jangan timpa status klinikal semasa) → jangan ganggu
  IF v_pstatus IN ('inactive','archived','deceased','deleted','warded') THEN
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

COMMENT ON COLUMN psy_patients.booking_blocked IS
  'TRUE = pesakit disekat daripada menempah sesi baru. Sebab semasa: ansuran pakej tertunggak (lihat psy_kob_installments). Auto set/reset oleh installment-overdue-check.';
COMMENT ON COLUMN psy_patients.booking_blocked_reason IS
  'Kod sebab sekatan, cth "installment_overdue". NULL bila booking_blocked = false.';
COMMENT ON COLUMN psy_patients.booking_blocked_since IS
  'Bila sekatan bermula. Dipadam (NULL) bila booking_blocked ditukar semula ke false.';

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

COMMENT ON COLUMN psy_patients.contact_preference IS
  'Siapa patut terima notifikasi/kemas kini (WhatsApp) pesakit ini: pesakit atau waris. Direkod sahaja setakat ini — belum digunakan oleh Edge Functions penghantaran WhatsApp.';

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
  contact_preference              TEXT DEFAULT 'pesakit' CHECK (contact_preference IN ('pesakit','waris')),
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
      emergency_contact_relationship = COALESCE(NULLIF(emergency_contact_relationship, ''), NEW.emergency_contact_relationship),
      emergency_contact_email = COALESCE(NULLIF(emergency_contact_email, ''), NEW.emergency_contact_email),
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

-- ──── trigger: amaran coach bila pesakit buah pinggang/dialisis ────
-- Audit #20 (8 Okt 2026). Bila staf tandakan has_kidney_condition = true
-- (ATAU coach pesakit yg SUDAH ditanda true ditukar/diisi — supaya coach
-- BAHARU pun kena notify "setiap kali DAPAT pesakit"), hantar notify() kpd
-- coach_id tu. Ikut pola trg_patient_warded_auto_event (25_patient_events.sql)
-- — SECURITY DEFINER + EXCEPTION WHEN OTHERS supaya tak gagalkan transaksi
-- update psy_patients kalau notify silap. Banner visual (bukan notifikasi
-- sahaja) papar di patient-hub.html setiap kali profil pesakit ni dibuka.
CREATE OR REPLACE FUNCTION trg_patient_kidney_alert_notify()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_became_flagged BOOLEAN;
  v_coach_changed BOOLEAN;
BEGIN
  v_became_flagged := NEW.has_kidney_condition = true
    AND OLD.has_kidney_condition IS DISTINCT FROM true;
  v_coach_changed := NEW.has_kidney_condition = true
    AND NEW.coach_id IS NOT NULL
    AND NEW.coach_id IS DISTINCT FROM OLD.coach_id;

  IF NOT (v_became_flagged OR v_coach_changed) OR NEW.coach_id IS NULL THEN
    RETURN NEW;
  END IF;

  PERFORM notify_patient_kidney_alert(NEW.coach_id, NEW.id, NEW.full_name);

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE LOG 'trg_patient_kidney_alert_notify: %', SQLERRM;
  RETURN NEW;
END;
$$;

-- Helper berasingan (bukan terus insert dlm trigger) supaya boleh re-use kalau
-- perlu panggil dari tempat lain kemudian (cth backfill manual).
CREATE OR REPLACE FUNCTION notify_patient_kidney_alert(p_coach_id UUID, p_patient_id UUID, p_patient_name TEXT)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO psy_notifications (user_id, type, title, body, link)
  VALUES (
    p_coach_id,
    'kidney_alert',
    '⚠️ Pesakit Buah Pinggang/Dialisis',
    'Pesakit ' || COALESCE(p_patient_name, 'ini') ||
      ' ada masalah buah pinggang/dialisis — perhatikan kadar peminuman air pesakit ' ||
      '& ELAK penyuntikan/pengambilan darah di lengan yang ada akses dialisis (fistula/kolaps vena).',
    'patient-hub.html?id=' || p_patient_id::TEXT
  );
EXCEPTION WHEN OTHERS THEN
  RAISE LOG 'notify_patient_kidney_alert: %', SQLERRM;
END;
$$;

DROP TRIGGER IF EXISTS trg_patient_kidney_alert_notify ON psy_patients;
CREATE TRIGGER trg_patient_kidney_alert_notify
  AFTER UPDATE ON psy_patients
  FOR EACH ROW EXECUTE FUNCTION trg_patient_kidney_alert_notify();

-- ──── komen psy_kyc_submissions ────
COMMENT ON COLUMN psy_kyc_submissions.submitted_by_proxy IS
  'true = wakil/keluarga isi borang ini (info mesti tepat & boleh disahkan dengan pesakit sebenar)';

COMMENT ON COLUMN psy_kyc_submissions.contact_preference IS
  'Siapa patut terima notifikasi/kemas kini (WhatsApp) pesakit ini: pesakit atau waris.';

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
  extension_price_per_session NUMERIC(10,2) DEFAULT 25,
  meet_link TEXT,
  -- Ditambah 24 Sept 2026 (audit management #B1-7/8 Tier 4) — keperluan DNA Test
  -- datang dari config pakej (pola sama macam hk1_types Sesi 1:1), bukan hard-code
  -- atau bergantung staf ingat "Cipta Proses Baharu" manual. Auto-cipta di plan-week.html.
  dna_test_required BOOLEAN NOT NULL DEFAULT false,
  dna_test_count     INT DEFAULT 1,
  dna_test_week      INT DEFAULT 1,
  -- bayaran ansuran — Deposit (Bayaran Pertama) + Tempoh(bulan) + Bayaran
  -- Bulanan RATA. Pesakit boleh top-up jumlah bebas bila-bila (payment.html),
  -- tapi jadual checkpoint (psy_kob_installment_checkpoints) dijana dari
  -- struktur rata ni — bukan checkpoint sewenang-wenang lagi.
  installment_allowed BOOLEAN NOT NULL DEFAULT false,
  installment_full_price NUMERIC(10,2),
  installment_deposit_amount NUMERIC(10,2),
  installment_duration_months INT,
  installment_monthly_amount NUMERIC(10,2),
  -- harga 4-tier KOB: field di atas (price/installment_*) = tier "Now" (selepas
  -- KOB). Field bawah = tier "Today" (eksklusif semasa sesi KOB langsung) —
  -- kosong = fallback senyap ke tier Now di semua tempat (pakej belum diset tier Today).
  nilai_program NUMERIC(10,2),
  harga_asal NUMERIC(10,2),
  today_price NUMERIC(10,2),
  today_installment_full_price NUMERIC(10,2),
  today_installment_deposit_amount NUMERIC(10,2),
  today_installment_duration_months INT,
  today_installment_monthly_amount NUMERIC(10,2),
  -- status paparan, nota dalaman & flag automation/access (editor pakej-edit.html)
  status TEXT DEFAULT 'active',
  internal_notes TEXT,
  automation_flags JSONB DEFAULT '{}',
  access_flags JSONB DEFAULT '{}',
  supplies JSONB DEFAULT '[]',
  addons JSONB DEFAULT '[]',
  -- value stack pemasaran (kad "Apa Yang Anda Terima" + bonus + jadual ringkasan nilai)
  value_stack JSONB DEFAULT '[]',
  value_bonuses JSONB DEFAULT '[]',
  -- version pakej: gantikan corak manual "(new)" dalam nama pakej — nombor sahaja,
  -- version tertinggi bagi Nama Pakej yang sama = version semasa (implicit, tiada
  -- medan status berasingan).
  version_number INT NOT NULL DEFAULT 1,
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

COMMENT ON COLUMN psy_packages.version_number IS
  'Nombor version pakej (1, 2, 3, ...) — gantikan corak manual "(new)" dalam nama pakej. Version tertinggi bagi Nama Pakej yang sama = version semasa (implicit ikut nombor, tiada medan status berasingan).';

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

COMMENT ON COLUMN psy_packages.supplies IS
  'Array of {name, qty, ...} — senarai bekalan rawatan keseluruhan pakej (tab Lain-lain, bukan per-minggu)';

COMMENT ON COLUMN psy_packages.addons IS
  'Array of {name, ...} — senarai addon pakej (tab Lain-lain)';

COMMENT ON COLUMN psy_packages.value_stack IS
  'Array of {category, title_bm, title_en, description, bullets:[text], value:number} — komponen "value stack" pemasaran pakej (kad Apa Yang Anda Terima + jadual ringkasan nilai), dipaparkan di pakej-detail.html (staff & patient).';

COMMENT ON COLUMN psy_packages.value_bonuses IS
  'Sama struktur dgn value_stack — bonus percuma pakej (dipaparkan berasingan sebagai jalur "Bonus Eksklusif").';

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

COMMENT ON COLUMN psy_packages.extension_price_per_session IS
  'Harga (RM) untuk tambah SATU sesi tunggal (bukan minggu penuh) pada minggu sedia ada — cth butang "Tambah Sesi" di patient-hub.html. Default RM 25.';

COMMENT ON COLUMN psy_packages.installment_full_price IS
  'Harga "Penuh" rujukan utk pelan Ansuran tier Now — BUKAN sama dgn price (Harga Bayaran Penuh/Full Payment), biasanya LEBIH TINGGI (kos bayar ansuran). Jumlah Komitmen (deposit + baki bulanan) mesti sepadan dgn nilai ni, disahkan di editor pakej-edit.html.';
COMMENT ON COLUMN psy_packages.installment_deposit_amount IS
  'Jumlah deposit ("Bayaran Pertama") wajib dibayar semasa aktifkan pakej (ansuran). Bayaran ini terus mengaktifkan pakej.';
COMMENT ON COLUMN psy_packages.installment_duration_months IS
  'Jumlah bayaran ansuran keseluruhan TERMASUK Bayaran Pertama (cth 8 = 1 deposit + 7 bayaran bulanan).';
COMMENT ON COLUMN psy_packages.installment_monthly_amount IS
  'Amaun RATA setiap bulan (bulan ke-2 hingga installment_duration_months). Jumlah Komitmen = deposit + (duration-1) × amaun ni — mesti sepadan dgn installment_full_price (BUKAN dgn price, boleh lebih tinggi, kos bayar ansuran).';

COMMENT ON COLUMN psy_packages.meet_link IS
  'Pautan Gmeet recurring untuk pakej. Dipaparkan kepada patient bila minggu semasa adalah online/both.';

COMMENT ON COLUMN psy_packages.nilai_program IS
  'Jumlah Nilai Keseluruhan Program — angka marketing rujukan (display sahaja di kad harga), TIDAK dipakai dalam sebarang pengiraan bayaran.';
COMMENT ON COLUMN psy_packages.harga_asal IS
  'Harga Asal — asas kira % diskaun (display sahaja). % diskaun dikira LIVE = round((1 - tier_price/harga_asal)*100), bukan disimpan.';
COMMENT ON COLUMN psy_packages.today_price IS
  'Harga Bayaran Penuh — tier "Today" (eksklusif semasa pesakit masih dalam sesi KOB langsung, package_payment_status=pending). NULL = pakej ini tiada tier Today berasingan, fallback ke price (tier Now) di semua tempat.';
COMMENT ON COLUMN psy_packages.today_installment_full_price IS
  'Sama makna dgn installment_full_price tapi utk tier Today. NULL = fallback ke installment_full_price (tier Now).';
COMMENT ON COLUMN psy_packages.today_installment_deposit_amount IS
  'Deposit ("Bayaran Pertama") — tier Today ansuran. NULL = fallback ke installment_deposit_amount (tier Now).';
COMMENT ON COLUMN psy_packages.today_installment_duration_months IS
  'Sama makna dgn installment_duration_months tapi utk tier Today. NULL = fallback ke installment_duration_months (tier Now).';
COMMENT ON COLUMN psy_packages.today_installment_monthly_amount IS
  'Sama makna dgn installment_monthly_amount tapi utk tier Today. NULL = fallback ke installment_monthly_amount (tier Now).';

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

DROP POLICY IF EXISTS "Staff insert purchases" ON psy_package_purchases;
CREATE POLICY "Staff insert purchases" ON psy_package_purchases FOR INSERT
  WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

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
  -- 'voided' ditambah 24 Sept 2026 (audit management #B1-24) — transaksi yg tersalah
  -- rekod terus (bukan pesakit betul-betul minta wang balik). Beza drpd 'refunded'
  -- (bayaran sah, wang dipulangkan). Lihat psy_payment_adjustments utk sebab/approver.
  status TEXT DEFAULT 'completed' CHECK (status IN ('pending','completed','refunded','failed','voided')),
  -- Ditambah 24 Sept 2026 (audit management #B1-23) — bayaran ujian/demo, DIKECUALIKAN
  -- drpd semua laporan kewangan sebenar (KPI dashboard, laporan bulanan dll).
  is_test BOOLEAN NOT NULL DEFAULT false,
  -- Ditambah 24 Sept 2026 (audit management #B1-27) — status penghantaran resit/invois
  -- (WhatsApp) supaya staf tahu ia dihantar atau gagal, bukan senyap "fire and forget".
  receipt_last_sent_at     TIMESTAMPTZ,
  receipt_last_sent_status TEXT CHECK (receipt_last_sent_status IS NULL OR receipt_last_sent_status IN ('sent','failed')),
  ghl_transaction_id TEXT,
  invoice_number TEXT,                        -- bayaran manual — no. invois ditaip staff/doktor
  manual_method TEXT CHECK (manual_method IN ('transfer','cash','other')),  -- kaedah bayaran manual (payment_method='manual')
  invoice_no TEXT UNIQUE,                     -- no. invois (INV-…) utk bayaran BUKAN pakej KOB — auto bila 'pending'/'completed'; bayaran KOB guna psy_kob_sessions.invoice_no
  bank_reference TEXT,                        -- no. rujukan transaksi bank / transfer (bayaran manual)
  recorded_by UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,  -- staf yg merekod bayaran manual (paid_at = tarikh bayaran SEBENAR; created_at = masa direkod)
  paid_for_type TEXT CHECK (paid_for_type IN ('package','installment','invoice','consultation','product','other')),  -- bayaran ni utk apa (bayaran manual)
  paid_for_seq INT,                           -- checkpoint ansuran yg dilunaskan (paid_for_type='installment')
  paid_for_ref TEXT,                          -- rujukan sasaran (cth invoice_no yg dilunaskan, paid_for_type='invoice')
  is_partial BOOLEAN NOT NULL DEFAULT false,  -- bayaran separa (kurang drpd baki sasaran) — dibenderakan
  receipt_no TEXT UNIQUE,                     -- no. resit paparan (REC10001..) — auto bila status jadi 'completed'; receipt_ref kekal kunci teknikal
  discount NUMERIC(10,2) NOT NULL DEFAULT 0,  -- diskaun pada bayaran ini (papar di resit; subtotal = total + discount)
  receipt_url TEXT,                           -- bayaran manual — resit yang di-upload
  notes TEXT,
  -- Ditambah 14 Okt 2026 — jualan walk-in (pembeli bukan pesakit, cth datang terus
  -- ke HQ). patient_id KEKAL NULL untuk baris ni; nama/telefon disimpan di sini
  -- (bukan psy_patients) sbb pembeli tiada akaun pesakit. Lihat roles/staff/jualan-walkin.html.
  buyer_name TEXT,
  buyer_phone TEXT,
  -- gateway bayaran (HitPay/Fiuu) — pending row dicipta sebelum redirect,
  -- webhook padankan gateway_ref & jalankan fulfillment ikut intent
  gateway_provider TEXT,                      -- 'hitpay' | 'fiuu' | NULL (manual)
  gateway_ref      TEXT,                      -- id rujukan dari gateway
  gateway_status   TEXT,                      -- status mentah dari gateway
  gateway_channel  TEXT,                      -- channel SEBENAR (fpx/card/paynow_online/dll) — diisi selepas webhook, lihat 20261014_payment_gateway_channel.sql
  checkout_url     TEXT,                      -- pautan checkout gateway (utk staff share/salin semula bila status pending)
  intent           JSONB DEFAULT '{}'::jsonb, -- niat bayaran utk fulfillment
  fulfilled_at     TIMESTAMPTZ,               -- bila fulfillment benar-benar jalan
  paid_at TIMESTAMPTZ DEFAULT now(),
  created_at TIMESTAMPTZ DEFAULT now()
);

-- No. resit paparan berjujukan — diberi sekali bila bayaran 'completed' (bukan masa 'pending' gateway, elak nombor terbuang).
CREATE SEQUENCE IF NOT EXISTS psy_receipt_no_seq START 10001;

CREATE OR REPLACE FUNCTION psy_assign_receipt_no() RETURNS trigger AS $$
BEGIN
  IF NEW.status = 'completed' AND NEW.receipt_no IS NULL THEN
    NEW.receipt_no := 'REC' || nextval('psy_receipt_no_seq');
  END IF;
  RETURN NEW;
END $$ LANGUAGE plpgsql;

-- Invois utk bayaran bukan-KOB (kedai, sambungan minggu, dll): jujukan dikongsi dgn invois pakej KOB.
CREATE SEQUENCE IF NOT EXISTS psy_invoice_no_seq START 1;

-- Audit management #F-23 (Tier 3→5, pisah Invoice/Receipt/Payment) — pautan ke psy_invoices
-- SEBENAR (jadual di hujung fail ni). Baris yg menyelesaikan invois tu TAK perlu invoice_no
-- sendiri (invois asal DAH ada nombor) — elak dua nombor invois berlainan rujuk benda sama.
ALTER TABLE psy_payments ADD COLUMN IF NOT EXISTS invoice_id UUID;

CREATE OR REPLACE FUNCTION psy_assign_payment_invoice_no() RETURNS trigger AS $$
BEGIN
  IF NEW.invoice_no IS NULL AND NEW.status IN ('pending','completed')
     AND (NEW.intent ->> 'kob_session_id') IS NULL
     AND NEW.invoice_id IS NULL THEN
    NEW.invoice_no := 'INV-' || lpad(nextval('psy_invoice_no_seq')::text, 6, '0');
  END IF;
  RETURN NEW;
END $$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_psy_assign_payment_invoice_no ON psy_payments;
CREATE TRIGGER trg_psy_assign_payment_invoice_no BEFORE INSERT OR UPDATE OF status ON psy_payments
  FOR EACH ROW EXECUTE FUNCTION psy_assign_payment_invoice_no();

DROP TRIGGER IF EXISTS trg_psy_assign_receipt_no ON psy_payments;
CREATE TRIGGER trg_psy_assign_receipt_no BEFORE INSERT OR UPDATE OF status ON psy_payments
  FOR EACH ROW EXECUTE FUNCTION psy_assign_receipt_no();

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
-- psy_payment_adjustments — Void/Refund/Correction workflow (audit #B1-24, 24 Sept 2026)
-- Transaksi kewangan tersalah TAK boleh dipadam terus — kena melalui rekod ni dgn
-- sebab+amount+approver. type='void' (transaksi tak sepatutnya wujud, status→'voided'),
-- 'refund' (bayaran sah, wang dipulangkan, status→'refunded'), 'correction'
-- (dokumentasi pembetulan — TAK ubah amount psy_payments terus, sbb amount berkait
-- invois/jadual ansuran KOB; staf betulkan rekod berkaitan secara manual selepas
-- catat sebab di sini).
-- ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS psy_payment_adjustments (
  id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  payment_id         UUID NOT NULL REFERENCES psy_payments(id) ON DELETE CASCADE,
  type               TEXT NOT NULL CHECK (type IN ('void','refund','correction')),
  reason             TEXT NOT NULL,
  amount             NUMERIC(10,2),  -- refund/correction; NULL utk void (batal penuh)
  requested_by       UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  requested_by_name  TEXT,
  requested_at       TIMESTAMPTZ DEFAULT now(),
  approved_by        UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  approved_by_name   TEXT,
  approved_at        TIMESTAMPTZ,
  status             TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected')),
  notes              TEXT,
  created_at         TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_payment_adj_payment ON psy_payment_adjustments(payment_id);
CREATE INDEX IF NOT EXISTS idx_payment_adj_status  ON psy_payment_adjustments(status, requested_at);

ALTER TABLE psy_payment_adjustments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff manage payment adjustments" ON psy_payment_adjustments;
CREATE POLICY "Staff manage payment adjustments" ON psy_payment_adjustments FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

COMMENT ON COLUMN psy_payment_adjustments.status IS
  'pending = menunggu kelulusan super_admin; approved = diluluskan & kesan diterapkan (psy_payments.status dikemaskini); rejected = ditolak, psy_payments tak berubah.';

-- ──────────────────────────────────────────────────────────────
-- psy_payment_status_log — Status Timeline (audit #B1-25/26, 24 Sept 2026)
-- Tambahan SEMATA-MATA (trigger auto-isi) — psy_payments.status tetap satu kolum
-- macam sedia ada, jadual ni cuma simpan SETIAP perubahan supaya boleh papar
-- "carta perjalanan" Created→Gateway/Manual→Verified→Paid/Failed/Refunded/Voided
-- kat UI. Bayaran SEDIA ADA (sebelum trigger dipasang) tiada sejarah — timeline
-- bermula dari bila migration ni run.
-- ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS psy_payment_status_log (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  payment_id  UUID NOT NULL REFERENCES psy_payments(id) ON DELETE CASCADE,
  old_status  TEXT,          -- NULL utk baris pertama (payment baru dicipta)
  new_status  TEXT NOT NULL,
  changed_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_payment_status_log_payment ON psy_payment_status_log(payment_id, changed_at);

ALTER TABLE psy_payment_status_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff read payment status log" ON psy_payment_status_log;
CREATE POLICY "Staff read payment status log" ON psy_payment_status_log FOR SELECT
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
-- Tiada INSERT/UPDATE/DELETE policy utk client — cuma trigger (SECURITY DEFINER) yg tulis.

CREATE OR REPLACE FUNCTION trg_log_payment_status()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO psy_payment_status_log (payment_id, old_status, new_status) VALUES (NEW.id, NULL, NEW.status);
  ELSIF TG_OP = 'UPDATE' AND NEW.status IS DISTINCT FROM OLD.status THEN
    INSERT INTO psy_payment_status_log (payment_id, old_status, new_status) VALUES (NEW.id, OLD.status, NEW.status);
  END IF;
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE LOG 'trg_log_payment_status: %', SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_log_payment_status ON psy_payments;
CREATE TRIGGER trg_log_payment_status
  AFTER INSERT OR UPDATE OF status ON psy_payments
  FOR EACH ROW EXECUTE FUNCTION trg_log_payment_status();

-- ──────────────────────────────────────────────────────────────
-- psy_receipts — Receipt DIPISAH dari Payment (audit #F-23, Tier 5).
-- Dulu psy_payments buat kerja invois+bayaran+resit SEKALI GUS dalam SATU baris
-- (receipt_no/receipt_url cuma kolum di atas). Jadual ni jamin secara STRUKTUR
-- (bukan sekadar konvensyen UI) yang resit CUMA wujud SELEPAS bayaran disahkan —
-- baris cuma boleh dicipta oleh trigger di bawah (SECURITY DEFINER), TIADA laluan
-- client INSERT langsung. Zero perubahan pada mana-mana laluan tulis psy_payments
-- sedia ada (webhook gateway, KOB, entri manual staf semua kekal sama).
-- ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS psy_receipts (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  payment_id UUID NOT NULL UNIQUE REFERENCES psy_payments(id) ON DELETE CASCADE,
  patient_id UUID REFERENCES psy_patients(id),
  receipt_no TEXT,
  total      NUMERIC(10,2) NOT NULL,
  issued_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  pdf_url    TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_psy_receipts_patient ON psy_receipts(patient_id);

ALTER TABLE psy_receipts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Patients read own receipts" ON psy_receipts;
CREATE POLICY "Patients read own receipts" ON psy_receipts FOR SELECT
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Staff read all receipts" ON psy_receipts;
CREATE POLICY "Staff read all receipts" ON psy_receipts FOR SELECT
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
-- Tiada INSERT/UPDATE/DELETE policy client — cuma trigger (SECURITY DEFINER) yg tulis.

CREATE OR REPLACE FUNCTION trg_create_receipt_on_payment_completed()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NEW.status = 'completed' AND (TG_OP = 'INSERT' OR OLD.status IS DISTINCT FROM 'completed') THEN
    INSERT INTO psy_receipts (payment_id, patient_id, receipt_no, total, pdf_url)
    VALUES (NEW.id, NEW.patient_id, NEW.receipt_no, NEW.total, NEW.receipt_url)
    ON CONFLICT (payment_id) DO NOTHING;
  END IF;
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE LOG 'trg_create_receipt_on_payment_completed: %', SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_create_receipt_on_payment_completed ON psy_payments;
CREATE TRIGGER trg_create_receipt_on_payment_completed
  AFTER INSERT OR UPDATE OF status ON psy_payments
  FOR EACH ROW EXECUTE FUNCTION trg_create_receipt_on_payment_completed();

-- Backfill sejarah — semua bayaran 'completed' sedia ada dapat rekod resit serta-merta.
INSERT INTO psy_receipts (payment_id, patient_id, receipt_no, total, pdf_url, issued_at)
SELECT id, patient_id, receipt_no, total, receipt_url, COALESCE(paid_at, created_at)
FROM psy_payments WHERE status = 'completed'
ON CONFLICT (payment_id) DO NOTHING;

-- ──────────────────────────────────────────────────────────────
-- psy_invoices — Invoice DIPISAH dari Payment (audit #F-23, Tier 5). Amaun
-- TERTUNGGAK yang boleh wujud SEBELUM sebarang percubaan bayaran — cth denda
-- tidak hadir (plan-week.html) yang dulu "menyamar" sebagai baris psy_payments
-- status='pending' (komen kod asal sendiri panggil ni "invois tertunggak").
-- Invois KOB (pakej/ansuran) SENGAJA TAK dipindah ke sini — kekal di
-- psy_kob_sessions.invoice_no + psy_kob_installment_checkpoints, yang sudah
-- berfungsi baik & disentuh banyak fail (kob.html/kob-detail.html/patient-hub.html
-- dll) — risiko tinggi sentuh tanpa faedah.
-- ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS psy_invoices (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  invoice_no  TEXT UNIQUE,
  patient_id  UUID NOT NULL REFERENCES psy_patients(id),
  description TEXT NOT NULL,
  amount      NUMERIC(10,2) NOT NULL CHECK (amount > 0),
  status      TEXT NOT NULL DEFAULT 'unpaid' CHECK (status IN ('unpaid','partially_paid','paid','void')),
  source_type TEXT,   -- cth 'absence_fee'
  source_ref  TEXT,   -- rujukan longgar (cth psy_plan_weekly_progress.id)
  created_by  UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  created_at  TIMESTAMPTZ DEFAULT now(),
  updated_at  TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_psy_invoices_patient ON psy_invoices(patient_id, status);

ALTER TABLE psy_invoices ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Patients read own invoices" ON psy_invoices;
CREATE POLICY "Patients read own invoices" ON psy_invoices FOR SELECT
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Staff manage invoices" ON psy_invoices;
CREATE POLICY "Staff manage invoices" ON psy_invoices FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- invoice_no auto — jujukan SAMA dgn psy_payments.invoice_no (satu rantaian nombor invois).
CREATE OR REPLACE FUNCTION psy_assign_invoice_no() RETURNS trigger AS $$
BEGIN
  IF NEW.invoice_no IS NULL THEN
    NEW.invoice_no := 'INV-' || lpad(nextval('psy_invoice_no_seq')::text, 6, '0');
  END IF;
  RETURN NEW;
END $$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_psy_assign_invoice_no ON psy_invoices;
CREATE TRIGGER trg_psy_assign_invoice_no BEFORE INSERT ON psy_invoices
  FOR EACH ROW EXECUTE FUNCTION psy_assign_invoice_no();

-- Pautan FK psy_payments.invoice_id → psy_invoices (kolum dah dicipta di atas,
-- constraint di sini sbb psy_invoices baru wujud sekarang).
ALTER TABLE psy_payments DROP CONSTRAINT IF EXISTS psy_payments_invoice_id_fkey;
ALTER TABLE psy_payments ADD CONSTRAINT psy_payments_invoice_id_fkey
  FOREIGN KEY (invoice_id) REFERENCES psy_invoices(id);
CREATE INDEX IF NOT EXISTS idx_psy_payments_invoice ON psy_payments(invoice_id);

-- Bila bayaran yg menyelesaikan invois berubah status (completed BARU, atau
-- lepas tu direfund/void), kira SEMULA baki dari SUM sebenar & kemaskini status
-- invois — jangan hanya "masuk paid" sekali dan lupa, supaya refund/void betul2
-- buka semula invois tu (bukan tinggal 'paid' walau duit dah dipulangkan).
CREATE OR REPLACE FUNCTION trg_update_invoice_status_on_payment()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_amount NUMERIC;
  v_paid   NUMERIC;
BEGIN
  IF NEW.invoice_id IS NULL THEN RETURN NEW; END IF;
  SELECT amount INTO v_amount FROM psy_invoices WHERE id = NEW.invoice_id;
  IF v_amount IS NULL THEN RETURN NEW; END IF;
  SELECT COALESCE(SUM(total), 0) INTO v_paid FROM psy_payments
    WHERE invoice_id = NEW.invoice_id AND status = 'completed';
  UPDATE psy_invoices SET
    status = CASE
      WHEN v_paid <= 0 THEN 'unpaid'
      WHEN v_paid + 0.005 >= v_amount THEN 'paid'
      ELSE 'partially_paid'
    END,
    updated_at = now()
  WHERE id = NEW.invoice_id AND status <> 'void';
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE LOG 'trg_update_invoice_status_on_payment: %', SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_update_invoice_status_on_payment ON psy_payments;
CREATE TRIGGER trg_update_invoice_status_on_payment
  AFTER INSERT OR UPDATE OF status ON psy_payments
  FOR EACH ROW EXECUTE FUNCTION trg_update_invoice_status_on_payment();

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

-- ──────────────────────────────────────────────────────────────
-- psy_ghl_transactions — ledger RAW transaksi GHL (Laluan A, guna
-- GHL_ISW_TOKEN sahaja, TIADA akses Stripe secret diperlukan).
-- TUJUAN: reconciliation kewangan/accounting — BUKAN untuk paparan
-- sejarah bayaran pesakit (itu kekal psy_payments, diisi ghl-pull-sync
-- untuk yuran KOB sahaja). Jadual BERASINGAN sengaja — grain berbeza
-- (SEMUA transaksi lokasi, bukan sekadar yang lulus gate KOB) & elak
-- double-count rekod yang SAMA muncul di psy_payments (dari sudut
-- pandang GHL Transaction) DAN di sini (dari sudut pandang ledger
-- mentah) kalau digabung jadi satu jadual.
-- Diisi oleh supabase/functions/ghl-transactions-sync/index.ts.
-- ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS psy_ghl_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ghl_transaction_id TEXT UNIQUE NOT NULL,   -- GHL `_id`
  contact_id TEXT,
  contact_name TEXT,
  contact_email TEXT,
  patient_id UUID REFERENCES psy_patients(id),   -- padan ikut email bila boleh, NULL kalau tak jumpa
  amount NUMERIC(10,2) NOT NULL DEFAULT 0,   -- RM (unit manusia, BUKAN sen — GHL amount top-level dah RM)
  amount_refunded NUMERIC(10,2) DEFAULT 0,
  currency TEXT DEFAULT 'MYR',
  status TEXT,                               -- succeeded/failed/pending/dll (mentah GHL)
  payment_provider_type TEXT,                -- 'stripe' | 'manual' | lain
  entity_type TEXT,                          -- 'order' | 'invoice'
  entity_source_type TEXT,                   -- 'payment_link' | 'text2Pay' | dll
  entity_source_name TEXT,                   -- nama produk/invois
  entity_id TEXT,
  charge_id TEXT,                            -- Stripe payment_intent id (stripe sahaja, NULL kalau manual)
  payment_method_type TEXT,                  -- 'fpx' | 'card' | 'bank_transfer' | dll (derived, lihat sync fn)
  receipt_url TEXT,                          -- resit rasmi Stripe (stripe sahaja)
  invoice_number TEXT,                       -- cth "INV-000952" (entityType='invoice' sahaja, dari entitySourceMeta)
  issue_date TIMESTAMPTZ,                    -- tarikh invois DIISUKAN (BEZA dari ghl_created_at = bila transaksi/bayaran direkod; perlu panggilan /invoices/ berasingan, lihat sync fn)
  live_mode BOOLEAN,
  ghl_created_at TIMESTAMPTZ,                -- createdAt GHL (masa transaksi sebenar)
  ghl_updated_at TIMESTAMPTZ,
  fulfilled_at TIMESTAMPTZ,
  raw JSONB DEFAULT '{}'::jsonb,              -- objek PENUH GHL — safety net field yang terlepas
  synced_at TIMESTAMPTZ DEFAULT now(),
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ghl_tx_patient ON psy_ghl_transactions(patient_id);
CREATE INDEX IF NOT EXISTS idx_ghl_tx_contact ON psy_ghl_transactions(contact_id);
CREATE INDEX IF NOT EXISTS idx_ghl_tx_created ON psy_ghl_transactions(ghl_created_at);

ALTER TABLE psy_ghl_transactions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff manage ghl transactions" ON psy_ghl_transactions;
CREATE POLICY "Staff manage ghl transactions" ON psy_ghl_transactions FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- ──────────────────────────────────────────────────────────────
-- vw_payment_ledger — VIEW gabungan untuk accountant trace SEMUA
-- bayaran dalam SATU senarai (roles/staff/payment-ledger.html).
-- UNION psy_payments (sumber='ISW') + psy_ghl_transactions
-- (sumber='GHL') — DEDUP eksplisit: baris GHL yang `ghl_transaction_id`
-- dia DAH wujud dalam psy_payments (kes yuran KOB yang lulus gate
-- ghl-pull-sync) DIKECUALIKAN dari sisi GHL supaya bayaran yang SAMA
-- tak muncul dua kali. security_invoker=true — VIEW jalan ikut
-- kebenaran PEMANGGIL (RLS "Staff manage..." pada 2 jadual asal
-- terpakai terus), bukan pemilik view.
-- ──────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW vw_payment_ledger WITH (security_invoker = true) AS
SELECT
  p.id::text                       AS id,
  'ISW'                             AS source,
  COALESCE(p.paid_at, p.created_at) AS tx_date,
  p.patient_id,
  COALESCE(pt.full_name, p.buyer_name, CASE WHEN p.patient_id IS NULL THEN 'Walk-in' ELSE 'Pesakit' END) AS contact_name,
  p.total                          AS amount,
  p.payment_method                 AS method,
  COALESCE(p.gateway_provider, p.payment_method) AS provider,
  p.status,
  p.receipt_ref                    AS reference,
  p.ghl_transaction_id,
  p.invoice_number,
  NULL::TIMESTAMPTZ                AS issue_date,
  p.notes
FROM psy_payments p
LEFT JOIN psy_patients pt ON pt.id = p.patient_id

UNION ALL

SELECT
  g.id::text                       AS id,
  'GHL'                             AS source,
  g.ghl_created_at                 AS tx_date,
  g.patient_id,
  g.contact_name,
  g.amount,
  g.payment_provider_type          AS method,
  g.payment_provider_type          AS provider,
  g.status,
  COALESCE(g.invoice_number, g.ghl_transaction_id) AS reference,
  g.ghl_transaction_id,
  g.invoice_number,
  g.issue_date,
  g.entity_source_name             AS notes
FROM psy_ghl_transactions g
WHERE g.ghl_transaction_id IS NULL
   OR g.ghl_transaction_id NOT IN (SELECT ghl_transaction_id FROM psy_payments WHERE ghl_transaction_id IS NOT NULL);

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
  schedule_auto_alt_day INT,                    -- NULL = hari tetap biasa. Diisi (dow JS 0-6) bila
                                                  -- setup guna mod auto fallback (cth preferred_days=[5]
                                                  -- Jumaat, tapi cuba Sabtu(6) kalau Jumaat tutup, cascade
                                                  -- +1 minggu kalau dua-dua tutup — lihat
                                                  -- ssGenerateSingleDayCascade di patient-hub.html /
                                                  -- computeChainedDateSafe di plan-week.html).
  sessions_per_week   INT   DEFAULT NULL,       -- disalin dari pakej masa setup
  schedule_setup_at   TIMESTAMPTZ,
  start_date          DATE,                     -- anchor sebenar Minggu 1
  created_at          TIMESTAMPTZ DEFAULT now()
);

-- Jaringan keselamatan: satu pesakit tak boleh ada 2 plan AKTIF utk pakej (template) yang
-- sama serentak — cth webhook bayaran retry serentak (race condition) cuba insert berganda.
CREATE UNIQUE INDEX IF NOT EXISTS uq_treatment_plans_active_patient_template
  ON psy_treatment_plans(patient_id, template) WHERE status = 'active';

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

COMMENT ON COLUMN psy_treatment_plans.schedule_auto_alt_day IS
  'NULL = hari tetap biasa (preferred_days ikut betul-betul). Diisi (getDay() JS) bila plan disetup
   guna mod "auto fallback" 1 sesi/minggu (staff punya "Setup Jadual Rawatan", pakej tiada Pilihan
   Hari Sesi disetkan) — preferred_days[0] = hari UTAMA (cth Jumaat), lajur ni = hari ALTERNATIF
   (cth Sabtu) yang dicuba kalau hari utama tutup. Dibaca oleh computeChainedDateSafe() di
   plan-week.html supaya cascadeBookFutureWeeks() elak book atas hari yang tutup untuk plan jenis ni.';

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
-- psy_production_recordings — jejak notifikasi Team Production (luar sistem,
-- hantar WhatsApp sahaja) bila pesakit capai milestone rakaman progress
-- report. Milestone: w3/w5/w7/w9/w12 (sesi mingguan dalam pakej asal 12 minggu,
-- dikesan bila sesi tu sebenar berlaku — status hadir/consultation_done) dan
-- m1/m2/m3/q1/q2/q3 (fasa sambungan selepas minggu 12, dikira dari
-- package_expires_at + 30/60/90/180/270/365 hari, selagi pesakit kekal active).
-- Diisi oleh cron event-reminders (runProductionMilestoneCheck) — audit 21 Okt 2026.
-- ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS psy_production_recordings (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id      UUID NOT NULL REFERENCES psy_patients(id) ON DELETE CASCADE,
  milestone       TEXT NOT NULL
                   CONSTRAINT psy_production_recordings_milestone_check
                   CHECK (milestone IN ('w3','w5','w7','w9','w12','m1','m2','m3','q1','q2','q3')),
  milestone_label TEXT,
  -- Tarikh sasaran rakaman (21 Okt 2026, lanjutan) — utk W3-W12 = tarikh sesi
  -- berjadual minggu tu (psy_plan_weekly_progress.session_date); utk M1-Q3 =
  -- psy_patients.package_expires_at + bilangan hari threshold. Cron hantar WA
  -- SEHARI SEBELUM due_date (bukan terus bila dikesan) — lihat
  -- runProductionMilestoneCheck() di supabase/functions/event-reminders/index.ts.
  due_date        DATE,
  -- Permudahkan (21 Okt 2026, lanjutan) — Team Production tiada akaun ISW &
  -- tiada staf ditugaskan follow-up/kemaskini balik, jadi jadual ni sekadar LOG
  -- PENGHANTARAN notis (pending/notified), BUKAN papan kerja status rakaman.
  -- Kolum recorded_at/recorded_by & status 'recorded'/'skipped' DIBUANG sengaja.
  status          TEXT NOT NULL DEFAULT 'pending'
                   CONSTRAINT psy_production_recordings_status_check
                   CHECK (status IN ('pending','notified')),
  wa_sent_at      TIMESTAMPTZ,
  wa_send_status  TEXT,
  created_at      TIMESTAMPTZ DEFAULT now(),
  CONSTRAINT psy_production_recordings_patient_milestone_key UNIQUE (patient_id, milestone)
);

CREATE INDEX IF NOT EXISTS idx_psy_production_recordings_status
  ON psy_production_recordings(status);

CREATE INDEX IF NOT EXISTS idx_psy_production_recordings_patient
  ON psy_production_recordings(patient_id);

ALTER TABLE psy_production_recordings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff manage production recordings" ON psy_production_recordings;
CREATE POLICY "Staff manage production recordings" ON psy_production_recordings FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

COMMENT ON TABLE psy_production_recordings IS
  'Queue notifikasi WhatsApp kpd Team Production (luar sistem, tiada akaun ISW) bila pesakit capai milestone rakaman progress report. Diisi auto oleh cron, diurus staf di production-queue.html.';

COMMENT ON COLUMN psy_production_recordings.milestone_label IS
  'Label paparan diisi masa insert, cth "Minggu 3" / "Bulan 1" / "Suku 1" — senang papar tanpa perlu map semula di UI.';

COMMENT ON COLUMN psy_production_recordings.status IS
  'pending = dikesan, belum/gagal hantar WA; notified = WA dah hantar; recorded = staf sahkan rakaman dah dibuat; skipped = staf pilih langkau.';

COMMENT ON COLUMN psy_production_recordings.wa_send_status IS
  'Status penghantaran WA terakhir (sent/failed) — rujukan debug, bukan status rekod (lihat column status).';

-- ──────────────────────────────────────────────────────────────
-- Trigger: pesakit stop/tamat rawatan → buang sesi akan datang yang
-- belum berlaku (pending/booked/reschedule) supaya jadual tak tinggal
-- bersepah & tak trigger reminder/escalation palsu. Rekod SEJARAH
-- (hadir/cancel/consultation_done) KEKAL — ni cuma buang slot yang
-- tak pernah berlaku. Pasangan kepada trg_auto_detach_card_on_patient_stop
-- (09_kob.sql, stop auto-caj) & trg_block_booking_for_inactive_patient
-- (bawah) — tiga-tiga sekali tangani kesan "pesakit berhenti".
-- ──────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION auto_clear_sessions_on_patient_stop()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_count INT;
  v_appt_ids UUID[];
BEGIN
  IF NEW.outcome_status IN ('berhenti', 'meninggal')
     AND OLD.outcome_status IS DISTINCT FROM NEW.outcome_status THEN
    WITH deleted AS (
      DELETE FROM psy_plan_weekly_progress
        WHERE patient_id = NEW.id AND status IN ('pending', 'booked', 'reschedule')
        RETURNING id, appointment_id
    )
    SELECT count(*), array_agg(appointment_id) FILTER (WHERE appointment_id IS NOT NULL)
      INTO v_count, v_appt_ids FROM deleted;

    -- Sesi terjadual yg dipadam mungkin pautan ke psy_appointments (kalendar umum) — batalkan
    -- sekali supaya tak tinggal baris 'scheduled' bersepah merujuk sesi yg dah tak wujud.
    IF v_appt_ids IS NOT NULL THEN
      UPDATE psy_appointments SET status = 'cancelled'
        WHERE id = ANY(v_appt_ids) AND status NOT IN ('completed', 'cancelled');
    END IF;

    IF v_count > 0 THEN
      INSERT INTO psy_audit_log (actor_name, action, target, meta)
      VALUES ('Sistem (Auto)', 'plan.sessions_cleared_on_stop', NEW.id::text,
        jsonb_build_object('reason', 'patient_treatment_stopped', 'outcome_status', NEW.outcome_status, 'sessions_removed', v_count));
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_auto_clear_sessions_on_patient_stop ON psy_patients;
CREATE TRIGGER trg_auto_clear_sessions_on_patient_stop
  AFTER UPDATE OF outcome_status ON psy_patients
  FOR EACH ROW
  EXECUTE FUNCTION auto_clear_sessions_on_patient_stop();

-- ──────────────────────────────────────────────────────────────
-- Trigger: sekat sesi BAHARU (pending/booked/reschedule) dijadualkan
-- untuk pesakit yang statusnya bukan 'active' (cth dah 'inactive' selepas
-- outcome_status='berhenti'/'meninggal', atau 'archived'/'deceased').
-- Rekod sejarah (hadir/cancel/consultation_done) & kemaskini baris sedia
-- ada tak disekat — cuma INSERT slot BAHARU yang disekat.
-- ──────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION block_booking_for_inactive_patient()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  v_status TEXT;
BEGIN
  IF NEW.status IN ('pending', 'booked', 'reschedule') THEN
    SELECT status INTO v_status FROM psy_patients WHERE id = NEW.patient_id;
    IF v_status IS DISTINCT FROM 'active' THEN
      RAISE EXCEPTION 'Pesakit ini tidak aktif (status: %) — sesi baharu tidak boleh dijadualkan.', v_status;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_block_booking_for_inactive_patient ON psy_plan_weekly_progress;
CREATE TRIGGER trg_block_booking_for_inactive_patient
  BEFORE INSERT ON psy_plan_weekly_progress
  FOR EACH ROW
  EXECUTE FUNCTION block_booking_for_inactive_patient();

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

  -- 'warded' ditambah 7 Okt 2026 (audit #124) — pesakit masuk wad TIDAK boleh
  -- ditimpa balik ke 'inactive' oleh automasi ni semata kerana sesi lama ditanda
  -- selesai; status klinikal 'warded' dikawal oleh modul Rekod Klinikal Pesakit.
  IF v_pstatus IN ('inactive','archived','deceased','deleted','warded') THEN
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
      -- NOT EXISTS di bawah cuma "best-effort" — boleh race bila >1 baris psy_plan_weekly_progress
      -- ditanda hadir hampir serentak (setiap satu cetus trigger ni secara berasingan).
      -- uq_treatment_plans_active_patient_template (unique index) ialah jaringan keselamatan
      -- SEBENAR; tangkap unique_violation di sini supaya UPDATE hadir yang mencetuskan trigger
      -- ni tak gagal walaupun panggilan/trigger lain menang race dulu (punca duplicate plan
      -- prod 7 Ogos — 3 baris "Overhaul Body Diamond Y1" dicipta dlm 44 saat utk 1 pesakit).
      BEGIN
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
      EXCEPTION WHEN unique_violation THEN
        NULL; -- plan aktif utk pakej sambungan ni dah dicipta oleh panggilan serentak — abaikan.
      END;
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
-- Audit management (Pelan Mingguan — Status Sesi): elak satu sesi bercanggah
-- (cth "Tidak Hadir"/dijadual-semula TAPI masih bertanda "Disahkan" pesakit).
-- Pengesahan (patient_confirmed) ditulis oleh fungsi berasingan drpd status
-- (markConfirmed di kehadiran.html vs markStatus/appointments.html/dashboard.html
-- yg semuanya tulis terus ke jadual ni) — jadi guard diletak di trigger, bukan
-- disemak berulang kali di setiap laluan JS.
CREATE OR REPLACE FUNCTION fn_clear_confirm_on_status_change()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status IN ('cancel','reschedule') AND NEW.status IS DISTINCT FROM OLD.status THEN
    NEW.patient_confirmed := NULL;
    NEW.patient_confirmed_at := NULL;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_clear_confirm_on_status_change ON psy_plan_weekly_progress;

CREATE TRIGGER trg_clear_confirm_on_status_change
  BEFORE UPDATE ON psy_plan_weekly_progress
  FOR EACH ROW
  EXECUTE FUNCTION fn_clear_confirm_on_status_change();

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
  -- kiv = sesi selesai TAPI pesakit tak teruskan pakej (parking, bukan cancel).
  -- no_show = staff sahkan pesakit tak hadir (BEZA drpd "Terlepas" — tu label
  -- terbitan sementara ikut masa lepas, no_show status TETAP yg staff set sendiri).
  status              TEXT NOT NULL DEFAULT 'booked'
                      CHECK (status IN ('booked','hadir','completed','reschedule','cancelled','kiv','no_show')),
  -- Asal tempahan: 'system' = dicipta dalam ISW system (staff/pesakit sendiri),
  -- 'ghl' = disync automatik dari GHL Calendar (lihat _shared/ghl-sync.ts).
  source              TEXT NOT NULL DEFAULT 'system' CHECK (source IN ('system','ghl')),

  -- LEGACY — peranan "Doktor" dibuang (gantikan Collector/Closer di bawah). Lajur ni
  -- kekal utk baca rekod lama sahaja, TAK DIISI LAGI utk rekod baharu.
  doctor_hadir_id     UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  doctor_hadir_name   TEXT,
  hadir_at            TIMESTAMPTZ,
  doctor_selesai_id   UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  doctor_selesai_name TEXT,
  selesai_at          TIMESTAMPTZ,

  -- Collector — staff "owner" pesakit sepanjang proses KOB. Ditugaskan/ditukar bila-bila
  -- (macam coach_id pesakit), TIDAK auto-terikat dgn butang Hadir/Selesai. Assign/tukar di
  -- kob-detail.html (openChangeKobRole). Staff yg layak dipilih = staff_role 'kob'.
  collector_id        UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  collector_name      TEXT,
  -- Closer — staff yang handle sesi presentation KOB. Berasingan drpd Collector, ditugaskan/
  -- ditukar bila-bila sama cara. Staff yg layak dipilih = staff_role 'kob'.
  closer_id           UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  closer_name         TEXT,

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
                            CHECK (package_payment_status IN ('pending','partial','paid','skipped','declined','na')),
  package_paid_at           TIMESTAMPTZ,
  package_receipt_ref       TEXT,
  package_discount          NUMERIC(12,2) NOT NULL DEFAULT 0,  -- diskaun (papar di invois; harga asal = recommended_package_price + package_discount)
  invoice_no                TEXT UNIQUE,                       -- no. invois (INV-000001..) — auto bila pakej dicadangkan
  package_payment_mode      TEXT CHECK (package_payment_mode IN ('full','installment')),
  intended_payment_mode     TEXT CHECK (intended_payment_mode IN ('full','installment','manual_installment')),

  -- Kunci Harga — staff klik "Kunci Harga" di Langkah 3 (kob-detail.html) utk tetapkan
  -- harga Now/Today bayaran ini TAK boleh berubah lagi (walaupun harga pakej diedit
  -- kemudian di pakej-edit.html). locked_price_amount snapshot harga sebenar masa
  -- dikunci (bukan dikira semula dari pkgMeta tiap kali). NULL = belum dikunci.
  locked_price_tier         TEXT CHECK (locked_price_tier IN ('now','today')),
  locked_price_amount       NUMERIC(12,2),
  locked_at                 TIMESTAMPTZ,
  locked_by                 UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  locked_by_name            TEXT,

  -- "OB Lock Harga" (reservation) — pesakit bayar OB Lock Harga hari ni utk "freeze"
  -- harga semasa SEBELUM pakej rasmi mula (beza drpd Ansuran Manual di Langkah 4,
  -- yang untuk pesakit yg DAH mula pakej). Tiada tarikh/jadual bayaran seterusnya
  -- di sini — cuma satu OB Lock Harga + tempoh lock. TAKDE REFUND kalau tempoh luput
  -- tanpa bayaran penuh (lock_status 'forfeited').
  lock_deposit_amount          NUMERIC(12,2),
  -- Rujuk terus psy_payments.id rekod OB Lock Harga ni — elak ambiguiti bila lock
  -- diluputkan+dikunci semula (byk baris 'kob_price_lock_deposit' sepanjang masa),
  -- supaya saveManualPayment() tahu TEPAT baris mana nak reclassify ke 'kob_package'
  -- bila pesakit akhirnya mula pakej.
  lock_deposit_payment_id      UUID REFERENCES psy_payments(id) ON DELETE SET NULL,
  lock_deposit_paid_at         TIMESTAMPTZ,
  -- 'gateway' = dibayar via pautan HitPay (payments-kob-initiate mode='price_lock'),
  -- rekod oleh webhook (fulfillKobPriceLock), bukan staff terus.
  lock_deposit_method          TEXT CHECK (lock_deposit_method IN ('cash','transfer','gateway')),
  lock_deposit_reference       TEXT,
  lock_deposit_recorded_by     UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  lock_deposit_recorded_by_name TEXT,
  lock_expiry_date             DATE,
  -- active = dalam tempoh; tempoh_tamat = tarikh dah sampai, menunggu staff lanjutkan/
  -- luputkan; forfeited = staff dah luputkan (OB Lock Harga burn, harga dibuka balik);
  -- completed = pesakit dah bayar penuh/mula ansuran dalam tempoh (OB Lock Harga
  -- dikreditkan ke harga pakej).
  lock_status                   TEXT CHECK (lock_status IN ('active','tempoh_tamat','forfeited','completed')),
  lock_extended_count           INT NOT NULL DEFAULT 0,
  lock_forfeited_at             TIMESTAMPTZ,
  lock_forfeited_by             UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  lock_forfeited_by_name        TEXT,

  reschedule_count    INT NOT NULL DEFAULT 0,
  reschedule_reason   TEXT,

  created_at          TIMESTAMPTZ DEFAULT now(),
  updated_at          TIMESTAMPTZ DEFAULT now()
);

COMMENT ON COLUMN psy_kob_sessions.questionnaire IS
  'Structured Q&A captured during KOB. Keys: anak[], tidur{}, gaya_hidup{}, masalah_kesihatan{} — see kob-detail.html for shape.';

COMMENT ON COLUMN psy_kob_sessions.recommended_package_id IS
  'Package recommended by doctor during KOB. Patient must pay before agreement signing.';

COMMENT ON COLUMN psy_kob_sessions.locked_price_tier IS
  'Staff-locked price tier (now/today) for this KOB payment, set via "Kunci Harga" button in
   kob-detail.html Langkah 3. When set, overrides wizPayTier in UI + payments-kob-initiate tier
   param, and keeps working even if the package price changes afterwards (snapshot in
   locked_price_amount). NULL = not locked, staff can still freely switch tiers.';

COMMENT ON COLUMN psy_kob_sessions.lock_deposit_amount IS
  '"OB Lock Harga" — reservation amount paid to lock the price (separate from the Langkah 4
   payment plan — no schedule/dates attached, just one upfront amount). Credited toward the
   package price ONLY while lock_status is still active/tempoh_tamat (not forfeited) when the
   real payment is finally recorded. NEVER refunded if the lock lapses (lock_status = forfeited).';

COMMENT ON COLUMN psy_kob_sessions.lock_status IS
  'active = within lock_expiry_date. tempoh_tamat = date reached, awaiting staff action
   (wizExtendLock to push the date out, or wizForfeitLock to burn the OB Lock Harga + release
   the locked price). forfeited = terminal, OB Lock Harga kept (no refund), locked_price_*
   cleared. completed = terminal, real package payment recorded while lock was still valid
   (OB Lock Harga credited toward the price — see getKobLockDepositCredit() in kob-detail.html).';

COMMENT ON COLUMN psy_kob_sessions.intended_payment_mode IS
  'Plan staff PILIH utk pesakit di wizard kob-detail.html (wizSelectPlan, Langkah 4) — SEBELUM
   sebarang bayaran cuba dibuat. Beza dengan package_payment_mode (hanya diisi SELEPAS bayaran
   berjaya). Dibaca oleh kob.html (roles/patient) utk papar butang self-checkout yang sepadan:
   installment = "Bayar Deposit Ansuran" (payments-kob-initiate, deposit amount), full/NULL =
   "Bayar Sekarang" (payments-initiate, harga penuh), manual_installment = kekal WhatsApp sahaja
   (jadual staff-entered, tiada formula deposit utk self-checkout).';

CREATE SEQUENCE IF NOT EXISTS psy_invoice_no_seq START 1;

CREATE OR REPLACE FUNCTION psy_assign_invoice_no() RETURNS trigger AS $$
BEGIN
  IF NEW.recommended_package_id IS NOT NULL AND NEW.invoice_no IS NULL THEN
    NEW.invoice_no := 'INV-' || lpad(nextval('psy_invoice_no_seq')::text, 6, '0');
  END IF;
  RETURN NEW;
END $$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_psy_assign_invoice_no ON psy_kob_sessions;
CREATE TRIGGER trg_psy_assign_invoice_no BEFORE INSERT OR UPDATE OF recommended_package_id ON psy_kob_sessions
  FOR EACH ROW EXECUTE FUNCTION psy_assign_invoice_no();

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

-- ──── psy_kob_installment_checkpoints ────
-- Checkpoint kumulatif pakej ansuran (Pelan Pelaburan Ansuran) bila
-- package_payment_mode = 'installment'. Dijana sekali dari template
-- psy_packages.installment_checkpoints semasa deposit disahkan (due_date
-- = tarikh deposit + month_offset bulan). Pesakit bayar apa-apa amount
-- bila-bila (rekod psy_payments biasa, tiada padanan 1:1) — checkpoint
-- disemak dgn banding JUMLAH TERKUMPUL psy_payments vs target_cumulative.
CREATE TABLE IF NOT EXISTS psy_kob_installment_checkpoints (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  kob_session_id    UUID NOT NULL REFERENCES psy_kob_sessions(id) ON DELETE CASCADE,
  patient_id        UUID NOT NULL REFERENCES psy_patients(id) ON DELETE CASCADE,
  seq               INT NOT NULL,
  month_offset      INT NOT NULL,
  due_date          DATE NOT NULL,
  target_cumulative NUMERIC(10,2) NOT NULL,
  status            TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','met','overdue')),
  met_at            TIMESTAMPTZ,
  created_at        TIMESTAMPTZ DEFAULT now(),
  CONSTRAINT psy_kob_installment_checkpoints_unique_seq UNIQUE (kob_session_id, seq)
);

-- Dedup peringatan auto "N hari sebelum due date" (runInstallmentReminderCheck,
-- event-reminders) — elak hantar berulang; lihat psy_auto_messages key='installment_reminder'.
ALTER TABLE psy_kob_installment_checkpoints
  ADD COLUMN IF NOT EXISTS installment_reminder_sent_at TIMESTAMPTZ;

-- Auto-Caj (kad tersimpan HitPay) — runInstallmentAutoChargeCheck (event-reminders)
-- cuba caj checkpoint ON due_date guna psy_kob_card_authorizations.gateway_auth_ref
-- SEBELUM jatuh balik ke pautan manual/overdue. autocharge_attempts dihadkan (3x,
-- 1x/hari) — lepas tu serah balik ke aliran manual sedia ada (installment_overdue).
ALTER TABLE psy_kob_installment_checkpoints
  ADD COLUMN IF NOT EXISTS autocharge_status TEXT NOT NULL DEFAULT 'not_attempted'
    CHECK (autocharge_status IN ('not_attempted','succeeded','failed')),
  ADD COLUMN IF NOT EXISTS autocharge_last_attempt_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS autocharge_attempts INT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS autocharge_payment_id UUID REFERENCES psy_payments(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_kob_checkpoints_session ON psy_kob_installment_checkpoints(kob_session_id);
CREATE INDEX IF NOT EXISTS idx_kob_checkpoints_patient ON psy_kob_installment_checkpoints(patient_id, status);
CREATE INDEX IF NOT EXISTS idx_kob_checkpoints_overdue ON psy_kob_installment_checkpoints(due_date) WHERE status = 'pending';

ALTER TABLE psy_kob_installment_checkpoints ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Patient read own checkpoints" ON psy_kob_installment_checkpoints;
CREATE POLICY "Patient read own checkpoints" ON psy_kob_installment_checkpoints FOR SELECT
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Staff manage checkpoints" ON psy_kob_installment_checkpoints;
CREATE POLICY "Staff manage checkpoints" ON psy_kob_installment_checkpoints FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

COMMENT ON COLUMN psy_kob_installment_checkpoints.seq IS
  '0 = checkpoint deposit (dibayar semasa sesi KOB, terus met). 1,2,3... = checkpoint seterusnya ikut turutan month_offset.';
COMMENT ON COLUMN psy_kob_installment_checkpoints.target_cumulative IS
  'Jumlah TERKUMPUL (bukan tambahan) yang wajib dicecah menjelang due_date. Checkpoint terakhir = harga penuh pakej (baki).';
COMMENT ON COLUMN psy_kob_installment_checkpoints.status IS
  'met = jumlah terkumpul psy_payments dah cecah target (disemak automatik tiap kali bayaran baru direkod). overdue ditetapkan oleh installment-overdue-check (cron harian) bila due_date lepas & belum met.';

-- ──── psy_kob_card_authorizations ────
-- Kad tersimpan HitPay (recurring-billing, save_payment_method=true) SATU
-- rekod per sesi KOB ansuran — bukan per checkpoint. Pesakit lampir kad
-- SEKALI (hosted page, dijana createKobCardAttachLink), kemudian tiap
-- checkpoint dicaj ON-DEMAND guna gateway_auth_ref (jumlah BERBEZA setiap
-- kali, ikut target_cumulative checkpoint semasa — bukan cycle/subscription
-- tetap HitPay). status='attached' ditetapkan oleh webhook JSON berasingan
-- (payments-webhook-recurring, event method_attached) — BEZA drpd webhook
-- form-encoded payments-webhook biasa (payment-requests).
CREATE TABLE IF NOT EXISTS psy_kob_card_authorizations (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  kob_session_id    UUID NOT NULL REFERENCES psy_kob_sessions(id) ON DELETE CASCADE,
  patient_id        UUID NOT NULL REFERENCES psy_patients(id) ON DELETE CASCADE,
  gateway_provider  TEXT NOT NULL DEFAULT 'hitpay',
  gateway_auth_ref  TEXT NOT NULL,   -- id 'recurring-billing' HitPay
  status            TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','attached','detached','failed')),
  card_last4        TEXT,
  card_brand        TEXT,
  attached_at       TIMESTAMPTZ,
  detached_at       TIMESTAMPTZ,
  created_at        TIMESTAMPTZ DEFAULT now(),
  CONSTRAINT psy_kob_card_authorizations_unique_session UNIQUE (kob_session_id)
);

CREATE INDEX IF NOT EXISTS idx_kob_card_auth_patient ON psy_kob_card_authorizations(patient_id);

ALTER TABLE psy_kob_card_authorizations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Patient read own card auth" ON psy_kob_card_authorizations;
CREATE POLICY "Patient read own card auth" ON psy_kob_card_authorizations FOR SELECT
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Staff manage card auth" ON psy_kob_card_authorizations;
CREATE POLICY "Staff manage card auth" ON psy_kob_card_authorizations FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- ──── trigger: auto-detach kad auto-caj bila pesakit stop/tamat rawatan ────
-- Audit Tier 9 #47 dah elak cron auto-caj pesakit stop (defensive skip, lihat
-- supabase/functions/event-reminders/index.ts), TAPI itu cuma semakan setiap
-- kali cron jalan — rekod kad sendiri (status='attached') tak pernah ditukar
-- secara automatik, kekal 'attached' sampai staff tekan "⏸️ Henti Auto-Caj"
-- manual (roles/staff/patient-hub.html stopAutoChargePH()). Trigger ni padankan
-- tindakan sama secara automatik bila outcome_status pesakit bertukar ke
-- 'berhenti'/'meninggal' — supaya rekod kad sentiasa tepat walau staf terlupa.
CREATE OR REPLACE FUNCTION auto_detach_card_on_patient_stop()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_row RECORD;
BEGIN
  IF NEW.outcome_status IN ('berhenti', 'meninggal')
     AND OLD.outcome_status IS DISTINCT FROM NEW.outcome_status THEN
    FOR v_row IN
      UPDATE psy_kob_card_authorizations
        SET status = 'detached', detached_at = now()
        WHERE patient_id = NEW.id AND status = 'attached'
        RETURNING id
    LOOP
      INSERT INTO psy_audit_log (actor_name, action, target, meta)
      VALUES ('Sistem (Auto)', 'kob.autocharge_stopped', v_row.id::text,
        jsonb_build_object('reason', 'patient_treatment_stopped', 'patient_id', NEW.id, 'outcome_status', NEW.outcome_status));
    END LOOP;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_auto_detach_card_on_patient_stop ON psy_patients;
CREATE TRIGGER trg_auto_detach_card_on_patient_stop
  AFTER UPDATE OF outcome_status ON psy_patients
  FOR EACH ROW
  EXECUTE FUNCTION auto_detach_card_on_patient_stop();

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

-- ──── psy_kob_agreements — Nama/IC tulisan tangan (LEGACY) + Waris/Penjamin ────
-- *_image_url di bawah adalah bukti tulisan-tangan LEGACY — sejak nama/IC ditukar
-- ke medan TAIP (bukan lukisan tangan), lajur ni TAK DIISI LAGI utk rekod baharu,
-- kekal hanya utk baca rekod lama. Waris/Penjamin (nama+IC+tandatangan) wajib
-- diisi di UI (validasi client-side), tapi nullable di DB supaya rekod lama tak terjejas.
ALTER TABLE psy_kob_agreements ADD COLUMN IF NOT EXISTS patient_name_image_url TEXT;
ALTER TABLE psy_kob_agreements ADD COLUMN IF NOT EXISTS patient_ic_image_url TEXT;
ALTER TABLE psy_kob_agreements ADD COLUMN IF NOT EXISTS guardian_name_image_url TEXT;
ALTER TABLE psy_kob_agreements ADD COLUMN IF NOT EXISTS guardian_ic_image_url TEXT;
ALTER TABLE psy_kob_agreements ADD COLUMN IF NOT EXISTS guardian_signature_url TEXT;
-- Nama/IC Waris/Penjamin kini medan TAIP (dulu cuma wujud sbg imej tulisan tangan
-- di atas, tiada lajur teks) — perlukan lajur teks baharu, sama konsep dgn
-- patient_name/patient_ic sedia ada.
ALTER TABLE psy_kob_agreements ADD COLUMN IF NOT EXISTS guardian_name TEXT;
ALTER TABLE psy_kob_agreements ADD COLUMN IF NOT EXISTS guardian_ic TEXT;

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

DROP POLICY IF EXISTS "Staff delete agreement" ON psy_kob_agreements;
CREATE POLICY "Staff delete agreement" ON psy_kob_agreements FOR DELETE
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- ──── psy_kob_slot_config ────
-- Templat slot tetap untuk KOB & Rawatan (Rabu-Ahad). Admin boleh on/off
-- setiap slot; tiada kapasiti per-pesakit.
CREATE TABLE IF NOT EXISTS psy_kob_slot_config (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  -- 'sesi_1on1' = Sesi 1:1 (Hakeema/Hakeem/Dr), diurus kad "C. Slot Sesi 1:1" kob-slots.html —
  -- guna baris-per-blok SAMA seperti KOB/Rawatan, reuse penuh (bukan jadual/model berasingan).
  slot_type    TEXT NOT NULL DEFAULT 'kob' CHECK (slot_type IN ('kob','rawatan','sesi_1on1')),
  day_of_week  INT NOT NULL CHECK (day_of_week IN (0, 3, 4, 5, 6)),  -- 0=Ahad, 3=Rabu, 4=Khamis, 5=Jumaat, 6=Sabtu
  slot_start   TIME NOT NULL,
  slot_end     TIME NOT NULL,
  is_active    BOOLEAN NOT NULL DEFAULT true,
  label        TEXT NOT NULL,         -- paparan cth "7-9 pg"
  sort_order   INT NOT NULL DEFAULT 0,
  note         TEXT,                  -- nota peringatan untuk slot
  max_bookings INT,                   -- audit #B2-47 (Tier 4): kapasiti maksimum blok ni (rawatan & sesi_1on1); NULL = tiada had/belum dikonfigur
  -- Jadual Slot Sesi 1:1 redesign (7 Okt 2026) — tempoh seorang pesakit dlm blok ni (minit).
  -- Dipakai sesi_1on1 sahaja utk auto-jana slot diskret (09:00,09:30,...) dari slot_start+max_bookings
  -- — SETIAP slot = SATU janji temu individu (bukan 1 blok = 1 kaunter kapasiti). NULL = kekal mod
  -- lama (blok utuh, tiada slot diskret) — kob/rawatan tak guna medan ni.
  slot_duration_minutes INT,
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

-- Seed lalai Slot Sesi 1:1 (Hakeema/Hakeem/Dr) — 2 blok (pagi/petang) x hari Rabu-Ahad,
-- sama pattern macam KOB/Rawatan di atas (baris-per-blok, ON/OFF per hari di UI).
INSERT INTO psy_kob_slot_config (slot_type, day_of_week, slot_start, slot_end, label, sort_order, is_active)
SELECT
  'sesi_1on1',
  d.day_of_week,
  s.slot_start::time,
  s.slot_end::time,
  s.label,
  s.sort_order,
  true
FROM
  (VALUES (3), (4), (5), (6), (0)) AS d(day_of_week),
  (VALUES
    ('09:00', '12:00', '9-12 pg',  1),
    ('14:00', '17:00', '2-5 ptg',  2)
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

-- Medan tambahan (dashboard Vitals — resp rate, pain score, penanda tidak normal)
ALTER TABLE psy_vitals ADD COLUMN IF NOT EXISTS respiratory_rate INT;
ALTER TABLE psy_vitals ADD COLUMN IF NOT EXISTS pain_score INT CHECK (pain_score BETWEEN 0 AND 10);
ALTER TABLE psy_vitals ADD COLUMN IF NOT EXISTS is_abnormal BOOLEAN NOT NULL DEFAULT false;

-- Kritikal (bahaya klinikal, perlu tindakan segera) — tahap lebih ketat drpd
-- "Tidak Normal" (is_abnormal) di atas. Dikira SERVER-SIDE SAHAJA (trigger di bawah),
-- tak boleh diubah/dipintas oleh client — supaya bacaan kritikal SENTIASA dikesan
-- tanpa bergantung laluan insert (patient-hub.html/plan-week.html/vitals-detail.html)
-- atau staf lupa tanda. Bila true, auto-cipta/kemaskini kes di Red Emergency
-- Protocol (psy_emergency_alerts) — lihat trg_vitals_notify_emergency di
-- 18_notifications_automations.sql.
ALTER TABLE psy_vitals ADD COLUMN IF NOT EXISTS is_critical BOOLEAN NOT NULL DEFAULT false;

-- Indeks
CREATE INDEX IF NOT EXISTS idx_psy_vitals_patient ON psy_vitals(patient_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_vitals_plan_week
  ON psy_vitals(plan_id, week_number) WHERE plan_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_psy_vitals_abnormal ON psy_vitals(is_abnormal) WHERE is_abnormal = true;
CREATE INDEX IF NOT EXISTS idx_psy_vitals_reading_date ON psy_vitals(reading_date DESC);

-- Backfill sekali sahaja: tandakan rekod sedia ada yang sudah melepasi ambang klinikal
-- biasa sebagai tidak normal, supaya statistik dashboard tak bermula 0 selepas migrate.
UPDATE psy_vitals SET is_abnormal = true WHERE is_abnormal = false AND (
  (bp_systolic IS NOT NULL AND (bp_systolic < 90 OR bp_systolic >= 130)) OR
  (bp_diastolic IS NOT NULL AND (bp_diastolic < 60 OR bp_diastolic >= 85)) OR
  (heart_rate IS NOT NULL AND (heart_rate < 60 OR heart_rate > 100)) OR
  (temperature IS NOT NULL AND (temperature < 36.1 OR temperature > 37.2)) OR
  (spo2 IS NOT NULL AND spo2 < 95)
);

-- ──── Ambang KRITIKAL — dikira server-side, elak client pintas/lupa tanda ────
-- Audit management batch 3 (29-30 Sept 2026): ambang BUKAN lagi hardcode di sini —
-- dibaca dari psy_settings key 'vitals_thresholds' (JSONB per-vital, diedit oleh
-- super_admin/doktor melalui tetapan.html, rujuk 23_settings.sql). critical_min/
-- critical_max kosong (NULL) utk sesuatu vital = automasi TAK aktif utk vital tu
-- (NULL dlm OR chain = falsy automatik) — jadi shipping fungsi ni TIDAK sendiri
-- menghidupkan apa-apa automasi baharu sehingga seseorang isi nilai melalui UI.
-- Dibalut exception-safe SEPENUHNYA (config rosak/parse gagal → is_critical=false)
-- sebab ni BEFORE trigger — kalau throw, ia boleh sekat SEMUA simpanan vitals klinik.
CREATE OR REPLACE FUNCTION fn_vitals_compute_critical()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
  v_cfg JSONB;
  v_bp_sys JSONB; v_bp_dia JSONB; v_hr JSONB; v_temp JSONB; v_spo2 JSONB; v_rr JSONB;
BEGIN
  NEW.is_critical := false;

  BEGIN
    SELECT value INTO v_cfg FROM psy_settings WHERE key = 'vitals_thresholds';
  EXCEPTION WHEN OTHERS THEN
    v_cfg := NULL;
  END;

  IF v_cfg IS NULL THEN
    RETURN NEW;
  END IF;

  BEGIN
    v_bp_sys := v_cfg -> 'bp_systolic';
    v_bp_dia := v_cfg -> 'bp_diastolic';
    v_hr     := v_cfg -> 'heart_rate';
    v_temp   := v_cfg -> 'temperature';
    v_spo2   := v_cfg -> 'spo2';
    v_rr     := v_cfg -> 'respiratory_rate';

    NEW.is_critical := (
      (NEW.bp_systolic IS NOT NULL AND v_bp_sys IS NOT NULL AND (
        (v_bp_sys->>'critical_min' IS NOT NULL AND NEW.bp_systolic < (v_bp_sys->>'critical_min')::numeric) OR
        (v_bp_sys->>'critical_max' IS NOT NULL AND NEW.bp_systolic >= (v_bp_sys->>'critical_max')::numeric)
      )) OR
      (NEW.bp_diastolic IS NOT NULL AND v_bp_dia IS NOT NULL AND (
        (v_bp_dia->>'critical_min' IS NOT NULL AND NEW.bp_diastolic < (v_bp_dia->>'critical_min')::numeric) OR
        (v_bp_dia->>'critical_max' IS NOT NULL AND NEW.bp_diastolic >= (v_bp_dia->>'critical_max')::numeric)
      )) OR
      (NEW.heart_rate IS NOT NULL AND v_hr IS NOT NULL AND (
        (v_hr->>'critical_min' IS NOT NULL AND NEW.heart_rate < (v_hr->>'critical_min')::numeric) OR
        (v_hr->>'critical_max' IS NOT NULL AND NEW.heart_rate > (v_hr->>'critical_max')::numeric)
      )) OR
      (NEW.temperature IS NOT NULL AND v_temp IS NOT NULL AND (
        (v_temp->>'critical_min' IS NOT NULL AND NEW.temperature < (v_temp->>'critical_min')::numeric) OR
        (v_temp->>'critical_max' IS NOT NULL AND NEW.temperature >= (v_temp->>'critical_max')::numeric)
      )) OR
      (NEW.spo2 IS NOT NULL AND v_spo2 IS NOT NULL AND
        (v_spo2->>'critical_min' IS NOT NULL AND NEW.spo2 < (v_spo2->>'critical_min')::numeric)
      ) OR
      (NEW.respiratory_rate IS NOT NULL AND v_rr IS NOT NULL AND (
        (v_rr->>'critical_min' IS NOT NULL AND NEW.respiratory_rate < (v_rr->>'critical_min')::numeric) OR
        (v_rr->>'critical_max' IS NOT NULL AND NEW.respiratory_rate > (v_rr->>'critical_max')::numeric)
      ))
    );
  EXCEPTION WHEN OTHERS THEN
    RAISE LOG 'fn_vitals_compute_critical: %', SQLERRM;
    NEW.is_critical := false;
  END;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_vitals_compute_critical ON psy_vitals;
CREATE TRIGGER trg_vitals_compute_critical
  BEFORE INSERT OR UPDATE ON psy_vitals
  FOR EACH ROW EXECUTE FUNCTION fn_vitals_compute_critical();

-- TIADA backfill is_critical — config critical_* kosong (NULL) secara default, jadi
-- backfill akan sentiasa false utk semua rekod sedia ada sehingga doktor isi ambang.

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
COMMENT ON COLUMN psy_vitals.respiratory_rate IS 'Kadar pernafasan (nafas/minit).';
COMMENT ON COLUMN psy_vitals.pain_score IS 'Skor kesakitan pesakit, 0 (tiada) hingga 10 (teruk). Pilihan, boleh NULL.';
COMMENT ON COLUMN psy_vitals.is_abnormal IS
  'Dikira semasa simpan (ambang klinikal BP/HR/suhu/SpO2/resp rate) ATAU ditanda manual oleh staff. '
  'Disimpan (bukan dikira semula tiap kali) supaya statistik dashboard Vitals murah untuk query.';

COMMENT ON COLUMN psy_vitals.is_critical IS
  'Bacaan kritikal (bahaya klinikal, perlu tindakan segera) — dikira SERVER-SIDE sahaja '
  '(trg_vitals_compute_critical), staf TAK boleh override/uncheck macam is_abnormal. Bila true, '
  'trg_vitals_notify_emergency (18_notifications_automations.sql) auto-cipta/kemaskini kes di '
  'psy_emergency_alerts — Red Emergency Protocol. Ambang dibaca dari psy_settings.vitals_thresholds '
  '(diedit oleh super_admin/doktor di tetapan.html) — kosong (NULL) = automasi TAK aktif utk vital tu.';


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
  -- Ditambah 7 Okt 2026 (audit management #B2-111) — status semakan, sama pola
  -- dgn psy_reaksi_actions.status. DEFAULT 'active' supaya rekod sedia ada tak
  -- terjejas; kod baharu (borang Tambah Reaksi) set 'draft' secara eksplisit.
  status           TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('draft','reviewed','approved','active')),
  -- Ditambah 8 Okt 2026 — simptom yang boleh berlaku sebelah (kiri/kanan),
  -- cth Kejang/Kebas/Sakit lutut/Sakit bahu. Pesakit pilih bila card ditanda;
  -- false = tiada sub-pilihan sisi langsung.
  boleh_pilih_lokasi BOOLEAN NOT NULL DEFAULT false,
  -- Ditambah 8 Okt 2026 — simptom yang juga boleh ditentukan ikut anggota
  -- (tangan/kaki), cth Kejang/Kebas. Hanya relevan bila boleh_pilih_lokasi=true.
  boleh_pilih_anggota BOOLEAN NOT NULL DEFAULT false,
  created_at       TIMESTAMPTZ DEFAULT now(),
  updated_at       TIMESTAMPTZ DEFAULT now(),
  CONSTRAINT chk_reaksi_item_tahap CHECK (tahap_risiko IN ('rendah','sederhana','tinggi')),
  -- Biasa/Teruk WAJIB ada pada semua reaksi (20 Okt 2026, arahan management) —
  -- kunci di DB supaya tiada laluan (termasuk SQL/import terus) boleh set false.
  CONSTRAINT chk_reaksi_item_pilih_teruk_wajib CHECK (boleh_pilih_teruk = true)
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
COMMENT ON COLUMN psy_reaksi_item.boleh_pilih_teruk IS 'WAJIB true pada semua baris (CHECK constraint, 20 Okt 2026) — pesakit sentiasa tanda Biasa/Teruk di Catatan Harian (Teruk→Merah terus, apa-apa tahap_risiko pun). Kolum dikekalkan (bukan dibuang) supaya kod baca sedia ada (!== false) terus berfungsi.';
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
  -- Ditambah 7 Okt 2026 (audit management #B2-111) — status semakan peringkat
  -- kategori, sama pola dgn psy_reaksi_actions.status.
  status     TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('draft','reviewed','approved','active')),
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
  -- Ditambah 23 Sept 2026 (audit management #B2-3, contraindication) — kata kunci
  -- dipisah koma (cth "diabetes, kencing manis") yang, bila dijumpai dalam
  -- psy_patients.medical_condition pesakit (carian teks, tak sensitif huruf besar),
  -- akan sorok/gantung cadangan ni + papar amaran kat staf/coach dari terus hantar
  -- kat pesakit. Pilihan (NULL/kosong = tiada sekatan diketahui).
  contraindication_keywords TEXT,
  -- Ditambah 23 Sept 2026 (audit management #B2-39/#B2-45) — status semakan.
  -- DEFAULT DB ialah 'active' (kekalkan tingkah laku sedia ada utk rekod sedia
  -- ada/laluan insert lain yg tak eksplisit set), TAPI kod baharu (import, tindakan
  -- baharu di drawer) set 'draft' secara eksplisit supaya kandungan baharu tak terus
  -- pengaruh cadangan pesakit sebelum staf semak. Cuma tindakan status='active' yang
  -- digunakan utk jana cadangan — lihat filter di roles/patient/kepatuhan.html.
  status       TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('draft','reviewed','approved','active')),
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

-- ──── psy_reaksi_conflict_pairs — pasangan tindakan yang BERCANGGAH (audit #118) ────
-- Staf tetapkan sendiri pasangan tindakan yang bercanggah bila tercadang serentak
-- (cth "Tambah air" vs "Kurangkan air") — sistem TIDAK cuba teka secara automatik
-- berdasarkan makna teks. Diguna generateReaksiAdvice() (roles/patient/kepatuhan.html)
-- utk paksa status='needs_review' bila mana-mana 2 tindakan dlm cadangan sepadan
-- dgn pasangan di sini, dan reaksi-preview.html (UI uji staf) utk papar amaran
-- SEBELUM pesakit submit sebenar. Urus senarai di reaksi-item.html tab Konflik.
CREATE TABLE IF NOT EXISTS psy_reaksi_conflict_pairs (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  action_id_1 UUID NOT NULL REFERENCES psy_reaksi_actions(id) ON DELETE CASCADE,
  action_id_2 UUID NOT NULL REFERENCES psy_reaksi_actions(id) ON DELETE CASCADE,
  note        TEXT,                                   -- sebab bercanggah (pilihan)
  created_by  UUID REFERENCES psy_profiles(id),
  created_at  TIMESTAMPTZ DEFAULT now(),
  CONSTRAINT chk_reaksi_conflict_pair_distinct CHECK (action_id_1 <> action_id_2)
);

-- Elak pasangan duplicate tak kira arah (A,B) sama dgn (B,A) — LEAST/GREATEST
-- supaya index tak kira susunan 2 tindakan diisi dalam borang.
CREATE UNIQUE INDEX IF NOT EXISTS uq_reaksi_conflict_pair
  ON psy_reaksi_conflict_pairs (LEAST(action_id_1, action_id_2), GREATEST(action_id_1, action_id_2));

ALTER TABLE psy_reaksi_conflict_pairs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff manage reaksi conflict pairs" ON psy_reaksi_conflict_pairs;
CREATE POLICY "Staff manage reaksi conflict pairs" ON psy_reaksi_conflict_pairs FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "Authenticated read reaksi conflict pairs" ON psy_reaksi_conflict_pairs;
CREATE POLICY "Authenticated read reaksi conflict pairs" ON psy_reaksi_conflict_pairs FOR SELECT
  USING (auth.uid() IS NOT NULL);

COMMENT ON COLUMN psy_reaksi_conflict_pairs.note IS 'Sebab bercanggah — dipaparkan kpd staf, pilihan';

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
  -- 'needs_review' ditambah 23 Sept 2026 (audit management #B2-2, conflict-check) —
  -- bila 1 submission Catatan Harian cetuskan >1 reaksi serentak, baris digantung
  -- di status ni (cron reaksi-advice-send HANYA proses status='draft' — lihat
  -- supabase/functions/reaksi-advice-send/index.ts, jadi 'needs_review' auto tak
  -- terhantar) sehingga staff Lulus (→'draft') atau Skip (→'skipped') di
  -- reaksi-laporan.html. Guna kolum reviewed_by/reviewed_at sedia ada.
  status           TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','sent','skipped','needs_review')),
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

-- Simptom yang pesakit tanda "Teruk" (format sama dgn symptoms: "Kumpulan::Label").
-- Dibaca oleh trg_reaksi_compute_zon utk kira zon di server, bukan pelayar pesakit.
ALTER TABLE psy_reaksi_advice_log ADD COLUMN IF NOT EXISTS teruk_labels JSONB NOT NULL DEFAULT '[]';

-- Pasangan tindakan bercanggah (audit #118) yg dikesan semasa generateReaksiAdvice()
-- — array of {action_id_1, title_1, action_id_2, title_2}. Diguna reaksi-laporan.html
-- papar SEBAB khusus di kad "Perlu Disemak" (bukan setakat "≥2 simptom" generik).
ALTER TABLE psy_reaksi_advice_log ADD COLUMN IF NOT EXISTS conflict_pairs JSONB NOT NULL DEFAULT '[]';

CREATE INDEX IF NOT EXISTS idx_reaksi_advice_log_status ON psy_reaksi_advice_log(status, created_at);
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
  -- 2. Jantung (dulu "Peredaran Darah", ditukar 1 Okt 2026 atas permintaan staf)
  ('Jantung','❤️','Tekanan darah tinggi',130),
  ('Jantung','❤️','Tekanan darah rendah',140),
  ('Jantung','❤️','Berdebar-debar',150),
  ('Jantung','❤️','Tiada simptom',160),
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

-- ──── Tambah simptom baharu (8 Okt 2026): Pencernaan — Najis berdarah, Buasir, Buasir dah pulih ────
-- Guard per-baris (bukan "jadual kosong") supaya jalan selamat pada DB sedia ada.
INSERT INTO psy_reaksi_item (kumpulan, ikon, label, urutan)
SELECT 'Pencernaan', '', v.label, v.urutan
FROM (VALUES
  ('Najis berdarah', 111),
  ('Buasir', 112),
  ('Buasir dah pulih', 113)
) AS v(label, urutan)
WHERE NOT EXISTS (
  SELECT 1 FROM psy_reaksi_item WHERE kumpulan = 'Pencernaan' AND label = v.label
);

-- ──── Otot & Saraf (8 Okt 2026): Kejang & Kebas dapat sub-pilihan sisi + anggota ────
-- (bukan item berasingan — ditarik balik, gantikan dgn boleh_pilih_lokasi di atas)
UPDATE psy_reaksi_item SET boleh_pilih_lokasi = true, boleh_pilih_anggota = true
WHERE kumpulan = 'Otot & Saraf' AND label IN ('Kejang','Kebas');

-- ──── Otot & Saraf (8 Okt 2026): tambah Sakit lutut, Sakit bahu — sisi sahaja ────
INSERT INTO psy_reaksi_item (kumpulan, ikon, label, urutan, boleh_pilih_lokasi)
SELECT 'Otot & Saraf', '', v.label, v.urutan, true
FROM (VALUES
  ('Sakit lutut', 245),
  ('Sakit bahu', 246)
) AS v(label, urutan)
WHERE NOT EXISTS (
  SELECT 1 FROM psy_reaksi_item WHERE kumpulan = 'Otot & Saraf' AND label = v.label
);

-- ──── Kumpulan baharu (8 Okt 2026): 8. Wanita ────
INSERT INTO psy_reaksi_item (kumpulan, ikon, label, urutan)
SELECT 'Wanita', '🌸', v.label, v.urutan
FROM (VALUES
  ('Keputihan (discharge)', 560),
  ('Period lambat datang', 570),
  ('Tempoh haid lama', 580),
  ('Keluar ketulan darah', 590),
  ('Keluar nanah di payudara', 600),
  ('Keluar lendir/darah/air di payudara', 610),
  ('Senggugut', 620),
  ('Keluar darah selepas menopaus', 630),
  ('Tiada simptom', 640)
) AS v(label, urutan)
WHERE NOT EXISTS (
  SELECT 1 FROM psy_reaksi_item WHERE kumpulan = 'Wanita' AND label = v.label
);

-- ──── Pernafasan (8 Okt 2026): kekal Sesak nafas/Batuk, tambah Semput/Tercungap-cungap,
-- buang Kahak/Mukus/Hidung berair/Bersin + item staf tambah (Radang Paru-paru) ────
INSERT INTO psy_reaksi_item (kumpulan, ikon, label, urutan)
SELECT 'Pernafasan', '🫁', v.label, v.urutan
FROM (VALUES
  ('Semput', 445),
  ('Tercungap-cungap', 447)
) AS v(label, urutan)
WHERE NOT EXISTS (
  SELECT 1 FROM psy_reaksi_item WHERE kumpulan = 'Pernafasan' AND label = v.label
);

DELETE FROM psy_reaksi_item
WHERE kumpulan = 'Pernafasan'
  AND label NOT IN ('Sesak nafas','Batuk','Semput','Tercungap-cungap','Tiada simptom');

-- ──── Emosi & Tenaga (8 Okt 2026): buang "Kurang tenaga" ────
DELETE FROM psy_reaksi_item
WHERE kumpulan = 'Emosi & Tenaga' AND label = 'Kurang tenaga';

-- ──── Bengkak & Cecair (8 Okt 2026): tambah "Keradangan", buang "Edema" ────
INSERT INTO psy_reaksi_item (kumpulan, ikon, label, urutan)
SELECT 'Bengkak & Cecair', '💧', 'Keradangan', 535
WHERE NOT EXISTS (
  SELECT 1 FROM psy_reaksi_item WHERE kumpulan = 'Bengkak & Cecair' AND label = 'Keradangan'
);

DELETE FROM psy_reaksi_item
WHERE kumpulan = 'Bengkak & Cecair' AND label = 'Edema';

-- ──── Seed psy_reaksi_kategori — dijana dari kumpulan psy_reaksi_item ────
INSERT INTO psy_reaksi_kategori (nama, ikon, urutan)
SELECT kumpulan, MAX(COALESCE(ikon, '')), MIN(COALESCE(urutan, 100))
FROM psy_reaksi_item GROUP BY kumpulan
ON CONFLICT (nama) DO NOTHING;

-- ──── Seed contoh psy_reaksi_actions + pemetaan (Pencernaan + Jantung) ────
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
  SELECT id INTO s_berdebar FROM psy_reaksi_item WHERE kumpulan='Jantung' AND label='Berdebar-debar' LIMIT 1;

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
-- Reaksi Pemulihan — taksonomi 9 kumpulan penuh (ikut jadual reference
-- client, 20 Okt 2026). REPLACE 100%: item sedia ada yang padan DINAMA
-- SEMULA (ID + mapping tindakan psy_reaksi_action_map dikekalkan), item
-- yang TIADA dalam jadual reference DIBUANG terus (arahan eksplisit user
-- — "yang takde dalam gambar tu dan ada dalam sistem kira buang"), item
-- baharu DITAMBAH. Kumpulan baharu: Sistem kencing & saluran urinari
-- (tiada padanan lama langsung).
--
-- Pemetaan kumpulan lama → baharu:
--   Pencernaan                 → Pencernaan (nama kekal, item diselaraskan)
--   Jantung                    → Jantung & Peredaran darah
--   Otot & Saraf                → Otot, sendi & saraf
--   Detoksifikasi               → Kulit & Perubahan badan
--   Emosi & Tenaga               → Emosi, tidur & tenaga
--   Pernafasan                  → Sistem pernafasan
--   Bengkak & Cecair              → Bengkak & perubahan cecair
--   Wanita                      → Kesihatan wanita
--   (tiada)                     → Sistem kencing & saluran urinari (BAHARU)
--
-- Nota: tahap_risiko/markah_risiko/boleh_pilih_teruk/is_emergency item
-- BAHARU kekal nilai default (rendah) — staff perlu tetapkan sendiri
-- tahap risiko (terutama item berkaitan darah: Najis Berdarah, Batuk
-- berdarah, Kencing berdarah, Pendarahan selepas menopaus, dll) di
-- reaksi-item.html selepas migration ni jalan.
-- ════════════════════════════════════════════════════════════════

-- ──── FASA A: Nama semula label (kekal ID + mapping tindakan) ────
UPDATE psy_reaksi_item SET label='Perut Kembung' WHERE kumpulan='Pencernaan' AND label='Kembung perut';
UPDATE psy_reaksi_item SET label='Banyak angin (kentut)' WHERE kumpulan='Pencernaan' AND label='Banyak angin';
UPDATE psy_reaksi_item SET label='Kerap sendawa' WHERE kumpulan='Pencernaan' AND label='Banyak sendawa';
UPDATE psy_reaksi_item SET label='Kerap buang air besar' WHERE kumpulan='Pencernaan' AND label='Banyak membuang air besar';
UPDATE psy_reaksi_item SET label='Cirit birit' WHERE kumpulan='Pencernaan' AND label='Cirit-birit';
UPDATE psy_reaksi_item SET label='Tiada masalah' WHERE kumpulan='Pencernaan' AND label='Tiada simptom';
UPDATE psy_reaksi_item SET label='Najis Berdarah' WHERE kumpulan='Pencernaan' AND label='Najis berdarah';
UPDATE psy_reaksi_item SET label='Buasir semakin pulih' WHERE kumpulan='Pencernaan' AND label='Buasir dah pulih';

UPDATE psy_reaksi_item SET label='Jantung berdebar-debar' WHERE kumpulan='Jantung' AND label='Berdebar-debar';
UPDATE psy_reaksi_item SET label='Tiada Masalah' WHERE kumpulan='Jantung' AND label='Tiada simptom';

UPDATE psy_reaksi_item SET label='Kejang otot' WHERE kumpulan='Otot & Saraf' AND label='Kejang';
UPDATE psy_reaksi_item SET label='Tiada Masalah' WHERE kumpulan='Otot & Saraf' AND label='Tiada simptom';

UPDATE psy_reaksi_item SET label='Jerawat muncul' WHERE kumpulan='Detoksifikasi' AND label='Jerawat keluar';
UPDATE psy_reaksi_item SET label='Ruam muncul' WHERE kumpulan='Detoksifikasi' AND label='Ruam';
UPDATE psy_reaksi_item SET label='Badan terasa panas' WHERE kumpulan='Detoksifikasi' AND label='Badan panas';
UPDATE psy_reaksi_item SET label='Badan terasa sejuk' WHERE kumpulan='Detoksifikasi' AND label='Badan sejuk';
UPDATE psy_reaksi_item SET label='Tiada Masalah' WHERE kumpulan='Detoksifikasi' AND label='Tiada simptom';

UPDATE psy_reaksi_item SET label='Susah tidur' WHERE kumpulan='Emosi & Tenaga' AND label='Susah nak tidur (insomnia)';
UPDATE psy_reaksi_item SET label='Mudah sebak/menangis' WHERE kumpulan='Emosi & Tenaga' AND label='Mudah sebak';
UPDATE psy_reaksi_item SET label='Tiada masalah' WHERE kumpulan='Emosi & Tenaga' AND label='Tiada simptom';

UPDATE psy_reaksi_item SET label='Semput/nafas berbunyi' WHERE kumpulan='Pernafasan' AND label='Semput';
UPDATE psy_reaksi_item SET label='Tiada masalah' WHERE kumpulan='Pernafasan' AND label='Tiada simptom';

UPDATE psy_reaksi_item SET label='Kawasan badan merah, panas atau bengkak' WHERE kumpulan='Bengkak & Cecair' AND label='Keradangan';
UPDATE psy_reaksi_item SET label='Tiada masalah' WHERE kumpulan='Bengkak & Cecair' AND label='Tiada simptom';

UPDATE psy_reaksi_item SET label='Keputihan' WHERE kumpulan='Wanita' AND label='Keputihan (discharge)';
UPDATE psy_reaksi_item SET label='Haid lewat datang' WHERE kumpulan='Wanita' AND label='Period lambat datang';
UPDATE psy_reaksi_item SET label='Haid lebih lama dari biasa' WHERE kumpulan='Wanita' AND label='Tempoh haid lama';
UPDATE psy_reaksi_item SET label='Keluar ketulan darah ketika haid' WHERE kumpulan='Wanita' AND label='Keluar ketulan darah';
UPDATE psy_reaksi_item SET label='Keluar cecair dari puting payudara' WHERE kumpulan='Wanita' AND label='Keluar lendir/darah/air di payudara';
UPDATE psy_reaksi_item SET label='Pendarahan selepas menopaus' WHERE kumpulan='Wanita' AND label='Keluar darah selepas menopaus';
UPDATE psy_reaksi_item SET label='Tiada Masalah' WHERE kumpulan='Wanita' AND label='Tiada simptom';

-- ──── FASA B: Buang item yang TIADA dalam jadual reference ────
DELETE FROM psy_reaksi_item WHERE kumpulan='Pencernaan' AND label NOT IN (
  'Perut Kembung','Banyak angin (kentut)','Kerap sendawa','Sakit perut','Sakit bahagian kanan atas perut',
  'Batu hempedu','Hilang selera makan','Kerap buang air besar','Loya','Muntah','Sembelit','Cirit birit',
  'Najis hitam','Najis Berdarah','Buasir semakin pulih','Lendir keluar bersama najis','Pedih ulu hati','Buasir','Tiada masalah');

DELETE FROM psy_reaksi_item WHERE kumpulan='Jantung' AND label NOT IN (
  'Tekanan darah tinggi','Tekanan darah rendah','Jantung berdebar-debar','Sakit dada',
  'Pening/hampir pengsan','Pengsan','Denyutan jantung tidak teratur','Tiada Masalah');

DELETE FROM psy_reaksi_item WHERE kumpulan='Otot & Saraf' AND label NOT IN (
  'Sakit badan','Sakit sendi','Sakit otot','Sakit belikat','Sakit tengkuk','Sakit pinggang','Sakit belakang',
  'Kejang otot','Kebas','Sakit lutut','Sakit bahu','Rasa mencucuk-cucuk','Lemah anggota badan','Tiada Masalah');

DELETE FROM psy_reaksi_item WHERE kumpulan='Detoksifikasi' AND label NOT IN (
  'Gatal-gatal','Jerawat muncul','Ruam muncul','Kulit mengelupas','Kulit menjadi lebih sensitif',
  'Kulit kemerahan','Kulit kering','Badan terasa panas','Badan terasa sejuk','Tiada Masalah');

DELETE FROM psy_reaksi_item WHERE kumpulan='Emosi & Tenaga' AND label NOT IN (
  'Susah tidur','Mengantuk luar biasa','Cepat letih','Lemah badan','Mudah sebak/menangis','Gelisah',
  'Badan terasa berat','Mudah marah','Sukar fokus','Tidur lebih baik','Tenaga bertambah baik','Emosi lebih stabil','Tiada masalah');

DELETE FROM psy_reaksi_item WHERE kumpulan='Pernafasan' AND label NOT IN (
  'Hidung berair/banyak hingus','Hidung tersumbat','Batuk','Batuk berkahak','Batuk berdarah',
  'Sesak nafas','Semput/nafas berbunyi','Tercungap-cungap','Tiada masalah');

DELETE FROM psy_reaksi_item WHERE kumpulan='Bengkak & Cecair' AND label NOT IN (
  'Bengkak kaki','Bengkak tangan','Bengkak muka','Bengkak sekitar mata','Perut membengkak',
  'Kawasan badan merah, panas atau bengkak','Bengkak semakin berkurang','Tiada masalah');

DELETE FROM psy_reaksi_item WHERE kumpulan='Wanita' AND label NOT IN (
  'Keputihan','Haid lewat datang','Haid lebih lama dari biasa','Keluar ketulan darah ketika haid',
  'Keluar cecair dari puting payudara','Keluar darah dari puting payudara','Senggugut',
  'Pendarahan selepas menopaus','Darah haid terlalu banyak','Tiada Masalah');

-- ──── FASA C: Nama semula kumpulan (kategori) ────
UPDATE psy_reaksi_item SET kumpulan='Jantung & Peredaran darah' WHERE kumpulan='Jantung';
UPDATE psy_reaksi_item SET kumpulan='Otot, sendi & saraf' WHERE kumpulan='Otot & Saraf';
UPDATE psy_reaksi_item SET kumpulan='Kulit & Perubahan badan' WHERE kumpulan='Detoksifikasi';
UPDATE psy_reaksi_item SET kumpulan='Emosi, tidur & tenaga' WHERE kumpulan='Emosi & Tenaga';
UPDATE psy_reaksi_item SET kumpulan='Sistem pernafasan' WHERE kumpulan='Pernafasan';
UPDATE psy_reaksi_item SET kumpulan='Bengkak & perubahan cecair' WHERE kumpulan='Bengkak & Cecair';
UPDATE psy_reaksi_item SET kumpulan='Kesihatan wanita' WHERE kumpulan='Wanita';

-- ──── FASA D: Tambah item baharu + selaras urutan/ikon SEMUA item (sedia ada + baharu) ────
-- Nota: SENGAJA guna WITH...AS(VALUES...) inline (bukan TEMP TABLE) — sesetengah
-- runner SQL (cth Supabase SQL editor/MCP) laksana setiap statement pada sambungan
-- berasingan, jadi TEMP TABLE hilang antara statement ("relation does not exist").
-- Senarai sama diulang 2x (INSERT + UPDATE) supaya setiap statement berdiri sendiri.
INSERT INTO psy_reaksi_item (kumpulan, ikon, label, urutan)
SELECT t.kumpulan, t.ikon, t.label, t.urutan FROM (VALUES
  ('Pencernaan','Perut Kembung',10,'🍽️'),
  ('Pencernaan','Banyak angin (kentut)',20,'🍽️'),
  ('Pencernaan','Kerap sendawa',30,'🍽️'),
  ('Pencernaan','Sakit perut',40,'🍽️'),
  ('Pencernaan','Sakit bahagian kanan atas perut',50,'🍽️'),
  ('Pencernaan','Batu hempedu',60,'🍽️'),
  ('Pencernaan','Hilang selera makan',70,'🍽️'),
  ('Pencernaan','Kerap buang air besar',80,'🍽️'),
  ('Pencernaan','Loya',90,'🍽️'),
  ('Pencernaan','Muntah',100,'🍽️'),
  ('Pencernaan','Sembelit',110,'🍽️'),
  ('Pencernaan','Cirit birit',120,'🍽️'),
  ('Pencernaan','Najis hitam',130,'🍽️'),
  ('Pencernaan','Najis Berdarah',140,'🍽️'),
  ('Pencernaan','Buasir semakin pulih',150,'🍽️'),
  ('Pencernaan','Lendir keluar bersama najis',160,'🍽️'),
  ('Pencernaan','Pedih ulu hati',170,'🍽️'),
  ('Pencernaan','Buasir',180,'🍽️'),
  ('Pencernaan','Tiada masalah',190,'🍽️'),

  ('Jantung & Peredaran darah','Tekanan darah tinggi',1010,'❤️'),
  ('Jantung & Peredaran darah','Tekanan darah rendah',1020,'❤️'),
  ('Jantung & Peredaran darah','Jantung berdebar-debar',1030,'❤️'),
  ('Jantung & Peredaran darah','Sakit dada',1040,'❤️'),
  ('Jantung & Peredaran darah','Pening/hampir pengsan',1050,'❤️'),
  ('Jantung & Peredaran darah','Pengsan',1060,'❤️'),
  ('Jantung & Peredaran darah','Denyutan jantung tidak teratur',1070,'❤️'),
  ('Jantung & Peredaran darah','Tiada Masalah',1080,'❤️'),

  ('Otot, sendi & saraf','Sakit badan',2010,'💪'),
  ('Otot, sendi & saraf','Sakit sendi',2020,'💪'),
  ('Otot, sendi & saraf','Sakit otot',2030,'💪'),
  ('Otot, sendi & saraf','Sakit belikat',2040,'💪'),
  ('Otot, sendi & saraf','Sakit tengkuk',2050,'💪'),
  ('Otot, sendi & saraf','Sakit pinggang',2060,'💪'),
  ('Otot, sendi & saraf','Sakit belakang',2070,'💪'),
  ('Otot, sendi & saraf','Kejang otot',2080,'💪'),
  ('Otot, sendi & saraf','Kebas',2090,'💪'),
  ('Otot, sendi & saraf','Sakit lutut',2100,'💪'),
  ('Otot, sendi & saraf','Sakit bahu',2110,'💪'),
  ('Otot, sendi & saraf','Rasa mencucuk-cucuk',2120,'💪'),
  ('Otot, sendi & saraf','Lemah anggota badan',2130,'💪'),
  ('Otot, sendi & saraf','Tiada Masalah',2140,'💪'),

  ('Kulit & Perubahan badan','Gatal-gatal',3010,'🧴'),
  ('Kulit & Perubahan badan','Jerawat muncul',3020,'🧴'),
  ('Kulit & Perubahan badan','Ruam muncul',3030,'🧴'),
  ('Kulit & Perubahan badan','Kulit mengelupas',3040,'🧴'),
  ('Kulit & Perubahan badan','Kulit menjadi lebih sensitif',3050,'🧴'),
  ('Kulit & Perubahan badan','Kulit kemerahan',3060,'🧴'),
  ('Kulit & Perubahan badan','Kulit kering',3070,'🧴'),
  ('Kulit & Perubahan badan','Badan terasa panas',3080,'🧴'),
  ('Kulit & Perubahan badan','Badan terasa sejuk',3090,'🧴'),
  ('Kulit & Perubahan badan','Tiada Masalah',3100,'🧴'),

  ('Emosi, tidur & tenaga','Susah tidur',4010,'⚡'),
  ('Emosi, tidur & tenaga','Mengantuk luar biasa',4020,'⚡'),
  ('Emosi, tidur & tenaga','Cepat letih',4030,'⚡'),
  ('Emosi, tidur & tenaga','Lemah badan',4040,'⚡'),
  ('Emosi, tidur & tenaga','Mudah sebak/menangis',4050,'⚡'),
  ('Emosi, tidur & tenaga','Gelisah',4060,'⚡'),
  ('Emosi, tidur & tenaga','Badan terasa berat',4070,'⚡'),
  ('Emosi, tidur & tenaga','Mudah marah',4080,'⚡'),
  ('Emosi, tidur & tenaga','Sukar fokus',4090,'⚡'),
  ('Emosi, tidur & tenaga','Tidur lebih baik',4100,'⚡'),
  ('Emosi, tidur & tenaga','Tenaga bertambah baik',4110,'⚡'),
  ('Emosi, tidur & tenaga','Emosi lebih stabil',4120,'⚡'),
  ('Emosi, tidur & tenaga','Tiada masalah',4130,'⚡'),

  ('Sistem pernafasan','Hidung berair/banyak hingus',5010,'🫁'),
  ('Sistem pernafasan','Hidung tersumbat',5020,'🫁'),
  ('Sistem pernafasan','Batuk',5030,'🫁'),
  ('Sistem pernafasan','Batuk berkahak',5040,'🫁'),
  ('Sistem pernafasan','Batuk berdarah',5050,'🫁'),
  ('Sistem pernafasan','Sesak nafas',5060,'🫁'),
  ('Sistem pernafasan','Semput/nafas berbunyi',5070,'🫁'),
  ('Sistem pernafasan','Tercungap-cungap',5080,'🫁'),
  ('Sistem pernafasan','Tiada masalah',5090,'🫁'),

  ('Bengkak & perubahan cecair','Bengkak kaki',6010,'💧'),
  ('Bengkak & perubahan cecair','Bengkak tangan',6020,'💧'),
  ('Bengkak & perubahan cecair','Bengkak muka',6030,'💧'),
  ('Bengkak & perubahan cecair','Bengkak sekitar mata',6040,'💧'),
  ('Bengkak & perubahan cecair','Perut membengkak',6050,'💧'),
  ('Bengkak & perubahan cecair','Kawasan badan merah, panas atau bengkak',6060,'💧'),
  ('Bengkak & perubahan cecair','Bengkak semakin berkurang',6070,'💧'),
  ('Bengkak & perubahan cecair','Tiada masalah',6080,'💧'),

  ('Kesihatan wanita','Keputihan',7010,'🌸'),
  ('Kesihatan wanita','Haid lewat datang',7020,'🌸'),
  ('Kesihatan wanita','Haid lebih lama dari biasa',7030,'🌸'),
  ('Kesihatan wanita','Keluar ketulan darah ketika haid',7040,'🌸'),
  ('Kesihatan wanita','Keluar cecair dari puting payudara',7050,'🌸'),
  ('Kesihatan wanita','Keluar darah dari puting payudara',7060,'🌸'),
  ('Kesihatan wanita','Senggugut',7070,'🌸'),
  ('Kesihatan wanita','Pendarahan selepas menopaus',7080,'🌸'),
  ('Kesihatan wanita','Darah haid terlalu banyak',7090,'🌸'),
  ('Kesihatan wanita','Tiada Masalah',7100,'🌸'),

  ('Sistem kencing & saluran urinari','Kerap kencing',8010,'🚰'),
  ('Sistem kencing & saluran urinari','Kerap bangun malam untuk kencing',8020,'🚰'),
  ('Sistem kencing & saluran urinari','Sukar kencing',8030,'🚰'),
  ('Sistem kencing & saluran urinari','Kencing tidak lawas',8040,'🚰'),
  ('Sistem kencing & saluran urinari','Kencing berbuih',8050,'🚰'),
  ('Sistem kencing & saluran urinari','Kencing berpasir',8060,'🚰'),
  ('Sistem kencing & saluran urinari','Keluar ketulan seperti batu ketika kencing',8070,'🚰'),
  ('Sistem kencing & saluran urinari','Pedih atau sakit ketika kencing',8080,'🚰'),
  ('Sistem kencing & saluran urinari','Kencing berdarah',8090,'🚰'),
  ('Sistem kencing & saluran urinari','Air kencing keruh',8100,'🚰'),
  ('Sistem kencing & saluran urinari','Air kencing berbau kuat',8110,'🚰'),
  ('Sistem kencing & saluran urinari','Kencing sedikit daripada biasa',8120,'🚰'),
  ('Sistem kencing & saluran urinari','Tidak boleh kencing',8130,'🚰'),
  ('Sistem kencing & saluran urinari','Tidak dapat menahan kencing',8140,'🚰'),
  ('Sistem kencing & saluran urinari','Sakit di bahagian tepi pinggang',8150,'🚰'),
  ('Sistem kencing & saluran urinari','Tiada masalah',8160,'🚰')
) AS t(kumpulan, label, urutan, ikon)
WHERE NOT EXISTS (
  SELECT 1 FROM psy_reaksi_item i WHERE i.kumpulan = t.kumpulan AND i.label = t.label
);

-- Selaraskan urutan + ikon semua item (sedia ada + baharu) ikut susunan jadual reference
UPDATE psy_reaksi_item i SET urutan = t.urutan, ikon = t.ikon
FROM (VALUES
  ('Pencernaan','Perut Kembung',10,'🍽️'),
  ('Pencernaan','Banyak angin (kentut)',20,'🍽️'),
  ('Pencernaan','Kerap sendawa',30,'🍽️'),
  ('Pencernaan','Sakit perut',40,'🍽️'),
  ('Pencernaan','Sakit bahagian kanan atas perut',50,'🍽️'),
  ('Pencernaan','Batu hempedu',60,'🍽️'),
  ('Pencernaan','Hilang selera makan',70,'🍽️'),
  ('Pencernaan','Kerap buang air besar',80,'🍽️'),
  ('Pencernaan','Loya',90,'🍽️'),
  ('Pencernaan','Muntah',100,'🍽️'),
  ('Pencernaan','Sembelit',110,'🍽️'),
  ('Pencernaan','Cirit birit',120,'🍽️'),
  ('Pencernaan','Najis hitam',130,'🍽️'),
  ('Pencernaan','Najis Berdarah',140,'🍽️'),
  ('Pencernaan','Buasir semakin pulih',150,'🍽️'),
  ('Pencernaan','Lendir keluar bersama najis',160,'🍽️'),
  ('Pencernaan','Pedih ulu hati',170,'🍽️'),
  ('Pencernaan','Buasir',180,'🍽️'),
  ('Pencernaan','Tiada masalah',190,'🍽️'),

  ('Jantung & Peredaran darah','Tekanan darah tinggi',1010,'❤️'),
  ('Jantung & Peredaran darah','Tekanan darah rendah',1020,'❤️'),
  ('Jantung & Peredaran darah','Jantung berdebar-debar',1030,'❤️'),
  ('Jantung & Peredaran darah','Sakit dada',1040,'❤️'),
  ('Jantung & Peredaran darah','Pening/hampir pengsan',1050,'❤️'),
  ('Jantung & Peredaran darah','Pengsan',1060,'❤️'),
  ('Jantung & Peredaran darah','Denyutan jantung tidak teratur',1070,'❤️'),
  ('Jantung & Peredaran darah','Tiada Masalah',1080,'❤️'),

  ('Otot, sendi & saraf','Sakit badan',2010,'💪'),
  ('Otot, sendi & saraf','Sakit sendi',2020,'💪'),
  ('Otot, sendi & saraf','Sakit otot',2030,'💪'),
  ('Otot, sendi & saraf','Sakit belikat',2040,'💪'),
  ('Otot, sendi & saraf','Sakit tengkuk',2050,'💪'),
  ('Otot, sendi & saraf','Sakit pinggang',2060,'💪'),
  ('Otot, sendi & saraf','Sakit belakang',2070,'💪'),
  ('Otot, sendi & saraf','Kejang otot',2080,'💪'),
  ('Otot, sendi & saraf','Kebas',2090,'💪'),
  ('Otot, sendi & saraf','Sakit lutut',2100,'💪'),
  ('Otot, sendi & saraf','Sakit bahu',2110,'💪'),
  ('Otot, sendi & saraf','Rasa mencucuk-cucuk',2120,'💪'),
  ('Otot, sendi & saraf','Lemah anggota badan',2130,'💪'),
  ('Otot, sendi & saraf','Tiada Masalah',2140,'💪'),

  ('Kulit & Perubahan badan','Gatal-gatal',3010,'🧴'),
  ('Kulit & Perubahan badan','Jerawat muncul',3020,'🧴'),
  ('Kulit & Perubahan badan','Ruam muncul',3030,'🧴'),
  ('Kulit & Perubahan badan','Kulit mengelupas',3040,'🧴'),
  ('Kulit & Perubahan badan','Kulit menjadi lebih sensitif',3050,'🧴'),
  ('Kulit & Perubahan badan','Kulit kemerahan',3060,'🧴'),
  ('Kulit & Perubahan badan','Kulit kering',3070,'🧴'),
  ('Kulit & Perubahan badan','Badan terasa panas',3080,'🧴'),
  ('Kulit & Perubahan badan','Badan terasa sejuk',3090,'🧴'),
  ('Kulit & Perubahan badan','Tiada Masalah',3100,'🧴'),

  ('Emosi, tidur & tenaga','Susah tidur',4010,'⚡'),
  ('Emosi, tidur & tenaga','Mengantuk luar biasa',4020,'⚡'),
  ('Emosi, tidur & tenaga','Cepat letih',4030,'⚡'),
  ('Emosi, tidur & tenaga','Lemah badan',4040,'⚡'),
  ('Emosi, tidur & tenaga','Mudah sebak/menangis',4050,'⚡'),
  ('Emosi, tidur & tenaga','Gelisah',4060,'⚡'),
  ('Emosi, tidur & tenaga','Badan terasa berat',4070,'⚡'),
  ('Emosi, tidur & tenaga','Mudah marah',4080,'⚡'),
  ('Emosi, tidur & tenaga','Sukar fokus',4090,'⚡'),
  ('Emosi, tidur & tenaga','Tidur lebih baik',4100,'⚡'),
  ('Emosi, tidur & tenaga','Tenaga bertambah baik',4110,'⚡'),
  ('Emosi, tidur & tenaga','Emosi lebih stabil',4120,'⚡'),
  ('Emosi, tidur & tenaga','Tiada masalah',4130,'⚡'),

  ('Sistem pernafasan','Hidung berair/banyak hingus',5010,'🫁'),
  ('Sistem pernafasan','Hidung tersumbat',5020,'🫁'),
  ('Sistem pernafasan','Batuk',5030,'🫁'),
  ('Sistem pernafasan','Batuk berkahak',5040,'🫁'),
  ('Sistem pernafasan','Batuk berdarah',5050,'🫁'),
  ('Sistem pernafasan','Sesak nafas',5060,'🫁'),
  ('Sistem pernafasan','Semput/nafas berbunyi',5070,'🫁'),
  ('Sistem pernafasan','Tercungap-cungap',5080,'🫁'),
  ('Sistem pernafasan','Tiada masalah',5090,'🫁'),

  ('Bengkak & perubahan cecair','Bengkak kaki',6010,'💧'),
  ('Bengkak & perubahan cecair','Bengkak tangan',6020,'💧'),
  ('Bengkak & perubahan cecair','Bengkak muka',6030,'💧'),
  ('Bengkak & perubahan cecair','Bengkak sekitar mata',6040,'💧'),
  ('Bengkak & perubahan cecair','Perut membengkak',6050,'💧'),
  ('Bengkak & perubahan cecair','Kawasan badan merah, panas atau bengkak',6060,'💧'),
  ('Bengkak & perubahan cecair','Bengkak semakin berkurang',6070,'💧'),
  ('Bengkak & perubahan cecair','Tiada masalah',6080,'💧'),

  ('Kesihatan wanita','Keputihan',7010,'🌸'),
  ('Kesihatan wanita','Haid lewat datang',7020,'🌸'),
  ('Kesihatan wanita','Haid lebih lama dari biasa',7030,'🌸'),
  ('Kesihatan wanita','Keluar ketulan darah ketika haid',7040,'🌸'),
  ('Kesihatan wanita','Keluar cecair dari puting payudara',7050,'🌸'),
  ('Kesihatan wanita','Keluar darah dari puting payudara',7060,'🌸'),
  ('Kesihatan wanita','Senggugut',7070,'🌸'),
  ('Kesihatan wanita','Pendarahan selepas menopaus',7080,'🌸'),
  ('Kesihatan wanita','Darah haid terlalu banyak',7090,'🌸'),
  ('Kesihatan wanita','Tiada Masalah',7100,'🌸'),

  ('Sistem kencing & saluran urinari','Kerap kencing',8010,'🚰'),
  ('Sistem kencing & saluran urinari','Kerap bangun malam untuk kencing',8020,'🚰'),
  ('Sistem kencing & saluran urinari','Sukar kencing',8030,'🚰'),
  ('Sistem kencing & saluran urinari','Kencing tidak lawas',8040,'🚰'),
  ('Sistem kencing & saluran urinari','Kencing berbuih',8050,'🚰'),
  ('Sistem kencing & saluran urinari','Kencing berpasir',8060,'🚰'),
  ('Sistem kencing & saluran urinari','Keluar ketulan seperti batu ketika kencing',8070,'🚰'),
  ('Sistem kencing & saluran urinari','Pedih atau sakit ketika kencing',8080,'🚰'),
  ('Sistem kencing & saluran urinari','Kencing berdarah',8090,'🚰'),
  ('Sistem kencing & saluran urinari','Air kencing keruh',8100,'🚰'),
  ('Sistem kencing & saluran urinari','Air kencing berbau kuat',8110,'🚰'),
  ('Sistem kencing & saluran urinari','Kencing sedikit daripada biasa',8120,'🚰'),
  ('Sistem kencing & saluran urinari','Tidak boleh kencing',8130,'🚰'),
  ('Sistem kencing & saluran urinari','Tidak dapat menahan kencing',8140,'🚰'),
  ('Sistem kencing & saluran urinari','Sakit di bahagian tepi pinggang',8150,'🚰'),
  ('Sistem kencing & saluran urinari','Tiada masalah',8160,'🚰')
) AS t(kumpulan, label, urutan, ikon)
WHERE i.kumpulan = t.kumpulan AND i.label = t.label;

-- ──── FASA E: Selaras psy_reaksi_kategori (nama kumpulan + kumpulan baharu) ────
UPDATE psy_reaksi_kategori SET nama='Jantung & Peredaran darah' WHERE nama='Jantung';
UPDATE psy_reaksi_kategori SET nama='Otot, sendi & saraf' WHERE nama='Otot & Saraf';
UPDATE psy_reaksi_kategori SET nama='Kulit & Perubahan badan', ikon='🧴' WHERE nama='Detoksifikasi';
UPDATE psy_reaksi_kategori SET nama='Emosi, tidur & tenaga' WHERE nama='Emosi & Tenaga';
UPDATE psy_reaksi_kategori SET nama='Sistem pernafasan' WHERE nama='Pernafasan';
UPDATE psy_reaksi_kategori SET nama='Bengkak & perubahan cecair' WHERE nama='Bengkak & Cecair';
UPDATE psy_reaksi_kategori SET nama='Kesihatan wanita' WHERE nama='Wanita';

INSERT INTO psy_reaksi_kategori (nama, ikon, urutan)
SELECT 'Sistem kencing & saluran urinari', '🚰', 950
WHERE NOT EXISTS (SELECT 1 FROM psy_reaksi_kategori WHERE nama='Sistem kencing & saluran urinari');

-- Kategori yang mungkin belum ada langsung (DB lama belum pernah run seed psy_reaksi_kategori
-- penuh) — jana dari kumpulan psy_reaksi_item terkini sebagai jaring keselamatan.
INSERT INTO psy_reaksi_kategori (nama, ikon, urutan)
SELECT kumpulan, MAX(COALESCE(ikon, '')), MIN(COALESCE(urutan, 100))
FROM psy_reaksi_item GROUP BY kumpulan
ON CONFLICT (nama) DO NOTHING;

-- ════════════════════════════════════════════════════════════════
-- FASA F (20 Okt 2026, susulan) — "Biasa/Teruk wajib ada dekat semua jawapan"
-- (arahan management). Togol "Benarkan pesakit tanda Biasa/Teruk" dibuang drpd
-- borang reaksi-item.html (staff tak boleh matikan lagi); CHECK di DB kunci
-- supaya tiada laluan lain (import/SQL terus) boleh set false pada masa depan.
-- Guard ni perlu utk jadual sedia ada (CREATE TABLE IF NOT EXISTS di atas tak
-- tambah constraint baharu pada jadual yang dah wujud).
-- ════════════════════════════════════════════════════════════════
UPDATE psy_reaksi_item SET boleh_pilih_teruk = true WHERE boleh_pilih_teruk IS DISTINCT FROM true;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_reaksi_item_pilih_teruk_wajib') THEN
    ALTER TABLE psy_reaksi_item ADD CONSTRAINT chk_reaksi_item_pilih_teruk_wajib CHECK (boleh_pilih_teruk = true);
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
  -- Audit management batch 3 (25 Sept 2026), Tier 7 — link ke minggu rawatan,
  -- audience staf/peranan, dan jadual terbit yang benar-benar dikuatkuasa
  -- (bukan kosmetik). Rujuk 20260925_library_workflow_week_audience.sql.
  week_number     INT,
  staff_roles     TEXT[],
  publish_at      TIMESTAMPTZ,
  -- Audit management batch — item 139, Tier Library Content: staf pilih sendiri
  -- "Kandungan Berkaitan" (bukan setakat cadangan automatik ikut topik).
  -- Rujuk 20261007_library_related_items.sql.
  related_item_ids UUID[] DEFAULT '{}',
  created_at      TIMESTAMPTZ DEFAULT now(),
  updated_at      TIMESTAMPTZ DEFAULT now()
);

-- Patch jadual sedia ada — CREATE TABLE IF NOT EXISTS di atas tak tambah
-- kolum baharu pada jadual yang dah wujud, jadi kolum lanjutan mesti di-ALTER
-- secara eksplisit (sama corak dgn 14_products_inventory.sql dll).
ALTER TABLE psy_library_items ADD COLUMN IF NOT EXISTS week_number INT;
ALTER TABLE psy_library_items ADD COLUMN IF NOT EXISTS staff_roles TEXT[];
ALTER TABLE psy_library_items ADD COLUMN IF NOT EXISTS publish_at TIMESTAMPTZ;
ALTER TABLE psy_library_items ADD COLUMN IF NOT EXISTS related_item_ids UUID[] DEFAULT '{}';

CREATE INDEX IF NOT EXISTS idx_library_package_ids ON psy_library_items USING GIN (package_ids);
CREATE INDEX IF NOT EXISTS idx_library_media_type  ON psy_library_items(media_type);
CREATE INDEX IF NOT EXISTS idx_library_topic       ON psy_library_items(topic);
CREATE INDEX IF NOT EXISTS idx_library_tags        ON psy_library_items USING GIN (tags);
CREATE INDEX IF NOT EXISTS idx_library_related     ON psy_library_items USING GIN (related_item_ids);

ALTER TABLE psy_library_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone read library" ON psy_library_items;
DROP POLICY IF EXISTS "Patients read allowed library" ON psy_library_items;
CREATE POLICY "Patients read allowed library" ON psy_library_items FOR SELECT
  TO authenticated
  USING (
    is_active = true
    AND (staff_roles IS NULL OR array_length(staff_roles, 1) IS NULL)
    AND (publish_at IS NULL OR publish_at <= now())
    AND (
      package_ids IS NULL OR array_length(package_ids, 1) IS NULL
      OR EXISTS (
        SELECT 1 FROM psy_patients p
        LEFT JOIN psy_packages pk
          ON pk.id::text = p.active_package_id OR pk.package_id = p.active_package_id
        WHERE p.user_id = auth.uid()
          AND (p.active_package_id = ANY(package_ids) OR pk.package_id = ANY(package_ids))
      )
    )
  );

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
  'draft | review | approved | published | archived. is_active = (status=published). Pesakit nampak published sahaja.';
COMMENT ON COLUMN psy_library_items.week_number IS
  'Minggu rawatan (dalam pakej yg dipilih di package_ids) kandungan ni relevan. NULL = semua minggu.';
COMMENT ON COLUMN psy_library_items.staff_roles IS
  'Kalau diisi, kandungan ni RUJUKAN STAF sahaja (bukan pesakit) — hanya staff dgn salah satu peranan ni nampak. NULL/kosong = kandungan pesakit biasa.';
COMMENT ON COLUMN psy_library_items.publish_at IS
  'Kalau diisi & di masa depan, kandungan tak nampak kpd pesakit walau status=published/is_active=true sehingga masa ni sampai (dikuatkuasa di RLS).';
COMMENT ON COLUMN psy_library_items.related_item_ids IS
  'Senarai id (psy_library_items.id) kandungan lain yang staf PILIH SENDIRI sebagai "Kandungan Berkaitan", ikut urutan staf pilih. Kosong/NULL = patient-side fallback ke cadangan automatik ikut topik sama (lihat loadRelated() di library-detail.html).';

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
  shopee_url           TEXT,   -- pautan Shopee untuk beli produk ini
  category             TEXT NOT NULL DEFAULT 'Bekalan Coaching',
  unit                 TEXT NOT NULL DEFAULT 'Unit'
                       CHECK (unit IN ('Pcs','Botol','Kotak','Pek','Tiub','Tablet',
                                       'Kapsul','Set','Gulung','Beg','Pasang','Unit','Gram','Kg','Naskhah','Gelas',
                                       'Liter (L)','Mililiter (ml)','Inci (inch)','Sentimeter (cm)','Milimeter (mm)')),
  -- issue_unit/issue_units_per_stock_unit: bagi item yg dibeli dlm unit besar tapi
  -- diguna pesakit dlm unit kecil (cth: beli 1 Gulung tape = 30 Inci, pesakit
  -- guna 1 Inci setiap kali). NULL = tiada tukaran, bagi pesakit kena guna unit sama
  -- macam stok. Lihat shared/inventoryStock.js & roles/staff/patient-hub.html submitSupply().
  issue_unit           TEXT
                       CHECK (issue_unit IS NULL OR issue_unit IN ('Pcs','Botol','Kotak','Pek','Tiub','Tablet',
                                       'Kapsul','Set','Gulung','Beg','Pasang','Unit','Gram','Kg','Naskhah','Gelas',
                                       'Liter (L)','Mililiter (ml)','Inci (inch)','Sentimeter (cm)','Milimeter (mm)')),
  issue_units_per_stock_unit NUMERIC(10,4),
  qty_in_stock         NUMERIC(12,4) NOT NULL DEFAULT 0,
  min_qty              NUMERIC(10,2) NOT NULL DEFAULT 5,
  requires_approval    BOOLEAN NOT NULL DEFAULT false,
  notes                TEXT,
  max_qty              NUMERIC(10,2),
  auto_reorder_qty     NUMERIC(10,2),
  last_auto_po_at      TIMESTAMPTZ,
  consumption_type     TEXT DEFAULT 'package'
                       CHECK (consumption_type IN ('package','service','general')),
  supplier_info        JSONB DEFAULT '{}'::jsonb,
  source_type          TEXT NOT NULL DEFAULT 'am'
                       CHECK (source_type IN ('farmasi_klinikal','am')),
  batch_no             TEXT,
  expiry_date          DATE,
  item_code            TEXT UNIQUE,
  is_active            BOOLEAN NOT NULL DEFAULT true,
  status               TEXT NOT NULL DEFAULT 'active'
                       CHECK (status IN ('active','inactive','discontinued')),
  reorder_threshold_pct NUMERIC(5,2),
  manufacturer         TEXT,
  registration_no      TEXT,
  storage_location     TEXT,
  storage_condition    TEXT,
  barcode              TEXT,
  shelf_life_days      INT,
  image_url            TEXT,
  internal_notes       TEXT,
  created_at           TIMESTAMPTZ DEFAULT now(),
  updated_at           TIMESTAMPTZ DEFAULT now()
);

-- Kolum ditambah selepas jadual asal wujud (patch untuk install sedia ada)
ALTER TABLE psy_inventory_items ADD COLUMN IF NOT EXISTS source_type TEXT NOT NULL DEFAULT 'am'
  CHECK (source_type IN ('farmasi_klinikal','am'));
ALTER TABLE psy_inventory_items ADD COLUMN IF NOT EXISTS batch_no TEXT;
ALTER TABLE psy_inventory_items ADD COLUMN IF NOT EXISTS expiry_date DATE;
ALTER TABLE psy_inventory_items ADD COLUMN IF NOT EXISTS item_code TEXT UNIQUE;
ALTER TABLE psy_inventory_items ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT true;
ALTER TABLE psy_inventory_items ADD COLUMN IF NOT EXISTS reorder_threshold_pct NUMERIC(5,2);
ALTER TABLE psy_inventory_items ADD COLUMN IF NOT EXISTS manufacturer TEXT;
ALTER TABLE psy_inventory_items ADD COLUMN IF NOT EXISTS registration_no TEXT;
ALTER TABLE psy_inventory_items ADD COLUMN IF NOT EXISTS storage_location TEXT;
ALTER TABLE psy_inventory_items ADD COLUMN IF NOT EXISTS storage_condition TEXT;
ALTER TABLE psy_inventory_items ADD COLUMN IF NOT EXISTS barcode TEXT;
ALTER TABLE psy_inventory_items ADD COLUMN IF NOT EXISTS shelf_life_days INT;
ALTER TABLE psy_inventory_items ADD COLUMN IF NOT EXISTS image_url TEXT;
ALTER TABLE psy_inventory_items ADD COLUMN IF NOT EXISTS internal_notes TEXT;
-- Fail print-ready (PDF) item ni — cth reka bentuk Brochure BNP. Staff buka
-- inventory-detail.html item ni terus untuk cetak semula bila nak restock,
-- bukan cari dalam senarai dokumen berasingan. Bucket: inventory-print-files.
ALTER TABLE psy_inventory_items ADD COLUMN IF NOT EXISTS print_file_url TEXT;
ALTER TABLE psy_inventory_items ADD COLUMN IF NOT EXISTS print_file_size BIGINT;

-- 29 Okt 2026 — unit tukaran (issue_unit) supaya item boleh dibeli dlm unit besar
-- (cth Gulung) tapi diberi pesakit dlm unit kecil (cth Inci) tanpa tolak 1 Gulung
-- penuh setiap kali. qty_in_stock dilebarkan ke 4dp (asal 2dp) sebab deduct pecahan
-- (cth 1/30 Gulung = 0.0333) akan terkumpul ralat bundaran ketara kalau cuma 2dp.
-- Susunan penting: DROP constraint lama + UPDATE row sedia ada WAJIB sebelum
-- ADD constraint baharu (lagi ketat, tiada 'Biji (pcs)'/'Paket') — kalau tak,
-- ADD akan gagal sbb row sedia ada guna nilai yg dah dibuang.
ALTER TABLE psy_inventory_items DROP CONSTRAINT IF EXISTS psy_inventory_items_unit_check;
ALTER TABLE psy_inventory_items DROP CONSTRAINT IF EXISTS psy_inventory_items_issue_unit_check;
ALTER TABLE psy_inventory_items ADD COLUMN IF NOT EXISTS issue_unit TEXT;
ALTER TABLE psy_inventory_items ADD COLUMN IF NOT EXISTS issue_units_per_stock_unit NUMERIC(10,4);
ALTER TABLE psy_inventory_items ALTER COLUMN qty_in_stock TYPE NUMERIC(12,4);
-- NOTA: psy_inventory_stock_by_location.qty_in_stock & psy_stock_movements.qty/balance_after
-- turut dilebarkan ke NUMERIC(12,4) — lihat ALTER COLUMN TYPE di 34_inventory_locations.sql
-- & 36_stock_movements.sql (jadual tu ditakrif SELEPAS fail ni, jadi ALTER kena di sana).
UPDATE psy_inventory_items SET unit = 'Pcs' WHERE unit = 'Biji (pcs)';
UPDATE psy_inventory_items SET issue_unit = 'Pcs' WHERE issue_unit = 'Biji (pcs)';
ALTER TABLE psy_inventory_items ADD CONSTRAINT psy_inventory_items_unit_check
  CHECK (unit IN ('Pcs','Botol','Kotak','Pek','Tiub','Tablet',
                   'Kapsul','Set','Gulung','Beg','Pasang','Unit','Gram','Kg','Naskhah','Gelas',
                   'Liter (L)','Mililiter (ml)','Inci (inch)','Sentimeter (cm)','Milimeter (mm)'));
ALTER TABLE psy_inventory_items ADD CONSTRAINT psy_inventory_items_issue_unit_check
  CHECK (issue_unit IS NULL OR issue_unit IN ('Pcs','Botol','Kotak','Pek','Tiub','Tablet',
                   'Kapsul','Set','Gulung','Beg','Pasang','Unit','Gram','Kg','Naskhah','Gelas',
                   'Liter (L)','Mililiter (ml)','Inci (inch)','Sentimeter (cm)','Milimeter (mm)'));
COMMENT ON COLUMN psy_inventory_items.issue_unit IS
  'Unit diberi kepada pesakit, jika berbeza drpd unit stok (cth stok=Gulung, issue_unit=Inci). NULL = tiada tukaran.';
COMMENT ON COLUMN psy_inventory_items.issue_units_per_stock_unit IS
  'Berapa issue_unit dalam 1 unit stok (cth 30 = 1 Gulung ada 30 Inci). Guna utk tukar kuantiti diberi pesakit kpd pecahan unit stok semasa tolak.';

-- status: peringkat lebih halus drpd is_active — 'discontinued' bermaksud dibuang
-- kekal (bukan cuma nyahaktif sementara). is_active DIKEKALKAN (banyak tempat lain
-- guna .eq('is_active', true) utk senarai produk boleh-pilih) — status='inactive'
-- ATAU 'discontinued' kedua-duanya set is_active=false, cuma UI Products list boleh
-- bezakan sebab & papar label yang betul.
ALTER TABLE psy_inventory_items ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'active'
  CHECK (status IN ('active','inactive','discontinued'));
UPDATE psy_inventory_items SET status = CASE WHEN is_active = false THEN 'inactive' ELSE 'active' END
  WHERE status = 'active' AND is_active = false;

-- auto_reorder_enabled dibuang — trigger auto-request tak pernah check flag ni,
-- sistem auto-cipta permintaan beli utk semua item bila stok rendah tanpa syarat.
ALTER TABLE psy_inventory_items DROP COLUMN IF EXISTS auto_reorder_enabled;

CREATE INDEX IF NOT EXISTS idx_inventory_items_source_type ON psy_inventory_items(source_type);
CREATE INDEX IF NOT EXISTS idx_inventory_items_is_active ON psy_inventory_items(is_active);

-- ──── item_code auto-generate (INV-01, INV-02, ... INV-99, INV-100) ────
CREATE SEQUENCE IF NOT EXISTS psy_inventory_item_code_seq START 1;

CREATE OR REPLACE FUNCTION psy_inventory_format_code(n BIGINT)
RETURNS TEXT
LANGUAGE sql IMMUTABLE
AS $$ SELECT 'INV-' || CASE WHEN n < 10 THEN '0' || n::text ELSE n::text END $$;

CREATE OR REPLACE FUNCTION psy_inventory_set_item_code()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.item_code IS NULL THEN
    NEW.item_code := psy_inventory_format_code(nextval('psy_inventory_item_code_seq'));
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_psy_inventory_set_item_code ON psy_inventory_items;
CREATE TRIGGER trg_psy_inventory_set_item_code
BEFORE INSERT ON psy_inventory_items
FOR EACH ROW EXECUTE FUNCTION psy_inventory_set_item_code();

-- Jujukan seterusnya bermula selepas nombor INV tertinggi sedia ada
SELECT setval('psy_inventory_item_code_seq',
  COALESCE((SELECT max(substring(item_code FROM 5)::bigint) FROM psy_inventory_items WHERE item_code ~ '^INV-[0-9]+$'), 0) + 1,
  false);

-- Beri kod kepada item yang belum ada, ikut tarikh dicipta
DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN SELECT id FROM psy_inventory_items WHERE item_code IS NULL ORDER BY created_at, id LOOP
    UPDATE psy_inventory_items
      SET item_code = psy_inventory_format_code(nextval('psy_inventory_item_code_seq'))
      WHERE id = r.id;
  END LOOP;
END $$;

-- RLS
ALTER TABLE psy_inventory_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff read inventory items" ON psy_inventory_items;
CREATE POLICY "Staff read inventory items" ON psy_inventory_items
  FOR SELECT USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "Admin manage inventory items" ON psy_inventory_items;
CREATE POLICY "Admin manage inventory items" ON psy_inventory_items
  FOR ALL USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff' AND staff_role IN ('super_admin','admin','manager')))
  WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff' AND staff_role IN ('super_admin','admin','manager')));

-- Komen
COMMENT ON COLUMN psy_inventory_items.max_qty IS
  'Saiz stok penuh / target. Trigger auto-PO bila qty_in_stock <= 30% dari max_qty.';
COMMENT ON COLUMN psy_inventory_items.auto_reorder_qty IS
  'Kuantiti yang sistem cadang dalam auto-PO. Default: max_qty - qty_in_stock.';
COMMENT ON COLUMN psy_inventory_items.last_auto_po_at IS
  'Tarikh auto-PO terakhir dijana — elak duplikat dalam tempoh pendek.';
COMMENT ON COLUMN psy_inventory_items.consumption_type IS
  'package = bekalan pakej (dynamic auto-calc); service = guna semasa service one-off; general = consumable umum (manual min sahaja).';
COMMENT ON COLUMN psy_inventory_items.supplier_info IS
  'Format: { name, pic_name, phone, email, address, payment_terms, cost_per_unit }. Maklumat pembekal.';
COMMENT ON COLUMN psy_inventory_items.item_code IS
  'Kod item auto-generate (INV-01, ...) via trigger — tidak boleh diedit.';
COMMENT ON COLUMN psy_inventory_items.is_active IS
  'false = item tidak aktif — disorok dari senarai pilihan (dispens/kit/jadual pakej) & auto-request.';
COMMENT ON COLUMN psy_inventory_items.print_file_url IS
  'Fail PDF print-ready (cth reka bentuk brochure) — dicetak terus dari inventory-detail.html bila restock.';
COMMENT ON COLUMN psy_inventory_items.reorder_threshold_pct IS
  'Peratus keperluan bulanan (dynamic_monthly) yang trigger status "Stok Rendah" utk item source_type=package. NULL = guna default sistem 30%.';
COMMENT ON COLUMN psy_inventory_items.manufacturer IS
  'Pengilang produk. Relevan utk source_type=farmasi_klinikal.';
COMMENT ON COLUMN psy_inventory_items.registration_no IS
  'No. pendaftaran/produk (cth MAL number). Relevan utk source_type=farmasi_klinikal.';
COMMENT ON COLUMN psy_inventory_items.storage_location IS
  'Lokasi simpanan fizikal (cth: Bilik Farmasi Rak 2). Relevan utk source_type=farmasi_klinikal.';
COMMENT ON COLUMN psy_inventory_items.storage_condition IS
  'Syarat simpanan (cth: Sejuk 2-8°C, Elak Cahaya). Relevan utk source_type=farmasi_klinikal.';
COMMENT ON COLUMN psy_inventory_items.source_type IS
  'farmasi_klinikal = ubat/bekalan perubatan (perlu batch_no/expiry_date, dispensing direkod di psy_supply_disbursements); am = inventori am/coaching/marketing. Default am.';
COMMENT ON COLUMN psy_inventory_items.batch_no IS
  'No. batch pembekal. Relevan hanya untuk item source_type=farmasi_klinikal.';
COMMENT ON COLUMN psy_inventory_items.expiry_date IS
  'Tarikh luput batch semasa. Relevan hanya untuk item source_type=farmasi_klinikal.';

-- ──── psy_inventory_requests ────
-- Header sahaja (banyak produk setiap permohonan — lihat psy_inventory_request_items).
-- Sebelum ni 1 request = 1 item (item_id/item_name/qty_requested/unit_price terus di
-- header); ditukar jadi multi-item macam psy_purchase_orders supaya konsisten.
CREATE TABLE IF NOT EXISTS psy_inventory_requests (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  request_no        TEXT UNIQUE,
  reason            TEXT,
  priority          TEXT NOT NULL DEFAULT 'sederhana'
                    CHECK (priority IN ('tinggi','sederhana','rendah')),
  status            TEXT NOT NULL DEFAULT 'pending_approval'
                    CHECK (status IN ('pending_approval','approved','partially_received','rejected','purchased')),
  subtotal          NUMERIC(12,2) NOT NULL DEFAULT 0,
  tax_amount        NUMERIC(12,2) NOT NULL DEFAULT 0,
  total_amount      NUMERIC(12,2) NOT NULL DEFAULT 0,
  requested_by      UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  requested_by_name TEXT NOT NULL DEFAULT '',
  requested_by_staff_code TEXT,
  approved_by       UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  approved_at       TIMESTAMPTZ,
  rejected_reason   TEXT,
  purchased_at      TIMESTAMPTZ,
  is_auto_generated BOOLEAN DEFAULT false,
  created_at        TIMESTAMPTZ DEFAULT now(),
  updated_at        TIMESTAMPTZ DEFAULT now()
);

-- ──── Line items (satu permohonan boleh ada banyak produk) ────
CREATE TABLE IF NOT EXISTS psy_inventory_request_items (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id     UUID NOT NULL REFERENCES psy_inventory_requests(id) ON DELETE CASCADE,
  item_id        UUID REFERENCES psy_inventory_items(id) ON DELETE SET NULL,
  item_name      TEXT NOT NULL,
  qty_requested  NUMERIC(10,2) NOT NULL,
  -- Kumulatif kuantiti item ni yang dah sampai (merentas berbilang Stock In jika
  -- supplier hantar berperingkat). Baki belum sampai = qty_requested - qty_received.
  qty_received   NUMERIC(10,2) NOT NULL DEFAULT 0,
  unit_price     NUMERIC(10,2) NOT NULL DEFAULT 0,
  subtotal       NUMERIC(12,2) NOT NULL DEFAULT 0,
  created_at     TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_inv_request_items_request ON psy_inventory_request_items(request_id);

-- ──── Dokumen lampiran (invois/resit pembelian) — boleh ditambah masa cipta
-- permohonan atau lepas tu (lazimnya invois/resit hanya ada lepas beli).
CREATE TABLE IF NOT EXISTS psy_inventory_request_attachments (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id        UUID NOT NULL REFERENCES psy_inventory_requests(id) ON DELETE CASCADE,
  file_name         TEXT NOT NULL,
  file_path         TEXT NOT NULL,
  file_size         BIGINT,
  file_type         TEXT,
  uploaded_by       UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  uploaded_by_name  TEXT,
  created_at        TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_inv_request_attachments_request ON psy_inventory_request_attachments(request_id);

-- ──── request_no auto-generate (PR-00001, PR-00002, ...) ────
CREATE SEQUENCE IF NOT EXISTS psy_inventory_request_no_seq START 1;

CREATE OR REPLACE FUNCTION psy_inventory_set_request_no()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.request_no IS NULL THEN
    NEW.request_no := 'PR-' || LPAD(nextval('psy_inventory_request_no_seq')::text, 5, '0');
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_psy_inventory_set_request_no ON psy_inventory_requests;
CREATE TRIGGER trg_psy_inventory_set_request_no
BEFORE INSERT ON psy_inventory_requests
FOR EACH ROW EXECUTE FUNCTION psy_inventory_set_request_no();

-- Backfill request_no utk baris sedia ada (install lama) — susun ikut created_at.
DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN SELECT id FROM psy_inventory_requests WHERE request_no IS NULL ORDER BY created_at LOOP
    UPDATE psy_inventory_requests
      SET request_no = 'PR-' || LPAD(nextval('psy_inventory_request_no_seq')::text, 5, '0')
      WHERE id = r.id;
  END LOOP;
END $$;

COMMENT ON COLUMN psy_inventory_requests.request_no IS
  'Nombor rujukan permohonan auto-generate (PR-00001, ...) via trigger — tidak boleh diedit.';
COMMENT ON COLUMN psy_inventory_requests.priority IS
  'Keutamaan pembelian: tinggi/sederhana/rendah. Default sederhana — staff boleh naikkan bila mendesak.';

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

ALTER TABLE psy_inventory_request_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff manage request items" ON psy_inventory_request_items;
CREATE POLICY "Staff manage request items" ON psy_inventory_request_items FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

ALTER TABLE psy_inventory_request_attachments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff manage request attachments" ON psy_inventory_request_attachments;
CREATE POLICY "Staff manage request attachments" ON psy_inventory_request_attachments FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

COMMENT ON COLUMN psy_inventory_requests.is_auto_generated IS
  'true = dijana automatik oleh checkAutoPO() (shared/inventoryForecast.js), false = manual request oleh staff.';

-- Auto-request bila stok rendah dikendalikan client-side (checkAutoPO() di inventory.html,
-- guna shared/inventoryForecast.js) — BUKAN trigger DB. Trigger lama psy_inventory_auto_request()
-- dibuang (lihat supabase/migrations/20260829_drop_inventory_auto_po_trigger.sql) sebab guna
-- medan `max_qty` yang tak pernah diisi di mana-mana borang (sentiasa NULL), jadi ia sentiasa
-- fallback ke min_qty untuk SEMUA item — tak selaras & duplicate logik dgn client-side.

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
  unit               TEXT DEFAULT 'Unit'
                     CHECK (unit IN ('Pcs','Botol','Kotak','Pek','Tiub','Tablet',
                                     'Kapsul','Set','Gulung','Beg','Pasang','Unit','Gram','Kg','Naskhah','Gelas')),
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

-- Baca sahaja utk pesakit (audit #144c) — roles/patient/plan-week.html perlu padan nama
-- item Bekalan dgn kit prosedur utk auto-collapse paparan "🧰 Nama Prosedur (N item)".
-- Data tak sensitif (nama kit + nama item generik), ikut corak baca-terbuka sedia ada
-- (cth psy_library_categories/psy_faq_items FOR SELECT USING (true)).
DROP POLICY IF EXISTS "Read active procedure kits" ON psy_procedure_kits;
CREATE POLICY "Read active procedure kits" ON psy_procedure_kits FOR SELECT
  USING (is_active = true);

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

-- ──── Seed: item inventori lalai ISW (IDEMPOTEN — insert HANYA kalau nama belum
-- wujud, TAK PERNAH padam baris sedia ada). SEBELUM NI fail ni ada "DELETE FROM
-- psy_inventory_items;" tanpa skop di atas INSERT — setiap kali schema/migration
-- ni di-run, SEMUA item sebenar (stok+ID) dipadam & diganti BARIS INI SAHAJA dgn
-- UUID RAWAK baharu. psy_inventory_items.id dirujuk sbg snapshot di BANYAK tempat
-- (coaching_schedule pakej, psy_stock_movements, psy_supply_invoices, kob_default_
-- supplies) — padam+insert semula = SEMUA rujukan tu jadi yatim SENYAP (tiada
-- error, cuma potong stok/invois bekalan senyap tak pernah berfungsi). Insiden ni
-- disahkan punca 100% rujukan item_id pakej jadi yatim (20 Okt 2026) — lihat
-- [[project_inventory_seed_destructive_delete]]. JANGAN tambah DELETE FROM balik
-- kat sini.
INSERT INTO psy_inventory_items (name, category, unit, qty_in_stock, min_qty, requires_approval, notes)
SELECT v.name, v.category, v.unit, v.qty_in_stock, v.min_qty, v.requires_approval, v.notes
FROM (VALUES

-- ── MADU & PRODUK ─────────────────────────────────────────
('Lebah Thoharah (LTH)',            'Madu & Produk', 'Kg',     0, 5,  false, 'Program NLC / JS / JS+ / EOL'),
('LTH Plus Green (LTHPG)',          'Madu & Produk', 'Kg',     0, 5,  false, 'Program NLC / JS / JS+ / EOL'),
('Ibu Bumi (IB)',                   'Madu & Produk', 'Kg',     0, 5,  false, 'Program OBD / OBP'),
('Young & Healthy Plus Green (YHPG)','Madu & Produk','Kg',     0, 5,  false, 'Program OBD / OBP'),
('Madu Kelulut',                    'Madu & Produk', 'Botol',  0, 3,  false, NULL),
('Minyak Zaitun Tulen',             'Madu & Produk', 'Botol',  0, 3,  false, NULL),

-- ── STARTER KIT ───────────────────────────────────────────
('SDS OB',                          'Starter Kit',   'Unit',   0, 5,  false, 'Starter kit OBD / OBP'),
('GHF',                             'Starter Kit',   'Unit',   0, 5,  false, 'Starter kit OBD / OBP'),
('BNP',                             'Starter Kit',   'Unit',   0, 5,  false, 'Bekalan pantang NLC / JS'),
('NSS',                             'Starter Kit',   'Unit',   0, 5,  false, 'Bekalan pantang NLC / JS'),
('Voucher Konsultasi',              'Starter Kit',   'Unit',   0, 10, false, 'Diedarkan semasa onboarding'),

-- ── SUPLEMEN & RESEPI ─────────────────────────────────────
('Resepi Superimun',                'Suplemen & Resepi', 'Unit', 0, 5, false, 'Diberi semasa onboarding'),
('Resepi Superenergi',              'Suplemen & Resepi', 'Unit', 0, 5, false, 'Diberi semasa onboarding'),
('Barley Organik',                  'Suplemen & Resepi', 'Kg',   0, 5, false, NULL),
('Spirulina',                       'Suplemen & Resepi', 'Botol',0, 3, false, NULL),
('Probiotik Advanced',              'Suplemen & Resepi', 'Botol',0, 3, false, NULL),
('Magnesium Glycinate',             'Suplemen & Resepi', 'Botol',0, 3, false, NULL),
('Vitamin D3',                      'Suplemen & Resepi', 'Botol',0, 3, false, NULL),
('Omega-3 Fish Oil',                'Suplemen & Resepi', 'Botol',0, 3, false, NULL),

-- ── BUKU & BAHAN CETAK ────────────────────────────────────
('Buku P101',                       'Buku & Bahan Cetak', 'Naskhah', 0, 10, false, '7 buku per set starter kit'),
('List Pantang',                    'Buku & Bahan Cetak', 'Naskhah', 0, 10, false, 'Diedarkan semasa onboarding'),
('Peta OB',                         'Buku & Bahan Cetak', 'Naskhah', 0, 10, false, 'Diedarkan semasa onboarding OBD / OBP'),
('Workbook Refleksi Harian',        'Buku & Bahan Cetak', 'Naskhah', 0, 10, false, NULL),
('Jadual Terapi Mingguan',          'Buku & Bahan Cetak', 'Naskhah', 0, 10, false, NULL),
('Mood Tracker',                    'Buku & Bahan Cetak', 'Naskhah', 0, 10, false, NULL),
('Buku Gaya Hidup Fitrah',          'Buku & Bahan Cetak', 'Naskhah', 0,  5, false, NULL),
('Kitab Doa Syifa',                 'Buku & Bahan Cetak', 'Naskhah', 0,  5, false, NULL),

-- ── BROSUR & MARKETING ────────────────────────────────────
('Brochure Madu',                   'Brosur & Marketing', 'Unit', 0, 20, false, NULL),
('Brochure ISW',                    'Brosur & Marketing', 'Unit', 0, 20, false, NULL),
('Brochure OB',                     'Brosur & Marketing', 'Unit', 0, 20, false, NULL),

-- ── BEKALAN COACHING ──────────────────────────────────────
('Air Afiyah',                      'Bekalan Coaching', 'Botol', 0, 10, false, '1 botol = 1.5L'),
('Air Za''afaran',                  'Bekalan Coaching', 'Botol', 0,  5, false, 'Untuk sesi Perubatan Rohani'),
('Herba Kolon',                     'Bekalan Coaching', 'Set',   0,  3, false, '1 set = 1 kursus rawatan'),
('Kurma Ajwa',                      'Bekalan Coaching', 'Pcs',  0, 50, false, '49 biji per pesakit 777 VIP'),

-- ── PERALATAN KLINIK ──────────────────────────────────────
('DNA Test Kit',                    'Peralatan Klinik', 'Set',  0, 2, true,  'Perlu kelulusan · hantar ke lab luar'),
('Enema Kit',                       'Peralatan Klinik', 'Set',  0, 3, true,  'Perlu kelulusan'),
('Mesin Ozon',                      'Peralatan Klinik', 'Unit', 0, 1, true,  'Rekod nombor siri setiap unit'),
('Alcohol Swab',                    'Peralatan Klinik', 'Pek',  0, 10, false, NULL),
('Cotton Ball',                     'Peralatan Klinik', 'Pek',  0, 10, false, NULL),
('Intravenous (IV) Infusion Set',   'Peralatan Klinik', 'Set',  0, 5,  false, NULL),
('Normal Saline (NS)',              'Peralatan Klinik', 'Botol',0, 5,  false, NULL),

-- ── BUKU & BAHAN CETAK (tambahan 20 Okt 2026 — susulan item yatim) ────────
('P101 Jilid 1',                    'Buku & Bahan Cetak', 'Naskhah', 0, 10, false, NULL),
('P101 Jilid 2',                    'Buku & Bahan Cetak', 'Naskhah', 0, 10, false, NULL),
('P101 Jilid 3',                    'Buku & Bahan Cetak', 'Naskhah', 0, 10, false, NULL),
('P101 Jilid 4',                    'Buku & Bahan Cetak', 'Naskhah', 0, 10, false, NULL),
('P101 Jilid 5',                    'Buku & Bahan Cetak', 'Naskhah', 0, 10, false, NULL),
('P101 Jilid 6',                    'Buku & Bahan Cetak', 'Naskhah', 0, 10, false, NULL),
('P101 Jilid 7',                    'Buku & Bahan Cetak', 'Naskhah', 0, 10, false, NULL),
('Biopsychosocial-Spiritual (BPS-S)', 'Buku & Bahan Cetak', 'Naskhah', 0, 10, false, NULL),
('Panduan Peminuman Madu (IB & YHPG)', 'Buku & Bahan Cetak', 'Naskhah', 0, 10, false, NULL),
('Panduan Peminuman Madu (LTH & LTHPG)', 'Buku & Bahan Cetak', 'Naskhah', 0, 10, false, NULL),
('Panduan Pengamalan Zikir Bersanad', 'Buku & Bahan Cetak', 'Naskhah', 0, 10, false, NULL),

-- ── STARTER KIT (tambahan 20 Okt 2026) ────────────────────
('Akses Portal ISW',                'Starter Kit', 'Unit', 0, 10, false, 'Diedarkan semasa onboarding'),
('BNP & NSS Pesakit Gastrik, Gerd, Radang Usus, Sembelit', 'Starter Kit', 'Unit', 0, 5, false, NULL)

) AS v(name, category, unit, qty_in_stock, min_qty, requires_approval, notes)
WHERE NOT EXISTS (SELECT 1 FROM psy_inventory_items existing WHERE existing.name = v.name);

-- ──── Seed: contoh kit prosedur ────
INSERT INTO psy_procedure_kits (name, description, category, items) VALUES
(
  'IV Drip Setup',
  'Set lengkap untuk satu sesi IV Saline Drip',
  'IV Therapy',
  '[
    {"item_id": null, "item_name": "IV Line",       "qty": 1, "unit": "Unit"},
    {"item_id": null, "item_name": "Gloves",         "qty": 2, "unit": "Pasang"},
    {"item_id": null, "item_name": "Alcohol Swab",   "qty": 3, "unit": "Unit"},
    {"item_id": null, "item_name": "Cotton Ball",    "qty": 2, "unit": "Unit"},
    {"item_id": null, "item_name": "Branula",        "qty": 1, "unit": "Unit"},
    {"item_id": null, "item_name": "Plaster",        "qty": 2, "unit": "Unit"},
    {"item_id": null, "item_name": "Scotch Tape",    "qty": 1, "unit": "Unit"}
  ]'::jsonb
),
(
  'Blood Test Setup',
  'Set lengkap untuk pengambilan darah',
  'Diagnostik',
  '[
    {"item_id": null, "item_name": "Gloves",         "qty": 1, "unit": "Pasang"},
    {"item_id": null, "item_name": "Alcohol Swab",   "qty": 2, "unit": "Unit"},
    {"item_id": null, "item_name": "Cotton Ball",    "qty": 2, "unit": "Unit"},
    {"item_id": null, "item_name": "Needle/Vacutainer","qty": 1, "unit": "Unit"},
    {"item_id": null, "item_name": "Plaster",        "qty": 1, "unit": "Unit"},
    {"item_id": null, "item_name": "Blood Tube",     "qty": 3, "unit": "Tiub"}
  ]'::jsonb
),
(
  'DNA Test Setup',
  'Set untuk pengambilan sampel DNA (buccal swab)',
  'Diagnostik',
  '[
    {"item_id": null, "item_name": "Gloves",         "qty": 1, "unit": "Pasang"},
    {"item_id": null, "item_name": "DNA Swab",       "qty": 2, "unit": "Unit"},
    {"item_id": null, "item_name": "DNA Collection Tube", "qty": 1, "unit": "Unit"},
    {"item_id": null, "item_name": "Ziplock Bag",    "qty": 1, "unit": "Unit"}
  ]'::jsonb
)
ON CONFLICT DO NOTHING;

-- ──────────────────────────────────────────────────────────────
-- Pautan silang domain: psy_supply_disbursements (fail 07) → item inventori
-- ──────────────────────────────────────────────────────────────
ALTER TABLE psy_supply_disbursements DROP CONSTRAINT IF EXISTS psy_supply_disbursements_item_id_fkey;
ALTER TABLE psy_supply_disbursements ADD CONSTRAINT psy_supply_disbursements_item_id_fkey
  FOREIGN KEY (item_id) REFERENCES psy_inventory_items(id) ON DELETE SET NULL;

-- ──────────────────────────────────────────────────────────────
-- Shop ↔ Inventori: produk MESTI wujud di Inventori (aktif) baru boleh dijual.
-- Pesakit tak boleh SELECT psy_inventory_items — fungsi SECURITY DEFINER ini dedah status/stok sahaja.
-- (Backfill pautan FK ikut nama: lihat database/add_shop_inventory_link.sql)
-- ──────────────────────────────────────────────────────────────
-- ── 2. Status inventori setiap produk ────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION psy_shop_product_inventory()
RETURNS TABLE (
  product_id    TEXT,
  name          TEXT,
  linked        BOOLEAN,
  item_status   TEXT,
  qty_in_stock  NUMERIC,
  unit          TEXT,
  sellable      BOOLEAN
)
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    p.product_id::text,
    p.name,
    (i.id IS NOT NULL) AS linked,
    CASE WHEN i.id IS NULL THEN NULL
         ELSE COALESCE(to_jsonb(i)->>'status',
                       CASE WHEN to_jsonb(i)->>'is_active' = 'false' THEN 'inactive' ELSE 'active' END) END AS item_status,
    i.qty_in_stock,
    i.unit,
    (i.id IS NOT NULL
      AND COALESCE(to_jsonb(i)->>'status',
                   CASE WHEN to_jsonb(i)->>'is_active' = 'false' THEN 'inactive' ELSE 'active' END) = 'active') AS sellable
  FROM psy_products p
  LEFT JOIN psy_inventory_items i ON i.id = p.inventory_item_id;
$$;

GRANT EXECUTE ON FUNCTION psy_shop_product_inventory() TO authenticated, anon;

-- ── 3. Fungsi lama (dipakai payment.html versi terdahulu): produk yang TIDAK boleh dijual ─
CREATE OR REPLACE FUNCTION psy_shop_unavailable_products()
RETURNS TABLE (product_id TEXT, name TEXT)
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT s.product_id, s.name FROM psy_shop_product_inventory() s WHERE NOT s.sellable;
$$;

GRANT EXECUTE ON FUNCTION psy_shop_unavailable_products() TO authenticated, anon;

-- ──────────────────────────────────────────────────────────────
-- Produk Shop ikut status Inventori secara automatik (sama dgn migration 20261006_shop_product_follow_inventory.sql)
-- ──────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION psy_inv_item_is_inactive(p_row JSONB)
RETURNS BOOLEAN LANGUAGE sql IMMUTABLE AS $$
  SELECT COALESCE(p_row->>'status',
                  CASE WHEN p_row->>'is_active' = 'false' THEN 'inactive' ELSE 'active' END) <> 'active'
$$;

CREATE OR REPLACE FUNCTION psy_sync_shop_products_on_inventory_change()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF psy_inv_item_is_inactive(to_jsonb(NEW)) THEN
    UPDATE psy_products
       SET is_active = false, status = 'inactive', updated_at = now()
     WHERE inventory_item_id = NEW.id
       AND (is_active IS DISTINCT FROM false OR status IS DISTINCT FROM 'inactive');
  END IF;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_sync_shop_products_on_inventory_change ON psy_inventory_items;
CREATE TRIGGER trg_sync_shop_products_on_inventory_change
  AFTER INSERT OR UPDATE ON psy_inventory_items
  FOR EACH ROW EXECUTE FUNCTION psy_sync_shop_products_on_inventory_change();

CREATE OR REPLACE FUNCTION psy_deactivate_shop_products_on_inventory_delete()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  UPDATE psy_products
     SET is_active = false, status = 'inactive', updated_at = now()
   WHERE inventory_item_id = OLD.id;
  RETURN OLD;
END $$;

DROP TRIGGER IF EXISTS trg_deactivate_shop_products_on_inventory_delete ON psy_inventory_items;
CREATE TRIGGER trg_deactivate_shop_products_on_inventory_delete
  BEFORE DELETE ON psy_inventory_items
  FOR EACH ROW EXECUTE FUNCTION psy_deactivate_shop_products_on_inventory_delete();

CREATE OR REPLACE FUNCTION psy_check_shop_product_link()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
  v_item JSONB;
BEGIN
  IF NEW.inventory_item_id IS NOT NULL THEN
    SELECT to_jsonb(i) INTO v_item FROM psy_inventory_items i WHERE i.id = NEW.inventory_item_id;
    IF v_item IS NOT NULL AND psy_inv_item_is_inactive(v_item) THEN
      NEW.is_active := false;
      NEW.status := 'inactive';
    END IF;
  END IF;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_check_shop_product_link ON psy_products;
CREATE TRIGGER trg_check_shop_product_link
  BEFORE INSERT OR UPDATE OF inventory_item_id ON psy_products
  FOR EACH ROW EXECUTE FUNCTION psy_check_shop_product_link();


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
  jenis_surat                TEXT,                 -- "Letter Type" (cth: Employment Confirmation)
  department                 TEXT,                 -- "Department / Category" (cth: Human Resources) — label sahaja, TAK drive routing
  language                   TEXT DEFAULT 'ms',
  recipient                  TEXT,                 -- "Pengurus Besar, KWSP, ..."
  title                      TEXT,                 -- "PERMOHONAN PENGELUARAN AHLI KWSP"
  body                       TEXT NOT NULL,        -- HTML (editor WYSIWYG) + [PLACEHOLDER]; templat lama = plain text, fillBody() auto-detect
  fields                     JSONB NOT NULL DEFAULT '[]',  -- [{key,label,type,autofill}]
  assigned_signer_id         UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  requires_specific_approver BOOLEAN DEFAULT false,
  is_active                  BOOLEAN DEFAULT true,
  created_by                 UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  created_by_name            TEXT,
  created_at                 TIMESTAMPTZ DEFAULT now(),
  updated_at                 TIMESTAMPTZ DEFAULT now()
);

-- Patch existing install
ALTER TABLE psy_letter_templates ADD COLUMN IF NOT EXISTS department TEXT;

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
  'Togol KELULUSAN kanonik ("Perlukan Kelulusan Management"). true = request mesti lalu pending_approval, HANYA
  assigned_signer (atau super_admin) boleh approve/sign — disemak di surat-issue.html DAN laluan ?tpl= terus
  (bukan setakat snapshot pada request). false = "No Approval Required": submitted → issued OTOMATIK, guna
  signature_url assigned_signer yg tersimpan (psy_profiles.signature_url), tiada staff perlu klik apa-apa.
  assigned_signer_id WAJIB diisi (ditegaskan di surat-edit.html) — dua-dua cabang perlukan signer ditetapkan.';

-- ──── psy_letter_requests ────
-- Permintaan surat dari patient ATAU staff (requester_type). Alur kelulusan:
-- draft (belum submit, boleh sambung) → submitted → pending_approval (kalau template
-- requires_specific_approver) → issued, ATAU rejected / revision_requested (kembali
-- submitted selepas requester edit). Template TANPA kelulusan: submitted → issued terus
-- (auto, tiada manusia sentuh — lihat surat-issue.html requiresApproval helper).
CREATE TABLE IF NOT EXISTS psy_letter_requests (
  id                     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id             UUID REFERENCES psy_patients(id) ON DELETE CASCADE,
  patient_name           TEXT,
  requester_type         TEXT NOT NULL DEFAULT 'patient'
                         CHECK (requester_type IN ('patient','staff')),
  requested_by_staff_id  UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  requested_by_staff_name TEXT,
  template_code          TEXT NOT NULL,
  template_name          TEXT NOT NULL,
  reason                 TEXT,
  recipient              TEXT,          -- "Kepada / Alamat" — override recipient default templat, khusus utk request ni
  field_values           JSONB DEFAULT '{}',
  status                 TEXT NOT NULL DEFAULT 'draft'
                         CHECK (status IN ('draft','submitted','pending_approval','revision_requested','rejected','issued','cancelled')),
  reject_reason          TEXT,
  revision_note          TEXT,
  assigned_signer_id     UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  approved_by            UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  approved_at            TIMESTAMPTZ,
  created_at             TIMESTAMPTZ DEFAULT now(),
  updated_at             TIMESTAMPTZ DEFAULT now()
);

-- ──── Patch existing install ────
ALTER TABLE psy_letter_requests ALTER COLUMN patient_id DROP NOT NULL;
ALTER TABLE psy_letter_requests ALTER COLUMN patient_name DROP NOT NULL;
ALTER TABLE psy_letter_requests ADD COLUMN IF NOT EXISTS requester_type TEXT NOT NULL DEFAULT 'patient';
ALTER TABLE psy_letter_requests ADD COLUMN IF NOT EXISTS requested_by_staff_id UUID REFERENCES psy_profiles(id) ON DELETE SET NULL;
ALTER TABLE psy_letter_requests ADD COLUMN IF NOT EXISTS requested_by_staff_name TEXT;
ALTER TABLE psy_letter_requests ADD COLUMN IF NOT EXISTS revision_note TEXT;
ALTER TABLE psy_letter_requests ADD COLUMN IF NOT EXISTS recipient TEXT;
ALTER TABLE psy_letter_requests DROP CONSTRAINT IF EXISTS psy_letter_requests_requester_type_check;
ALTER TABLE psy_letter_requests ADD CONSTRAINT psy_letter_requests_requester_type_check
  CHECK (requester_type IN ('patient','staff'));
-- PENTING: constraint LAMA (kalau install lama) mungkin cuma benarkan set nilai lebih kecil —
-- kena DROP constraint lama DULU sebelum UPDATE data guna vokab status baru, barulah ADD constraint
-- baru selepas data dah bersih.
ALTER TABLE psy_letter_requests DROP CONSTRAINT IF EXISTS psy_letter_requests_status_check;
-- Rekod lama guna status 'pending' — sepadankan ke 'pending_approval' (dah lalu proses kelulusan dulu).
UPDATE psy_letter_requests SET status = 'pending_approval' WHERE status = 'pending';
-- Jaring keselamatan: mana-mana rekod lama/seed guna status lain yang tak dikenali langsung —
-- sepadankan ke 'pending_approval' supaya staff boleh semak & proses manual, bukan hilang senyap.
UPDATE psy_letter_requests SET status = 'pending_approval'
  WHERE status NOT IN ('draft','submitted','pending_approval','revision_requested','rejected','issued','cancelled');
ALTER TABLE psy_letter_requests ADD CONSTRAINT psy_letter_requests_status_check
  CHECK (status IN ('draft','submitted','pending_approval','revision_requested','rejected','issued','cancelled'));
ALTER TABLE psy_letter_requests ALTER COLUMN status SET DEFAULT 'draft';

-- Indeks
CREATE INDEX IF NOT EXISTS idx_letter_req_patient ON psy_letter_requests(patient_id);
CREATE INDEX IF NOT EXISTS idx_letter_req_staff    ON psy_letter_requests(requested_by_staff_id);
CREATE INDEX IF NOT EXISTS idx_letter_req_status  ON psy_letter_requests(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_letter_req_signer  ON psy_letter_requests(assigned_signer_id, status);

-- RLS
ALTER TABLE psy_letter_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Patient manage own letter requests" ON psy_letter_requests;
CREATE POLICY "Patient manage own letter requests" ON psy_letter_requests
  FOR ALL USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()))
  WITH CHECK (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Staff manage own letter requests" ON psy_letter_requests;
CREATE POLICY "Staff manage own letter requests" ON psy_letter_requests
  FOR ALL USING (requested_by_staff_id = auth.uid())
  WITH CHECK (requested_by_staff_id = auth.uid());

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
COMMENT ON COLUMN psy_letter_requests.requester_type IS
  '''patient'' = pesakit mohon utk diri sendiri (category=patient templates). ''staff'' = staff mohon utk diri sendiri (category=internal templates, cth surat pengesahan kerja utk RELA/KWSP).';
COMMENT ON COLUMN psy_letter_requests.status IS
  'draft=belum submit (boleh sambung) · submitted=baru hantar, sistem tentukan approval · pending_approval=menunggu signer · revision_requested=kena edit & hantar semula · rejected/issued/cancelled=status akhir.';

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

-- Patch existing install — Audit #143: auto-hantar WhatsApp kepada pesakit
-- lepas surat sedia (letters-send-wa edge function). Status penghantaran
-- disimpan di sini supaya staff boleh nampak kat UI (surat-issue.html /
-- patient-hub.html tab Surat) tanpa kena semak log edge function.
ALTER TABLE psy_letter_issued ADD COLUMN IF NOT EXISTS wa_sent_at    TIMESTAMPTZ;
ALTER TABLE psy_letter_issued ADD COLUMN IF NOT EXISTS wa_send_status TEXT;

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

-- Staff boleh baca surat DIA SENDIRI (surat-request.html) walau tiada permission 'communication'
-- (cth coach mohon surat pengesahan kerja utk diri sendiri, bukan proses surat pesakit).
DROP POLICY IF EXISTS "issued_self_read" ON psy_letter_issued;
CREATE POLICY "issued_self_read" ON psy_letter_issued FOR SELECT
  USING (
    request_id IN (SELECT id FROM psy_letter_requests WHERE requested_by_staff_id = auth.uid())
  );

DROP POLICY IF EXISTS "issued_staff_insert" ON psy_letter_issued;
CREATE POLICY "issued_staff_insert" ON psy_letter_issued FOR INSERT
  WITH CHECK (user_has_perm('communication','create'));

-- Auto-issue (template requires_specific_approver=false): requester punya sesi SENDIRI
-- (pesakit atau staff) yang insert psy_letter_issued terus, tanpa staff processing terlibat —
-- dibenarkan HANYA untuk request kepunyaan mereka sendiri.
DROP POLICY IF EXISTS "issued_self_auto_insert" ON psy_letter_issued;
CREATE POLICY "issued_self_auto_insert" ON psy_letter_issued FOR INSERT
  WITH CHECK (
    request_id IN (
      SELECT id FROM psy_letter_requests
      WHERE (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()))
         OR (requested_by_staff_id = auth.uid())
    )
  );

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
COMMENT ON COLUMN psy_letter_issued.wa_sent_at IS
  'Waktu mesej WhatsApp "surat sedia" berjaya dihantar kepada pesakit (letters-send-wa). NULL = belum/tak cuba.';
COMMENT ON COLUMN psy_letter_issued.wa_send_status IS
  'sent = WA berjaya hantar · failed = cuba tapi gagal (cth tiada no. telefon/GHL error) · NULL = belum cuba (surat internal, atau request lama sebelum ciri ni wujud).';

-- ──── psy_letter_request_attachments ────
-- Lampiran (PDF/gambar) yang requester upload masa mohon surat — cth salinan IC, surat tawaran
-- kerja, dll. Sama corak dgn psy_stock_in_documents (database/schema/35_stock_in.sql).
CREATE TABLE IF NOT EXISTS psy_letter_request_attachments (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id       UUID NOT NULL REFERENCES psy_letter_requests(id) ON DELETE CASCADE,
  file_name        TEXT NOT NULL,
  file_path        TEXT NOT NULL,   -- laluan storan: {request_id}/{timestamp}_{filename}
  file_size        INT,
  file_type        TEXT,
  uploaded_by      UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  uploaded_by_name TEXT,
  created_at       TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_letter_attach_request ON psy_letter_request_attachments(request_id);

ALTER TABLE psy_letter_request_attachments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "attach_staff_all" ON psy_letter_request_attachments;
CREATE POLICY "attach_staff_all" ON psy_letter_request_attachments FOR ALL
  USING (user_has_perm('communication','view'))
  WITH CHECK (user_has_perm('communication','create'));

-- Requester (pesakit/staff) urus lampiran request DIA SENDIRI — walau tiada permission 'communication'.
DROP POLICY IF EXISTS "attach_self_all" ON psy_letter_request_attachments;
CREATE POLICY "attach_self_all" ON psy_letter_request_attachments FOR ALL
  USING (
    request_id IN (
      SELECT id FROM psy_letter_requests
      WHERE (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()))
         OR (requested_by_staff_id = auth.uid())
    )
  )
  WITH CHECK (
    request_id IN (
      SELECT id FROM psy_letter_requests
      WHERE (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()))
         OR (requested_by_staff_id = auth.uid())
    )
  );

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
  -- source 'vitals' ditambah 23 Sept 2026 — bacaan Vitals kritikal auto-cipta kes,
  -- lihat trg_vitals_notify_emergency di bawah.
  source                   TEXT DEFAULT 'auto' CHECK (source IN ('auto','manual','patient','vitals')),
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

-- Masa sasaran tindak balas (minit) ikut zon — boleh diubah di Tetapan (key 'emergency_targets').
INSERT INTO psy_settings (key, value) VALUES ('emergency_targets', '{"merah":15,"kuning":30}')
ON CONFLICT (key) DO NOTHING;

CREATE OR REPLACE FUNCTION fn_emergency_target(p_zon TEXT)
RETURNS INT LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT COALESCE(
    (SELECT (value->>p_zon)::INT FROM psy_settings WHERE key = 'emergency_targets'),
    CASE WHEN p_zon = 'merah' THEN 15 ELSE 30 END
  );
$$;

-- PIC lalai bila pesakit tiada coach: staf aktif peringkat pengurusan (ikut nama).
CREATE OR REPLACE FUNCTION fn_emergency_fallback_pic()
RETURNS UUID LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT id FROM psy_profiles
  WHERE role = 'staff' AND staff_role IN ('super_admin','manager','admin')
  ORDER BY full_name
  LIMIT 1;
$$;

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
  v_coach_id := COALESCE(v_coach_id, fn_emergency_fallback_pic());

  v_zon := CASE WHEN NEW.is_emergency THEN 'merah' ELSE NEW.zon END;
  v_target_min := fn_emergency_target(v_zon);

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
      -- Audit trail (management audit item 97.2): perubahan zon AUTOMATIK pun
      -- kena tercatat, bukan hanya perubahan manual staf dari emergency.html.
      -- Dibungkus sub-block sendiri — audit log gagal TAK BOLEH rollback alert
      -- kecemasan yang dah berjaya dicipta/dikemaskini di atas.
      IF v_open_zon IS DISTINCT FROM v_zon THEN
        BEGIN
          INSERT INTO psy_audit_log (actor_name, actor_role, action, target, meta)
          VALUES ('System (Reaksi & Tindakan)', 'system', 'emergency.auto_zon_escalated', v_open_id::TEXT,
            jsonb_build_object('patient_id', NEW.patient_id, 'from', v_open_zon, 'to', v_zon, 'trigger_source', 'reaksi_advice_log', 'source_log_id', NEW.id));
        EXCEPTION WHEN OTHERS THEN NULL;
        END;
      END IF;
    END IF;
  ELSE
    INSERT INTO psy_emergency_alerts
      (patient_id, zon, symptoms, source, source_log_id, response_target_minutes, assigned_to)
    VALUES
      (NEW.patient_id, v_zon, COALESCE(NEW.symptoms, '[]'::jsonb), 'auto', NEW.id, v_target_min, v_coach_id)
    RETURNING id INTO v_open_id;
    BEGIN
      INSERT INTO psy_audit_log (actor_name, actor_role, action, target, meta)
      VALUES ('System (Reaksi & Tindakan)', 'system', 'emergency.auto_created', v_open_id::TEXT,
        jsonb_build_object('patient_id', NEW.patient_id, 'zon', v_zon, 'trigger_source', 'reaksi_advice_log', 'source_log_id', NEW.id));
    EXCEPTION WHEN OTHERS THEN NULL;
    END;
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

-- Kira zon di SERVER (peraturan yang diluluskan): simptom teruk/kecemasan/tahap tinggi → merah,
-- tahap sederhana → kuning, tindakan kecemasan → merah, selain itu hijau. Dijalankan SEBELUM
-- trigger AFTER di atas supaya trg_reaksi_advice_notify_emergency guna zon yang sahih.
CREATE OR REPLACE FUNCTION fn_reaksi_compute_zon()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_zon   TEXT := 'hijau';
  v_tahap TEXT;
  r       RECORD;
BEGIN
  FOR r IN
    SELECT (i.kumpulan || '::' || i.label) AS key, i.is_emergency, i.tahap_risiko, i.boleh_pilih_teruk
    FROM psy_reaksi_item i
    WHERE (i.kumpulan || '::' || i.label) IN (SELECT jsonb_array_elements_text(NEW.symptoms))
  LOOP
    v_tahap := CASE
      WHEN (NEW.teruk_labels ? r.key) AND COALESCE(r.boleh_pilih_teruk, true) THEN 'tinggi'
      ELSE COALESCE(r.tahap_risiko, 'rendah')
    END;
    IF COALESCE(r.is_emergency, false) OR v_tahap = 'tinggi' THEN
      v_zon := 'merah';
    ELSIF v_tahap = 'sederhana' AND v_zon <> 'merah' THEN
      v_zon := 'kuning';
    END IF;
  END LOOP;

  IF EXISTS (SELECT 1 FROM jsonb_array_elements(NEW.actions) a WHERE COALESCE((a->>'is_emergency')::BOOLEAN, false)) THEN
    v_zon := 'merah';
  END IF;

  NEW.zon := v_zon;
  NEW.is_emergency := (v_zon = 'merah');
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE LOG 'fn_reaksi_compute_zon: %', SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_reaksi_compute_zon ON psy_reaksi_advice_log;
CREATE TRIGGER trg_reaksi_compute_zon
  BEFORE INSERT ON psy_reaksi_advice_log
  FOR EACH ROW EXECUTE FUNCTION fn_reaksi_compute_zon();

-- ──── Eskalasi kes lewat (SOP): kes belum Selesai melebihi masa sasaran → notifikasi PIC + pengurusan ────
-- Sekali sahaja per kes (escalated_at). Dijalankan pg_cron tiap 5 minit.
ALTER TABLE psy_emergency_alerts ADD COLUMN IF NOT EXISTS escalated_at TIMESTAMPTZ;

CREATE OR REPLACE FUNCTION fn_emergency_escalate_overdue()
RETURNS INT LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  r        RECORD;
  v_mgr    UUID;
  v_title  TEXT;
  v_body   TEXT;
  v_link   TEXT;
  v_n      INT := 0;
BEGIN
  FOR r IN
    SELECT ea.id, ea.patient_id, ea.zon, ea.assigned_to, ea.response_target_minutes,
           COALESCE(pr.full_name, pt.full_name, 'Pesakit') AS patient_name
    FROM psy_emergency_alerts ea
    JOIN psy_patients pt ON pt.id = ea.patient_id
    LEFT JOIN psy_profiles pr ON pr.id = pt.user_id
    WHERE ea.status <> 'resolved'
      AND ea.escalated_at IS NULL
      AND ea.reported_at + make_interval(mins => ea.response_target_minutes) < now()
  LOOP
    UPDATE psy_emergency_alerts SET escalated_at = now() WHERE id = r.id;
    v_n := v_n + 1;

    v_title := '⏰ KES LEWAT: ' || r.patient_name;
    v_body  := 'Kes zon ' || upper(r.zon) || ' belum selesai melebihi masa sasaran (' || r.response_target_minutes || ' min). Sila tindak SEGERA.';
    v_link  := 'emergency.html?patient_id=' || r.patient_id::TEXT;

    IF r.assigned_to IS NOT NULL THEN
      INSERT INTO psy_notifications (user_id, type, title, body, link)
      VALUES (r.assigned_to, 'reaksi', v_title, v_body, v_link);
    END IF;

    FOR v_mgr IN
      SELECT id FROM psy_profiles
      WHERE role = 'staff' AND staff_role IN ('super_admin','manager','admin')
        AND id IS DISTINCT FROM r.assigned_to
    LOOP
      INSERT INTO psy_notifications (user_id, type, title, body, link)
      VALUES (v_mgr, 'reaksi', v_title, v_body, v_link);
    END LOOP;

    BEGIN
      INSERT INTO psy_audit_log (actor_name, actor_role, action, target, meta)
      VALUES ('System (Eskalasi)', 'system', 'emergency.auto_escalated_overdue', r.id::TEXT,
        jsonb_build_object('patient_id', r.patient_id, 'zon', r.zon, 'target_min', r.response_target_minutes));
    EXCEPTION WHEN OTHERS THEN NULL;
    END;
  END LOOP;

  RETURN v_n;
END;
$$;

SELECT cron.schedule('emergency-overdue-escalate', '*/5 * * * *', $$SELECT fn_emergency_escalate_overdue();$$);

-- ──── Fungsi trigger: bacaan Vitals KRITIKAL → auto-cipta/kemaskini kes Red Emergency ────
-- Sama pola dgn trg_reaksi_advice_notify_emergency di atas (satu alert AKTIF per
-- pesakit, taraf naik ke merah dibenarkan, taraf turun DISEKAT). is_critical
-- dikira server-side di fn_vitals_compute_critical() (10_vitals.sql) — trigger ni
-- cuma respons bila NEW.is_critical = true, tak kira laluan insert (patient-hub/
-- plan-week/vitals-detail) atau staf sedar/tidak.
CREATE OR REPLACE FUNCTION trg_vitals_notify_emergency()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_coach_id     UUID;
  v_patient_name TEXT;
  v_open_id      UUID;
  v_open_zon     TEXT;
  v_reason       TEXT;
BEGIN
  IF NOT NEW.is_critical AND NOT NEW.is_abnormal THEN RETURN NEW; END IF;

  SELECT pt.coach_id, COALESCE(pr.full_name, pt.full_name, 'Pesakit')
    INTO v_coach_id, v_patient_name
  FROM psy_patients pt
  LEFT JOIN psy_profiles pr ON pr.id = pt.user_id
  WHERE pt.id = NEW.patient_id;
  v_coach_id := COALESCE(v_coach_id, fn_emergency_fallback_pic());

  -- Tidak Normal sahaja (bukan kritikal) → kes KUNING, hanya kalau pesakit belum ada kes aktif.
  IF NOT NEW.is_critical THEN
    IF EXISTS (SELECT 1 FROM psy_emergency_alerts WHERE patient_id = NEW.patient_id AND status <> 'resolved') THEN
      RETURN NEW;
    END IF;

    INSERT INTO psy_notifications (user_id, type, title, body, link)
    VALUES (
      v_coach_id, 'vitals',
      '🟡 BACAAN TIDAK NORMAL: ' || v_patient_name,
      'Bacaan Vitals di luar julat normal — sila semak dan susul pesakit.',
      'emergency.html?patient_id=' || NEW.patient_id::TEXT
    );

    INSERT INTO psy_emergency_alerts
      (patient_id, zon, source, response_target_minutes, assigned_to, notes)
    VALUES
      (NEW.patient_id, 'kuning', 'vitals', fn_emergency_target('kuning'), v_coach_id, 'Bacaan Vitals tidak normal')
    RETURNING id INTO v_open_id;
    BEGIN
      INSERT INTO psy_audit_log (actor_name, actor_role, action, target, meta)
      VALUES ('System (Vitals Tidak Normal)', 'system', 'emergency.auto_created', v_open_id::TEXT,
        jsonb_build_object('patient_id', NEW.patient_id, 'zon', 'kuning', 'trigger_source', 'vitals', 'vitals_id', NEW.id));
    EXCEPTION WHEN OTHERS THEN NULL;
    END;
    RETURN NEW;
  END IF;

  v_reason := 'Bacaan Vitals kritikal: ' || COALESCE(NULLIF(concat_ws(', ',
    CASE WHEN NEW.bp_systolic IS NOT NULL AND (NEW.bp_systolic < 80 OR NEW.bp_systolic >= 180)
      THEN 'BP ' || NEW.bp_systolic || '/' || COALESCE(NEW.bp_diastolic::TEXT, '—') END,
    CASE WHEN NEW.bp_diastolic IS NOT NULL AND NEW.bp_diastolic >= 120
      THEN 'BP diastolik ' || NEW.bp_diastolic END,
    CASE WHEN NEW.heart_rate IS NOT NULL AND (NEW.heart_rate < 40 OR NEW.heart_rate > 130)
      THEN 'Nadi ' || NEW.heart_rate || ' bpm' END,
    CASE WHEN NEW.temperature IS NOT NULL AND (NEW.temperature < 35.0 OR NEW.temperature >= 39.5)
      THEN 'Suhu ' || NEW.temperature || '°C' END,
    CASE WHEN NEW.spo2 IS NOT NULL AND NEW.spo2 < 90
      THEN 'SpO2 ' || NEW.spo2 || '%' END,
    CASE WHEN NEW.respiratory_rate IS NOT NULL AND (NEW.respiratory_rate < 8 OR NEW.respiratory_rate > 30)
      THEN 'RR ' || NEW.respiratory_rate || '/min' END
  ), ''), 'ambang kritikal');

  INSERT INTO psy_notifications (user_id, type, title, body, link)
  VALUES (
    v_coach_id, 'vitals',
    '🔴 BACAAN KRITIKAL: ' || v_patient_name,
    v_reason || ' — sila susul SEGERA.',
    'emergency.html?patient_id=' || NEW.patient_id::TEXT
  );

  -- Worklist: satu alert AKTIF per pesakit — kemaskini kalau dah ada (taraf terus
  -- ke merah, tak pernah turun), cipta baharu kalau tiada.
  SELECT id, zon INTO v_open_id, v_open_zon
  FROM psy_emergency_alerts
  WHERE patient_id = NEW.patient_id AND status <> 'resolved'
  ORDER BY created_at DESC LIMIT 1;

  IF v_open_id IS NOT NULL THEN
    UPDATE psy_emergency_alerts
    SET zon = 'merah', reported_at = now(), response_target_minutes = fn_emergency_target('merah'), updated_at = now(),
        notes = CASE WHEN notes IS NULL OR notes = '' THEN v_reason ELSE notes || E'\n' || v_reason END
    WHERE id = v_open_id;
    -- Audit trail (management audit item 97.2): perubahan/zon-refresh AUTOMATIK
    -- pun kena tercatat, bukan hanya perubahan manual staf dari emergency.html.
    -- Dibungkus sub-block sendiri — audit log gagal TAK BOLEH rollback alert
    -- kecemasan yang dah berjaya dicipta/dikemaskini di atas.
    BEGIN
      INSERT INTO psy_audit_log (actor_name, actor_role, action, target, meta)
      VALUES ('System (Vitals Kritikal)', 'system',
        CASE WHEN v_open_zon IS DISTINCT FROM 'merah' THEN 'emergency.auto_zon_escalated' ELSE 'emergency.auto_vitals_critical_repeat' END,
        v_open_id::TEXT,
        jsonb_build_object('patient_id', NEW.patient_id, 'from', v_open_zon, 'to', 'merah', 'trigger_source', 'vitals', 'reason', v_reason, 'vitals_id', NEW.id));
    EXCEPTION WHEN OTHERS THEN NULL;
    END;
  ELSE
    INSERT INTO psy_emergency_alerts
      (patient_id, zon, source, response_target_minutes, assigned_to, notes)
    VALUES
      (NEW.patient_id, 'merah', 'vitals', fn_emergency_target('merah'), v_coach_id, v_reason)
    RETURNING id INTO v_open_id;
    BEGIN
      INSERT INTO psy_audit_log (actor_name, actor_role, action, target, meta)
      VALUES ('System (Vitals Kritikal)', 'system', 'emergency.auto_created', v_open_id::TEXT,
        jsonb_build_object('patient_id', NEW.patient_id, 'zon', 'merah', 'trigger_source', 'vitals', 'reason', v_reason, 'vitals_id', NEW.id));
    EXCEPTION WHEN OTHERS THEN NULL;
    END;
  END IF;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE LOG 'trg_vitals_notify_emergency: %', SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_vitals_notify_emergency ON psy_vitals;
CREATE TRIGGER trg_vitals_notify_emergency
  AFTER INSERT ON psy_vitals
  FOR EACH ROW EXECUTE FUNCTION trg_vitals_notify_emergency();

-- ──── Fungsi trigger: saranan Reaksi tergantung 'needs_review' → notify coach ────
-- Audit management #B2-2 (23 Sept 2026). Bila roles/patient/kepatuhan.html kesan
-- >1 reaksi tercetus serentak dlm satu submission (conflict-check), baris
-- psy_reaksi_advice_log dicipta dgn status='needs_review' (bukan 'draft') supaya
-- cron reaksi-advice-send TAK auto-hantar. Patient client tak boleh INSERT terus
-- ke psy_notifications (RLS staff-only), jadi trigger ni yang notify coach.
-- Dedup: hanya baris PERTAMA (msg_jenis='tindakan', send_after≈created_at) bagi
-- satu submission yang cetus notifikasi — elak 3 notifikasi berulang.
CREATE OR REPLACE FUNCTION trg_reaksi_advice_notify_review()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_coach_id     UUID;
  v_patient_name TEXT;
BEGIN
  IF NEW.status <> 'needs_review' THEN RETURN NEW; END IF;
  IF NOT (NEW.send_after IS NULL OR NEW.send_after <= NEW.created_at + interval '2 minutes') THEN RETURN NEW; END IF;

  SELECT pt.coach_id, COALESCE(pr.full_name, pt.full_name, 'Pesakit')
    INTO v_coach_id, v_patient_name
  FROM psy_patients pt
  LEFT JOIN psy_profiles pr ON pr.id = pt.user_id
  WHERE pt.id = NEW.patient_id;
  IF v_coach_id IS NULL THEN RETURN NEW; END IF;

  INSERT INTO psy_notifications (user_id, type, title, body, link)
  VALUES (
    v_coach_id, 'reaksi',
    '⚠️ Cadangan Perlu Disemak: ' || v_patient_name,
    v_patient_name || ' alami beberapa reaksi serentak — cadangan digenerate TAPI belum dihantar sehingga disemak. Sila semak di reaksi-laporan.html.',
    'reaksi-laporan.html'
  );

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE LOG 'trg_reaksi_advice_notify_review: %', SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_reaksi_advice_notify_review ON psy_reaksi_advice_log;
CREATE TRIGGER trg_reaksi_advice_notify_review
  AFTER INSERT ON psy_reaksi_advice_log
  FOR EACH ROW EXECUTE FUNCTION trg_reaksi_advice_notify_review();

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
  v_open_zon     TEXT;
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

  SELECT id, zon INTO v_open_id, v_open_zon FROM psy_emergency_alerts
  WHERE patient_id = v_patient_id AND status <> 'resolved'
  ORDER BY created_at DESC LIMIT 1;

  IF v_open_id IS NOT NULL THEN
    UPDATE psy_emergency_alerts
    SET zon = 'merah', reported_at = now(), response_target_minutes = fn_emergency_target('merah'), updated_at = now(),
        notes = CASE WHEN notes IS NULL OR notes = '' THEN v_note ELSE notes || E'\n' || v_note END
    WHERE id = v_open_id
    RETURNING id INTO v_alert_id;
    -- Audit trail (management audit item 97.2): laporan sendiri pesakit pun
    -- kena tercatat, bukan hanya perubahan manual staf dari emergency.html.
    -- Dibungkus sub-block sendiri — fungsi ni TIADA exception handler lain
    -- langsung, jadi audit log gagal TAK BOLEH rollback laporan kecemasan
    -- pesakit yang dah berjaya disimpan di atas.
    BEGIN
      INSERT INTO psy_audit_log (actor_id, actor_name, actor_role, action, target, meta)
      VALUES (auth.uid(), v_patient_name, 'patient',
        CASE WHEN v_open_zon IS DISTINCT FROM 'merah' THEN 'emergency.auto_zon_escalated' ELSE 'emergency.auto_patient_repeat' END,
        v_alert_id::TEXT,
        jsonb_build_object('patient_id', v_patient_id, 'from', v_open_zon, 'to', 'merah', 'trigger_source', 'patient_button', 'channel', p_channel));
    EXCEPTION WHEN OTHERS THEN NULL;
    END;
  ELSE
    INSERT INTO psy_emergency_alerts (patient_id, zon, source, response_target_minutes, assigned_to, notes)
    VALUES (v_patient_id, 'merah', 'patient', fn_emergency_target('merah'), v_coach_id, v_note)
    RETURNING id INTO v_alert_id;
    BEGIN
      INSERT INTO psy_audit_log (actor_id, actor_name, actor_role, action, target, meta)
      VALUES (auth.uid(), v_patient_name, 'patient', 'emergency.auto_created', v_alert_id::TEXT,
        jsonb_build_object('patient_id', v_patient_id, 'zon', 'merah', 'trigger_source', 'patient_button', 'channel', p_channel));
    EXCEPTION WHEN OTHERS THEN NULL;
    END;
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

-- Staff boleh tulis terus dari client (audit #133 — delivery log pengumuman
-- in-app, roles/staff/pengumuman-baru.html, bukan setakat dari Edge Function).
drop policy if exists "notif_logs staff insert" on psy_notification_logs;
create policy "notif_logs staff insert" on psy_notification_logs for insert
  with check (auth.uid() in (select id from psy_profiles where role = 'staff'));

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
  -- Audit Tier 9 #8 — bezakan "bila nak buat" (task_date) drpd "bila deadline"
  -- (due_date, opsyen — NULL = tiada deadline berasingan, ikut task_date sahaja).
  due_date     DATE,
  status       TEXT DEFAULT 'belum_mula' CHECK (status IN ('belum_mula','dalam_proses','selesai')),
  priority     TEXT DEFAULT 'sederhana'  CHECK (priority IN ('rendah','sederhana','tinggi')),
  patient_id   UUID REFERENCES psy_patients(id) ON DELETE SET NULL,
  session_id   UUID REFERENCES psy_plan_weekly_progress(id) ON DELETE SET NULL,
  -- Ulangan: none = sekali sahaja (task_date); daily = setiap hari; weekly = hari tertentu (recur_days, 0=Ahad..6=Sabtu)
  recur_type   TEXT NOT NULL DEFAULT 'none' CHECK (recur_type IN ('none','daily','weekly')),
  recur_days   INT[],
  recur_until  DATE,
  -- Lampiran fail task (bucket referral-docs, path tasks/<task_id>/...): [{name,path,uploaded_at}]
  attachments  JSONB DEFAULT '[]'::jsonb,
  -- Audit #146 (7 Okt 2026) — pautan SEHALA (task→appointment) ke psy_appointments
  -- supaya task peribadi (sekali sahaja, bukan berulang) muncul dalam Jadual
  -- Temujanji bersama sesi/temujanji lain. Lihat roles/staff/weekly-plan.html
  -- syncTaskAppointment().
  linked_appointment_id UUID REFERENCES psy_appointments(id) ON DELETE SET NULL,
  created_at   TIMESTAMPTZ DEFAULT now(),
  updated_at   TIMESTAMPTZ DEFAULT now()
);

-- Status setiap kejadian task berulang (task berulang tak ada satu status sahaja)
CREATE TABLE IF NOT EXISTS psy_coach_task_logs (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id     UUID NOT NULL REFERENCES psy_coach_tasks(id) ON DELETE CASCADE,
  log_date    DATE NOT NULL,
  status      TEXT NOT NULL DEFAULT 'belum_mula' CHECK (status IN ('belum_mula','dalam_proses','selesai')),
  updated_at  TIMESTAMPTZ DEFAULT now(),
  CONSTRAINT psy_coach_task_logs_task_date_key UNIQUE (task_id, log_date)
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

ALTER TABLE psy_coach_task_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "coach_task_logs_own" ON psy_coach_task_logs;
CREATE POLICY "coach_task_logs_own" ON psy_coach_task_logs
  USING (EXISTS (SELECT 1 FROM psy_coach_tasks t WHERE t.id = task_id AND t.coach_id = auth.uid()))
  WITH CHECK (EXISTS (SELECT 1 FROM psy_coach_tasks t WHERE t.id = task_id AND t.coach_id = auth.uid()));

DROP POLICY IF EXISTS "coach_task_logs_manager_read" ON psy_coach_task_logs;
CREATE POLICY "coach_task_logs_manager_read" ON psy_coach_task_logs
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff' AND staff_role IN ('manager','admin'))
  );

-- Log aktiviti task (siapa buat apa, bila) — dipaparkan di halaman detail task
CREATE TABLE IF NOT EXISTS psy_coach_task_activity (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id     UUID NOT NULL REFERENCES psy_coach_tasks(id) ON DELETE CASCADE,
  actor_id    UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  actor_name  TEXT,
  action      TEXT NOT NULL,
  detail      JSONB DEFAULT '{}'::jsonb,
  created_at  TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_coach_task_activity_task ON psy_coach_task_activity (task_id, created_at DESC);

ALTER TABLE psy_coach_task_activity ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "coach_task_activity_own" ON psy_coach_task_activity;
CREATE POLICY "coach_task_activity_own" ON psy_coach_task_activity
  USING (EXISTS (SELECT 1 FROM psy_coach_tasks t WHERE t.id = task_id AND t.coach_id = auth.uid()))
  WITH CHECK (EXISTS (SELECT 1 FROM psy_coach_tasks t WHERE t.id = task_id AND t.coach_id = auth.uid()));

DROP POLICY IF EXISTS "coach_task_activity_manager_read" ON psy_coach_task_activity;
CREATE POLICY "coach_task_activity_manager_read" ON psy_coach_task_activity
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

-- Templat "Perjanjian KOB Ditandatangan" (butang manual "Hantar WhatsApp" di kob-detail.html,
-- lepas agreement disign; PDF sah dilampirkan sebagai attachment, bukan placeholder —
-- boleh edit ayat oleh staff; toggle off sembunyikan butang tu terus)
INSERT INTO psy_auto_messages (key, name, description, channel, trigger_type, channels, audience, message_template, placeholders, is_active)
VALUES (
  'kob_agreement_signed',
  'Perjanjian KOB Ditandatangan (WhatsApp)',
  'Mesej + PDF salinan perjanjian yang dihantar bila staff tekan butang "Hantar WhatsApp" (kad Sign Agreement, kob-detail.html) selepas agreement ditandatangan. Toggle off untuk sembunyikan butang tu.',
  'whatsapp',
  'on_action',
  '["whatsapp"]'::jsonb,
  '["patient"]'::jsonb,
  E'Assalamualaikum {nama}, berikut salinan Perjanjian Rawatan ISW yang telah anda tandatangani.',
  '["{nama}"]'::jsonb,
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

-- Peringatan Pengambilan Sampel DNA (dna_sample_reminder) — sehari sebelum tarikh
-- janji temu (psy_dna_test_process.sample_appointment_id), hantar WA + syarat
-- persediaan. Dedup via sample_reminder_sent_at. UPSERT dgn DO UPDATE macam session_confirm.
--   rule.lead_days : berapa hari sebelum tarikh peringatan dihantar (default 1)
insert into psy_auto_messages
  (key, name, description, channel, trigger_type, message_template,
   placeholders, channels, rule, category, language, is_active)
values
  ('dna_sample_reminder',
   'Peringatan Pengambilan Sampel DNA',
   'Sehari sebelum tarikh janji temu pengambilan sampel DNA Test, hantar WA kpd pesakit — nyatakan tarikh/masa & syarat persediaan (makan 2 jam sebelum, jangan makan/minum 30 minit sebelum).',
   'whatsapp', 'before_event',
   E'Salam {nama} 👋\n\nPeringatan: esok anda dijadualkan untuk *Pengambilan Sampel DNA Test* di klinik.\n\n📅 {tarikh_sample} · {masa_sample}\n\n⚠️ Sila patuhi sebelum ujian:\n• Pastikan anda telah makan sekurang-kurangnya 2 jam sebelum ujian.\n• Jangan makan atau minum sekurang-kurangnya 30 minit sebelum ujian.\n\nJumpa esok!\n\n— {nama_klinik}',
   '["{nama}","{tarikh_sample}","{masa_sample}","{nama_klinik}"]'::jsonb,
   '["whatsapp"]'::jsonb,
   '{"lead_days":1}'::jsonb,
   'dna_test', 'ms',
   false)
on conflict (key) do update set
  name             = excluded.name,
  description      = excluded.description,
  channel          = excluded.channel,
  trigger_type     = excluded.trigger_type,
  message_template = excluded.message_template,
  placeholders     = excluded.placeholders,
  channels         = excluded.channels,
  rule             = excluded.rule,
  category         = excluded.category,
  language         = excluded.language,
  updated_at       = now();

-- Ansuran pakej tertunggak (installment_overdue) — bila jumlah TERKUMPUL
-- pesakit (psy_payments) tak cecah target checkpoint (psy_kob_installment_
-- checkpoints) menjelang due_date, tandakan overdue + sekat tempahan sesi
-- baru pesakit, hantar WA sekali. Dijalankan setiap kali event-reminders cron cetus.
insert into psy_auto_messages
  (key, name, description, channel, trigger_type, message_template,
   placeholders, channels, category, language, is_active)
values
  ('installment_overdue',
   'Ansuran Pakej Tertunggak',
   'Bila jumlah terkumpul pesakit tak cecah target checkpoint ansuran menjelang tarikh due, hantar WA + sekat tempahan sesi baru sehingga bayaran diselesaikan.',
   'whatsapp', 'installment_overdue',
   E'Salam {nama} 👋\n\nAnsuran pakej rawatan anda (checkpoint Bulan {bulan}) tertunggak sejak {tarikh_due}. Jumlah wajib terkumpul: RM {jumlah} — baki RM {baki} lagi.\n\nTempahan sesi baru disekat buat sementara waktu sehingga bayaran diselesaikan. Sila hubungi pusat rawatan untuk bantuan.\n\n— {nama_klinik}',
   '["{nama}","{bulan}","{jumlah}","{baki}","{tarikh_due}","{nama_klinik}"]'::jsonb,
   '["whatsapp"]'::jsonb,
   'pembayaran', 'ms',
   false)
on conflict (key) do update set
  name             = excluded.name,
  description      = excluded.description,
  channel          = excluded.channel,
  trigger_type     = excluded.trigger_type,
  message_template = excluded.message_template,
  placeholders     = excluded.placeholders,
  channels         = excluded.channels,
  category         = excluded.category,
  language         = excluded.language,
  updated_at       = now();

-- Peringatan Ansuran Akan Tamat Tempoh (installment_reminder) — N hari sebelum
-- checkpoint psy_kob_installment_checkpoints jatuh tempoh (status masih 'pending'),
-- hantar WA + pautan bayaran HitPay dijana on-the-fly (runInstallmentReminderCheck,
-- event-reminders → _shared/kob_topup.ts). Dedup via installment_reminder_sent_at.
-- Beza dgn installment_overdue (lepas due date, sekat tempahan) — ni SEBELUM due date,
-- galakan bayar awal. UPSERT dgn DO UPDATE macam session_confirm/dna_sample_reminder.
--   rule.lead_days : berapa hari sebelum due_date peringatan dihantar (default 3)
insert into psy_auto_messages
  (key, name, description, channel, trigger_type, message_template,
   placeholders, channels, rule, category, language, is_active)
values
  ('installment_reminder',
   'Peringatan Ansuran Akan Tamat Tempoh',
   'Sebelum checkpoint ansuran KOB jatuh tempoh (rule.lead_days hari, default 3), hantar WA kpd pesakit dengan pautan bayaran HitPay — dijana automatik.',
   'whatsapp', 'installment_reminder',
   E'Salam {nama} 👋\n\nPeringatan mesra: ansuran *{ansuran}* pakej rawatan anda (RM {jumlah}) akan tamat tempoh pada *{tarikh_due}*.\n\nSila selesaikan bayaran melalui pautan selamat:\n{pautan}\n\nTerima kasih — ISW',
   '["{nama}","{ansuran}","{jumlah}","{tarikh_due}","{pautan}"]'::jsonb,
   '["whatsapp"]'::jsonb,
   '{"lead_days":3}'::jsonb,
   'pembayaran', 'ms',
   false)
on conflict (key) do update set
  name             = excluded.name,
  description      = excluded.description,
  channel          = excluded.channel,
  trigger_type     = excluded.trigger_type,
  message_template = excluded.message_template,
  placeholders     = excluded.placeholders,
  channels         = excluded.channels,
  rule             = excluded.rule,
  category         = excluded.category,
  language         = excluded.language,
  updated_at       = now();

-- Jemputan Lampir Kad (card_attach_invite) — staff hantar pautan HitPay
-- "lampir kad" (createKobCardAttachLink) supaya ansuran seterusnya boleh
-- di-auto-caj tanpa pesakit klik pautan tiap bulan. Dihantar MANUAL oleh
-- staff (butang kob-detail.html), bukan cron — is_active kawal sama ada
-- placeholder ni dipakai/skip terus ke teks manual.
insert into psy_auto_messages
  (key, name, description, channel, trigger_type, message_template,
   placeholders, channels, category, language, is_active)
values
  ('card_attach_invite',
   'Jemputan Lampir Kad — Ansuran Automatik',
   'Pautan HitPay "lampir kad" (RM1 pengesahan) supaya ansuran seterusnya dicaj automatik pada tarikh due, pesakit tak perlu klik pautan tiap bulan.',
   'whatsapp', 'card_attach_invite',
   E'Salam {nama} 👋\n\nUntuk memudahkan bayaran ansuran pakej rawatan anda, sila lampirkan kad debit/kredit anda (pengesahan RM1) melalui pautan selamat di bawah. Ansuran seterusnya akan ditolak SECARA AUTOMATIK pada tarikh due — anda tak perlu klik pautan bayaran setiap bulan lagi.\n\n{pautan}\n\n— {nama_klinik}',
   '["{nama}","{pautan}","{nama_klinik}"]'::jsonb,
   '["whatsapp"]'::jsonb,
   'pembayaran', 'ms',
   false)
on conflict (key) do update set
  name             = excluded.name,
  description      = excluded.description,
  channel          = excluded.channel,
  trigger_type     = excluded.trigger_type,
  message_template = excluded.message_template,
  placeholders     = excluded.placeholders,
  channels         = excluded.channels,
  category         = excluded.category,
  language         = excluded.language,
  updated_at       = now();

-- Auto-Caj Berjaya (installment_autocharge_success) — kad tersimpan berjaya
-- dicaj on due_date (runInstallmentAutoChargeCheck, event-reminders →
-- _shared/kob_autocharge.ts). Beza dgn resit HitPay biasa (payments-webhook
-- sendPaymentReceiptWhatsApp) — mesej RINGKAS khusus konteks auto-caj.
insert into psy_auto_messages
  (key, name, description, channel, trigger_type, message_template,
   placeholders, channels, category, language, is_active)
values
  ('installment_autocharge_success',
   'Ansuran Auto-Caj Berjaya',
   'Kad tersimpan pesakit berjaya dicaj automatik pada tarikh due checkpoint ansuran — hantar WA makluman ringkas.',
   'whatsapp', 'installment_autocharge_success',
   E'Salam {nama} 👋\n\nAnsuran *{ansuran}* pakej rawatan anda (RM {jumlah}) telah berjaya ditolak secara automatik daripada kad tersimpan anda pada hari ini.\n\nTerima kasih — {nama_klinik}',
   '["{nama}","{ansuran}","{jumlah}","{nama_klinik}"]'::jsonb,
   '["whatsapp"]'::jsonb,
   'pembayaran', 'ms',
   false)
on conflict (key) do update set
  name             = excluded.name,
  description      = excluded.description,
  channel          = excluded.channel,
  trigger_type     = excluded.trigger_type,
  message_template = excluded.message_template,
  placeholders     = excluded.placeholders,
  channels         = excluded.channels,
  category         = excluded.category,
  language         = excluded.language,
  updated_at       = now();

-- Auto-Caj Gagal (installment_autocharge_failed) — kad tersimpan DITOLAK
-- (kad tamat tempoh/tiada baki dll) semasa cuba caj automatik pada due_date.
-- Fallback ke pautan bayaran manual (createKobInstallmentTopupLink) — sama
-- pautan dgn installment_reminder, cuma konteks mesej berbeza (bukan sekadar
-- peringatan awal, tapi makluman kegagalan caj).
insert into psy_auto_messages
  (key, name, description, channel, trigger_type, message_template,
   placeholders, channels, category, language, is_active)
values
  ('installment_autocharge_failed',
   'Ansuran Auto-Caj Gagal',
   'Kad tersimpan pesakit gagal dicaj (ditolak/tamat tempoh dll) semasa cuba caj automatik pada tarikh due — hantar WA + pautan bayaran manual fallback.',
   'whatsapp', 'installment_autocharge_failed',
   E'Salam {nama} 👋\n\nAnsuran *{ansuran}* pakej rawatan anda (RM {jumlah}) GAGAL ditolak secara automatik daripada kad tersimpan anda (kad mungkin ditolak/tamat tempoh).\n\nSila selesaikan bayaran melalui pautan selamat di bawah, atau hubungi klinik untuk kemas kini kad:\n{pautan}\n\n— {nama_klinik}',
   '["{nama}","{ansuran}","{jumlah}","{pautan}","{nama_klinik}"]'::jsonb,
   '["whatsapp"]'::jsonb,
   'pembayaran', 'ms',
   false)
on conflict (key) do update set
  name             = excluded.name,
  description      = excluded.description,
  channel          = excluded.channel,
  trigger_type     = excluded.trigger_type,
  message_template = excluded.message_template,
  placeholders     = excluded.placeholders,
  channels         = excluded.channels,
  category         = excluded.category,
  language         = excluded.language,
  updated_at       = now();

-- Bayaran Gagal/Dibatalkan (payment_failed) — WA dihantar automatik oleh
-- payments-webhook bila HitPay report status 'failed' (kali pertama sahaja,
-- lihat notifyPaymentFailed). {pautan} diisi kod: sentence lengkap dgn
-- pautan HitPay BAHARU (auto-jana, kob_deposit sahaja) ATAU sentence fallback
-- "cuba semula/hubungi klinik" kalau tiada pautan (package/self-checkout,
-- atau sesi KOB dah tak eligible). UPSERT dgn DO UPDATE macam installment_*.
insert into psy_auto_messages
  (key, name, description, channel, trigger_type, message_template,
   placeholders, channels, category, language, is_active)
values
  ('payment_failed',
   'Bayaran Gagal / Dibatalkan',
   'Dihantar automatik bila bayaran (HitPay) gagal/dibatalkan (kali pertama sahaja per resit). {pautan} = ayat lengkap dgn pautan bayar-semula (auto-jana, kob_deposit sahaja) atau ayat "cuba semula/hubungi klinik" jika tiada pautan.',
   'whatsapp', 'on_action',
   E'Assalamualaikum {nama} 👋\n\nBayaran anda ({item}, RM {jumlah}) tidak berjaya/dibatalkan. {pautan}\n\n— Ibnu Sina Wellness',
   '["{nama}","{item}","{jumlah}","{pautan}"]'::jsonb,
   '["whatsapp"]'::jsonb,
   'pembayaran', 'ms',
   true)
on conflict (key) do update set
  name             = excluded.name,
  description      = excluded.description,
  channel          = excluded.channel,
  trigger_type     = excluded.trigger_type,
  message_template = excluded.message_template,
  placeholders     = excluded.placeholders,
  channels         = excluded.channels,
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

-- ──── psy_announcement_reads (audit #G-33/34, Tier 5) ────
-- Tanda "dibaca" bila pengumuman muncul di dashboard pesakit (impression-based,
-- bukan scroll-tracking terperinci) — cukup utk staf nampak jangkauan sebenar
-- vs sasaran, tanpa infrastruktur analytics berasingan.
CREATE TABLE IF NOT EXISTS psy_announcement_reads (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  announcement_id UUID NOT NULL REFERENCES psy_announcements(id) ON DELETE CASCADE,
  patient_id      UUID NOT NULL REFERENCES psy_patients(id) ON DELETE CASCADE,
  read_at         TIMESTAMPTZ DEFAULT now(),
  UNIQUE (announcement_id, patient_id)
);

CREATE INDEX IF NOT EXISTS idx_ann_reads_ann ON psy_announcement_reads(announcement_id);

ALTER TABLE psy_announcement_reads ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Patients mark own reads" ON psy_announcement_reads;
CREATE POLICY "Patients mark own reads" ON psy_announcement_reads FOR INSERT
  WITH CHECK (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Patients view own reads" ON psy_announcement_reads;
CREATE POLICY "Patients view own reads" ON psy_announcement_reads FOR SELECT
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Staff view all reads" ON psy_announcement_reads;
CREATE POLICY "Staff view all reads" ON psy_announcement_reads FOR SELECT
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

-- ──── psy_event_meet_links (audit #H-36, Tier 5) ────
-- meet_link SENGAJA DIKELUARKAN dari psy_events (lihat migration
-- 20260924_event_meet_link_capacity.sql utk ALTER TABLE DROP COLUMN + backfill
-- data sedia ada) — RLS Postgres cuma boleh benar/tolak SEBARIS, bukan sembunyi
-- SATU LAJUR sahaja. Dulu meet_link tinggal dlm psy_events (dibaca terus lepas
-- event 'published', tak kira pesakit dah daftar atau belum; UI event-detail.html
-- cuma sorok butang client-side, data sebenar tetap ADA dlm respons API). Jadual
-- berasingan + RLS sendiri tutup jurang tu betul-betul. Staf (acara-baru.html/
-- acara-edit.html/acara-detail.html/events.html) baca/tulis terus jadual ni.
CREATE TABLE IF NOT EXISTS psy_event_meet_links (
  event_id   UUID PRIMARY KEY REFERENCES psy_events(id) ON DELETE CASCADE,
  meet_link  TEXT,
  updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE psy_event_meet_links ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff manage event meet links" ON psy_event_meet_links;
CREATE POLICY "Staff manage event meet links" ON psy_event_meet_links FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
  WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "Registered patients read meet link" ON psy_event_meet_links;
CREATE POLICY "Registered patients read meet link" ON psy_event_meet_links FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM psy_event_registrations r
    JOIN psy_patients p ON p.id = r.patient_id
    WHERE r.event_id = psy_event_meet_links.event_id
      AND p.user_id = auth.uid() AND r.status <> 'batal'
  ));

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
ALTER TABLE psy_event_registrations ADD COLUMN IF NOT EXISTS source TEXT DEFAULT 'portal';

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

-- ──── Trigger: kuatkuasa kapasiti acara (audit #H-35, Tier 5) ────
-- Dulu client terus upsert tanpa apa-apa semakan — kapasiti cuma paparan
-- ("6 sesi/8 slot" style), tak dikuatkuasa langsung. Server-side (bukan
-- client) supaya tak boleh dipintas — staf (INSERT terus dari admin,
-- cth manual add) tetap dibenarkan lepas kapasiti (override sengaja).
CREATE OR REPLACE FUNCTION trg_enforce_event_capacity()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_capacity INT;
  v_count    INT;
  v_is_staff BOOLEAN;
BEGIN
  IF NEW.status = 'batal' THEN RETURN NEW; END IF;
  SELECT EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff') INTO v_is_staff;
  IF v_is_staff THEN RETURN NEW; END IF;

  SELECT capacity INTO v_capacity FROM psy_events WHERE id = NEW.event_id;
  IF v_capacity IS NULL THEN RETURN NEW; END IF;

  SELECT COUNT(*) INTO v_count FROM psy_event_registrations
    WHERE event_id = NEW.event_id AND status <> 'batal' AND id <> COALESCE(NEW.id, '00000000-0000-0000-0000-000000000000'::uuid);
  IF v_count >= v_capacity THEN
    RAISE EXCEPTION 'Acara ini telah penuh (kapasiti % peserta).', v_capacity;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_enforce_event_capacity ON psy_event_registrations;
CREATE TRIGGER trg_enforce_event_capacity
  BEFORE INSERT OR UPDATE ON psy_event_registrations
  FOR EACH ROW EXECUTE FUNCTION trg_enforce_event_capacity();

-- ──── Tetingkap Pendaftaran (bila dibuka/ditutup) + Keperluan custom ────
-- registration_deadline (atas) = bila ditutup, NULL = default tutup pada start_at.
ALTER TABLE psy_events ADD COLUMN IF NOT EXISTS registration_opens_at TIMESTAMPTZ;
ALTER TABLE psy_events ADD COLUMN IF NOT EXISTS requirements TEXT;

-- ──── PIC (Person In Charge) acara — koordinator, berasingan dari host ────
ALTER TABLE psy_events ADD COLUMN IF NOT EXISTS pic_id UUID REFERENCES psy_profiles(id) ON DELETE SET NULL;

CREATE OR REPLACE FUNCTION trg_enforce_registration_window()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_opens_at   TIMESTAMPTZ;
  v_closes_at  TIMESTAMPTZ;
  v_start_at   TIMESTAMPTZ;
  v_is_staff   BOOLEAN;
BEGIN
  IF NEW.status = 'batal' THEN RETURN NEW; END IF;
  SELECT EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff') INTO v_is_staff;
  IF v_is_staff THEN RETURN NEW; END IF;

  SELECT registration_opens_at, registration_deadline, start_at
    INTO v_opens_at, v_closes_at, v_start_at
    FROM psy_events WHERE id = NEW.event_id;

  IF v_opens_at IS NOT NULL AND now() < v_opens_at THEN
    RAISE EXCEPTION 'Pendaftaran acara ini belum dibuka.';
  END IF;
  IF now() > COALESCE(v_closes_at, v_start_at) THEN
    RAISE EXCEPTION 'Pendaftaran acara ini telah ditutup.';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_enforce_registration_window ON psy_event_registrations;
CREATE TRIGGER trg_enforce_registration_window
  BEFORE INSERT OR UPDATE ON psy_event_registrations
  FOR EACH ROW EXECUTE FUNCTION trg_enforce_registration_window();

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

-- ═══════════════════════════════════════════════════════════════════
-- Persediaan Event (Inventory Event) — Modul Persediaan Event v1
-- Checklist peralatan/bahan untuk setiap Acara & Kelas. Murni perancangan —
-- TIADA potong/pulang stok automatik. "Stok Sedia Ada" dikira LIVE dari
-- psy_inventory_items.qty_in_stock masa paparan (bukan snapshot di sini).
-- Migration: supabase/migrations/20261014_event_prep_items.sql
-- ═══════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS psy_event_prep_items (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id         UUID NOT NULL REFERENCES psy_events(id) ON DELETE CASCADE,
  source           TEXT NOT NULL DEFAULT 'manual' CHECK (source IN ('inventory','manual')),
  inventory_item_id UUID REFERENCES psy_inventory_items(id) ON DELETE SET NULL,
  item_name        TEXT NOT NULL,
  category         TEXT,
  unit             TEXT,
  qty_needed       NUMERIC(10,2) NOT NULL DEFAULT 1,
  pic_id           UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  deadline_date    DATE,
  status           TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('ready','preparing','pending','not_available')),
  notes            TEXT,
  created_by       UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  created_at       TIMESTAMPTZ DEFAULT now(),
  updated_at       TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_psy_event_prep_items_event ON psy_event_prep_items(event_id);

ALTER TABLE psy_event_prep_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff manage event prep items" ON psy_event_prep_items;
CREATE POLICY "Staff manage event prep items" ON psy_event_prep_items FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

COMMENT ON TABLE psy_event_prep_items IS
  'Checklist persediaan peralatan/bahan untuk Acara & Kelas (psy_events) — Modul Persediaan Event v1. Tiada kaitan pergerakan stok automatik.';
COMMENT ON COLUMN psy_event_prep_items.source IS
  '''inventory'' = dipautkan ke psy_inventory_items (stok sedia ada dikira live); ''manual'' = item bebas, tiada pautan inventori.';
COMMENT ON COLUMN psy_event_prep_items.status IS
  'Ditetapkan staff sendiri: pending (baru/belum mula) -> preparing (sedang disiapkan) -> ready (sedia); not_available = tak dapat disediakan.';
-- Persediaan Event v2: Checklist Setup, Template, Nota, Pengeluaran & Pemulangan
-- Susulan kepada 20261014_event_prep_items.sql (psy_event_prep_items, v1)

-- ── Checklist Setup (tugasan persediaan — bukan barang fizikal) ──
CREATE TABLE IF NOT EXISTS psy_event_checklist_tasks (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id    UUID NOT NULL REFERENCES psy_events(id) ON DELETE CASCADE,
  task        TEXT NOT NULL,
  pic_id      UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  target_date DATE,
  status      TEXT NOT NULL DEFAULT 'belum_mula' CHECK (status IN ('belum_mula','dalam_proses','selesai')),
  created_at  TIMESTAMPTZ DEFAULT now(),
  updated_at  TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_psy_event_checklist_tasks_event ON psy_event_checklist_tasks(event_id);
ALTER TABLE psy_event_checklist_tasks ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Staff manage event checklist tasks" ON psy_event_checklist_tasks;
CREATE POLICY "Staff manage event checklist tasks" ON psy_event_checklist_tasks FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- ── Template persediaan (senarai barang guna-semula) ──
CREATE TABLE IF NOT EXISTS psy_event_prep_templates (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name        TEXT NOT NULL,
  description TEXT,
  created_by  UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  created_at  TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE psy_event_prep_templates ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Staff manage event prep templates" ON psy_event_prep_templates;
CREATE POLICY "Staff manage event prep templates" ON psy_event_prep_templates FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

CREATE TABLE IF NOT EXISTS psy_event_prep_template_items (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  template_id       UUID NOT NULL REFERENCES psy_event_prep_templates(id) ON DELETE CASCADE,
  source            TEXT NOT NULL DEFAULT 'manual' CHECK (source IN ('inventory','manual')),
  inventory_item_id UUID REFERENCES psy_inventory_items(id) ON DELETE SET NULL,
  item_name         TEXT NOT NULL,
  category          TEXT,
  unit              TEXT,
  qty_needed        NUMERIC(10,2) NOT NULL DEFAULT 1
);
CREATE INDEX IF NOT EXISTS idx_psy_event_prep_template_items_template ON psy_event_prep_template_items(template_id);
ALTER TABLE psy_event_prep_template_items ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Staff manage event prep template items" ON psy_event_prep_template_items;
CREATE POLICY "Staff manage event prep template items" ON psy_event_prep_template_items FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- ── Metadata persediaan 1:1 per acara (template digunakan, nota, tarikh akhir persediaan) ──
CREATE TABLE IF NOT EXISTS psy_event_prep_meta (
  event_id      UUID PRIMARY KEY REFERENCES psy_events(id) ON DELETE CASCADE,
  template_id   UUID REFERENCES psy_event_prep_templates(id) ON DELETE SET NULL,
  notes         TEXT,
  deadline_date DATE,
  updated_at    TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE psy_event_prep_meta ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Staff manage event prep meta" ON psy_event_prep_meta;
CREATE POLICY "Staff manage event prep meta" ON psy_event_prep_meta FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- Submit Senarai Persediaan — tab Pemulangan Barang muncul lepas ni disi.
ALTER TABLE psy_event_prep_meta ADD COLUMN IF NOT EXISTS submitted_at TIMESTAMPTZ;

-- ── Pengeluaran & Pemulangan barang (stok keluar untuk event + rekod pulangan) ──
CREATE TABLE IF NOT EXISTS psy_event_stock_issuance (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id          UUID NOT NULL REFERENCES psy_events(id) ON DELETE CASCADE,
  prep_item_id      UUID REFERENCES psy_event_prep_items(id) ON DELETE SET NULL,
  inventory_item_id UUID REFERENCES psy_inventory_items(id) ON DELETE SET NULL,
  item_name         TEXT NOT NULL,
  qty               NUMERIC(10,2) NOT NULL,
  location_id       UUID REFERENCES psy_inventory_locations(id) ON DELETE SET NULL,
  borrowed_by       UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  issued_by         UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  issued_at         TIMESTAMPTZ DEFAULT now(),
  status            TEXT NOT NULL DEFAULT 'dikeluarkan' CHECK (status IN ('dikeluarkan','dipulangkan')),
  returned_at       TIMESTAMPTZ,
  notes             TEXT
);
CREATE INDEX IF NOT EXISTS idx_psy_event_stock_issuance_event ON psy_event_stock_issuance(event_id);
ALTER TABLE psy_event_stock_issuance ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Staff manage event stock issuance" ON psy_event_stock_issuance;
CREATE POLICY "Staff manage event stock issuance" ON psy_event_stock_issuance FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
-- Sambung Persediaan & Peralatan ke modul Equipment (psy_equipment — aset
-- bertag EQ-xxxx, berasingan dari psy_inventory_items yang pukal/konsumsi).
ALTER TABLE psy_event_prep_items DROP CONSTRAINT IF EXISTS psy_event_prep_items_source_check;
ALTER TABLE psy_event_prep_items ADD CONSTRAINT psy_event_prep_items_source_check
  CHECK (source IN ('inventory','manual','equipment'));

ALTER TABLE psy_event_prep_items
  ADD COLUMN IF NOT EXISTS equipment_id UUID REFERENCES psy_equipment(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_psy_event_prep_items_equipment ON psy_event_prep_items(equipment_id);

-- ──── PIC kembali ke Persediaan & Peralatan (per-barang) ────
ALTER TABLE psy_event_prep_items ADD COLUMN IF NOT EXISTS pic_id UUID REFERENCES psy_profiles(id) ON DELETE SET NULL;

-- ──── Pemulangan Barang (gantikan persediaan-event-keluar.html) ────
CREATE TABLE IF NOT EXISTS psy_event_item_returns (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id      UUID NOT NULL REFERENCES psy_events(id) ON DELETE CASCADE,
  prep_item_id  UUID NOT NULL REFERENCES psy_event_prep_items(id) ON DELETE CASCADE,
  qty_borrowed  NUMERIC(10,2) NOT NULL DEFAULT 0,
  qty_returned  NUMERIC(10,2) NOT NULL DEFAULT 0,
  condition     TEXT CHECK (condition IS NULL OR condition IN ('baik','rosak','hilang')),
  returned_at   TIMESTAMPTZ,
  pic_id        UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  created_at    TIMESTAMPTZ DEFAULT now(),
  updated_at    TIMESTAMPTZ DEFAULT now(),
  UNIQUE (prep_item_id)
);
CREATE INDEX IF NOT EXISTS idx_psy_event_item_returns_event ON psy_event_item_returns(event_id);
ALTER TABLE psy_event_item_returns ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Staff manage event item returns" ON psy_event_item_returns;
CREATE POLICY "Staff manage event item returns" ON psy_event_item_returns FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));


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
-- Kod 6 huruf RAWAK (bukan ISW+MRN) — elak corak boleh diteka (cth
-- ISW019 mendedahkan MRN pesakit secara tak langsung dlm pautan rujukan
-- awam, lihat 20261027_referral_silent_link.sql). Nota: trigger MRN
-- (trg_assign_patient_mrn) berjalan dulu ikut abjad nama, jadi NEW.mrn
-- sudah diisi bila trigger ini berjalan (tak lagi digunakan di sini,
-- dikekalkan sbb komen trigger order di atas masih relevan).
CREATE OR REPLACE FUNCTION assign_referral_code()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  candidate TEXT;
BEGIN
  -- Kod sudah diset client — normalkan ke huruf besar & biarkan
  IF NEW.referral_code IS NOT NULL AND length(trim(NEW.referral_code)) > 0 THEN
    NEW.referral_code := upper(trim(NEW.referral_code));
    RETURN NEW;
  END IF;

  LOOP
    SELECT string_agg(substr('ABCDEFGHIJKLMNOPQRSTUVWXYZ', (random() * 25 + 1)::int, 1), '')
    INTO candidate FROM generate_series(1, 6);
    EXIT WHEN NOT EXISTS (SELECT 1 FROM psy_patients WHERE referral_code = candidate);
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
  -- kekal NULL utk rujukan manual biasa. source='plan_1on1' + session_type + unique index elak duplicate.
  plan_id           UUID REFERENCES psy_treatment_plans(id) ON DELETE SET NULL,
  week_number       INT,
  source            TEXT NOT NULL DEFAULT 'manual' CHECK (source IN ('manual','plan_1on1')),
  -- Jenis sesi 1:1 ad-hoc ditanda terus di plan-week.html (checkbox Hakeema/Hakeem/Dr
  -- Session). NULL utk rujukan manual biasa (source='manual').
  session_type      TEXT CHECK (session_type IN ('hakeema','hakeem','dr')),
  created_at        TIMESTAMPTZ DEFAULT now(),
  updated_at        TIMESTAMPTZ DEFAULT now(),
  resolved_at       TIMESTAMPTZ,
  -- Ditambah 23 Sept 2026 (audit management #B2-4) — saranan sesi tak boleh berhenti
  -- sbg nota bebas; perlu Next Action + PIC + Due Date boleh dijejak sehingga selesai.
  next_action        TEXT,
  next_action_pic    UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  next_action_due    DATE,
  next_action_done_at TIMESTAMPTZ,
  -- Ditambah 8 Okt 2026 (audit #17b/#17c) — follow-up saranan Sesi 1:1 kini
  -- AUTO-hantar oleh cron (event-reminders), bukan staf klik wa.me manual lagi;
  -- follow_up_date/follow_up_result sendiri KEKAL dlm consultation JSONB (sedia
  -- ada), tapi follow_up_sent_at diletak TOP-LEVEL supaya cron senang query/dedup.
  follow_up_sent_at        TIMESTAMPTZ,
  -- Reminder harian per-saranan (audit #17c) — staf tandakan masa di
  -- sesi-1on1-detail.html, cron hantar WA ringkas tiap hari sepanjang
  -- tempoh saranan (saranan_start + saranan_days, dlm consultation JSONB).
  reminder_time            TIME,
  reminder_last_sent_date  DATE
);

CREATE INDEX IF NOT EXISTS idx_psy_clinical_referrals_target  ON psy_clinical_referrals(target_id, status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_psy_clinical_referrals_patient ON psy_clinical_referrals(patient_id, created_at DESC);
CREATE UNIQUE INDEX IF NOT EXISTS uq_psy_clinical_referrals_plan_1on1
  ON psy_clinical_referrals(plan_id, week_number, session_type) WHERE source = 'plan_1on1';

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
-- SKEMA: KNOWLEDGE BASE (Pusat Rujukan Dalaman Staff)
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

-- ──── psy_kb_subcategories (subkategori utama dalam setiap kategori) ────
CREATE TABLE IF NOT EXISTS psy_kb_subcategories (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  category_id UUID NOT NULL REFERENCES psy_kb_categories(id) ON DELETE CASCADE,
  name        TEXT NOT NULL,
  slug        TEXT UNIQUE NOT NULL,
  icon        TEXT DEFAULT '📄',
  sort_order  INT  DEFAULT 100,
  is_active   BOOLEAN DEFAULT true,
  created_at  TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_kb_subcategories_category ON psy_kb_subcategories(category_id);

ALTER TABLE psy_kb_subcategories ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "kb_subcat_read" ON psy_kb_subcategories;
CREATE POLICY "kb_subcat_read"  ON psy_kb_subcategories FOR SELECT USING (kb_is_staff());
DROP POLICY IF EXISTS "kb_subcat_write" ON psy_kb_subcategories;
CREATE POLICY "kb_subcat_write" ON psy_kb_subcategories FOR ALL    USING (kb_is_staff()) WITH CHECK (kb_is_staff());

-- ──── psy_kb_resources ────
CREATE TABLE IF NOT EXISTS psy_kb_resources (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title         TEXT NOT NULL,
  description   TEXT,
  category_id   UUID REFERENCES psy_kb_categories(id) ON DELETE SET NULL,
  subcategory_id UUID REFERENCES psy_kb_subcategories(id) ON DELETE SET NULL,
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
CREATE INDEX IF NOT EXISTS idx_kb_res_subcategory ON psy_kb_resources(subcategory_id);
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

-- ──── seed: kategori (8) ────
INSERT INTO psy_kb_categories (name, slug, description, icon, color, sort_order) VALUES
  ('SOP & Operations',                      'sop-operations',
   'SOP operasi, polisi dan aliran kerja pentadbiran dan prosedur harian pusat.',                         '📄', 'navy',       10),
  ('Clinical Guidelines & Protocols',       'clinical-guidelines-protocols',
   'Garis panduan klinikal, keselamatan pesakit dan protokol rawatan yang diluluskan.',                   '🩺', 'green',      20),
  ('Clinical & Therapy Modules',            'clinical-therapy-modules',
   'Modul fisioterapi, kaunseling, bekam dan akupunktur mengikut bidang perkhidmatan.',                   '❤️', 'terracotta', 30),
  ('Forms & Templates',                     'forms-templates',
   'Borang pendaftaran, persetujuan termaklum, template laporan dan checklist.',                          '📋', 'gold',       40),
  ('Staff Training & Development',          'staff-training-development',
   'Modul latihan staf, orientasi pekerja baharu, kemahiran komunikasi dan pembangunan profesional.',      '🎓', 'purple',     50),
  ('Offers, Packages & Sales Workflows',    'offers-packages-sales',
   'Bahan stack tawaran, pakej, harga, aliran kerja jualan dan skrip objection-handling.',                 '🏷️', 'blue',       60),
  ('Client Education & Wellness Resources', 'client-education-wellness',
   'Bahan pendidikan klien, panduan penjagaan selepas rawatan dan sumber kesejahteraan.',                  '📖', 'teal',       70),
  ('Announcements & FAQ',                   'announcements-faq',
   'Pengumuman rasmi, notis staf dan soalan lazim panduan sistem.',                                       '📢', 'grey',       80)
ON CONFLICT (slug) DO NOTHING;

-- ──── seed: subkategori (5-6 setiap kategori) ────
INSERT INTO psy_kb_subcategories (category_id, name, slug, icon, sort_order)
SELECT c.id, v.name, v.slug, v.icon, v.sort_order
FROM (VALUES
  ('sop-operations','Polisi & Prosedur','sop-polisi-prosedur','📜',10),
  ('sop-operations','Pengurusan Janji Temu','sop-janji-temu','📅',20),
  ('sop-operations','Operasi Harian','sop-operasi-harian','🗂️',30),
  ('sop-operations','Keselamatan & Kerahsiaan','sop-keselamatan-kerahsiaan','🔐',40),
  ('sop-operations','Pengurusan Fasiliti','sop-pengurusan-fasiliti','🏢',50),

  ('clinical-guidelines-protocols','Penilaian & Saringan','cgp-penilaian-saringan','🔎',10),
  ('clinical-guidelines-protocols','Protokol Rawatan','cgp-protokol-rawatan','📘',20),
  ('clinical-guidelines-protocols','Pengurusan Risiko','cgp-pengurusan-risiko','⚠️',30),
  ('clinical-guidelines-protocols','Kriteria Rujukan','cgp-kriteria-rujukan','📎',40),
  ('clinical-guidelines-protocols','Standard Keselamatan','cgp-standard-keselamatan','🛡️',50),

  ('clinical-therapy-modules','Fisioterapi','ctm-fisioterapi','🦵',10),
  ('clinical-therapy-modules','Kaunseling & Psikoterapi','ctm-kaunseling-psikoterapi','🧠',20),
  ('clinical-therapy-modules','Bekam','ctm-bekam','🩹',30),
  ('clinical-therapy-modules','Akupunktur','ctm-akupunktur','📍',40),
  ('clinical-therapy-modules','Latihan & Praktikal','ctm-latihan-praktikal','🏋️',50),

  ('forms-templates','Borang Pesakit','ft-borang-pesakit','📝',10),
  ('forms-templates','Persetujuan Termaklum','ft-persetujuan-termaklum','✍️',20),
  ('forms-templates','Template Laporan','ft-template-laporan','📊',30),
  ('forms-templates','Checklist','ft-checklist','☑️',40),
  ('forms-templates','Dokumen Pentadbiran','ft-dokumen-pentadbiran','🗃️',50),

  ('staff-training-development','Staff Onboarding','std-staff-onboarding','👋',10),
  ('staff-training-development','Customer Service & Communication','std-customer-service-comm','💬',20),
  ('staff-training-development','System & Software Training','std-system-software','💻',30),
  ('staff-training-development','Clinical Skills Training','std-clinical-skills','🩺',40),
  ('staff-training-development','Sales & Service Training','std-sales-service','🎯',50),
  ('staff-training-development','Competency & Assessment','std-competency-assessment','✅',60),

  ('offers-packages-sales','Offer Stack','ops-offer-stack','🎁',10),
  ('offers-packages-sales','Pakej & Harga','ops-pakej-harga','💰',20),
  ('offers-packages-sales','Sales Workflow','ops-sales-workflow','🔁',30),
  ('offers-packages-sales','Upsell & Cross-sell','ops-upsell-crosssell','📈',40),
  ('offers-packages-sales','Skrip & Objection Handling','ops-skrip-objection','🗣️',50),
  ('offers-packages-sales','Customer Journey','ops-customer-journey','🧭',60),

  ('client-education-wellness','Psikoedukasi','cew-psikoedukasi','🧩',10),
  ('client-education-wellness','Bahan Kesejahteraan','cew-bahan-kesejahteraan','🌿',20),
  ('client-education-wellness','Lembaran Kerja & Aktiviti','cew-lembaran-aktiviti','📑',30),
  ('client-education-wellness','Panduan Penjagaan Selepas Rawatan','cew-penjagaan-selepas-rawatan','🩺',40),
  ('client-education-wellness','Video & Infografik','cew-video-infografik','🎞️',50),
  ('client-education-wellness','Rujukan & Sumber Bacaan','cew-rujukan-sumber','📚',60),

  ('announcements-faq','Pengumuman Rasmi','af-pengumuman-rasmi','📢',10),
  ('announcements-faq','Notis & Kemas Kini','af-notis-kemaskini','🔔',20),
  ('announcements-faq','Soalan Lazim (FAQ)','af-soalan-lazim','❓',30),
  ('announcements-faq','Panduan Sistem','af-panduan-sistem','🖥️',40),
  ('announcements-faq','Maklumat Penting','af-maklumat-penting','❗',50),
  ('announcements-faq','Arkib Pengumuman','af-arkib-pengumuman','🗄️',60)
) AS v(cat_slug, name, slug, icon, sort_order)
JOIN psy_kb_categories c ON c.slug = v.cat_slug
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

-- Ambang Normal/Tidak Normal/Kritikal per-vital — audit management batch 3
-- (29-30 Sept 2026). normal_min/normal_max = nilai sedia ada (dah dipakai client-side
-- di vitals-detail.html/vitals.html/patient/vitals.html sebelum ni, kekal sama supaya
-- tiada perubahan tingkah laku is_abnormal semasa cutover). critical_min/critical_max
-- SENGAJA null (belum disahkan doktor ISW) — automasi kes kecemasan (is_critical,
-- rujuk fn_vitals_compute_critical() di 10_vitals.sql) TAK aktif sehingga super_admin/
-- doktor isi nilai melalui tetapan.html. JANGAN pra-isi nombor di sini.
INSERT INTO psy_settings (key, value) VALUES
  ('vitals_thresholds', '{
    "bp_systolic":      {"normal_min": 90,   "normal_max": 129,  "critical_min": null, "critical_max": null},
    "bp_diastolic":      {"normal_min": 60,   "normal_max": 84,   "critical_min": null, "critical_max": null},
    "heart_rate":        {"normal_min": 60,   "normal_max": 100,  "critical_min": null, "critical_max": null},
    "temperature":       {"normal_min": 36.1, "normal_max": 37.2, "critical_min": null, "critical_max": null},
    "spo2":              {"normal_min": 95,   "normal_max": null, "critical_min": null, "critical_max": null},
    "respiratory_rate":  {"normal_min": 12,   "normal_max": 20,   "critical_min": null, "critical_max": null}
  }'::jsonb)
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
VALUES ('avatars', 'avatars', true, 15728640, ARRAY['image/png','image/jpeg','image/jpg','image/webp','image/gif'])
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
-- Audit management (30 Sept 2026): bucket ni dulu tiada had saiz/format
-- langsung (unaudited, sama corak dgn library-media sebelum dibaiki).
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('dna-test', 'dna-test', false, 52428800, ARRAY['application/pdf','image/jpeg','image/png','image/jpg','image/webp'])
ON CONFLICT (id) DO UPDATE
  SET file_size_limit = EXCLUDED.file_size_limit,
      allowed_mime_types = EXCLUDED.allowed_mime_types;

-- Library (video/audio/thumbnail/dokumen kandungan pesakit) — audit management
-- batch 3 (25 Sept 2026) Tier 7 #4: bucket ni wujud sebelum ni tapi TIADA had
-- saiz/format langsung (unaudited, ad hoc). Tambah had 500MB + whitelist format.
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('library-media', 'library-media', true, 524288000, ARRAY[
  'video/mp4','video/quicktime','video/webm',
  'audio/mpeg','audio/mp4','audio/x-m4a','audio/wav',
  'image/png','image/jpeg','image/jpg','image/webp',
  'application/pdf','application/msword',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'application/vnd.ms-powerpoint',
  'application/vnd.openxmlformats-officedocument.presentationml.presentation'
])
ON CONFLICT (id) DO UPDATE
  SET public = EXCLUDED.public,
      file_size_limit = EXCLUDED.file_size_limit,
      allowed_mime_types = EXCLUDED.allowed_mime_types;

-- Supplier documents (SSM cert, agreement, dll.) — staff sahaja
INSERT INTO storage.buckets (id, name, public) VALUES ('supplier-docs', 'supplier-docs', false)
ON CONFLICT (id) DO NOTHING;

-- Gambar produk inventori — public (dipaparkan terus di senarai/detail produk).
-- Turut dikongsi oleh Produk & Bahan Luar (psy_recommended_products.image_url).
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('inventory-images', 'inventory-images', true, 15728640, ARRAY['image/png','image/jpeg','image/jpg','image/webp'])
ON CONFLICT (id) DO UPDATE
  SET file_size_limit = EXCLUDED.file_size_limit,
      allowed_mime_types = EXCLUDED.allowed_mime_types;

-- Gambar produk shop (gallery multi-gambar) — public (dipaparkan di shop & senarai produk)
INSERT INTO storage.buckets (id, name, public) VALUES ('product-images', 'product-images', true)
ON CONFLICT (id) DO NOTHING;

-- Dokumen Stock In (delivery note, invois, dll.) — staff sahaja
INSERT INTO storage.buckets (id, name, public) VALUES ('stock-in-docs', 'stock-in-docs', false)
ON CONFLICT (id) DO NOTHING;

-- Lampiran permohonan Surat Rasmi (salinan IC, surat tawaran, dll.) — requester + staff
INSERT INTO storage.buckets (id, name, public) VALUES ('letter-attachments', 'letter-attachments', false)
ON CONFLICT (id) DO NOTHING;

-- Media mesej automasi (imej/video dilampirkan pada mesej sequence) — public (GHL fetch terus URL)
INSERT INTO storage.buckets (id, name, public) VALUES ('automation-media', 'automation-media', true)
ON CONFLICT (id) DO NOTHING;

-- Fail print-ready item inventori (cth reka bentuk Brochure BNP) — dilampir pada
-- psy_inventory_items.print_file_url (14_products_inventory.sql), staff cetak terus
-- dari inventory-detail.html bila perlu restock.
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('inventory-print-files', 'inventory-print-files', true, 52428800, ARRAY['application/pdf','image/png'])
ON CONFLICT (id) DO UPDATE
  SET public = EXCLUDED.public,
      file_size_limit = EXCLUDED.file_size_limit,
      allowed_mime_types = EXCLUDED.allowed_mime_types;


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

-- Pesakit perlu baca fail Rujukan pakej di This Week Coaching (plan-week.html)
-- supaya butang buka fail/link tak mati senyap bila signed URL tersimpan dah luput
-- (audit management Okt 2026 — box "Rujukan" nampak tak boleh tekan).
DROP POLICY IF EXISTS "Patients read pakej rujukan" ON storage.objects;
CREATE POLICY "Patients read pakej rujukan"
    ON storage.objects FOR SELECT
    USING (
      bucket_id = 'pakej-rujukan'
      AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'patient')
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

DROP POLICY IF EXISTS "library_media_staff_write" ON storage.objects;
CREATE POLICY "library_media_staff_write" ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'library-media' AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "library_media_staff_update" ON storage.objects;
CREATE POLICY "library_media_staff_update" ON storage.objects
    FOR UPDATE TO authenticated
    USING (bucket_id = 'library-media' AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "library_media_staff_delete" ON storage.objects;
CREATE POLICY "library_media_staff_delete" ON storage.objects
    FOR DELETE TO authenticated
    USING (bucket_id = 'library-media' AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "library_media_public_read" ON storage.objects;
CREATE POLICY "library_media_public_read" ON storage.objects
    FOR SELECT USING (bucket_id = 'library-media');

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

-- Audit management (30 Sept 2026): dulu pesakit boleh baca SEMUA fail dalam
-- folder mereka sendiri tanpa kira status proses — bermakna laporan DNA boleh
-- dimuat turun terus sebaik staf upload (Step 4), SEBELUM konsultasi/hadir
-- disahkan (Step 5-6). Kini kuatkuasa gate status='completed' di server —
-- path fail berbentuk <patient_id>/<process_id>/nama-fail.
DROP POLICY IF EXISTS "dna_test_patient_read_own" ON storage.objects;
CREATE POLICY "dna_test_patient_read_own" ON storage.objects
    FOR SELECT TO authenticated
    USING (
      bucket_id = 'dna-test'
      AND (storage.foldername(name))[1] IN (
        SELECT id::text FROM psy_patients WHERE user_id = auth.uid()
      )
      AND EXISTS (
        SELECT 1 FROM psy_dna_test_process p
        WHERE p.id::text = (storage.foldername(name))[2]
          AND p.status = 'completed'
      )
    );

DROP POLICY IF EXISTS "supplier_docs_staff_all" ON storage.objects;
CREATE POLICY "supplier_docs_staff_all" ON storage.objects
    FOR ALL TO authenticated
    USING (bucket_id = 'supplier-docs' AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
    WITH CHECK (bucket_id = 'supplier-docs' AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "inventory_images_public_read" ON storage.objects;
CREATE POLICY "inventory_images_public_read" ON storage.objects
    FOR SELECT USING (bucket_id = 'inventory-images');

DROP POLICY IF EXISTS "inventory_images_staff_write" ON storage.objects;
CREATE POLICY "inventory_images_staff_write" ON storage.objects
    FOR ALL TO authenticated
    USING (bucket_id = 'inventory-images' AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
    WITH CHECK (bucket_id = 'inventory-images' AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "product_images_public_read" ON storage.objects;
CREATE POLICY "product_images_public_read" ON storage.objects
    FOR SELECT USING (bucket_id = 'product-images');

DROP POLICY IF EXISTS "product_images_staff_write" ON storage.objects;
CREATE POLICY "product_images_staff_write" ON storage.objects
    FOR ALL TO authenticated
    USING (bucket_id = 'product-images' AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
    WITH CHECK (bucket_id = 'product-images' AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "automation_media_public_read" ON storage.objects;
CREATE POLICY "automation_media_public_read" ON storage.objects
    FOR SELECT USING (bucket_id = 'automation-media');

DROP POLICY IF EXISTS "automation_media_staff_write" ON storage.objects;
CREATE POLICY "automation_media_staff_write" ON storage.objects
    FOR ALL TO authenticated
    USING (bucket_id = 'automation-media' AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
    WITH CHECK (bucket_id = 'automation-media' AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "stock_in_docs_staff_all" ON storage.objects;
CREATE POLICY "stock_in_docs_staff_all" ON storage.objects
    FOR ALL TO authenticated
    USING (bucket_id = 'stock-in-docs' AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
    WITH CHECK (bucket_id = 'stock-in-docs' AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "inventory_print_staff_write" ON storage.objects;
CREATE POLICY "inventory_print_staff_write" ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'inventory-print-files' AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "inventory_print_staff_update" ON storage.objects;
CREATE POLICY "inventory_print_staff_update" ON storage.objects
    FOR UPDATE TO authenticated
    USING (bucket_id = 'inventory-print-files' AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "inventory_print_staff_delete" ON storage.objects;
CREATE POLICY "inventory_print_staff_delete" ON storage.objects
    FOR DELETE TO authenticated
    USING (bucket_id = 'inventory-print-files' AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "inventory_print_public_read" ON storage.objects;
CREATE POLICY "inventory_print_public_read" ON storage.objects
    FOR SELECT USING (bucket_id = 'inventory-print-files');

-- Lampiran permohonan surat: staff (proses) + requester sendiri (laluan {request_id}/... —
-- (storage.foldername(name))[1] mesti request_id kepunyaan pesakit/staff yang login).
DROP POLICY IF EXISTS "letter_attachments_staff_all" ON storage.objects;
CREATE POLICY "letter_attachments_staff_all" ON storage.objects
    FOR ALL TO authenticated
    USING (bucket_id = 'letter-attachments' AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
    WITH CHECK (bucket_id = 'letter-attachments' AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "letter_attachments_self_all" ON storage.objects;
CREATE POLICY "letter_attachments_self_all" ON storage.objects
    FOR ALL TO authenticated
    USING (
      bucket_id = 'letter-attachments'
      AND (storage.foldername(name))[1] IN (
        SELECT id::text FROM psy_letter_requests
        WHERE (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()))
           OR (requested_by_staff_id = auth.uid())
      )
    )
    WITH CHECK (
      bucket_id = 'letter-attachments'
      AND (storage.foldername(name))[1] IN (
        SELECT id::text FROM psy_letter_requests
        WHERE (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()))
           OR (requested_by_staff_id = auth.uid())
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
  -- Ditambah 23 Sept 2026 (audit management #B1-40) — pautan balik ke kes Red
  -- Emergency Protocol (psy_emergency_alerts) yang mencetuskan rekod klinikal ni,
  -- cth staf tandakan pesakit Masuk Wad terus dari emergency.html. Bila rekod ni
  -- ditutup (status → closed), trigger di bawah auto-kemaskini nota kes asal —
  -- lihat trg_patient_event_notify_emergency.
  source_emergency_alert_id UUID REFERENCES psy_emergency_alerts(id) ON DELETE SET NULL,
  created_at            TIMESTAMPTZ DEFAULT now(),
  updated_at            TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_pe_patient  ON psy_patient_events(patient_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_pe_status   ON psy_patient_events(status, event_date DESC);
CREATE INDEX IF NOT EXISTS idx_pe_type     ON psy_patient_events(event_type);
CREATE INDEX IF NOT EXISTS idx_pe_assigned ON psy_patient_events(assigned_to) WHERE assigned_to IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_pe_source_alert ON psy_patient_events(source_emergency_alert_id) WHERE source_emergency_alert_id IS NOT NULL;

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

-- ──── Fungsi trigger: rekod klinikal (dicipta drpd kes Emergency) ditutup → kemaskini kes asal ────
-- Audit management #B1-40 (23 Sept 2026). Bila peristiwa (warded/ICU/kecemasan dll)
-- yang dipautkan ke satu kes Red Emergency Protocol (source_emergency_alert_id)
-- ditutup, tambah nota di kes asal supaya staf yang urus emergency.html nampak
-- perkembangan — TAK auto-resolve kes (staf tetap perlu semak & tutup sendiri
-- di emergency.html, sebab kes emergency mungkin masih perlukan susulan lain).
CREATE OR REPLACE FUNCTION trg_patient_event_notify_emergency()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_note TEXT;
BEGIN
  IF NEW.source_emergency_alert_id IS NULL THEN RETURN NEW; END IF;
  IF NOT (NEW.status = 'closed' AND OLD.status <> 'closed') THEN RETURN NEW; END IF;

  v_note := 'Rekod Klinikal Pesakit (' || NEW.event_type || ') ditutup pada ' ||
            to_char(now(), 'DD Mon YYYY HH24:MI') ||
            COALESCE(' — ' || NEW.notes, '') ||
            '. Lihat peristiwa-detail.html?id=' || NEW.id::TEXT;

  UPDATE psy_emergency_alerts
  SET notes = CASE WHEN notes IS NULL OR notes = '' THEN v_note ELSE notes || E'\n' || v_note END,
      updated_at = now()
  WHERE id = NEW.source_emergency_alert_id;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE LOG 'trg_patient_event_notify_emergency: %', SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_patient_event_notify_emergency ON psy_patient_events;
CREATE TRIGGER trg_patient_event_notify_emergency
  AFTER UPDATE ON psy_patient_events
  FOR EACH ROW EXECUTE FUNCTION trg_patient_event_notify_emergency();

-- ──── Fungsi trigger: auto-cipta Rekod Klinikal Pesakit bila status → 'warded' ────
-- Audit management #124 (7 Okt 2026). Staf dulu kena tukar status pesakit KE
-- 'warded' (roles/staff/patient-hub.html — butang "🏥 Tandakan Warded") DAN klik
-- pautan berasingan ke peristiwa-baru.html utk cipta rekod. Trigger ni gantikan
-- langkah manual kedua tu: sebaik status psy_patients bertukar ke 'warded', satu
-- psy_patient_events (event_type='warded') auto dicipta + lawatan auto-assign
-- kepada coach pesakit (assigned_to = psy_patients.coach_id). Notifikasi loceng &
-- log timeline ikut sendiri melalui trigger sedia ada (trg_patient_event_notify /
-- trg_patient_event_log_created) sebab ia AFTER INSERT ON psy_patient_events.
CREATE OR REPLACE FUNCTION trg_patient_warded_auto_event()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NEW.status <> 'warded' OR OLD.status IS NOT DISTINCT FROM 'warded' THEN
    RETURN NEW;
  END IF;

  -- Elak rekod berganda kalau dah ada rekod 'warded' TERBUKA utk pesakit ni
  -- (cth staf toggle status warded→aktif→warded semula tanpa tutup rekod lama).
  IF EXISTS (
    SELECT 1 FROM psy_patient_events
    WHERE patient_id = NEW.id AND event_type = 'warded' AND status = 'open'
  ) THEN
    RETURN NEW;
  END IF;

  INSERT INTO psy_patient_events (
    patient_id, event_type, priority, status, event_date,
    need_visit, visit_priority, assigned_to, notify_roles, notes, reported_by
  ) VALUES (
    NEW.id, 'warded', 'high', 'open', CURRENT_DATE,
    true, 'high', NEW.coach_id, '["manager","coach"]'::jsonb,
    'Rekod dicipta automatik — status pesakit ditukar ke Warded (Masuk Wad/Hospital).',
    NULL
  );

  -- Audit #146 (sub-3, 7 Okt 2026) — task peribadi auto-cipta & dipautkan kpd
  -- coach pesakit ni (psy_coach_tasks.patient_id), supaya terus muncul di
  -- widget "Task Peribadi" dashboard coach tanpa staf perlu taip manual.
  -- Marker '[auto:warded]' dlm notes elak duplikasi kalau status toggle
  -- warded→aktif→warded berulang kali sebelum task lama ditutup.
  IF NEW.coach_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM psy_coach_tasks
    WHERE patient_id = NEW.id AND coach_id = NEW.coach_id
      AND status <> 'selesai' AND notes LIKE '%[auto:warded]%'
  ) THEN
    INSERT INTO psy_coach_tasks (
      coach_id, title, notes, task_date, priority, status, patient_id
    ) VALUES (
      NEW.coach_id,
      '🏥 Pesakit ' || COALESCE(NEW.full_name, 'Tanpa Nama') || ' masuk Wad/Hospital — rancang lawatan',
      'Dicipta automatik — status pesakit ditukar ke Warded. [auto:warded]',
      CURRENT_DATE, 'tinggi', 'belum_mula', NEW.id
    );
  END IF;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE LOG 'trg_patient_warded_auto_event: %', SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_patient_warded_auto_event ON psy_patients;
CREATE TRIGGER trg_patient_warded_auto_event
  AFTER UPDATE ON psy_patients
  FOR EACH ROW EXECUTE FUNCTION trg_patient_warded_auto_event();


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
  -- Ditambah 24 Sept 2026 (audit management #B1-7/8 Tier 4) — pautan ke pelan
  -- rawatan yang cetus proses ni, supaya boleh kira "berapa proses DNA test dah
  -- dicipta utk pelan ni" (banding dgn pakej.dna_test_count) sebelum auto-cipta lagi.
  plan_id                         UUID REFERENCES psy_treatment_plans(id) ON DELETE SET NULL,
  current_step                    INT NOT NULL DEFAULT 1 CHECK (current_step BETWEEN 1 AND 6),
  status                          TEXT NOT NULL DEFAULT 'in_progress'
                                    CHECK (status IN ('in_progress','completed','cancelled')),

  -- Step 1: Sample Collection
  kit_received_at                 DATE,       -- tarikh pesakit terima DNA Test Kit
  sample_appointment_id           UUID REFERENCES psy_appointments(id) ON DELETE SET NULL,
                                               -- janji temu pesakit datang ambil sampel (reuse psy_appointments, macam Step 5)
  sample_reminder_sent_at         TIMESTAMPTZ, -- dedup peringatan WA sehari sebelum tarikh janji temu sampel
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
  -- Coach yang URUSKAN langkah ni (dipilih staf via dropdown) — BEZA drpd
  -- atgc_activated_by (akaun yang literal klik butang, cth Customer Service
  -- boleh klik bagi pihak coach). Audit management batch (30 Sept 2026).
  atgc_coach_id                   UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,

  -- Step 4: Muat Naik Laporan DNA (dari portal ATGC — boleh >1 fail setiap kategori)
  -- report_files: {"plant_based": ["path1","path2"], "health_risk": [...], "carrier_drug": [...], "summary": [...]}
  report_files                    JSONB DEFAULT '{}'::jsonb,
  -- report_files_meta: {"path1": {"uploaded_at": "...", "uploaded_by": "uuid", "uploaded_by_name": "..."}}
  -- Berasingan drpd report_files (bukan ubah bentuk sedia ada — elak pecahkan
  -- consumer lain cth rekod-perubatan.html yg jangka array string path).
  report_files_meta               JSONB DEFAULT '{}'::jsonb,
  report_notes                    TEXT,
  reports_uploaded_at              TIMESTAMPTZ,
  lab_report_issued_at            DATE,       -- tarikh laporan dikeluarkan oleh lab (bukan tarikh upload)
  reports_emailed_at              TIMESTAMPTZ, -- tarikh laporan dihantar ke pesakit via emel
  -- Staff yg uruskan muat naik/susulan laporan langkah ni (dipilih via dropdown) —
  -- sama corak macam atgc_coach_id (Step 3), supaya setiap langkah ada "siapa handle".
  report_handler_id               UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,

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
CREATE INDEX IF NOT EXISTS idx_dna_test_plan    ON psy_dna_test_process(plan_id) WHERE plan_id IS NOT NULL;

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

-- ──── psy_patients — attribution GHL Affiliate Manager (27 Okt 2026) ────
-- Skop BAHARU di luar rujukan pesakit-ke-pesakit asal (psy_referrals di
-- atas): GHL Affiliate Manager (affiliate luar/"Duta", bukan semestinya
-- pesakit ISW) ada sistem rujukan+komisen SENDIRI (tertutup — tiada API
-- awam/merge tag standard, disahkan 27 Okt 2026). Custom field GHL
-- (folder "PT Sytem") bekalkan field keys ni — rujuk
-- supabase/functions/ghl-booking-webhook/README.md bahagian (d)/(e):
--   contact.referred_by_affiliate → nama affiliate yang rujuk PESAKIT ni
--     (hidup pada contact PESAKIT, event='contact'/'appointment'/'order')
--   contact.kob_referal_code / contact.affiliate_link → kod & pautan
--     affiliate ITU SENDIRI (hidup pada contact AFFILIATE, event='affiliate')
-- Padanan affiliate↔pesakit cuma ikut NAMA (text) — GHL tak bekalkan kod
-- affiliate pada contact pelanggan lagi (boleh ditambah kemudian utk
-- padanan lebih tepat, lihat README).
ALTER TABLE psy_patients ADD COLUMN IF NOT EXISTS referred_by_affiliate_name TEXT;
ALTER TABLE psy_patients ADD COLUMN IF NOT EXISTS affiliate_code TEXT;
ALTER TABLE psy_patients ADD COLUMN IF NOT EXISTS affiliate_link TEXT;

-- contact.referred_by_affiliate_email / _phone (folder "PT Sytem", disahkan
-- 29 Okt 2026 via list_custom_fields) — email & no phone affiliate yang
-- rujuk pesakit ni, sama field group dengan referred_by_affiliate_name di
-- atas. Dipaparkan terus di kob-detail.html seksyen "Affiliate" (keputusan
-- user: 3 data ni terus dari GHL, bukan pengiraan psy_referrals).
ALTER TABLE psy_patients ADD COLUMN IF NOT EXISTS referred_by_affiliate_email TEXT;
ALTER TABLE psy_patients ADD COLUMN IF NOT EXISTS referred_by_affiliate_phone TEXT;

-- ──── psy_external_affiliates — affiliate GHL yang BUKAN semestinya pesakit
-- ISW (keputusan user 27 Okt 2026: komisen pakej OB — bayaran HitPay di ISW,
-- GHL tiada visibiliti — mesti dikira di ISW utk SEMUA affiliate, pesakit
-- atau tidak). `linked_patient_id` diisi automatik kalau telefon affiliate
-- padan dgn psy_patients sedia ada (dia kebetulan pesakit juga) — rujuk
-- upsertExternalAffiliate() di ghl-sync.ts.
CREATE TABLE IF NOT EXISTS psy_external_affiliates (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  full_name           TEXT NOT NULL,
  phone               TEXT,
  email               TEXT,
  bank_name           TEXT,
  bank_account_no     TEXT,
  bank_account_holder TEXT,
  ic_number           TEXT,   -- {{contact.no_ic_agent}} (borang "Duta Sihat Sefitrahnya", 28 Okt 2026)
  address             TEXT,   -- {{contact.alamat_agent}}
  ghl_affiliate_code  TEXT,   -- {{contact.kob_referal_code}} (ejaan GHL — SATU "r")
  affiliate_link      TEXT,   -- {{contact.affiliate_link}}
  ghl_contact_id      TEXT,
  linked_patient_id   UUID REFERENCES psy_patients(id) ON DELETE SET NULL,
  created_at          TIMESTAMPTZ DEFAULT now(),
  updated_at          TIMESTAMPTZ DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_psy_external_affiliates_phone
  ON psy_external_affiliates (phone) WHERE phone IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_psy_external_affiliates_name
  ON psy_external_affiliates (lower(full_name));

ALTER TABLE psy_external_affiliates ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Staff manage external affiliates" ON psy_external_affiliates;
CREATE POLICY "Staff manage external affiliates" ON psy_external_affiliates FOR ALL
  USING      (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
  WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
-- Tiada polisi pesakit/login — affiliate luar tiada akaun ISW, staff sahaja nampak.

-- ──── psy_referrals — benarkan perujuk jadi affiliate luar (bukan psy_patients) ────
-- referrer_patient_id (sedia ada) kekal utk rujukan pesakit-ke-pesakit asal
-- (laluan ?ref=). referrer_affiliate_id (baharu) utk rujukan dari GHL
-- Affiliate Manager — TEPAT SATU drpd dua ni wajib diisi (CHECK di bawah).
ALTER TABLE psy_referrals ADD COLUMN IF NOT EXISTS referrer_affiliate_id UUID REFERENCES psy_external_affiliates(id) ON DELETE CASCADE;
ALTER TABLE psy_referrals ADD COLUMN IF NOT EXISTS source TEXT NOT NULL DEFAULT 'patient' CHECK (source IN ('patient','ghl_affiliate'));

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_psy_referrals_referrer') THEN
    ALTER TABLE psy_referrals ADD CONSTRAINT chk_psy_referrals_referrer CHECK (
      (referrer_patient_id IS NOT NULL AND referrer_affiliate_id IS NULL) OR
      (referrer_patient_id IS NULL AND referrer_affiliate_id IS NOT NULL)
    );
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_psy_referrals_referrer_affiliate ON psy_referrals (referrer_affiliate_id);

-- ──── psy_referrals — tambah kolum komisen ────
ALTER TABLE psy_referrals ADD COLUMN IF NOT EXISTS qualifying_payment_id UUID REFERENCES psy_payments(id) ON DELETE SET NULL;
ALTER TABLE psy_referrals ADD COLUMN IF NOT EXISTS qualifying_package_id UUID REFERENCES psy_packages(id) ON DELETE SET NULL;
ALTER TABLE psy_referrals ADD COLUMN IF NOT EXISTS commission_amount NUMERIC(10,2) DEFAULT 0;
ALTER TABLE psy_referrals ADD COLUMN IF NOT EXISTS payout_id UUID; -- FK ditambah di bawah (selepas psy_affiliate_payouts wujud)

-- ──── psy_affiliate_payouts — lejar bayaran keluar (batch per pesakit/affiliate) ────
CREATE TABLE IF NOT EXISTS psy_affiliate_payouts (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id    UUID REFERENCES psy_patients(id) ON DELETE CASCADE,
  affiliate_id  UUID REFERENCES psy_external_affiliates(id) ON DELETE CASCADE, -- (27 Okt 2026) payout utk affiliate GHL luar
  amount        NUMERIC(10,2) NOT NULL,
  -- 'pending' sengaja tak dimasukkan: staff yang cetus bayaran (butang
  -- "Mulakan Bayaran"), payout terus jadi 'processing' — tiada laluan
  -- kelulusan pesakit-mohon dalam design semasa (Ags 2026).
  status        TEXT NOT NULL DEFAULT 'processing' CHECK (status IN ('processing','paid','rejected')),
  method        TEXT NOT NULL DEFAULT 'bank_transfer' CHECK (method IN ('bank_transfer','hitpay')),
  bank_snapshot JSONB DEFAULT '{}'::jsonb, -- salinan bank_name/account_no/holder masa payout dicipta
  payout_ref    TEXT,                      -- rujukan transaksi (manual, atau HitPay txn id kelak)
  note          TEXT,
  requested_at  TIMESTAMPTZ DEFAULT now(),
  processed_at  TIMESTAMPTZ,
  processed_by  UUID REFERENCES psy_profiles(id)
);

-- Sesuaikan constraint utk table sedia ada (idempotent).
-- GOTCHA (sama corak psy_notifications type_check): jangan teka nama
-- constraint (cth 'psy_affiliate_payouts_status_check') — kalau table
-- ni pernah dicipta/diubah melalui laluan lain, nama sebenar mungkin
-- tak sepadan dan DROP CONSTRAINT IF EXISTS senyap gagal (constraint
-- lama kekal, ADD baru pun gagal/insert lama-lama tersekat). Cari &
-- buang SEMUA check constraint pada kolum status secara dinamik.
UPDATE psy_affiliate_payouts SET status = 'processing' WHERE status NOT IN ('processing','paid','rejected');
DO $$
DECLARE c RECORD;
BEGIN
  FOR c IN
    SELECT con.conname FROM pg_constraint con
    JOIN pg_class rel ON rel.oid = con.conrelid
    WHERE rel.relname = 'psy_affiliate_payouts' AND con.contype = 'c'
      AND pg_get_constraintdef(con.oid) ILIKE '%status%'
  LOOP
    EXECUTE format('ALTER TABLE psy_affiliate_payouts DROP CONSTRAINT %I', c.conname);
  END LOOP;
END $$;
ALTER TABLE psy_affiliate_payouts ADD CONSTRAINT psy_affiliate_payouts_status_check
  CHECK (status IN ('processing','paid','rejected'));

-- GOTCHA lanjutan: CREATE TABLE IF NOT EXISTS tak ubah DEFAULT pada
-- jadual sedia ada — pada jadual yg dicipta sebelum ni, default kolum
-- `status` didapati kekal 'pending' (drift dari versi awal migration)
-- walaupun definisi CREATE TABLE atas kata 'processing'. Insert tanpa
-- nyatakan status (cth startPayout() di affiliate.html) jadi gagal
-- constraint. Paksa default betul secara eksplisit, idempotent.
ALTER TABLE psy_affiliate_payouts ALTER COLUMN status SET DEFAULT 'processing';

-- (27 Okt 2026) Jadual sedia ada dicipta dgn patient_id NOT NULL — kini
-- payout boleh jadi affiliate luar pulak (affiliate_id), jadi patient_id
-- kena jadi opsyenal. affiliate_id ditambah di atas (CREATE TABLE IF NOT
-- EXISTS tak sentuh jadual sedia ada — ALTER eksplisit di sini jamin ia
-- wujud jua pada jadual yg dah dicipta sebelum perubahan ni).
ALTER TABLE psy_affiliate_payouts ALTER COLUMN patient_id DROP NOT NULL;
ALTER TABLE psy_affiliate_payouts ADD COLUMN IF NOT EXISTS affiliate_id UUID REFERENCES psy_external_affiliates(id) ON DELETE CASCADE;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_psy_affiliate_payouts_target') THEN
    ALTER TABLE psy_affiliate_payouts ADD CONSTRAINT chk_psy_affiliate_payouts_target CHECK (
      (patient_id IS NOT NULL AND affiliate_id IS NULL) OR
      (patient_id IS NULL AND affiliate_id IS NOT NULL)
    );
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_psy_affiliate_payouts_patient ON psy_affiliate_payouts(patient_id, status);
CREATE INDEX IF NOT EXISTS idx_psy_affiliate_payouts_affiliate ON psy_affiliate_payouts(affiliate_id, status);

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

-- ──── psy_affiliate_commission_tiers — komisen TIER ikut volume SU/bulan
-- (27 Okt 2026, keputusan user: "kadar komisen OB pun sama macam KOB")
-- GANTI model lama (psy_affiliate_commission_rules, fixed/percent PER
-- PAKEJ) khas utk rujukan GHL affiliate (source='ghl_affiliate') —
-- kadar kini ikut JUMLAH "SU" (sign-up pakej, lepas KOB settle) affiliate
-- tu hasilkan BULAN tu, bukan ikut pakej mana dibeli. Rujukan pesakit-ke-
-- pesakit asal (?ref=, source='patient') KEKAL guna
-- psy_affiliate_commission_rules — TIDAK terjejas/diubah.
--
-- Tier disahkan (poster "Duta Sihat Sefitrahnya"):
--   0-49 SU/bulan   → RM20/SU, tiada bonus bulanan        = RM20/SU
--   50-99 SU/bulan  → RM20/SU + RM10 bonus bulanan/SU     = RM30/SU
--   100+ SU/bulan   → RM20/SU + RM20 bonus bulanan/SU     = RM40/SU
-- Bonus TAHUNAN (RM10/RM20 extra lepas 1,000+ SU setahun) BELUM dibina —
-- poster cuma beri 2 titik data ilustrasi (99/bulan, 100/bulan), tak
-- cukup spec tepat macam mana kadar ditentukan bila volume affiliate
-- naik-turun merentas bulan. TANGGUH sehingga disahkan.
CREATE TABLE IF NOT EXISTS psy_affiliate_commission_tiers (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  min_su               INT NOT NULL,
  max_su               INT,  -- NULL = tiada had atas
  rate_per_su          NUMERIC(10,2) NOT NULL,
  bonus_bulanan_per_su NUMERIC(10,2) NOT NULL DEFAULT 0,
  is_active            BOOLEAN NOT NULL DEFAULT true,
  created_at           TIMESTAMPTZ DEFAULT now()
);

INSERT INTO psy_affiliate_commission_tiers (min_su, max_su, rate_per_su, bonus_bulanan_per_su)
SELECT * FROM (VALUES
  (0,   49,   20.00, 0.00),
  (50,  99,   20.00, 10.00),
  (100, NULL, 20.00, 20.00)
) AS v(min_su, max_su, rate_per_su, bonus_bulanan_per_su)
WHERE NOT EXISTS (SELECT 1 FROM psy_affiliate_commission_tiers);

ALTER TABLE psy_affiliate_commission_tiers ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Staff manage commission tiers" ON psy_affiliate_commission_tiers;
CREATE POLICY "Staff manage commission tiers" ON psy_affiliate_commission_tiers FOR ALL
  USING      (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
  WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

ALTER TABLE psy_referrals ADD COLUMN IF NOT EXISTS commission_month DATE;

-- ──── fn: kira semula tier affiliate utk SATU bulan (retroaktif) ────
-- Dipanggil lepas SETIAP SU baharu qualify bulan tu — jumlah SU TERKINI
-- bulan tu ditentukan tier, kadar gabungan (rate_per_su+bonus_bulanan_per_su)
-- disapu KE SEMUA SU bulan tu (bukan pro-rata). Memandangkan SU tak pernah
-- "backdate" (qualified_at = now() semasa trigger bayaran), nilai yang
-- tersimpan pada bila-bila masa SUDAH jadi jawapan akhir bulan tu —
-- TIADA cron/batch bulanan diperlukan, trigger ni cukup.
-- Payout yang DAH dicipta (payout_id bukan NULL) TAK disentuh — kunci
-- amaun selepas staff mula proses bayaran.
CREATE OR REPLACE FUNCTION recalc_affiliate_commission_tier(p_affiliate_id UUID, p_month DATE)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_su_count INT;
  v_tier     RECORD;
  v_rate     NUMERIC(10,2);
BEGIN
  IF p_affiliate_id IS NULL OR p_month IS NULL THEN RETURN; END IF;

  SELECT count(*) INTO v_su_count FROM psy_referrals
  WHERE referrer_affiliate_id = p_affiliate_id
    AND source = 'ghl_affiliate'
    AND status = 'qualified'
    AND commission_month = p_month;

  SELECT * INTO v_tier FROM psy_affiliate_commission_tiers
  WHERE is_active AND min_su <= v_su_count AND (max_su IS NULL OR v_su_count <= max_su)
  ORDER BY min_su DESC LIMIT 1;

  v_rate := COALESCE(v_tier.rate_per_su, 0) + COALESCE(v_tier.bonus_bulanan_per_su, 0);

  UPDATE psy_referrals SET commission_amount = v_rate
  WHERE referrer_affiliate_id = p_affiliate_id
    AND source = 'ghl_affiliate'
    AND status = 'qualified'
    AND payout_id IS NULL
    AND commission_month = p_month;
END;
$$;

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
  v_referrer_patient_id   UUID;
  v_referrer_affiliate_id UUID;
  v_referrer_user_id      UUID;
  v_source    TEXT;
  v_has_kob   BOOLEAN;
  v_month     DATE;
BEGIN
  IF NEW.status IS DISTINCT FROM 'completed' OR NEW.patient_id IS NULL THEN
    RETURN NEW;
  END IF;
  IF TG_OP = 'UPDATE' AND OLD.status = 'completed' THEN
    RETURN NEW; -- elak kira dua kali
  END IF;

  SELECT id, referrer_patient_id, referrer_affiliate_id, source
    INTO v_ref_id, v_referrer_patient_id, v_referrer_affiliate_id, v_source
  FROM psy_referrals
  WHERE referee_patient_id = NEW.patient_id AND status = 'pending'
  LIMIT 1;
  IF v_ref_id IS NULL THEN
    RETURN NEW;
  END IF;

  -- (27 Okt 2026) Rujukan GHL affiliate — "1 SU" cuma layak lepas pesakit
  -- SETTLE sesi KOB (hadir/completed), bukan setakat bayar pakej.
  IF v_source = 'ghl_affiliate' THEN
    SELECT EXISTS (
      SELECT 1 FROM psy_kob_sessions WHERE patient_id = NEW.patient_id AND status IN ('hadir','completed')
    ) INTO v_has_kob;
    IF NOT v_has_kob THEN
      RETURN NEW; -- KOB belum settle — belum layak qualify lagi
    END IF;
  END IF;

  -- Cuba kesan pakej dari baris pertama items[] (teks kod ATAU UUID —
  -- ikut ketidakkonsistenan active_package_id yang direkod dlm memory).
  -- FIX 29 Okt 2026: kunci JSON SEBENAR yang ditulis setiap laluan insert
  -- psy_payments (payments-initiate, manual KOB dll.) ialah `reference_id`
  -- — `packageId` TAK PERNAH wujud dalam items[] (bug lama, qualifying_
  -- package_id sentiasa NULL utk SEMUA rujukan sebelum ni, bukan isu
  -- khusus GHL affiliate).
  BEGIN
    v_pkg_text := COALESCE(NEW.items -> 0 ->> 'reference_id', NEW.items -> 0 ->> 'packageId');
  EXCEPTION WHEN OTHERS THEN
    v_pkg_text := NULL;
  END;

  IF v_pkg_text IS NOT NULL THEN
    SELECT id INTO v_pkg_id FROM psy_packages
    WHERE id::text = v_pkg_text OR package_id = v_pkg_text
    LIMIT 1;
  END IF;

  IF v_source = 'ghl_affiliate' THEN
    -- Nilai AWAL sahaja — recalc_affiliate_commission_tier() di bawah
    -- timpa dgn kadar tier SEBENAR serta-merta (dalam transaksi sama).
    v_amount := 0;
  ELSE
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
  END IF;

  v_month := date_trunc('month', now())::date;

  UPDATE psy_referrals SET
    status = 'qualified',
    qualified_at = now(),
    qualifying_payment_id = NEW.id,
    qualifying_package_id = v_pkg_id,
    commission_amount = v_amount,
    commission_month = v_month
  WHERE id = v_ref_id;

  IF v_source = 'ghl_affiliate' THEN
    PERFORM recalc_affiliate_commission_tier(v_referrer_affiliate_id, v_month);
    SELECT commission_amount INTO v_amount FROM psy_referrals WHERE id = v_ref_id;
  END IF;

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
  created_at        TIMESTAMPTZ DEFAULT now(),
  -- Fasa 2 (6 Okt 2026)
  voucher_code      TEXT NOT NULL UNIQUE DEFAULT ('VC' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8))),  -- kod paparan baucar (auto jika tak diisi)
  title             TEXT,                  -- nama baucar (cth "Birthday Reward")
  min_subtotal      NUMERIC(10,2) NOT NULL DEFAULT 0,
  applies_to        TEXT NOT NULL DEFAULT 'all' CHECK (applies_to IN ('all','product','category','package')),
  applies_to_values TEXT[],
  issued_by         UUID REFERENCES psy_profiles(id) ON DELETE SET NULL
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
-- (referee) — boleh digunakan untuk MANA-MANA bayaran akan datang (bukan
-- terhad pakej pertama — elak baucar "terperap" kalau pakej diaktifkan
-- melalui laluan lain, cth staff Tandakan Selesai KOB terus tanpa checkout).
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


-- ════════════════════════════════════════════════════════════════
-- schema/29_promo_codes.sql
-- ════════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════════
-- 29 — KOD PROMO (KEDAI)
-- Jadual: psy_promo_codes, psy_promo_redemptions
-- Kod diskaun umum (cth 'RAYA10') dicipta staff, ditaip pesakit di cart
-- kedai (shop.html). Berbeza dari psy_vouchers (28_rewards.sql) yang
-- auto-apply ganjaran khusus per-pesakit — kod promo ni umum & manual.
-- Logik sah & redeem terpusat dalam payments-initiate; trigger di sini
-- cuma kunci penggunaan bila bayaran SAHAJA disahkan 'completed'.
-- ═══════════════════════════════════════════════════════════════════

-- ──── psy_promo_codes ────
CREATE TABLE IF NOT EXISTS psy_promo_codes (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code                  TEXT UNIQUE NOT NULL,
  description           TEXT,
  discount_type         TEXT NOT NULL CHECK (discount_type IN ('percent','fixed')),
  discount_value        NUMERIC(10,2) NOT NULL CHECK (discount_value > 0),
  min_subtotal          NUMERIC(10,2) NOT NULL DEFAULT 0,
  max_uses              INT,                       -- NULL = tiada had keseluruhan
  used_count            INT NOT NULL DEFAULT 0,
  max_uses_per_patient  INT NOT NULL DEFAULT 1,     -- NULL = tiada had per-pesakit
  valid_from            DATE,
  valid_until           DATE,
  is_active             BOOLEAN NOT NULL DEFAULT true,
  created_by            UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  created_at            TIMESTAMPTZ DEFAULT now(),
  updated_at            TIMESTAMPTZ DEFAULT now(),
  -- Audit #D-15/16/17 (Tier 5)
  applies_to            TEXT NOT NULL DEFAULT 'all' CHECK (applies_to IN ('all','product','category','package')),
  applies_to_values     TEXT[],       -- product_id / category / package_id list, ikut applies_to (NULL bila 'all')
  stackable             BOOLEAN NOT NULL DEFAULT false,  -- MVP: tak boleh gabung (lock 6 Okt). Medan kekal utk kegunaan masa depan
  new_customer_only     BOOLEAN NOT NULL DEFAULT false,  -- LEGACY — digantikan customer_eligibility='new' (kekal utk kod lama)
  campaign              TEXT,         -- label kempen (pilihan, utk pengelompokan/laporan sahaja — bukan gate)
  -- Fasa 2 (6 Okt 2026)
  start_time            TIME NOT NULL DEFAULT '00:00:00',  -- masa mula (masa tempatan MY)
  end_time              TIME NOT NULL DEFAULT '23:59:59',  -- masa tamat (masa tempatan MY)
  promotion_type        TEXT NOT NULL DEFAULT 'promo_code' CHECK (promotion_type IN ('promo_code','voucher')),  -- promo_code=taip/claim sendiri; voucher=push ke wallet (lihat 30_promo_claims.sql)
  name                  TEXT,         -- nama promosi (cth "New Patient 10% Off"); description kekal utk penerangan
  max_discount          NUMERIC(10,2) CHECK (max_discount IS NULL OR max_discount > 0),  -- had maksimum RM utk diskaun peratus (NULL = tiada)
  show_on_shop          BOOLEAN NOT NULL DEFAULT false,  -- papar dalam banner Shop pesakit?
  customer_eligibility  TEXT NOT NULL DEFAULT 'all' CHECK (customer_eligibility IN ('all','new','existing','selected')),
  selected_patient_ids  UUID[]        -- pesakit tertentu (bila customer_eligibility='selected')
);

CREATE INDEX IF NOT EXISTS idx_psy_promo_codes_code ON psy_promo_codes(code);

ALTER TABLE psy_promo_codes ENABLE ROW LEVEL SECURITY;

-- Baca terbuka (macam psy_products) — client perlu preview kod sebelum checkout.
DROP POLICY IF EXISTS "Anyone read promo codes" ON psy_promo_codes;
CREATE POLICY "Anyone read promo codes" ON psy_promo_codes FOR SELECT USING (true);

DROP POLICY IF EXISTS "Staff manage promo codes" ON psy_promo_codes;
CREATE POLICY "Staff manage promo codes" ON psy_promo_codes
  FOR ALL USING      (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
           WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

COMMENT ON COLUMN psy_promo_codes.code IS
  'Disimpan uppercase (cth RAYA10). Sentiasa banding upper(trim(input)) semasa sah kod.';
COMMENT ON COLUMN psy_promo_codes.min_subtotal IS
  'Subjumlah troli minimum (RM) sebelum kod boleh diguna. 0 = tiada syarat.';
COMMENT ON COLUMN psy_promo_codes.max_uses_per_patient IS
  'Had berapa kali SATU pesakit boleh guna kod ni (dikira dari psy_promo_redemptions).';
COMMENT ON COLUMN psy_promo_codes.applies_to IS
  'Skop troli yang perlu ADA sebelum kod sah dipakai (gate seluruh-atau-tiada — diskaun tetap kena SELURUH subjumlah, bukan pro-rata baris tertentu, sama falsafah macam min_subtotal).';
COMMENT ON COLUMN psy_promo_codes.applies_to_values IS
  'product_id (psy_products) / category (psy_products.category) / package_id (psy_packages), ikut applies_to.';
COMMENT ON COLUMN psy_promo_codes.stackable IS
  'false = tak boleh dipakai serentak dgn baucar ganjaran auto-apply (psy_vouchers, cth baucar tukar mata) dlm checkout yang sama.';

-- ──── psy_promo_redemptions ────
-- Lejar penggunaan — dicipta oleh trigger (bukan client) bila bayaran sah selesai.
CREATE TABLE IF NOT EXISTS psy_promo_redemptions (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  promo_id         UUID NOT NULL REFERENCES psy_promo_codes(id) ON DELETE CASCADE,
  patient_id       UUID NOT NULL REFERENCES psy_patients(id) ON DELETE CASCADE,
  payment_id       UUID REFERENCES psy_payments(id) ON DELETE SET NULL,
  discount_amount  NUMERIC(10,2) NOT NULL,
  created_at       TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_psy_promo_redemptions_promo_patient
  ON psy_promo_redemptions(promo_id, patient_id);

ALTER TABLE psy_promo_redemptions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Patients view own promo redemptions" ON psy_promo_redemptions;
CREATE POLICY "Patients view own promo redemptions" ON psy_promo_redemptions FOR SELECT
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Staff view all promo redemptions" ON psy_promo_redemptions;
CREATE POLICY "Staff view all promo redemptions" ON psy_promo_redemptions FOR SELECT
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- ──── Redeem: kunci kod promo bila bayaran yang memakainya SAHAJA selesai ────
-- payments-initiate simpan promoCodeId + promoDiscount dalam psy_payments.intent
-- bila kod diguna pakai (total dah ditolak). Trigger ni sahkan bayaran itu betul-
-- betul SELESAI sebelum log penggunaan + naikkan used_count (elak bayaran
-- gagal/dibatal "makan" kuota kod orang). Sama pattern dengan
-- trg_voucher_mark_used_on_payment (28_rewards.sql).
CREATE OR REPLACE FUNCTION trg_promo_mark_used_on_payment()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_promo_id UUID;
  v_discount NUMERIC;
  v_patient_id UUID;
BEGIN
  IF NEW.status IS DISTINCT FROM 'completed' THEN RETURN NEW; END IF;
  IF TG_OP = 'UPDATE' AND OLD.status = 'completed' THEN RETURN NEW; END IF;

  v_promo_id := (NEW.intent ->> 'promoCodeId')::uuid;
  IF v_promo_id IS NULL THEN RETURN NEW; END IF;

  v_discount := COALESCE((NEW.intent ->> 'promoDiscount')::numeric, 0);
  v_patient_id := NEW.patient_id;
  IF v_patient_id IS NULL THEN RETURN NEW; END IF;

  INSERT INTO psy_promo_redemptions (promo_id, patient_id, payment_id, discount_amount)
  VALUES (v_promo_id, v_patient_id, NEW.id, v_discount);

  UPDATE psy_promo_codes SET used_count = used_count + 1, updated_at = now()
  WHERE id = v_promo_id;

  -- Tandakan claim wallet (30_promo_claims.sql) sebagai 'used' kalau pesakit
  -- claim kod ni dulu sebelum checkout. No-op senyap kalau tiada claim padan
  -- (pesakit taip kod terus tanpa claim pun sah — wallet cuma lapisan UX).
  UPDATE psy_promo_claims SET status = 'used', used_at = now(), used_in_payment_id = NEW.id
  WHERE promo_id = v_promo_id AND patient_id = v_patient_id AND status = 'active';

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE LOG 'trg_promo_mark_used_on_payment: %', SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_promo_mark_used_on_payment ON psy_payments;
CREATE TRIGGER trg_promo_mark_used_on_payment
  AFTER INSERT OR UPDATE ON psy_payments
  FOR EACH ROW EXECUTE FUNCTION trg_promo_mark_used_on_payment();


-- ════════════════════════════════════════════════════════════════
-- schema/30_promo_claims.sql
-- ════════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════════
-- 30 — VOUCHER WALLET (CLAIM KOD PROMO)
-- Jadual: psy_promo_claims. Fungsi: claim_promo_code().
-- Lapisan kedua di atas psy_promo_codes (29_promo_codes.sql) — pesakit
-- boleh "claim" kod ke wallet peribadi (gaya ZUS: tab Active/Past,
-- kotak "Add a voucher") supaya tak perlu ingat/taip kod setiap kali
-- checkout. Cara "taip terus di cart" (29) KEKAL berfungsi tanpa claim.
-- ═══════════════════════════════════════════════════════════════════

ALTER TABLE psy_promo_codes
  ADD COLUMN IF NOT EXISTS wallet_validity_days INT;

COMMENT ON COLUMN psy_promo_codes.wallet_validity_days IS
  'Bilangan hari sah dari tarikh CLAIM (bukan dari cipta kod) — dipakai bila valid_until tiada. NULL + valid_until tiada = tiada had.';

-- ──── psy_promo_claims ────
-- Snapshot nilai kod pada masa claim (elak join semasa papar wallet,
-- & kekal betul walaupun kod dipinda/dipadam kemudian).
CREATE TABLE IF NOT EXISTS psy_promo_claims (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id        UUID NOT NULL REFERENCES psy_patients(id) ON DELETE CASCADE,
  promo_id          UUID NOT NULL REFERENCES psy_promo_codes(id) ON DELETE CASCADE,
  code              TEXT NOT NULL,
  discount_type     TEXT NOT NULL,
  discount_value    NUMERIC(10,2) NOT NULL,
  min_subtotal      NUMERIC(10,2) NOT NULL DEFAULT 0,
  claimed_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at        TIMESTAMPTZ,
  status            TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active','used')),
  used_at           TIMESTAMPTZ,
  used_in_payment_id UUID REFERENCES psy_payments(id) ON DELETE SET NULL,
  UNIQUE (promo_id, patient_id)
);

CREATE INDEX IF NOT EXISTS idx_psy_promo_claims_patient ON psy_promo_claims(patient_id, status);

ALTER TABLE psy_promo_claims ENABLE ROW LEVEL SECURITY;

-- Pesakit cuma boleh BACA claim sendiri. TIADA INSERT/UPDATE policy untuk
-- pesakit — semua tulisan lalui claim_promo_code() (SECURITY DEFINER) atau
-- trigger trg_promo_mark_used_on_payment (29_promo_codes.sql). Ini elak
-- pesakit forge discount_value/discount_type terus via client insert.
DROP POLICY IF EXISTS "Patients view own promo claims" ON psy_promo_claims;
CREATE POLICY "Patients view own promo claims" ON psy_promo_claims FOR SELECT
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Staff view all promo claims" ON psy_promo_claims;
CREATE POLICY "Staff view all promo claims" ON psy_promo_claims FOR SELECT
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

COMMENT ON TABLE psy_promo_claims IS
  'Wallet peribadi pesakit — 1 baris = 1 kod yang di-"claim" (gaya ZUS Voucher Wallet). status=used ditanda oleh trg_promo_mark_used_on_payment bila bayaran yg guna kod ni SELESAI.';

-- ──── claim_promo_code() ────
-- RPC dipanggil client (window.db.rpc('claim_promo_code', { p_code })).
-- Sah kod SEPENUHNYA server-side (sama syarat macam blok promo dalam
-- payments-initiate) sebelum insert snapshot. RAISE EXCEPTION dgn mesej
-- BM mesra bila gagal — client papar terus error.message.
CREATE OR REPLACE FUNCTION claim_promo_code(p_code TEXT)
RETURNS psy_promo_claims
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_patient_id UUID;
  v_promo      psy_promo_codes%ROWTYPE;
  v_now_my     TIMESTAMP;
  v_start_my   TIMESTAMP;
  v_end_my     TIMESTAMP;
  v_expires_at TIMESTAMPTZ;
  v_claim      psy_promo_claims%ROWTYPE;
  v_elig_mode  TEXT;
  v_has_paid   BOOLEAN;
  v_redeemed   INT;
BEGIN
  SELECT id INTO v_patient_id FROM psy_patients WHERE user_id = auth.uid() LIMIT 1;
  IF v_patient_id IS NULL THEN
    RAISE EXCEPTION 'Rekod pesakit tidak dijumpai.';
  END IF;

  SELECT * INTO v_promo FROM psy_promo_codes WHERE code = upper(trim(p_code));
  IF v_promo.id IS NULL OR NOT v_promo.is_active THEN
    RAISE EXCEPTION 'Kod tidak sah atau telah luput.';
  END IF;

  -- Tarikh + masa (waktu tempatan Malaysia, UTC+8) — sama kaedah dgn payments-initiate
  v_now_my := (now() + interval '8 hours');
  v_start_my := CASE WHEN v_promo.valid_from IS NOT NULL THEN v_promo.valid_from::timestamp + COALESCE(v_promo.start_time, '00:00:00')::time ELSE NULL END;
  v_end_my := CASE WHEN v_promo.valid_until IS NOT NULL THEN v_promo.valid_until::timestamp + COALESCE(v_promo.end_time, '23:59:59')::time ELSE NULL END;
  IF (v_start_my IS NOT NULL AND v_now_my < v_start_my) OR (v_end_my IS NOT NULL AND v_now_my > v_end_my) THEN
    RAISE EXCEPTION 'Kod tidak sah atau telah luput.';
  END IF;

  IF v_promo.max_uses IS NOT NULL AND v_promo.used_count >= v_promo.max_uses THEN
    RAISE EXCEPTION 'Kod ini telah mencapai had penggunaan.';
  END IF;

  -- Had setiap pesakit (dikira dari penggunaan SEBENAR, bukan claim)
  IF v_promo.max_uses_per_patient IS NOT NULL THEN
    SELECT count(*) INTO v_redeemed FROM psy_promo_redemptions
      WHERE promo_id = v_promo.id AND patient_id = v_patient_id;
    IF v_redeemed >= v_promo.max_uses_per_patient THEN
      RAISE EXCEPTION 'Anda sudah guna had maksimum untuk kod ini.';
    END IF;
  END IF;

  -- Kelayakan pelanggan
  v_elig_mode := COALESCE(v_promo.customer_eligibility, CASE WHEN v_promo.new_customer_only THEN 'new' ELSE 'all' END);
  IF v_elig_mode IN ('new', 'existing') THEN
    SELECT EXISTS (SELECT 1 FROM psy_payments WHERE patient_id = v_patient_id AND status = 'completed') INTO v_has_paid;
    IF v_elig_mode = 'new' AND v_has_paid THEN
      RAISE EXCEPTION 'Kod ini untuk pesakit baharu sahaja.';
    END IF;
    IF v_elig_mode = 'existing' AND NOT v_has_paid THEN
      RAISE EXCEPTION 'Kod ini untuk pesakit sedia ada sahaja.';
    END IF;
  ELSIF v_elig_mode = 'selected' AND NOT (v_patient_id = ANY(COALESCE(v_promo.selected_patient_ids, ARRAY[]::UUID[]))) THEN
    RAISE EXCEPTION 'Kod ini tidak sah untuk akaun anda.';
  END IF;

  v_expires_at := CASE
    WHEN v_promo.valid_until IS NOT NULL THEN v_promo.valid_until::timestamptz + INTERVAL '1 day' - INTERVAL '1 second'
    WHEN v_promo.wallet_validity_days IS NOT NULL THEN now() + (v_promo.wallet_validity_days || ' days')::interval
    ELSE NULL
  END;

  BEGIN
    INSERT INTO psy_promo_claims (patient_id, promo_id, code, discount_type, discount_value, min_subtotal, expires_at)
    VALUES (v_patient_id, v_promo.id, v_promo.code, v_promo.discount_type, v_promo.discount_value, v_promo.min_subtotal, v_expires_at)
    RETURNING * INTO v_claim;
  EXCEPTION WHEN unique_violation THEN
    RAISE EXCEPTION 'Anda sudah menuntut kod ini.';
  END;

  RETURN v_claim;
END;
$$;

GRANT EXECUTE ON FUNCTION claim_promo_code(TEXT) TO authenticated;

-- ═══════════════════════════════════════════════════════════════════
-- Fasa 2b (7 Okt 2026) — Promosi jenis "Voucher": AUTO-PUSH claim ke
-- wallet ramai pesakit sekali gus bila promosi jadi/kekal Aktif
-- (bukan pesakit taip/claim sendiri, dan bukan butang manual staff).
-- Idempoten — ON CONFLICT (promo_id, patient_id) DO NOTHING, jadi
-- selamat dicetus berulang kali (setiap kali disunting semasa Aktif);
-- pesakit baharu yang jadi layak akan terangkum pada push seterusnya.
-- "History" (used/expired) guna status + expires_at sedia ada pada
-- psy_promo_claims — roles/patient/vouchers.html dah pisah tab
-- Aktif/Lepas berdasarkan ini, tiada kerja tambahan diperlukan.
-- ═══════════════════════════════════════════════════════════════════

-- ──── _push_promo_wallet_rows(): logik insert sebenar (dalaman, tiada semakan staff) ────
-- Dipanggil oleh trigger (selepas UPDATE/INSERT yang DAH lepas RLS staff-only
-- pada psy_promo_codes — jadi kebenaran dah disahkan oleh UPDATE/INSERT itu sendiri).
CREATE OR REPLACE FUNCTION _push_promo_wallet_rows(p_promo_id UUID)
RETURNS INT
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_promo psy_promo_codes%ROWTYPE;
  v_expires_at TIMESTAMPTZ;
  v_count INT;
BEGIN
  SELECT * INTO v_promo FROM psy_promo_codes WHERE id = p_promo_id;
  IF v_promo.id IS NULL OR v_promo.promotion_type IS DISTINCT FROM 'voucher' OR NOT v_promo.is_active THEN
    RETURN 0;
  END IF;

  v_expires_at := CASE
    WHEN v_promo.valid_until IS NOT NULL THEN v_promo.valid_until::timestamptz + INTERVAL '1 day' - INTERVAL '1 second'
    WHEN v_promo.wallet_validity_days IS NOT NULL THEN now() + (v_promo.wallet_validity_days || ' days')::interval
    ELSE NULL
  END;

  INSERT INTO psy_promo_claims (patient_id, promo_id, code, discount_type, discount_value, min_subtotal, expires_at)
  SELECT p.id, v_promo.id, v_promo.code, v_promo.discount_type, v_promo.discount_value, v_promo.min_subtotal, v_expires_at
  FROM psy_patients p
  WHERE p.status <> 'deleted'
    AND (
      v_promo.customer_eligibility = 'all' OR v_promo.customer_eligibility IS NULL
      OR (v_promo.customer_eligibility = 'new' AND NOT EXISTS (SELECT 1 FROM psy_payments pay WHERE pay.patient_id = p.id AND pay.status = 'completed'))
      OR (v_promo.customer_eligibility = 'existing' AND EXISTS (SELECT 1 FROM psy_payments pay WHERE pay.patient_id = p.id AND pay.status = 'completed'))
      OR (v_promo.customer_eligibility = 'selected' AND p.id = ANY(COALESCE(v_promo.selected_patient_ids, ARRAY[]::UUID[])))
    )
  ON CONFLICT (promo_id, patient_id) DO NOTHING;

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

-- ──── trg_promo_push_voucher(): auto-push bila promosi Voucher jadi/kekal Aktif ────
CREATE OR REPLACE FUNCTION trg_promo_push_voucher()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NEW.promotion_type = 'voucher' AND NEW.is_active THEN
    PERFORM _push_promo_wallet_rows(NEW.id);
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_promo_push_voucher ON psy_promo_codes;
CREATE TRIGGER trg_promo_push_voucher
  AFTER INSERT OR UPDATE ON psy_promo_codes
  FOR EACH ROW EXECUTE FUNCTION trg_promo_push_voucher();


-- ════════════════════════════════════════════════════════════════
-- schema/31_points.sql
-- ════════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════════
-- 31 — SISTEM MATA (POINTS)
-- Jadual: psy_points_ledger, psy_point_rewards. View: psy_points_balance.
-- Fungsi: redeem_point_reward(). Trigger: trg_award_daily_checkin_point.
-- Pesakit dapat 1 mata setiap hari isi Catatan Harian (psy_kepatuhan_log,
-- 11_checkins_kepatuhan.sql), tukar mata jadi baucar RM (reuse psy_vouchers,
-- 28_rewards.sql — auto-apply FIFO checkout, tiada kerja tambahan).
-- ═══════════════════════════════════════════════════════════════════

-- ──── psy_points_ledger ────
-- Lejar mata generik (append-only) — sama falsafah dgn psy_vouchers:
-- setiap peraturan cuma perlu INSERT satu baris, logik baki dikira sekali.
CREATE TABLE IF NOT EXISTS psy_points_ledger (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id   UUID NOT NULL REFERENCES psy_patients(id) ON DELETE CASCADE,
  source_type  TEXT NOT NULL,      -- 'daily_checkin' | 'reward_redeem' | ...
  source_ref   UUID,               -- rujukan longgar (psy_kepatuhan_log.id / psy_point_rewards.id)
  points       INT NOT NULL CHECK (points <> 0),  -- positif = dapat, negatif = belanja
  note         TEXT,
  created_at   TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_psy_points_ledger_patient ON psy_points_ledger(patient_id, created_at);

ALTER TABLE psy_points_ledger ENABLE ROW LEVEL SECURITY;

-- Tiada INSERT policy pesakit — semua tulisan lalui trigger/RPC SECURITY
-- DEFINER (elak pesakit forge mata sendiri).
DROP POLICY IF EXISTS "Patients view own points" ON psy_points_ledger;
CREATE POLICY "Patients view own points" ON psy_points_ledger FOR SELECT
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Staff view all points" ON psy_points_ledger;
CREATE POLICY "Staff view all points" ON psy_points_ledger FOR SELECT
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- View baki mata per-pesakit — senang dibaca client (SELECT terus, bukan
-- aggregate manual di JS). security_invoker=true WAJIB — tanpa ni, view
-- jalan dengan hak pemilik (bypass RLS psy_points_ledger), pesakit boleh
-- nampak baki SEMUA orang.
CREATE OR REPLACE VIEW psy_points_balance
  WITH (security_invoker = true) AS
  SELECT patient_id, COALESCE(SUM(points), 0)::INT AS balance
  FROM psy_points_ledger
  GROUP BY patient_id;

-- ──── Trigger: 1 mata setiap hari isi Catatan Harian ────
-- kepatuhan.html simpan guna .upsert(payload, {onConflict:'patient_id,log_date'})
-- — AFTER INSERT cuma fire pada submission PERTAMA hari tu; edit berulang
-- hari sama jatuh ke laluan UPDATE (conflict), trigger INSERT tak fire
-- semula. Jadi 1 hari = 1 mata, auto, tiada duplicate-guard tambahan perlu.
CREATE OR REPLACE FUNCTION trg_award_daily_checkin_point()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  INSERT INTO psy_points_ledger (patient_id, source_type, source_ref, points, note)
  VALUES (NEW.patient_id, 'daily_checkin', NEW.id, 1, 'Catatan Harian — ' || NEW.log_date);
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE LOG 'trg_award_daily_checkin_point: %', SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_award_daily_checkin_point ON psy_kepatuhan_log;
CREATE TRIGGER trg_award_daily_checkin_point
  AFTER INSERT ON psy_kepatuhan_log
  FOR EACH ROW EXECUTE FUNCTION trg_award_daily_checkin_point();

-- ──── psy_point_rewards ────
-- Katalog ganjaran (staff-managed) — tukar mata jadi baucar RM.
CREATE TABLE IF NOT EXISTS psy_point_rewards (
  id                          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name                        TEXT NOT NULL,
  description                 TEXT,
  points_cost                 INT NOT NULL CHECK (points_cost > 0),
  voucher_amount              NUMERIC(10,2) NOT NULL CHECK (voucher_amount > 0),
  max_redemptions_per_patient INT,   -- NULL = tiada had
  is_active                   BOOLEAN NOT NULL DEFAULT true,
  created_by                  UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  created_at                  TIMESTAMPTZ DEFAULT now(),
  updated_at                  TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE psy_point_rewards ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone read point rewards" ON psy_point_rewards;
CREATE POLICY "Anyone read point rewards" ON psy_point_rewards FOR SELECT USING (true);

DROP POLICY IF EXISTS "Staff manage point rewards" ON psy_point_rewards;
CREATE POLICY "Staff manage point rewards" ON psy_point_rewards
  FOR ALL USING      (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
           WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- ──── redeem_point_reward() ────
-- RPC dipanggil client (window.db.rpc('redeem_point_reward', { p_reward_id })).
-- Kira baki mata SENDIRI dalam function (bukan baca view) elak race/staleness.
-- Belanja mata + cipta baucar RM (psy_vouchers) dalam SATU transaksi.
CREATE OR REPLACE FUNCTION redeem_point_reward(p_reward_id UUID)
RETURNS psy_vouchers
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_patient_id UUID;
  v_reward     psy_point_rewards%ROWTYPE;
  v_balance    INT;
  v_redeemed   INT;
  v_voucher    psy_vouchers%ROWTYPE;
BEGIN
  SELECT id INTO v_patient_id FROM psy_patients WHERE user_id = auth.uid() LIMIT 1;
  IF v_patient_id IS NULL THEN
    RAISE EXCEPTION 'Rekod pesakit tidak dijumpai.';
  END IF;

  SELECT * INTO v_reward FROM psy_point_rewards WHERE id = p_reward_id;
  IF v_reward.id IS NULL OR NOT v_reward.is_active THEN
    RAISE EXCEPTION 'Ganjaran ini tidak sah atau tidak lagi ditawarkan.';
  END IF;

  IF v_reward.max_redemptions_per_patient IS NOT NULL THEN
    SELECT COUNT(*) INTO v_redeemed FROM psy_points_ledger
      WHERE patient_id = v_patient_id AND source_type = 'reward_redeem' AND source_ref = v_reward.id;
    IF v_redeemed >= v_reward.max_redemptions_per_patient THEN
      RAISE EXCEPTION 'Anda telah mencapai had tukaran untuk ganjaran ini.';
    END IF;
  END IF;

  SELECT COALESCE(SUM(points), 0) INTO v_balance FROM psy_points_ledger WHERE patient_id = v_patient_id;
  IF v_balance < v_reward.points_cost THEN
    RAISE EXCEPTION 'Mata tidak mencukupi.';
  END IF;

  INSERT INTO psy_points_ledger (patient_id, source_type, source_ref, points, note)
  VALUES (v_patient_id, 'reward_redeem', v_reward.id, -v_reward.points_cost, 'Tukar: ' || v_reward.name);

  -- Audit #C-13 (Tier 5) — tempoh sah 90 hari dari tarikh tebus (dulu expires_at
  -- sentiasa NULL = tiada luput langsung). payments-initiate.ts (checkout) & profile.html
  -- (paparan pesakit) dua-dua dah semak expires_at, jadi terus berkesan.
  INSERT INTO psy_vouchers (patient_id, source_type, source_ref, amount, note, expires_at)
  VALUES (v_patient_id, 'point_redeem', v_reward.id, v_reward.voucher_amount, 'Ditukar dari mata: ' || v_reward.name, now() + interval '90 days')
  RETURNING * INTO v_voucher;

  RETURN v_voucher;
END;
$$;

GRANT EXECUTE ON FUNCTION redeem_point_reward(UUID) TO authenticated;

-- ──── adjust_points_manual() ────
-- Audit #C-13 (Tier 5) — dulu TIADA cara staf laras mata pesakit secara manual
-- (cth pampasan kesilapan sistem, ganjaran ad-hoc) sbb psy_points_ledger langsung
-- tiada INSERT policy (sengaja, elak forge). RPC ni SATU-SATUNYA laluan tulisan
-- manual — sebab WAJIB, staf-sahaja (semak role dlm function, bukan harap RLS).
CREATE OR REPLACE FUNCTION adjust_points_manual(p_patient_id UUID, p_points INT, p_reason TEXT)
RETURNS psy_points_ledger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_is_staff BOOLEAN;
  v_row      psy_points_ledger%ROWTYPE;
BEGIN
  SELECT EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff') INTO v_is_staff;
  IF NOT v_is_staff THEN
    RAISE EXCEPTION 'Hanya staf boleh laras mata pesakit.';
  END IF;
  IF p_points = 0 THEN
    RAISE EXCEPTION 'Bilangan mata mesti bukan sifar.';
  END IF;
  IF p_reason IS NULL OR btrim(p_reason) = '' THEN
    RAISE EXCEPTION 'Sebab pelarasan diperlukan.';
  END IF;

  INSERT INTO psy_points_ledger (patient_id, source_type, points, note)
  VALUES (p_patient_id, 'manual_adjustment', p_points, btrim(p_reason))
  RETURNING * INTO v_row;

  RETURN v_row;
END;
$$;

GRANT EXECUTE ON FUNCTION adjust_points_manual(UUID, INT, TEXT) TO authenticated;

-- ──── Fasa 5 (7 Okt 2026) — Mata Shop: trigger auto-kira bila bayaran Shop selesai/refund ────
-- RM1 produk layak = 1 mata (selepas diskaun, tak termasuk penghantaran).
-- Lihat migration 20261007_shop_points.sql utk nota penuh.
CREATE OR REPLACE FUNCTION _shop_points_eligible_amount(p_payment psy_payments)
RETURNS NUMERIC
LANGUAGE plpgsql
AS $$
DECLARE
  v_items JSONB;
  v_item JSONB;
  v_delivery NUMERIC := 0;
  v_only_shop BOOLEAN := true;
BEGIN
  v_items := p_payment.intent -> 'items';
  IF v_items IS NULL OR jsonb_typeof(v_items) <> 'array' OR jsonb_array_length(v_items) = 0 THEN
    RETURN 0;
  END IF;

  FOR v_item IN SELECT * FROM jsonb_array_elements(v_items) LOOP
    IF (v_item ->> 'type') IS DISTINCT FROM 'shop_order' THEN
      v_only_shop := false;
    ELSE
      -- JANGAN baca (v_item->>'deliveryFee') — nilai CLIENT mentah, boleh ditokok.
      v_delivery := v_delivery + (CASE WHEN v_item ->> 'deliveryMethod' = 'pos' THEN 8 ELSE 0 END);
    END IF;
  END LOOP;

  -- Elak kira mata utk pesanan campur (shop_order + jenis lain) — tak berlaku
  -- dalam UI sedia ada (satu checkout = satu jenis), tapi jaga-jaga.
  IF NOT v_only_shop THEN
    RETURN 0;
  END IF;

  RETURN GREATEST(0, COALESCE(p_payment.total, 0) - v_delivery);
END;
$$;

CREATE OR REPLACE FUNCTION trg_shop_points_on_payment()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_points INT;
  v_eligible NUMERIC;
BEGIN
  -- Diberi: status BARU jadi 'completed' (bukan status lain → completed berulang)
  IF NEW.status = 'completed' AND (TG_OP = 'INSERT' OR OLD.status IS DISTINCT FROM 'completed') THEN
    IF NOT EXISTS (SELECT 1 FROM psy_points_ledger WHERE source_type = 'shop_purchase' AND source_ref = NEW.id) THEN
      v_eligible := _shop_points_eligible_amount(NEW);
      v_points := floor(v_eligible)::int;
      IF v_points > 0 AND NEW.patient_id IS NOT NULL THEN
        INSERT INTO psy_points_ledger (patient_id, source_type, source_ref, points, note)
        VALUES (NEW.patient_id, 'shop_purchase', NEW.id, v_points, 'Pembelian Shop — resit ' || COALESCE(NEW.receipt_ref, NEW.id::text));
      END IF;
    END IF;
  END IF;

  -- Dibalikkan: bayaran yang DAH pernah 'completed', kini jadi refunded/voided
  IF NEW.status IN ('refunded', 'voided') AND OLD.status IS DISTINCT FROM NEW.status AND OLD.status = 'completed' THEN
    IF EXISTS (SELECT 1 FROM psy_points_ledger WHERE source_type = 'shop_purchase' AND source_ref = NEW.id)
       AND NOT EXISTS (SELECT 1 FROM psy_points_ledger WHERE source_type = 'shop_refund' AND source_ref = NEW.id) THEN
      SELECT -points INTO v_points FROM psy_points_ledger WHERE source_type = 'shop_purchase' AND source_ref = NEW.id;
      IF v_points IS NOT NULL AND v_points <> 0 THEN
        INSERT INTO psy_points_ledger (patient_id, source_type, source_ref, points, note)
        VALUES (NEW.patient_id, 'shop_refund', NEW.id, v_points, 'Pembalikan mata — bayaran ' || NEW.status);
      END IF;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_shop_points_on_payment ON psy_payments;
CREATE TRIGGER trg_shop_points_on_payment
  AFTER INSERT OR UPDATE OF status ON psy_payments
  FOR EACH ROW EXECUTE FUNCTION trg_shop_points_on_payment();


-- ════════════════════════════════════════════════════════════════
-- schema/32_suppliers.sql
-- ════════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════════
-- 32 — SUPPLIERS
-- Supplier sebagai ENTITI SENDIRI — sebelum ni cuma teks bebas dalam
-- psy_inventory_items.supplier_info (JSON), tak boleh dikongsi/rujuk
-- silang. Ni asas untuk Purchase Orders (P15-17), supplier performance,
-- dan filter Supplier yang konsisten di Products/Purchase Requests.
-- psy_inventory_items.supplier_id ditambah (nullable) supaya borang
-- item boleh pilih supplier sebenar kemudian — belum wired di UI lagi.
-- ═══════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS psy_suppliers (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  supplier_code       TEXT UNIQUE,
  supplier_type       TEXT NOT NULL DEFAULT 'supplier'
                      CHECK (supplier_type IN ('supplier','manufacturer','distributor','service_provider')),
  name                TEXT NOT NULL,
  registration_no     TEXT,   -- No. SSM
  gst_no              TEXT,
  tax_type            TEXT,   -- 'registered' | 'not_registered'
  currency            TEXT NOT NULL DEFAULT 'MYR',
  category            TEXT,
  is_preferred        BOOLEAN NOT NULL DEFAULT false,
  status              TEXT NOT NULL DEFAULT 'active'
                      CHECK (status IN ('active','inactive','blacklisted')),

  -- Contact & Address
  phone               TEXT,
  mobile              TEXT,
  email               TEXT,
  fax                 TEXT,
  location_url        TEXT,   -- pautan Waze lokasi supplier
  website             TEXT,
  address             TEXT,
  city                TEXT,
  state               TEXT,
  postcode            TEXT,
  country             TEXT DEFAULT 'Malaysia',

  -- Business & Payment
  business_nature     TEXT,
  payment_terms       TEXT,          -- cth '30 Hari'
  credit_limit        NUMERIC(12,2),
  min_order_amount    NUMERIC(12,2),
  lead_time_days      INT,
  bank_name           TEXT,
  bank_account_no     TEXT,
  bank_account_name   TEXT,

  notes               TEXT,

  created_by          UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_by_name     TEXT,
  updated_by          UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  updated_by_name     TEXT,
  created_at          TIMESTAMPTZ DEFAULT now(),
  updated_at          TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_suppliers_status ON psy_suppliers(status);
CREATE INDEX IF NOT EXISTS idx_suppliers_name   ON psy_suppliers(name);

-- ──── supplier_code auto-generate (SUP-0001, SUP-0002, ...) ────
CREATE SEQUENCE IF NOT EXISTS psy_supplier_code_seq START 1;

CREATE OR REPLACE FUNCTION psy_set_supplier_code()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.supplier_code IS NULL THEN
    NEW.supplier_code := 'SUP-' || LPAD(nextval('psy_supplier_code_seq')::text, 4, '0');
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_psy_set_supplier_code ON psy_suppliers;
CREATE TRIGGER trg_psy_set_supplier_code
BEFORE INSERT ON psy_suppliers
FOR EACH ROW EXECUTE FUNCTION psy_set_supplier_code();

-- ──── Contact Persons (satu supplier boleh ada banyak) ────
CREATE TABLE IF NOT EXISTS psy_supplier_contacts (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  supplier_id   UUID NOT NULL REFERENCES psy_suppliers(id) ON DELETE CASCADE,
  name          TEXT NOT NULL,
  position      TEXT,
  phone         TEXT,
  email         TEXT,
  created_at    TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_supplier_contacts_supplier ON psy_supplier_contacts(supplier_id);

-- ──── Documents/Attachments (metadata; fail sebenar di bucket 'supplier-docs') ────
CREATE TABLE IF NOT EXISTS psy_supplier_documents (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  supplier_id       UUID NOT NULL REFERENCES psy_suppliers(id) ON DELETE CASCADE,
  file_name         TEXT NOT NULL,
  file_path         TEXT NOT NULL,   -- path dlm bucket supplier-docs
  file_size         INT,
  uploaded_by_name  TEXT,
  created_at        TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_supplier_documents_supplier ON psy_supplier_documents(supplier_id);

-- Rujukan supplier sebenar dari item (nullable — borang item belum wired,
-- kekal guna supplier_info JSON buat masa ni; kolum ni sedia utk kemudian).
ALTER TABLE psy_inventory_items ADD COLUMN IF NOT EXISTS supplier_id UUID REFERENCES psy_suppliers(id) ON DELETE SET NULL;

-- ──── RLS ────
ALTER TABLE psy_suppliers ENABLE ROW LEVEL SECURITY;
ALTER TABLE psy_supplier_contacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE psy_supplier_documents ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff manage suppliers" ON psy_suppliers;
CREATE POLICY "Staff manage suppliers" ON psy_suppliers FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "Staff manage supplier contacts" ON psy_supplier_contacts;
CREATE POLICY "Staff manage supplier contacts" ON psy_supplier_contacts FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "Staff manage supplier documents" ON psy_supplier_documents;
CREATE POLICY "Staff manage supplier documents" ON psy_supplier_documents FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

COMMENT ON TABLE psy_suppliers IS
  'Supplier sebagai entiti sendiri (P18-20). Asas utk Purchase Orders (P15-17) & filter supplier konsisten merentasi Products/Purchase Requests.';
COMMENT ON COLUMN psy_suppliers.supplier_code IS
  'Kod auto-generate (SUP-0001, ...) via trigger — tidak boleh diedit.';


-- ════════════════════════════════════════════════════════════════
-- schema/34_inventory_locations.sql
-- ════════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════════
-- 34 — INVENTORY LOCATIONS (multi-warehouse stock)
-- Sebelum ni psy_inventory_items.qty_in_stock ialah SATU angka keseluruhan
-- (tiada pecahan ikut gudang). Kini setiap item boleh ada stok berasingan
-- di banyak lokasi (psy_inventory_stock_by_location); qty_in_stock pada
-- psy_inventory_items menjadi AGGREGATE (jumlah semua lokasi), dikekalkan
-- automatik oleh trigger psy_sync_item_stock_total — JANGAN update
-- qty_in_stock terus dari kod aplikasi, sentiasa upsert ke
-- psy_inventory_stock_by_location dan biar trigger kira semula jumlah.
-- ═══════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS psy_inventory_locations (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name        TEXT NOT NULL UNIQUE,
  code        TEXT UNIQUE,
  is_default  BOOLEAN NOT NULL DEFAULT false,
  is_active   BOOLEAN NOT NULL DEFAULT true,
  created_at  TIMESTAMPTZ DEFAULT now()
);

-- Permohonan belian simpan lokasi (rujukan kpd psy_inventory_locations) — ALTER di sini
-- sebab jadual lokasi ditakrif selepas psy_inventory_requests (14_products_inventory.sql).
ALTER TABLE psy_inventory_requests
  ADD COLUMN IF NOT EXISTS location_id UUID REFERENCES psy_inventory_locations(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS idx_inventory_requests_location ON psy_inventory_requests (location_id);

CREATE TABLE IF NOT EXISTS psy_inventory_stock_by_location (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  item_id       UUID NOT NULL REFERENCES psy_inventory_items(id) ON DELETE CASCADE,
  location_id   UUID NOT NULL REFERENCES psy_inventory_locations(id) ON DELETE RESTRICT,
  qty_in_stock  NUMERIC(12,4) NOT NULL DEFAULT 0,
  min_qty       NUMERIC(10,2),
  updated_at    TIMESTAMPTZ DEFAULT now(),
  UNIQUE (item_id, location_id)
);
CREATE INDEX IF NOT EXISTS idx_stock_by_location_item ON psy_inventory_stock_by_location(item_id);

-- 29 Okt 2026 — lebarkan ke 4dp supaya deduct pecahan unit (issue_unit, lihat
-- 14_products_inventory.sql) tak hilang ketepatan (cth 1/30 Gulung = 0.0333).
ALTER TABLE psy_inventory_stock_by_location ALTER COLUMN qty_in_stock TYPE NUMERIC(12,4);

-- ──── Trigger: kekalkan psy_inventory_items.qty_in_stock = SUM semua lokasi ────
CREATE OR REPLACE FUNCTION psy_sync_item_stock_total()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE target_item UUID := COALESCE(NEW.item_id, OLD.item_id);
BEGIN
  UPDATE psy_inventory_items
  SET qty_in_stock = (SELECT COALESCE(SUM(qty_in_stock), 0) FROM psy_inventory_stock_by_location WHERE item_id = target_item)
  WHERE id = target_item;
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_item_stock_total ON psy_inventory_stock_by_location;
CREATE TRIGGER trg_sync_item_stock_total
AFTER INSERT OR UPDATE OR DELETE ON psy_inventory_stock_by_location
FOR EACH ROW EXECUTE FUNCTION psy_sync_item_stock_total();

-- ──── Seed lokasi standard ────
INSERT INTO psy_inventory_locations (name, code, is_default) VALUES
  ('General Inventory',   'GEN',  true),
  ('Clinical Pharmacy',   'PHARM', false),
  ('Shop Warehouse',      'SHOP', false),
  ('Raw Material Store',  'RAW',  false),
  ('Equipment Store',     'EQUIP', false),
  ('Printing',            'PRINT', false)
ON CONFLICT (name) DO NOTHING;

-- ──── Backfill: pindah qty_in_stock sedia ada ke SATU lokasi (ikut source_type) ────
INSERT INTO psy_inventory_stock_by_location (item_id, location_id, qty_in_stock)
SELECT i.id,
       (SELECT id FROM psy_inventory_locations WHERE name = CASE WHEN i.source_type = 'farmasi_klinikal' THEN 'Clinical Pharmacy' ELSE 'General Inventory' END),
       COALESCE(i.qty_in_stock, 0)
FROM psy_inventory_items i
WHERE NOT EXISTS (SELECT 1 FROM psy_inventory_stock_by_location WHERE item_id = i.id);

-- ──── RLS ────
ALTER TABLE psy_inventory_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE psy_inventory_stock_by_location ENABLE ROW LEVEL SECURITY;

-- 29 Okt 2026 — SELECT-sahaja digantikan FOR ALL, supaya staff boleh tambah
-- lokasi baharu terus dari item-form.html ("+ Tambah Lokasi Baharu", cth
-- "Printing") tanpa kena insert manual via SQL/migration setiap kali.
DROP POLICY IF EXISTS "Staff read locations" ON psy_inventory_locations;
DROP POLICY IF EXISTS "Staff manage locations" ON psy_inventory_locations;
CREATE POLICY "Staff manage locations" ON psy_inventory_locations FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "Staff manage stock by location" ON psy_inventory_stock_by_location;
CREATE POLICY "Staff manage stock by location" ON psy_inventory_stock_by_location FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

COMMENT ON TABLE psy_inventory_stock_by_location IS
  'Stok sebenar per (item, lokasi). psy_inventory_items.qty_in_stock ialah jumlah automatik (trigger) — jangan tulis terus, upsert sini.';


-- ════════════════════════════════════════════════════════════════
-- schema/35_stock_in.sql
-- ════════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════════
-- 35 — STOCK IN / RECEIVE
-- Rekod penerimaan stok sebenar (bukan lagi 1 butang "Tandakan Dibeli"
-- je) — setiap penerimaan simpan batch no + expiry date PER PRODUK
-- (psy_stock_in_items), sebab 1 produk boleh ada banyak batch dengan
-- expiry berlainan (stok lama vs baru). "Expiring Soon" di Stock Alerts
-- dikira dari sini, BUKAN dari psy_inventory_items.expiry_date (medan
-- lama, single-value, dikekalkan tapi tak lagi sumber utama).
--
-- Reference: rujuk Purchase Request yang diluluskan (reference_type=
-- 'purchase_request'), ATAU 'manual' (restock terus tanpa PR). BUKAN
-- Purchase Order — modul PO dah dibuang (lihat 32_suppliers.sql nota).
-- Stock In yang dipautkan ke PR & di-post akan auto tanda PR tu
-- 'purchased' (sama kesan macam "Tandakan Dibeli" di PR, tapi dengan
-- rekod batch/expiry/kos sebenar).
-- ═══════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS psy_stock_in_records (
  id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  receive_no         TEXT UNIQUE,
  receive_date       DATE DEFAULT CURRENT_DATE,
  reference_type     TEXT NOT NULL DEFAULT 'manual'
                     CHECK (reference_type IN ('purchase_request','manual')),
  reference_id       UUID REFERENCES psy_inventory_requests(id) ON DELETE SET NULL,
  location_id        UUID NOT NULL REFERENCES psy_inventory_locations(id) ON DELETE RESTRICT,
  status             TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','posted')),
  delivery_note_no   TEXT,
  invoice_no         TEXT,
  transporter        TEXT,
  received_condition TEXT,
  remarks            TEXT,
  subtotal           NUMERIC(12,2) NOT NULL DEFAULT 0,
  tax_amount         NUMERIC(12,2) NOT NULL DEFAULT 0,
  total_cost         NUMERIC(12,2) NOT NULL DEFAULT 0,
  received_by        UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  received_by_name   TEXT,
  posted_at          TIMESTAMPTZ,
  created_at         TIMESTAMPTZ DEFAULT now(),
  updated_at         TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_stock_in_reference ON psy_stock_in_records(reference_id);

-- ──── receive_no auto-generate (RCV-0001, ...) ────
CREATE SEQUENCE IF NOT EXISTS psy_stock_in_no_seq START 1;

CREATE OR REPLACE FUNCTION psy_set_stock_in_no()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.receive_no IS NULL THEN
    NEW.receive_no := 'RCV-' || LPAD(nextval('psy_stock_in_no_seq')::text, 4, '0');
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_psy_set_stock_in_no ON psy_stock_in_records;
CREATE TRIGGER trg_psy_set_stock_in_no
BEFORE INSERT ON psy_stock_in_records
FOR EACH ROW EXECUTE FUNCTION psy_set_stock_in_no();

-- ──── Line items (batch/expiry per produk per penerimaan) ────
CREATE TABLE IF NOT EXISTS psy_stock_in_items (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  stock_in_id    UUID NOT NULL REFERENCES psy_stock_in_records(id) ON DELETE CASCADE,
  item_id        UUID REFERENCES psy_inventory_items(id) ON DELETE SET NULL,
  item_name      TEXT NOT NULL,
  batch_no       TEXT,
  expiry_date    DATE,
  qty_received   NUMERIC(10,2) NOT NULL,
  unit_cost      NUMERIC(10,2) NOT NULL DEFAULT 0,
  subtotal       NUMERIC(12,2) NOT NULL DEFAULT 0,
  created_at     TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_stock_in_items_record ON psy_stock_in_items(stock_in_id);
CREATE INDEX IF NOT EXISTS idx_stock_in_items_item ON psy_stock_in_items(item_id);
CREATE INDEX IF NOT EXISTS idx_stock_in_items_expiry ON psy_stock_in_items(expiry_date) WHERE expiry_date IS NOT NULL;

-- ──── Attachments (delivery note, invoice, dll.) ────
CREATE TABLE IF NOT EXISTS psy_stock_in_documents (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  stock_in_id       UUID NOT NULL REFERENCES psy_stock_in_records(id) ON DELETE CASCADE,
  file_name         TEXT NOT NULL,
  file_path         TEXT NOT NULL,
  file_size         INT,
  uploaded_by_name  TEXT,
  created_at        TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_stock_in_documents_record ON psy_stock_in_documents(stock_in_id);

-- ──── RLS ────
ALTER TABLE psy_stock_in_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE psy_stock_in_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE psy_stock_in_documents ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff manage stock in records" ON psy_stock_in_records;
CREATE POLICY "Staff manage stock in records" ON psy_stock_in_records FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "Staff manage stock in items" ON psy_stock_in_items;
CREATE POLICY "Staff manage stock in items" ON psy_stock_in_items FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "Staff manage stock in documents" ON psy_stock_in_documents;
CREATE POLICY "Staff manage stock in documents" ON psy_stock_in_documents FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

COMMENT ON TABLE psy_stock_in_records IS
  'Rekod penerimaan stok sebenar — post akan tambah stok ke psy_inventory_stock_by_location & tanda PR (jika ada rujukan) sebagai purchased.';


-- ════════════════════════════════════════════════════════════════
-- schema/36_stock_movements.sql
-- ════════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════════
-- 36 — STOCK MOVEMENTS (ledger)
-- Rekod SETIAP perubahan stok (IN/OUT/ADJUSTMENT) merentasi semua punca:
-- Stock In (posted), Quick "Tandakan Dibeli", Stock Adjustment (manual),
-- Opening Stock (produk baharu), auto-deduct sesi pesakit. Ditulis SECARA
-- BERPUSAT dalam shared/inventoryStock.js addStockToLocation() — jangan
-- insert terus dari page, sentiasa lalu fungsi tu supaya ledger konsisten
-- dgn psy_inventory_stock_by_location (sumber kebenaran qty_in_stock).
--
-- Dipakai oleh roles/staff/inventory-overview.html ("Recent Stock
-- Movements") — kalau kod baharu ubah stok tanpa lalu addStockToLocation(),
-- ia TIDAK akan muncul di sini (dan qty_in_stock aggregate boleh out-of-sync,
-- lihat nota 34_inventory_locations.sql).
-- ═══════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS psy_stock_movements (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  item_id          UUID REFERENCES psy_inventory_items(id) ON DELETE SET NULL,
  item_name        TEXT,
  location_id      UUID REFERENCES psy_inventory_locations(id) ON DELETE SET NULL,
  movement_type    TEXT NOT NULL CHECK (movement_type IN ('in','out','adjustment')),
  qty              NUMERIC(12,4) NOT NULL,  -- delta bertanda: +masuk, -keluar
  balance_after    NUMERIC(12,4),  -- baki stok di lokasi tu SELEPAS movement ni (utk kolum "Balance After")
  reference_type   TEXT,   -- 'stock_in' | 'purchase_request' | 'adjustment' | 'opening_stock' | 'patient_package' | 'transfer'
  reference_id     UUID,
  reference_label  TEXT,   -- KOD rujukan sahaja bila ada, cth: 'RCV-0001', 'PR-0004' (bukan free text)
  notes            TEXT,   -- penerangan bebas, cth: sebab adjustment, 'Sesi minggu 3', 'Pindah → Shop Warehouse'
  actor_id         UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  actor_name       TEXT,
  created_at       TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_stock_movements_item ON psy_stock_movements(item_id);
CREATE INDEX IF NOT EXISTS idx_stock_movements_created ON psy_stock_movements(created_at DESC);

-- 29 Okt 2026 — lebarkan ke 4dp (sama sebab di 34_inventory_locations.sql).
ALTER TABLE psy_stock_movements ALTER COLUMN qty TYPE NUMERIC(12,4);
ALTER TABLE psy_stock_movements ALTER COLUMN balance_after TYPE NUMERIC(12,4);

ALTER TABLE psy_stock_movements ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff manage stock movements" ON psy_stock_movements;
CREATE POLICY "Staff manage stock movements" ON psy_stock_movements FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

COMMENT ON TABLE psy_stock_movements IS
  'Ledger setiap perubahan stok — ditulis berpusat dalam addStockToLocation() (shared/inventoryStock.js). Sumber "Recent Stock Movements" di Inventory Overview.';


-- ════════════════════════════════════════════════════════════════
-- schema/37_automation_sequences.sql
-- ════════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════════
-- 37 — AUTOMATION SEQUENCES (psy_automation_messages)
-- Sokongan "sequence" berbilang mesej bagi SATU automasi (perjalanan
-- pesakit hari-demi-hari, cth Minggu 1 Hari 1/2/3...). Trigger
-- 'schedule' (Broadcast Berjadual) KEKAL guna psy_automations.message_template
-- sedia ada — jadual ini untuk trigger lain (cth patient_enrolled).
-- ═══════════════════════════════════════════════════════════════════

create table if not exists psy_automation_messages (
  id uuid primary key default gen_random_uuid(),
  automation_id uuid not null references psy_automations(id) on delete cascade,
  position int not null,
  -- BILA hantar (relatif ke anchor automasi, cth psy_treatment_plans.start_date)
  send_mode text not null default 'specific_time',   -- immediate | after_delay | specific_time
  day_offset int not null default 0,                 -- Hari ke-N sejak anchor (0 = hari sama)
  delay_value int,                                    -- utk send_mode='after_delay'
  delay_unit text,                                    -- minute | hour | day
  send_time time,                                     -- utk send_mode='specific_time' (jam:minit)
  -- APA hantar
  content_type text not null default 'text',          -- text | image | video | link
  message_text text not null default '',
  media_url text,                                     -- imej/video (attachment WhatsApp)
  link_url text,                                       -- pautan (dihantar sbg teks, BUKAN butang — GHL tiada sokongan butang)
  link_label text,
  attach_invoice boolean not null default false,       -- lampirkan PDF invois (hanya trigger ansuran — perlu {{pautan}} dlm teks)
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create index if not exists idx_psy_auto_msgs_automation on psy_automation_messages(automation_id, position);

alter table psy_automation_messages enable row level security;

drop policy if exists "auto_msgs staff read" on psy_automation_messages;
create policy "auto_msgs staff read" on psy_automation_messages for select
  using (auth.uid() in (select id from psy_profiles where role = 'staff'));

drop policy if exists "auto_msgs mgr manage" on psy_automation_messages;
create policy "auto_msgs mgr manage" on psy_automation_messages for all
  using (auth.uid() in (select id from psy_profiles where staff_role in ('super_admin','manager')))
  with check (auth.uid() in (select id from psy_profiles where staff_role in ('super_admin','manager')));

-- Kaitkan log hantaran dengan mesej tertentu dalam sequence (dedup + statistik per-mesej).
-- NULL utk log lama/broadcast tunggal (message_template).
alter table psy_notification_logs add column if not exists message_id uuid references psy_automation_messages(id) on delete set null;

create index if not exists idx_psy_notif_logs_message on psy_notification_logs(message_id);


-- ════════════════════════════════════════════════════════════════
-- schema/38_automation_recipient.sql
-- ════════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════════
-- 38 — AUTOMATION MESSAGE RECIPIENT (patient | coach)
-- Bagi mesej sequence (psy_automation_messages) boleh ditujukan kepada
-- coach pesakit (cth eskalasi Sesi Confirm) bukan pesakit itu sendiri.
-- ═══════════════════════════════════════════════════════════════════

alter table psy_automation_messages
  add column if not exists recipient text not null default 'patient'
  check (recipient in ('patient', 'coach'));


-- ════════════════════════════════════════════════════════════════
-- schema/39_recommended_directory.sql
-- ════════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════════
-- 39 — MASTER PRODUK & BAHAN (Barang + Kedai Makan)
-- Audit management 23 Sept 2026, Tier 5 batch 2 module VI & VII — 2 modul
-- BAHARU sepenuhnya (disahkan tiada langsung dlm sistem masa audit).
-- REDESIGN 7 Okt 2026 #1: Seller/Platform jadi entiti MASTER berasingan
-- (senarai + detail tersendiri, dikongsi merentas produk) — bukan lagi
-- teks platform/nama-seller bebas diulang setiap baris dalam tiap produk.
-- REDESIGN 7 Okt 2026 #2: Direktori Cadangan (Restoran/Tempat Makan)
-- DIGABUNG terus ke psy_recommended_products lewat kolum `item_type`
-- ('barang' | 'kedai_makan') — SATU jadual + SATU senarai + SATU borang
-- (borang tukar medan ikut kategori dipilih). Jadual psy_recommended_restaurants
-- + halaman direktori-cadangan.html DIBUANG (data dipindah masuk — lihat
-- migration 20261007_merge_restaurant_into_products.sql).
--
-- Jadual: psy_recommended_sellers, psy_recommended_products,
--         psy_recommended_product_sellers, psy_package_recommended_products
--
-- BEZA drpd modul sedia ada (penting, jangan campur):
--   - psy_products (Produk Shop) = ISW SENDIRI jual & hantar. Jadual ni
--     SEBALIKNYA — barang yang ISW TAK jual, pesakit kena cari/beli sendiri
--     di luar (cth herba/suplemen tertentu utk minggu tertentu dlm pakej),
--     ATAU cadangan kedai makan luar (item_type='kedai_makan').
--   - psy_suppliers = vendor ISW beli DARI utk stok ISW sendiri (procurement
--     dalaman). psy_recommended_sellers pula cadangan tempat/seller PESAKIT
--     beli (Shopee/Lazada/kedai fizikal dll) — entiti berasingan sepenuhnya,
--     tiada kaitan stok/procurement ISW. Seller/Platform HANYA relevan utk
--     item_type='barang' — kedai makan tiada konsep "beli dari seller".
-- ═══════════════════════════════════════════════════════════════════

-- ──── psy_recommended_sellers (Master Seller / Platform) ────
CREATE TABLE IF NOT EXISTS psy_recommended_sellers (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name              TEXT NOT NULL,        -- nama seller/kedai, cth "ABC Fitness Store"
  platform          TEXT,                 -- cth Shopee / Lazada / Website / Kedai Fizikal
  link              TEXT,                 -- pautan kedai/storefront umum seller
  seller_type       TEXT,                 -- cth "Kedai rasmi / Authorised reseller"
  description       TEXT,                 -- deskripsi/penerangan seller (dipaparkan di Ringkasan)
  logo_url          TEXT,
  contact_email     TEXT,
  contact_phone     TEXT,
  address           TEXT,
  notes             TEXT,                 -- nota dalaman (berasingan drpd description)
  status            TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active','inactive')),
  last_verified_at  TIMESTAMPTZ,
  verified_by       UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  created_by        UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  updated_by        UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  created_at        TIMESTAMPTZ DEFAULT now(),
  updated_at        TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_rec_sellers_status ON psy_recommended_sellers(status);
CREATE INDEX IF NOT EXISTS idx_rec_sellers_platform ON psy_recommended_sellers(platform);

ALTER TABLE psy_recommended_sellers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff manage recommended sellers" ON psy_recommended_sellers;
CREATE POLICY "Staff manage recommended sellers" ON psy_recommended_sellers FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
  WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- ──── psy_recommended_products (Master Produk & Bahan — Barang + Kedai Makan) ────
CREATE TABLE IF NOT EXISTS psy_recommended_products (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  item_type         TEXT NOT NULL DEFAULT 'barang'
                    CHECK (item_type IN ('barang','kedai_makan')),
  name              TEXT NOT NULL,         -- nama produk ATAU nama restoran/tempat makan
  category          TEXT,                  -- barang: tak dipaparkan dlm UI semasa. kedai_makan: cth Halal/Vegetarian/Healthy Food
  purpose           TEXT,                  -- barang: "Tujuan/Kegunaan". kedai_makan: "Nota/Tujuan Cadangan"
  qty_note          TEXT,                  -- "Kuantiti Asas" (barang sahaja, teks bebas cth "1 unit")
  requirement_level TEXT NOT NULL DEFAULT 'cadangan'
                    CHECK (requirement_level IN ('wajib','cadangan','opsyenal')),  -- barang sahaja
  price             NUMERIC(10,2),  -- LEGACY, dibuang drpd UI (commit 29f11820) — harga kini per-seller (psy_recommended_product_sellers.price)
  image_url         TEXT,        -- gambar utama (= image_urls[0]), sama corak dgn psy_products
  image_urls        JSONB DEFAULT '[]',  -- gallery multi-gambar (7 Okt 2026)
  notes             TEXT,
  is_active         BOOLEAN NOT NULL DEFAULT true,
  last_verified_at  TIMESTAMPTZ,
  -- medan khusus kedai_makan (null utk barang) — digabung dari psy_recommended_restaurants 7 Okt 2026
  address           TEXT,        -- Alamat / Lokasi
  area              TEXT,        -- Kawasan / Bandar
  maps_url          TEXT,        -- pautan Google Maps / Waze
  contact_phone     TEXT,        -- No. Telefon
  website           TEXT,        -- Website (jika ada)
  operating_hours   TEXT,        -- Waktu Operasi (cth "9:00 AM - 10:00 PM (Setiap Hari)")
  menu_items        JSONB DEFAULT '[]',  -- Menu / Hidangan Cadangan — array [{name, image_url}], gambar opsyenal per-item
  price_range       TEXT,        -- Julat Harga (opsyenal, cth "RM10-20") — legacy drpd psy_recommended_restaurants
  created_by        UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  updated_by        UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  created_at        TIMESTAMPTZ DEFAULT now(),
  updated_at        TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_rec_products_active ON psy_recommended_products(is_active);
CREATE INDEX IF NOT EXISTS idx_rec_products_item_type ON psy_recommended_products(item_type);

ALTER TABLE psy_recommended_products ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff manage recommended products" ON psy_recommended_products;
CREATE POLICY "Staff manage recommended products" ON psy_recommended_products FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
  WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- ──── psy_recommended_product_sellers (pautan produk ↔ seller master, multi per produk) ────
CREATE TABLE IF NOT EXISTS psy_recommended_product_sellers (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id        UUID NOT NULL REFERENCES psy_recommended_products(id) ON DELETE CASCADE,
  seller_id         UUID NOT NULL REFERENCES psy_recommended_sellers(id) ON DELETE CASCADE,
  link              TEXT,   -- pautan beli KHUSUS produk ni (boleh beza drpd storefront umum seller)
  price             NUMERIC(10,2),
  is_primary        BOOLEAN NOT NULL DEFAULT false,  -- seller utama/disyorkan utk produk ni
  last_verified_at  TIMESTAMPTZ,
  notes             TEXT,
  sort_order        INT DEFAULT 0,
  created_at        TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_rec_prod_sellers_product ON psy_recommended_product_sellers(product_id);
CREATE INDEX IF NOT EXISTS idx_rec_prod_sellers_seller ON psy_recommended_product_sellers(seller_id);
CREATE UNIQUE INDEX IF NOT EXISTS uq_rec_product_seller ON psy_recommended_product_sellers(product_id, seller_id);

ALTER TABLE psy_recommended_product_sellers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff manage recommended product sellers" ON psy_recommended_product_sellers;
CREATE POLICY "Staff manage recommended product sellers" ON psy_recommended_product_sellers FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
  WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- ──── psy_package_recommended_products (pautan item ↔ pakej ↔ minggu) ────
-- package_id ialah TEXT (psy_packages.package_id, kod perniagaan cth "OBDY1")
-- — SAMA konvensyen dgn psy_promo_codes.applies_to_values/psy_announcements.
-- package_ids (bukan psy_packages.id UUID) supaya konsisten dgn cara pakej
-- dirujuk merentas modul lain (rujuk memori project_active_package_id_gotcha).
CREATE TABLE IF NOT EXISTS psy_package_recommended_products (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  package_id  TEXT NOT NULL,
  product_id  UUID NOT NULL REFERENCES psy_recommended_products(id) ON DELETE CASCADE,
  week_number INT,   -- NULL = terpakai sepanjang pakej (bukan minggu tertentu)
  qty         INT DEFAULT 1,   -- kuantiti diperlukan pada minggu/pakej ni
  notes       TEXT,            -- nota pemetaan (cth "Digunakan untuk aktiviti asas.")
  created_at  TIMESTAMPTZ DEFAULT now(),
  UNIQUE (package_id, product_id, week_number)
);

CREATE INDEX IF NOT EXISTS idx_rec_pkg_map_package ON psy_package_recommended_products(package_id);
CREATE INDEX IF NOT EXISTS idx_rec_pkg_map_product ON psy_package_recommended_products(product_id);

ALTER TABLE psy_package_recommended_products ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff manage package recommended products" ON psy_package_recommended_products;
CREATE POLICY "Staff manage package recommended products" ON psy_package_recommended_products FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
  WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- psy_recommended_restaurants DIBUANG 7 Okt 2026 — digabung ke
-- psy_recommended_products (item_type='kedai_makan'). Lihat migration
-- 20261007_merge_restaurant_into_products.sql untuk pemindahan data.


-- ════════════════════════════════════════════════════════════════
-- schema/40_equipment.sql
-- ════════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════════
-- 40 — EQUIPMENT STORE + PERMINTAAN MAINTENANCE
-- psy_equipment: rekod peralatan (berasingan dari item inventori)
-- psy_equipment_documents: lampiran (invois, waranti, manual, foto)
-- psy_equipment_maintenance: staf lapor masalah → manager lulus/tolak → selesai
-- Kod peralatan (EQ-0001...) & no. permohonan (MR-2026-00001...) dijana DB.
-- Asal: migration 20261008-20261012 (digabung ke schema bersih).
-- ═══════════════════════════════════════════════════════════════════

CREATE SEQUENCE IF NOT EXISTS psy_equipment_code_seq;
CREATE SEQUENCE IF NOT EXISTS psy_maint_request_seq;

CREATE TABLE IF NOT EXISTS psy_equipment (
  id                       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name                     TEXT NOT NULL,
  code                     TEXT UNIQUE DEFAULT 'EQ-' || lpad(nextval('psy_equipment_code_seq')::text, 4, '0'),
  location_id              UUID REFERENCES psy_inventory_locations(id) ON DELETE SET NULL,
  category                 TEXT,
  brand                    TEXT,
  model                    TEXT,
  serial_no                TEXT,
  description              TEXT,
  purchase_date            DATE,
  purchase_cost            NUMERIC(12,2),
  warranty_expiry          DATE,
  condition                TEXT CHECK (condition IS NULL OR condition IN ('good','fair','poor')),
  supplier                 TEXT,
  supplier_id              UUID REFERENCES psy_suppliers(id) ON DELETE SET NULL,
  invoice_no               TEXT,
  po_no                    TEXT,
  remarks                  TEXT,
  assigned_to_name         TEXT,
  last_service_date        DATE,
  next_maintenance_date    DATE,
  maintenance_cycle_months INT,
  maintenance_remarks      TEXT,
  image_url                TEXT,
  status                   TEXT NOT NULL DEFAULT 'available'
                           CHECK (status IN ('available','in_use','under_maintenance','damaged','lost','retired')),
  notes                    TEXT,
  created_at               TIMESTAMPTZ DEFAULT now(),
  updated_at               TIMESTAMPTZ DEFAULT now()
);

-- 5 Nov 2026 — supplier_id FK (equipment-add.html Pembekal kini dropdown dari
-- psy_suppliers, bukan free text) — kolum `supplier` TEXT lama DIKEKALKAN
-- (equipment-detail.html papar terus drpd situ, tiada join perlu), cuma
-- diisi dari nama supplier yg dipilih.
ALTER TABLE psy_equipment ADD COLUMN IF NOT EXISTS supplier_id UUID REFERENCES psy_suppliers(id) ON DELETE SET NULL;

CREATE TABLE IF NOT EXISTS psy_equipment_documents (
  id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  equipment_id       UUID NOT NULL REFERENCES psy_equipment(id) ON DELETE CASCADE,
  file_name          TEXT NOT NULL,
  file_path          TEXT NOT NULL,
  file_size          BIGINT,
  file_type          TEXT,
  uploaded_by        UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  uploaded_by_name   TEXT,
  created_at         TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS psy_equipment_maintenance (
  id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  equipment_id       UUID NOT NULL REFERENCES psy_equipment(id) ON DELETE CASCADE,
  request_no         TEXT UNIQUE
                     DEFAULT 'MR-' || to_char(now(), 'YYYY') || '-' || lpad(nextval('psy_maint_request_seq')::text, 5, '0'),
  issue              TEXT NOT NULL,
  request_type       TEXT,
  issue_category     TEXT,
  priority           TEXT CHECK (priority IS NULL OR priority IN ('low','medium','high','urgent')),
  preferred_date     DATE,
  notes              TEXT,
  photo_url          TEXT,
  status             TEXT NOT NULL DEFAULT 'baru'
                     CHECK (status IN ('baru','diluluskan','dalam_servis','selesai','ditolak')),
  reported_by        UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  reported_by_name   TEXT,
  manager_note       TEXT,
  handled_by         UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  handled_by_name    TEXT,
  handled_at         TIMESTAMPTZ,
  scheduled_date     DATE,
  created_at         TIMESTAMPTZ DEFAULT now(),
  updated_at         TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_equip_maint_status    ON psy_equipment_maintenance (status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_equip_maint_equipment ON psy_equipment_maintenance (equipment_id);
CREATE INDEX IF NOT EXISTS idx_equip_docs_equipment  ON psy_equipment_documents (equipment_id);

ALTER TABLE psy_equipment             ENABLE ROW LEVEL SECURITY;
ALTER TABLE psy_equipment_documents   ENABLE ROW LEVEL SECURITY;
ALTER TABLE psy_equipment_maintenance ENABLE ROW LEVEL SECURITY;

-- Staff boleh baca peralatan
DROP POLICY IF EXISTS "staff read equipment" ON psy_equipment;
CREATE POLICY "staff read equipment" ON psy_equipment FOR SELECT
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- Manager/admin urus peralatan (tambah, ubah)
DROP POLICY IF EXISTS "manager manage equipment" ON psy_equipment;
CREATE POLICY "manager manage equipment" ON psy_equipment FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff' AND staff_role IN ('super_admin','admin','manager')))
  WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff' AND staff_role IN ('super_admin','admin','manager')));

-- Staff boleh baca & lapor masalah
DROP POLICY IF EXISTS "staff read maintenance" ON psy_equipment_maintenance;
CREATE POLICY "staff read maintenance" ON psy_equipment_maintenance FOR SELECT
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "staff report maintenance" ON psy_equipment_maintenance;
CREATE POLICY "staff report maintenance" ON psy_equipment_maintenance FOR INSERT
  WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff') AND reported_by = auth.uid());

-- Manager/admin kemaskini status (lulus/tolak/selesai)
DROP POLICY IF EXISTS "manager update maintenance" ON psy_equipment_maintenance;
CREATE POLICY "manager update maintenance" ON psy_equipment_maintenance FOR UPDATE
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff' AND staff_role IN ('super_admin','admin','manager')))
  WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff' AND staff_role IN ('super_admin','admin','manager')));

-- Lampiran dokumen
DROP POLICY IF EXISTS "staff read equipment docs" ON psy_equipment_documents;
CREATE POLICY "staff read equipment docs" ON psy_equipment_documents FOR SELECT
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "manager manage equipment docs" ON psy_equipment_documents;
CREATE POLICY "manager manage equipment docs" ON psy_equipment_documents FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff' AND staff_role IN ('super_admin','admin','manager')))
  WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff' AND staff_role IN ('super_admin','admin','manager')));

-- ───────────────────────────────────────────────────────────────────
-- RBAC: modul 'equipment' (Equipment Store)
-- Coach: lihat + lapor masalah. Manager/Admin/Super Admin: view, create, edit.
-- ───────────────────────────────────────────────────────────────────
INSERT INTO psy_modules (code, label, icon, scope, sort_order) VALUES
  ('equipment', 'Equipment Store', '🛠️', 'staff', 112)
ON CONFLICT (code) DO UPDATE SET label = EXCLUDED.label, icon = EXCLUDED.icon;

INSERT INTO psy_module_actions (module_code, action_code) VALUES
  ('equipment', 'view'), ('equipment', 'create'), ('equipment', 'edit')
ON CONFLICT DO NOTHING;

INSERT INTO psy_role_module_actions (role_code, module_code, action_code) VALUES
  ('coach',       'equipment', 'view'),
  ('coach',       'equipment', 'create'),
  ('manager',     'equipment', 'view'),
  ('manager',     'equipment', 'create'),
  ('manager',     'equipment', 'edit'),
  ('admin',       'equipment', 'view'),
  ('admin',       'equipment', 'create'),
  ('admin',       'equipment', 'edit'),
  ('super_admin', 'equipment', 'view'),
  ('super_admin', 'equipment', 'create'),
  ('super_admin', 'equipment', 'edit')
ON CONFLICT DO NOTHING;


-- ════════════════════════════════════════════════════════════════
-- schema/41_missions.sql
-- ════════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════════
-- 41 — MISSION (GANJARAN MATA)
-- Jadual: psy_missions, psy_mission_progress.
-- Fungsi: advance_my_mission(), claim_mission_reward().
-- Trigger: trg_advance_daily_checkin_missions (pada psy_kepatuhan_log).
-- Fasa 6 (teras: jadual + enjin, skop MVP). Keputusan terkunci (7 Okt 2026):
--   • mission_type 'daily_checkin' = AUTOMATIK (trigger bila pesakit isi
--     Catatan Harian, psy_kepatuhan_log). Dipilih sebab data bersih &
--     UNIQUE(patient_id, log_date) sedia ada — selamat & tepat.
--   • mission_type 'manual' = pesakit tekan butang sendiri (RPC
--     advance_my_mission), had SEKALI sehari (last_advanced_on).
--   • Attend Session / Medical Checkup / Complete Profile automatik —
--     BELUM dibina dalam v1 ni (perlu hook pada 3 modul berasingan,
--     sengaja ditangguh supaya teras boleh diuji dulu). Staff boleh
--     guna 'manual' buat sementara utk jenis mission ni.
--   • Ganjaran mata TAK auto masuk bila progress cukup — status jadi
--     'completed' dulu, pesakit kena tekan "Tuntut" (claim_mission_reward)
--     sebelum mata masuk psy_points_ledger. Elak duplicate via status guard.
-- ═══════════════════════════════════════════════════════════════════

-- ──── psy_missions ────
CREATE TABLE IF NOT EXISTS psy_missions (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name                  TEXT NOT NULL,
  description           TEXT,
  mission_type          TEXT NOT NULL DEFAULT 'manual' CHECK (mission_type IN ('daily_checkin', 'manual')),
  target                INT NOT NULL DEFAULT 1 CHECK (target > 0),
  reward_points         INT NOT NULL DEFAULT 0 CHECK (reward_points >= 0),
  repeat_cycle          TEXT NOT NULL DEFAULT 'none' CHECK (repeat_cycle IN ('none', 'weekly')),
  customer_eligibility  TEXT NOT NULL DEFAULT 'all' CHECK (customer_eligibility IN ('all', 'new', 'existing')),
  start_date            DATE,
  end_date              DATE,
  is_active             BOOLEAN NOT NULL DEFAULT true,
  created_by            UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  created_at            TIMESTAMPTZ DEFAULT now(),
  updated_at            TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE psy_missions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone read active missions" ON psy_missions;
CREATE POLICY "Anyone read active missions" ON psy_missions FOR SELECT USING (true);

DROP POLICY IF EXISTS "Staff manage missions" ON psy_missions;
CREATE POLICY "Staff manage missions" ON psy_missions
  FOR ALL USING      (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
           WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- ──── psy_mission_progress ────
-- cycle_start: sentinel '2000-01-01' utk mission 'none' (bukan NULL — NULL
-- buat UNIQUE tak boleh percaya, sebab Postgres anggap tiap NULL lain-lain).
-- Utk 'weekly', cycle_start = Isnin minggu bila progress pertama dibuat.
CREATE TABLE IF NOT EXISTS psy_mission_progress (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  mission_id        UUID NOT NULL REFERENCES psy_missions(id) ON DELETE CASCADE,
  patient_id        UUID NOT NULL REFERENCES psy_patients(id) ON DELETE CASCADE,
  cycle_start       DATE NOT NULL DEFAULT '2000-01-01',
  progress          INT NOT NULL DEFAULT 0,
  status            TEXT NOT NULL DEFAULT 'in_progress' CHECK (status IN ('in_progress', 'completed', 'claimed')),
  last_advanced_on  DATE,
  completed_at      TIMESTAMPTZ,
  claimed_at        TIMESTAMPTZ,
  created_at        TIMESTAMPTZ DEFAULT now(),
  updated_at        TIMESTAMPTZ DEFAULT now(),
  UNIQUE (mission_id, patient_id, cycle_start)
);

CREATE INDEX IF NOT EXISTS idx_mission_progress_patient ON psy_mission_progress(patient_id, status);

ALTER TABLE psy_mission_progress ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Patients view own mission progress" ON psy_mission_progress;
CREATE POLICY "Patients view own mission progress" ON psy_mission_progress FOR SELECT
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Staff view all mission progress" ON psy_mission_progress;
CREATE POLICY "Staff view all mission progress" ON psy_mission_progress FOR SELECT
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
-- TIADA INSERT/UPDATE policy pesakit sengaja — semua tulisan lalui
-- advance_my_mission()/claim_mission_reward() (SECURITY DEFINER) atau trigger.

-- ──── advance_my_mission(): pesakit sendiri tekan "selesai hari ini" (mission_type='manual') ────
CREATE OR REPLACE FUNCTION advance_my_mission(p_mission_id UUID)
RETURNS psy_mission_progress
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_patient_id UUID;
  v_mission    psy_missions%ROWTYPE;
  v_cycle      DATE;
  v_row        psy_mission_progress%ROWTYPE;
BEGIN
  SELECT id INTO v_patient_id FROM psy_patients WHERE user_id = auth.uid() LIMIT 1;
  IF v_patient_id IS NULL THEN RAISE EXCEPTION 'Rekod pesakit tidak dijumpai.'; END IF;

  SELECT * INTO v_mission FROM psy_missions WHERE id = p_mission_id;
  IF v_mission.id IS NULL OR NOT v_mission.is_active THEN RAISE EXCEPTION 'Mission tidak sah.'; END IF;
  IF v_mission.mission_type <> 'manual' THEN RAISE EXCEPTION 'Mission ini dikemaskini automatik, bukan secara manual.'; END IF;
  IF v_mission.start_date IS NOT NULL AND CURRENT_DATE < v_mission.start_date THEN RAISE EXCEPTION 'Mission belum bermula.'; END IF;
  IF v_mission.end_date IS NOT NULL AND CURRENT_DATE > v_mission.end_date THEN RAISE EXCEPTION 'Mission sudah tamat.'; END IF;

  v_cycle := CASE WHEN v_mission.repeat_cycle = 'weekly' THEN date_trunc('week', CURRENT_DATE)::date ELSE DATE '2000-01-01' END;

  INSERT INTO psy_mission_progress (mission_id, patient_id, cycle_start)
  VALUES (p_mission_id, v_patient_id, v_cycle)
  ON CONFLICT (mission_id, patient_id, cycle_start) DO NOTHING;

  SELECT * INTO v_row FROM psy_mission_progress
    WHERE mission_id = p_mission_id AND patient_id = v_patient_id AND cycle_start = v_cycle;

  IF v_row.status IN ('completed', 'claimed') THEN RAISE EXCEPTION 'Mission ini sudah selesai untuk tempoh semasa.'; END IF;
  IF v_row.last_advanced_on = CURRENT_DATE THEN RAISE EXCEPTION 'Anda sudah kemaskini mission ini hari ini.'; END IF;

  UPDATE psy_mission_progress SET
    progress = LEAST(v_mission.target, progress + 1),
    last_advanced_on = CURRENT_DATE,
    status = CASE WHEN progress + 1 >= v_mission.target THEN 'completed' ELSE 'in_progress' END,
    completed_at = CASE WHEN progress + 1 >= v_mission.target THEN now() ELSE completed_at END,
    updated_at = now()
  WHERE id = v_row.id
  RETURNING * INTO v_row;

  RETURN v_row;
END;
$$;

GRANT EXECUTE ON FUNCTION advance_my_mission(UUID) TO authenticated;

-- ──── claim_mission_reward(): tuntut mata bila status='completed' ────
CREATE OR REPLACE FUNCTION claim_mission_reward(p_progress_id UUID)
RETURNS psy_mission_progress
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_patient_id UUID;
  v_row        psy_mission_progress%ROWTYPE;
  v_mission    psy_missions%ROWTYPE;
BEGIN
  SELECT id INTO v_patient_id FROM psy_patients WHERE user_id = auth.uid() LIMIT 1;
  IF v_patient_id IS NULL THEN RAISE EXCEPTION 'Rekod pesakit tidak dijumpai.'; END IF;

  SELECT * INTO v_row FROM psy_mission_progress WHERE id = p_progress_id AND patient_id = v_patient_id;
  IF v_row.id IS NULL THEN RAISE EXCEPTION 'Progress mission tidak dijumpai.'; END IF;
  IF v_row.status = 'claimed' THEN RAISE EXCEPTION 'Ganjaran ini sudah dituntut.'; END IF;
  IF v_row.status <> 'completed' THEN RAISE EXCEPTION 'Mission belum selesai.'; END IF;

  SELECT * INTO v_mission FROM psy_missions WHERE id = v_row.mission_id;

  UPDATE psy_mission_progress SET status = 'claimed', claimed_at = now(), updated_at = now()
  WHERE id = p_progress_id RETURNING * INTO v_row;

  IF v_mission.reward_points > 0 THEN
    INSERT INTO psy_points_ledger (patient_id, source_type, source_ref, points, note)
    VALUES (v_patient_id, 'mission_complete', v_row.id, v_mission.reward_points, 'Mission selesai: ' || v_mission.name);
  END IF;

  RETURN v_row;
END;
$$;

GRANT EXECUTE ON FUNCTION claim_mission_reward(UUID) TO authenticated;

-- ──── Trigger automatik: mission_type='daily_checkin' bila Catatan Harian diisi ────
CREATE OR REPLACE FUNCTION trg_advance_daily_checkin_missions()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_mission  RECORD;
  v_cycle    DATE;
  v_has_paid BOOLEAN;
BEGIN
  FOR v_mission IN
    SELECT * FROM psy_missions
    WHERE mission_type = 'daily_checkin' AND is_active
      AND (start_date IS NULL OR start_date <= NEW.log_date)
      AND (end_date IS NULL OR end_date >= NEW.log_date)
  LOOP
    IF v_mission.customer_eligibility IN ('new', 'existing') THEN
      SELECT EXISTS (SELECT 1 FROM psy_payments WHERE patient_id = NEW.patient_id AND status = 'completed') INTO v_has_paid;
      IF v_mission.customer_eligibility = 'new' AND v_has_paid THEN CONTINUE; END IF;
      IF v_mission.customer_eligibility = 'existing' AND NOT v_has_paid THEN CONTINUE; END IF;
    END IF;

    v_cycle := CASE WHEN v_mission.repeat_cycle = 'weekly' THEN date_trunc('week', NEW.log_date)::date ELSE DATE '2000-01-01' END;

    INSERT INTO psy_mission_progress (mission_id, patient_id, cycle_start)
    VALUES (v_mission.id, NEW.patient_id, v_cycle)
    ON CONFLICT (mission_id, patient_id, cycle_start) DO NOTHING;

    UPDATE psy_mission_progress SET
      progress = LEAST(v_mission.target, progress + 1),
      last_advanced_on = NEW.log_date,
      status = CASE WHEN status = 'in_progress' AND progress + 1 >= v_mission.target THEN 'completed' ELSE status END,
      completed_at = CASE WHEN status = 'in_progress' AND progress + 1 >= v_mission.target THEN now() ELSE completed_at END,
      updated_at = now()
    WHERE mission_id = v_mission.id AND patient_id = NEW.patient_id AND cycle_start = v_cycle
      AND status = 'in_progress' AND (last_advanced_on IS DISTINCT FROM NEW.log_date);
  END LOOP;
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE LOG 'trg_advance_daily_checkin_missions: %', SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_advance_daily_checkin_missions ON psy_kepatuhan_log;
CREATE TRIGGER trg_advance_daily_checkin_missions
  AFTER INSERT ON psy_kepatuhan_log
  FOR EACH ROW EXECUTE FUNCTION trg_advance_daily_checkin_missions();


-- ════════════════════════════════════════════════════════════════
-- schema/42_supply_invoices.sql
-- ════════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════════
-- 42 — SUPPLY INVOICES (invois bekalan produk kepada pesakit)
-- Invois BUKAN-DUIT dikeluarkan setiap kali produk/bekalan (cth madu)
-- diberi kepada pesakit — snapshot kuantiti diberi HARI INI + jumlah
-- dirancang seluruh pakej + baki SELEPAS pemberian ini. Snapshot kekal
-- (immutable) supaya sejarah tak berubah walau baki berubah kemudian.
--
-- Ditulis dari shared/supplyInvoice.js createSupplyInvoice() — dipanggil
-- SELEPAS addStockToLocation() (shared/inventoryStock.js) berjaya, dari
-- DUA laluan: "+ Bagi Bekalan" manual (roles/staff/patient-hub.html
-- submitSupply()) & auto-deduct lepas sesi Hadir (roles/staff/plan-week.html
-- applySupplyStock()). psy_stock_movements (36_stock_movements.sql) kekal
-- SUMBER KEBENARAN stok — jadual ni cuma dokumen invois, tak pernah ditulis
-- balik ke ledger.
-- ═══════════════════════════════════════════════════════════════════

CREATE SEQUENCE IF NOT EXISTS psy_supply_invoice_no_seq START 1;

CREATE TABLE IF NOT EXISTS psy_supply_invoices (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  invoice_no    TEXT UNIQUE,
  patient_id    UUID NOT NULL REFERENCES psy_patients(id),
  plan_id       UUID REFERENCES psy_treatment_plans(id) ON DELETE SET NULL,
  week_number   INT,
  source        TEXT NOT NULL DEFAULT 'manual' CHECK (source IN ('manual', 'auto_weekly')),
  -- items: [{item_id, name, unit, qty_given, qty_planned_total, qty_given_cumulative, qty_remaining}]
  items         JSONB NOT NULL DEFAULT '[]',
  given_by      UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  given_by_name TEXT,
  notes         TEXT,
  created_at    TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_supply_invoices_patient ON psy_supply_invoices(patient_id, created_at DESC);

ALTER TABLE psy_supply_invoices ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Patients read own supply invoices" ON psy_supply_invoices;
CREATE POLICY "Patients read own supply invoices" ON psy_supply_invoices FOR SELECT
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Staff manage supply invoices" ON psy_supply_invoices;
CREATE POLICY "Staff manage supply invoices" ON psy_supply_invoices FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

CREATE OR REPLACE FUNCTION psy_assign_supply_invoice_no() RETURNS trigger AS $$
BEGIN
  IF NEW.invoice_no IS NULL THEN
    NEW.invoice_no := 'INV-BKL-' || lpad(nextval('psy_supply_invoice_no_seq')::text, 6, '0');
  END IF;
  RETURN NEW;
END $$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_psy_assign_supply_invoice_no ON psy_supply_invoices;
CREATE TRIGGER trg_psy_assign_supply_invoice_no BEFORE INSERT ON psy_supply_invoices
  FOR EACH ROW EXECUTE FUNCTION psy_assign_supply_invoice_no();

COMMENT ON TABLE psy_supply_invoices IS
  'Invois bekalan produk (bukan duit) — snapshot kuantiti diberi + baki pakej setiap kali bekalan dikeluarkan kepada pesakit.';

-- Pautan terus dari baris ledger (psy_stock_movements) ke invois yg merekodkannya, supaya
-- UI sejarah bekalan boleh papar butang "Lihat Invois" terus tanpa carian masa/nama yg rapuh.
ALTER TABLE psy_stock_movements ADD COLUMN IF NOT EXISTS supply_invoice_id UUID REFERENCES psy_supply_invoices(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS idx_stock_movements_supply_invoice ON psy_stock_movements(supply_invoice_id);


-- ════════════════════════════════════════════════════════════════
-- schema/43_package_supply_invoices.sql
-- ════════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════════
-- 43 — PACKAGE SUPPLY INVOICE HEADER (nombor invois tetap per pakej)
-- Satu baris per (patient_id, plan_id) — pegang SATU nombor invois rasmi
-- yang kekal sepanjang pakej tu, walau berapa kali bekalan ditambah
-- lepas tu. Kandungan penuh invois (senarai produk + rekod mingguan)
-- TIDAK disimpan di sini — ia dikira secara LIVE setiap kali dibuka,
-- dengan menggabungkan semua baris psy_supply_invoices (42_supply_invoices.sql)
-- bagi plan_id yang sama. Jadual ni cuma "pemegang nombor".
--
-- Dicipta lazy (get-or-create) oleh shared/supplyInvoice.js
-- getOrCreatePackageSupplyInvoiceNo() — dipanggil SEKALI sebaik bekalan
-- PERTAMA pakej tu diberi (dari createSupplyInvoice()), supaya nombor
-- wujud dari transaksi pertama walau staff belum buka paparan invois lagi.
-- ═══════════════════════════════════════════════════════════════════

CREATE SEQUENCE IF NOT EXISTS psy_package_supply_invoice_no_seq START 1;

CREATE TABLE IF NOT EXISTS psy_package_supply_invoices (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  invoice_no    TEXT UNIQUE,
  patient_id    UUID NOT NULL REFERENCES psy_patients(id),
  plan_id       UUID NOT NULL REFERENCES psy_treatment_plans(id) ON DELETE CASCADE,
  created_at    TIMESTAMPTZ DEFAULT now(),
  UNIQUE (patient_id, plan_id)
);

CREATE INDEX IF NOT EXISTS idx_package_supply_invoices_patient ON psy_package_supply_invoices(patient_id);

ALTER TABLE psy_package_supply_invoices ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Patients read own package supply invoices" ON psy_package_supply_invoices;
CREATE POLICY "Patients read own package supply invoices" ON psy_package_supply_invoices FOR SELECT
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Staff manage package supply invoices" ON psy_package_supply_invoices;
CREATE POLICY "Staff manage package supply invoices" ON psy_package_supply_invoices FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

CREATE OR REPLACE FUNCTION psy_assign_package_supply_invoice_no() RETURNS trigger AS $$
BEGIN
  IF NEW.invoice_no IS NULL THEN
    NEW.invoice_no := 'INV-BK-' || lpad(nextval('psy_package_supply_invoice_no_seq')::text, 4, '0');
  END IF;
  RETURN NEW;
END $$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_psy_assign_package_supply_invoice_no ON psy_package_supply_invoices;
CREATE TRIGGER trg_psy_assign_package_supply_invoice_no BEFORE INSERT ON psy_package_supply_invoices
  FOR EACH ROW EXECUTE FUNCTION psy_assign_package_supply_invoice_no();

COMMENT ON TABLE psy_package_supply_invoices IS
  'Pemegang nombor invois bekalan PAKEJ (satu nombor tetap per patient_id+plan_id). Kandungan invois dikira live dari psy_supply_invoices, bukan disimpan di sini.';
