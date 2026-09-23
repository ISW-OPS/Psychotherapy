-- Audit management 23 Sept 2026, Tier 1 (#B1-40): pesakit Masuk Wad/Hospital/Perlu
-- Lawatan dari kes Red Emergency Protocol perlu auto-link ke Rekod Klinikal Pesakit
-- (Modul Peristiwa Pesakit, sedia ada) — bila rekod klinikal ditutup, kes emergency
-- asal dikemaskini automatik.
-- Rujuk: database/schema/25_patient_events.sql

ALTER TABLE psy_patient_events
  ADD COLUMN IF NOT EXISTS source_emergency_alert_id UUID REFERENCES psy_emergency_alerts(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_pe_source_alert ON psy_patient_events(source_emergency_alert_id) WHERE source_emergency_alert_id IS NOT NULL;

CREATE OR REPLACE FUNCTION trg_patient_event_notify_emergency()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_note TEXT;
BEGIN
  IF NEW.source_emergency_alert_id IS NULL THEN RETURN NEW; END IF;
  IF NOT (NEW.status = 'closed' AND OLD.status <> 'closed') THEN RETURN NEW; END IF;

  v_note := 'Rekod Klinikal Pesakit (' || NEW.event_type || ') ditutup pada ' ||
            to_char(now(), 'DD Mon YYYY HH24:MI') ||
            COALESCE(' — ' || NEW.notes, '') ||
            '. Lihat peristiwa-detail.html?id=' || NEW.id::TEXT;

  UPDATE psy_emergency_alerts
  SET notes = CASE WHEN notes IS NULL OR notes = '' THEN v_note ELSE notes || E'\n' || v_note END,
      updated_at = now()
  WHERE id = NEW.source_emergency_alert_id;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE LOG 'trg_patient_event_notify_emergency: %', SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_patient_event_notify_emergency ON psy_patient_events;
CREATE TRIGGER trg_patient_event_notify_emergency
  AFTER UPDATE ON psy_patient_events
  FOR EACH ROW EXECUTE FUNCTION trg_patient_event_notify_emergency();
