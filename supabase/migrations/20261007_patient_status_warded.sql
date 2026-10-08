-- ═══════════════════════════════════════════════════════════════════
-- Audit management #124 (7 Okt 2026) — Rekod Klinikal Pesakit auto-create
--
-- 1. Tambah status baharu 'warded' (Masuk Wad/Hospital) ke psy_patients.status.
-- 2. Lindungi status 'warded' drpd ditimpa semula oleh automasi auto-inactive
--    sedia ada (fn_auto_inactive_on_session_done) bila sesi lama ditanda selesai.
-- 3. Trigger baharu: bila status psy_patients bertukar KE 'warded', auto-cipta
--    satu psy_patient_events (event_type='warded') + auto-assign lawatan kepada
--    coach pesakit (assigned_to = coach_id) — tanpa staf perlu klik butang/link
--    berasingan ke peristiwa-baru.html lagi.
--
-- Selamat dijalankan berulang kali (idempotent).
-- ═══════════════════════════════════════════════════════════════════

-- ──── 1. CHECK constraint psy_patients.status — tambah 'warded' ────
ALTER TABLE psy_patients DROP CONSTRAINT IF EXISTS psy_patients_status_check;
ALTER TABLE psy_patients ADD CONSTRAINT psy_patients_status_check CHECK (status IN (
  'pending_kyc','active','inactive','rejected','deleted',
  'unregistered','archived','deceased','warded'
));

-- ──── 2. fn_auto_inactive_on_session_done — jangan timpa status 'warded' ────
-- (Takrifan sebenar yg aktif di DB — definisi di 07_treatment_plans.sql yg
-- CREATE OR REPLACE paling akhir pada fungsi ni; disalin sini supaya migration
-- berdiri sendiri.)
CREATE OR REPLACE FUNCTION fn_auto_inactive_on_session_done()
RETURNS TRIGGER AS $$
DECLARE
  v_patient_id    UUID;
  v_pstatus       TEXT;
  v_pkg_expired   BOOLEAN;
  v_all_done      BOOLEAN;
  v_has_core      BOOLEAN;
  v_next_pkg      TEXT;
  v_next_name     TEXT;
BEGIN
  IF NEW.status NOT IN ('hadir','consultation_done') THEN
    RETURN NEW;
  END IF;
  IF TG_OP = 'UPDATE' AND OLD.status = NEW.status THEN
    RETURN NEW;
  END IF;

  SELECT patient_id INTO v_patient_id FROM psy_treatment_plans WHERE id = NEW.plan_id;
  IF v_patient_id IS NULL THEN RETURN NEW; END IF;

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

  SELECT status, (package_expires_at IS NOT NULL AND package_expires_at < now()),
         next_package_id, next_package_name
    INTO v_pstatus, v_pkg_expired, v_next_pkg, v_next_name
    FROM psy_patients WHERE id = v_patient_id;

  -- 'warded' ditambah 7 Okt 2026 (audit #124) — pesakit masuk wad TIDAK boleh
  -- ditimpa balik ke 'inactive' oleh automasi ni semata kerana sesi lama ditanda
  -- selesai; status klinikal 'warded' dikawal oleh modul Rekod Klinikal Pesakit.
  IF v_pstatus IN ('inactive','archived','deceased','deleted','warded') THEN
    RETURN NEW;
  END IF;

  IF (v_has_core AND v_all_done) OR v_pkg_expired THEN
    UPDATE psy_treatment_plans SET status = 'completed'
      WHERE id = NEW.plan_id AND status <> 'completed';

    IF v_next_pkg IS NOT NULL AND v_next_pkg <> '' THEN
      UPDATE psy_patients
        SET active_package_id    = v_next_pkg,
            active_package_name  = COALESCE(v_next_name, active_package_name),
            package_purchased_at = now(),
            package_expires_at   = now() + interval '3 months',
            next_package_id      = NULL,
            next_package_name    = NULL,
            status               = 'active'
        WHERE id = v_patient_id;

      UPDATE psy_package_purchases
        SET status = 'active', expires_at = now() + interval '3 months'
        WHERE patient_id = v_patient_id AND package_id = v_next_pkg AND status = 'queued';

      BEGIN
        INSERT INTO psy_treatment_plans
          (patient_id, name, template, duration_unit, duration_weeks, current_week, coaching_schedule, status)
        SELECT v_patient_id, COALESCE(pk.name,'Pakej') || ' Treatment Plan', pk.package_id,
               COALESCE(pk.duration_unit,'week'), COALESCE(pk.duration_weeks,12), 1,
               COALESCE(pk.coaching_schedule, '[]'::jsonb), 'active'
        FROM psy_packages pk
        WHERE pk.package_id = v_next_pkg
          AND NOT EXISTS (
            SELECT 1 FROM psy_treatment_plans
            WHERE patient_id = v_patient_id AND template = v_next_pkg AND status = 'active'
          );
      EXCEPTION WHEN unique_violation THEN
        NULL;
      END;
    ELSE
      UPDATE psy_patients
        SET status = 'inactive',
            outcome_status = CASE WHEN outcome_status IS NULL OR outcome_status = ''
                                  THEN 'completed' ELSE outcome_status END,
            outcome_status_at = CASE WHEN outcome_status IS NULL OR outcome_status = ''
                                     THEN now() ELSE outcome_status_at END
        WHERE id = v_patient_id;
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ──── 3. Trigger: auto-cipta Rekod Klinikal Pesakit bila status → 'warded' ────
CREATE OR REPLACE FUNCTION trg_patient_warded_auto_event()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NEW.status <> 'warded' OR OLD.status IS NOT DISTINCT FROM 'warded' THEN
    RETURN NEW;
  END IF;

  IF EXISTS (
    SELECT 1 FROM psy_patient_events
    WHERE patient_id = NEW.id AND event_type = 'warded' AND status = 'open'
  ) THEN
    RETURN NEW;
  END IF;

  INSERT INTO psy_patient_events (
    patient_id, event_type, priority, status, event_date,
    need_visit, visit_priority, assigned_to, notify_roles, notes, reported_by
  ) VALUES (
    NEW.id, 'warded', 'high', 'open', CURRENT_DATE,
    true, 'high', NEW.coach_id, '["manager","coach"]'::jsonb,
    'Rekod dicipta automatik — status pesakit ditukar ke Warded (Masuk Wad/Hospital).',
    NULL
  );

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE LOG 'trg_patient_warded_auto_event: %', SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_patient_warded_auto_event ON psy_patients;
CREATE TRIGGER trg_patient_warded_auto_event
  AFTER UPDATE ON psy_patients
  FOR EACH ROW EXECUTE FUNCTION trg_patient_warded_auto_event();
