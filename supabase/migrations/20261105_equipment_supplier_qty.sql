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
-- 5 Nov 2026 (bahagian 5-10, DITULIS SEMULA) — Import 123 produk merentas 6
-- kategori (Clinical Equipment/Inventory, General/Raw Inventory, Coaching
-- Supplies, Equipment Event). DITULIS SEMULA drpd versi asal (yg guna
-- CREATE TEMP TABLE) sbb 2 kegagalan run berturut-turut:
--   1) Constraint 'Balang' tertinggal dikemaskini dlm migration SQL (dah
--      dibaiki, lihat ALTER CONSTRAINT di bawah — kini satu sahaja, cover
--      SEMUA unit baharu: Ampoule, Nebule, Balang).
--   2) "relation does not exist" bila cuma sebahagian fail (cth bahagian 8
--      sahaja) di-run berasingan — TEMP TABLE tak boleh dipercayai merentas
--      statement/sesi bergantung macam mana tool SQL awak hantar query
--      (sesetengah editor/tool hantar tiap statement sbg sambungan/transaksi
--      BERASINGAN, jadi CREATE TEMP TABLE di statement 1 tak nampak di
--      statement 2). Jadi SEMUA import di bawah ni ditulis semula TANPA
--      temp table langsung — tiap statement INSERT berdiri sendiri, senarai
--      data terus tersisip dlm FROM (VALUES ...) — selamat tak kira macam
--      mana tool hantar/pecah query ni, boleh run SELURUH fail ni sekali
--      gus ATAU SEBAHAGIAN (cth hanya 1 bahagian) tanpa risiko.
--
-- SEMUA statement idempoten (WHERE NOT EXISTS / ON CONFLICT DO NOTHING) —
-- selamat run berulang kali, row yg dah wujud (nama/stok/ledger) di-skip.
-- ═══════════════════════════════════════════════════════════════════
ALTER TABLE psy_inventory_items DROP CONSTRAINT IF EXISTS psy_inventory_items_unit_check;
ALTER TABLE psy_inventory_items DROP CONSTRAINT IF EXISTS psy_inventory_items_issue_unit_check;
ALTER TABLE psy_inventory_items ADD CONSTRAINT psy_inventory_items_unit_check
  CHECK (unit IN ('Pcs','Botol','Kotak','Pek','Set','Gulung','Beg','Karton','Pasang',
                   'Unit','Gram','Kg','Naskhah','Ampoule','Nebule','Balang',
                   'Liter (L)','Mililiter (ml)','Meter (m)','Sentimeter (cm)','Inci (inch)'));
ALTER TABLE psy_inventory_items ADD CONSTRAINT psy_inventory_items_issue_unit_check
  CHECK (issue_unit IS NULL OR issue_unit IN ('Pcs','Botol','Kotak','Pek','Set','Gulung','Beg','Karton','Pasang',
                   'Unit','Gram','Kg','Naskhah','Ampoule','Nebule','Balang',
                   'Liter (L)','Mililiter (ml)','Meter (m)','Sentimeter (cm)','Inci (inch)'));

-- ───────────────────────────────────────────────────────────────────
-- (bahagian 5) 26 produk "Clinical Equipment" (Oxygen Concentrator,
-- Wheelchair, BP Monitor dll). Lokasi "Clinical Store". Harga julat ->
-- Harga Anggaran Min/Maks, Price (RM) tunggal kosong. Harga "500+"/"1000+"
-- (open-ended) -> Min sahaja, Maks NULL. Gambar produk TIADA fail sebenar
-- diberi — image_url kekal NULL. requires_approval=true utk SEMUA 26.
-- ───────────────────────────────────────────────────────────────────

-- Clinical Equipment: insert 26 items (inline VALUES, no temp table)
INSERT INTO psy_inventory_items (name, notes, unit, category, consumption_type, min_qty, source_type, status, is_active, requires_approval, supplier_info)
SELECT v.name, v.notes, v.unit, v.category, v.consumption_type, 1, 'am', 'active', true, true,
  jsonb_strip_nulls(jsonb_build_object(
    'cost_per_unit', CASE WHEN v.price_min = v.price_max THEN v.price_min ELSE NULL END,
    'cost_per_unit_min', CASE WHEN v.price_min = v.price_max THEN NULL ELSE v.price_min END,
    'cost_per_unit_max', CASE WHEN v.price_min = v.price_max THEN NULL ELSE v.price_max END
  ))
FROM (VALUES
  ('Oxygen Concentrator', 'Device that concentrates oxygen from ambient air for supplemental oxygen delivery.', 'Pcs', 'Clinical Equipment', 'general', 2000::numeric, 4500::numeric, 1::numeric),
  ('Humidifier Bottle', 'Bottle used with an oxygen concentrator to humidify the oxygen supply.', 'Botol', 'Clinical Equipment', 'general', 15::numeric, 45::numeric, 1::numeric),
  ('Oxygen Nasal Cannula', 'Nasal cannula for low-flow supplemental oxygen delivery.', 'Pek', 'Clinical Equipment', 'package', 3::numeric, 10::numeric, 1::numeric),
  ('Oxygen Tubing (Tiub)', 'Tubing connecting oxygen equipment to the patient delivery interface.', 'Pek', 'Clinical Equipment', 'package', 5::numeric, 20::numeric, 1::numeric),
  ('Oxygen Mask', 'Mask for supplemental oxygen delivery.', 'Pek', 'Clinical Equipment', 'package', 3::numeric, 15::numeric, 1::numeric),
  ('IV Infusion Stand', 'Stand for supporting IV fluid containers during infusion.', 'Pcs', 'Clinical Equipment', 'general', 150::numeric, 150::numeric, 3::numeric),
  ('Venous Tourniquet', 'Reusable tourniquet for venous access and blood collection.', 'Pcs', 'Clinical Equipment', 'general', 10::numeric, 10::numeric, 2::numeric),
  ('Digital Blood Pressure Monitor', 'Digital device for non-invasive blood pressure measurement.', 'Unit', 'Clinical Equipment', 'general', 120::numeric, 120::numeric, 2::numeric),
  ('Blood Pressure Cuff (BP Cuff)', 'Inflatable cuff used with a blood pressure monitor.', 'Pcs', 'Clinical Equipment', 'general', 50::numeric, 50::numeric, 2::numeric),
  ('Oximeter', 'Pulse oximeter for measuring oxygen saturation and pulse rate.', 'Unit', 'Clinical Equipment', 'general', 60::numeric, 60::numeric, 1::numeric),
  ('Thermometer', 'Digital thermometer for body temperature measurement.', 'Unit', 'Clinical Equipment', 'general', 20::numeric, 20::numeric, 1::numeric),
  ('Glucometer Machine', 'Blood glucose meter for capillary blood glucose testing.', 'Unit', 'Clinical Equipment', 'general', 40::numeric, 150::numeric, 1::numeric),
  ('Electronic Body Weight Scale', 'Electronic scale for measuring body weight.', 'Unit', 'Clinical Equipment', 'general', 70::numeric, 70::numeric, 1::numeric),
  ('Plastic Kidney Tray', 'Kidney-shaped tray for holding clinical materials.', 'Unit', 'Clinical Equipment', 'general', 10::numeric, 10::numeric, 2::numeric),
  ('Wheelchair', 'Mobility chair for patients with mobility difficulties.', 'Unit', 'Clinical Equipment', 'general', 350::numeric, 350::numeric, 1::numeric),
  ('Nebuliser Machine / Compressor', 'Compressor unit for nebulised treatment.', 'Unit', 'Clinical Equipment', 'general', 500::numeric, NULL::numeric, 1::numeric),
  ('Nebuliser Cup / Chamber', 'Medication chamber or cup used with a nebuliser.', 'Pek', 'Clinical Equipment', 'package', 8::numeric, 8::numeric, 1::numeric),
  ('Hydrogen Inhalation Machine', 'Clinical equipment for hydrogen inhalation treatment.', 'Unit', 'Clinical Equipment', 'general', 1000::numeric, NULL::numeric, 1::numeric),
  ('Adjustable Hospital Bed', 'Adjustable hospital bed for patient care and positioning.', 'Unit', 'Clinical Equipment', 'general', 1200::numeric, 3500::numeric, 1::numeric),
  ('Medical Air Mattress', 'Air mattress for patient care and support.', 'Unit', 'Clinical Equipment', 'general', 250::numeric, 700::numeric, 1::numeric),
  ('Mattress', 'Mattress for patient care and treatment support.', 'Unit', 'Clinical Equipment', 'general', 150::numeric, 600::numeric, 1::numeric),
  ('Nebuliser Mask', 'Mask interface for nebuliser treatment.', 'Pek', 'Clinical Equipment', 'package', 10::numeric, 10::numeric, 1::numeric),
  ('Nebuliser Tubing', 'Tubing connecting the nebuliser to the patient interface.', 'Pek', 'Clinical Equipment', 'package', 8::numeric, 8::numeric, 1::numeric),
  ('Hydrogen Nasal Cannula', 'Nasal cannula interface for hydrogen equipment.', 'Pek', 'Clinical Equipment', 'package', 30::numeric, 30::numeric, 1::numeric),
  ('Hydrogen Tubing', 'Tubing connecting hydrogen equipment to the patient interface.', 'Pek', 'Clinical Equipment', 'package', 25::numeric, 25::numeric, 1::numeric),
  ('C-Shape Overbed Table', 'C-shaped overbed table designed to fit around a patient''s bed.', 'Unit', 'Clinical Equipment', 'general', 250::numeric, 250::numeric, 1::numeric)
) AS v(name, notes, unit, category, consumption_type, price_min, price_max, opening_qty)
WHERE NOT EXISTS (SELECT 1 FROM psy_inventory_items existing WHERE existing.name = v.name);

-- Clinical Equipment: opening stock by location
INSERT INTO psy_inventory_stock_by_location (item_id, location_id, qty_in_stock)
SELECT i.id, loc.id, v.opening_qty
FROM (VALUES
  ('Oxygen Concentrator', 1::numeric),
  ('Humidifier Bottle', 1::numeric),
  ('Oxygen Nasal Cannula', 1::numeric),
  ('Oxygen Tubing (Tiub)', 1::numeric),
  ('Oxygen Mask', 1::numeric),
  ('IV Infusion Stand', 3::numeric),
  ('Venous Tourniquet', 2::numeric),
  ('Digital Blood Pressure Monitor', 2::numeric),
  ('Blood Pressure Cuff (BP Cuff)', 2::numeric),
  ('Oximeter', 1::numeric),
  ('Thermometer', 1::numeric),
  ('Glucometer Machine', 1::numeric),
  ('Electronic Body Weight Scale', 1::numeric),
  ('Plastic Kidney Tray', 2::numeric),
  ('Wheelchair', 1::numeric),
  ('Nebuliser Machine / Compressor', 1::numeric),
  ('Nebuliser Cup / Chamber', 1::numeric),
  ('Hydrogen Inhalation Machine', 1::numeric),
  ('Adjustable Hospital Bed', 1::numeric),
  ('Medical Air Mattress', 1::numeric),
  ('Mattress', 1::numeric),
  ('Nebuliser Mask', 1::numeric),
  ('Nebuliser Tubing', 1::numeric),
  ('Hydrogen Nasal Cannula', 1::numeric),
  ('Hydrogen Tubing', 1::numeric),
  ('C-Shape Overbed Table', 1::numeric)
) AS v(name, opening_qty)
JOIN psy_inventory_items i ON i.name = v.name
JOIN psy_inventory_locations loc ON loc.name = 'Clinical Store'
WHERE NOT EXISTS (SELECT 1 FROM psy_inventory_stock_by_location sbl WHERE sbl.item_id = i.id AND sbl.location_id = loc.id);

-- Clinical Equipment: opening stock ledger entry
INSERT INTO psy_stock_movements (item_id, item_name, location_id, movement_type, qty, balance_after, reference_type, notes, actor_name)
SELECT i.id, i.name, loc.id, 'in', v.opening_qty, v.opening_qty, 'opening_stock', 'Import data awal — 26 produk Clinical Equipment (5 Nov 2026)', 'System Import'
FROM (VALUES
  ('Oxygen Concentrator', 1::numeric),
  ('Humidifier Bottle', 1::numeric),
  ('Oxygen Nasal Cannula', 1::numeric),
  ('Oxygen Tubing (Tiub)', 1::numeric),
  ('Oxygen Mask', 1::numeric),
  ('IV Infusion Stand', 3::numeric),
  ('Venous Tourniquet', 2::numeric),
  ('Digital Blood Pressure Monitor', 2::numeric),
  ('Blood Pressure Cuff (BP Cuff)', 2::numeric),
  ('Oximeter', 1::numeric),
  ('Thermometer', 1::numeric),
  ('Glucometer Machine', 1::numeric),
  ('Electronic Body Weight Scale', 1::numeric),
  ('Plastic Kidney Tray', 2::numeric),
  ('Wheelchair', 1::numeric),
  ('Nebuliser Machine / Compressor', 1::numeric),
  ('Nebuliser Cup / Chamber', 1::numeric),
  ('Hydrogen Inhalation Machine', 1::numeric),
  ('Adjustable Hospital Bed', 1::numeric),
  ('Medical Air Mattress', 1::numeric),
  ('Mattress', 1::numeric),
  ('Nebuliser Mask', 1::numeric),
  ('Nebuliser Tubing', 1::numeric),
  ('Hydrogen Nasal Cannula', 1::numeric),
  ('Hydrogen Tubing', 1::numeric),
  ('C-Shape Overbed Table', 1::numeric)
) AS v(name, opening_qty)
JOIN psy_inventory_items i ON i.name = v.name
JOIN psy_inventory_locations loc ON loc.name = 'Clinical Store'
WHERE NOT EXISTS (
  SELECT 1 FROM psy_stock_movements sm
  WHERE sm.item_id = i.id AND sm.reference_type = 'opening_stock' AND sm.notes = 'Import data awal — 26 produk Clinical Equipment (5 Nov 2026)'
);

-- ───────────────────────────────────────────────────────────────────
-- (bahagian 6) 16 produk "Clinical Inventory" (tape, saline, sarung
-- tangan, cannula dll). Lokasi "Clinical Store". Harga min=max (cth Normal
-- Saline RM3.50) dikesan sbg harga TETAP -> cost_per_unit, bukan julat.
-- Unit baharu "Ampoule"/"Nebule" (Vitamin C IV / Ventolin Nebules).
-- "Surgical Tape (1 inch)" kemungkinan besar dah wujud (item tes awal
-- hari ni) — WHERE NOT EXISTS skip row tu, TAK duplicate. Supplier
-- (Caring Pharmacy/Pharmacy-Shopee/Shopee) auto-cipta kalau belum wujud.
-- ───────────────────────────────────────────────────────────────────

-- Clinical Inventory: ensure suppliers exist
INSERT INTO psy_suppliers (name, status)
SELECT DISTINCT v.supplier_name, 'active'
FROM (VALUES
  ('Caring Pharmacy'),
  ('Pharmacy/Shopee'),
  ('Shopee')
) AS v(supplier_name)
WHERE NOT EXISTS (SELECT 1 FROM psy_suppliers existing WHERE existing.name = v.supplier_name);

-- Clinical Inventory: insert 16 items (inline VALUES, no temp table)
INSERT INTO psy_inventory_items (name, notes, internal_notes, unit, category, consumption_type, min_qty, source_type, status, is_active, requires_approval, supplier_id, supplier_info)
SELECT v.name, v.notes, v.internal_notes, v.unit, v.category, v.consumption_type, 1, 'am', 'active', true, true, sup.id,
  jsonb_strip_nulls(jsonb_build_object(
    'name', sup.name,
    'cost_per_unit', CASE WHEN v.price_min = v.price_max THEN v.price_min ELSE NULL END,
    'cost_per_unit_min', CASE WHEN v.price_min = v.price_max THEN NULL ELSE v.price_min END,
    'cost_per_unit_max', CASE WHEN v.price_min = v.price_max THEN NULL ELSE v.price_max END
  ))
FROM (VALUES
  ('Surgical Tape (1 inch)', 'Medical adhesive tape, 1 inch wide, with 3 metres per roll.', '3M = 30 patients', 'Gulung', 'Clinical Inventory', 'package', 3::numeric, 8::numeric, 3::numeric, 'Caring Pharmacy'),
  ('Alcohol (Surface Disinfectant) (250 mL)', 'Surface disinfectant for sanitising clinical surfaces.', '250 mL', 'Botol', 'Clinical Inventory', 'package', 10::numeric, 15::numeric, 250::numeric, 'Caring Pharmacy'),
  ('Normal Saline (0.9% Sodium Chloride)', '0.9% sodium chloride solution.', NULL, 'Botol', 'Clinical Inventory', 'package', 3.5::numeric, 3.5::numeric, 26::numeric, 'Caring Pharmacy'),
  ('Vitamin C IV Infusion', 'Intravenous ascorbic acid, 500 mg/2 mL.', '5 ampoules', 'Ampoule', 'Clinical Inventory', 'package', 1.3::numeric, 2.0::numeric, 5::numeric, 'Pharmacy/Shopee'),
  ('Ventolin Nebules (Salbutamol)', 'Sterile solution of salbutamol supplied in nebules.', '5 nebules', 'Nebule', 'Clinical Inventory', 'package', 2::numeric, 8::numeric, 5::numeric, 'Pharmacy/Shopee'),
  ('Alcohol Swab', 'Isopropyl Alcohol 70%, 50 gsm, for skin cleaning before procedures.', NULL, 'Kotak', 'Clinical Inventory', 'package', 5::numeric, 10::numeric, 20::numeric, 'Caring Pharmacy'),
  ('Infusion Set (Length: 134 cm)', 'Infusion set with a tubing length of 134 cm.', NULL, 'Pcs', 'Clinical Inventory', 'package', 3::numeric, 6::numeric, 20::numeric, 'Caring Pharmacy'),
  ('Cotton Ball (50 pieces - 1 pack)', 'Sterile or clean cotton balls for routine cleaning.', '100+', 'Pek', 'Clinical Inventory', 'package', 3::numeric, 6::numeric, 100::numeric, 'Caring Pharmacy'),
  ('Examination Glove (Medium)', 'Examination gloves, medium size, 100 pieces per box.', '100 pieces per box', 'Kotak', 'Clinical Inventory', 'package', 18::numeric, 25::numeric, 15::numeric, 'Caring Pharmacy'),
  ('Surgical Face Mask (50 pieces - 1 pack)', 'Three-ply surgical face masks, 50 pieces per pack.', '50 pieces per pack', 'Pek', 'Clinical Inventory', 'package', 10::numeric, 22::numeric, 10::numeric, 'Caring Pharmacy'),
  ('Tegaderm Transparent IV Frame Dressing', 'Transparent adhesive dressing for protecting IV access sites, 6 cm x 7 cm.', NULL, 'Pcs', 'Clinical Inventory', 'package', 1.3::numeric, 1.3::numeric, 10::numeric, 'Shopee'),
  ('IV Cannula (22G)', 'IV cannula, 22G, 0.9 x 25 mm, flow rate 36 mL/min.', '100+', 'Pcs', 'Clinical Inventory', 'package', 2::numeric, 5::numeric, 100::numeric, 'Shopee'),
  ('IV Cannula (Kids) (24G)', 'Paediatric IV cannula, 24G, 0.8 x 19 mm, flow rate 25 mL/min.', NULL, 'Pcs', 'Clinical Inventory', 'package', 2::numeric, 10::numeric, 10::numeric, 'Shopee'),
  ('Sharp Bin (10 L)', '10-litre sharps container for safe disposal of needles and other sharps.', '10L = 80 patients', 'Unit', 'Clinical Inventory', 'package', 30::numeric, 30::numeric, 10::numeric, 'Shopee'),
  ('Yellow Biohazard Bag', 'Yellow clinical waste bag for safe clinical waste disposal.', '10L', 'Pcs', 'Clinical Inventory', 'package', 0.55::numeric, 0.55::numeric, 10::numeric, 'Shopee'),
  ('Lancets & Test Strips Blood Glucose', 'Blood glucose testing consumables, including lancets and compatible test strips.', NULL, 'Pek', 'Clinical Inventory', 'package', 25::numeric, 80::numeric, 10::numeric, 'Shopee')
) AS v(name, notes, internal_notes, unit, category, consumption_type, price_min, price_max, opening_qty, supplier_name)
JOIN psy_suppliers sup ON sup.name = v.supplier_name
WHERE NOT EXISTS (SELECT 1 FROM psy_inventory_items existing WHERE existing.name = v.name);

-- Clinical Inventory: opening stock by location
INSERT INTO psy_inventory_stock_by_location (item_id, location_id, qty_in_stock)
SELECT i.id, loc.id, v.opening_qty
FROM (VALUES
  ('Surgical Tape (1 inch)', 3::numeric),
  ('Alcohol (Surface Disinfectant) (250 mL)', 250::numeric),
  ('Normal Saline (0.9% Sodium Chloride)', 26::numeric),
  ('Vitamin C IV Infusion', 5::numeric),
  ('Ventolin Nebules (Salbutamol)', 5::numeric),
  ('Alcohol Swab', 20::numeric),
  ('Infusion Set (Length: 134 cm)', 20::numeric),
  ('Cotton Ball (50 pieces - 1 pack)', 100::numeric),
  ('Examination Glove (Medium)', 15::numeric),
  ('Surgical Face Mask (50 pieces - 1 pack)', 10::numeric),
  ('Tegaderm Transparent IV Frame Dressing', 10::numeric),
  ('IV Cannula (22G)', 100::numeric),
  ('IV Cannula (Kids) (24G)', 10::numeric),
  ('Sharp Bin (10 L)', 10::numeric),
  ('Yellow Biohazard Bag', 10::numeric),
  ('Lancets & Test Strips Blood Glucose', 10::numeric)
) AS v(name, opening_qty)
JOIN psy_inventory_items i ON i.name = v.name
JOIN psy_inventory_locations loc ON loc.name = 'Clinical Store'
WHERE NOT EXISTS (SELECT 1 FROM psy_inventory_stock_by_location sbl WHERE sbl.item_id = i.id AND sbl.location_id = loc.id);

-- Clinical Inventory: opening stock ledger entry
INSERT INTO psy_stock_movements (item_id, item_name, location_id, movement_type, qty, balance_after, reference_type, notes, actor_name)
SELECT i.id, i.name, loc.id, 'in', v.opening_qty, v.opening_qty, 'opening_stock', 'Import data awal — 16 produk Clinical Inventory (5 Nov 2026)', 'System Import'
FROM (VALUES
  ('Surgical Tape (1 inch)', 3::numeric),
  ('Alcohol (Surface Disinfectant) (250 mL)', 250::numeric),
  ('Normal Saline (0.9% Sodium Chloride)', 26::numeric),
  ('Vitamin C IV Infusion', 5::numeric),
  ('Ventolin Nebules (Salbutamol)', 5::numeric),
  ('Alcohol Swab', 20::numeric),
  ('Infusion Set (Length: 134 cm)', 20::numeric),
  ('Cotton Ball (50 pieces - 1 pack)', 100::numeric),
  ('Examination Glove (Medium)', 15::numeric),
  ('Surgical Face Mask (50 pieces - 1 pack)', 10::numeric),
  ('Tegaderm Transparent IV Frame Dressing', 10::numeric),
  ('IV Cannula (22G)', 100::numeric),
  ('IV Cannula (Kids) (24G)', 10::numeric),
  ('Sharp Bin (10 L)', 10::numeric),
  ('Yellow Biohazard Bag', 10::numeric),
  ('Lancets & Test Strips Blood Glucose', 10::numeric)
) AS v(name, opening_qty)
JOIN psy_inventory_items i ON i.name = v.name
JOIN psy_inventory_locations loc ON loc.name = 'Clinical Store'
WHERE NOT EXISTS (
  SELECT 1 FROM psy_stock_movements sm
  WHERE sm.item_id = i.id AND sm.reference_type = 'opening_stock' AND sm.notes = 'Import data awal — 16 produk Clinical Inventory (5 Nov 2026)'
);

-- ───────────────────────────────────────────────────────────────────
-- (bahagian 7) 12 produk "General Inventory" (plastik sampah, sabun
-- tandas, air mineral, bubble wrap, bateri dll). Lokasi BAHARU "General
-- Store" (beza drpd lokasi "General Inventory" seed asal). UOM asal byk
-- letak saiz/dimensi fizikal (bukan unit sah) -> dianggar unit sebenar,
-- saiz disimpan internal_notes. "Toilet Soap (2 Liter)": Opening Stock
-- asal data literal '2 L' (tersalin drpd UOM) dianggap 2 unit — SILA
-- SEMAK. Tiada supplier diberi dlm templat ni.
-- ───────────────────────────────────────────────────────────────────

-- General Inventory: insert 12 items (inline VALUES, no temp table)
INSERT INTO psy_inventory_items (name, notes, internal_notes, unit, category, consumption_type, min_qty, source_type, status, is_active, requires_approval, supplier_info)
SELECT v.name, v.notes, v.internal_notes, v.unit, v.category, v.consumption_type, 1, 'am', 'active', true, true,
  jsonb_strip_nulls(jsonb_build_object(
    'cost_per_unit', CASE WHEN v.price_min = v.price_max THEN v.price_min ELSE NULL END,
    'cost_per_unit_min', CASE WHEN v.price_min = v.price_max THEN NULL ELSE v.price_min END,
    'cost_per_unit_max', CASE WHEN v.price_min = v.price_max THEN NULL ELSE v.price_max END
  ))
FROM (VALUES
  ('Garbage Plastic (Toilet) – Small (S)', 'General consumable for routine toilet waste disposal.', 'Saiz 18" x 22"', 'Pek', 'General Inventory', 'general', 3::numeric, 5::numeric, 10::numeric),
  ('T-Shirt Plastic – Small (S)', 'Small plastic bags for general packing and daily use.', 'Saiz 18" x 22"', 'Pek', 'General Inventory', 'general', 3::numeric, 6::numeric, 10::numeric),
  ('Toilet Soap (2 Liter)', 'Liquid soap for routine toilet and hand washing use.', 'Botol 2 Liter. NOTA: opening stock asal data ''2 L'' — dianggap 2 unit, sila semak.', 'Botol', 'General Inventory', 'general', 12::numeric, 18::numeric, 2::numeric),
  ('Toilet Tissue Roll (1 Packet)', 'Toilet tissue rolls for restroom use.', 'Diameter/saiz roll: 10cm', 'Pek', 'General Inventory', 'general', 10::numeric, 15::numeric, 10::numeric),
  ('Mineral Water (250 mL)', 'Bottled mineral water for general consumption.', '250 mL setiap botol', 'Botol', 'General Inventory', 'general', 2::numeric, 3::numeric, 24::numeric),
  ('Mineral Water (1.5 L)', 'Bottled mineral water, 1.5-litre size.', '1.5 Liter setiap botol', 'Botol', 'General Inventory', 'general', 2::numeric, 3::numeric, 10::numeric),
  ('Pocket Tissue', 'Pocket-sized tissue for daily use.', 'Saiz 10 x 5 x 2 cm', 'Pek', 'General Inventory', 'general', 2::numeric, 5::numeric, 10::numeric),
  ('Honey Tablespoon (Plastic)', 'Plastic tablespoon for handling or serving honey.', NULL, 'Pcs', 'General Inventory', 'general', 1::numeric, 3::numeric, 10::numeric),
  ('Bubble Wrap (1 M)', 'Protective bubble wrap for packing and protecting items.', NULL, 'Meter (m)', 'General Inventory', 'general', 65::numeric, 65::numeric, 10::numeric),
  ('Beg Hijau (1 Box – 300 pcs)', 'Green bags, 300 pieces per box.', '300 keping setiap kotak', 'Kotak', 'General Inventory', 'general', 5::numeric, 25::numeric, 50::numeric),
  ('Battery AAA (Energizer / Eveready)', 'AAA batteries, 16 pieces per pack.', '16 keping setiap pek. Saiz bateri: 1.05cm x 4.45cm', 'Pek', 'General Inventory', 'general', 20::numeric, 30::numeric, 10::numeric),
  ('Cell Battery (Panasonic)', 'Panasonic cell battery, 20 mm diameter and 3.2 mm thickness.', '20mm diameter, 3.2mm ketebalan', 'Pcs', 'General Inventory', 'general', 4::numeric, 8::numeric, 5::numeric)
) AS v(name, notes, internal_notes, unit, category, consumption_type, price_min, price_max, opening_qty)
WHERE NOT EXISTS (SELECT 1 FROM psy_inventory_items existing WHERE existing.name = v.name);

-- General Inventory: opening stock by location
INSERT INTO psy_inventory_stock_by_location (item_id, location_id, qty_in_stock)
SELECT i.id, loc.id, v.opening_qty
FROM (VALUES
  ('Garbage Plastic (Toilet) – Small (S)', 10::numeric),
  ('T-Shirt Plastic – Small (S)', 10::numeric),
  ('Toilet Soap (2 Liter)', 2::numeric),
  ('Toilet Tissue Roll (1 Packet)', 10::numeric),
  ('Mineral Water (250 mL)', 24::numeric),
  ('Mineral Water (1.5 L)', 10::numeric),
  ('Pocket Tissue', 10::numeric),
  ('Honey Tablespoon (Plastic)', 10::numeric),
  ('Bubble Wrap (1 M)', 10::numeric),
  ('Beg Hijau (1 Box – 300 pcs)', 50::numeric),
  ('Battery AAA (Energizer / Eveready)', 10::numeric),
  ('Cell Battery (Panasonic)', 5::numeric)
) AS v(name, opening_qty)
JOIN psy_inventory_items i ON i.name = v.name
JOIN psy_inventory_locations loc ON loc.name = 'General Store'
WHERE NOT EXISTS (SELECT 1 FROM psy_inventory_stock_by_location sbl WHERE sbl.item_id = i.id AND sbl.location_id = loc.id);

-- General Inventory: opening stock ledger entry
INSERT INTO psy_stock_movements (item_id, item_name, location_id, movement_type, qty, balance_after, reference_type, notes, actor_name)
SELECT i.id, i.name, loc.id, 'in', v.opening_qty, v.opening_qty, 'opening_stock', 'Import data awal — 12 produk General Inventory (5 Nov 2026)', 'System Import'
FROM (VALUES
  ('Garbage Plastic (Toilet) – Small (S)', 10::numeric),
  ('T-Shirt Plastic – Small (S)', 10::numeric),
  ('Toilet Soap (2 Liter)', 2::numeric),
  ('Toilet Tissue Roll (1 Packet)', 10::numeric),
  ('Mineral Water (250 mL)', 24::numeric),
  ('Mineral Water (1.5 L)', 10::numeric),
  ('Pocket Tissue', 10::numeric),
  ('Honey Tablespoon (Plastic)', 10::numeric),
  ('Bubble Wrap (1 M)', 10::numeric),
  ('Beg Hijau (1 Box – 300 pcs)', 50::numeric),
  ('Battery AAA (Energizer / Eveready)', 10::numeric),
  ('Cell Battery (Panasonic)', 5::numeric)
) AS v(name, opening_qty)
JOIN psy_inventory_items i ON i.name = v.name
JOIN psy_inventory_locations loc ON loc.name = 'General Store'
WHERE NOT EXISTS (
  SELECT 1 FROM psy_stock_movements sm
  WHERE sm.item_id = i.id AND sm.reference_type = 'opening_stock' AND sm.notes = 'Import data awal — 12 produk General Inventory (5 Nov 2026)'
);

-- ───────────────────────────────────────────────────────────────────
-- (bahagian 8) 8 produk "Raw Inventory" (botol/balang kosong + bahan
-- mentah cecair pembuatan). Storage Location "Raw Inventory" (templat
-- asal) dipadankan ke lokasi SEDIA ADA "Raw Material Store" (maksud sama,
-- elak 2 lokasi raw material hampir sama nama). Unit baharu "Balang"
-- (Jar) utk 4 produk Glass Jar. Olive Oil & Colon Herbs ditukar unit ke
-- Liter (L) sbb bahan mentah cecair sebenar (bukan bekas) — "Colon Herbs"
-- (deskripsi dualistik raw material/packaging) dianggap bahan mentah
-- cecair, SILA SAHKAN. "Raw Herbs" RM1,100 ditafsir harga tetap (koma =
-- pemisah ribu).
-- ───────────────────────────────────────────────────────────────────

-- Raw Inventory: insert 8 items (inline VALUES, no temp table)
INSERT INTO psy_inventory_items (name, notes, internal_notes, unit, category, consumption_type, min_qty, source_type, status, is_active, requires_approval, supplier_info)
SELECT v.name, v.notes, v.internal_notes, v.unit, v.category, v.consumption_type, 1, 'am', 'active', true, true,
  jsonb_strip_nulls(jsonb_build_object(
    'cost_per_unit', CASE WHEN v.price_min = v.price_max THEN v.price_min ELSE NULL END,
    'cost_per_unit_min', CASE WHEN v.price_min = v.price_max THEN NULL ELSE v.price_min END,
    'cost_per_unit_max', CASE WHEN v.price_min = v.price_max THEN NULL ELSE v.price_max END
  ))
FROM (VALUES
  ('Plastic Bottle (Herba Kolon)', 'Plastic bottle for Herba Kolon.', 'Kapasiti 1.5 Liter', 'Botol', 'Raw Inventory', 'general', 50::numeric, 150::numeric, 5::numeric),
  ('Glass Jar 250 mL (Olive Oil)', 'Glass jar with 250 mL capacity for Olive Oil.', 'Kapasiti 250 mL', 'Balang', 'Raw Inventory', 'general', 5::numeric, 25::numeric, 5::numeric),
  ('Glass Jar 500 g', 'Glass jar with 500 g capacity.', 'Kapasiti 500 g', 'Balang', 'Raw Inventory', 'general', 5::numeric, 25::numeric, 10::numeric),
  ('Glass Jar 1 kg', 'Glass jar with 1 kg capacity.', 'Kapasiti 1 kg', 'Balang', 'Raw Inventory', 'general', 5::numeric, 25::numeric, 10::numeric),
  ('Glass Jar 2 kg', 'Glass jar with 2 kg capacity.', 'Kapasiti 2 kg', 'Balang', 'Raw Inventory', 'general', 5::numeric, 25::numeric, 10::numeric),
  ('Olive Oil', 'Olive oil used as a raw material.', 'Dibeli dlm bekas 2 Liter', 'Liter (L)', 'Raw Inventory', 'general', 35::numeric, 120::numeric, 1::numeric),
  ('Raw Herbs', 'Raw herbs used as production materials.', NULL, 'Pek', 'Raw Inventory', 'general', 1100::numeric, 1100::numeric, 10::numeric),
  ('Colon Herbs', 'Raw material or packaging item for Colon Herbs.', 'Anggap bahan mentah cecair (bukan bekas kosong) — kapasiti rujukan 1.5L, SILA SAHKAN.', 'Liter (L)', 'Raw Inventory', 'general', 110::numeric, 110::numeric, 5::numeric)
) AS v(name, notes, internal_notes, unit, category, consumption_type, price_min, price_max, opening_qty)
WHERE NOT EXISTS (SELECT 1 FROM psy_inventory_items existing WHERE existing.name = v.name);

-- Raw Inventory: opening stock by location
INSERT INTO psy_inventory_stock_by_location (item_id, location_id, qty_in_stock)
SELECT i.id, loc.id, v.opening_qty
FROM (VALUES
  ('Plastic Bottle (Herba Kolon)', 5::numeric),
  ('Glass Jar 250 mL (Olive Oil)', 5::numeric),
  ('Glass Jar 500 g', 10::numeric),
  ('Glass Jar 1 kg', 10::numeric),
  ('Glass Jar 2 kg', 10::numeric),
  ('Olive Oil', 1::numeric),
  ('Raw Herbs', 10::numeric),
  ('Colon Herbs', 5::numeric)
) AS v(name, opening_qty)
JOIN psy_inventory_items i ON i.name = v.name
JOIN psy_inventory_locations loc ON loc.name = 'Raw Material Store'
WHERE NOT EXISTS (SELECT 1 FROM psy_inventory_stock_by_location sbl WHERE sbl.item_id = i.id AND sbl.location_id = loc.id);

-- Raw Inventory: opening stock ledger entry
INSERT INTO psy_stock_movements (item_id, item_name, location_id, movement_type, qty, balance_after, reference_type, notes, actor_name)
SELECT i.id, i.name, loc.id, 'in', v.opening_qty, v.opening_qty, 'opening_stock', 'Import data awal — 8 produk Raw Inventory (5 Nov 2026)', 'System Import'
FROM (VALUES
  ('Plastic Bottle (Herba Kolon)', 5::numeric),
  ('Glass Jar 250 mL (Olive Oil)', 5::numeric),
  ('Glass Jar 500 g', 10::numeric),
  ('Glass Jar 1 kg', 10::numeric),
  ('Glass Jar 2 kg', 10::numeric),
  ('Olive Oil', 1::numeric),
  ('Raw Herbs', 10::numeric),
  ('Colon Herbs', 5::numeric)
) AS v(name, opening_qty)
JOIN psy_inventory_items i ON i.name = v.name
JOIN psy_inventory_locations loc ON loc.name = 'Raw Material Store'
WHERE NOT EXISTS (
  SELECT 1 FROM psy_stock_movements sm
  WHERE sm.item_id = i.id AND sm.reference_type = 'opening_stock' AND sm.notes = 'Import data awal — 8 produk Raw Inventory (5 Nov 2026)'
);

-- ───────────────────────────────────────────────────────────────────
-- (bahagian 9) 17 "produk" Coaching Supplies (poster/bahan cetak panduan
-- dos madu + panduan coaching). NOTA KRITIKAL: nama produk templat asal
-- DUPLICATE SAMA PERSIS merentas byk baris (cth 4 baris "Poster Saranan
-- Peminuman Madu Lote Tree Honey..." cuma beza di Description "Table
-- spoon Nx") — nama DITAMBAH sufiks dos (10x)/(8x)/(4x)/(2x)/(1x) supaya
-- unik, elak hilang data senyap via WHERE NOT EXISTS. Unit semua ->
-- Naskhah. Storage Location "Other Location" (templat asal, tak wujud
-- dlm sistem) dipadankan ke lokasi sedia ada "Printing". Hanya 1 baris
-- ada harga sebenar; 16 lain "Not specified" dibiarkan kosong. Baris
-- "Poster Panduan Pengamalan Zikir Bersanad" mungkin bertindih dgn item
-- lama "Panduan Pengamalan Zikir Bersanad" — nama beza jadi tak auto-
-- dikesan, sila semak manual.
-- ───────────────────────────────────────────────────────────────────

-- Coaching Supplies: insert 17 items (inline VALUES, no temp table)
INSERT INTO psy_inventory_items (name, notes, unit, category, consumption_type, min_qty, source_type, status, is_active, requires_approval, supplier_info)
SELECT v.name, v.notes, v.unit, v.category, v.consumption_type, 1, 'am', 'active', true, true,
  jsonb_strip_nulls(jsonb_build_object(
    'cost_per_unit', CASE WHEN v.price_min = v.price_max THEN v.price_min ELSE NULL END,
    'cost_per_unit_min', CASE WHEN v.price_min = v.price_max THEN NULL ELSE v.price_min END,
    'cost_per_unit_max', CASE WHEN v.price_min = v.price_max THEN NULL ELSE v.price_max END
  ))
FROM (VALUES
  ('Poster Saranan Peminuman Madu Lote Tree Honey & Lote Tree Honey Pearl Garlic (10x)', 'Table spoon 10x', 'Naskhah', 'Coaching Supplies', 'package', NULL::numeric, NULL::numeric, 10::numeric),
  ('Poster Saranan Peminuman Madu Lote Tree Honey & Lote Tree Honey Pearl Garlic (8x)', 'Table spoon 8x', 'Naskhah', 'Coaching Supplies', 'package', NULL::numeric, NULL::numeric, 10::numeric),
  ('Poster Saranan Peminuman Madu Lote Tree Honey & Lote Tree Honey Pearl Garlic (4x)', 'Table spoon 4x', 'Naskhah', 'Coaching Supplies', 'package', 1::numeric, 15::numeric, 10::numeric),
  ('Poster Saranan Peminuman Madu Lote Tree Honey & Lote Tree Honey Pearl Garlic (2x)', 'Table spoon 2x', 'Naskhah', 'Coaching Supplies', 'package', NULL::numeric, NULL::numeric, 10::numeric),
  ('Poster Saranan Peminuman Madu Immune Booster & Young & Healthy Pearl Garlic (2 kg) (10x)', 'Table spoon 10x', 'Naskhah', 'Coaching Supplies', 'package', NULL::numeric, NULL::numeric, 10::numeric),
  ('Poster Saranan Peminuman Madu Immune Booster & Young & Healthy Pearl Garlic (2 kg) (8x)', 'Table spoon 8x', 'Naskhah', 'Coaching Supplies', 'package', NULL::numeric, NULL::numeric, 10::numeric),
  ('Poster Saranan Peminuman Madu Immune Booster & Young & Healthy Pearl Garlic (2 kg) (4x)', 'Table spoon 4x', 'Naskhah', 'Coaching Supplies', 'package', NULL::numeric, NULL::numeric, 10::numeric),
  ('Poster Saranan Peminuman Madu Immune Booster (500g) (2x)', 'Table spoon 2x', 'Naskhah', 'Coaching Supplies', 'package', NULL::numeric, NULL::numeric, 10::numeric),
  ('Poster Saranan Peminuman Young & Healthy Honey (500g) (2x)', 'Tablespoon 2x', 'Naskhah', 'Coaching Supplies', 'package', NULL::numeric, NULL::numeric, 10::numeric),
  ('Poster Saranan Peminuman Breath & Digest Honey (500g) (2x)', 'Tablespoon 2x', 'Naskhah', 'Coaching Supplies', 'package', NULL::numeric, NULL::numeric, 10::numeric),
  ('Poster Saranan Peminuman Brainy Kidz Honey (500g) (2x)', 'Tablespoon 2x', 'Naskhah', 'Coaching Supplies', 'package', NULL::numeric, NULL::numeric, 10::numeric),
  ('Poster Saranan Peminuman Madu Immune Booster (500g) (1x)', 'Table spoon 1x', 'Naskhah', 'Coaching Supplies', 'package', NULL::numeric, NULL::numeric, 10::numeric),
  ('Poster Saranan Peminuman Young & Healthy Honey (500g) (1x)', 'Tablespoon 1x', 'Naskhah', 'Coaching Supplies', 'package', NULL::numeric, NULL::numeric, 10::numeric),
  ('Poster Saranan Peminuman Breath & Digest Honey (500g) (1x)', 'Tablespoon 1x', 'Naskhah', 'Coaching Supplies', 'package', NULL::numeric, NULL::numeric, 10::numeric),
  ('Poster Saranan Peminuman Brainy Kidz Honey (500g) (1x)', 'Tablespoon 1x', 'Naskhah', 'Coaching Supplies', 'package', NULL::numeric, NULL::numeric, 10::numeric),
  ('Poster Panduan Pengamalan Zikir Bersanad (A4 Thick Paper)', 'Coaching and patient-education material for wellness guidance.', 'Naskhah', 'Coaching Supplies', 'package', NULL::numeric, NULL::numeric, 10::numeric),
  ('Senarai Nikmat Selera Sel dan Bahaya Nafsu Perut (A4 Paper)', 'Coaching and patient-education material for wellness guidance.', 'Naskhah', 'Coaching Supplies', 'package', NULL::numeric, NULL::numeric, 10::numeric)
) AS v(name, notes, unit, category, consumption_type, price_min, price_max, opening_qty)
WHERE NOT EXISTS (SELECT 1 FROM psy_inventory_items existing WHERE existing.name = v.name);

-- Coaching Supplies: opening stock by location
INSERT INTO psy_inventory_stock_by_location (item_id, location_id, qty_in_stock)
SELECT i.id, loc.id, v.opening_qty
FROM (VALUES
  ('Poster Saranan Peminuman Madu Lote Tree Honey & Lote Tree Honey Pearl Garlic (10x)', 10::numeric),
  ('Poster Saranan Peminuman Madu Lote Tree Honey & Lote Tree Honey Pearl Garlic (8x)', 10::numeric),
  ('Poster Saranan Peminuman Madu Lote Tree Honey & Lote Tree Honey Pearl Garlic (4x)', 10::numeric),
  ('Poster Saranan Peminuman Madu Lote Tree Honey & Lote Tree Honey Pearl Garlic (2x)', 10::numeric),
  ('Poster Saranan Peminuman Madu Immune Booster & Young & Healthy Pearl Garlic (2 kg) (10x)', 10::numeric),
  ('Poster Saranan Peminuman Madu Immune Booster & Young & Healthy Pearl Garlic (2 kg) (8x)', 10::numeric),
  ('Poster Saranan Peminuman Madu Immune Booster & Young & Healthy Pearl Garlic (2 kg) (4x)', 10::numeric),
  ('Poster Saranan Peminuman Madu Immune Booster (500g) (2x)', 10::numeric),
  ('Poster Saranan Peminuman Young & Healthy Honey (500g) (2x)', 10::numeric),
  ('Poster Saranan Peminuman Breath & Digest Honey (500g) (2x)', 10::numeric),
  ('Poster Saranan Peminuman Brainy Kidz Honey (500g) (2x)', 10::numeric),
  ('Poster Saranan Peminuman Madu Immune Booster (500g) (1x)', 10::numeric),
  ('Poster Saranan Peminuman Young & Healthy Honey (500g) (1x)', 10::numeric),
  ('Poster Saranan Peminuman Breath & Digest Honey (500g) (1x)', 10::numeric),
  ('Poster Saranan Peminuman Brainy Kidz Honey (500g) (1x)', 10::numeric),
  ('Poster Panduan Pengamalan Zikir Bersanad (A4 Thick Paper)', 10::numeric),
  ('Senarai Nikmat Selera Sel dan Bahaya Nafsu Perut (A4 Paper)', 10::numeric)
) AS v(name, opening_qty)
JOIN psy_inventory_items i ON i.name = v.name
JOIN psy_inventory_locations loc ON loc.name = 'Printing'
WHERE NOT EXISTS (SELECT 1 FROM psy_inventory_stock_by_location sbl WHERE sbl.item_id = i.id AND sbl.location_id = loc.id);

-- Coaching Supplies: opening stock ledger entry
INSERT INTO psy_stock_movements (item_id, item_name, location_id, movement_type, qty, balance_after, reference_type, notes, actor_name)
SELECT i.id, i.name, loc.id, 'in', v.opening_qty, v.opening_qty, 'opening_stock', 'Import data awal — 17 produk Coaching Supplies (5 Nov 2026)', 'System Import'
FROM (VALUES
  ('Poster Saranan Peminuman Madu Lote Tree Honey & Lote Tree Honey Pearl Garlic (10x)', 10::numeric),
  ('Poster Saranan Peminuman Madu Lote Tree Honey & Lote Tree Honey Pearl Garlic (8x)', 10::numeric),
  ('Poster Saranan Peminuman Madu Lote Tree Honey & Lote Tree Honey Pearl Garlic (4x)', 10::numeric),
  ('Poster Saranan Peminuman Madu Lote Tree Honey & Lote Tree Honey Pearl Garlic (2x)', 10::numeric),
  ('Poster Saranan Peminuman Madu Immune Booster & Young & Healthy Pearl Garlic (2 kg) (10x)', 10::numeric),
  ('Poster Saranan Peminuman Madu Immune Booster & Young & Healthy Pearl Garlic (2 kg) (8x)', 10::numeric),
  ('Poster Saranan Peminuman Madu Immune Booster & Young & Healthy Pearl Garlic (2 kg) (4x)', 10::numeric),
  ('Poster Saranan Peminuman Madu Immune Booster (500g) (2x)', 10::numeric),
  ('Poster Saranan Peminuman Young & Healthy Honey (500g) (2x)', 10::numeric),
  ('Poster Saranan Peminuman Breath & Digest Honey (500g) (2x)', 10::numeric),
  ('Poster Saranan Peminuman Brainy Kidz Honey (500g) (2x)', 10::numeric),
  ('Poster Saranan Peminuman Madu Immune Booster (500g) (1x)', 10::numeric),
  ('Poster Saranan Peminuman Young & Healthy Honey (500g) (1x)', 10::numeric),
  ('Poster Saranan Peminuman Breath & Digest Honey (500g) (1x)', 10::numeric),
  ('Poster Saranan Peminuman Brainy Kidz Honey (500g) (1x)', 10::numeric),
  ('Poster Panduan Pengamalan Zikir Bersanad (A4 Thick Paper)', 10::numeric),
  ('Senarai Nikmat Selera Sel dan Bahaya Nafsu Perut (A4 Paper)', 10::numeric)
) AS v(name, opening_qty)
JOIN psy_inventory_items i ON i.name = v.name
JOIN psy_inventory_locations loc ON loc.name = 'Printing'
WHERE NOT EXISTS (
  SELECT 1 FROM psy_stock_movements sm
  WHERE sm.item_id = i.id AND sm.reference_type = 'opening_stock' AND sm.notes = 'Import data awal — 17 produk Coaching Supplies (5 Nov 2026)'
);

-- ───────────────────────────────────────────────────────────────────
-- (bahagian 10) 44 produk "Equipment Event" (acara Santapan Fitrah +
-- Booth/Seminar). Lokasi baharu "Event Store". DIBUANG 2 baris duplicate
-- drpd templat 46-baris asal (nama lain ejaan/huruf besar-kecil, data
-- sama persis): "Honey Taster Spoon"=duplicate "Honey tester spoon";
-- "Kain alas putih" (Booth/Seminar)=duplicate "Kain alas Putih" (Santapan
-- Fitrah). "Banting" (baris asal) dah wujud sedia ada (INV-142) — WHERE
-- NOT EXISTS skip automatik. UOM asal byk letak saiz fizikal (18cm, 42cm
-- dll) bukan unit sah -> Pcs, saiz+konteks acara asal disimpan
-- internal_notes (lajur "Description" templat asal bukan deskripsi
-- produk). Harga "X per pack/unit/copy" — suffix dibuang, nombor sahaja.
-- "30+"/"10+" (Opening Stock) — tanda '+' dibuang.
-- ───────────────────────────────────────────────────────────────────

-- Equipment Event: insert 44 items (inline VALUES, no temp table)
INSERT INTO psy_inventory_items (name, internal_notes, unit, category, consumption_type, min_qty, source_type, status, is_active, requires_approval, supplier_info)
SELECT v.name, v.internal_notes, v.unit, v.category, v.consumption_type, 1, 'am', 'active', true, true,
  jsonb_strip_nulls(jsonb_build_object(
    'cost_per_unit', CASE WHEN v.price_min = v.price_max THEN v.price_min ELSE NULL END,
    'cost_per_unit_min', CASE WHEN v.price_min = v.price_max THEN NULL ELSE v.price_min END,
    'cost_per_unit_max', CASE WHEN v.price_min = v.price_max THEN NULL ELSE v.price_max END
  ))
FROM (VALUES
  ('Pinggan Porselin 18 cm', 'Event: Santapan Fitrah. Saiz 18 cm.', 'Pcs', 'Equipment Event', 'general', 3::numeric, 20::numeric, 1::numeric),
  ('Mangkuk Porselin 24 cm', 'Event: Santapan Fitrah. Saiz 24 cm.', 'Pcs', 'Equipment Event', 'general', 3::numeric, 20::numeric, 1::numeric),
  ('Mangkuk Porselin 15 cm', 'Event: Santapan Fitrah. Saiz 15 cm.', 'Pcs', 'Equipment Event', 'general', 3::numeric, 20::numeric, 1::numeric),
  ('Papan Pemotong Plastik', 'Event: Santapan Fitrah', 'Pcs', 'Equipment Event', 'general', 25::numeric, 100::numeric, 1::numeric),
  ('Pan 42 cm', 'Event: Santapan Fitrah. Saiz 42 cm.', 'Pcs', 'Equipment Event', 'general', 25::numeric, 100::numeric, 2::numeric),
  ('Pan 36 cm', 'Event: Santapan Fitrah. Saiz 36 cm.', 'Pcs', 'Equipment Event', 'general', 25::numeric, 100::numeric, 1::numeric),
  ('Apron', 'Event: Santapan Fitrah', 'Pek', 'Equipment Event', 'general', 20::numeric, 20::numeric, 2::numeric),
  ('Mangkuk Porcelin kecil', 'Event: Santapan Fitrah', 'Pek', 'Equipment Event', 'general', 3::numeric, 20::numeric, 8::numeric),
  ('Mangkuk Plastik kecil', 'Event: Santapan Fitrah', 'Pek', 'Equipment Event', 'general', 3::numeric, 30::numeric, 8::numeric),
  ('Penapis Besi', 'Event: Santapan Fitrah', 'Pcs', 'Equipment Event', 'general', 8::numeric, 35::numeric, 1::numeric),
  ('Sudip kayu', 'Event: Santapan Fitrah', 'Pcs', 'Equipment Event', 'general', 3::numeric, 15::numeric, 3::numeric),
  ('Senduk kayu', 'Event: Santapan Fitrah', 'Pcs', 'Equipment Event', 'general', 3::numeric, 15::numeric, 1::numeric),
  ('Pinggan plastik Hijau 24 cm', 'Event: Santapan Fitrah. Saiz 24 cm.', 'Pcs', 'Equipment Event', 'general', 5::numeric, 15::numeric, 2::numeric),
  ('Mangkuk plastk hijau 15 cm', 'Event: Santapan Fitrah. Saiz 15 cm.', 'Pcs', 'Equipment Event', 'general', 3::numeric, 30::numeric, 3::numeric),
  ('Backdrop Santapan Fitrah', 'Event: Santapan Fitrah', 'Pcs', 'Equipment Event', 'general', 30::numeric, 250::numeric, 1::numeric),
  ('Meja lipat', 'Event: Santapan Fitrah', 'Pcs', 'Equipment Event', 'general', 80::numeric, 150::numeric, 2::numeric),
  ('Kabinet dapur gas mudah alih', 'Event: Santapan Fitrah', 'Pcs', 'Equipment Event', 'general', 150::numeric, 250::numeric, 1::numeric),
  ('Kain alas Putih', 'Event: Santapan Fitrah', 'Pcs', 'Equipment Event', 'general', 15::numeric, 45::numeric, 1::numeric),
  ('Kain alas Hitam', 'Event: Santapan Fitrah', 'Pcs', 'Equipment Event', 'general', 15::numeric, 45::numeric, 1::numeric),
  ('Portables Stove', 'Event: Santapan Fitrah', 'Unit', 'Equipment Event', 'general', 100::numeric, 150::numeric, 1::numeric),
  ('Mesin Pengisar elektrik', 'Event: Santapan Fitrah', 'Unit', 'Equipment Event', 'general', 50::numeric, 180::numeric, 1::numeric),
  ('Alas tahan haba', 'Event: Santapan Fitrah', 'Pcs', 'Equipment Event', 'general', 3::numeric, 5::numeric, 1::numeric),
  ('Buku Stand', 'Event: Booth/Seminar', 'Pcs', 'Equipment Event', 'general', 20::numeric, 80::numeric, 1::numeric),
  ('Poster stand', 'Event: Booth/Seminar', 'Pcs', 'Equipment Event', 'general', 40::numeric, 250::numeric, 24::numeric),
  ('Honey tester spoon', 'Event: Booth/Seminar', 'Pek', 'Equipment Event', 'general', 3::numeric, 12::numeric, 5::numeric),
  ('Tong sampah kecil', 'Event: Booth/Seminar', 'Pcs', 'Equipment Event', 'general', 5::numeric, 20::numeric, 1::numeric),
  ('Troli hitam', 'Event: Booth/Seminar', 'Unit', 'Equipment Event', 'general', 50::numeric, 180::numeric, 1::numeric),
  ('Troli besi biasa', 'Event: Booth/Seminar', 'Unit', 'Equipment Event', 'general', 50::numeric, 180::numeric, 1::numeric),
  ('Banting', 'Event: Booth/Seminar', 'Pcs', 'Equipment Event', 'general', 40::numeric, 250::numeric, 1::numeric),
  ('Roll Up Banting', 'Event: Booth/Seminar', 'Gulung', 'Equipment Event', 'general', 40::numeric, 250::numeric, 1::numeric),
  ('Pamplet @ Brochure Madu', 'Event: Booth/Seminar', 'Pcs', 'Equipment Event', 'general', 1::numeric, 15::numeric, 1::numeric),
  ('Sudu plastic pakai buang', 'Event: Santapan Fitrah', 'Pcs', 'Equipment Event', 'general', 3::numeric, 12::numeric, 30::numeric),
  ('Pinggan plastik pakai buang', 'Event: Santapan Fitrah', 'Pek', 'Equipment Event', 'general', 5::numeric, 15::numeric, 10::numeric),
  ('Cawan kertas', 'Event: Santapan Fitrah', 'Pcs', 'Equipment Event', 'general', 5::numeric, 15::numeric, 10::numeric),
  ('Tisu gulung', 'Event: Santapan Fitrah', 'Pek', 'Equipment Event', 'general', 3::numeric, 8::numeric, 3::numeric),
  ('Sarung tangan plastk plastik pakai buang', 'Event: Santapan Fitrah', 'Pcs', 'Equipment Event', 'general', 5::numeric, 15::numeric, 10::numeric),
  ('Tong gas butana', 'Event: Santapan Fitrah', 'Pcs', 'Equipment Event', 'general', 3::numeric, 3::numeric, 3::numeric),
  ('Voucher RM 100', 'Event: Santapan Fitrah', 'Pcs', 'Equipment Event', 'general', 100::numeric, 100::numeric, 10::numeric),
  ('Paparan Qr Pembayaran', 'Event: Booth/Seminar', 'Pcs', 'Equipment Event', 'general', 10::numeric, 10::numeric, 1::numeric),
  ('Beg sampah', 'Event: Booth/Seminar', 'Pek', 'Equipment Event', 'general', 5::numeric, 20::numeric, 10::numeric),
  ('Beg Pembelian', 'Event: Booth/Seminar', 'Pek', 'Equipment Event', 'general', 5::numeric, 10::numeric, 10::numeric),
  ('Poster Madu @ Produk', 'Event: Booth/Seminar', 'Pcs', 'Equipment Event', 'general', 1::numeric, 20::numeric, 10::numeric),
  ('Flyer', 'Event: Booth/Seminar', 'Pcs', 'Equipment Event', 'general', 1::numeric, 3::numeric, 10::numeric),
  ('Banner', 'Event: Booth/Seminar', 'Pcs', 'Equipment Event', 'general', 40::numeric, 250::numeric, 10::numeric)
) AS v(name, internal_notes, unit, category, consumption_type, price_min, price_max, opening_qty)
WHERE NOT EXISTS (SELECT 1 FROM psy_inventory_items existing WHERE existing.name = v.name);

-- Equipment Event: opening stock by location
INSERT INTO psy_inventory_stock_by_location (item_id, location_id, qty_in_stock)
SELECT i.id, loc.id, v.opening_qty
FROM (VALUES
  ('Pinggan Porselin 18 cm', 1::numeric),
  ('Mangkuk Porselin 24 cm', 1::numeric),
  ('Mangkuk Porselin 15 cm', 1::numeric),
  ('Papan Pemotong Plastik', 1::numeric),
  ('Pan 42 cm', 2::numeric),
  ('Pan 36 cm', 1::numeric),
  ('Apron', 2::numeric),
  ('Mangkuk Porcelin kecil', 8::numeric),
  ('Mangkuk Plastik kecil', 8::numeric),
  ('Penapis Besi', 1::numeric),
  ('Sudip kayu', 3::numeric),
  ('Senduk kayu', 1::numeric),
  ('Pinggan plastik Hijau 24 cm', 2::numeric),
  ('Mangkuk plastk hijau 15 cm', 3::numeric),
  ('Backdrop Santapan Fitrah', 1::numeric),
  ('Meja lipat', 2::numeric),
  ('Kabinet dapur gas mudah alih', 1::numeric),
  ('Kain alas Putih', 1::numeric),
  ('Kain alas Hitam', 1::numeric),
  ('Portables Stove', 1::numeric),
  ('Mesin Pengisar elektrik', 1::numeric),
  ('Alas tahan haba', 1::numeric),
  ('Buku Stand', 1::numeric),
  ('Poster stand', 24::numeric),
  ('Honey tester spoon', 5::numeric),
  ('Tong sampah kecil', 1::numeric),
  ('Troli hitam', 1::numeric),
  ('Troli besi biasa', 1::numeric),
  ('Banting', 1::numeric),
  ('Roll Up Banting', 1::numeric),
  ('Pamplet @ Brochure Madu', 1::numeric),
  ('Sudu plastic pakai buang', 30::numeric),
  ('Pinggan plastik pakai buang', 10::numeric),
  ('Cawan kertas', 10::numeric),
  ('Tisu gulung', 3::numeric),
  ('Sarung tangan plastk plastik pakai buang', 10::numeric),
  ('Tong gas butana', 3::numeric),
  ('Voucher RM 100', 10::numeric),
  ('Paparan Qr Pembayaran', 1::numeric),
  ('Beg sampah', 10::numeric),
  ('Beg Pembelian', 10::numeric),
  ('Poster Madu @ Produk', 10::numeric),
  ('Flyer', 10::numeric),
  ('Banner', 10::numeric)
) AS v(name, opening_qty)
JOIN psy_inventory_items i ON i.name = v.name
JOIN psy_inventory_locations loc ON loc.name = 'Event Store'
WHERE NOT EXISTS (SELECT 1 FROM psy_inventory_stock_by_location sbl WHERE sbl.item_id = i.id AND sbl.location_id = loc.id);

-- Equipment Event: opening stock ledger entry
INSERT INTO psy_stock_movements (item_id, item_name, location_id, movement_type, qty, balance_after, reference_type, notes, actor_name)
SELECT i.id, i.name, loc.id, 'in', v.opening_qty, v.opening_qty, 'opening_stock', 'Import data awal — 44 produk Equipment Event (5 Nov 2026)', 'System Import'
FROM (VALUES
  ('Pinggan Porselin 18 cm', 1::numeric),
  ('Mangkuk Porselin 24 cm', 1::numeric),
  ('Mangkuk Porselin 15 cm', 1::numeric),
  ('Papan Pemotong Plastik', 1::numeric),
  ('Pan 42 cm', 2::numeric),
  ('Pan 36 cm', 1::numeric),
  ('Apron', 2::numeric),
  ('Mangkuk Porcelin kecil', 8::numeric),
  ('Mangkuk Plastik kecil', 8::numeric),
  ('Penapis Besi', 1::numeric),
  ('Sudip kayu', 3::numeric),
  ('Senduk kayu', 1::numeric),
  ('Pinggan plastik Hijau 24 cm', 2::numeric),
  ('Mangkuk plastk hijau 15 cm', 3::numeric),
  ('Backdrop Santapan Fitrah', 1::numeric),
  ('Meja lipat', 2::numeric),
  ('Kabinet dapur gas mudah alih', 1::numeric),
  ('Kain alas Putih', 1::numeric),
  ('Kain alas Hitam', 1::numeric),
  ('Portables Stove', 1::numeric),
  ('Mesin Pengisar elektrik', 1::numeric),
  ('Alas tahan haba', 1::numeric),
  ('Buku Stand', 1::numeric),
  ('Poster stand', 24::numeric),
  ('Honey tester spoon', 5::numeric),
  ('Tong sampah kecil', 1::numeric),
  ('Troli hitam', 1::numeric),
  ('Troli besi biasa', 1::numeric),
  ('Banting', 1::numeric),
  ('Roll Up Banting', 1::numeric),
  ('Pamplet @ Brochure Madu', 1::numeric),
  ('Sudu plastic pakai buang', 30::numeric),
  ('Pinggan plastik pakai buang', 10::numeric),
  ('Cawan kertas', 10::numeric),
  ('Tisu gulung', 3::numeric),
  ('Sarung tangan plastk plastik pakai buang', 10::numeric),
  ('Tong gas butana', 3::numeric),
  ('Voucher RM 100', 10::numeric),
  ('Paparan Qr Pembayaran', 1::numeric),
  ('Beg sampah', 10::numeric),
  ('Beg Pembelian', 10::numeric),
  ('Poster Madu @ Produk', 10::numeric),
  ('Flyer', 10::numeric),
  ('Banner', 10::numeric)
) AS v(name, opening_qty)
JOIN psy_inventory_items i ON i.name = v.name
JOIN psy_inventory_locations loc ON loc.name = 'Event Store'
WHERE NOT EXISTS (
  SELECT 1 FROM psy_stock_movements sm
  WHERE sm.item_id = i.id AND sm.reference_type = 'opening_stock' AND sm.notes = 'Import data awal — 44 produk Equipment Event (5 Nov 2026)'
);
