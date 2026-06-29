-- ============================================================
-- 20260628_reaksi_notif_order_alert.sql
-- 1. psy_patient_reaksi_reports — patient self-report per week
-- 2. Trigger: notify patient when coach opens new week row
-- 3. Trigger: notify coach when patient submits reaksi
-- 4. Trigger: notify all staff when new order placed
-- ============================================================

-- ── 1. Extend psy_notifications type CHECK to include 'reaksi' ─
DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN
    SELECT conname FROM pg_constraint
    WHERE conrelid = 'psy_notifications'::regclass
      AND contype = 'c'
      AND pg_get_constraintdef(oid) LIKE '%type%'
  LOOP
    EXECUTE 'ALTER TABLE psy_notifications DROP CONSTRAINT ' || quote_ident(r.conname);
  END LOOP;
END $$;
ALTER TABLE psy_notifications ADD CONSTRAINT psy_notifications_type_check
  CHECK (type IN ('appointment','order','plan','system','reaksi','kyc'));

-- ── 2. Patient reaksi reports table ───────────────────────────
CREATE TABLE IF NOT EXISTS psy_patient_reaksi_reports (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id          UUID REFERENCES psy_treatment_plans(id) ON DELETE CASCADE NOT NULL,
  patient_id       UUID REFERENCES psy_patients(id)        ON DELETE CASCADE NOT NULL,
  week_number      INT  NOT NULL,
  reaksi_pemulihan JSONB DEFAULT '{}',
  submitted_at     TIMESTAMPTZ DEFAULT now(),
  updated_at       TIMESTAMPTZ DEFAULT now(),
  UNIQUE (plan_id, patient_id, week_number)
);
ALTER TABLE psy_patient_reaksi_reports ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "Patient select own reaksi" ON psy_patient_reaksi_reports
    FOR SELECT USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "Patient insert own reaksi" ON psy_patient_reaksi_reports
    FOR INSERT WITH CHECK (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "Patient update own reaksi" ON psy_patient_reaksi_reports
    FOR UPDATE USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "Staff read reaksi reports" ON psy_patient_reaksi_reports
    FOR SELECT USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE INDEX IF NOT EXISTS idx_patient_reaksi_plan_week
  ON psy_patient_reaksi_reports(plan_id, patient_id, week_number);

-- ── 3. Trigger: notify patient when new weekly progress row ────
--    (coach adds a new week → patient gets reminder to submit reaksi)
CREATE OR REPLACE FUNCTION trg_notify_patient_new_week()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_user_id UUID;
BEGIN
  SELECT user_id INTO v_user_id FROM psy_patients WHERE id = NEW.patient_id;
  IF v_user_id IS NULL THEN RETURN NEW; END IF;

  -- Deduplicate: one notification per patient per plan+week
  IF EXISTS (
    SELECT 1 FROM psy_notifications
    WHERE user_id = v_user_id
      AND type = 'plan'
      AND link LIKE '%plan_id=' || NEW.plan_id::TEXT || '%week=' || NEW.week_number
    LIMIT 1
  ) THEN RETURN NEW; END IF;

  INSERT INTO psy_notifications (user_id, type, title, body, link)
  VALUES (
    v_user_id, 'plan',
    'Sila Hantar Laporan Reaksi — Minggu ' || NEW.week_number,
    'Minggu ' || NEW.week_number || ' rawatan anda bermula. Rekod simptom reaksi pemulihan yang anda alami.',
    'plan-week.html?plan_id=' || NEW.plan_id::TEXT || '&week=' || NEW.week_number
  );
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE LOG 'trg_notify_patient_new_week: %', SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_patient_new_week ON psy_plan_weekly_progress;
CREATE TRIGGER trg_notify_patient_new_week
  AFTER INSERT ON psy_plan_weekly_progress
  FOR EACH ROW EXECUTE FUNCTION trg_notify_patient_new_week();

-- ── 4. Trigger: notify coach when patient submits reaksi ───────
CREATE OR REPLACE FUNCTION trg_patient_reaksi_notify_coach()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_coach_id    UUID;
  v_patient_name TEXT;
BEGIN
  -- Only on first submission (INSERT), not on updates
  IF TG_OP != 'INSERT' THEN RETURN NEW; END IF;

  SELECT pr.full_name INTO v_patient_name
  FROM psy_patients pt
  JOIN psy_profiles pr ON pr.id = pt.user_id
  WHERE pt.id = NEW.patient_id;

  -- Get coach from psy_patients.coach_id first
  SELECT coach_id INTO v_coach_id FROM psy_patients WHERE id = NEW.patient_id;

  -- Fallback: most recent weekly progress row for this plan
  IF v_coach_id IS NULL THEN
    SELECT coach_id INTO v_coach_id FROM psy_plan_weekly_progress
    WHERE plan_id = NEW.plan_id AND patient_id = NEW.patient_id
    ORDER BY created_at DESC LIMIT 1;
  END IF;

  IF v_coach_id IS NOT NULL THEN
    INSERT INTO psy_notifications (user_id, type, title, body, link)
    VALUES (
      v_coach_id, 'reaksi',
      '🌀 Laporan Reaksi: ' || COALESCE(v_patient_name, 'Pesakit'),
      'Minggu ' || NEW.week_number || ' — ' || COALESCE(v_patient_name, 'Pesakit') || ' telah hantar laporan reaksi pemulihan.',
      'plan-week.html?plan_id=' || NEW.plan_id::TEXT || '&week=' || NEW.week_number
    );
  END IF;
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE LOG 'trg_patient_reaksi_notify_coach: %', SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_patient_reaksi_notify_coach ON psy_patient_reaksi_reports;
CREATE TRIGGER trg_patient_reaksi_notify_coach
  AFTER INSERT ON psy_patient_reaksi_reports
  FOR EACH ROW EXECUTE FUNCTION trg_patient_reaksi_notify_coach();

-- ── 5. Trigger: notify all staff when new order placed ────────
CREATE OR REPLACE FUNCTION trg_notify_staff_new_order()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_patient_name TEXT;
  v_staff        RECORD;
BEGIN
  SELECT full_name INTO v_patient_name FROM psy_profiles WHERE id = NEW.patient_id;

  FOR v_staff IN SELECT id FROM psy_profiles WHERE role = 'staff' LOOP
    INSERT INTO psy_notifications (user_id, type, title, body, link)
    VALUES (
      v_staff.id, 'order',
      '📦 Pesanan Baru: ' || COALESCE(v_patient_name, 'Pesakit'),
      'Pesanan ' || COALESCE(NEW.order_ref, '') || ' diterima. Sila proses penghantaran.',
      'orders.html'
    );
  END LOOP;
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE LOG 'trg_notify_staff_new_order: %', SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_staff_new_order ON psy_orders;
CREATE TRIGGER trg_notify_staff_new_order
  AFTER INSERT ON psy_orders
  FOR EACH ROW EXECUTE FUNCTION trg_notify_staff_new_order();

SELECT 'OK — reaksi reports + order notifications ready' AS status;
