-- ============================================================
-- SERVICES TABLE — appointment types managed by staff
-- ============================================================

CREATE TABLE IF NOT EXISTS services (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  service_id TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  description TEXT,
  price NUMERIC(10,2) DEFAULT 0,
  duration_min INT DEFAULT 30,
  icon TEXT DEFAULT '⚕',
  is_active BOOLEAN DEFAULT true,
  sort_order INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE services ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone read services" ON services FOR SELECT USING (true);
CREATE POLICY "Staff manage services" ON services FOR ALL
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'staff'));

-- Seed default services
INSERT INTO services (service_id, name, description, price, duration_min, icon, sort_order) VALUES
  ('consultation', 'Consultation with Doctor', 'Dr. Hamzah, Dr. Aziz · Perubatan Alami + BPS-S assessment', 120, 45, '⚕', 1),
  ('coaching', 'Coaching Session', 'SU · OB · NLC · JS programs', 80, 60, '🎯', 2),
  ('nurse', 'Nurse Check-up', 'Vital signs, blood pressure, routine monitoring', 40, 20, '✚', 3),
  ('nutrition', 'Nutrition Consultation', 'Santapan Fitrah · diet plan · Nutritionist', 70, 30, '🌱', 4)
ON CONFLICT (service_id) DO NOTHING;
