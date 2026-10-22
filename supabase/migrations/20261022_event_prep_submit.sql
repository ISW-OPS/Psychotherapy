-- ═══════════════════════════════════════════════════════════════════
-- Submit Senarai Persediaan — tab "Pemulangan Barang" kini hanya
-- muncul lepas staff tekan "Submit Senarai Persediaan" (bukan auto
-- sebaik tambah barang pertama).
-- ═══════════════════════════════════════════════════════════════════
ALTER TABLE psy_event_prep_meta ADD COLUMN IF NOT EXISTS submitted_at TIMESTAMPTZ;
