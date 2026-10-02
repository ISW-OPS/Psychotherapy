-- Version Management pakej: gantikan corak manual "(new)" dalam nama pakej —
-- nombor version sahaja, version tertinggi bagi Nama Pakej yang sama = version
-- semasa (implicit ikut nombor, tiada medan status berasingan).
-- Rujuk: database/schema/05_packages.sql, roles/staff/pakej-edit.html, roles/staff/pakej.html

ALTER TABLE psy_packages
  ADD COLUMN IF NOT EXISTS version_number INT NOT NULL DEFAULT 1;

COMMENT ON COLUMN psy_packages.version_number IS
  'Nombor version pakej (1, 2, 3, ...) — gantikan corak manual "(new)" dalam nama pakej. Version tertinggi bagi Nama Pakej yang sama = version semasa (implicit ikut nombor, tiada medan status berasingan).';
