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
