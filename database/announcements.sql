-- ============================================================
-- ANNOUNCEMENTS — promo/event banners for patient dashboard carousel
-- Managed by staff via staff portal
-- ============================================================

CREATE TABLE IF NOT EXISTS announcements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  body TEXT,
  tag TEXT,                          -- e.g. "Kelas Baru", "Event"
  bg TEXT DEFAULT 'from-navy to-green-dark',  -- Tailwind gradient classes
  cta_label TEXT,                    -- Button label, e.g. "Daftar Sekarang"
  cta_url TEXT,                      -- Link destination
  is_active BOOLEAN DEFAULT true,
  sort_order INT DEFAULT 0,
  starts_at TIMESTAMPTZ,
  ends_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE announcements ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone read active announcements" ON announcements
  FOR SELECT USING (is_active = true);

CREATE POLICY "Staff manage announcements" ON announcements
  FOR ALL USING (EXISTS (
    SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'staff'
  ));

-- Sample data
INSERT INTO announcements (title, body, tag, bg, cta_label, cta_url, sort_order) VALUES
  ('Kelas Mindfulness Percuma', 'Setiap Sabtu 9AM — Sertai sesi meditasi & pernafasan bersama Coach Izzah.', 'Kelas Minggu Ini', 'from-navy to-teal', 'Daftar Sekarang', 'https://wa.me/60123456789', 1),
  ('Program Detox Digital', 'Cabaran 7 hari kurangkan screen time untuk kesejahteraan mental anda.', 'Challenge Baru', 'from-green-dark to-teal', 'Sertai Cabaran', null, 2),
  ('Pakej Ramadan Khas', 'Rawatan holistik dengan fokus spiritual — promosi sehingga hujung bulan.', 'Promosi', 'from-navy to-green-dark', 'Lihat Pakej', 'pakej.html', 3);
