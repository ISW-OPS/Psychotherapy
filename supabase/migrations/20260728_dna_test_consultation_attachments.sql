-- ═══════════════════════════════════════════════════════════════════
-- MIGRASI: Lampiran bebas untuk Step 5 Consultation (DNA Test)
-- Run SEKALI di Supabase SQL Editor (testing & prod).
-- Lampiran (skrip/nota/dll) khusus untuk satu proses/pesakit — bukan
-- disimpan/reuse merentas pesakit lain.
-- ═══════════════════════════════════════════════════════════════════

ALTER TABLE psy_dna_test_process ADD COLUMN IF NOT EXISTS consultation_attachments JSONB DEFAULT '[]'::jsonb;
