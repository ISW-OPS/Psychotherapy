-- Red Emergency Protocol — sisi PESAKIT (seksyen "Protokol Kecemasan" di
-- bawah roles/patient/dashboard.html — bukan halaman berasingan).
-- Tambah keupayaan pesakit lapor kecemasan sendiri (butang Call 999/Coach/
-- Keluarga) terus ke worklist psy_emergency_alerts sedia ada (20260722_emergency_alerts.sql),
-- tanpa bagi pesakit akses INSERT/UPDATE terus ke jadual itu (RLS kekal
-- staff-only) — guna RPC SECURITY DEFINER fn_patient_report_emergency().

-- ──── 1) CHECK constraint 'source' — tambah 'patient' (corak PENYESUAI-DIRI,
--         guna nilai sedia ada + senarai wajib, elak gagal macam gotcha
--         psy_notifications_type_check di PROD — rujuk memory) ────
DO $$
DECLARE v_vals TEXT;
BEGIN
  SELECT string_agg(quote_literal(v), ',') INTO v_vals FROM (
    SELECT DISTINCT source AS v FROM psy_emergency_alerts WHERE source IS NOT NULL
    UNION SELECT unnest(ARRAY['auto','manual','patient'])
  ) x;

  EXECUTE 'ALTER TABLE psy_emergency_alerts DROP CONSTRAINT IF EXISTS psy_emergency_alerts_source_check';
  EXECUTE format('ALTER TABLE psy_emergency_alerts ADD CONSTRAINT psy_emergency_alerts_source_check CHECK (source IN (%s))', v_vals);
END $$;

-- ──── 2) Pesakit boleh BACA alert sendiri sahaja (papar status "Coach akan hubungi anda") ────
DROP POLICY IF EXISTS "Patient read own emergency alert" ON psy_emergency_alerts;
CREATE POLICY "Patient read own emergency alert" ON psy_emergency_alerts FOR SELECT
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

-- ──── 3) fn_patient_report_emergency — pesakit tekan butang kecemasan ────
-- Satu alert AKTIF (status <> 'resolved') per pesakit — sama dedup logic
-- dgn trg_reaksi_advice_notify_emergency. Taraf sentiasa naik ke 'merah'
-- (pesakit tekan butang kecemasan = tahap tertinggi), tak pernah turun taraf.
CREATE OR REPLACE FUNCTION fn_patient_report_emergency(p_channel TEXT DEFAULT 'unknown')
RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_patient_id   UUID;
  v_coach_id     UUID;
  v_patient_name TEXT;
  v_open_id      UUID;
  v_alert_id     UUID;
  v_note         TEXT;
BEGIN
  SELECT id, coach_id INTO v_patient_id, v_coach_id FROM psy_patients WHERE user_id = auth.uid() LIMIT 1;
  IF v_patient_id IS NULL THEN
    RAISE EXCEPTION 'Rekod pesakit tidak dijumpai';
  END IF;

  SELECT COALESCE(pr.full_name, pt.full_name, 'Pesakit') INTO v_patient_name
  FROM psy_patients pt LEFT JOIN psy_profiles pr ON pr.id = pt.user_id
  WHERE pt.id = v_patient_id;

  v_note := 'Pesakit tekan butang kecemasan (' || COALESCE(p_channel, 'unknown') || ') pada '
            || to_char(now(), 'DD Mon YYYY HH24:MI');

  SELECT id INTO v_open_id FROM psy_emergency_alerts
  WHERE patient_id = v_patient_id AND status <> 'resolved'
  ORDER BY created_at DESC LIMIT 1;

  IF v_open_id IS NOT NULL THEN
    UPDATE psy_emergency_alerts
    SET zon = 'merah', reported_at = now(), response_target_minutes = 15, updated_at = now(),
        notes = CASE WHEN notes IS NULL OR notes = '' THEN v_note ELSE notes || E'\n' || v_note END
    WHERE id = v_open_id
    RETURNING id INTO v_alert_id;
  ELSE
    INSERT INTO psy_emergency_alerts (patient_id, zon, source, response_target_minutes, assigned_to, notes)
    VALUES (v_patient_id, 'merah', 'patient', 15, v_coach_id, v_note)
    RETURNING id INTO v_alert_id;
  END IF;

  IF v_coach_id IS NOT NULL THEN
    INSERT INTO psy_notifications (user_id, type, title, body, link)
    VALUES (
      v_coach_id, 'reaksi',
      '🚨 Pesakit Tekan Butang Kecemasan: ' || v_patient_name,
      v_patient_name || ' menekan butang kecemasan (' || COALESCE(p_channel, 'unknown') || ') di Protokol Kecemasan. Sila hubungi SEGERA.',
      'emergency.html?patient_id=' || v_patient_id::TEXT
    );
  END IF;

  RETURN v_alert_id;
END;
$$;

GRANT EXECUTE ON FUNCTION fn_patient_report_emergency(TEXT) TO authenticated;

-- Nota: seksyen "Protokol Kecemasan" (roles/patient/dashboard.html, bahagian
-- bawah — asalnya emergency.html berasingan, digabung 22 Jul 2026) tidak
-- didaftar dalam PAGE_PATIENT_MODULE (authGuard.js) — ciri keselamatan mesti
-- sentiasa boleh diakses, sama macam dashboard sendiri, tak tertakluk toggle RBAC.
