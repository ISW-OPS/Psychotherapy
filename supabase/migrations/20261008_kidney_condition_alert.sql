-- Audit #20 (8 Okt 2026) — notification + banner amaran utk pesakit yang ada
-- masalah buah pinggang/dialisis (kadar peminuman air + larangan suntikan/
-- kolar vena di lengan akses dialisis).
--
-- 1. Kolum baharu psy_patients.has_kidney_condition (BOOLEAN, default false) —
--    ditandakan SECARA EKSPLISIT oleh staf (checkbox di patient-form.html),
--    BUKAN keyword-matching pada medical_condition free-text (terlalu fragile).
-- 2. Trigger AFTER UPDATE ON psy_patients — bila flag ditukar ke true, ATAU
--    coach_id ditukar/diisi utk pesakit yg dah flag true (supaya coach BAHARU
--    pun kena notify "setiap kali DAPAT pesakit"), hantar notify() kpd coach.
-- Idempoten (ADD COLUMN IF NOT EXISTS + CREATE OR REPLACE FUNCTION) — selamat
-- dijalankan berulang kali.

ALTER TABLE psy_patients ADD COLUMN IF NOT EXISTS has_kidney_condition BOOLEAN NOT NULL DEFAULT false;

CREATE OR REPLACE FUNCTION notify_patient_kidney_alert(p_coach_id UUID, p_patient_id UUID, p_patient_name TEXT)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO psy_notifications (user_id, type, title, body, link)
  VALUES (
    p_coach_id,
    'kidney_alert',
    '⚠️ Pesakit Buah Pinggang/Dialisis',
    'Pesakit ' || COALESCE(p_patient_name, 'ini') ||
      ' ada masalah buah pinggang/dialisis — perhatikan kadar peminuman air pesakit ' ||
      '& ELAK penyuntikan/pengambilan darah di lengan yang ada akses dialisis (fistula/kolaps vena).',
    'patient-hub.html?id=' || p_patient_id::TEXT
  );
EXCEPTION WHEN OTHERS THEN
  RAISE LOG 'notify_patient_kidney_alert: %', SQLERRM;
END;
$$;

CREATE OR REPLACE FUNCTION trg_patient_kidney_alert_notify()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_became_flagged BOOLEAN;
  v_coach_changed BOOLEAN;
BEGIN
  v_became_flagged := NEW.has_kidney_condition = true
    AND OLD.has_kidney_condition IS DISTINCT FROM true;
  v_coach_changed := NEW.has_kidney_condition = true
    AND NEW.coach_id IS NOT NULL
    AND NEW.coach_id IS DISTINCT FROM OLD.coach_id;

  IF NOT (v_became_flagged OR v_coach_changed) OR NEW.coach_id IS NULL THEN
    RETURN NEW;
  END IF;

  PERFORM notify_patient_kidney_alert(NEW.coach_id, NEW.id, NEW.full_name);

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE LOG 'trg_patient_kidney_alert_notify: %', SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_patient_kidney_alert_notify ON psy_patients;
CREATE TRIGGER trg_patient_kidney_alert_notify
  AFTER UPDATE ON psy_patients
  FOR EACH ROW EXECUTE FUNCTION trg_patient_kidney_alert_notify();
