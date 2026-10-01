-- DNA Test Step 4 — rekod tarikh/masa & staf yang muat naik setiap dokumen
-- laporan (permintaan staf, 1 Okt 2026). Jadual meta berasingan supaya tak
-- ubah bentuk report_files sedia ada (array path string, dipakai consumer
-- lain cth roles/patient/rekod-perubatan.html).
-- Rujuk: database/schema/26_dna_test.sql, roles/staff/dna-test.html

ALTER TABLE psy_dna_test_process
  ADD COLUMN IF NOT EXISTS report_files_meta JSONB DEFAULT '{}'::jsonb;
