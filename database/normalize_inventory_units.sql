-- Migration: standardize psy_inventory_items.unit / psy_products.unit
-- Punca: kolum "unit" TEXT bebas tanpa constraint di kedua-dua jadual, jadi
-- staff boleh taip apa-apa ("botol" vs "Botol" vs "bottle") — risiko kiraan
-- salah bila unit tak sepadan antara Products, Stock In & pemberian bekalan
-- kepada pesakit. UI dah ditukar guna senarai piawai kongsi
-- (shared/inventoryUnits.js), tapi data sedia ada kena dinormalisasi dulu
-- SEBELUM constraint ditambah (kalau tak, ALTER akan gagal pada baris lama).
--
-- Senarai piawai (16): Biji (pcs), Botol, Kotak, Pek, Paket, Tiub, Tablet,
-- Kapsul, Set, Gulung, Beg, Pasang, Unit, Gram, Kg, Naskhah, Gelas.
--
-- Disahkan terhadap data PROD sebenar (xmvqvq, psy_inventory_items) — nilai
-- tak konsisten yang wujud sekarang: biji, botol, bottle, g, gelas, naskhah,
-- set, unit. Semak semula SELECT DISTINCT di bawah sebelum run kalau dah
-- lama — mungkin ada nilai baru masuk lagi.
--
-- Jalankan STEP 1 dulu (semak), pastikan setiap unit sedia ada ada dalam
-- peta STEP 2 sebelum teruskan. Idempotent — selamat re-run.

-- ── STEP 1: semak nilai unit sedia ada (jalankan & baca dulu) ──
-- SELECT unit, count(*) FROM psy_inventory_items GROUP BY unit ORDER BY unit;
-- SELECT unit, count(*) FROM psy_products        GROUP BY unit ORDER BY unit;

-- ── STEP 2: normalisasi nilai sedia ada ke senarai piawai ──
UPDATE psy_inventory_items SET unit = 'Biji (pcs)' WHERE unit = 'biji';
UPDATE psy_inventory_items SET unit = 'Botol'      WHERE unit IN ('botol', 'bottle');
UPDATE psy_inventory_items SET unit = 'Gram'       WHERE unit IN ('g', 'gram');
UPDATE psy_inventory_items SET unit = 'Kg'         WHERE unit IN ('kg');
UPDATE psy_inventory_items SET unit = 'Gelas'      WHERE unit = 'gelas';
UPDATE psy_inventory_items SET unit = 'Naskhah'    WHERE unit = 'naskhah';
UPDATE psy_inventory_items SET unit = 'Set'        WHERE unit = 'set';
UPDATE psy_inventory_items SET unit = 'Pasang'     WHERE unit = 'pasang';
UPDATE psy_inventory_items SET unit = 'Tiub'       WHERE unit IN ('tiub', 'tube');
UPDATE psy_inventory_items SET unit = 'Unit'       WHERE unit = 'unit';

UPDATE psy_products SET unit = 'Biji (pcs)' WHERE unit = 'biji';
UPDATE psy_products SET unit = 'Botol'      WHERE unit IN ('botol', 'bottle');
UPDATE psy_products SET unit = 'Gram'       WHERE unit IN ('g', 'gram');
UPDATE psy_products SET unit = 'Kg'         WHERE unit IN ('kg');
UPDATE psy_products SET unit = 'Gelas'      WHERE unit = 'gelas';
UPDATE psy_products SET unit = 'Naskhah'    WHERE unit = 'naskhah';
UPDATE psy_products SET unit = 'Set'        WHERE unit = 'set';
UPDATE psy_products SET unit = 'Pasang'     WHERE unit = 'pasang';
UPDATE psy_products SET unit = 'Tiub'       WHERE unit IN ('tiub', 'tube');
UPDATE psy_products SET unit = 'Unit'       WHERE unit = 'unit';

-- ── STEP 3: semak baki nilai yang TAK sepadan senarai piawai ──
-- Kalau query ni pulangkan baris, tambah UPDATE map baharu kat STEP 2 dulu
-- dan run semula STEP 2+3 sebelum teruskan ke STEP 4 (constraint akan gagal
-- kalau masih ada baris tak sepadan).
-- SELECT id, name, unit FROM psy_inventory_items
--   WHERE unit NOT IN ('Biji (pcs)','Botol','Kotak','Pek','Paket','Tiub','Tablet',
--                       'Kapsul','Set','Gulung','Beg','Pasang','Unit','Gram','Kg','Naskhah','Gelas');
-- SELECT id, name, unit FROM psy_products
--   WHERE unit IS NOT NULL AND unit NOT IN
--     ('Biji (pcs)','Botol','Kotak','Pek','Paket','Tiub','Tablet','Kapsul',
--      'Set','Gulung','Beg','Pasang','Unit','Gram','Kg','Naskhah','Gelas');

-- ── STEP 4: kunci default + CHECK constraint (padan schema/14_products_inventory.sql) ──
ALTER TABLE psy_inventory_items ALTER COLUMN unit SET DEFAULT 'Unit';
ALTER TABLE psy_inventory_items DROP CONSTRAINT IF EXISTS psy_inventory_items_unit_check;
ALTER TABLE psy_inventory_items ADD CONSTRAINT psy_inventory_items_unit_check
  CHECK (unit IN ('Biji (pcs)','Botol','Kotak','Pek','Paket','Tiub','Tablet',
                  'Kapsul','Set','Gulung','Beg','Pasang','Unit','Gram','Kg','Naskhah','Gelas'));

ALTER TABLE psy_products ALTER COLUMN unit SET DEFAULT 'Unit';
ALTER TABLE psy_products DROP CONSTRAINT IF EXISTS psy_products_unit_check;
ALTER TABLE psy_products ADD CONSTRAINT psy_products_unit_check
  CHECK (unit IS NULL OR unit IN ('Biji (pcs)','Botol','Kotak','Pek','Paket','Tiub','Tablet',
                                   'Kapsul','Set','Gulung','Beg','Pasang','Unit','Gram','Kg','Naskhah','Gelas'));

-- Run on testing (ipmemyiz) dulu kalau boleh akses, verify (buka item-form.html
-- -> unit sedia ada semua papar betul, tiada "(lama)" muncul), lepas tu run
-- pada prod (xmvqvq). Nota: sesi ini didapati Supabase MCP connect terus ke
-- prod (xmvqvq / "Real Data Center") — semak akaun MCP semasa sebelum run.
