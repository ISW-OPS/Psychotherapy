-- ═══════════════════════════════════════════════════════════════════
-- Fasa 6 — Mission (teras: jadual + enjin, skop MVP)
-- Keputusan terkunci (7 Okt 2026):
--   • mission_type 'daily_checkin' = AUTOMATIK (trigger bila pesakit isi
--     Catatan Harian, psy_kepatuhan_log). Dipilih sebab data bersih &
--     UNIQUE(patient_id, log_date) sedia ada — selamat & tepat.
--   • mission_type 'manual' = pesakit tekan butang sendiri (RPC
--     advance_my_mission), had SEKALI sehari (last_advanced_on).
--   • Attend Session / Medical Checkup / Complete Profile automatik —
--     BELUM dibina dalam v1 ni (perlu hook pada 3 modul berasingan,
--     sengaja ditangguh supaya teras boleh diuji dulu). Staff boleh
--     guna 'manual' buat sementara utk jenis mission ni.
--   • Ganjaran mata TAK auto masuk bila progress cukup — status jadi
--     'completed' dulu, pesakit kena tekan "Tuntut" (claim_mission_reward)
--     sebelum mata masuk psy_points_ledger. Elak duplicate via status guard.
-- ═══════════════════════════════════════════════════════════════════

-- ──── psy_missions ────
CREATE TABLE IF NOT EXISTS psy_missions (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name                  TEXT NOT NULL,
  description           TEXT,
  mission_type          TEXT NOT NULL DEFAULT 'manual' CHECK (mission_type IN ('daily_checkin', 'manual')),
  target                INT NOT NULL DEFAULT 1 CHECK (target > 0),
  reward_points         INT NOT NULL DEFAULT 0 CHECK (reward_points >= 0),
  repeat_cycle          TEXT NOT NULL DEFAULT 'none' CHECK (repeat_cycle IN ('none', 'weekly')),
  customer_eligibility  TEXT NOT NULL DEFAULT 'all' CHECK (customer_eligibility IN ('all', 'new', 'existing')),
  start_date            DATE,
  end_date              DATE,
  is_active             BOOLEAN NOT NULL DEFAULT true,
  created_by            UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  created_at            TIMESTAMPTZ DEFAULT now(),
  updated_at            TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE psy_missions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone read active missions" ON psy_missions;
CREATE POLICY "Anyone read active missions" ON psy_missions FOR SELECT USING (true);

DROP POLICY IF EXISTS "Staff manage missions" ON psy_missions;
CREATE POLICY "Staff manage missions" ON psy_missions
  FOR ALL USING      (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
           WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- ──── psy_mission_progress ────
-- cycle_start: sentinel '2000-01-01' utk mission 'none' (bukan NULL — NULL
-- buat UNIQUE tak boleh percaya, sebab Postgres anggap tiap NULL lain-lain).
-- Utk 'weekly', cycle_start = Isnin minggu bila progress pertama dibuat.
CREATE TABLE IF NOT EXISTS psy_mission_progress (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  mission_id        UUID NOT NULL REFERENCES psy_missions(id) ON DELETE CASCADE,
  patient_id        UUID NOT NULL REFERENCES psy_patients(id) ON DELETE CASCADE,
  cycle_start       DATE NOT NULL DEFAULT '2000-01-01',
  progress          INT NOT NULL DEFAULT 0,
  status            TEXT NOT NULL DEFAULT 'in_progress' CHECK (status IN ('in_progress', 'completed', 'claimed')),
  last_advanced_on  DATE,
  completed_at      TIMESTAMPTZ,
  claimed_at        TIMESTAMPTZ,
  created_at        TIMESTAMPTZ DEFAULT now(),
  updated_at        TIMESTAMPTZ DEFAULT now(),
  UNIQUE (mission_id, patient_id, cycle_start)
);

CREATE INDEX IF NOT EXISTS idx_mission_progress_patient ON psy_mission_progress(patient_id, status);

ALTER TABLE psy_mission_progress ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Patients view own mission progress" ON psy_mission_progress;
CREATE POLICY "Patients view own mission progress" ON psy_mission_progress FOR SELECT
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Staff view all mission progress" ON psy_mission_progress;
CREATE POLICY "Staff view all mission progress" ON psy_mission_progress FOR SELECT
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
-- TIADA INSERT/UPDATE policy pesakit sengaja — semua tulisan lalui
-- advance_my_mission()/claim_mission_reward() (SECURITY DEFINER) atau trigger.

-- ──── advance_my_mission(): pesakit sendiri tekan "selesai hari ini" (mission_type='manual') ────
CREATE OR REPLACE FUNCTION advance_my_mission(p_mission_id UUID)
RETURNS psy_mission_progress
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_patient_id UUID;
  v_mission    psy_missions%ROWTYPE;
  v_cycle      DATE;
  v_row        psy_mission_progress%ROWTYPE;
BEGIN
  SELECT id INTO v_patient_id FROM psy_patients WHERE user_id = auth.uid() LIMIT 1;
  IF v_patient_id IS NULL THEN RAISE EXCEPTION 'Rekod pesakit tidak dijumpai.'; END IF;

  SELECT * INTO v_mission FROM psy_missions WHERE id = p_mission_id;
  IF v_mission.id IS NULL OR NOT v_mission.is_active THEN RAISE EXCEPTION 'Mission tidak sah.'; END IF;
  IF v_mission.mission_type <> 'manual' THEN RAISE EXCEPTION 'Mission ini dikemaskini automatik, bukan secara manual.'; END IF;
  IF v_mission.start_date IS NOT NULL AND CURRENT_DATE < v_mission.start_date THEN RAISE EXCEPTION 'Mission belum bermula.'; END IF;
  IF v_mission.end_date IS NOT NULL AND CURRENT_DATE > v_mission.end_date THEN RAISE EXCEPTION 'Mission sudah tamat.'; END IF;

  v_cycle := CASE WHEN v_mission.repeat_cycle = 'weekly' THEN date_trunc('week', CURRENT_DATE)::date ELSE DATE '2000-01-01' END;

  INSERT INTO psy_mission_progress (mission_id, patient_id, cycle_start)
  VALUES (p_mission_id, v_patient_id, v_cycle)
  ON CONFLICT (mission_id, patient_id, cycle_start) DO NOTHING;

  SELECT * INTO v_row FROM psy_mission_progress
    WHERE mission_id = p_mission_id AND patient_id = v_patient_id AND cycle_start = v_cycle;

  IF v_row.status IN ('completed', 'claimed') THEN RAISE EXCEPTION 'Mission ini sudah selesai untuk tempoh semasa.'; END IF;
  IF v_row.last_advanced_on = CURRENT_DATE THEN RAISE EXCEPTION 'Anda sudah kemaskini mission ini hari ini.'; END IF;

  UPDATE psy_mission_progress SET
    progress = LEAST(v_mission.target, progress + 1),
    last_advanced_on = CURRENT_DATE,
    status = CASE WHEN progress + 1 >= v_mission.target THEN 'completed' ELSE 'in_progress' END,
    completed_at = CASE WHEN progress + 1 >= v_mission.target THEN now() ELSE completed_at END,
    updated_at = now()
  WHERE id = v_row.id
  RETURNING * INTO v_row;

  RETURN v_row;
END;
$$;

GRANT EXECUTE ON FUNCTION advance_my_mission(UUID) TO authenticated;

-- ──── claim_mission_reward(): tuntut mata bila status='completed' ────
CREATE OR REPLACE FUNCTION claim_mission_reward(p_progress_id UUID)
RETURNS psy_mission_progress
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_patient_id UUID;
  v_row        psy_mission_progress%ROWTYPE;
  v_mission    psy_missions%ROWTYPE;
BEGIN
  SELECT id INTO v_patient_id FROM psy_patients WHERE user_id = auth.uid() LIMIT 1;
  IF v_patient_id IS NULL THEN RAISE EXCEPTION 'Rekod pesakit tidak dijumpai.'; END IF;

  SELECT * INTO v_row FROM psy_mission_progress WHERE id = p_progress_id AND patient_id = v_patient_id;
  IF v_row.id IS NULL THEN RAISE EXCEPTION 'Progress mission tidak dijumpai.'; END IF;
  IF v_row.status = 'claimed' THEN RAISE EXCEPTION 'Ganjaran ini sudah dituntut.'; END IF;
  IF v_row.status <> 'completed' THEN RAISE EXCEPTION 'Mission belum selesai.'; END IF;

  SELECT * INTO v_mission FROM psy_missions WHERE id = v_row.mission_id;

  UPDATE psy_mission_progress SET status = 'claimed', claimed_at = now(), updated_at = now()
  WHERE id = p_progress_id RETURNING * INTO v_row;

  IF v_mission.reward_points > 0 THEN
    INSERT INTO psy_points_ledger (patient_id, source_type, source_ref, points, note)
    VALUES (v_patient_id, 'mission_complete', v_row.id, v_mission.reward_points, 'Mission selesai: ' || v_mission.name);
  END IF;

  RETURN v_row;
END;
$$;

GRANT EXECUTE ON FUNCTION claim_mission_reward(UUID) TO authenticated;

-- ──── Trigger automatik: mission_type='daily_checkin' bila Catatan Harian diisi ────
CREATE OR REPLACE FUNCTION trg_advance_daily_checkin_missions()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_mission  RECORD;
  v_cycle    DATE;
  v_has_paid BOOLEAN;
BEGIN
  FOR v_mission IN
    SELECT * FROM psy_missions
    WHERE mission_type = 'daily_checkin' AND is_active
      AND (start_date IS NULL OR start_date <= NEW.log_date)
      AND (end_date IS NULL OR end_date >= NEW.log_date)
  LOOP
    IF v_mission.customer_eligibility IN ('new', 'existing') THEN
      SELECT EXISTS (SELECT 1 FROM psy_payments WHERE patient_id = NEW.patient_id AND status = 'completed') INTO v_has_paid;
      IF v_mission.customer_eligibility = 'new' AND v_has_paid THEN CONTINUE; END IF;
      IF v_mission.customer_eligibility = 'existing' AND NOT v_has_paid THEN CONTINUE; END IF;
    END IF;

    v_cycle := CASE WHEN v_mission.repeat_cycle = 'weekly' THEN date_trunc('week', NEW.log_date)::date ELSE DATE '2000-01-01' END;

    INSERT INTO psy_mission_progress (mission_id, patient_id, cycle_start)
    VALUES (v_mission.id, NEW.patient_id, v_cycle)
    ON CONFLICT (mission_id, patient_id, cycle_start) DO NOTHING;

    UPDATE psy_mission_progress SET
      progress = LEAST(v_mission.target, progress + 1),
      last_advanced_on = NEW.log_date,
      status = CASE WHEN status = 'in_progress' AND progress + 1 >= v_mission.target THEN 'completed' ELSE status END,
      completed_at = CASE WHEN status = 'in_progress' AND progress + 1 >= v_mission.target THEN now() ELSE completed_at END,
      updated_at = now()
    WHERE mission_id = v_mission.id AND patient_id = NEW.patient_id AND cycle_start = v_cycle
      AND status = 'in_progress' AND (last_advanced_on IS DISTINCT FROM NEW.log_date);
  END LOOP;
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE LOG 'trg_advance_daily_checkin_missions: %', SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_advance_daily_checkin_missions ON psy_kepatuhan_log;
CREATE TRIGGER trg_advance_daily_checkin_missions
  AFTER INSERT ON psy_kepatuhan_log
  FOR EACH ROW EXECUTE FUNCTION trg_advance_daily_checkin_missions();
