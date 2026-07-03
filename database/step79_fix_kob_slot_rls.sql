-- step79_fix_kob_slot_rls.sql
-- Betulkan polisi RLS supaya SUPER ADMIN boleh urus Slot, Cuti/Penutupan & Override.
-- Punca: sesetengah polisi tertinggal 'super_admin' (cth clinic_closures cuma
-- ('admin','manager')), jadi Super Admin dapat ralat "new row violates RLS policy".
-- Migrasi ni selaraskan semua ke ('admin','manager','doctor','super_admin') + WITH CHECK.
-- Jalankan di TESTING dahulu, kemudian PRODUCTION (xmvqvq).

-- 1) Slot rawatan/KOB
DROP POLICY IF EXISTS "Admin manage kob slots" ON psy_kob_slot_config;
CREATE POLICY "Admin manage kob slots" ON psy_kob_slot_config FOR ALL
  USING (EXISTS (
    SELECT 1 FROM psy_profiles
    WHERE id = auth.uid() AND role = 'staff'
      AND staff_role IN ('admin','manager','doctor','super_admin')
  ))
  WITH CHECK (EXISTS (
    SELECT 1 FROM psy_profiles
    WHERE id = auth.uid() AND role = 'staff'
      AND staff_role IN ('admin','manager','doctor','super_admin')
  ));

-- 2) Cuti / Penutupan klinik
DROP POLICY IF EXISTS "Admin manage clinic closures" ON psy_clinic_closures;
CREATE POLICY "Admin manage clinic closures" ON psy_clinic_closures FOR ALL
  USING (EXISTS (
    SELECT 1 FROM psy_profiles
    WHERE id = auth.uid() AND role = 'staff'
      AND staff_role IN ('admin','manager','doctor','super_admin')
  ))
  WITH CHECK (EXISTS (
    SELECT 1 FROM psy_profiles
    WHERE id = auth.uid() AND role = 'staff'
      AND staff_role IN ('admin','manager','doctor','super_admin')
  ));

-- 3) Override per-tarikh (kalau jadual wujud)
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'psy_slot_date_overrides') THEN
    DROP POLICY IF EXISTS "Staff manage slot overrides" ON psy_slot_date_overrides;
    CREATE POLICY "Staff manage slot overrides" ON psy_slot_date_overrides FOR ALL
      USING (EXISTS (
        SELECT 1 FROM psy_profiles
        WHERE id = auth.uid() AND role = 'staff'
          AND staff_role IN ('admin','manager','doctor','super_admin')
      ))
      WITH CHECK (EXISTS (
        SELECT 1 FROM psy_profiles
        WHERE id = auth.uid() AND role = 'staff'
          AND staff_role IN ('admin','manager','doctor','super_admin')
      ));
  END IF;
END $$;

SELECT 'OK — super_admin boleh urus slot / cuti / override sekarang' AS status;
