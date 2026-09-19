-- ============================================================
-- Shop ↔ Inventori: produk MESTI wujud di Inventori baru boleh dijual
-- ============================================================
-- Ganti add_shop_unavailable_products_rpc.sql (fungsi lama ditakrif semula di bawah).
-- Idempotent — selamat dijalankan berulang kali. Run di TESTING dahulu, kemudian PROD.
--
-- Peraturan "boleh dijual" (sellable) untuk satu produk Shop:
--   1) ada item Inventori dipaut: psy_products.inventory_item_id, ATAU nama sama
--      (case-insensitive, trim; bila beberapa item sama nama, yang aktif diutamakan), DAN
--   2) status item itu 'active'.
-- Produk tanpa item Inventori, atau item Inactive/Discontinued = TIDAK boleh dijual.
--
-- Pesakit tak boleh SELECT psy_inventory_items (RLS: staf sahaja), jadi fungsi SECURITY DEFINER
-- ini dedah HANYA: product_id, nama, sama ada dipaut, status item, stok semasa & unit.
-- to_jsonb() dipakai supaya selamat walaupun lajur status / is_active tiada pada sesuatu persekitaran.

-- ── 1. Backfill pautan FK utk produk yang dipaut ikut nama sahaja ────────────────────────
-- (Pautan FK kekal betul walaupun item Inventori kemudian dinamakan semula.)
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

-- ── 2. Status inventori setiap produk ────────────────────────────────────────────────────
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
    (m.id IS NOT NULL) AS linked,
    m.st AS item_status,
    m.qty,
    m.unit,
    (m.id IS NOT NULL AND m.st = 'active') AS sellable
  FROM psy_products p
  LEFT JOIN LATERAL (
    SELECT i.id,
           COALESCE(to_jsonb(i)->>'status',
                    CASE WHEN to_jsonb(i)->>'is_active' = 'false' THEN 'inactive' ELSE 'active' END) AS st,
           i.qty_in_stock AS qty,
           i.unit
    FROM psy_inventory_items i
    WHERE i.id = p.inventory_item_id
       OR (p.inventory_item_id IS NULL AND lower(trim(i.name)) = lower(trim(p.name)))
    ORDER BY (i.id = p.inventory_item_id) DESC NULLS LAST,
             (COALESCE(to_jsonb(i)->>'status',
                       CASE WHEN to_jsonb(i)->>'is_active' = 'false' THEN 'inactive' ELSE 'active' END) = 'active') DESC
    LIMIT 1
  ) m ON true;
$$;

GRANT EXECUTE ON FUNCTION psy_shop_product_inventory() TO authenticated, anon;

-- ── 3. Fungsi lama (dipakai payment.html versi terdahulu): produk yang TIDAK boleh dijual ─
CREATE OR REPLACE FUNCTION psy_shop_unavailable_products()
RETURNS TABLE (product_id TEXT, name TEXT)
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT s.product_id, s.name FROM psy_shop_product_inventory() s WHERE NOT s.sellable;
$$;

GRANT EXECUTE ON FUNCTION psy_shop_unavailable_products() TO authenticated, anon;
