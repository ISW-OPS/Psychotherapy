-- Menu & Hidangan Cadangan: tukar drpd teks bebas (satu baris satu item) kepada
-- senarai berstruktur [{name, image_url}] supaya setiap menu boleh ada gambar
-- sendiri (opsyenal). Idempoten — guard ikut jenis kolum sedia ada.
--
-- Nota: ALTER COLUMN ... TYPE ... USING tak boleh guna subquery terus
-- (ERROR 0A000). Jadi tukar guna kolum sementara + UPDATE biasa (yang
-- membenarkan subquery/aggregate), lepas tu gantikan kolum asal.

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'psy_recommended_products' AND column_name = 'menu_items' AND data_type <> 'jsonb'
  ) THEN
    ALTER TABLE psy_recommended_products ADD COLUMN menu_items_new JSONB DEFAULT '[]';

    UPDATE psy_recommended_products
    SET menu_items_new = COALESCE(
      (SELECT jsonb_agg(jsonb_build_object('name', trim(line), 'image_url', null))
       FROM unnest(string_to_array(menu_items, E'\n')) AS line
       WHERE trim(line) <> ''),
      '[]'::jsonb
    )
    WHERE menu_items IS NOT NULL AND trim(menu_items) <> '';

    ALTER TABLE psy_recommended_products DROP COLUMN menu_items;
    ALTER TABLE psy_recommended_products RENAME COLUMN menu_items_new TO menu_items;
  END IF;
END $$;

-- Jadual baharu/belum pernah ada kolum ni langsung (jaga-jaga).
ALTER TABLE psy_recommended_products ADD COLUMN IF NOT EXISTS menu_items JSONB DEFAULT '[]';
