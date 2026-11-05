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

-- ═══════════════════════════════════════════════════════════════════
-- 5 Nov 2026 (bahagian 6) — Import data: 16 produk "Clinical Inventory"
-- (bekalan/consumables pesakit — tape, saline, sarung tangan, cannula dll),
-- semua lokasi "Clinical Store", consumption_type='package' (Patient Usage,
-- default templat asal) utk SEMUA 16, requires_approval=true, min_qty=1
-- (sama corak dgn bahagian 5). Kategori BAHARU "Clinical Inventory" (bukan
-- "Clinical Equipment" bahagian 5 — ikut nama literal dlm templat asal).
--
-- Harga: bila price_min=price_max (cth Normal Saline RM3.50-RM3.50, Tegaderm,
-- Sharp Bin, Yellow Biohazard Bag) dikesan sbg harga TETAP -> cost_per_unit
-- diisi, Min/Maks kosong (bukan "julat" RM3.50-RM3.50 yg tak bermakna).
-- Lain-lain (min<>max) -> cost_per_unit kosong, Harga Anggaran Min/Maks diisi.
--
-- Unit BAHARU "Ampoule" & "Nebule" ditambah ke CHECK constraint (templat
-- asal guna unit ni utk Vitamin C IV & Ventolin Nebules — tiada padanan
-- sedia ada dlm senarai 18 unit kita).
--
-- "Surgical Tape (1 inch)" KEMUNGKINAN BESAR dah wujud (item tes awal hari
-- ni, issue_unit Gulung->Inci) — WHERE NOT EXISTS by name skip row ni kalau
-- dah ada, TAK ditimpa/duplicate.
--
-- opening_stock_note templat asal (cth "100 pieces per box", "10L = 80
-- patients") disimpan dlm internal_notes (staf sahaja, tiada UI expose lagi)
-- — bukan notes (Product Description pesakit-facing).
--
-- Supplier: psy_suppliers TIADA UNIQUE(name), jadi guna WHERE NOT EXISTS
-- (bukan ON CONFLICT) utk elak duplicate bila migration ni run >1 kali.
-- ═══════════════════════════════════════════════════════════════════
ALTER TABLE psy_inventory_items DROP CONSTRAINT IF EXISTS psy_inventory_items_unit_check;
ALTER TABLE psy_inventory_items DROP CONSTRAINT IF EXISTS psy_inventory_items_issue_unit_check;
ALTER TABLE psy_inventory_items ADD CONSTRAINT psy_inventory_items_unit_check
  CHECK (unit IN ('Pcs','Botol','Kotak','Pek','Set','Gulung','Beg','Karton','Pasang',
                   'Unit','Gram','Kg','Naskhah','Ampoule','Nebule',
                   'Liter (L)','Mililiter (ml)','Meter (m)','Sentimeter (cm)','Inci (inch)'));
ALTER TABLE psy_inventory_items ADD CONSTRAINT psy_inventory_items_issue_unit_check
  CHECK (issue_unit IS NULL OR issue_unit IN ('Pcs','Botol','Kotak','Pek','Set','Gulung','Beg','Karton','Pasang',
                   'Unit','Gram','Kg','Naskhah','Ampoule','Nebule',
                   'Liter (L)','Mililiter (ml)','Meter (m)','Sentimeter (cm)','Inci (inch)'));

DROP TABLE IF EXISTS _import_clinical_inventory;
CREATE TEMP TABLE _import_clinical_inventory (
  name TEXT, notes TEXT, internal_notes TEXT, unit TEXT,
  price_min NUMERIC, price_max NUMERIC, opening_qty NUMERIC, supplier_name TEXT
);

INSERT INTO _import_clinical_inventory VALUES
('Surgical Tape (1 inch)', 'Medical adhesive tape, 1 inch wide, with 3 metres per roll.', '3M = 30 patients', 'Gulung', 3, 8, 3, 'Caring Pharmacy'),
('Alcohol (Surface Disinfectant) (250 mL)', 'Surface disinfectant for sanitising clinical surfaces.', '250 mL', 'Botol', 10, 15, 250, 'Caring Pharmacy'),
('Normal Saline (0.9% Sodium Chloride)', '0.9% sodium chloride solution.', NULL, 'Botol', 3.50, 3.50, 26, 'Caring Pharmacy'),
('Vitamin C IV Infusion', 'Intravenous ascorbic acid, 500 mg/2 mL.', '5 ampoules', 'Ampoule', 1.30, 2.00, 5, 'Pharmacy/Shopee'),
('Ventolin Nebules (Salbutamol)', 'Sterile solution of salbutamol supplied in nebules.', '5 nebules', 'Nebule', 2, 8, 5, 'Pharmacy/Shopee'),
('Alcohol Swab', 'Isopropyl Alcohol 70%, 50 gsm, for skin cleaning before procedures.', NULL, 'Kotak', 5, 10, 20, 'Caring Pharmacy'),
('Infusion Set (Length: 134 cm)', 'Infusion set with a tubing length of 134 cm.', NULL, 'Pcs', 3, 6, 20, 'Caring Pharmacy'),
('Cotton Ball (50 pieces - 1 pack)', 'Sterile or clean cotton balls for routine cleaning.', '100+', 'Pek', 3, 6, 100, 'Caring Pharmacy'),
('Examination Glove (Medium)', 'Examination gloves, medium size, 100 pieces per box.', '100 pieces per box', 'Kotak', 18, 25, 15, 'Caring Pharmacy'),
('Surgical Face Mask (50 pieces - 1 pack)', 'Three-ply surgical face masks, 50 pieces per pack.', '50 pieces per pack', 'Pek', 10, 22, 10, 'Caring Pharmacy'),
('Tegaderm Transparent IV Frame Dressing', 'Transparent adhesive dressing for protecting IV access sites, 6 cm x 7 cm.', NULL, 'Pcs', 1.30, 1.30, 10, 'Shopee'),
('IV Cannula (22G)', 'IV cannula, 22G, 0.9 x 25 mm, flow rate 36 mL/min.', '100+', 'Pcs', 2, 5, 100, 'Shopee'),
('IV Cannula (Kids) (24G)', 'Paediatric IV cannula, 24G, 0.8 x 19 mm, flow rate 25 mL/min.', NULL, 'Pcs', 2, 10, 10, 'Shopee'),
('Sharp Bin (10 L)', '10-litre sharps container for safe disposal of needles and other sharps.', '10L = 80 patients', 'Unit', 30, 30, 10, 'Shopee'),
('Yellow Biohazard Bag', 'Yellow clinical waste bag for safe clinical waste disposal.', '10L', 'Pcs', 0.55, 0.55, 10, 'Shopee'),
('Lancets & Test Strips Blood Glucose', 'Blood glucose testing consumables, including lancets and compatible test strips.', NULL, 'Pek', 25, 80, 10, 'Shopee');

INSERT INTO psy_inventory_categories (name) VALUES ('Clinical Inventory') ON CONFLICT (name) DO NOTHING;
INSERT INTO psy_inventory_locations (name, is_default) VALUES ('Clinical Store', false) ON CONFLICT (name) DO NOTHING;

INSERT INTO psy_suppliers (name, status)
SELECT DISTINCT ip.supplier_name, 'active'
FROM _import_clinical_inventory ip
WHERE NOT EXISTS (SELECT 1 FROM psy_suppliers existing WHERE existing.name = ip.supplier_name);

INSERT INTO psy_inventory_items (name, notes, internal_notes, unit, category, consumption_type, min_qty,
  source_type, status, is_active, requires_approval, supplier_id, supplier_info)
SELECT ip.name, ip.notes, ip.internal_notes, ip.unit, 'Clinical Inventory', 'package', 1,
  'am', 'active', true, true, sup.id,
  jsonb_strip_nulls(jsonb_build_object(
    'name', sup.name,
    'cost_per_unit', CASE WHEN ip.price_min = ip.price_max THEN ip.price_min ELSE NULL END,
    'cost_per_unit_min', CASE WHEN ip.price_min = ip.price_max THEN NULL ELSE ip.price_min END,
    'cost_per_unit_max', CASE WHEN ip.price_min = ip.price_max THEN NULL ELSE ip.price_max END
  ))
FROM _import_clinical_inventory ip
JOIN psy_suppliers sup ON sup.name = ip.supplier_name
WHERE NOT EXISTS (SELECT 1 FROM psy_inventory_items existing WHERE existing.name = ip.name);

INSERT INTO psy_inventory_stock_by_location (item_id, location_id, qty_in_stock)
SELECT i.id, loc.id, ip.opening_qty
FROM _import_clinical_inventory ip
JOIN psy_inventory_items i ON i.name = ip.name
JOIN psy_inventory_locations loc ON loc.name = 'Clinical Store'
WHERE NOT EXISTS (SELECT 1 FROM psy_inventory_stock_by_location sbl WHERE sbl.item_id = i.id AND sbl.location_id = loc.id);

INSERT INTO psy_stock_movements (item_id, item_name, location_id, movement_type, qty, balance_after, reference_type, notes, actor_name)
SELECT i.id, i.name, loc.id, 'in', ip.opening_qty, ip.opening_qty, 'opening_stock', 'Import data awal — 16 produk Clinical Inventory (5 Nov 2026)', 'System Import'
FROM _import_clinical_inventory ip
JOIN psy_inventory_items i ON i.name = ip.name
JOIN psy_inventory_locations loc ON loc.name = 'Clinical Store'
WHERE NOT EXISTS (
  SELECT 1 FROM psy_stock_movements sm
  WHERE sm.item_id = i.id AND sm.reference_type = 'opening_stock'
    AND sm.notes = 'Import data awal — 16 produk Clinical Inventory (5 Nov 2026)'
);

DROP TABLE IF EXISTS _import_clinical_inventory;

-- ═══════════════════════════════════════════════════════════════════
-- 5 Nov 2026 (bahagian 7) — Import data: 12 produk "General Inventory"
-- (bekalan dalaman — plastik sampah, sabun tandas, air mineral, bubble wrap,
-- bateri dll), consumption_type='general' (Internal Use) + requires_approval
-- =true utk SEMUA 12 (per arahan). Lokasi "General Store" (BAHARU — beza drpd
-- lokasi "General Inventory" yg dah sedia ada dari seed asal; kategori
-- "General Inventory" pula memang nama sengaja sama tapi jadual BERLAINAN
-- (psy_inventory_categories vs psy_inventory_locations), tiada konflik).
--
-- NOTA data bersih: templat asal letak SAIZ/DIMENSI fizikal dlm lajur UOM
-- utk beberapa baris (cth '18" x 22"', '1.05cm x 4.45cm') — ni BUKAN unit
-- stok sah (gagal CHECK constraint terus). Saya anggar unit SEBENAR ikut
-- konteks produk (cth beg sampah -> Pek, bateri AAA pek 16 -> Pek) &
-- simpan saiz/dimensi asal dlm internal_notes supaya info tak hilang.
-- Row #3 "Toilet Soap (2 Liter)": Opening Stock asal data literal '2 L'
-- (nampak tersalin drpd lajur UOM) — DIANGGAP 2 unit botol, SILA SEMAK &
-- betulkan di item-form.html kalau silap anggapan.
-- Tiada supplier diberi dlm templat ni (lain drpd batch sebelum) —
-- supplier_id/name kekal kosong.
-- ═══════════════════════════════════════════════════════════════════
DROP TABLE IF EXISTS _import_general_inventory;
CREATE TEMP TABLE _import_general_inventory (
  name TEXT, notes TEXT, internal_notes TEXT, unit TEXT,
  price_min NUMERIC, price_max NUMERIC, opening_qty NUMERIC
);

INSERT INTO _import_general_inventory VALUES
('Garbage Plastic (Toilet) – Small (S)', 'General consumable for routine toilet waste disposal.', 'Saiz 18" x 22"', 'Pek', 3, 5, 10),
('T-Shirt Plastic – Small (S)', 'Small plastic bags for general packing and daily use.', 'Saiz 18" x 22"', 'Pek', 3, 6, 10),
('Toilet Soap (2 Liter)', 'Liquid soap for routine toilet and hand washing use.', 'Botol 2 Liter. NOTA: opening stock asal data ''2 L'' — dianggap 2 unit, sila semak.', 'Botol', 12, 18, 2),
('Toilet Tissue Roll (1 Packet)', 'Toilet tissue rolls for restroom use.', 'Diameter/saiz roll: 10cm', 'Pek', 10, 15, 10),
('Mineral Water (250 mL)', 'Bottled mineral water for general consumption.', '250 mL setiap botol', 'Botol', 2, 3, 24),
('Mineral Water (1.5 L)', 'Bottled mineral water, 1.5-litre size.', '1.5 Liter setiap botol', 'Botol', 2, 3, 10),
('Pocket Tissue', 'Pocket-sized tissue for daily use.', 'Saiz 10 x 5 x 2 cm', 'Pek', 2, 5, 10),
('Honey Tablespoon (Plastic)', 'Plastic tablespoon for handling or serving honey.', NULL, 'Pcs', 1, 3, 10),
('Bubble Wrap (1 M)', 'Protective bubble wrap for packing and protecting items.', NULL, 'Meter (m)', 65, 65, 10),
('Beg Hijau (1 Box – 300 pcs)', 'Green bags, 300 pieces per box.', '300 keping setiap kotak', 'Kotak', 5, 25, 50),
('Battery AAA (Energizer / Eveready)', 'AAA batteries, 16 pieces per pack.', '16 keping setiap pek. Saiz bateri: 1.05cm x 4.45cm', 'Pek', 20, 30, 10),
('Cell Battery (Panasonic)', 'Panasonic cell battery, 20 mm diameter and 3.2 mm thickness.', '20mm diameter, 3.2mm ketebalan', 'Pcs', 4, 8, 5);

INSERT INTO psy_inventory_categories (name) VALUES ('General Inventory') ON CONFLICT (name) DO NOTHING;
INSERT INTO psy_inventory_locations (name, is_default) VALUES ('General Store', false) ON CONFLICT (name) DO NOTHING;

INSERT INTO psy_inventory_items (name, notes, internal_notes, unit, category, consumption_type, min_qty,
  source_type, status, is_active, requires_approval, supplier_info)
SELECT ip.name, ip.notes, ip.internal_notes, ip.unit, 'General Inventory', 'general', 1,
  'am', 'active', true, true,
  jsonb_strip_nulls(jsonb_build_object(
    'cost_per_unit', CASE WHEN ip.price_min = ip.price_max THEN ip.price_min ELSE NULL END,
    'cost_per_unit_min', CASE WHEN ip.price_min = ip.price_max THEN NULL ELSE ip.price_min END,
    'cost_per_unit_max', CASE WHEN ip.price_min = ip.price_max THEN NULL ELSE ip.price_max END
  ))
FROM _import_general_inventory ip
WHERE NOT EXISTS (SELECT 1 FROM psy_inventory_items existing WHERE existing.name = ip.name);

INSERT INTO psy_inventory_stock_by_location (item_id, location_id, qty_in_stock)
SELECT i.id, loc.id, ip.opening_qty
FROM _import_general_inventory ip
JOIN psy_inventory_items i ON i.name = ip.name
JOIN psy_inventory_locations loc ON loc.name = 'General Store'
WHERE NOT EXISTS (SELECT 1 FROM psy_inventory_stock_by_location sbl WHERE sbl.item_id = i.id AND sbl.location_id = loc.id);

INSERT INTO psy_stock_movements (item_id, item_name, location_id, movement_type, qty, balance_after, reference_type, notes, actor_name)
SELECT i.id, i.name, loc.id, 'in', ip.opening_qty, ip.opening_qty, 'opening_stock', 'Import data awal — 12 produk General Inventory (5 Nov 2026)', 'System Import'
FROM _import_general_inventory ip
JOIN psy_inventory_items i ON i.name = ip.name
JOIN psy_inventory_locations loc ON loc.name = 'General Store'
WHERE NOT EXISTS (
  SELECT 1 FROM psy_stock_movements sm
  WHERE sm.item_id = i.id AND sm.reference_type = 'opening_stock'
    AND sm.notes = 'Import data awal — 12 produk General Inventory (5 Nov 2026)'
);

DROP TABLE IF EXISTS _import_general_inventory;

-- ═══════════════════════════════════════════════════════════════════
-- 5 Nov 2026 (bahagian 8) — Import data: 8 produk "Raw Inventory" (bekalan
-- mentah pembuatan — botol/balang kosong + bahan mentah cecair), consumption
-- _type='general' (Internal Use*), requires_approval=true (ikut corak batch
-- sebelum, TIADA arahan teks eksplisit kali ni — sila betulkan kalau silap).
--
-- Lokasi: templat letak "Raw Inventory" sbg Storage Location (SAMA teks dgn
-- Category) — bukan dicipta lokasi baharu, DIPADANKAN ke lokasi "Raw Material
-- Store" yg SEDIA ADA dari seed asal sistem (34_inventory_locations.sql) sbb
-- maksud jelas sama (stor bahan mentah) — elak 2 lokasi raw material hampir
-- same nama. Kategori "Raw Inventory" pula memang baharu dicipta (jadual
-- berlainan drpd lokasi, tiada konflik).
--
-- Unit BAHARU "Balang" (Jar) ditambah — 4 produk Glass Jar tiada padanan unit
-- sedia ada (bekas, bukan botol). "Plastic Bottle"/"Colon Herbs" (1.5L) kekal
-- Botol sbb bekas cecair biasa.
--
-- NOTA anggapan ketara (SILA SEMAK):
-- - Olive Oil & Colon Herbs: UOM asal "2 L"/"1.5 L" tafsir sbg SAIZ BEKAS beli
--   (disimpan dlm internal_notes), tapi unit SEBENAR utk jejak stok bahan
--   mentah cecair ni ditukar ke Liter (L) (bukan "botol") — opening stock
--   diambil terus drpd lajur Opening Stock asal (1 utk Olive Oil).
-- - "Colon Herbs" deskripsi dualistik ("raw material OR packaging item") —
--   saya anggap bahan mentah cecair (sama corak Olive Oil), BUKAN bekas
--   kosong (tu dah ada baris berasingan "Plastic Bottle (Herba Kolon)").
-- - Glass Jar 4 baris: unit "Balang", kapasiti (250mL/500g/1kg/2kg) disimpan
--   internal_notes sahaja (bukan unit sah utk balang kosong — balang dikira
--   per keping, bukan per isipadu/berat kandungan).
-- - "Raw Herbs" harga "1,100" ditafsir RM1,100 (koma = pemisah ribu), BUKAN
--   julat/berbilang nombor.
-- ═══════════════════════════════════════════════════════════════════
DROP TABLE IF EXISTS _import_raw_inventory;
CREATE TEMP TABLE _import_raw_inventory (
  name TEXT, notes TEXT, internal_notes TEXT, unit TEXT,
  price_min NUMERIC, price_max NUMERIC, opening_qty NUMERIC
);

INSERT INTO _import_raw_inventory VALUES
('Plastic Bottle (Herba Kolon)', 'Plastic bottle for Herba Kolon.', 'Kapasiti 1.5 Liter', 'Botol', 50, 150, 5),
('Glass Jar 250 mL (Olive Oil)', 'Glass jar with 250 mL capacity for Olive Oil.', 'Kapasiti 250 mL', 'Balang', 5, 25, 5),
('Glass Jar 500 g', 'Glass jar with 500 g capacity.', 'Kapasiti 500 g', 'Balang', 5, 25, 10),
('Glass Jar 1 kg', 'Glass jar with 1 kg capacity.', 'Kapasiti 1 kg', 'Balang', 5, 25, 10),
('Glass Jar 2 kg', 'Glass jar with 2 kg capacity.', 'Kapasiti 2 kg', 'Balang', 5, 25, 10),
('Olive Oil', 'Olive oil used as a raw material.', 'Dibeli dlm bekas 2 Liter', 'Liter (L)', 35, 120, 1),
('Raw Herbs', 'Raw herbs used as production materials.', NULL, 'Pek', 1100, 1100, 10),
('Colon Herbs', 'Raw material or packaging item for Colon Herbs.', 'Anggap bahan mentah cecair (bukan bekas kosong) — kapasiti rujukan 1.5L, SILA SAHKAN.', 'Liter (L)', 110, 110, 5);

INSERT INTO psy_inventory_categories (name) VALUES ('Raw Inventory') ON CONFLICT (name) DO NOTHING;
INSERT INTO psy_inventory_locations (name, is_default) VALUES ('Raw Material Store', false) ON CONFLICT (name) DO NOTHING;

INSERT INTO psy_inventory_items (name, notes, internal_notes, unit, category, consumption_type, min_qty,
  source_type, status, is_active, requires_approval, supplier_info)
SELECT ip.name, ip.notes, ip.internal_notes, ip.unit, 'Raw Inventory', 'general', 1,
  'am', 'active', true, true,
  jsonb_strip_nulls(jsonb_build_object(
    'cost_per_unit', CASE WHEN ip.price_min = ip.price_max THEN ip.price_min ELSE NULL END,
    'cost_per_unit_min', CASE WHEN ip.price_min = ip.price_max THEN NULL ELSE ip.price_min END,
    'cost_per_unit_max', CASE WHEN ip.price_min = ip.price_max THEN NULL ELSE ip.price_max END
  ))
FROM _import_raw_inventory ip
WHERE NOT EXISTS (SELECT 1 FROM psy_inventory_items existing WHERE existing.name = ip.name);

INSERT INTO psy_inventory_stock_by_location (item_id, location_id, qty_in_stock)
SELECT i.id, loc.id, ip.opening_qty
FROM _import_raw_inventory ip
JOIN psy_inventory_items i ON i.name = ip.name
JOIN psy_inventory_locations loc ON loc.name = 'Raw Material Store'
WHERE NOT EXISTS (SELECT 1 FROM psy_inventory_stock_by_location sbl WHERE sbl.item_id = i.id AND sbl.location_id = loc.id);

INSERT INTO psy_stock_movements (item_id, item_name, location_id, movement_type, qty, balance_after, reference_type, notes, actor_name)
SELECT i.id, i.name, loc.id, 'in', ip.opening_qty, ip.opening_qty, 'opening_stock', 'Import data awal — 8 produk Raw Inventory (5 Nov 2026)', 'System Import'
FROM _import_raw_inventory ip
JOIN psy_inventory_items i ON i.name = ip.name
JOIN psy_inventory_locations loc ON loc.name = 'Raw Material Store'
WHERE NOT EXISTS (
  SELECT 1 FROM psy_stock_movements sm
  WHERE sm.item_id = i.id AND sm.reference_type = 'opening_stock'
    AND sm.notes = 'Import data awal — 8 produk Raw Inventory (5 Nov 2026)'
);

DROP TABLE IF EXISTS _import_raw_inventory;

-- ═══════════════════════════════════════════════════════════════════
-- 5 Nov 2026 (bahagian 9) — Import data: 17 "produk" Coaching Supplies
-- (POSTER/bahan cetak panduan dos madu + panduan coaching lain),
-- consumption_type='package' (Patient Usage), min_qty=1, requires_approval
-- =true (ikut corak). Kategori "Coaching Supplies" SEDIA ADA (tiada perlu
-- cipta).
--
-- NOTA KRITIKAL — nama produk templat asal (baris 1-15) DUPLICATE SAMA
-- PERSIS merentas pelbagai baris (cth 4 baris "Poster Saranan Peminuman
-- Madu Lote Tree Honey & Lote Tree Honey Pearl Garlic" — cuma beza di lajur
-- Description "Table spoon 10x/8x/4x/2x", bukan nama produk). Kalau diimport
-- ikut nama ASAL, WHERE NOT EXISTS (padanan nama) akan SKIP 3 drpd 4 baris
-- (dianggap "dah wujud"), hilang data senyap. Jadi nama produk DITAMBAH
-- sufiks dos (10x)/(8x)/(4x)/(2x)/(1x) supaya UNIK — SILA SEMAK nama
-- akhir ni padan cara awak nak panggil item ni.
--
-- Unit: UOM asal "1 Piece"/"A4"/"2 kg"/"500 g" SEMUA ditukar ke "Naskhah"
-- (unit piawai sistem utk bahan cetak/poster — sama corak dgn seed sedia
-- ada "Panduan Peminuman Madu", "Buku & Bahan Cetak"). "2 kg"/"500 g" dlm
-- UOM asal sekadar rujukan SAIZ PRODUK MADU yg poster tu terangkan (dah
-- ada dlm nama produk sendiri), BUKAN berat/isipadu poster — tak dipakai
-- sbg unit.
--
-- Harga: hanya baris #3 ada harga sebenar ("1-15 per copy" -> RM1-RM15).
-- Baki 16 baris "Not specified" -> Price (RM) & Harga Anggaran DUA-DUA
-- kosong (tiada anggapan harga dibuat).
--
-- Storage Location: templat tulis "Other Location" (SAMA teks dgn salah 1
-- pilihan di modul Equipment, BUKAN lokasi sedia ada di Inventory) —
-- DIPADANKAN ke lokasi "Printing" yg SEDIA ADA (dicipta awal hari ni khusus
-- utk bahan cetak) sbb lebih sesuai dr segi makna drpd cipta "Other
-- Location" generik baharu. SILA SEMAK/betulkan kalau silap anggapan.
--
-- NOTA: baris #16 "Poster Panduan Pengamalan Zikir Bersanad (A4 Thick
-- Paper)" nama HAMPIR SAMA dgn item sedia ada "Panduan Pengamalan Zikir
-- Bersanad" (seed asal, kategori Buku & Bahan Cetak) — nama BERBEZA jadi
-- TAK dikesan sbg duplicate, kedua-dua akan wujud berasingan. Mungkin
-- sebenarnya produk sama (versi poster vs buku) — sila semak & gabung
-- manual kalau perlu.
-- ═══════════════════════════════════════════════════════════════════
DROP TABLE IF EXISTS _import_coaching_supplies;
CREATE TEMP TABLE _import_coaching_supplies (
  name TEXT, notes TEXT, unit TEXT,
  price_min NUMERIC, price_max NUMERIC, opening_qty NUMERIC
);

INSERT INTO _import_coaching_supplies VALUES
('Poster Saranan Peminuman Madu Lote Tree Honey & Lote Tree Honey Pearl Garlic (10x)', 'Table spoon 10x', 'Naskhah', NULL, NULL, 10),
('Poster Saranan Peminuman Madu Lote Tree Honey & Lote Tree Honey Pearl Garlic (8x)', 'Table spoon 8x', 'Naskhah', NULL, NULL, 10),
('Poster Saranan Peminuman Madu Lote Tree Honey & Lote Tree Honey Pearl Garlic (4x)', 'Table spoon 4x', 'Naskhah', 1, 15, 10),
('Poster Saranan Peminuman Madu Lote Tree Honey & Lote Tree Honey Pearl Garlic (2x)', 'Table spoon 2x', 'Naskhah', NULL, NULL, 10),
('Poster Saranan Peminuman Madu Immune Booster & Young & Healthy Pearl Garlic (2 kg) (10x)', 'Table spoon 10x', 'Naskhah', NULL, NULL, 10),
('Poster Saranan Peminuman Madu Immune Booster & Young & Healthy Pearl Garlic (2 kg) (8x)', 'Table spoon 8x', 'Naskhah', NULL, NULL, 10),
('Poster Saranan Peminuman Madu Immune Booster & Young & Healthy Pearl Garlic (2 kg) (4x)', 'Table spoon 4x', 'Naskhah', NULL, NULL, 10),
('Poster Saranan Peminuman Madu Immune Booster (500g) (2x)', 'Table spoon 2x', 'Naskhah', NULL, NULL, 10),
('Poster Saranan Peminuman Young & Healthy Honey (500g) (2x)', 'Tablespoon 2x', 'Naskhah', NULL, NULL, 10),
('Poster Saranan Peminuman Breath & Digest Honey (500g) (2x)', 'Tablespoon 2x', 'Naskhah', NULL, NULL, 10),
('Poster Saranan Peminuman Brainy Kidz Honey (500g) (2x)', 'Tablespoon 2x', 'Naskhah', NULL, NULL, 10),
('Poster Saranan Peminuman Madu Immune Booster (500g) (1x)', 'Table spoon 1x', 'Naskhah', NULL, NULL, 10),
('Poster Saranan Peminuman Young & Healthy Honey (500g) (1x)', 'Tablespoon 1x', 'Naskhah', NULL, NULL, 10),
('Poster Saranan Peminuman Breath & Digest Honey (500g) (1x)', 'Tablespoon 1x', 'Naskhah', NULL, NULL, 10),
('Poster Saranan Peminuman Brainy Kidz Honey (500g) (1x)', 'Tablespoon 1x', 'Naskhah', NULL, NULL, 10),
('Poster Panduan Pengamalan Zikir Bersanad (A4 Thick Paper)', 'Coaching and patient-education material for wellness guidance.', 'Naskhah', NULL, NULL, 10),
('Senarai Nikmat Selera Sel dan Bahaya Nafsu Perut (A4 Paper)', 'Coaching and patient-education material for wellness guidance.', 'Naskhah', NULL, NULL, 10);

INSERT INTO psy_inventory_categories (name) VALUES ('Coaching Supplies') ON CONFLICT (name) DO NOTHING;
INSERT INTO psy_inventory_locations (name, is_default) VALUES ('Printing', false) ON CONFLICT (name) DO NOTHING;

INSERT INTO psy_inventory_items (name, notes, unit, category, consumption_type, min_qty,
  source_type, status, is_active, requires_approval, supplier_info)
SELECT ip.name, ip.notes, ip.unit, 'Coaching Supplies', 'package', 1,
  'am', 'active', true, true,
  jsonb_strip_nulls(jsonb_build_object(
    'cost_per_unit', CASE WHEN ip.price_min = ip.price_max THEN ip.price_min ELSE NULL END,
    'cost_per_unit_min', CASE WHEN ip.price_min = ip.price_max THEN NULL ELSE ip.price_min END,
    'cost_per_unit_max', CASE WHEN ip.price_min = ip.price_max THEN NULL ELSE ip.price_max END
  ))
FROM _import_coaching_supplies ip
WHERE NOT EXISTS (SELECT 1 FROM psy_inventory_items existing WHERE existing.name = ip.name);

INSERT INTO psy_inventory_stock_by_location (item_id, location_id, qty_in_stock)
SELECT i.id, loc.id, ip.opening_qty
FROM _import_coaching_supplies ip
JOIN psy_inventory_items i ON i.name = ip.name
JOIN psy_inventory_locations loc ON loc.name = 'Printing'
WHERE NOT EXISTS (SELECT 1 FROM psy_inventory_stock_by_location sbl WHERE sbl.item_id = i.id AND sbl.location_id = loc.id);

INSERT INTO psy_stock_movements (item_id, item_name, location_id, movement_type, qty, balance_after, reference_type, notes, actor_name)
SELECT i.id, i.name, loc.id, 'in', ip.opening_qty, ip.opening_qty, 'opening_stock', 'Import data awal — 17 produk Coaching Supplies (5 Nov 2026)', 'System Import'
FROM _import_coaching_supplies ip
JOIN psy_inventory_items i ON i.name = ip.name
JOIN psy_inventory_locations loc ON loc.name = 'Printing'
WHERE NOT EXISTS (
  SELECT 1 FROM psy_stock_movements sm
  WHERE sm.item_id = i.id AND sm.reference_type = 'opening_stock'
    AND sm.notes = 'Import data awal — 17 produk Coaching Supplies (5 Nov 2026)'
);

DROP TABLE IF EXISTS _import_coaching_supplies;
