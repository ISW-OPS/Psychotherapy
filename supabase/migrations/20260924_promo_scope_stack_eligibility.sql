-- Audit management 23 Sept 2026, Tier 5 (#D-15, #D-16, #D-17) — skop
-- "Terpakai Untuk" (Produk/Kategori/Pakej), gabung baucar (stackable),
-- eligibility pelanggan baharu, label kempen.
-- Rujuk: database/schema/29_promo_codes.sql

ALTER TABLE psy_promo_codes ADD COLUMN IF NOT EXISTS applies_to TEXT NOT NULL DEFAULT 'all'
  CHECK (applies_to IN ('all','product','category','package'));
ALTER TABLE psy_promo_codes ADD COLUMN IF NOT EXISTS applies_to_values TEXT[];
ALTER TABLE psy_promo_codes ADD COLUMN IF NOT EXISTS stackable BOOLEAN NOT NULL DEFAULT true;
ALTER TABLE psy_promo_codes ADD COLUMN IF NOT EXISTS new_customer_only BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE psy_promo_codes ADD COLUMN IF NOT EXISTS campaign TEXT;
