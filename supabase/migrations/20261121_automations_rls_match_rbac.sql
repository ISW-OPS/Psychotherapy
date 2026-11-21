-- ═══════════════════════════════════════════════════════════════════
-- 20261121 — RLS psy_automations/psy_automation_messages/psy_auto_messages/
-- psy_audiences diselaraskan dengan RBAC sedia ada (psy_user_effective_permissions)
--
-- Punca: UI "Cipta Automasi" (automation-builder.html) bagi butang create
-- kepada staff_role coach/doctor/admin/manager/super_admin (ikut RBAC modul
-- auto_messages), tapi RLS DB cuma benarkan super_admin/manager (atau
-- super_admin sahaja utk psy_auto_messages) — insert gagal dgn
-- "new row violates row-level security policy".
--
-- Fix: lebarkan RLS supaya padan RBAC sedia ada.
-- ═══════════════════════════════════════════════════════════════════

drop policy if exists "automations mgr manage" on psy_automations;
create policy "automations mgr manage" on psy_automations for all
  using (auth.uid() in (select id from psy_profiles where staff_role in ('super_admin','manager','admin','coach','doctor')))
  with check (auth.uid() in (select id from psy_profiles where staff_role in ('super_admin','manager','admin','coach','doctor')));

drop policy if exists "auto_msgs mgr manage" on psy_automation_messages;
create policy "auto_msgs mgr manage" on psy_automation_messages for all
  using (auth.uid() in (select id from psy_profiles where staff_role in ('super_admin','manager','admin','coach','doctor')))
  with check (auth.uid() in (select id from psy_profiles where staff_role in ('super_admin','manager','admin','coach','doctor')));

drop policy if exists "auto_msg super manage" on psy_auto_messages;
create policy "auto_msg super manage" on psy_auto_messages for all
  using (auth.uid() in (select id from psy_profiles where staff_role in ('super_admin','manager','admin','coach','doctor')))
  with check (auth.uid() in (select id from psy_profiles where staff_role in ('super_admin','manager','admin','coach','doctor')));

drop policy if exists "audiences mgr manage" on psy_audiences;
create policy "audiences mgr manage" on psy_audiences for all
  using (auth.uid() in (select id from psy_profiles where staff_role in ('super_admin','manager','admin','coach','doctor')))
  with check (auth.uid() in (select id from psy_profiles where staff_role in ('super_admin','manager','admin','coach','doctor')));

-- ═══════════════════════════════════════════════════════════════════
-- Pisahkan denda Tidak Hadir drpd harga "Tambah Sesi" (psy_packages)
--
-- Punca: "Charge Fee" (denda tidak hadir) di plan-week.html SEBELUM NI guna
-- terus extension_price_per_session (medan sama dgn harga butang "Tambah
-- Sesi" di patient-hub.html) — dua niat berbeza bercampur dalam 1 field,
-- staff ubah satu secara tak sengaja ubah yang satu lagi. UI pakej-edit.html
-- pun cuma label "Harga Tambah Sesi", tak sebut ia jugak jadi amaun denda.
--
-- Fix: field baharu absence_fee_amount, backfill ikut nilai extension_price_
-- per_session SEDIA ADA (supaya amaun yang pesakit tengah kena denda TAK
-- berubah tiba-tiba lepas migration) — staff boleh betulkan nilai lepas ni
-- di pakej-edit.html → tab Lain → "⛔ Denda Tidak Hadir (RM)".
-- ═══════════════════════════════════════════════════════════════════

alter table psy_packages add column if not exists absence_fee_amount numeric(10,2) default 25;

comment on column psy_packages.absence_fee_amount is
  'Denda (RM) bila pesakit Tidak Hadir sesi — butang "Kenakan Denda" di plan-week.html. Field berasingan drpd extension_price_per_session (dulu guna field sama, bercampur niat); default RM 25.';

update psy_packages
set absence_fee_amount = extension_price_per_session
where absence_fee_amount is null or absence_fee_amount = 25;
