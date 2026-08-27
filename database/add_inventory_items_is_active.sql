-- Migration: psy_inventory_items.is_active
-- Kolum ni DAH lama ada dalam database/schema/14_products_inventory.sql
-- (ALTER TABLE ... ADD COLUMN IF NOT EXISTS is_active) tapi rupanya tak
-- pernah dijalankan pada testing — punca "Choose Supply" modal di
-- pakej-edit.html papar "No items" walaupun Inventory ada banyak item.
-- Root cause: query openSupplyPicker() filter .eq('is_active', true),
-- PostgREST return ralat 42703 "column does not exist" (bukan senarai
-- kosong), lalu window._invItems disenyapkan jadi [].
-- Additive only, idempotent — selamat re-run.
-- Run on testing (ipmemyiz) dulu, verify (buka pakej-edit.html -> Choose
-- Supply modal patut papar semua item), lepas tu run pada prod (xmvqvq)
-- kalau prod pun kena isu sama.

ALTER TABLE psy_inventory_items
  ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT true;

CREATE INDEX IF NOT EXISTS idx_inventory_items_is_active ON psy_inventory_items(is_active);

COMMENT ON COLUMN psy_inventory_items.is_active IS
  'false = item tidak aktif — disorok dari senarai pilihan (dispens/kit/jadual pakej) & auto-request.';
