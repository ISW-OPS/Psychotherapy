-- ═══════════════════════════════════════════════════════════════════
-- SEED: WELCOME10 usage demo data (TESTING sahaja)
-- Jana 45 penggunaan (daripada had 50) utk kod promo WELCOME10
-- (id 78ed9083-dc13-4bfa-ba35-55600890dec9) supaya halaman
-- promo-detail.html (Ikhtisar/Penggunaan) ada data utk ditunjuk.
--
-- Guna psy_patients + psy_products SEBENAR yang wujud dlm DB testing
-- (rawak), cipta psy_payments (is_test=true, ditandakan notes
-- 'SEED:WELCOME10-REDEMPTION' supaya boleh re-run selamat / dibuang
-- semula) + psy_promo_redemptions padanan, lepas tu set
-- max_uses=50, used_count=45 pada kod promo.
--
-- is_test=true → DIKECUALIKAN drpd laporan kewangan sebenar (KPI
-- dashboard dll), jadi tak mengotorkan nombor jualan sebenar.
--
-- JALANKAN DI SUPABASE SQL EDITOR PROJEK TESTING (ipmemyizigwgivccytcu)
-- — bukan production.
-- ═══════════════════════════════════════════════════════════════════

DO $$
DECLARE
  v_promo_id     UUID := '78ed9083-dc13-4bfa-ba35-55600890dec9';
  v_promo        psy_promo_codes%ROWTYPE;
  v_patients     UUID[];
  v_patient_id   UUID;
  v_payment_id   UUID;
  v_items        JSONB;
  v_line_count   INT;
  v_subtotal     NUMERIC;
  v_discount     NUMERIC;
  v_total        NUMERIC;
  v_created      TIMESTAMPTZ;
  v_product      RECORD;
  v_qty          INT;
  v_price        NUMERIC;
  i              INT;
  j              INT;
BEGIN
  SELECT * INTO v_promo FROM psy_promo_codes WHERE id = v_promo_id;
  IF v_promo.id IS NULL THEN
    RAISE EXCEPTION 'Kod promo % tidak dijumpai dalam DB ini — pastikan anda run script ni di projek TESTING.', v_promo_id;
  END IF;

  SELECT array_agg(id) INTO v_patients FROM psy_patients WHERE status <> 'deleted';
  IF v_patients IS NULL OR array_length(v_patients, 1) = 0 THEN
    RAISE EXCEPTION 'Tiada pesakit aktif dijumpai utk seed.';
  END IF;

  -- Buang seed lama (kalau script ni di-run berulang kali)
  DELETE FROM psy_promo_redemptions WHERE promo_id = v_promo_id
    AND payment_id IN (SELECT id FROM psy_payments WHERE notes = 'SEED:WELCOME10-REDEMPTION');
  DELETE FROM psy_payments WHERE notes = 'SEED:WELCOME10-REDEMPTION';

  FOR i IN 1..45 LOOP
    v_patient_id := v_patients[1 + floor(random() * array_length(v_patients, 1))::int];
    v_created    := now() - (floor(random() * 25) || ' days')::interval - (floor(random() * 24) || ' hours')::interval;

    -- Jana 1-3 baris item dari produk SEBENAR
    v_items      := '[]'::jsonb;
    v_subtotal   := 0;
    v_line_count := 1 + floor(random() * 3)::int;
    FOR j IN 1..v_line_count LOOP
      SELECT product_id, name, price INTO v_product FROM psy_products ORDER BY random() LIMIT 1;
      EXIT WHEN v_product.product_id IS NULL;
      v_qty   := 1 + floor(random() * 3)::int;
      v_price := COALESCE(NULLIF(v_product.price, 0), round((20 + random() * 80)::numeric, 2));
      v_items := v_items || jsonb_build_array(jsonb_build_object(
        'id', v_product.product_id, 'name', v_product.name, 'qty', v_qty, 'price', v_price
      ));
      v_subtotal := v_subtotal + v_price * v_qty;
    END LOOP;

    IF v_subtotal = 0 THEN v_subtotal := round((50 + random() * 150)::numeric, 2); END IF;

    -- Kira diskaun ikut jenis kod promo sebenar
    IF v_promo.discount_type = 'percent' THEN
      v_discount := round(v_subtotal * v_promo.discount_value / 100, 2);
      IF v_promo.max_discount IS NOT NULL AND v_discount > v_promo.max_discount THEN
        v_discount := v_promo.max_discount;
      END IF;
    ELSE
      v_discount := LEAST(v_promo.discount_value, v_subtotal);
    END IF;
    v_total := v_subtotal - v_discount;

    INSERT INTO psy_payments (
      receipt_ref, patient_id, subtotal, total, discount, payment_method, status,
      is_test, notes, intent, paid_at, created_at
    ) VALUES (
      'SEED-WC10-' || lpad(i::text, 3, '0') || '-' || substr(gen_random_uuid()::text, 1, 6),
      v_patient_id, v_subtotal, v_total, v_discount, 'gateway', 'completed',
      true, 'SEED:WELCOME10-REDEMPTION',
      jsonb_build_object('promoCodeId', v_promo_id, 'promoDiscount', v_discount,
        'items', jsonb_build_array(jsonb_build_object('type', 'shop_order', 'items', v_items))),
      v_created, v_created
    ) RETURNING id INTO v_payment_id;

    INSERT INTO psy_promo_redemptions (promo_id, patient_id, payment_id, discount_amount, created_at)
    VALUES (v_promo_id, v_patient_id, v_payment_id, v_discount, v_created);
  END LOOP;

  UPDATE psy_promo_codes SET max_uses = 50, used_count = 45, updated_at = now()
  WHERE id = v_promo_id;

  RAISE NOTICE 'Selesai: 45 penggunaan seed utk kod %', v_promo.code;
END $$;
