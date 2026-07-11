-- ============================================================
-- step95: Knowledge Base (Knowledge Hub) — pusat dokumen dalaman staff
-- ------------------------------------------------------------
-- Modul rujukan dalaman: SOP, garis panduan klinikal, latihan, borang,
-- template, video, pautan. Termasuk bookmark, nota peribadi, versioning,
-- dan pusat latihan (training center).
--
-- Idempotent: selamat run berulang kali (IF NOT EXISTS / ON CONFLICT).
-- Jalankan di Supabase (TESTING dulu → PROD) SQL Editor.
-- Storage bucket 'kb-media' dicipta di bahagian bawah.
-- ============================================================

-- ── 1) Kategori ──────────────────────────────────────────────
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

-- ── 2) Resource / dokumen ────────────────────────────────────
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
                CHECK (visibility IN ('public','department','role','private')),
  allowed_roles TEXT[] DEFAULT '{}',   -- bila visibility='role'
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
-- Visibility 'user' → dikongsi kepada staf tertentu sahaja
ALTER TABLE psy_kb_resources ADD COLUMN IF NOT EXISTS allowed_users UUID[] DEFAULT '{}';
-- 'department' dikekalkan dalam CHECK utk data lama, tetapi tak lagi ditawar di borang.
ALTER TABLE psy_kb_resources DROP CONSTRAINT IF EXISTS psy_kb_resources_visibility_check;
ALTER TABLE psy_kb_resources ADD CONSTRAINT psy_kb_resources_visibility_check
  CHECK (visibility IN ('public','department','role','user','private'));

-- ── 3) Sejarah versi ─────────────────────────────────────────
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

-- ── 4) Bookmark / pinned (per-user) ──────────────────────────
CREATE TABLE IF NOT EXISTS psy_kb_bookmarks (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES psy_profiles(id) ON DELETE CASCADE,
  resource_id UUID NOT NULL REFERENCES psy_kb_resources(id) ON DELETE CASCADE,
  is_pinned   BOOLEAN DEFAULT false,
  created_at  TIMESTAMPTZ DEFAULT now(),
  UNIQUE (user_id, resource_id)
);
CREATE INDEX IF NOT EXISTS idx_kb_bm_user ON psy_kb_bookmarks(user_id);

-- ── 5) Recently viewed (per-user) ────────────────────────────
CREATE TABLE IF NOT EXISTS psy_kb_views (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES psy_profiles(id) ON DELETE CASCADE,
  resource_id UUID NOT NULL REFERENCES psy_kb_resources(id) ON DELETE CASCADE,
  viewed_at   TIMESTAMPTZ DEFAULT now(),
  UNIQUE (user_id, resource_id)
);
CREATE INDEX IF NOT EXISTS idx_kb_views_user ON psy_kb_views(user_id, viewed_at DESC);

-- ── 6) Nota peribadi + folder (per-user) ─────────────────────
CREATE TABLE IF NOT EXISTS psy_kb_note_folders (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID NOT NULL REFERENCES psy_profiles(id) ON DELETE CASCADE,
  name       TEXT NOT NULL,
  color      TEXT DEFAULT 'navy',
  created_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_kb_folders_user ON psy_kb_note_folders(user_id);

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

-- ── 7) Training Center ───────────────────────────────────────
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

CREATE TABLE IF NOT EXISTS psy_kb_certificates (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES psy_profiles(id) ON DELETE CASCADE,
  training_id UUID REFERENCES psy_kb_trainings(id) ON DELETE SET NULL,
  title       TEXT NOT NULL,
  cert_url    TEXT,
  earned_at   TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_kb_cert_user ON psy_kb_certificates(user_id);

-- ── updated_at trigger ───────────────────────────────────────
CREATE OR REPLACE FUNCTION kb_touch_updated_at() RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END; $$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_kb_res_touch ON psy_kb_resources;
CREATE TRIGGER trg_kb_res_touch BEFORE UPDATE ON psy_kb_resources
  FOR EACH ROW EXECUTE FUNCTION kb_touch_updated_at();

DROP TRIGGER IF EXISTS trg_kb_notes_touch ON psy_kb_notes;
CREATE TRIGGER trg_kb_notes_touch BEFORE UPDATE ON psy_kb_notes
  FOR EACH ROW EXECUTE FUNCTION kb_touch_updated_at();

-- ============================================================
-- RLS
-- ------------------------------------------------------------
-- Katil-katil "kongsi" (categories/resources/versions/trainings): semua staff
-- boleh baca; hanya staff dgn kebenaran boleh tulis (guna helper is_staff()).
-- Katil per-user (bookmarks/views/notes/folders/progress/certs): user sendiri.
-- ============================================================

-- Helper: adakah auth.uid() seorang staff?
CREATE OR REPLACE FUNCTION kb_is_staff() RETURNS BOOLEAN AS $$
  SELECT EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff');
$$ LANGUAGE sql SECURITY DEFINER STABLE;

ALTER TABLE psy_kb_categories        ENABLE ROW LEVEL SECURITY;
ALTER TABLE psy_kb_resources         ENABLE ROW LEVEL SECURITY;
ALTER TABLE psy_kb_versions          ENABLE ROW LEVEL SECURITY;
ALTER TABLE psy_kb_bookmarks         ENABLE ROW LEVEL SECURITY;
ALTER TABLE psy_kb_views             ENABLE ROW LEVEL SECURITY;
ALTER TABLE psy_kb_note_folders      ENABLE ROW LEVEL SECURITY;
ALTER TABLE psy_kb_notes             ENABLE ROW LEVEL SECURITY;
ALTER TABLE psy_kb_trainings         ENABLE ROW LEVEL SECURITY;
ALTER TABLE psy_kb_training_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE psy_kb_certificates      ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  -- Shared read for all staff, write for staff (butiran kebenaran dikuatkuasa di UI/RBAC)
  CREATE POLICY "kb_cat_read"  ON psy_kb_categories FOR SELECT USING (kb_is_staff());
  CREATE POLICY "kb_cat_write" ON psy_kb_categories FOR ALL    USING (kb_is_staff()) WITH CHECK (kb_is_staff());

  CREATE POLICY "kb_res_read"  ON psy_kb_resources  FOR SELECT USING (kb_is_staff());
  CREATE POLICY "kb_res_write" ON psy_kb_resources  FOR ALL    USING (kb_is_staff()) WITH CHECK (kb_is_staff());

  CREATE POLICY "kb_ver_read"  ON psy_kb_versions   FOR SELECT USING (kb_is_staff());
  CREATE POLICY "kb_ver_write" ON psy_kb_versions   FOR ALL    USING (kb_is_staff()) WITH CHECK (kb_is_staff());

  CREATE POLICY "kb_train_read"  ON psy_kb_trainings FOR SELECT USING (kb_is_staff());
  CREATE POLICY "kb_train_write" ON psy_kb_trainings FOR ALL    USING (kb_is_staff()) WITH CHECK (kb_is_staff());

  -- Per-user
  CREATE POLICY "kb_bm_own"    ON psy_kb_bookmarks         FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
  CREATE POLICY "kb_views_own" ON psy_kb_views             FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
  CREATE POLICY "kb_fold_own"  ON psy_kb_note_folders      FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
  CREATE POLICY "kb_notes_own" ON psy_kb_notes             FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
  CREATE POLICY "kb_tprog_own" ON psy_kb_training_progress FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
  CREATE POLICY "kb_cert_own"  ON psy_kb_certificates      FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ── view_count increment (RPC, elak race + patuh RLS) ────────
CREATE OR REPLACE FUNCTION kb_bump_view(res UUID) RETURNS void AS $$
  UPDATE psy_kb_resources SET view_count = view_count + 1 WHERE id = res;
$$ LANGUAGE sql SECURITY DEFINER;

-- ============================================================
-- RBAC: daftar modul 'kb' supaya muncul di peranan.html
-- ============================================================
INSERT INTO psy_modules (code, label, icon, scope, sort_order) VALUES
  ('kb', 'Knowledge Base', '📖', 'staff', 185)
ON CONFLICT (code) DO UPDATE SET label=EXCLUDED.label, icon=EXCLUDED.icon, scope=EXCLUDED.scope, sort_order=EXCLUDED.sort_order;

INSERT INTO psy_module_actions (module_code, action_code) VALUES
  ('kb','view'),('kb','create'),('kb','edit'),('kb','delete'),('kb','export'),('kb','settings')
ON CONFLICT DO NOTHING;

-- Semua role boleh CRUD penuh (view/create/edit/delete/export). 'settings' (Pengurusan Admin)
-- kekal untuk super_admin+manager+admin sahaja.
INSERT INTO psy_role_module_actions (role_code, module_code, action_code) VALUES
  ('super_admin','kb','view'),('super_admin','kb','create'),('super_admin','kb','edit'),('super_admin','kb','delete'),('super_admin','kb','export'),('super_admin','kb','settings'),
  ('manager','kb','view'),('manager','kb','create'),('manager','kb','edit'),('manager','kb','delete'),('manager','kb','export'),('manager','kb','settings'),
  ('admin','kb','view'),('admin','kb','create'),('admin','kb','edit'),('admin','kb','delete'),('admin','kb','export'),('admin','kb','settings'),
  ('doctor','kb','view'),('doctor','kb','create'),('doctor','kb','edit'),('doctor','kb','delete'),('doctor','kb','export'),
  ('coach','kb','view'),('coach','kb','create'),('coach','kb','edit'),('coach','kb','delete'),('coach','kb','export')
ON CONFLICT DO NOTHING;

-- ============================================================
-- Seed kategori (11 — padan mockup)
-- ============================================================
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

-- ============================================================
-- Storage bucket untuk fail KB
-- ============================================================
INSERT INTO storage.buckets (id, name, public) VALUES ('kb-media', 'kb-media', true)
ON CONFLICT (id) DO NOTHING;

DO $$
BEGIN
  CREATE POLICY "kb_media_staff_write" ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'kb-media' AND kb_is_staff());
  CREATE POLICY "kb_media_staff_update" ON storage.objects
    FOR UPDATE TO authenticated
    USING (bucket_id = 'kb-media' AND kb_is_staff());
  CREATE POLICY "kb_media_staff_delete" ON storage.objects
    FOR DELETE TO authenticated
    USING (bucket_id = 'kb-media' AND kb_is_staff());
  CREATE POLICY "kb_media_public_read" ON storage.objects
    FOR SELECT USING (bucket_id = 'kb-media');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

SELECT 'OK — step95 knowledge base ready (' ||
  (SELECT COUNT(*) FROM psy_kb_categories) || ' kategori)' AS status;
