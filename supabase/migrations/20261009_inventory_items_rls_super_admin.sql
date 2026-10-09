-- Bug sedia ada (bukan dari fitur Fail Print): polisi RLS write psy_inventory_items
-- hanya benarkan staff_role admin/manager — super_admin tertinggal, jadi Super Admin
-- gagal cipta/kemaskini item inventori ("new row violates row-level security policy").
DROP POLICY IF EXISTS "Admin manage inventory items" ON psy_inventory_items;
CREATE POLICY "Admin manage inventory items" ON psy_inventory_items
  FOR ALL USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff' AND staff_role IN ('super_admin','admin','manager')))
  WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff' AND staff_role IN ('super_admin','admin','manager')));
