-- Audit management 23 Sept 2026, Tier 1 (#B1-2, #B2-10, #B2-14, #B2-15): bacaan Vitals
-- kritikal perlu auto-masuk Red Emergency Protocol, bukan bergantung staf buka modul
-- Vitals. is_critical dikira SERVER-SIDE sahaja (trigger) supaya tak bergantung mana-mana
-- laluan insert (patient-hub.html / plan-week.html / vitals-detail.html) betul-betul set
-- ia, dan staf tak boleh terlupa/uncheck.
--
-- PENTING: ambang KRITIKAL di fn_vitals_compute_critical() di bawah ialah piawai am
-- industri, BELUM disahkan oleh doktor/klinikal ISW. Sila semak & minta pengesahan
-- sebelum jalankan migration ni di prod. Boleh tukar ambang lepas run — CREATE OR REPLACE
-- FUNCTION selamat dijalankan semula.
--
-- Rujuk: database/schema/10_vitals.sql, database/schema/18_notifications_automations.sql

-- 1) Kolum baharu
ALTER TABLE psy_vitals ADD COLUMN IF NOT EXISTS is_critical BOOLEAN NOT NULL DEFAULT false;

-- 2) Fungsi + trigger kira is_critical server-side (BEFORE INSERT/UPDATE)
CREATE OR REPLACE FUNCTION fn_vitals_compute_critical()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.is_critical := (
    (NEW.bp_systolic IS NOT NULL AND (NEW.bp_systolic < 80 OR NEW.bp_systolic >= 180)) OR
    (NEW.bp_diastolic IS NOT NULL AND NEW.bp_diastolic >= 120) OR
    (NEW.heart_rate IS NOT NULL AND (NEW.heart_rate < 40 OR NEW.heart_rate > 130)) OR
    (NEW.temperature IS NOT NULL AND (NEW.temperature < 35.0 OR NEW.temperature >= 39.5)) OR
    (NEW.spo2 IS NOT NULL AND NEW.spo2 < 90) OR
    (NEW.respiratory_rate IS NOT NULL AND (NEW.respiratory_rate < 8 OR NEW.respiratory_rate > 30))
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_vitals_compute_critical ON psy_vitals;
CREATE TRIGGER trg_vitals_compute_critical
  BEFORE INSERT OR UPDATE ON psy_vitals
  FOR EACH ROW EXECUTE FUNCTION fn_vitals_compute_critical();

-- 3) Backfill sekali sahaja utk rekod sedia ada
UPDATE psy_vitals SET is_critical = (
  (bp_systolic IS NOT NULL AND (bp_systolic < 80 OR bp_systolic >= 180)) OR
  (bp_diastolic IS NOT NULL AND bp_diastolic >= 120) OR
  (heart_rate IS NOT NULL AND (heart_rate < 40 OR heart_rate > 130)) OR
  (temperature IS NOT NULL AND (temperature < 35.0 OR temperature >= 39.5)) OR
  (spo2 IS NOT NULL AND spo2 < 90) OR
  (respiratory_rate IS NOT NULL AND (respiratory_rate < 8 OR respiratory_rate > 30))
) WHERE is_critical = false;

-- 4) Lanjutkan psy_emergency_alerts.source terima 'vitals' (DROP dulu, sebelum data
--    baharu cuba masuk — ikut gotcha migration constraint order sedia ada)
ALTER TABLE psy_emergency_alerts DROP CONSTRAINT IF EXISTS psy_emergency_alerts_source_check;
ALTER TABLE psy_emergency_alerts ADD CONSTRAINT psy_emergency_alerts_source_check
  CHECK (source IN ('auto','manual','patient','vitals'));

-- 5) Fungsi + trigger: bacaan kritikal → auto-cipta/kemaskini kes psy_emergency_alerts
CREATE OR REPLACE FUNCTION trg_vitals_notify_emergency()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_coach_id     UUID;
  v_patient_name TEXT;
  v_open_id      UUID;
  v_reason       TEXT;
BEGIN
  IF NOT NEW.is_critical THEN RETURN NEW; END IF;

  SELECT pt.coach_id, COALESCE(pr.full_name, pt.full_name, 'Pesakit')
    INTO v_coach_id, v_patient_name
  FROM psy_patients pt
  LEFT JOIN psy_profiles pr ON pr.id = pt.user_id
  WHERE pt.id = NEW.patient_id;
  IF v_coach_id IS NULL THEN RETURN NEW; END IF;

  v_reason := 'Bacaan Vitals kritikal: ' || COALESCE(NULLIF(concat_ws(', ',
    CASE WHEN NEW.bp_systolic IS NOT NULL AND (NEW.bp_systolic < 80 OR NEW.bp_systolic >= 180)
      THEN 'BP ' || NEW.bp_systolic || '/' || COALESCE(NEW.bp_diastolic::TEXT, '—') END,
    CASE WHEN NEW.bp_diastolic IS NOT NULL AND NEW.bp_diastolic >= 120
      THEN 'BP diastolik ' || NEW.bp_diastolic END,
    CASE WHEN NEW.heart_rate IS NOT NULL AND (NEW.heart_rate < 40 OR NEW.heart_rate > 130)
      THEN 'Nadi ' || NEW.heart_rate || ' bpm' END,
    CASE WHEN NEW.temperature IS NOT NULL AND (NEW.temperature < 35.0 OR NEW.temperature >= 39.5)
      THEN 'Suhu ' || NEW.temperature || '°C' END,
    CASE WHEN NEW.spo2 IS NOT NULL AND NEW.spo2 < 90
      THEN 'SpO2 ' || NEW.spo2 || '%' END,
    CASE WHEN NEW.respiratory_rate IS NOT NULL AND (NEW.respiratory_rate < 8 OR NEW.respiratory_rate > 30)
      THEN 'RR ' || NEW.respiratory_rate || '/min' END
  ), ''), 'ambang kritikal');

  INSERT INTO psy_notifications (user_id, type, title, body, link)
  VALUES (
    v_coach_id, 'vitals',
    '🔴 BACAAN KRITIKAL: ' || v_patient_name,
    v_reason || ' — sila susul SEGERA.',
    'emergency.html?patient_id=' || NEW.patient_id::TEXT
  );

  SELECT id INTO v_open_id FROM psy_emergency_alerts
  WHERE patient_id = NEW.patient_id AND status <> 'resolved'
  ORDER BY created_at DESC LIMIT 1;

  IF v_open_id IS NOT NULL THEN
    UPDATE psy_emergency_alerts
    SET zon = 'merah', reported_at = now(), response_target_minutes = 15, updated_at = now(),
        notes = CASE WHEN notes IS NULL OR notes = '' THEN v_reason ELSE notes || E'\n' || v_reason END
    WHERE id = v_open_id;
  ELSE
    INSERT INTO psy_emergency_alerts
      (patient_id, zon, source, response_target_minutes, assigned_to, notes)
    VALUES
      (NEW.patient_id, 'merah', 'vitals', 15, v_coach_id, v_reason);
  END IF;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE LOG 'trg_vitals_notify_emergency: %', SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_vitals_notify_emergency ON psy_vitals;
CREATE TRIGGER trg_vitals_notify_emergency
  AFTER INSERT ON psy_vitals
  FOR EACH ROW EXECUTE FUNCTION trg_vitals_notify_emergency();
