-- ============================================================
-- step_inventory_supplier_info.sql
-- Tambah supplier_info JSONB pada psy_inventory_items
-- Format: { name, cost_per_unit, lead_days, po_min, po_max }
-- ============================================================

ALTER TABLE psy_inventory_items
  ADD COLUMN IF NOT EXISTS supplier_info JSONB DEFAULT '{}'::jsonb;

COMMENT ON COLUMN psy_inventory_items.supplier_info IS
  'Format: { name, cost_per_unit, lead_days, po_min, po_max }. Maklumat pembekal dan cadangan PO.';
