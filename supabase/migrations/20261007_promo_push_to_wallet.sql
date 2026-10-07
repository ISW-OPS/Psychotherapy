-- ═══════════════════════════════════════════════════════════════════
-- Fasa 2b — Promosi sebagai Voucher (auto-push ke wallet pesakit)
-- Lock 7 Okt 2026 (dikemaskini): satu promosi (psy_promo_codes), staff
-- pilih "Jenis Promosi" = Promo Code (pesakit taip/claim sendiri — gaya
-- sedia ada) atau Voucher (sistem AUTOMATIK push ke wallet pesakit
-- layak — psy_promo_claims — sebaik promosi jadi Aktif, tiada butang
-- manual). Idempoten: ON CONFLICT (promo_id, patient_id) DO NOTHING,
-- jadi trigger boleh jalan berulang kali (setiap kali disunting semasa
-- aktif) tanpa duplikat — ini jugak cara pesakit baharu yang jadi
-- layak lepas tu turut terangkum bila staff edit promosi.
-- "History" (used/expired) tak perlu kerja tambahan — psy_promo_claims
-- + roles/patient/vouchers.html dah pisah tab Aktif/Lepas sedia ada.
-- ═══════════════════════════════════════════════════════════════════

ALTER TABLE psy_promo_codes
  ADD COLUMN IF NOT EXISTS promotion_type TEXT NOT NULL DEFAULT 'promo_code';

ALTER TABLE psy_promo_codes DROP CONSTRAINT IF EXISTS psy_promo_codes_promotion_type_check;
ALTER TABLE psy_promo_codes ADD CONSTRAINT psy_promo_codes_promotion_type_check
  CHECK (promotion_type IN ('promo_code', 'voucher'));

COMMENT ON COLUMN psy_promo_codes.promotion_type IS
  'promo_code = pesakit taip/claim kod sendiri. voucher = auto-push ke wallet (psy_promo_claims) pesakit layak bila promosi Aktif — lihat trg_promo_push_voucher.';

-- ──── _push_promo_wallet_rows(): logik insert sebenar (dalaman, tiada semakan staff) ────
-- Dipanggil oleh trigger (selepas UPDATE/INSERT yang DAH lepas RLS staff-only
-- pada psy_promo_codes — jadi kebenaran dah disahkan oleh UPDATE/INSERT itu sendiri).
CREATE OR REPLACE FUNCTION _push_promo_wallet_rows(p_promo_id UUID)
RETURNS INT
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_promo psy_promo_codes%ROWTYPE;
  v_expires_at TIMESTAMPTZ;
  v_count INT;
BEGIN
  SELECT * INTO v_promo FROM psy_promo_codes WHERE id = p_promo_id;
  IF v_promo.id IS NULL OR v_promo.promotion_type IS DISTINCT FROM 'voucher' OR NOT v_promo.is_active THEN
    RETURN 0;
  END IF;

  v_expires_at := CASE
    WHEN v_promo.valid_until IS NOT NULL THEN v_promo.valid_until::timestamptz + INTERVAL '1 day' - INTERVAL '1 second'
    WHEN v_promo.wallet_validity_days IS NOT NULL THEN now() + (v_promo.wallet_validity_days || ' days')::interval
    ELSE NULL
  END;

  INSERT INTO psy_promo_claims (patient_id, promo_id, code, discount_type, discount_value, min_subtotal, expires_at)
  SELECT p.id, v_promo.id, v_promo.code, v_promo.discount_type, v_promo.discount_value, v_promo.min_subtotal, v_expires_at
  FROM psy_patients p
  WHERE p.status <> 'deleted'
    AND (
      v_promo.customer_eligibility = 'all' OR v_promo.customer_eligibility IS NULL
      OR (v_promo.customer_eligibility = 'new' AND NOT EXISTS (SELECT 1 FROM psy_payments pay WHERE pay.patient_id = p.id AND pay.status = 'completed'))
      OR (v_promo.customer_eligibility = 'existing' AND EXISTS (SELECT 1 FROM psy_payments pay WHERE pay.patient_id = p.id AND pay.status = 'completed'))
      OR (v_promo.customer_eligibility = 'selected' AND p.id = ANY(COALESCE(v_promo.selected_patient_ids, ARRAY[]::UUID[])))
    )
  ON CONFLICT (promo_id, patient_id) DO NOTHING;

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

-- ──── trg_promo_push_voucher(): auto-push bila promosi Voucher jadi/kekal Aktif ────
-- Jalan pada INSERT (dicipta terus Aktif) dan UPDATE (ditogol Aktif, atau
-- disunting semasa Aktif — supaya pesakit baharu yang jadi layak turut dapat).
CREATE OR REPLACE FUNCTION trg_promo_push_voucher()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NEW.promotion_type = 'voucher' AND NEW.is_active THEN
    PERFORM _push_promo_wallet_rows(NEW.id);
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_promo_push_voucher ON psy_promo_codes;
CREATE TRIGGER trg_promo_push_voucher
  AFTER INSERT OR UPDATE ON psy_promo_codes
  FOR EACH ROW EXECUTE FUNCTION trg_promo_push_voucher();
