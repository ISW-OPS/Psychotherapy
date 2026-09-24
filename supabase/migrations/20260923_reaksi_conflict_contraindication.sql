-- Audit management 23 Sept 2026, Tier 1 (#B2-2 conflict-check, #B2-3 contraindication).
-- Rujuk: database/schema/12_reaksi.sql

-- #B2-2 — status 'needs_review' utk saranan yang tergantung sbb >1 reaksi
-- triggered serentak (conflict-check). Cron reaksi-advice-send cuma proses
-- status='draft', jadi 'needs_review' auto tak terhantar sehingga staf Lulus/Skip.
ALTER TABLE psy_reaksi_advice_log DROP CONSTRAINT IF EXISTS psy_reaksi_advice_log_status_check;
ALTER TABLE psy_reaksi_advice_log ADD CONSTRAINT psy_reaksi_advice_log_status_check
  CHECK (status IN ('draft','sent','skipped','needs_review'));

-- #B2-3 — kata kunci contraindication (padan drpd psy_patients.medical_condition)
ALTER TABLE psy_reaksi_actions ADD COLUMN IF NOT EXISTS contraindication_keywords TEXT;

-- #B2-39/#B2-45 — status semakan (Draft/Reviewed/Approved/Active). DEFAULT 'active'
-- supaya rekod sedia ada tak terjejas; kod baharu (import/drawer) set 'draft' eksplisit.
ALTER TABLE psy_reaksi_actions ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'active';
ALTER TABLE psy_reaksi_actions DROP CONSTRAINT IF EXISTS psy_reaksi_actions_status_check;
ALTER TABLE psy_reaksi_actions ADD CONSTRAINT psy_reaksi_actions_status_check
  CHECK (status IN ('draft','reviewed','approved','active'));

-- #B2-2 — notify coach bila baris 'needs_review' dicipta (patient client tak boleh
-- INSERT terus ke psy_notifications, RLS staff-only)
CREATE OR REPLACE FUNCTION trg_reaksi_advice_notify_review()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_coach_id     UUID;
  v_patient_name TEXT;
BEGIN
  IF NEW.status <> 'needs_review' THEN RETURN NEW; END IF;
  IF NOT (NEW.send_after IS NULL OR NEW.send_after <= NEW.created_at + interval '2 minutes') THEN RETURN NEW; END IF;

  SELECT pt.coach_id, COALESCE(pr.full_name, pt.full_name, 'Pesakit')
    INTO v_coach_id, v_patient_name
  FROM psy_patients pt
  LEFT JOIN psy_profiles pr ON pr.id = pt.user_id
  WHERE pt.id = NEW.patient_id;
  IF v_coach_id IS NULL THEN RETURN NEW; END IF;

  INSERT INTO psy_notifications (user_id, type, title, body, link)
  VALUES (
    v_coach_id, 'reaksi',
    '⚠️ Cadangan Perlu Disemak: ' || v_patient_name,
    v_patient_name || ' alami beberapa reaksi serentak — cadangan digenerate TAPI belum dihantar sehingga disemak. Sila semak di reaksi-laporan.html.',
    'reaksi-laporan.html'
  );

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE LOG 'trg_reaksi_advice_notify_review: %', SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_reaksi_advice_notify_review ON psy_reaksi_advice_log;
CREATE TRIGGER trg_reaksi_advice_notify_review
  AFTER INSERT ON psy_reaksi_advice_log
  FOR EACH ROW EXECUTE FUNCTION trg_reaksi_advice_notify_review();
