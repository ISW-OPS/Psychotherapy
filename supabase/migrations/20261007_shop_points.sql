-- ═══════════════════════════════════════════════════════════════════
-- Fasa 5 — Mata Shop (lock sebelum ni, 6 Okt 2026)
-- RM1 jumlah produk LAYAK = 1 mata. Dikira SELEPAS diskaun (psy_payments.total
-- sedia ada total selepas diskaun), TIDAK termasuk caj penghantaran (deliveryFee
-- dalam intent.items[].deliveryFee bagi item jenis 'shop_order').
-- Diberi HANYA bila status psy_payments jadi 'completed'. Dibalikkan automatik
-- bila bayaran yang sama kemudian jadi 'refunded'/'voided'. Idempoten penuh —
-- trigger guna psy_payments.id sebagai source_ref unik, jadi selamat kalau UPDATE
-- jalan berkali-kali (cth retry webhook) kerana NOT EXISTS/EXISTS guard.
-- Skop: HANYA bayaran yang SEMUA itemnya 'shop_order' (checkout Shop tulen) —
-- bayaran pakej/KOB/sesi yang guna fungsi sama TIDAK layak mata Shop.
-- ═══════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION _shop_points_eligible_amount(p_payment psy_payments)
RETURNS NUMERIC
LANGUAGE plpgsql
AS $$
DECLARE
  v_items JSONB;
  v_item JSONB;
  v_delivery NUMERIC := 0;
  v_only_shop BOOLEAN := true;
BEGIN
  v_items := p_payment.intent -> 'items';
  IF v_items IS NULL OR jsonb_typeof(v_items) <> 'array' OR jsonb_array_length(v_items) = 0 THEN
    RETURN 0;
  END IF;

  FOR v_item IN SELECT * FROM jsonb_array_elements(v_items) LOOP
    IF (v_item ->> 'type') IS DISTINCT FROM 'shop_order' THEN
      v_only_shop := false;
    ELSE
      -- JANGAN baca (v_item->>'deliveryFee') — itu nilai CLIENT yang disimpan mentah
      -- dalam intent (boleh ditokok tolak); payments-initiate dah tak percaya nilai
      -- tu utk kira total sebenar (dibetulkan 7 Okt), jadi kira sendiri sama cara di sini.
      v_delivery := v_delivery + (CASE WHEN v_item ->> 'deliveryMethod' = 'pos' THEN 8 ELSE 0 END);
    END IF;
  END LOOP;

  -- Elak kira mata utk pesanan campur (shop_order + jenis lain) — tak berlaku
  -- dalam UI sedia ada (satu checkout = satu jenis), tapi jaga-jaga.
  IF NOT v_only_shop THEN
    RETURN 0;
  END IF;

  RETURN GREATEST(0, COALESCE(p_payment.total, 0) - v_delivery);
END;
$$;

CREATE OR REPLACE FUNCTION trg_shop_points_on_payment()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_points INT;
  v_eligible NUMERIC;
BEGIN
  -- Diberi: status BARU jadi 'completed' (bukan status lain → completed berulang)
  IF NEW.status = 'completed' AND (TG_OP = 'INSERT' OR OLD.status IS DISTINCT FROM 'completed') THEN
    IF NOT EXISTS (SELECT 1 FROM psy_points_ledger WHERE source_type = 'shop_purchase' AND source_ref = NEW.id) THEN
      v_eligible := _shop_points_eligible_amount(NEW);
      v_points := floor(v_eligible)::int;
      IF v_points > 0 AND NEW.patient_id IS NOT NULL THEN
        INSERT INTO psy_points_ledger (patient_id, source_type, source_ref, points, note)
        VALUES (NEW.patient_id, 'shop_purchase', NEW.id, v_points, 'Pembelian Shop — resit ' || COALESCE(NEW.receipt_ref, NEW.id::text));
      END IF;
    END IF;
  END IF;

  -- Dibalikkan: bayaran yang DAH pernah 'completed', kini jadi refunded/voided
  IF NEW.status IN ('refunded', 'voided') AND OLD.status IS DISTINCT FROM NEW.status AND OLD.status = 'completed' THEN
    IF EXISTS (SELECT 1 FROM psy_points_ledger WHERE source_type = 'shop_purchase' AND source_ref = NEW.id)
       AND NOT EXISTS (SELECT 1 FROM psy_points_ledger WHERE source_type = 'shop_refund' AND source_ref = NEW.id) THEN
      SELECT -points INTO v_points FROM psy_points_ledger WHERE source_type = 'shop_purchase' AND source_ref = NEW.id;
      IF v_points IS NOT NULL AND v_points <> 0 THEN
        INSERT INTO psy_points_ledger (patient_id, source_type, source_ref, points, note)
        VALUES (NEW.patient_id, 'shop_refund', NEW.id, v_points, 'Pembalikan mata — bayaran ' || NEW.status);
      END IF;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_shop_points_on_payment ON psy_payments;
CREATE TRIGGER trg_shop_points_on_payment
  AFTER INSERT OR UPDATE OF status ON psy_payments
  FOR EACH ROW EXECUTE FUNCTION trg_shop_points_on_payment();
