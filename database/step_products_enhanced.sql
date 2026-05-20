-- ============================================================
-- STEP — psy_products enhanced fields
-- Untuk sokong mockup baru: jenama, promo, stok lanjut, media, butiran, visibility
-- ============================================================

ALTER TABLE psy_products
  ADD COLUMN IF NOT EXISTS sku           TEXT,
  ADD COLUMN IF NOT EXISTS brand         TEXT,
  ADD COLUMN IF NOT EXISTS description_short TEXT,
  ADD COLUMN IF NOT EXISTS status        TEXT DEFAULT 'active',
  ADD COLUMN IF NOT EXISTS promo_price   NUMERIC(10,2),
  ADD COLUMN IF NOT EXISTS promo_until   DATE,
  ADD COLUMN IF NOT EXISTS min_stock     INT DEFAULT 5,
  ADD COLUMN IF NOT EXISTS unit          TEXT DEFAULT 'unit',
  ADD COLUMN IF NOT EXISTS track_inventory  BOOLEAN DEFAULT true,
  ADD COLUMN IF NOT EXISTS low_stock_alert  BOOLEAN DEFAULT true,
  ADD COLUMN IF NOT EXISTS image_urls    JSONB DEFAULT '[]',
  ADD COLUMN IF NOT EXISTS weight_size   TEXT,
  ADD COLUMN IF NOT EXISTS supplier      TEXT,
  ADD COLUMN IF NOT EXISTS tags          JSONB DEFAULT '[]',
  ADD COLUMN IF NOT EXISTS notes         TEXT,
  ADD COLUMN IF NOT EXISTS visible_in_shop  BOOLEAN DEFAULT true,
  ADD COLUMN IF NOT EXISTS featured      BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS online_purchase BOOLEAN DEFAULT true;

-- Backfill sku from product_id if null
UPDATE psy_products SET sku = product_id WHERE sku IS NULL;

-- Backfill status from is_active
UPDATE psy_products SET status = 'active'   WHERE status IS NULL AND is_active = true;
UPDATE psy_products SET status = 'inactive' WHERE status IS NULL AND is_active = false;

SELECT 'Step psy_products enhanced OK' AS status;
