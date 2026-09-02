-- Buang trigger DB psy_inventory_auto_request — ia guna medan `max_qty` yang tak pernah
-- diisi di mana-mana borang/kod staff (sentiasa NULL), jadi trigger ni sentiasa fallback ke
-- min_qty untuk SEMUA item (tak kira consumption_type='package' ke tidak) — langsung tak
-- selaras dengan logik forecast (shared/inventoryForecast.js) yang kini jadi SATU-SATUNYA
-- sumber kebenaran utk Auto-PO (checkAutoPO() di inventory.html, dipanggil client-side
-- setiap kali page dibuka). Lihat database/schema/14_products_inventory.sql baris 174-283
-- utk versi asal (sumber kebenaran skema patut dikemaskini buang bahagian trigger ni juga).

DROP TRIGGER IF EXISTS trg_psy_inventory_auto_request ON psy_inventory_items;
DROP FUNCTION IF EXISTS psy_inventory_auto_request();
