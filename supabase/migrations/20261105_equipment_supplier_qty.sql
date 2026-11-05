-- 5 Nov 2026 — equipment-add.html: Pembekal jadi dropdown dari psy_suppliers
-- (dulu free text), + medan Kuantiti (daftar beberapa unit serupa sekaligus,
-- tiap satu dapat kod EQ- sendiri — peralatan ditrack per-unit, bukan qty
-- di 1 row, sbb status/assign/maintenance berasingan utk setiap unit fizikal).
-- Kolum `supplier` TEXT lama DIKEKALKAN (equipment-detail.html papar terus
-- drpd situ) — diisi nama supplier yg dipilih drpd dropdown baharu.
ALTER TABLE psy_equipment ADD COLUMN IF NOT EXISTS supplier_id UUID REFERENCES psy_suppliers(id) ON DELETE SET NULL;

-- 5 Nov 2026 (bahagian 1b) — Equipment Category (18 pilihan) + Storage Location
-- (22 pilihan, kolum TEXT baharu — BERBEZA drpd location_id lama yg rujuk
-- psy_inventory_locations/gudang stok, tak pernah terdedah di UI). Senarai
-- tetap kat shared/equipmentMasterData.js, dipakai equipment-add.html.
ALTER TABLE psy_equipment ADD COLUMN IF NOT EXISTS storage_location TEXT;

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

-- 5 Nov 2026 (bahagian 3c) — Jadual urus kategori produk (Add/Rename/Padam) —
-- psy_inventory_items.category KEKAL TEXT bebas (tiada perubahan di tempat
-- lain), jadual ni cuma sumber dropdown + "Urus Kategori" di item-form.html,
-- ganti cara lama (DISTINCT drpd item sedia ada). Padam SELAMAT (tiada FK).
CREATE TABLE IF NOT EXISTS psy_inventory_categories (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name        TEXT NOT NULL UNIQUE,
  is_active   BOOLEAN NOT NULL DEFAULT true,
  created_at  TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE psy_inventory_categories ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Staff manage categories" ON psy_inventory_categories;
CREATE POLICY "Staff manage categories" ON psy_inventory_categories FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
INSERT INTO psy_inventory_categories (name)
SELECT DISTINCT category FROM psy_inventory_items WHERE category IS NOT NULL AND category <> ''
ON CONFLICT (name) DO NOTHING;

-- 5 Nov 2026 (bahagian 4) — Kit Prosedur/jadual pakej (pakej-edit.html) SEBENARNYA
-- tiada pengiraan issue_unit (cth stok=Gulung tapi pesakit guna Inci) — admin
-- terpaksa taip pecahan stok manual (cth 0.033 Gulung utk 1 Inci), tiada cara
-- nak expresi "1 Inci" terus. deductSessionSupplies() (shared/inventoryDeduct.js)
-- pun DAH BETUL (ambil qty terus sbg unit stok) — isunya cuma di borang input
-- (pakej-edit.html renderSuppliesList/addSupplyFromPicker/updateSupplyQty, dah
-- dikemaskini di kod) supaya admin boleh taip terus dlm Inci, auto ditukar &
-- disimpan dlm unit stok (qty tetap unit stok — TIADA perubahan skema/data,
-- cuma UI input). Tiada migration SQL diperlukan utk bahagian ni.

-- ═══════════════════════════════════════════════════════════════════
-- 5 Nov 2026 (bahagian 5) — Import data: 26 produk "Clinical Equipment"
-- (Oxygen Concentrator, Wheelchair, BP Monitor, dll) ke psy_inventory_items,
-- semua lokasi "Clinical Store". Harga julat (cth "2000-4500") -> Harga
-- Anggaran Min/Maks (supplier_info.cost_per_unit_min/max), Price (RM) tunggal
-- dibiarkan kosong (cost_per_unit NULL) ikut keputusan "Harga Anggaran
-- berdiri sendiri" hari ni. Harga "500+"/"1000+" (open-ended) -> Min sahaja,
-- Maks NULL. Gambar produk TIADA fail sebenar diberi — image_url kekal NULL,
-- perlu upload manual lepas ni. Opening stock masuk ke psy_inventory_stock_
-- by_location (trigger psy_sync_item_stock_total auto-kemaskini qty_in_stock
-- aggregate) + ledger psy_stock_movements (reference_type='opening_stock'),
-- SAMA laluan dgn addStockToLocation() yg item-form.html guna — JANGAN set
-- qty_in_stock terus pada INSERT psy_inventory_items. requires_approval=true
-- utk SEMUA 26 produk ni (per arahan). Idempoten (boleh run semula selamat
-- — skip baris yg nama/stok/ledger dah wujud).
-- ═══════════════════════════════════════════════════════════════════
-- NOTA: TANPA "ON COMMIT DROP" (meskipun TEMP) — Supabase SQL editor boleh
-- auto-commit tiap statement berasingan, jadi "ON COMMIT DROP" boleh buang
-- jadual ni SEBELUM statement INSERT seterusnya sempat baca. Jadual sementara
-- ni hilang sendiri bila sesi/connection tamat; DROP eksplisit di hujung utk
-- kemas serta-merta.
DROP TABLE IF EXISTS _import_clinical_equipment;
CREATE TEMP TABLE _import_clinical_equipment (
  name TEXT, notes TEXT, unit TEXT, category TEXT, consumption_type TEXT,
  min_qty NUMERIC, price NUMERIC, price_min NUMERIC, price_max NUMERIC, opening_qty NUMERIC
);

INSERT INTO _import_clinical_equipment VALUES
('Oxygen Concentrator', 'Device that concentrates oxygen from ambient air for supplemental oxygen delivery.', 'Pcs', 'Clinical Equipment', 'general', 1, NULL, 2000, 4500, 1),
('Humidifier Bottle', 'Bottle used with an oxygen concentrator to humidify the oxygen supply.', 'Botol', 'Clinical Equipment', 'general', 1, NULL, 15, 45, 1),
('Oxygen Nasal Cannula', 'Nasal cannula for low-flow supplemental oxygen delivery.', 'Pek', 'Clinical Equipment', 'package', 1, NULL, 3, 10, 1),
('Oxygen Tubing (Tiub)', 'Tubing connecting oxygen equipment to the patient delivery interface.', 'Pek', 'Clinical Equipment', 'package', 1, NULL, 5, 20, 1),
('Oxygen Mask', 'Mask for supplemental oxygen delivery.', 'Pek', 'Clinical Equipment', 'package', 1, NULL, 3, 15, 1),
('IV Infusion Stand', 'Stand for supporting IV fluid containers during infusion.', 'Pcs', 'Clinical Equipment', 'general', 1, 150, NULL, NULL, 3),
('Venous Tourniquet', 'Reusable tourniquet for venous access and blood collection.', 'Pcs', 'Clinical Equipment', 'general', 1, 10, NULL, NULL, 2),
('Digital Blood Pressure Monitor', 'Digital device for non-invasive blood pressure measurement.', 'Unit', 'Clinical Equipment', 'general', 1, 120, NULL, NULL, 2),
('Blood Pressure Cuff (BP Cuff)', 'Inflatable cuff used with a blood pressure monitor.', 'Pcs', 'Clinical Equipment', 'general', 1, 50, NULL, NULL, 2),
('Oximeter', 'Pulse oximeter for measuring oxygen saturation and pulse rate.', 'Unit', 'Clinical Equipment', 'general', 1, 60, NULL, NULL, 1),
('Thermometer', 'Digital thermometer for body temperature measurement.', 'Unit', 'Clinical Equipment', 'general', 1, 20, NULL, NULL, 1),
('Glucometer Machine', 'Blood glucose meter for capillary blood glucose testing.', 'Unit', 'Clinical Equipment', 'general', 1, NULL, 40, 150, 1),
('Electronic Body Weight Scale', 'Electronic scale for measuring body weight.', 'Unit', 'Clinical Equipment', 'general', 1, 70, NULL, NULL, 1),
('Plastic Kidney Tray', 'Kidney-shaped tray for holding clinical materials.', 'Unit', 'Clinical Equipment', 'general', 1, 10, NULL, NULL, 2),
('Wheelchair', 'Mobility chair for patients with mobility difficulties.', 'Unit', 'Clinical Equipment', 'general', 1, 350, NULL, NULL, 1),
('Nebuliser Machine / Compressor', 'Compressor unit for nebulised treatment.', 'Unit', 'Clinical Equipment', 'general', 1, NULL, 500, NULL, 1),
('Nebuliser Cup / Chamber', 'Medication chamber or cup used with a nebuliser.', 'Pek', 'Clinical Equipment', 'package', 1, 8, NULL, NULL, 1),
('Hydrogen Inhalation Machine', 'Clinical equipment for hydrogen inhalation treatment.', 'Unit', 'Clinical Equipment', 'general', 1, NULL, 1000, NULL, 1),
('Adjustable Hospital Bed', 'Adjustable hospital bed for patient care and positioning.', 'Unit', 'Clinical Equipment', 'general', 1, NULL, 1200, 3500, 1),
('Medical Air Mattress', 'Air mattress for patient care and support.', 'Unit', 'Clinical Equipment', 'general', 1, NULL, 250, 700, 1),
('Mattress', 'Mattress for patient care and treatment support.', 'Unit', 'Clinical Equipment', 'general', 1, NULL, 150, 600, 1),
('Nebuliser Mask', 'Mask interface for nebuliser treatment.', 'Pek', 'Clinical Equipment', 'package', 1, 10, NULL, NULL, 1),
('Nebuliser Tubing', 'Tubing connecting the nebuliser to the patient interface.', 'Pek', 'Clinical Equipment', 'package', 1, 8, NULL, NULL, 1),
('Hydrogen Nasal Cannula', 'Nasal cannula interface for hydrogen equipment.', 'Pek', 'Clinical Equipment', 'package', 1, 30, NULL, NULL, 1),
('Hydrogen Tubing', 'Tubing connecting hydrogen equipment to the patient interface.', 'Pek', 'Clinical Equipment', 'package', 1, 25, NULL, NULL, 1),
('C-Shape Overbed Table', 'C-shaped overbed table designed to fit around a patient''s bed.', 'Unit', 'Clinical Equipment', 'general', 1, 250, NULL, NULL, 1);

INSERT INTO psy_inventory_categories (name) VALUES ('Clinical Equipment') ON CONFLICT (name) DO NOTHING;
INSERT INTO psy_inventory_locations (name, is_default) VALUES ('Clinical Store', false) ON CONFLICT (name) DO NOTHING;

INSERT INTO psy_inventory_items (name, notes, unit, category, consumption_type, min_qty, source_type, status, is_active, requires_approval, supplier_info)
SELECT ip.name, ip.notes, ip.unit, ip.category, ip.consumption_type, ip.min_qty, 'am', 'active', true, true,
  jsonb_strip_nulls(jsonb_build_object('cost_per_unit', ip.price, 'cost_per_unit_min', ip.price_min, 'cost_per_unit_max', ip.price_max))
FROM _import_clinical_equipment ip
WHERE NOT EXISTS (SELECT 1 FROM psy_inventory_items existing WHERE existing.name = ip.name);

INSERT INTO psy_inventory_stock_by_location (item_id, location_id, qty_in_stock)
SELECT i.id, loc.id, ip.opening_qty
FROM _import_clinical_equipment ip
JOIN psy_inventory_items i ON i.name = ip.name
JOIN psy_inventory_locations loc ON loc.name = 'Clinical Store'
WHERE NOT EXISTS (SELECT 1 FROM psy_inventory_stock_by_location sbl WHERE sbl.item_id = i.id AND sbl.location_id = loc.id);

INSERT INTO psy_stock_movements (item_id, item_name, location_id, movement_type, qty, balance_after, reference_type, notes, actor_name)
SELECT i.id, i.name, loc.id, 'in', ip.opening_qty, ip.opening_qty, 'opening_stock', 'Import data awal — 26 produk Clinical Equipment (5 Nov 2026)', 'System Import'
FROM _import_clinical_equipment ip
JOIN psy_inventory_items i ON i.name = ip.name
JOIN psy_inventory_locations loc ON loc.name = 'Clinical Store'
WHERE NOT EXISTS (
  SELECT 1 FROM psy_stock_movements sm
  WHERE sm.item_id = i.id AND sm.reference_type = 'opening_stock'
    AND sm.notes = 'Import data awal — 26 produk Clinical Equipment (5 Nov 2026)'
);

DROP TABLE IF EXISTS _import_clinical_equipment;
