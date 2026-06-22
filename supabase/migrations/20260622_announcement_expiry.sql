-- Optional display-expiry for announcements: hide from patient carousel once passed.
alter table psy_announcements add column if not exists expires_at timestamptz;
