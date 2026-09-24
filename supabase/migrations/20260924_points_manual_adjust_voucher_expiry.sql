-- Audit management 23 Sept 2026, Tier 5 (#C-13) — pelarasan mata manual (staf,
-- sebab wajib, audit trail) + tempoh sah 90 hari utk baucar tukar mata.
-- Rujuk: database/schema/31_points.sql

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

  INSERT INTO psy_vouchers (patient_id, source_type, source_ref, amount, note, expires_at)
  VALUES (v_patient_id, 'point_redeem', v_reward.id, v_reward.voucher_amount, 'Ditukar dari mata: ' || v_reward.name, now() + interval '90 days')
  RETURNING * INTO v_voucher;

  RETURN v_voucher;
END;
$$;

GRANT EXECUTE ON FUNCTION redeem_point_reward(UUID) TO authenticated;

CREATE OR REPLACE FUNCTION adjust_points_manual(p_patient_id UUID, p_points INT, p_reason TEXT)
RETURNS psy_points_ledger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_is_staff BOOLEAN;
  v_row      psy_points_ledger%ROWTYPE;
BEGIN
  SELECT EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff') INTO v_is_staff;
  IF NOT v_is_staff THEN
    RAISE EXCEPTION 'Hanya staf boleh laras mata pesakit.';
  END IF;
  IF p_points = 0 THEN
    RAISE EXCEPTION 'Bilangan mata mesti bukan sifar.';
  END IF;
  IF p_reason IS NULL OR btrim(p_reason) = '' THEN
    RAISE EXCEPTION 'Sebab pelarasan diperlukan.';
  END IF;

  INSERT INTO psy_points_ledger (patient_id, source_type, points, note)
  VALUES (p_patient_id, 'manual_adjustment', p_points, btrim(p_reason))
  RETURNING * INTO v_row;

  RETURN v_row;
END;
$$;

GRANT EXECUTE ON FUNCTION adjust_points_manual(UUID, INT, TEXT) TO authenticated;
