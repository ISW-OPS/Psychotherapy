-- run_step_unnumbered.sql — GENERATED 2026-05-21T01:57:58Z
-- Run AFTER step1-51 are done. Combines all step_*.sql files in order.


-- ── FILE: step_adherence_alerts.sql ──
-- ============================================================
-- step_adherence_alerts.sql
-- Track patient adherence alerts (madu, dll).
-- Coach dapat notif bila patient kurang madu 4+ hari berturut.
-- ============================================================

CREATE TABLE IF NOT EXISTS psy_adherence_alerts (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id    UUID REFERENCES psy_patients(id) ON DELETE CASCADE NOT NULL,
  alert_type    TEXT NOT NULL,             -- 'madu_low_5days' / 'madu_low_4days'
  trigger_date  DATE NOT NULL,             -- tarikh alert dikira
  details       JSONB DEFAULT '{}',        -- snapshot: { target, days_below: [...], counts: {} }
  notified_coach_id UUID REFERENCES psy_profiles(id),
  acknowledged_by   UUID REFERENCES psy_profiles(id),
  acknowledged_at   TIMESTAMPTZ,
  created_at    TIMESTAMPTZ DEFAULT now(),
  UNIQUE (patient_id, alert_type, trigger_date)  -- elak duplicate sehari
);

CREATE INDEX IF NOT EXISTS idx_adherence_patient ON psy_adherence_alerts(patient_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_adherence_unack   ON psy_adherence_alerts(acknowledged_at) WHERE acknowledged_at IS NULL;

ALTER TABLE psy_adherence_alerts ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "Patient read own adherence" ON psy_adherence_alerts
    FOR SELECT USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "Staff read all adherence" ON psy_adherence_alerts
    FOR SELECT USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "Staff manage adherence" ON psy_adherence_alerts
    FOR ALL USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
    WITH CHECK (auth.uid() IS NOT NULL);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Patient pun boleh insert (sebab patient dashboard akan trigger check)
DO $$ BEGIN
  CREATE POLICY "Patient insert own adherence" ON psy_adherence_alerts
    FOR INSERT WITH CHECK (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;


-- ── FILE: step_bottle_returns.sql ──
-- ============================================================
-- step_bottle_returns.sql
-- Sistem pulangan botol madu untuk patient.
-- ============================================================

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
  verified_by          UUID REFERENCES psy_profiles(id),
  verified_by_name     TEXT,
  verified_at          TIMESTAMPTZ,
  created_at           TIMESTAMPTZ DEFAULT now(),
  updated_at           TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_bottle_returns_patient ON psy_bottle_returns(patient_id);
CREATE INDEX IF NOT EXISTS idx_bottle_returns_status  ON psy_bottle_returns(status, created_at DESC);

ALTER TABLE psy_bottle_returns ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "Patient manage own returns" ON psy_bottle_returns
    FOR ALL USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()))
    WITH CHECK (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "Staff read all returns" ON psy_bottle_returns
    FOR SELECT USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "Staff update returns" ON psy_bottle_returns
    FOR UPDATE USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

COMMENT ON TABLE psy_bottle_returns IS
  'Permohonan pulangan botol madu patient. Chat thread guna psy_audit_log dengan meta.return_id.';
COMMENT ON COLUMN psy_bottle_returns.criteria_confirmed IS
  'JSONB: {tidak_berkarat, bersih, getah_ada, besi_kemas} - semua mesti true sebelum patient boleh submit.';
COMMENT ON COLUMN psy_bottle_returns.photo_urls IS
  'Array URL foto bukti botol (boleh upload multiple).';

-- Storage bucket untuk photos (manual setup di Supabase Dashboard atau via SQL kalau extension dah enable)
-- Bucket name: 'bottle-returns', public read, authenticated insert


-- ── FILE: step_coaching_catalog.sql ──
-- ============================================================
-- step_coaching_catalog.sql
-- Master catalog untuk Bimbingan/Calling & Aktiviti/Rawatan.
-- Admin CRUD via dedicated page. Pakej-edit pakai picker.
-- ============================================================

CREATE TABLE IF NOT EXISTS psy_coaching_catalog (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name          TEXT NOT NULL,
  type          TEXT NOT NULL CHECK (type IN ('bimbingan','aktiviti')),
  description   TEXT,
  category      TEXT,             -- optional grouping (cth: 'Bimbingan Reaksi', 'Herba', dll)
  is_active     BOOLEAN DEFAULT true,
  sort_order    INT DEFAULT 0,
  created_by    UUID REFERENCES psy_profiles(id),
  created_by_name TEXT,
  created_at    TIMESTAMPTZ DEFAULT now(),
  updated_at    TIMESTAMPTZ DEFAULT now(),
  UNIQUE (name, type)
);

CREATE INDEX IF NOT EXISTS idx_coaching_catalog_type ON psy_coaching_catalog(type, sort_order);
CREATE INDEX IF NOT EXISTS idx_coaching_catalog_active ON psy_coaching_catalog(is_active);

ALTER TABLE psy_coaching_catalog ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "Anyone read catalog" ON psy_coaching_catalog
    FOR SELECT USING (auth.uid() IS NOT NULL);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "Staff manage catalog" ON psy_coaching_catalog
    FOR ALL USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
    WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Seed beberapa default
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


-- ── FILE: step_inventory_auto_po.sql ──
-- ============================================================
-- step_inventory_auto_po.sql
-- Auto-trigger purchase invoice bila stok ≤ 30% dari max.
-- ============================================================

ALTER TABLE psy_inventory_items
  ADD COLUMN IF NOT EXISTS max_qty NUMERIC(10,2),
  ADD COLUMN IF NOT EXISTS auto_reorder_qty NUMERIC(10,2),
  ADD COLUMN IF NOT EXISTS auto_reorder_enabled BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS last_auto_po_at TIMESTAMPTZ;

COMMENT ON COLUMN psy_inventory_items.max_qty IS
  'Saiz stok penuh / target. Trigger auto-PO bila qty_in_stock <= 30% dari max_qty.';
COMMENT ON COLUMN psy_inventory_items.auto_reorder_qty IS
  'Kuantiti yang sistem cadang dalam auto-PO. Default: max_qty - qty_in_stock.';
COMMENT ON COLUMN psy_inventory_items.auto_reorder_enabled IS
  'true = auto-create purchase invoice bila stok rendah; false = manual sahaja.';
COMMENT ON COLUMN psy_inventory_items.last_auto_po_at IS
  'Tarikh auto-PO terakhir dijana — elak duplikat dalam tempoh pendek.';

-- Mark auto-generated requests
ALTER TABLE psy_inventory_requests
  ADD COLUMN IF NOT EXISTS is_auto_generated BOOLEAN DEFAULT false;

COMMENT ON COLUMN psy_inventory_requests.is_auto_generated IS
  'true = dijana automatik bila stok ≤ 30%, false = manual request oleh staff.';


-- ── FILE: step_inventory_consumption_type.sql ──
-- ============================================================
-- step_inventory_consumption_type.sql
-- Klasifikasi barang inventory ikut sifat consumption:
--   package  = pakai sebagai bekalan pakej (kira dynamic dari patient × pakej supplies)
--   service  = pakai untuk service one-off (cth: DNA test kit, swab, urine cup)
--   general  = consumable umum (sarung tangan, alcohol swab, tissue) — manual min sahaja
-- ============================================================

ALTER TABLE psy_inventory_items
  ADD COLUMN IF NOT EXISTS consumption_type TEXT DEFAULT 'package'
    CHECK (consumption_type IN ('package','service','general'));

COMMENT ON COLUMN psy_inventory_items.consumption_type IS
  'package = bekalan pakej (dynamic auto-calc); service = guna semasa service one-off; general = consumable umum (manual min sahaja).';

UPDATE psy_inventory_items SET consumption_type = 'package' WHERE consumption_type IS NULL;

-- ============================================================
-- psy_services — Senarai service (appointment types) yang clinic tawarkan.
-- Page services.html dan service-detail.html guna table ni.
-- ============================================================
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

DO $$ BEGIN
  CREATE POLICY "Staff manage services" ON psy_services FOR ALL
    USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "All authenticated read services" ON psy_services FOR SELECT
    USING (auth.uid() IS NOT NULL);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Kalau table sudah pernah wujud tanpa column supplies (cth. di-create melalui jalan lain), tambah dia.
ALTER TABLE psy_services
  ADD COLUMN IF NOT EXISTS supplies JSONB DEFAULT '[]'::jsonb;

-- Seed beberapa service umum (idempotent — skip jika sudah ada)
INSERT INTO psy_services (service_id, name, description, icon, price, duration_min, sort_order)
VALUES
  ('consultation', 'Consultation with Doctor', 'Sesi konsultasi dengan doktor',           '🩺',  50.00, 30, 10),
  ('dna_test',     'DNA Test',                  'Ujian genetik untuk profil kesihatan',  '🧬', 350.00, 45, 20),
  ('blood_test',   'Blood Test',                'Pemeriksaan darah asas',                '🩸', 120.00, 20, 30),
  ('kob',          'Kursus Orientasi Bestari',  'Kursus orientasi pesakit baru',         '🎓',   0.00, 90, 40)
ON CONFLICT (service_id) DO NOTHING;


-- ── FILE: step_inventory_supplier_info.sql ──
-- ============================================================
-- step_inventory_supplier_info.sql
-- Tambah supplier_info JSONB pada psy_inventory_items
-- Format: { name, cost_per_unit, lead_days, po_min, po_max }
-- ============================================================

ALTER TABLE psy_inventory_items
  ADD COLUMN IF NOT EXISTS supplier_info JSONB DEFAULT '{}'::jsonb;

COMMENT ON COLUMN psy_inventory_items.supplier_info IS
  'Format: { name, cost_per_unit, lead_days, po_min, po_max }. Maklumat pembekal dan cadangan PO.';


-- ── FILE: step_letter_auto_fields.sql ──
-- ============================================================
-- step_letter_auto_fields.sql
-- Admin boleh tambah auto-field tambahan (selain yang hardcoded).
-- Cth: [BMI], [BERAT], [PEKERJAAN] — sistem ambil dari column DB.
-- ============================================================

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
  created_by      UUID REFERENCES psy_profiles(id),
  created_by_name TEXT,
  created_at      TIMESTAMPTZ DEFAULT now(),
  updated_at      TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE psy_letter_auto_fields
  ADD COLUMN IF NOT EXISTS is_default BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS sort_order INT DEFAULT 0;

ALTER TABLE psy_letter_auto_fields ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "Anyone read auto fields" ON psy_letter_auto_fields
    FOR SELECT USING (auth.uid() IS NOT NULL);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "Staff manage auto fields" ON psy_letter_auto_fields
    FOR ALL USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
    WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

COMMENT ON TABLE psy_letter_auto_fields IS
  'Auto-fields untuk surat. Admin manage via UI. Sistem ambil value dari DB column yang ditentukan.';

-- ── Seed default auto-fields ────────────────────────────────
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


-- ── FILE: step_letter_base.sql ──
-- ============================================================
-- step_letters.sql
-- Sistem generate surat rasmi (KWSP, PERKESO, RELA, dll).
-- Patient request → Staff fill template → sign → patient download PDF.
-- ============================================================

-- Staff signature (upload sekali, reuse semua surat)
ALTER TABLE psy_profiles
  ADD COLUMN IF NOT EXISTS signature_url TEXT;

COMMENT ON COLUMN psy_profiles.signature_url IS
  'URL signature image staff. Embed dalam surat rasmi yang di-sign.';

-- Permintaan surat dari patient
CREATE TABLE IF NOT EXISTS psy_letter_requests (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id      UUID REFERENCES psy_patients(id) ON DELETE CASCADE NOT NULL,
  patient_name    TEXT NOT NULL,
  template_code   TEXT NOT NULL,
  template_name   TEXT NOT NULL,
  reason          TEXT,
  field_values    JSONB DEFAULT '{}',
  status          TEXT NOT NULL DEFAULT 'pending'
                  CHECK (status IN ('pending','issued','rejected','cancelled')),
  reject_reason   TEXT,
  created_at      TIMESTAMPTZ DEFAULT now(),
  updated_at      TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_letter_req_patient ON psy_letter_requests(patient_id);
CREATE INDEX IF NOT EXISTS idx_letter_req_status  ON psy_letter_requests(status, created_at DESC);

ALTER TABLE psy_letter_requests ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "Patient manage own letter requests" ON psy_letter_requests
    FOR ALL USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()))
    WITH CHECK (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "Staff read all letter requests" ON psy_letter_requests
    FOR SELECT USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "Staff update letter requests" ON psy_letter_requests
    FOR UPDATE USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;


-- Surat yang telah dikeluarkan & disign
CREATE TABLE IF NOT EXISTS psy_letter_issued (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id      UUID REFERENCES psy_letter_requests(id) ON DELETE SET NULL,
  patient_id      UUID REFERENCES psy_patients(id) ON DELETE CASCADE,  -- nullable: NULL = internal document
  patient_name    TEXT NOT NULL,
  template_code   TEXT NOT NULL,
  template_name   TEXT NOT NULL,
  field_values    JSONB NOT NULL DEFAULT '{}',
  ref_number      TEXT,  -- cth: ISW/RELA/2026/0001
  signed_by       UUID REFERENCES psy_profiles(id),
  signed_by_name  TEXT NOT NULL,
  signed_by_role  TEXT,
  signature_url   TEXT,  -- snapshot signature staff masa sign
  signed_at       TIMESTAMPTZ DEFAULT now(),
  created_at      TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_letter_issued_patient ON psy_letter_issued(patient_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_letter_issued_code    ON psy_letter_issued(template_code);

ALTER TABLE psy_letter_issued ENABLE ROW LEVEL SECURITY;

-- Untuk DB sedia ada — drop NOT NULL kalau ada
ALTER TABLE psy_letter_issued ALTER COLUMN patient_id DROP NOT NULL;

DO $$ BEGIN
  CREATE POLICY "Patient read own issued letters" ON psy_letter_issued
    FOR SELECT USING (patient_id IS NOT NULL AND patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "Staff manage issued letters" ON psy_letter_issued
    FOR ALL USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
    WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;


-- ── FILE: step_letter_files.sql ──
-- ============================================================
-- step_letter_files.sql
-- Refactor sistem surat ke document repository (Word/PDF upload).
-- Staff upload templates → download → fill dalam Word → save PDF →
-- upload PDF balik untuk patient.
-- ============================================================

-- ── Storage untuk uploaded template files ────────────────────
CREATE TABLE IF NOT EXISTS psy_letter_template_files (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name            TEXT NOT NULL,            -- cth: "Surat Permohonan KWSP"
  description     TEXT,
  file_url        TEXT NOT NULL,
  file_name       TEXT NOT NULL,            -- nama original file
  file_size       INT,                      -- bytes
  file_type       TEXT,                     -- 'docx', 'pdf', 'doc'
  uploaded_by     UUID REFERENCES psy_profiles(id),
  uploaded_by_name TEXT,
  created_at      TIMESTAMPTZ DEFAULT now()
);

-- Sokong dua jenis templat: 'file' (upload Word/PDF) atau 'inline' (cipta dalam sistem)
ALTER TABLE psy_letter_template_files
  ADD COLUMN IF NOT EXISTS template_type TEXT DEFAULT 'file'
    CHECK (template_type IN ('file','inline')),
  ADD COLUMN IF NOT EXISTS body_html TEXT;

-- Buat file_url nullable (inline tak ada file)
ALTER TABLE psy_letter_template_files ALTER COLUMN file_url DROP NOT NULL;
ALTER TABLE psy_letter_template_files ALTER COLUMN file_name DROP NOT NULL;

CREATE INDEX IF NOT EXISTS idx_letter_tpl_files_created ON psy_letter_template_files(created_at DESC);

ALTER TABLE psy_letter_template_files ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "Staff manage template files" ON psy_letter_template_files
    FOR ALL USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
    WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;


-- ── Issued letters: tambah file_url untuk uploaded PDF ───────
ALTER TABLE psy_letter_issued
  ADD COLUMN IF NOT EXISTS file_url     TEXT,
  ADD COLUMN IF NOT EXISTS file_name    TEXT,
  ADD COLUMN IF NOT EXISTS file_size    INT,
  ADD COLUMN IF NOT EXISTS template_file_id UUID REFERENCES psy_letter_template_files(id) ON DELETE SET NULL;

COMMENT ON COLUMN psy_letter_issued.file_url IS
  'URL PDF/Word file lengkap yang dah disign (upload oleh staff).';
COMMENT ON COLUMN psy_letter_issued.template_file_id IS
  'Refer template yang digunakan (untuk track sahaja).';

-- Field lama (field_values, signature_url, body_html) jadi optional/legacy
-- Tak perlu drop sebab old data mungkin ada.


-- ── FILE: step_letter_simple.sql ──
-- ============================================================
-- step_letter_simple.sql
-- Sistem surat: format tetap (letterhead auto), admin define
-- template body + fields, staff fill form → generate PDF.
-- ============================================================

CREATE TABLE IF NOT EXISTS psy_letter_templates (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name            TEXT NOT NULL,
  description     TEXT,
  category        TEXT NOT NULL DEFAULT 'patient'
                  CHECK (category IN ('patient','internal')),
  recipient       TEXT,                 -- "Pengurus Besar, KWSP, ..."
  title           TEXT,                 -- "PERMOHONAN PENGELUARAN AHLI KWSP"
  body            TEXT NOT NULL,        -- plain text + [PLACEHOLDER]
  fields          JSONB NOT NULL DEFAULT '[]',  -- [{key,label,type,autofill}]
  created_by      UUID REFERENCES psy_profiles(id),
  created_by_name TEXT,
  created_at      TIMESTAMPTZ DEFAULT now(),
  updated_at      TIMESTAMPTZ DEFAULT now()
);

-- Tambah kalau table dah wujud
ALTER TABLE psy_letter_templates
  ADD COLUMN IF NOT EXISTS category TEXT NOT NULL DEFAULT 'patient';

ALTER TABLE psy_letter_templates ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "Anyone read templates" ON psy_letter_templates
    FOR SELECT USING (auth.uid() IS NOT NULL);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "Staff manage templates" ON psy_letter_templates
    FOR ALL USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
    WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Cleanup old tables (jika ada, dari iterasi lepas)
DROP TABLE IF EXISTS psy_letter_template_overrides;

-- Drop column dalam psy_letter_issued yang refer psy_letter_template_files dulu
ALTER TABLE psy_letter_issued DROP COLUMN IF EXISTS template_file_id;
DROP TABLE IF EXISTS psy_letter_template_files;


-- ── FILE: step_letter_template_overrides.sql ──
-- ============================================================
-- step_letter_template_overrides.sql
-- Staff boleh override templates surat hardcoded.
-- Cara kerja: DB override → kalau tiada, fallback ke hardcoded JS templates.
-- ============================================================

CREATE TABLE IF NOT EXISTS psy_letter_template_overrides (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  template_code   TEXT UNIQUE NOT NULL,  -- 'rela', 'kwsp', etc.
  name            TEXT NOT NULL,
  description     TEXT,
  icon            TEXT,
  body_html       TEXT NOT NULL,
  fields          JSONB NOT NULL DEFAULT '[]',  -- [{key,label,type,required,autofill}]
  updated_by      UUID REFERENCES psy_profiles(id),
  updated_by_name TEXT,
  updated_at      TIMESTAMPTZ DEFAULT now(),
  created_at      TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE psy_letter_template_overrides ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "Staff read templates" ON psy_letter_template_overrides
    FOR SELECT USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "Staff manage templates" ON psy_letter_template_overrides
    FOR ALL USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
    WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Patient juga boleh read (untuk render surat masa download — sebab template_code dirujuk)
DO $$ BEGIN
  CREATE POLICY "Patient read templates" ON psy_letter_template_overrides
    FOR SELECT USING (auth.uid() IS NOT NULL);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

COMMENT ON TABLE psy_letter_template_overrides IS
  'Override templates surat hardcoded. Tiada row = guna hardcoded defaults.';


-- ── FILE: step_package_extension_price.sql ──
-- Phase 1: Harga tambah minggu rawatan (extension) — admin tetapkan per pakej.

ALTER TABLE psy_packages
  ADD COLUMN IF NOT EXISTS extension_price_per_week NUMERIC(10,2) DEFAULT 50;

COMMENT ON COLUMN psy_packages.extension_price_per_week IS
  'Harga (RM) untuk tambah satu minggu rawatan bila patient miss sesi. Default RM 50.';


-- ── FILE: step_package_meet_link.sql ──
-- Add single Gmeet link per package — used for all weeks with online/both mode.
ALTER TABLE psy_packages
  ADD COLUMN IF NOT EXISTS meet_link TEXT;

COMMENT ON COLUMN psy_packages.meet_link IS
  'Pautan Gmeet recurring untuk pakej. Dipaparkan kepada patient bila minggu semasa adalah online/both.';


-- ── FILE: step_patient_address_residence.sql ──
-- ============================================================
-- STEP — Patient Address: Residence + City/State columns
-- Tambah alamat kediaman (berasingan dari surat-menyurat) +
-- pecahkan bandar / negeri untuk filter & laporan.
-- ============================================================

ALTER TABLE psy_patients
  ADD COLUMN IF NOT EXISTS home_address TEXT,
  ADD COLUMN IF NOT EXISTS city         TEXT,
  ADD COLUMN IF NOT EXISTS state        TEXT;

COMMENT ON COLUMN psy_patients.home_address IS
  'Alamat kediaman pesakit (berbeza dari address yang digunakan untuk surat-menyurat / mailing).';
COMMENT ON COLUMN psy_patients.city  IS 'Bandar (sebahagian dari alamat kediaman).';
COMMENT ON COLUMN psy_patients.state IS 'Negeri (Selangor, Johor, dll.).';

CREATE INDEX IF NOT EXISTS idx_patients_state ON psy_patients(state);

SELECT 'Step Patient Address OK — home_address, city, state added' AS status;


-- ── FILE: step_patient_hub_v2.sql ──
-- ============================================================
-- STEP — Patient Hub v2 schema
-- 1. Rename psy_dna_reports → psy_medical_reports + expand
-- 2. NEW psy_patient_notes (Nota Coach / Sesi / General)
-- 3. NEW psy_patient_documents (KYC, IC, Persetujuan, Laporan, Gambar)
-- 4. Patient supplies = derived dari coaching_schedule + audit log (no new table)
-- ============================================================

-- ───────── 1. EXPAND DNA → Medical Reports (general purpose) ─────────
-- Rename only if old table exists with old name; otherwise skip
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'psy_dna_reports')
     AND NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'psy_medical_reports') THEN
    ALTER TABLE psy_dna_reports RENAME TO psy_medical_reports;
  END IF;
END $$;

-- If neither exists, create fresh
CREATE TABLE IF NOT EXISTS psy_medical_reports (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id      UUID NOT NULL REFERENCES psy_patients(id) ON DELETE CASCADE,
  file_name       TEXT NOT NULL,
  file_path       TEXT,
  file_url        TEXT,
  notes           TEXT,
  uploaded_by     UUID,
  uploaded_by_name TEXT,
  uploaded_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Add expanded columns
ALTER TABLE psy_medical_reports
  ADD COLUMN IF NOT EXISTS report_type    TEXT DEFAULT 'dna',
  ADD COLUMN IF NOT EXISTS title          TEXT,
  ADD COLUMN IF NOT EXISTS status         TEXT DEFAULT 'pending',
  ADD COLUMN IF NOT EXISTS sample_date    DATE,
  ADD COLUMN IF NOT EXISTS sample_type    TEXT,
  ADD COLUMN IF NOT EXISTS result_date    DATE,
  ADD COLUMN IF NOT EXISTS analysis_duration_days INT,
  ADD COLUMN IF NOT EXISTS categories     JSONB DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS summary        TEXT,
  ADD COLUMN IF NOT EXISTS doctor_id      UUID,
  ADD COLUMN IF NOT EXISTS doctor_name    TEXT,
  ADD COLUMN IF NOT EXISTS doctor_review  TEXT,
  ADD COLUMN IF NOT EXISTS review_status  TEXT DEFAULT 'pending',
  ADD COLUMN IF NOT EXISTS reviewed_at    TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS shared_with_patient BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS shared_at      TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS attached_files JSONB DEFAULT '[]';

COMMENT ON COLUMN psy_medical_reports.report_type IS
  'dna | xray | ct | mri | ultrasound | blood | colonoscopy | endoscopy | other';
COMMENT ON COLUMN psy_medical_reports.status IS
  'pending | sampling | lab | ready | reviewed';
COMMENT ON COLUMN psy_medical_reports.review_status IS
  'pending | diluluskan | ditolak';

CREATE INDEX IF NOT EXISTS idx_medical_reports_patient ON psy_medical_reports(patient_id, uploaded_at DESC);
CREATE INDEX IF NOT EXISTS idx_medical_reports_type    ON psy_medical_reports(report_type);

ALTER TABLE psy_medical_reports ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  CREATE POLICY "staff_medical_all" ON psy_medical_reports FOR ALL
    USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "patient_medical_read" ON psy_medical_reports FOR SELECT
    USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ───────── 2. NEW: Patient Notes ─────────
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
DO $$ BEGIN
  CREATE POLICY "staff_notes_all" ON psy_patient_notes FOR ALL
    USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "patient_notes_read" ON psy_patient_notes FOR SELECT
    USING (visibility IN ('patient','both') AND
           patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ───────── 3. NEW: Patient Documents ─────────
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
  approved_at  TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_patient_docs_patient ON psy_patient_documents(patient_id, uploaded_at DESC);
CREATE INDEX IF NOT EXISTS idx_patient_docs_type    ON psy_patient_documents(doc_type);

ALTER TABLE psy_patient_documents ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  CREATE POLICY "staff_docs_all" ON psy_patient_documents FOR ALL
    USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "patient_docs_read_own" ON psy_patient_documents FOR SELECT
    USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "patient_docs_insert_own" ON psy_patient_documents FOR INSERT
    WITH CHECK (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

SELECT 'Step Patient Hub v2 OK — medical_reports expanded, notes + documents created' AS status;


-- ── FILE: step_plan_schedule_setup.sql ──
-- Phase 1: Treatment plan schedule preferences
-- Patient pilih sekali masa onboarding: pasangan hari + jam untuk setiap hari.
-- Sistem auto-seed 24 sesi (12 minggu × 2 hari).

ALTER TABLE psy_treatment_plans
  ADD COLUMN IF NOT EXISTS preferred_pair TEXT CHECK (preferred_pair IN ('fri_sat','sat_sun')),
  ADD COLUMN IF NOT EXISTS preferred_time_day1 TIME,   -- jam hari pertama (Jum atau Sab)
  ADD COLUMN IF NOT EXISTS preferred_time_day2 TIME,   -- jam hari kedua (Sab atau Ahad)
  ADD COLUMN IF NOT EXISTS schedule_setup_at TIMESTAMPTZ;

COMMENT ON COLUMN psy_treatment_plans.preferred_pair IS
  'Pasangan hari pilihan patient: fri_sat (Jumaat+Sabtu) atau sat_sun (Sabtu+Ahad).';
COMMENT ON COLUMN psy_treatment_plans.preferred_time_day1 IS
  'Jam pilihan hari pertama dalam pair (Jumaat untuk fri_sat, Sabtu untuk sat_sun).';
COMMENT ON COLUMN psy_treatment_plans.preferred_time_day2 IS
  'Jam pilihan hari kedua dalam pair (Sabtu untuk fri_sat, Ahad untuk sat_sun).';
COMMENT ON COLUMN psy_treatment_plans.schedule_setup_at IS
  'Bila patient siap setup jadual. NULL = belum setup, tunjuk wizard.';


-- ── FILE: step_plan_session_day.sql ──
-- Phase 1: 2 sesi seminggu — tambah session_day untuk pisahkan sesi A vs B.
-- Existing rows tetap session_day=1 supaya plan lama tak terjejas.

ALTER TABLE psy_plan_weekly_progress
  ADD COLUMN IF NOT EXISTS session_day INT DEFAULT 1 CHECK (session_day IN (1,2)),
  ADD COLUMN IF NOT EXISTS is_extension BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS extension_for_week INT,
  ADD COLUMN IF NOT EXISTS extension_price NUMERIC(10,2),
  ADD COLUMN IF NOT EXISTS extension_paid_at TIMESTAMPTZ;

-- Drop old uniqueness yang assume 1 row per minggu
ALTER TABLE psy_plan_weekly_progress
  DROP CONSTRAINT IF EXISTS psy_plan_weekly_progress_plan_id_week_number_key;

-- Composite unique: 1 row per sesi (plan + minggu + day)
DO $$ BEGIN
  ALTER TABLE psy_plan_weekly_progress
    ADD CONSTRAINT psy_plan_weekly_progress_plan_week_day_key
    UNIQUE (plan_id, week_number, session_day);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Status tambahan untuk extension flow
ALTER TABLE psy_plan_weekly_progress
  DROP CONSTRAINT IF EXISTS psy_plan_weekly_progress_status_check;

ALTER TABLE psy_plan_weekly_progress
  ADD CONSTRAINT psy_plan_weekly_progress_status_check
  CHECK (status IN (
    'pending','booked','hadir','reschedule','cancel','consultation_done',
    'extension_pending_payment','extension_paid'
  ));

COMMENT ON COLUMN psy_plan_weekly_progress.session_day IS
  '1 = sesi pertama dalam minggu (Jum/Sab), 2 = sesi kedua (Sab/Ahad). Default 1 untuk backward compat.';
COMMENT ON COLUMN psy_plan_weekly_progress.is_extension IS
  'true = minggu tambahan (extension) selepas miss sesi. Perlu bayar sebelum tempah.';
COMMENT ON COLUMN psy_plan_weekly_progress.extension_for_week IS
  'Refer minggu asal yang miss, untuk audit trail.';


-- ── FILE: step_procedure_kits.sql ──
-- ============================================================
-- step_procedure_kits.sql
-- Kit prosedur — satu kit = set item inventory yang diguna
-- untuk satu prosedur (cth: IV Drip Setup, DNA Test Kit).
-- Bila pakej ada kit dalam supplies, demand auto-expand
-- kepada semua sub-items dalam kit.
-- ============================================================

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

ALTER TABLE psy_procedure_kits ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  CREATE POLICY "Staff manage kits" ON psy_procedure_kits FOR ALL
    USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Seed contoh kits
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


-- ── FILE: step_product_inventory_link.sql ──
-- ============================================================
-- step_product_inventory_link.sql
-- Link psy_products → psy_inventory_items supaya stok shop
-- auto-deduct dari inventory bila order paid.
-- ============================================================

ALTER TABLE psy_products
  ADD COLUMN IF NOT EXISTS inventory_item_id UUID REFERENCES psy_inventory_items(id) ON DELETE SET NULL;

COMMENT ON COLUMN psy_products.inventory_item_id IS
  'Link ke inventory item. Bila order status=paid, qty_in_stock auto-deduct ikut quantity dibeli.';

-- ============================================================
-- Trigger: auto-deduct inventory bila order status tukar ke 'paid'.
-- Items JSONB format: [{product_id: "...", qty: N, ...}, ...]
-- ============================================================
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

DROP TRIGGER IF EXISTS trg_psy_order_deduct_inventory ON psy_orders;
CREATE TRIGGER trg_psy_order_deduct_inventory
  AFTER UPDATE ON psy_orders
  FOR EACH ROW EXECUTE FUNCTION psy_order_deduct_inventory();


-- ── FILE: step_products_enhanced.sql ──
-- ============================================================
-- STEP — psy_products enhanced fields
-- Untuk sokong mockup baru: jenama, promo, stok lanjut, media, butiran, visibility
-- ============================================================

ALTER TABLE psy_products
  ADD COLUMN IF NOT EXISTS sku           TEXT,
  ADD COLUMN IF NOT EXISTS brand         TEXT,
  ADD COLUMN IF NOT EXISTS description_short TEXT,
  ADD COLUMN IF NOT EXISTS status        TEXT DEFAULT 'active',
  ADD COLUMN IF NOT EXISTS promo_price   NUMERIC(10,2),
  ADD COLUMN IF NOT EXISTS promo_until   DATE,
  ADD COLUMN IF NOT EXISTS min_stock     INT DEFAULT 5,
  ADD COLUMN IF NOT EXISTS unit          TEXT DEFAULT 'unit',
  ADD COLUMN IF NOT EXISTS track_inventory  BOOLEAN DEFAULT true,
  ADD COLUMN IF NOT EXISTS low_stock_alert  BOOLEAN DEFAULT true,
  ADD COLUMN IF NOT EXISTS image_urls    JSONB DEFAULT '[]',
  ADD COLUMN IF NOT EXISTS weight_size   TEXT,
  ADD COLUMN IF NOT EXISTS supplier      TEXT,
  ADD COLUMN IF NOT EXISTS tags          JSONB DEFAULT '[]',
  ADD COLUMN IF NOT EXISTS notes         TEXT,
  ADD COLUMN IF NOT EXISTS visible_in_shop  BOOLEAN DEFAULT true,
  ADD COLUMN IF NOT EXISTS featured      BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS online_purchase BOOLEAN DEFAULT true;

-- Backfill sku from product_id if null
UPDATE psy_products SET sku = product_id WHERE sku IS NULL;

-- Backfill status from is_active
UPDATE psy_products SET status = 'active'   WHERE status IS NULL AND is_active = true;
UPDATE psy_products SET status = 'inactive' WHERE status IS NULL AND is_active = false;

SELECT 'Step psy_products enhanced OK' AS status;

