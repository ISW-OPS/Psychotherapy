-- Product Status peringkat halus (Active/Inactive/Discontinued) — lihat
-- database/schema/14_products_inventory.sql (sumber kebenaran) utk versi
-- penuh + nota. is_active DIKEKALKAN (banyak query lain guna
-- .eq('is_active', true)) — status='inactive' ATAU 'discontinued' kedua-dua
-- set is_active=false.

ALTER TABLE psy_inventory_items ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'active'
  CHECK (status IN ('active','inactive','discontinued'));

-- Pastikan is_active wujud dulu — testing kadang tertinggal patch ni
-- (lihat database/schema/14_products_inventory.sql baris 52).
ALTER TABLE psy_inventory_items ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT true;

UPDATE psy_inventory_items SET status = CASE WHEN is_active = false THEN 'inactive' ELSE 'active' END
  WHERE status = 'active' AND is_active = false;
