-- DNA Test Step 4 (Muat Naik Laporan): tambah "Dikendalikan Oleh" dropdown,
-- sama corak macam atgc_coach_id (Step 3). Jalankan sekali di TESTING dan PROD.

ALTER TABLE psy_dna_test_process ADD COLUMN IF NOT EXISTS report_handler_id UUID REFERENCES psy_profiles(id) ON DELETE SET NULL;
