-- psy_settings was staff-only readable (RLS). Patient dashboard's Protokol
-- Kecemasan seksyen needs 'clinic_phone' as a fallback for "Call Coach" when
-- the patient has no coach assigned, or the assigned coach has no phone on
-- file — without this, the fallback silently does nothing (RLS just returns
-- an empty row set, no error).
--
-- Safe to open to all authenticated users: psy_settings never stores API
-- secrets (see comment atop 23_settings.sql) — only operational config like
-- clinic_name/phone/email/address/hours/currency.

DROP POLICY IF EXISTS "settings_read_authenticated" ON psy_settings;
CREATE POLICY "settings_read_authenticated" ON psy_settings
  FOR SELECT USING (auth.role() = 'authenticated');
