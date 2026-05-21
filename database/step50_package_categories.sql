-- ============================================================
-- step50_package_categories.sql
-- Dynamic categories for packages — admin boleh CRUD dari UI
-- ============================================================

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

COMMENT ON TABLE psy_package_categories IS 'Senarai kategori pakej (dahulu hardcoded: standard/free/vip). Slug disimpan dalam psy_packages.tier.';
COMMENT ON COLUMN psy_package_categories.slug IS 'Stored value in psy_packages.tier (e.g. standard, free, vip, detox)';
COMMENT ON COLUMN psy_package_categories.badge_color IS 'Tailwind color suffix for badge (e.g. gold, green, navy) — null = no badge';

-- Seed kategori sedia ada
INSERT INTO psy_package_categories (slug, label, badge_color, sort_order)
VALUES
  ('standard', 'Program Intensif', NULL,    10),
  ('free',     'Pakej Percuma',    'green', 20),
  ('vip',      'VIP / Premium',    'gold',  30)
ON CONFLICT (slug) DO NOTHING;

-- RLS
ALTER TABLE psy_package_categories ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "Anyone read categories" ON psy_package_categories
    FOR SELECT USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "Staff manage categories" ON psy_package_categories
    FOR ALL USING (
      EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff')
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
