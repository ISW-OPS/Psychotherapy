-- ============================================================
-- PRODUCTS TABLE — shop items managed by staff
-- ============================================================

CREATE TABLE IF NOT EXISTS products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  description TEXT,
  category TEXT,
  price NUMERIC(10,2) DEFAULT 0,
  stock INT,
  icon TEXT DEFAULT '📦',
  bg_color TEXT DEFAULT 'bg-cream',
  is_active BOOLEAN DEFAULT true,
  sort_order INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE products ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone read products" ON products FOR SELECT USING (true);
CREATE POLICY "Staff manage products" ON products FOR ALL
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'staff'));

-- Seed initial products
INSERT INTO products (product_id, name, description, category, price, icon, bg_color, sort_order) VALUES
  ('madu-shifa-500g', 'Madu Shifa 500g', 'Pure raw honey · acacia', 'Madu', 85, '🍯', 'bg-gold-light', 1),
  ('madu-kelulut', 'Madu Kelulut 400g', 'Stingless bee honey', 'Madu', 120, '🍯', 'bg-gold-light', 2),
  ('jus-halia', 'Jus Halia Concentrate', '250ml · 100% natural', 'Herba', 45, '🌿', 'bg-green-light', 3),
  ('herba-zaitun', 'Minyak Zaitun Tulen', '500ml · cold-pressed', 'Herba', 65, '🫒', 'bg-green-light', 4),
  ('magnesium', 'Magnesium Glycinate', '60 caps · 200mg', 'Supplements', 55, '💊', 'bg-navy-light', 5),
  ('vitamin-d', 'Vitamin D3 5000IU', '90 softgels', 'Supplements', 48, '☀️', 'bg-gold-light', 6),
  ('santapan-fitrah', 'Santapan Fitrah Set', '7-day starter pack', 'Santapan Fitrah', 220, '🌱', 'bg-terracotta-light', 7),
  ('rahsia-syifa', 'Rahsia Syifa Book', 'Ibn Sina & modern med', 'Books', 35, '📖', 'bg-navy-light', 8),
  ('doa-syifa-book', 'Kitab Doa Syifa', 'Tafsir + transliterasi', 'Books', 28, '📖', 'bg-terracotta-light', 9)
ON CONFLICT (product_id) DO NOTHING;
