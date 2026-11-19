-- ═══════════════════════════════════════════════════════════════════
-- 6 Nov 2026 — Pindah item "equipment" yg tersalah masuk Inventori (bukan
-- Bekalan/Konsumabel) ke modul Equipment Store (psy_equipment) sebenar.
--
-- Punca: import 5 Nov 2026 letak SEMUA produk dlm kategori "Clinical
-- Equipment" (26 item) & "Equipment Event" (43 item) terus ke
-- psy_inventory_items — tapi sebenarnya dua kategori ni CAMPURAN:
--   - Peralatan tahan lama (reusable asset: mesin, troli, meja dll) —
--     sepatutnya di Equipment Store (form/field lain: no. siri, waranti,
--     servis/maintenance — bukan stok/reorder macam Inventori).
--   - Bekalan pakai-buang sebenar (mask, cannula, tisu, beg sampah dll) —
--     KEKAL di Inventori sbb betul2 konsumabel/stok.
--
-- Pemisahan ni JUDGMENT CALL berasaskan nama produk (bukan 100% pasti utk
-- semua) — SILA SEMAK senarai di Equipment Store & Inventori lepas run,
-- repair manual kalau ada yg tersilap letak.
--
-- Teknik: INSERT psy_equipment dibaca terus drpd psy_inventory_items
-- (qty_in_stock tiap item -> bilangan row equipment, sbb Equipment Store
-- track per-unit fizikal, bukan 1 row+qty) SEBELUM DELETE row asal —
-- jadi kalau fail ni di-run 2x, SELECT kali ke-2 dah 0 row (row dah
-- dipadam kali pertama), auto idempoten tanpa perlu WHERE NOT EXISTS.
-- ═══════════════════════════════════════════════════════════════════

-- ───────────────────────────────────────────────────────────────────
-- BAHAGIAN 1: "Clinical Equipment" (26 item) — 18 peralatan tahan lama
-- pindah ke Equipment Store (kategori "Clinical Equipment", lokasi
-- "Clinical Store" — padan terus dgn shared/equipmentMasterData.js).
-- Baki 8 (mask/cannula/tubing pakai-buang) KEKAL Inventori, recategorize
-- ke "Clinical Inventory" (bahagian 3) sbb "Clinical Equipment" dah tak
-- sesuai label utk konsumabel ni.
-- ───────────────────────────────────────────────────────────────────
-- 1 row per item (bukan 1 row per unit-stok lagi — user putuskan tak nak
-- track per-unit utk item bulk-import ni, cukup 1 row wakil tiap jenis
-- peralatan walau qty_in_stock asal >1).
INSERT INTO psy_equipment (name, category, storage_location, supplier, supplier_id, purchase_cost, image_url, status)
SELECT i.name,
       'Clinical Equipment', 'Clinical Store',
       i.supplier_info->>'name',
       (SELECT s.id FROM psy_suppliers s WHERE s.name = i.supplier_info->>'name' LIMIT 1),
       COALESCE((i.supplier_info->>'cost_per_unit')::numeric, (i.supplier_info->>'cost_per_unit_min')::numeric),
       i.image_url, 'available'
FROM psy_inventory_items i
WHERE i.item_code IN (
  'INV-198', -- Adjustable Hospital Bed
  'INV-188', -- Blood Pressure Cuff (BP Cuff)
  'INV-205', -- C-Shape Overbed Table
  'INV-187', -- Digital Blood Pressure Monitor
  'INV-192', -- Electronic Body Weight Scale
  'INV-191', -- Glucometer Machine
  'INV-181', -- Humidifier Bottle
  'INV-197', -- Hydrogen Inhalation Machine
  'INV-185', -- IV Infusion Stand
  'INV-200', -- Mattress
  'INV-199', -- Medical Air Mattress
  'INV-195', -- Nebuliser Machine / Compressor
  'INV-189', -- Oximeter
  'INV-180', -- Oxygen Concentrator
  'INV-193', -- Plastic Kidney Tray
  'INV-190', -- Thermometer
  'INV-186', -- Venous Tourniquet
  'INV-194'  -- Wheelchair
);

DELETE FROM psy_inventory_items WHERE item_code IN (
  'INV-198','INV-188','INV-205','INV-187','INV-192','INV-191','INV-181','INV-197',
  'INV-185','INV-200','INV-199','INV-195','INV-189','INV-180','INV-193','INV-190',
  'INV-186','INV-194'
);

-- ───────────────────────────────────────────────────────────────────
-- BAHAGIAN 2: "Equipment Event" (43 item) — 30 peralatan tahan lama
-- pindah ke Equipment Store (kategori "Event Equipment", lokasi
-- "Event Store"). Baki 13 (beg sampah/cawan/tisu/flyer/voucher dll —
-- betul2 pakai-buang/edar) KEKAL Inventori, recategorize ke "Bekalan
-- Acara" (bahagian 4) sbb kategori asal "Equipment Event" akan jadi
-- kosong/mengelirukan lepas ni.
-- ───────────────────────────────────────────────────────────────────
-- 1 row per item (lihat nota BAHAGIAN 1).
INSERT INTO psy_equipment (name, category, storage_location, supplier, supplier_id, purchase_cost, image_url, status)
SELECT i.name,
       'Event Equipment', 'Event Store',
       i.supplier_info->>'name',
       (SELECT s.id FROM psy_suppliers s WHERE s.name = i.supplier_info->>'name' LIMIT 1),
       COALESCE((i.supplier_info->>'cost_per_unit')::numeric, (i.supplier_info->>'cost_per_unit_min')::numeric),
       i.image_url, 'available'
FROM psy_inventory_items i
WHERE i.item_code IN (
  'INV-281', -- Alas tahan haba
  'INV-274', -- Backdrop Santapan Fitrah
  'INV-302', -- Banner
  'INV-282', -- Buku Stand
  'INV-276', -- Kabinet dapur gas mudah alih
  'INV-278', -- Kain alas Hitam
  'INV-277', -- Kain alas Putih
  'INV-268', -- Mangkuk Plastik kecil
  'INV-273', -- Mangkuk plastk hijau 15 cm
  'INV-267', -- Mangkuk Porcelin kecil
  'INV-262', -- Mangkuk Porselin 15 cm
  'INV-261', -- Mangkuk Porselin 24 cm
  'INV-275', -- Meja lipat
  'INV-280', -- Mesin Pengisar elektrik
  'INV-265', -- Pan 36 cm
  'INV-264', -- Pan 42 cm
  'INV-263', -- Papan Pemotong Plastik
  'INV-297', -- Paparan Qr Pembayaran
  'INV-269', -- Penapis Besi
  'INV-272', -- Pinggan plastik Hijau 24 cm
  'INV-260', -- Pinggan Porselin 18 cm
  'INV-279', -- Portables Stove
  'INV-283', -- Poster stand
  'INV-288', -- Roll Up Banting
  'INV-271', -- Senduk kayu
  'INV-270', -- Sudip kayu
  'INV-295', -- Tong gas butana
  'INV-285', -- Tong sampah kecil
  'INV-287', -- Troli besi biasa
  'INV-286'  -- Troli hitam
);

DELETE FROM psy_inventory_items WHERE item_code IN (
  'INV-281','INV-274','INV-302','INV-282','INV-276','INV-278','INV-277','INV-268',
  'INV-273','INV-267','INV-262','INV-261','INV-275','INV-280','INV-265','INV-264',
  'INV-263','INV-297','INV-269','INV-272','INV-260','INV-279','INV-283','INV-288',
  'INV-271','INV-270','INV-295','INV-285','INV-287','INV-286'
);

-- ───────────────────────────────────────────────────────────────────
-- BAHAGIAN 3: baki 8 konsumabel "Clinical Equipment" -> recategorize ke
-- "Clinical Inventory" (kategori sedia ada, sama jenis dgn tape/saline/
-- gloves/cannula yg diimport 5 Nov).
-- ───────────────────────────────────────────────────────────────────
UPDATE psy_inventory_items SET category = 'Clinical Inventory'
WHERE item_code IN (
  'INV-203', -- Hydrogen Nasal Cannula
  'INV-204', -- Hydrogen Tubing
  'INV-196', -- Nebuliser Cup / Chamber
  'INV-201', -- Nebuliser Mask
  'INV-202', -- Nebuliser Tubing
  'INV-184', -- Oxygen Mask
  'INV-182', -- Oxygen Nasal Cannula
  'INV-183'  -- Oxygen Tubing (Tiub)
);

-- ───────────────────────────────────────────────────────────────────
-- BAHAGIAN 4: baki 13 konsumabel "Equipment Event" -> kategori baharu
-- "Bekalan Acara" (Event Supplies) supaya tak lagi label "Equipment".
-- ───────────────────────────────────────────────────────────────────
INSERT INTO psy_inventory_categories (name)
SELECT 'Bekalan Acara'
WHERE NOT EXISTS (SELECT 1 FROM psy_inventory_categories WHERE name = 'Bekalan Acara');

UPDATE psy_inventory_items SET category = 'Bekalan Acara'
WHERE item_code IN (
  'INV-266', -- Apron
  'INV-299', -- Beg Pembelian
  'INV-298', -- Beg sampah
  'INV-292', -- Cawan kertas
  'INV-301', -- Flyer
  'INV-284', -- Honey tester spoon
  'INV-289', -- Pamplet @ Brochure Madu
  'INV-291', -- Pinggan plastik pakai buang
  'INV-300', -- Poster Madu @ Produk
  'INV-294', -- Sarung tangan plastk plastik pakai buang
  'INV-290', -- Sudu plastic pakai buang
  'INV-293', -- Tisu gulung
  'INV-296'  -- Voucher RM 100
);

-- ───────────────────────────────────────────────────────────────────
-- BAHAGIAN 5: kategori "Clinical Equipment" & "Equipment Event" kini
-- kosong di Inventori (semua item dah dipindah/direcategorize di atas)
-- — buang dari senarai kategori Inventori. psy_inventory_categories
-- bukan FK target (TEXT bebas di psy_inventory_items), hard DELETE
-- selamat. TIDAK sentuh kategori sama nama di Equipment Store
-- (shared/equipmentMasterData.js) — itu senarai berasingan.
-- ───────────────────────────────────────────────────────────────────
DELETE FROM psy_inventory_categories WHERE name IN ('Clinical Equipment','Equipment Event')
  AND NOT EXISTS (
    SELECT 1 FROM psy_inventory_items ii WHERE ii.category IN ('Clinical Equipment','Equipment Event')
  );

-- ───────────────────────────────────────────────────────────────────
-- BAHAGIAN 6 (tambahan, selepas user perasan nama bertindih di Equipment
-- Store — cth "Pinggan plastik Hijau 24 cm" x2) — user putuskan TAK NAK
-- track per-unit utk bulk-import ni, cukup 1 row wakil tiap jenis. BAHAGIAN
-- 1 & 2 di atas dah dikemaskini terus (1 row/item) utk run akan datang di
-- persekitaran lain spt testing. DELETE ni safety-net: buang baki row
-- bertindih nama (kekalkan 1 — kod EQ- terkecil), idempoten (0 row kesan
-- kalau dah bersih).
-- ───────────────────────────────────────────────────────────────────
DELETE FROM psy_equipment e USING (
  SELECT id, row_number() OVER (PARTITION BY name ORDER BY code) AS rn
  FROM psy_equipment
) sub
WHERE e.id = sub.id AND sub.rn > 1;
