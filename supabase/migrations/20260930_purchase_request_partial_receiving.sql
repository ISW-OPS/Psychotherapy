-- ═══════════════════════════════════════════════════════════════════
-- Tier 8 (30 Sept 2026) — Partial receiving untuk Purchase Request —
-- supplier selalu hantar berperingkat (cth PR 100 unit, sampai 60 hari
-- ni, baki 40 lain hari).
-- Stock In sekarang boleh post kurang dari qty penuh tanpa terus tutup
-- PR sebagai 'purchased' — baki akan muncul balik kat 'Menunggu Diterima'
-- utk Stock In susulan. Lihat roles/staff/stock-in.html.
-- ═══════════════════════════════════════════════════════════════════

ALTER TABLE psy_inventory_request_items
  ADD COLUMN IF NOT EXISTS qty_received NUMERIC(10,2) NOT NULL DEFAULT 0;

ALTER TABLE psy_inventory_requests DROP CONSTRAINT IF EXISTS psy_inventory_requests_status_check;
ALTER TABLE psy_inventory_requests ADD CONSTRAINT psy_inventory_requests_status_check
  CHECK (status IN ('pending_approval','approved','partially_received','rejected','purchased'));
