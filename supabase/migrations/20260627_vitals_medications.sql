-- Tambah kolum ubat-ubatan pada bacaan vitals (diisi coach di plan-week.html).
-- spo2 sudah wujud dalam skema; ini hanya untuk medications.
ALTER TABLE psy_vitals ADD COLUMN IF NOT EXISTS medications TEXT;
