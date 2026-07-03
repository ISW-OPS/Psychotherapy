-- step80_auto_inactive_trigger.sql
-- Auto-tandai pesakit "Tidak Aktif" bila SEMUA sesi selesai ATAU pakej tamat tempoh,
-- dicetus bila mana-mana sesi ditanda hadir/consultation_done — TAK KIRA dari UI mana
-- (plan-week, appointments, dashboard, dll). Menggantikan keperluan hook JS di setiap tempat.
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
  -- Hanya bertindak bila status BARU jadi hadir/selesai (dan berubah)
  IF NEW.status NOT IN ('hadir','consultation_done') THEN
    RETURN NEW;
  END IF;
  IF TG_OP = 'UPDATE' AND OLD.status = NEW.status THEN
    RETURN NEW;
  END IF;

  -- Pesakit untuk plan ni
  SELECT patient_id INTO v_patient_id FROM psy_treatment_plans WHERE id = NEW.plan_id;
  IF v_patient_id IS NULL THEN RETURN NEW; END IF;

  -- Semua sesi TERAS (bukan extension) dah selesai?
  SELECT
    EXISTS (SELECT 1 FROM psy_plan_weekly_progress
            WHERE plan_id = NEW.plan_id AND COALESCE(is_extension,false) = false),
    NOT EXISTS (SELECT 1 FROM psy_plan_weekly_progress
                WHERE plan_id = NEW.plan_id AND COALESCE(is_extension,false) = false
                  AND status NOT IN ('hadir','consultation_done'))
    INTO v_has_core, v_all_done;

  -- Status pesakit semasa + pakej tamat tempoh?
  SELECT status, (package_expires_at IS NOT NULL AND package_expires_at < now())
    INTO v_pstatus, v_pkg_expired
    FROM psy_patients WHERE id = v_patient_id;

  -- Sudah tak aktif → jangan ganggu
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

DROP TRIGGER IF EXISTS trg_auto_inactive ON psy_plan_weekly_progress;
CREATE TRIGGER trg_auto_inactive
  AFTER UPDATE ON psy_plan_weekly_progress
  FOR EACH ROW
  EXECUTE FUNCTION fn_auto_inactive_on_session_done();

SELECT 'OK — trigger auto-inactive dipasang' AS status;
