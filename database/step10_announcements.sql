-- ============================================================
-- STEP 10 — PSY_ANNOUNCEMENTS
-- ============================================================

CREATE TABLE IF NOT EXISTS psy_announcements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  body TEXT,
  tag TEXT,
  bg TEXT DEFAULT 'from-navy to-green-dark',
  cta_label TEXT,
  cta_url TEXT,
  image_url TEXT,
  is_active BOOLEAN DEFAULT true,
  sort_order INT DEFAULT 0,
  starts_at TIMESTAMPTZ,
  ends_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE psy_announcements ADD COLUMN IF NOT EXISTS image_url TEXT;

ALTER TABLE psy_announcements ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN CREATE POLICY "Anyone read active announcements" ON psy_announcements FOR SELECT USING (is_active = true); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "Staff manage announcements" ON psy_announcements FOR ALL USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff')); EXCEPTION WHEN duplicate_object THEN NULL; END $$;

INSERT INTO psy_announcements (title, body, tag, bg, cta_label, cta_url, sort_order) VALUES
  ('Kelas Mindfulness Percuma', 'Setiap Sabtu 9AM — Sertai sesi meditasi & pernafasan bersama Coach Izzah.', 'Kelas Minggu Ini', 'from-navy to-teal', 'Daftar Sekarang', 'https://wa.me/60123456789', 1),
  ('Program Detox Digital', 'Cabaran 7 hari kurangkan screen time untuk kesejahteraan mental anda.', 'Challenge Baru', 'from-green-dark to-teal', 'Sertai Cabaran', null, 2),
  ('Pakej Ramadan Khas', 'Rawatan holistik dengan fokus spiritual — promosi sehingga hujung bulan.', 'Promosi', 'from-navy to-green-dark', 'Lihat Pakej', 'pakej.html', 3)
ON CONFLICT DO NOTHING;

SELECT 'Step 10 OK — psy_announcements ready' AS status;
