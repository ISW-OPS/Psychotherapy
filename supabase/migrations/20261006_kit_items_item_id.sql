-- ═══════════════════════════════════════════════════════════════════
-- Kit Prosedur: simpan item_id (ID Inventori) pada setiap entri kit
-- Sebelum ni padanan kit ↔ item inventori dibuat ikut NAMA sahaja
-- (inventory-detail.html). Nama boleh tukar, dan dua item nama sama
-- akan bertindih. Migration ni:
--   1. Backfill item_id untuk entri sedia ada — HANYA bila nama padan
--      tepat dengan SATU item inventori (case-insensitive). Nama yang
--      samar atau tiada padanan dibiarkan null (fallback nama kekal).
--   2. Entri yang sudah ada item_id tak diubah.
-- Tak mengubah struktur jadual — items kekal JSONB.
-- ═══════════════════════════════════════════════════════════════════

WITH unique_items AS (
  SELECT lower(trim(name)) AS match_key, (array_agg(id))[1] AS item_id
  FROM psy_inventory_items
  GROUP BY lower(trim(name))
  HAVING count(*) = 1
)
UPDATE psy_procedure_kits k
SET items = (
  SELECT coalesce(jsonb_agg(
    CASE
      WHEN u.item_id IS NULL OR (e->>'item_id') IS NOT NULL THEN e
      ELSE jsonb_set(e, '{item_id}', to_jsonb(u.item_id::text))
    END
    ORDER BY ord
  ), '[]'::jsonb)
  FROM jsonb_array_elements(k.items) WITH ORDINALITY AS t(e, ord)
  LEFT JOIN unique_items u ON u.match_key = lower(trim(e->>'item_name'))
)
WHERE jsonb_typeof(k.items) = 'array'
  AND jsonb_array_length(k.items) > 0;
