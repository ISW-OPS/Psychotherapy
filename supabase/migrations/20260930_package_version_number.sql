-- Version Management pakej (audit management, gantikan corak manual "(new)" dlm
-- nama pakej — lihat pakej.html versionCell()/pakej-edit.html f-version).
-- psy_packages.version_number sudah ADA dlm CREATE TABLE (database/schema/05_packages.sql)
-- utk pemasangan BAHARU, tapi tiada ALTER TABLE ditulis utk DB SEDIA ADA (testing/prod)
-- — kod UI dah siap sejak 18 Sept 2026 tapi lajur ni tak pernah benar-benar wujud
-- di live DB sehingga migration ni dijalankan.
ALTER TABLE psy_packages ADD COLUMN IF NOT EXISTS version_number INT NOT NULL DEFAULT 1;

COMMENT ON COLUMN psy_packages.version_number IS
  'Nombor version pakej (1, 2, 3, ...) — gantikan corak manual "(new)" dalam nama pakej. Version tertinggi bagi Nama Pakej yang sama = version semasa (implicit ikut nombor, tiada medan status berasingan).';
