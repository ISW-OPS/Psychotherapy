-- ════════════════════════════════════════════════════════════════
-- Security RLS fixes — 28 Jun 2026
-- ════════════════════════════════════════════════════════════════

-- 1. psy_notifications: hadkan INSERT kepada staff sahaja
--    (sebelum ini WITH CHECK(true) → mana-mana user boleh hantar notif kepada sesiapa)
DO $$ BEGIN
  DROP POLICY IF EXISTS "Anyone insert notifications" ON psy_notifications;
EXCEPTION WHEN undefined_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "Staff insert notifications" ON psy_notifications FOR INSERT
    WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- 2. psy_kepatuhan_log: beri staff write access
--    (kepatuhan-fill.html memerlukan staff boleh upsert log bagi pihak pesakit)
DO $$ BEGIN
  CREATE POLICY "kepatuhan_log_staff_write" ON psy_kepatuhan_log FOR ALL
    USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
    WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- 3. psy_kepatuhan_weekly: beri staff write access (sama seperti log)
DO $$ BEGIN
  CREATE POLICY "kepatuhan_weekly_staff_write" ON psy_kepatuhan_weekly FOR ALL
    USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
    WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

SELECT 'Security RLS fixes OK' AS status;
