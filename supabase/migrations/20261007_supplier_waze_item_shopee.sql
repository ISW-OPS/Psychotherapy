-- ═══════════════════════════════════════════════════════════════════
-- Pautan lokasi (Waze) pada SUPPLIER & pautan Shopee pada PRODUK INVENTORI
-- Staff boleh klik terus untuk buka lokasi supplier (Waze) dan pembelian
-- produk di Shopee. Kedua-dua medan optional, jadi data sedia ada tak terjejas.
-- Tak ubah struktur sedia ada — hanya tambah kolum TEXT.
-- ═══════════════════════════════════════════════════════════════════

ALTER TABLE psy_suppliers ADD COLUMN IF NOT EXISTS location_url TEXT;      -- pautan Waze lokasi supplier
ALTER TABLE psy_inventory_items ADD COLUMN IF NOT EXISTS shopee_url TEXT;  -- pautan Shopee untuk beli produk ini
