-- ============================================================
-- Inventori: kod item pendek (INV-01, INV-02, ...) sebagai ID mesra pengguna
-- ============================================================
-- Kolum item_code tertakrif dalam schema tetapi TIDAK pernah dipasang pada pangkalan data sebenar,
-- jadi lajur "Kod Produk" di senarai Inventori sentiasa kosong. Fail ini memasangnya + trigger auto-jana.
-- Format: INV-01 … INV-99, kemudian INV-100, INV-101 … (tidak dipotong bila > 99).
-- Item sedia ada diberi kod ikut tarikh dicipta. Kod lama format ITM-00001 (kalau ada) ditukar ke INV-01.
-- Idempotent — selamat dijalankan berulang kali. Run di TESTING dahulu, kemudian PROD.

ALTER TABLE psy_inventory_items ADD COLUMN IF NOT EXISTS item_code TEXT UNIQUE;

CREATE SEQUENCE IF NOT EXISTS psy_inventory_item_code_seq START 1;

CREATE OR REPLACE FUNCTION psy_inventory_format_code(n BIGINT)
RETURNS TEXT
LANGUAGE sql IMMUTABLE
AS $$ SELECT 'INV-' || CASE WHEN n < 10 THEN '0' || n::text ELSE n::text END $$;

CREATE OR REPLACE FUNCTION psy_inventory_set_item_code()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.item_code IS NULL THEN
    NEW.item_code := psy_inventory_format_code(nextval('psy_inventory_item_code_seq'));
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_psy_inventory_set_item_code ON psy_inventory_items;
CREATE TRIGGER trg_psy_inventory_set_item_code
BEFORE INSERT ON psy_inventory_items
FOR EACH ROW EXECUTE FUNCTION psy_inventory_set_item_code();

-- Tukar kod lama ITM-00001 → INV-01 (nombor sama dikekalkan)
UPDATE psy_inventory_items
SET item_code = psy_inventory_format_code(substring(item_code FROM 5)::bigint)
WHERE item_code ~ '^ITM-[0-9]+$'
  AND NOT EXISTS (
    SELECT 1 FROM psy_inventory_items o
    WHERE o.item_code = psy_inventory_format_code(substring(psy_inventory_items.item_code FROM 5)::bigint)
  );

-- Jujukan seterusnya bermula selepas nombor INV tertinggi sedia ada
SELECT setval('psy_inventory_item_code_seq',
  COALESCE((SELECT max(substring(item_code FROM 5)::bigint) FROM psy_inventory_items WHERE item_code ~ '^INV-[0-9]+$'), 0) + 1,
  false);

-- Beri kod kepada item yang belum ada, ikut tarikh dicipta
DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN SELECT id FROM psy_inventory_items WHERE item_code IS NULL ORDER BY created_at, id LOOP
    UPDATE psy_inventory_items
      SET item_code = psy_inventory_format_code(nextval('psy_inventory_item_code_seq'))
      WHERE id = r.id;
  END LOOP;
END $$;
