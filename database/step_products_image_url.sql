-- ============================================================
-- STEP — psy_products.image_url (single primary image)
-- Schema sedia ada: image_urls JSONB (array, plural).
-- UI product-edit.html guna image_url (singular, satu gambar utama).
-- Tambah column untuk match dengan kod, kekal image_urls untuk future.
-- ============================================================

ALTER TABLE psy_products
  ADD COLUMN IF NOT EXISTS image_url TEXT;

COMMENT ON COLUMN psy_products.image_url IS
  'URL gambar utama produk (single). Untuk gallery multi-gambar, guna image_urls (JSONB array).';

-- Backfill: kalau image_urls ada element pertama, copy ke image_url
UPDATE psy_products
SET image_url = image_urls->>0
WHERE image_url IS NULL
  AND image_urls IS NOT NULL
  AND jsonb_array_length(image_urls) > 0;

-- ── Verification: semua column yang product-edit.html guna ──
DO $$
DECLARE
  required_cols TEXT[] := ARRAY[
    'name','sku','product_id','category','status','is_active',
    'brand','description','description_short',
    'price','promo_price','promo_until',
    'stock','min_stock','unit','track_inventory','low_stock_alert',
    'image_url','image_urls','weight_size','supplier','tags','notes',
    'visible_in_shop','featured','online_purchase',
    'inventory_item_id','updated_at'
  ];
  missing_cols TEXT[] := '{}';
  col TEXT;
BEGIN
  FOREACH col IN ARRAY required_cols LOOP
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_name = 'psy_products' AND column_name = col
    ) THEN
      missing_cols := array_append(missing_cols, col);
    END IF;
  END LOOP;

  IF array_length(missing_cols, 1) > 0 THEN
    RAISE NOTICE 'MASIH MISSING dalam psy_products: %', missing_cols;
  ELSE
    RAISE NOTICE 'OK — semua column product-edit.html sudah ada';
  END IF;
END $$;

SELECT 'OK — psy_products.image_url added + verified' AS status;
