-- ============================================================
-- STEP 12 — Add thumbnail_url to psy_library_items
-- Run in Supabase SQL Editor
-- ============================================================

ALTER TABLE psy_library_items
  ADD COLUMN IF NOT EXISTS thumbnail_url TEXT;

-- Create storage bucket for library media (run once)
-- In Supabase Dashboard → Storage → New Bucket → "library-media" → Public
-- OR run via API. Manual step needed in dashboard.

SELECT 'Step 12 OK — library thumbnail_url column added' AS status;
