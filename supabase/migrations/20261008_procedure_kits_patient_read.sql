-- Audit management #144c (8 Okt 2026) — roles/patient/plan-week.html perlu baca
-- psy_procedure_kits (nama kit + nama item) utk auto-collapse paparan Bekalan
-- ("🧰 Nama Prosedur (N item)") bila senarai supplies minggu tu padan SATU kit.
-- Sebelum ni RLS cuma benarkan role='staff' — pesakit terkena blok senyap (data
-- kosong, bukan ralat). Kit tak sensitif (nama kit + nama item generik sahaja),
-- jadi dibuka baca utk SEMUA pengguna log masuk — ikut corak sedia ada
-- psy_library_categories/psy_faq_items (FOR SELECT USING (true)), tapi dihadkan
-- is_active=true supaya kit yg dah dimatikan staff tak terdedah.
-- Rujuk database/schema/14_products_inventory.sql (sumber). Idempoten.

DROP POLICY IF EXISTS "Read active procedure kits" ON psy_procedure_kits;
CREATE POLICY "Read active procedure kits" ON psy_procedure_kits FOR SELECT
  USING (is_active = true);
