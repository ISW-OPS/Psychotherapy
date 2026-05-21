-- ============================================================
-- STEP — Patient Address: Residence + City/State columns
-- Tambah alamat kediaman (berasingan dari surat-menyurat) +
-- pecahkan bandar / negeri untuk filter & laporan.
-- ============================================================

ALTER TABLE psy_patients
  ADD COLUMN IF NOT EXISTS home_address TEXT,
  ADD COLUMN IF NOT EXISTS city         TEXT,
  ADD COLUMN IF NOT EXISTS state        TEXT;

COMMENT ON COLUMN psy_patients.home_address IS
  'Alamat kediaman pesakit (berbeza dari address yang digunakan untuk surat-menyurat / mailing).';
COMMENT ON COLUMN psy_patients.city  IS 'Bandar (sebahagian dari alamat kediaman).';
COMMENT ON COLUMN psy_patients.state IS 'Negeri (Selangor, Johor, dll.).';

CREATE INDEX IF NOT EXISTS idx_patients_state ON psy_patients(state);

SELECT 'Step Patient Address OK — home_address, city, state added' AS status;
