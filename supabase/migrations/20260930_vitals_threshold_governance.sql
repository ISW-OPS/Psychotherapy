-- Audit management batch 3 (29-30 Sept 2026) — Governance ambang vitals.
-- Menggantikan pendekatan lama (20260923_vitals_critical_emergency.sql, TAK PERNAH
-- dijalankan) yang hardcode nombor kritikal terus dalam fungsi SQL tanpa pengesahan
-- doktor. Kini ambang dibaca dari psy_settings.vitals_thresholds (diedit oleh
-- super_admin/doktor di tetapan.html, tab "Ambang Vitals").
--
-- PENTING: critical_min/critical_max SENGAJA null untuk semua vital dalam seed di
-- bawah — automasi Protokol Kecemasan (is_critical → auto-cipta psy_emergency_alerts)
-- TAK AKAN aktif sehingga seseorang isi nilai melalui UI. Migration ni sendiri TIDAK
-- menghidupkan apa-apa automasi baharu.
--
-- Rujuk: database/schema/10_vitals.sql, database/schema/23_settings.sql

-- ═══ 1. Kolum is_critical (belum wujud di prod) ═══
ALTER TABLE psy_vitals ADD COLUMN IF NOT EXISTS is_critical BOOLEAN NOT NULL DEFAULT false;
CREATE INDEX IF NOT EXISTS idx_psy_vitals_abnormal ON psy_vitals(is_abnormal) WHERE is_abnormal = true;

-- ═══ 2. Seed ambang — normal_* sepadan angka client-side sedia ada (tiada perubahan
-- tingkah laku is_abnormal semasa cutover); critical_* kosong sehingga doktor sahkan ═══
INSERT INTO psy_settings (key, value) VALUES
  ('vitals_thresholds', '{
    "bp_systolic":      {"normal_min": 90,   "normal_max": 129,  "critical_min": null, "critical_max": null},
    "bp_diastolic":      {"normal_min": 60,   "normal_max": 84,   "critical_min": null, "critical_max": null},
    "heart_rate":        {"normal_min": 60,   "normal_max": 100,  "critical_min": null, "critical_max": null},
    "temperature":       {"normal_min": 36.1, "normal_max": 37.2, "critical_min": null, "critical_max": null},
    "spo2":              {"normal_min": 95,   "normal_max": null, "critical_min": null, "critical_max": null},
    "respiratory_rate":  {"normal_min": 12,   "normal_max": 20,   "critical_min": null, "critical_max": null}
  }'::jsonb)
ON CONFLICT (key) DO NOTHING;

-- ═══ 3. fn_vitals_compute_critical() — config-driven, exception-safe sepenuhnya
-- (BEFORE trigger; kalau throw, ia boleh sekat SEMUA simpanan vitals klinik) ═══
CREATE OR REPLACE FUNCTION fn_vitals_compute_critical()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
  v_cfg JSONB;
  v_bp_sys JSONB; v_bp_dia JSONB; v_hr JSONB; v_temp JSONB; v_spo2 JSONB; v_rr JSONB;
BEGIN
  NEW.is_critical := false;

  BEGIN
    SELECT value INTO v_cfg FROM psy_settings WHERE key = 'vitals_thresholds';
  EXCEPTION WHEN OTHERS THEN
    v_cfg := NULL;
  END;

  IF v_cfg IS NULL THEN
    RETURN NEW;
  END IF;

  BEGIN
    v_bp_sys := v_cfg -> 'bp_systolic';
    v_bp_dia := v_cfg -> 'bp_diastolic';
    v_hr     := v_cfg -> 'heart_rate';
    v_temp   := v_cfg -> 'temperature';
    v_spo2   := v_cfg -> 'spo2';
    v_rr     := v_cfg -> 'respiratory_rate';

    NEW.is_critical := (
      (NEW.bp_systolic IS NOT NULL AND v_bp_sys IS NOT NULL AND (
        (v_bp_sys->>'critical_min' IS NOT NULL AND NEW.bp_systolic < (v_bp_sys->>'critical_min')::numeric) OR
        (v_bp_sys->>'critical_max' IS NOT NULL AND NEW.bp_systolic >= (v_bp_sys->>'critical_max')::numeric)
      )) OR
      (NEW.bp_diastolic IS NOT NULL AND v_bp_dia IS NOT NULL AND (
        (v_bp_dia->>'critical_min' IS NOT NULL AND NEW.bp_diastolic < (v_bp_dia->>'critical_min')::numeric) OR
        (v_bp_dia->>'critical_max' IS NOT NULL AND NEW.bp_diastolic >= (v_bp_dia->>'critical_max')::numeric)
      )) OR
      (NEW.heart_rate IS NOT NULL AND v_hr IS NOT NULL AND (
        (v_hr->>'critical_min' IS NOT NULL AND NEW.heart_rate < (v_hr->>'critical_min')::numeric) OR
        (v_hr->>'critical_max' IS NOT NULL AND NEW.heart_rate > (v_hr->>'critical_max')::numeric)
      )) OR
      (NEW.temperature IS NOT NULL AND v_temp IS NOT NULL AND (
        (v_temp->>'critical_min' IS NOT NULL AND NEW.temperature < (v_temp->>'critical_min')::numeric) OR
        (v_temp->>'critical_max' IS NOT NULL AND NEW.temperature >= (v_temp->>'critical_max')::numeric)
      )) OR
      (NEW.spo2 IS NOT NULL AND v_spo2 IS NOT NULL AND
        (v_spo2->>'critical_min' IS NOT NULL AND NEW.spo2 < (v_spo2->>'critical_min')::numeric)
      ) OR
      (NEW.respiratory_rate IS NOT NULL AND v_rr IS NOT NULL AND (
        (v_rr->>'critical_min' IS NOT NULL AND NEW.respiratory_rate < (v_rr->>'critical_min')::numeric) OR
        (v_rr->>'critical_max' IS NOT NULL AND NEW.respiratory_rate > (v_rr->>'critical_max')::numeric)
      ))
    );
  EXCEPTION WHEN OTHERS THEN
    RAISE LOG 'fn_vitals_compute_critical: %', SQLERRM;
    NEW.is_critical := false;
  END;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_vitals_compute_critical ON psy_vitals;
CREATE TRIGGER trg_vitals_compute_critical
  BEFORE INSERT OR UPDATE ON psy_vitals
  FOR EACH ROW EXECUTE FUNCTION fn_vitals_compute_critical();

-- TIADA backfill is_critical — config critical_* kosong (NULL) secara default, jadi
-- backfill akan sentiasa false utk semua rekod sedia ada sehingga doktor isi ambang.

COMMENT ON COLUMN psy_vitals.is_critical IS
  'Bacaan kritikal (bahaya klinikal, perlu tindakan segera) — dikira SERVER-SIDE sahaja '
  '(trg_vitals_compute_critical), staf TAK boleh override/uncheck macam is_abnormal. Bila true, '
  'trg_vitals_notify_emergency (18_notifications_automations.sql) auto-cipta/kemaskini kes di '
  'psy_emergency_alerts — Red Emergency Protocol. Ambang dibaca dari psy_settings.vitals_thresholds '
  '(diedit oleh super_admin/doktor di tetapan.html) — kosong (NULL) = automasi TAK aktif utk vital tu.';
