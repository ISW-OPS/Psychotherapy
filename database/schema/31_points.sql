-- ═══════════════════════════════════════════════════════════════════
-- 31 — SISTEM MATA (POINTS)
-- Jadual: psy_points_ledger, psy_point_rewards. View: psy_points_balance.
-- Fungsi: redeem_point_reward(). Trigger: trg_award_daily_checkin_point.
-- Pesakit dapat 1 mata setiap hari isi Catatan Harian (psy_kepatuhan_log,
-- 11_checkins_kepatuhan.sql), tukar mata jadi baucar RM (reuse psy_vouchers,
-- 28_rewards.sql — auto-apply FIFO checkout, tiada kerja tambahan).
-- ═══════════════════════════════════════════════════════════════════

-- ──── psy_points_ledger ────
-- Lejar mata generik (append-only) — sama falsafah dgn psy_vouchers:
-- setiap peraturan cuma perlu INSERT satu baris, logik baki dikira sekali.
CREATE TABLE IF NOT EXISTS psy_points_ledger (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id   UUID NOT NULL REFERENCES psy_patients(id) ON DELETE CASCADE,
  source_type  TEXT NOT NULL,      -- 'daily_checkin' | 'reward_redeem' | ...
  source_ref   UUID,               -- rujukan longgar (psy_kepatuhan_log.id / psy_point_rewards.id)
  points       INT NOT NULL CHECK (points <> 0),  -- positif = dapat, negatif = belanja
  note         TEXT,
  created_at   TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_psy_points_ledger_patient ON psy_points_ledger(patient_id, created_at);

ALTER TABLE psy_points_ledger ENABLE ROW LEVEL SECURITY;

-- Tiada INSERT policy pesakit — semua tulisan lalui trigger/RPC SECURITY
-- DEFINER (elak pesakit forge mata sendiri).
DROP POLICY IF EXISTS "Patients view own points" ON psy_points_ledger;
CREATE POLICY "Patients view own points" ON psy_points_ledger FOR SELECT
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Staff view all points" ON psy_points_ledger;
CREATE POLICY "Staff view all points" ON psy_points_ledger FOR SELECT
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- View baki mata per-pesakit — senang dibaca client (SELECT terus, bukan
-- aggregate manual di JS). security_invoker=true WAJIB — tanpa ni, view
-- jalan dengan hak pemilik (bypass RLS psy_points_ledger), pesakit boleh
-- nampak baki SEMUA orang.
CREATE OR REPLACE VIEW psy_points_balance
  WITH (security_invoker = true) AS
  SELECT patient_id, COALESCE(SUM(points), 0)::INT AS balance
  FROM psy_points_ledger
  GROUP BY patient_id;

-- ──── Trigger: 1 mata setiap hari isi Catatan Harian ────
-- kepatuhan.html simpan guna .upsert(payload, {onConflict:'patient_id,log_date'})
-- — AFTER INSERT cuma fire pada submission PERTAMA hari tu; edit berulang
-- hari sama jatuh ke laluan UPDATE (conflict), trigger INSERT tak fire
-- semula. Jadi 1 hari = 1 mata, auto, tiada duplicate-guard tambahan perlu.
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

-- ──── psy_point_rewards ────
-- Katalog ganjaran (staff-managed) — tukar mata jadi baucar RM.
CREATE TABLE IF NOT EXISTS psy_point_rewards (
  id                          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name                        TEXT NOT NULL,
  description                 TEXT,
  points_cost                 INT NOT NULL CHECK (points_cost > 0),
  voucher_amount              NUMERIC(10,2) NOT NULL CHECK (voucher_amount > 0),
  max_redemptions_per_patient INT,   -- NULL = tiada had
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

-- ──── redeem_point_reward() ────
-- RPC dipanggil client (window.db.rpc('redeem_point_reward', { p_reward_id })).
-- Kira baki mata SENDIRI dalam function (bukan baca view) elak race/staleness.
-- Belanja mata + cipta baucar RM (psy_vouchers) dalam SATU transaksi.
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

  -- Audit #C-13 (Tier 5) — tempoh sah 90 hari dari tarikh tebus (dulu expires_at
  -- sentiasa NULL = tiada luput langsung). payments-initiate.ts (checkout) & profile.html
  -- (paparan pesakit) dua-dua dah semak expires_at, jadi terus berkesan.
  INSERT INTO psy_vouchers (patient_id, source_type, source_ref, amount, note, expires_at)
  VALUES (v_patient_id, 'point_redeem', v_reward.id, v_reward.voucher_amount, 'Ditukar dari mata: ' || v_reward.name, now() + interval '90 days')
  RETURNING * INTO v_voucher;

  RETURN v_voucher;
END;
$$;

GRANT EXECUTE ON FUNCTION redeem_point_reward(UUID) TO authenticated;

-- ──── adjust_points_manual() ────
-- Audit #C-13 (Tier 5) — dulu TIADA cara staf laras mata pesakit secara manual
-- (cth pampasan kesilapan sistem, ganjaran ad-hoc) sbb psy_points_ledger langsung
-- tiada INSERT policy (sengaja, elak forge). RPC ni SATU-SATUNYA laluan tulisan
-- manual — sebab WAJIB, staf-sahaja (semak role dlm function, bukan harap RLS).
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

-- ──── Fasa 5 (7 Okt 2026) — Mata Shop: trigger auto-kira bila bayaran Shop selesai/refund ────
-- RM1 produk layak = 1 mata (selepas diskaun, tak termasuk penghantaran).
-- Lihat migration 20261007_shop_points.sql utk nota penuh.
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
      -- JANGAN baca (v_item->>'deliveryFee') — nilai CLIENT mentah, boleh ditokok.
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
