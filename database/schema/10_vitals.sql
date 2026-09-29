-- ═══════════════════════════════════════════════════════════════════
-- SKEMA: VITALS (Bacaan Klinikal Pesakit)
-- Jadual: psy_vitals
-- Bacaan vital (BP, HR, SpO2, berat, gula, HbA1c dll.) direkod oleh
-- staff di klinik atau oleh pesakit sendiri; boleh diikat pada plan
-- rawatan + minggu, dengan tarikh & masa bacaan (berbilang sehari).
-- ═══════════════════════════════════════════════════════════════════

-- ──── psy_vitals ────
CREATE TABLE IF NOT EXISTS psy_vitals (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id       UUID REFERENCES psy_patients(id) ON DELETE CASCADE NOT NULL,
  recorded_by      UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  recorded_by_name TEXT,
  bp_systolic      INT,
  bp_diastolic     INT,
  heart_rate       INT,
  spo2             NUMERIC(5,2),
  temperature      NUMERIC(4,1),
  weight           NUMERIC(5,2),
  height           NUMERIC(5,1),
  bmi              NUMERIC(4,1),
  waist_cm         NUMERIC(5,1),
  rbs              NUMERIC(6,2),
  hba1c            NUMERIC(4,2),
  phq2_score       INT,
  medications      TEXT,
  notes            TEXT,
  source           TEXT NOT NULL DEFAULT 'staff' CHECK (source IN ('staff','patient_self')),
  plan_id          UUID REFERENCES psy_treatment_plans(id) ON DELETE SET NULL,
  week_number      INT,
  reading_date     DATE,
  reading_time     TIME,
  created_at       TIMESTAMPTZ DEFAULT now()
);

-- Medan tambahan (dashboard Vitals — resp rate, pain score, penanda tidak normal)
ALTER TABLE psy_vitals ADD COLUMN IF NOT EXISTS respiratory_rate INT;
ALTER TABLE psy_vitals ADD COLUMN IF NOT EXISTS pain_score INT CHECK (pain_score BETWEEN 0 AND 10);
ALTER TABLE psy_vitals ADD COLUMN IF NOT EXISTS is_abnormal BOOLEAN NOT NULL DEFAULT false;

-- Kritikal (bahaya klinikal, perlu tindakan segera) — tahap lebih ketat drpd
-- "Tidak Normal" (is_abnormal) di atas. Dikira SERVER-SIDE SAHAJA (trigger di bawah),
-- tak boleh diubah/dipintas oleh client — supaya bacaan kritikal SENTIASA dikesan
-- tanpa bergantung laluan insert (patient-hub.html/plan-week.html/vitals-detail.html)
-- atau staf lupa tanda. Bila true, auto-cipta/kemaskini kes di Red Emergency
-- Protocol (psy_emergency_alerts) — lihat trg_vitals_notify_emergency di
-- 18_notifications_automations.sql.
ALTER TABLE psy_vitals ADD COLUMN IF NOT EXISTS is_critical BOOLEAN NOT NULL DEFAULT false;

-- Indeks
CREATE INDEX IF NOT EXISTS idx_psy_vitals_patient ON psy_vitals(patient_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_vitals_plan_week
  ON psy_vitals(plan_id, week_number) WHERE plan_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_psy_vitals_abnormal ON psy_vitals(is_abnormal) WHERE is_abnormal = true;
CREATE INDEX IF NOT EXISTS idx_psy_vitals_reading_date ON psy_vitals(reading_date DESC);

-- Backfill sekali sahaja: tandakan rekod sedia ada yang sudah melepasi ambang klinikal
-- biasa sebagai tidak normal, supaya statistik dashboard tak bermula 0 selepas migrate.
UPDATE psy_vitals SET is_abnormal = true WHERE is_abnormal = false AND (
  (bp_systolic IS NOT NULL AND (bp_systolic < 90 OR bp_systolic >= 130)) OR
  (bp_diastolic IS NOT NULL AND (bp_diastolic < 60 OR bp_diastolic >= 85)) OR
  (heart_rate IS NOT NULL AND (heart_rate < 60 OR heart_rate > 100)) OR
  (temperature IS NOT NULL AND (temperature < 36.1 OR temperature > 37.2)) OR
  (spo2 IS NOT NULL AND spo2 < 95)
);

-- ──── Ambang KRITIKAL — dikira server-side, elak client pintas/lupa tanda ────
-- Audit management batch 3 (29-30 Sept 2026): ambang BUKAN lagi hardcode di sini —
-- dibaca dari psy_settings key 'vitals_thresholds' (JSONB per-vital, diedit oleh
-- super_admin/doktor melalui tetapan.html, rujuk 23_settings.sql). critical_min/
-- critical_max kosong (NULL) utk sesuatu vital = automasi TAK aktif utk vital tu
-- (NULL dlm OR chain = falsy automatik) — jadi shipping fungsi ni TIDAK sendiri
-- menghidupkan apa-apa automasi baharu sehingga seseorang isi nilai melalui UI.
-- Dibalut exception-safe SEPENUHNYA (config rosak/parse gagal → is_critical=false)
-- sebab ni BEFORE trigger — kalau throw, ia boleh sekat SEMUA simpanan vitals klinik.
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

-- RLS
ALTER TABLE psy_vitals ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff manage vitals" ON psy_vitals;
CREATE POLICY "Staff manage vitals" ON psy_vitals FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "Patients read own vitals" ON psy_vitals;
CREATE POLICY "Patients read own vitals" ON psy_vitals FOR SELECT
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

-- Pesakit hanya boleh masuk/edit bacaan sendiri (source = patient_self)
DROP POLICY IF EXISTS "Patients insert own vitals" ON psy_vitals;
CREATE POLICY "Patients insert own vitals" ON psy_vitals FOR INSERT
  WITH CHECK (
    source = 'patient_self'
    AND patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid())
  );

DROP POLICY IF EXISTS "Patients update own vitals" ON psy_vitals;
CREATE POLICY "Patients update own vitals" ON psy_vitals FOR UPDATE
  USING (
    source = 'patient_self'
    AND patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid())
  )
  WITH CHECK (
    source = 'patient_self'
    AND patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid())
  );

-- Komen
COMMENT ON COLUMN psy_vitals.hba1c IS 'HbA1c % (e.g. 6.5 = 6.5%)';
COMMENT ON COLUMN psy_vitals.source IS 'Who entered the reading: staff at clinic, or patient self-reported';
COMMENT ON COLUMN psy_vitals.reading_date IS 'Date the reading was actually taken (may differ from created_at for back-dated entries)';
COMMENT ON COLUMN psy_vitals.plan_id IS
  'Refer treatment plan masa vitals direkod. NULL kalau direkod luar konteks plan.';
COMMENT ON COLUMN psy_vitals.week_number IS
  'Minggu rawatan ke berapa bila vitals direkod. NULL kalau tiada plan aktif.';
COMMENT ON COLUMN psy_vitals.reading_time IS
  'Masa bacaan (HH:MM). Staff boleh rekod beberapa bacaan sehari — masa bezakan setiap satu.';
COMMENT ON COLUMN psy_vitals.respiratory_rate IS 'Kadar pernafasan (nafas/minit).';
COMMENT ON COLUMN psy_vitals.pain_score IS 'Skor kesakitan pesakit, 0 (tiada) hingga 10 (teruk). Pilihan, boleh NULL.';
COMMENT ON COLUMN psy_vitals.is_abnormal IS
  'Dikira semasa simpan (ambang klinikal BP/HR/suhu/SpO2/resp rate) ATAU ditanda manual oleh staff. '
  'Disimpan (bukan dikira semula tiap kali) supaya statistik dashboard Vitals murah untuk query.';

COMMENT ON COLUMN psy_vitals.is_critical IS
  'Bacaan kritikal (bahaya klinikal, perlu tindakan segera) — dikira SERVER-SIDE sahaja '
  '(trg_vitals_compute_critical), staf TAK boleh override/uncheck macam is_abnormal. Bila true, '
  'trg_vitals_notify_emergency (18_notifications_automations.sql) auto-cipta/kemaskini kes di '
  'psy_emergency_alerts — Red Emergency Protocol. Ambang dibaca dari psy_settings.vitals_thresholds '
  '(diedit oleh super_admin/doktor di tetapan.html) — kosong (NULL) = automasi TAK aktif utk vital tu.';
