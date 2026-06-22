-- Audience targeting by package: store package codes (psy_packages.package_id) an
-- announcement/event is restricted to. Empty array = no restriction (all patients).
alter table psy_announcements add column if not exists package_ids jsonb default '[]'::jsonb;
alter table psy_events        add column if not exists package_ids jsonb default '[]'::jsonb;
