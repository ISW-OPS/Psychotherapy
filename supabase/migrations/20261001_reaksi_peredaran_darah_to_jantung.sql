-- Tukar nama kategori "Peredaran Darah" -> "Jantung" (permintaan staf, 1 Okt 2026).
-- Mencerminkan laluan sama macam rename manual via UI Kategori (reaksi-item.html
-- ktEditSave()) — cascade ke psy_reaksi_item.kumpulan + psy_reaksi_actions.kategori.
-- Rujuk: database/schema/12_reaksi.sql

UPDATE psy_reaksi_kategori SET nama = 'Jantung', ikon = '❤️', updated_at = now()
  WHERE nama = 'Peredaran Darah';

UPDATE psy_reaksi_item SET kumpulan = 'Jantung', ikon = '❤️'
  WHERE kumpulan = 'Peredaran Darah';

UPDATE psy_reaksi_actions SET kategori = 'Jantung'
  WHERE kategori = 'Peredaran Darah';

-- Produk & Bahan Luar: tambah gambar produk (staf minta) + kekalkan had saiz
-- bucket inventory-images yang dikongsi (dulu tiada file_size_limit/
-- allowed_mime_types langsung).
-- Rujuk: database/schema/39_recommended_directory.sql, database/schema/24_storage.sql
-- roles/staff/produk-bahan.html

ALTER TABLE psy_recommended_products
  ADD COLUMN IF NOT EXISTS image_url TEXT;

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('inventory-images', 'inventory-images', true, 2097152, ARRAY['image/png','image/jpeg','image/jpg','image/webp'])
ON CONFLICT (id) DO UPDATE
  SET file_size_limit = EXCLUDED.file_size_limit,
      allowed_mime_types = EXCLUDED.allowed_mime_types;


-- DNA Test Step 4 — rekod tarikh/masa & staf yang muat naik setiap dokumen
-- laporan (permintaan staf, 1 Okt 2026). Jadual meta berasingan supaya tak
-- ubah bentuk report_files sedia ada (array path string, dipakai consumer
-- lain cth roles/patient/rekod-perubatan.html).
-- Rujuk: database/schema/26_dna_test.sql, roles/staff/dna-test.html

ALTER TABLE psy_dna_test_process
  ADD COLUMN IF NOT EXISTS report_files_meta JSONB DEFAULT '{}'::jsonb;

-- Audit Tier 9 #8 — Tugasan Peribadi Coach: tambah medan Due Date berasingan
-- drpd task_date (dulu satu medan double sbg "bila nak buat" DAN "bila deadline").
-- Rujuk: database/schema/18_notifications_automations.sql, roles/staff/weekly-plan.html

ALTER TABLE psy_coach_tasks
  ADD COLUMN IF NOT EXISTS due_date DATE;

-- Audit (Pesakit/KOB) #11 — status vs outcome_status overlap. Backfill rekod
-- sedia ada yang mungkin desync (cth staff tukar "Status Outcome Rawatan" di
-- patient-form.html tanpa status turut berubah), lepas tu pasang trigger
-- supaya kekal sepadan selepas ini. Rujuk: database/schema/04_patients.sql

UPDATE psy_patients SET status = 'deceased'
  WHERE outcome_status = 'meninggal' AND status <> 'deceased';

UPDATE psy_patients SET outcome_status = 'meninggal', outcome_status_at = COALESCE(outcome_status_at, now())
  WHERE status = 'deceased' AND outcome_status IS DISTINCT FROM 'meninggal';

UPDATE psy_patients SET status = 'inactive'
  WHERE outcome_status IN ('completed', 'berhenti') AND status = 'active';

-- Kes nyata di audit: akaun dah 'inactive'/'archived' tapi outcome masih
-- 'otw' ("Sedang Berjalan") sbb fn_auto_inactive_on_session_done cuma isi
-- outcome bila ia NULL dulu, bukan bila ia 'otw'. UI papar kombinasi
-- mengelirukan "Tidak Aktif" + "Sedang Berjalan" utk pesakit yang sama.
UPDATE psy_patients SET outcome_status = 'completed', outcome_status_at = COALESCE(outcome_status_at, now())
  WHERE status IN ('inactive', 'archived') AND (outcome_status IS NULL OR outcome_status IN ('', 'otw'));

CREATE OR REPLACE FUNCTION sync_patient_status_outcome()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.outcome_status = 'meninggal' THEN
    NEW.status := 'deceased';
  ELSIF NEW.status = 'deceased' THEN
    NEW.outcome_status := 'meninggal';
  END IF;

  IF NEW.outcome_status IN ('completed', 'berhenti') AND NEW.status = 'active' THEN
    NEW.status := 'inactive';
  END IF;

  IF NEW.status IN ('inactive', 'archived')
     AND (NEW.outcome_status IS NULL OR NEW.outcome_status IN ('', 'otw')) THEN
    NEW.outcome_status := 'completed';
  END IF;

  IF NEW.outcome_status IS DISTINCT FROM OLD.outcome_status
     AND NEW.outcome_status IS NOT NULL
     AND NEW.outcome_status_at IS NULL THEN
    NEW.outcome_status_at := now();
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_patient_status_outcome ON psy_patients;
CREATE TRIGGER trg_sync_patient_status_outcome
  BEFORE UPDATE ON psy_patients
  FOR EACH ROW
  EXECUTE FUNCTION sync_patient_status_outcome();
