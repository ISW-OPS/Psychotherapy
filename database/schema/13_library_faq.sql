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
