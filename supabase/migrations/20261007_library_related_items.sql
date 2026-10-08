-- Audit management — item 139 (Library Content): staf kini boleh PILIH SENDIRI
-- "Kandungan Berkaitan" utk setiap item library (bukan setakat cadangan automatik
-- ikut topik sama). Rujuk database/schema/13_library_faq.sql.
-- Idempoten — selamat dijalankan berulang kali.

ALTER TABLE psy_library_items ADD COLUMN IF NOT EXISTS related_item_ids UUID[] DEFAULT '{}';

-- Pastikan baris sedia ada (ditambah sebelum kolum ni wujud) ada array kosong,
-- bukan NULL — patient-side (library-detail.html loadRelated()) jangan terkeliru
-- antara "staf belum tetapkan" (NULL/kosong, fallback auto-suggest) dgn ralat.
UPDATE psy_library_items SET related_item_ids = '{}' WHERE related_item_ids IS NULL;

CREATE INDEX IF NOT EXISTS idx_library_related ON psy_library_items USING GIN (related_item_ids);

COMMENT ON COLUMN psy_library_items.related_item_ids IS
  'Senarai id (psy_library_items.id) kandungan lain yang staf PILIH SENDIRI sebagai "Kandungan Berkaitan", ikut urutan staf pilih. Kosong/NULL = patient-side fallback ke cadangan automatik ikut topik sama (lihat loadRelated() di library-detail.html).';
