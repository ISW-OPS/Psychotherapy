-- ═══════════════════════════════════════════════════════════════════
-- 20261123 — Staff boleh key-in pulangan botol bagi pihak pesakit
--
-- Punca: pulangan.html (staff) langsung tiada cara utk staff cipta rekod
-- psy_bottle_returns — hanya patient yang boleh INSERT ("Patient manage own
-- returns" FOR ALL guna patient_id = auth.uid() punya pesakit). Pesakit yang
-- hantar/bawa botol terus (tanpa guna borang app) jadi tiada rekod langsung.
--
-- Fix: tambah policy INSERT utk staff, padan pola "Staff read/update returns"
-- sedia ada (semak role = 'staff' di psy_profiles).
-- ═══════════════════════════════════════════════════════════════════

drop policy if exists "Staff insert returns" on psy_bottle_returns;
create policy "Staff insert returns" on psy_bottle_returns
  for insert
  with check (exists (select 1 from psy_profiles where id = auth.uid() and role = 'staff'));
