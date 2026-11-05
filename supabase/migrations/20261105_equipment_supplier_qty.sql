-- 5 Nov 2026 — equipment-add.html: Pembekal jadi dropdown dari psy_suppliers
-- (dulu free text), + medan Kuantiti (daftar beberapa unit serupa sekaligus,
-- tiap satu dapat kod EQ- sendiri — peralatan ditrack per-unit, bukan qty
-- di 1 row, sbb status/assign/maintenance berasingan utk setiap unit fizikal).
-- Kolum `supplier` TEXT lama DIKEKALKAN (equipment-detail.html papar terus
-- drpd situ) — diisi nama supplier yg dipilih drpd dropdown baharu.
ALTER TABLE psy_equipment ADD COLUMN IF NOT EXISTS supplier_id UUID REFERENCES psy_suppliers(id) ON DELETE SET NULL;

-- 5 Nov 2026 (bahagian 2) — Inventory Management spec, Fasa 1: Jenis Penggunaan +
-- Anggaran Kapasiti Pesakit. "Jenis Penggunaan" guna consumption_type SEDIA ADA
-- (kini terdedah buat kali pertama di item-form.html, dulu tak boleh diubah staff
-- langsung). qty_per_patient + issue_unit/issue_units_per_stock_unit (ditambah 29
-- Okt) sama-sama bentuk pengiraan: (qty_in_stock * issue_units_per_stock_unit) /
-- qty_per_patient = anggaran berapa ramai pesakit boleh dapat ikut stok semasa.
-- Ni SEKADAR anggaran paparan — tak sentuh logik tolak stok sebenar (kekal ikut
-- jadual pakej/Bagi Bekalan di patient-hub.html, shared/inventoryDeduct.js).
ALTER TABLE psy_inventory_items ADD COLUMN IF NOT EXISTS qty_per_patient NUMERIC(10,4);
ALTER TABLE psy_inventory_items ADD COLUMN IF NOT EXISTS usage_frequency TEXT
  CHECK (usage_frequency IS NULL OR usage_frequency IN ('per_session','per_day','per_week','per_package','one_time'));
ALTER TABLE psy_inventory_items ADD COLUMN IF NOT EXISTS usage_notes TEXT;
