-- Sistem Mata (points) — psy_points_ledger + psy_point_rewards + redeem_point_reward() RPC
-- + trigger 1 mata/hari Catatan Harian. Rujuk: database/schema/31_points.sql

CREATE TABLE IF NOT EXISTS psy_points_ledger (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id   UUID NOT NULL REFERENCES psy_patients(id) ON DELETE CASCADE,
  source_type  TEXT NOT NULL,
  source_ref   UUID,
  points       INT NOT NULL CHECK (points <> 0),
  note         TEXT,
  created_at   TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_psy_points_ledger_patient ON psy_points_ledger(patient_id, created_at);

ALTER TABLE psy_points_ledger ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Patients view own points" ON psy_points_ledger;
CREATE POLICY "Patients view own points" ON psy_points_ledger FOR SELECT
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Staff view all points" ON psy_points_ledger;
CREATE POLICY "Staff view all points" ON psy_points_ledger FOR SELECT
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

CREATE OR REPLACE VIEW psy_points_balance
  WITH (security_invoker = true) AS
  SELECT patient_id, COALESCE(SUM(points), 0)::INT AS balance
  FROM psy_points_ledger
  GROUP BY patient_id;

CREATE OR REPLACE FUNCTION trg_award_daily_checkin_point()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  INSERT INTO psy_points_ledger (patient_id, source_type, source_ref, points, note)
  VALUES (NEW.patient_id, 'daily_checkin', NEW.id, 1, 'Catatan Harian — ' || NEW.log_date);
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE LOG 'trg_award_daily_checkin_point: %', SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_award_daily_checkin_point ON psy_kepatuhan_log;
CREATE TRIGGER trg_award_daily_checkin_point
  AFTER INSERT ON psy_kepatuhan_log
  FOR EACH ROW EXECUTE FUNCTION trg_award_daily_checkin_point();

CREATE TABLE IF NOT EXISTS psy_point_rewards (
  id                          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name                        TEXT NOT NULL,
  description                 TEXT,
  points_cost                 INT NOT NULL CHECK (points_cost > 0),
  voucher_amount              NUMERIC(10,2) NOT NULL CHECK (voucher_amount > 0),
  max_redemptions_per_patient INT,
  is_active                   BOOLEAN NOT NULL DEFAULT true,
  created_by                  UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  created_at                  TIMESTAMPTZ DEFAULT now(),
  updated_at                  TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE psy_point_rewards ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone read point rewards" ON psy_point_rewards;
CREATE POLICY "Anyone read point rewards" ON psy_point_rewards FOR SELECT USING (true);

DROP POLICY IF EXISTS "Staff manage point rewards" ON psy_point_rewards;
CREATE POLICY "Staff manage point rewards" ON psy_point_rewards
  FOR ALL USING      (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
           WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

CREATE OR REPLACE FUNCTION redeem_point_reward(p_reward_id UUID)
RETURNS psy_vouchers
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_patient_id UUID;
  v_reward     psy_point_rewards%ROWTYPE;
  v_balance    INT;
  v_redeemed   INT;
  v_voucher    psy_vouchers%ROWTYPE;
BEGIN
  SELECT id INTO v_patient_id FROM psy_patients WHERE user_id = auth.uid() LIMIT 1;
  IF v_patient_id IS NULL THEN
    RAISE EXCEPTION 'Rekod pesakit tidak dijumpai.';
  END IF;

  SELECT * INTO v_reward FROM psy_point_rewards WHERE id = p_reward_id;
  IF v_reward.id IS NULL OR NOT v_reward.is_active THEN
    RAISE EXCEPTION 'Ganjaran ini tidak sah atau tidak lagi ditawarkan.';
  END IF;

  IF v_reward.max_redemptions_per_patient IS NOT NULL THEN
    SELECT COUNT(*) INTO v_redeemed FROM psy_points_ledger
      WHERE patient_id = v_patient_id AND source_type = 'reward_redeem' AND source_ref = v_reward.id;
    IF v_redeemed >= v_reward.max_redemptions_per_patient THEN
      RAISE EXCEPTION 'Anda telah mencapai had tukaran untuk ganjaran ini.';
    END IF;
  END IF;

  SELECT COALESCE(SUM(points), 0) INTO v_balance FROM psy_points_ledger WHERE patient_id = v_patient_id;
  IF v_balance < v_reward.points_cost THEN
    RAISE EXCEPTION 'Mata tidak mencukupi.';
  END IF;

  INSERT INTO psy_points_ledger (patient_id, source_type, source_ref, points, note)
  VALUES (v_patient_id, 'reward_redeem', v_reward.id, -v_reward.points_cost, 'Tukar: ' || v_reward.name);

  INSERT INTO psy_vouchers (patient_id, source_type, source_ref, amount, note)
  VALUES (v_patient_id, 'point_redeem', v_reward.id, v_reward.voucher_amount, 'Ditukar dari mata: ' || v_reward.name)
  RETURNING * INTO v_voucher;

  RETURN v_voucher;
END;
$$;

GRANT EXECUTE ON FUNCTION redeem_point_reward(UUID) TO authenticated;
