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
