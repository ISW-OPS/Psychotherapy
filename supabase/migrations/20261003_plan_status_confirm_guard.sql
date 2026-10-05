-- Audit management (Pelan Mingguan — Status Sesi): elak satu sesi bercanggah
-- (cth "Tidak Hadir"/dijadual-semula TAPI masih bertanda "Disahkan" pesakit).
-- Pengesahan (patient_confirmed) ditulis oleh fungsi berasingan drpd status
-- (markConfirmed di kehadiran.html vs markStatus/appointments.html/dashboard.html
-- yg semuanya tulis terus ke jadual ni) — jadi guard diletak di trigger, bukan
-- disemak berulang kali di setiap laluan JS.
-- Rujuk: database/schema/07_treatment_plans.sql

CREATE OR REPLACE FUNCTION fn_clear_confirm_on_status_change()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status IN ('cancel','reschedule') AND NEW.status IS DISTINCT FROM OLD.status THEN
    NEW.patient_confirmed := NULL;
    NEW.patient_confirmed_at := NULL;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_clear_confirm_on_status_change ON psy_plan_weekly_progress;

CREATE TRIGGER trg_clear_confirm_on_status_change
  BEFORE UPDATE ON psy_plan_weekly_progress
  FOR EACH ROW
  EXECUTE FUNCTION fn_clear_confirm_on_status_change();
