-- 5 Nov 2026 — equipment-add.html: Pembekal jadi dropdown dari psy_suppliers
-- (dulu free text), + medan Kuantiti (daftar beberapa unit serupa sekaligus,
-- tiap satu dapat kod EQ- sendiri — peralatan ditrack per-unit, bukan qty
-- di 1 row, sbb status/assign/maintenance berasingan utk setiap unit fizikal).
-- Kolum `supplier` TEXT lama DIKEKALKAN (equipment-detail.html papar terus
-- drpd situ) — diisi nama supplier yg dipilih drpd dropdown baharu.
ALTER TABLE psy_equipment ADD COLUMN IF NOT EXISTS supplier_id UUID REFERENCES psy_suppliers(id) ON DELETE SET NULL;

-- 5 Nov 2026 (bahagian 2) — Jenis Penggunaan "Kegunaan Pesakit" vs "Dalaman/Am"
-- guna consumption_type SEDIA ADA (kini terdedah buat kali pertama di
-- item-form.html, dulu tak boleh diubah staff langsung).
--
-- 5 Nov 2026 (bahagian 3) — REVERT bahagian 2 punya qty_per_patient/
-- usage_frequency/usage_notes (card "Konfigurasi Penggunaan Pesakit"). Punca:
-- ia "double data" dgn sistem Kit Prosedur (psy_procedure_kits + supplies di
-- pakej-edit.html) yg SEDIA ADA jadi sumber kebenaran SEBENAR utk kuantiti
-- guna-per-pesakit (cth IV Drip = 1 Inci tape + 1 Drip Water) — letak sekali
-- lagi kat produk cuma buat 2 tempat berlainan boleh bercanggah. Kuantiti
-- betul2 digunakan pesakit kekal ditetapkan di jadual pakej (per-minggu), bukan
-- nilai statik di produk. DROP (bukan sekadar tak-tambah) sbb ADD COLUMN
-- bahagian 2 asal (push awal) mungkin dah di-run org.
ALTER TABLE psy_inventory_items DROP COLUMN IF EXISTS qty_per_patient;
ALTER TABLE psy_inventory_items DROP COLUMN IF EXISTS usage_frequency;
ALTER TABLE psy_inventory_items DROP COLUMN IF EXISTS usage_notes;

-- 5 Nov 2026 (bahagian 3b) — Selaraskan senarai unit ikut spec "Stock Unit"
-- (Unit/Piece/Pack/Box/Bottle/Roll/Set/Pair/Bag/Carton/Kg/Gram/Liter/ml/
-- Meter/cm/inch). Dibuang: Tiub/Tablet/Kapsul/Gelas/Milimeter (disahkan 0
-- item psy_inventory_items guna — selamat). DIKEKALKAN Naskhah walau tiada
-- dlm spec sbb 19 item sedia ada (bahan cetak) guna dia. Baharu: Karton, Meter.
ALTER TABLE psy_inventory_items DROP CONSTRAINT IF EXISTS psy_inventory_items_unit_check;
ALTER TABLE psy_inventory_items DROP CONSTRAINT IF EXISTS psy_inventory_items_issue_unit_check;
ALTER TABLE psy_inventory_items ADD CONSTRAINT psy_inventory_items_unit_check
  CHECK (unit IN ('Pcs','Botol','Kotak','Pek','Set','Gulung','Beg','Karton','Pasang',
                   'Unit','Gram','Kg','Naskhah',
                   'Liter (L)','Mililiter (ml)','Meter (m)','Sentimeter (cm)','Inci (inch)'));
ALTER TABLE psy_inventory_items ADD CONSTRAINT psy_inventory_items_issue_unit_check
  CHECK (issue_unit IS NULL OR issue_unit IN ('Pcs','Botol','Kotak','Pek','Set','Gulung','Beg','Karton','Pasang',
                   'Unit','Gram','Kg','Naskhah',
                   'Liter (L)','Mililiter (ml)','Meter (m)','Sentimeter (cm)','Inci (inch)'));

-- 5 Nov 2026 (bahagian 4) — Kit Prosedur/jadual pakej (pakej-edit.html) SEBENARNYA
-- tiada pengiraan issue_unit (cth stok=Gulung tapi pesakit guna Inci) — admin
-- terpaksa taip pecahan stok manual (cth 0.033 Gulung utk 1 Inci), tiada cara
-- nak expresi "1 Inci" terus. deductSessionSupplies() (shared/inventoryDeduct.js)
-- pun DAH BETUL (ambil qty terus sbg unit stok) — isunya cuma di borang input
-- (pakej-edit.html renderSuppliesList/addSupplyFromPicker/updateSupplyQty, dah
-- dikemaskini di kod) supaya admin boleh taip terus dlm Inci, auto ditukar &
-- disimpan dlm unit stok (qty tetap unit stok — TIADA perubahan skema/data,
-- cuma UI input). Tiada migration SQL diperlukan utk bahagian ni.
