-- Announcement categories: managed in-app. Super admin can add; all staff can read.
create table if not exists psy_announcement_categories (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  sort_order int default 0,
  is_active boolean default true,
  created_by uuid references psy_profiles(id) on delete set null,
  created_at timestamptz default now()
);
create index if not exists idx_ann_cat_sort on psy_announcement_categories(sort_order);

alter table psy_announcement_categories enable row level security;

-- All staff can read categories
drop policy if exists "ann_cat read" on psy_announcement_categories;
create policy "ann_cat read" on psy_announcement_categories for select using (
  auth.uid() in (select id from psy_profiles where role = 'staff')
);

-- Only super_admin can add / edit / remove
drop policy if exists "ann_cat manage" on psy_announcement_categories;
create policy "ann_cat manage" on psy_announcement_categories for all
  using (auth.uid() in (select id from psy_profiles where staff_role = 'super_admin'))
  with check (auth.uid() in (select id from psy_profiles where staff_role = 'super_admin'));

-- Seed default categories
insert into psy_announcement_categories (name, sort_order) values
  ('Promosi', 1), ('Info', 2), ('Kesihatan', 3), ('Kelas & Acara', 4),
  ('Komuniti', 5), ('Webinar', 6), ('Bacaan Manzil', 7), ('Kemaskini Sistem', 8)
on conflict (name) do nothing;
