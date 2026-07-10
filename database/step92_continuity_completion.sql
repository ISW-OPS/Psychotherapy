-- step92_continuity_completion.sql
-- KERJA A (minggu sambungan): kemaskini trigger auto-inactive (step80) supaya PELAN TIDAK
-- auto-tutup selagi ada MINGGU SAMBUNGAN (continuity) yang sudah DIBAYAR tetapi belum selesai.
--
-- Latar: fn_auto_inactive_on_session_done() tanda pesakit 'inactive' + pelan 'completed'
-- sebaik semua sesi TERAS (is_extension=false) selesai. Masalah: pesakit continuity dah
-- hadir semua sesi teras, jadi trigger tutup pelan walaupun coach baru tambah minggu
-- sambungan yang belum dihadiri → minggu sambungan jadi yatim.
--
-- Pembeza: minggu continuity ditanda extension_for_week = 0 (coach tambah, bukan ganti absen).
--   - absen  : is_extension=true, extension_for_week >= 1  → kelakuan LAMA kekal (tak menghalang).
--   - continuity: is_extension=true, extension_for_week = 0 → menghalang bila SUDAH DIBAYAR
--     (status <> 'extension_pending_payment') dan belum 'hadir'/'consultation_done'.
--
-- Minggu continuity yang MASIH menunggu bayaran (extension_pending_payment) TIDAK menghalang
-- (pesakit mungkin tak jadi bayar — jangan pegang pesakit tebusan).
--
-- Jalankan di TESTING dahulu, kemudian PRODUCTION (xmvqvq).

CREATE OR REPLACE FUNCTION fn_auto_inactive_on_session_done()
RETURNS TRIGGER AS $$
DECLARE
  v_patient_id   UUID;
  v_pstatus      TEXT;
  v_pkg_expired  BOOLEAN;
  v_all_done     BOOLEAN;
  v_has_core     BOOLEAN;
BEGIN
  IF NEW.status NOT IN ('hadir','consultation_done') THEN
    RETURN NEW;
  END IF;
  IF TG_OP = 'UPDATE' AND OLD.status = NEW.status THEN
    RETURN NEW;
  END IF;

  SELECT patient_id INTO v_patient_id FROM psy_treatment_plans WHERE id = NEW.plan_id;
  IF v_patient_id IS NULL THEN RETURN NEW; END IF;

  -- v_has_core : ada sekurang-kurangnya satu sesi teras.
  -- v_all_done : tiada baris "menghalang" yang belum selesai, iaitu
  --   (a) sesi teras (is_extension=false) yang belum selesai, ATAU
  --   (b) minggu continuity BERBAYAR (extension_for_week = 0, bukan pending bayaran) yang belum selesai.
  SELECT
    EXISTS (SELECT 1 FROM psy_plan_weekly_progress
            WHERE plan_id = NEW.plan_id AND COALESCE(is_extension,false) = false),
    NOT EXISTS (
      SELECT 1 FROM psy_plan_weekly_progress
      WHERE plan_id = NEW.plan_id
        AND status NOT IN ('hadir','consultation_done')
        AND (
          COALESCE(is_extension,false) = false
          OR (COALESCE(extension_for_week, -1) = 0 AND status <> 'extension_pending_payment')
        )
    )
    INTO v_has_core, v_all_done;

  SELECT status, (package_expires_at IS NOT NULL AND package_expires_at < now())
    INTO v_pstatus, v_pkg_expired
    FROM psy_patients WHERE id = v_patient_id;

  IF v_pstatus IN ('inactive','archived','deceased','deleted') THEN
    RETURN NEW;
  END IF;

  IF (v_has_core AND v_all_done) OR v_pkg_expired THEN
    UPDATE psy_patients
      SET status = 'inactive',
          outcome_status = CASE WHEN outcome_status IS NULL OR outcome_status = ''
                                THEN 'completed' ELSE outcome_status END,
          outcome_status_at = CASE WHEN outcome_status IS NULL OR outcome_status = ''
                                   THEN now() ELSE outcome_status_at END
      WHERE id = v_patient_id;
    UPDATE psy_treatment_plans SET status = 'completed'
      WHERE id = NEW.plan_id AND status <> 'completed';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger sedia ada (trg_auto_inactive) terus guna fungsi yang dikemaskini — tak perlu cipta semula.

SELECT 'OK — trigger continuity-aware dipasang (step92)' AS status;
