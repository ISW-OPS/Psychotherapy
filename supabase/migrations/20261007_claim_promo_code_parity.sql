-- ═══════════════════════════════════════════════════════════════════
-- Fasa 3 (7 Okt 2026) — Selaraskan claim_promo_code() dengan payments-initiate
-- claim_promo_code() (pesakit simpan kod ke My Vouchers) ditulis SEBELUM
-- medan Fasa 2 (customer_eligibility, max_uses_per_patient, start_time,
-- end_time) wujud. Ia cuma semak is_active + tarikh + had keseluruhan —
-- jadi pesakit boleh "claim" kod yang sepatutnya tak layak utk dia
-- (cth kod pelanggan baharu, dia dah pelanggan sedia ada), walaupun
-- checkout akan tolak lepas tu. Patch ni selaraskan kedua-dua laluan.
-- ═══════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION claim_promo_code(p_code TEXT)
RETURNS psy_promo_claims
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_patient_id UUID;
  v_promo      psy_promo_codes%ROWTYPE;
  v_now_my     TIMESTAMP;
  v_start_my   TIMESTAMP;
  v_end_my     TIMESTAMP;
  v_expires_at TIMESTAMPTZ;
  v_claim      psy_promo_claims%ROWTYPE;
  v_elig_mode  TEXT;
  v_has_paid   BOOLEAN;
  v_redeemed   INT;
BEGIN
  SELECT id INTO v_patient_id FROM psy_patients WHERE user_id = auth.uid() LIMIT 1;
  IF v_patient_id IS NULL THEN
    RAISE EXCEPTION 'Rekod pesakit tidak dijumpai.';
  END IF;

  SELECT * INTO v_promo FROM psy_promo_codes WHERE code = upper(trim(p_code));
  IF v_promo.id IS NULL OR NOT v_promo.is_active THEN
    RAISE EXCEPTION 'Kod tidak sah atau telah luput.';
  END IF;

  -- Tarikh + masa (waktu tempatan Malaysia, UTC+8) — sama kaedah dgn payments-initiate
  v_now_my := (now() + interval '8 hours');
  v_start_my := CASE WHEN v_promo.valid_from IS NOT NULL THEN v_promo.valid_from::timestamp + COALESCE(v_promo.start_time, '00:00:00')::time ELSE NULL END;
  v_end_my := CASE WHEN v_promo.valid_until IS NOT NULL THEN v_promo.valid_until::timestamp + COALESCE(v_promo.end_time, '23:59:59')::time ELSE NULL END;
  IF (v_start_my IS NOT NULL AND v_now_my < v_start_my) OR (v_end_my IS NOT NULL AND v_now_my > v_end_my) THEN
    RAISE EXCEPTION 'Kod tidak sah atau telah luput.';
  END IF;

  IF v_promo.max_uses IS NOT NULL AND v_promo.used_count >= v_promo.max_uses THEN
    RAISE EXCEPTION 'Kod ini telah mencapai had penggunaan.';
  END IF;

  -- Had setiap pesakit (dikira dari penggunaan SEBENAR, bukan claim)
  IF v_promo.max_uses_per_patient IS NOT NULL THEN
    SELECT count(*) INTO v_redeemed FROM psy_promo_redemptions
      WHERE promo_id = v_promo.id AND patient_id = v_patient_id;
    IF v_redeemed >= v_promo.max_uses_per_patient THEN
      RAISE EXCEPTION 'Anda sudah guna had maksimum untuk kod ini.';
    END IF;
  END IF;

  -- Kelayakan pelanggan
  v_elig_mode := COALESCE(v_promo.customer_eligibility, CASE WHEN v_promo.new_customer_only THEN 'new' ELSE 'all' END);
  IF v_elig_mode IN ('new', 'existing') THEN
    SELECT EXISTS (SELECT 1 FROM psy_payments WHERE patient_id = v_patient_id AND status = 'completed') INTO v_has_paid;
    IF v_elig_mode = 'new' AND v_has_paid THEN
      RAISE EXCEPTION 'Kod ini untuk pesakit baharu sahaja.';
    END IF;
    IF v_elig_mode = 'existing' AND NOT v_has_paid THEN
      RAISE EXCEPTION 'Kod ini untuk pesakit sedia ada sahaja.';
    END IF;
  ELSIF v_elig_mode = 'selected' AND NOT (v_patient_id = ANY(COALESCE(v_promo.selected_patient_ids, ARRAY[]::UUID[]))) THEN
    RAISE EXCEPTION 'Kod ini tidak sah untuk akaun anda.';
  END IF;

  v_expires_at := CASE
    WHEN v_promo.valid_until IS NOT NULL THEN v_promo.valid_until::timestamptz + INTERVAL '1 day' - INTERVAL '1 second'
    WHEN v_promo.wallet_validity_days IS NOT NULL THEN now() + (v_promo.wallet_validity_days || ' days')::interval
    ELSE NULL
  END;

  BEGIN
    INSERT INTO psy_promo_claims (patient_id, promo_id, code, discount_type, discount_value, min_subtotal, expires_at)
    VALUES (v_patient_id, v_promo.id, v_promo.code, v_promo.discount_type, v_promo.discount_value, v_promo.min_subtotal, v_expires_at)
    RETURNING * INTO v_claim;
  EXCEPTION WHEN unique_violation THEN
    RAISE EXCEPTION 'Anda sudah menuntut kod ini.';
  END;

  RETURN v_claim;
END;
$$;
