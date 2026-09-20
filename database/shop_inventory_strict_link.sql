-- ============================================================
-- Shop ↔ Inventori: pautan HANYA melalui ID (psy_products.inventory_item_id), bukan nama
-- ============================================================
-- Ganti definisi psy_shop_product_inventory() dalam add_shop_inventory_link.sql (buang padanan nama).
-- Idempotent — selamat dijalankan berulang kali. Run di TESTING dahulu, kemudian PROD.
--
-- 1) Backfill terakhir: produk lama tanpa FK dipaut ikut nama SEKALI SAHAJA supaya tiada produk
--    lama terputus pautan bila padanan nama dibuang (item aktif diutamakan).
-- 2) Fungsi status inventori kini padan ikut inventory_item_id sahaja.
--    Produk tanpa inventory_item_id = TIDAK boleh dijual.

UPDATE psy_products p
SET inventory_item_id = m.id
FROM (
  SELECT DISTINCT ON (lower(trim(i.name))) lower(trim(i.name)) AS nm, i.id
  FROM psy_inventory_items i
  ORDER BY lower(trim(i.name)),
           (COALESCE(to_jsonb(i)->>'status',
                     CASE WHEN to_jsonb(i)->>'is_active' = 'false' THEN 'inactive' ELSE 'active' END) = 'active') DESC,
           i.id
) m
WHERE p.inventory_item_id IS NULL
  AND lower(trim(p.name)) = m.nm;

CREATE OR REPLACE FUNCTION psy_shop_product_inventory()
RETURNS TABLE (
  product_id    TEXT,
  name          TEXT,
  linked        BOOLEAN,
  item_status   TEXT,
  qty_in_stock  NUMERIC,
  unit          TEXT,
  sellable      BOOLEAN
)
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    p.product_id::text,
    p.name,
    (i.id IS NOT NULL) AS linked,
    CASE WHEN i.id IS NULL THEN NULL
         ELSE COALESCE(to_jsonb(i)->>'status',
                       CASE WHEN to_jsonb(i)->>'is_active' = 'false' THEN 'inactive' ELSE 'active' END) END AS item_status,
    i.qty_in_stock,
    i.unit,
    (i.id IS NOT NULL
      AND COALESCE(to_jsonb(i)->>'status',
                   CASE WHEN to_jsonb(i)->>'is_active' = 'false' THEN 'inactive' ELSE 'active' END) = 'active') AS sellable
  FROM psy_products p
  LEFT JOIN psy_inventory_items i ON i.id = p.inventory_item_id;
$$;

GRANT EXECUTE ON FUNCTION psy_shop_product_inventory() TO authenticated, anon;
