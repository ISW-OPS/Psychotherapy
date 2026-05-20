-- Add single Gmeet link per package — used for all weeks with online/both mode.
ALTER TABLE psy_packages
  ADD COLUMN IF NOT EXISTS meet_link TEXT;

COMMENT ON COLUMN psy_packages.meet_link IS
  'Pautan Gmeet recurring untuk pakej. Dipaparkan kepada patient bila minggu semasa adalah online/both.';
