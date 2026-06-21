-- Unified "Tambah Pengumuman" — extra columns for announcements & events
-- Announcements: category label, long rich content, audience targeting
alter table psy_announcements add column if not exists category text;
alter table psy_announcements add column if not exists content text;
alter table psy_announcements add column if not exists audience jsonb default '["patient"]'::jsonb;

-- Events: physical address + maps link + audience targeting
alter table psy_events add column if not exists address text;
alter table psy_events add column if not exists maps_url text;
alter table psy_events add column if not exists audience jsonb default '["patient"]'::jsonb;
