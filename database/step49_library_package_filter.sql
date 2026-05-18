-- ============================================================
-- step49_library_package_filter.sql
-- Library content can be tagged with package IDs to restrict visibility.
-- NULL or empty array = visible to everyone (default).
-- Array of package_ids = only patients on matching package see it.
-- ============================================================

ALTER TABLE psy_library_items
  ADD COLUMN IF NOT EXISTS package_ids TEXT[];

COMMENT ON COLUMN psy_library_items.package_ids IS
  'Package IDs (psy_packages.package_id) that can access this content. NULL/empty = public for all.';

CREATE INDEX IF NOT EXISTS idx_library_package_ids
  ON psy_library_items USING GIN (package_ids);

SELECT 'Step 49 OK — library package filter ready' AS status;
