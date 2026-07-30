-- ═══════════════════════════════════════════════════════════════════
-- MIGRASI: Tarikh tambahan untuk audit trail proses DNA Test
-- Run SEKALI di Supabase SQL Editor (testing & prod).
-- ═══════════════════════════════════════════════════════════════════

ALTER TABLE psy_dna_test_process ADD COLUMN IF NOT EXISTS kit_received_at       DATE;        -- Step 1: tarikh pesakit terima kit
ALTER TABLE psy_dna_test_process ADD COLUMN IF NOT EXISTS sample_sent_to_lab_at DATE;        -- Step 2: tarikh sample dihantar ke makmal
ALTER TABLE psy_dna_test_process ADD COLUMN IF NOT EXISTS lab_report_issued_at DATE;         -- Step 4: tarikh laporan dikeluarkan oleh lab
ALTER TABLE psy_dna_test_process ADD COLUMN IF NOT EXISTS reports_emailed_at   TIMESTAMPTZ;  -- Step 4: tarikh laporan dihantar ke pesakit via emel
