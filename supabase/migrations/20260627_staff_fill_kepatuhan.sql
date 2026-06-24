-- =====================================================================
-- Staff isi Catatan Harian bagi pihak pesakit (mod staff borang kepatuhan)
-- ---------------------------------------------------------------------
-- Borang pesakit roles/patient/kepatuhan.html boleh dibuka dalam "mod
-- staff" (?patient_id=&date=&staff=1) supaya coach/staff tolong isi
-- Catatan Harian bagi pihak pesakit (cth hari tertinggal).
--
-- RLS asal hanya benarkan PESAKIT tulis rekod sendiri. Migrasi ini tambah
-- polisi izinkan STAFF tulis ke psy_kepatuhan_log + psy_daily_checkins.
-- Tag audit disimpan dalam jawapan.__by = 'staff:<id>'. Idempotent.
-- =====================================================================

do $$ begin
  create policy "Staff manage kepatuhan log" on psy_kepatuhan_log for all
    using (exists (select 1 from psy_profiles where id = auth.uid() and role = 'staff'))
    with check (exists (select 1 from psy_profiles where id = auth.uid() and role = 'staff'));
exception when duplicate_object then null; end $$;

do $$ begin
  create policy "Staff manage daily checkins" on psy_daily_checkins for all
    using (exists (select 1 from psy_profiles where id = auth.uid() and role = 'staff'))
    with check (exists (select 1 from psy_profiles where id = auth.uid() and role = 'staff'));
exception when duplicate_object then null; end $$;

select 'OK — staff fill kepatuhan RLS ready' as status;
