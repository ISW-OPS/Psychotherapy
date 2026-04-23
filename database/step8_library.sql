-- ============================================================
-- STEP 8 — PSY_LIBRARY_ITEMS
-- ============================================================

CREATE TABLE IF NOT EXISTS psy_library_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  item_id TEXT UNIQUE,
  title TEXT NOT NULL,
  description TEXT,
  content_type TEXT,
  content_url TEXT,
  category TEXT,
  icon TEXT DEFAULT '📄',
  gradient TEXT DEFAULT 'from-navy to-teal',
  content_body TEXT,
  is_active BOOLEAN DEFAULT true,
  sort_order INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE psy_library_items ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN CREATE POLICY "Anyone read library" ON psy_library_items FOR SELECT USING (true); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "Staff manage library" ON psy_library_items FOR ALL USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff')); EXCEPTION WHEN duplicate_object THEN NULL; END $$;

INSERT INTO psy_library_items (item_id, title, description, content_type, category, icon, gradient, sort_order) VALUES
  ('bps-s-intro', 'Apa itu BPS-S model?', 'Dr. Hamzah menerangkan 4 pillar holistik Ibn Sina', 'Video · 8 min', 'navy', '🎥', 'from-navy to-teal', 1),
  ('santapan-panduan', 'Santapan Fitrah: Panduan Harian', 'Resipi + cara penyediaan untuk 7 hari pertama', 'Article · 5 min', 'green', '📝', 'from-green to-gold-dark', 2),
  ('zikir-syifa', 'Zikir Pagi Petang Syifa', 'Audio + transliterasi untuk amalan harian', 'Doa & Zikir', 'terracotta', '🕌', 'from-terracotta to-gold-dark', 3),
  ('breathing-muraqabah', 'Breathing & Muraqabah', 'Teknik pernafasan untuk ketenangan mental', 'Exercise · 15 min', 'gold', '🧘‍♀️', 'from-gold to-green', 4),
  ('faq-baru', '10 Soalan Lazim Pesakit Baru', 'Apa yang perlu anda tahu sebelum memulakan', 'FAQ', 'teal', '💬', 'from-teal to-navy', 5),
  ('mood-tracker', 'Mood & Progress Tracker', 'PDF printable untuk rekod harian', 'Worksheet', 'ink', '📊', 'from-navy to-terracotta', 6)
ON CONFLICT (item_id) DO NOTHING;

SELECT 'Step 8 OK — psy_library_items ready' AS status;
