-- Patch: tambah lajur teks guardian_name/guardian_ic pada psy_kob_agreements.
-- Nama/IC Waris/Penjamin kini medan TAIP (bukan lagi imej tulisan tangan sahaja),
-- sama konsep dengan patient_name/patient_ic sedia ada. Lihat database/schema/09_kob.sql
-- untuk definisi penuh & sumber kebenaran (fail ni patch manual sahaja, run terus
-- di SQL Editor Supabase — testing DULU, prod lepas disahkan OK).

ALTER TABLE psy_kob_agreements ADD COLUMN IF NOT EXISTS guardian_name TEXT;
ALTER TABLE psy_kob_agreements ADD COLUMN IF NOT EXISTS guardian_ic TEXT;

-- Refresh PostgREST schema cache supaya lajur baharu terus dikesan tanpa perlu
-- restart projek (elak ralat "Could not find the 'X' column ... in the schema cache").
NOTIFY pgrst, 'reload schema';
