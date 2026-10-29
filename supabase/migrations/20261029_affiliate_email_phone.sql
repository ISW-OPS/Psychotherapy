-- 29 Okt 2026 — tarik 2 field GHL tambahan (folder "PT Sytem"):
-- referred_by_affiliate_email, referred_by_affiliate_phone — supaya
-- kob-detail.html seksyen "Affiliate" boleh papar nama+email+phone terus
-- dari GHL (gantikan logik qualified/eligible date psy_referrals yang
-- sebelum ni kosong sentiasa bila tiada padanan nama affiliate).
ALTER TABLE psy_patients ADD COLUMN IF NOT EXISTS referred_by_affiliate_email TEXT;
ALTER TABLE psy_patients ADD COLUMN IF NOT EXISTS referred_by_affiliate_phone TEXT;

-- Fix bug lama: trg_referral_qualify_on_payment() baca kunci 'packageId'
-- dalam items[0], tapi TIADA laluan insert psy_payments pernah tulis kunci
-- tu — semua guna 'reference_id'. qualifying_package_id sentiasa NULL utk
-- SEMUA rujukan (affiliate GHL & pesakit-ke-pesakit) sejak dulu. Papar
-- "Product/Package" kosong di affiliate.html punca utama.
CREATE OR REPLACE FUNCTION trg_referral_qualify_on_payment()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_ref_id    UUID;
  v_pkg_text  TEXT;
  v_pkg_id    UUID;
  v_rule      RECORD;
  v_amount    NUMERIC(10,2);
  v_referrer_patient_id   UUID;
  v_referrer_affiliate_id UUID;
  v_referrer_user_id      UUID;
  v_source    TEXT;
  v_has_kob   BOOLEAN;
  v_month     DATE;
BEGIN
  IF NEW.status IS DISTINCT FROM 'completed' OR NEW.patient_id IS NULL THEN
    RETURN NEW;
  END IF;
  IF TG_OP = 'UPDATE' AND OLD.status = 'completed' THEN
    RETURN NEW; -- elak kira dua kali
  END IF;

  SELECT id, referrer_patient_id, referrer_affiliate_id, source
    INTO v_ref_id, v_referrer_patient_id, v_referrer_affiliate_id, v_source
  FROM psy_referrals
  WHERE referee_patient_id = NEW.patient_id AND status = 'pending'
  LIMIT 1;
  IF v_ref_id IS NULL THEN
    RETURN NEW;
  END IF;

  -- (27 Okt 2026) Rujukan GHL affiliate — "1 SU" cuma layak lepas pesakit
  -- SETTLE sesi KOB (hadir/completed), bukan setakat bayar pakej.
  IF v_source = 'ghl_affiliate' THEN
    SELECT EXISTS (
      SELECT 1 FROM psy_kob_sessions WHERE patient_id = NEW.patient_id AND status IN ('hadir','completed')
    ) INTO v_has_kob;
    IF NOT v_has_kob THEN
      RETURN NEW; -- KOB belum settle — belum layak qualify lagi
    END IF;
  END IF;

  -- Cuba kesan pakej dari baris pertama items[] (teks kod ATAU UUID —
  -- ikut ketidakkonsistenan active_package_id yang direkod dlm memory).
  -- FIX 29 Okt 2026: kunci JSON SEBENAR yang ditulis setiap laluan insert
  -- psy_payments (payments-initiate, manual KOB dll.) ialah `reference_id`
  -- — `packageId` TAK PERNAH wujud dalam items[] (bug lama, qualifying_
  -- package_id sentiasa NULL utk SEMUA rujukan sebelum ni, bukan isu
  -- khusus GHL affiliate).
  BEGIN
    v_pkg_text := COALESCE(NEW.items -> 0 ->> 'reference_id', NEW.items -> 0 ->> 'packageId');
  EXCEPTION WHEN OTHERS THEN
    v_pkg_text := NULL;
  END;

  IF v_pkg_text IS NOT NULL THEN
    SELECT id INTO v_pkg_id FROM psy_packages
    WHERE id::text = v_pkg_text OR package_id = v_pkg_text
    LIMIT 1;
  END IF;

  IF v_source = 'ghl_affiliate' THEN
    -- Nilai AWAL sahaja — recalc_affiliate_commission_tier() di bawah
    -- timpa dgn kadar tier SEBENAR serta-merta (dalam transaksi sama).
    v_amount := 0;
  ELSE
    SELECT * INTO v_rule FROM psy_affiliate_commission_rules
    WHERE package_id = v_pkg_id AND is_active LIMIT 1;

    IF NOT FOUND THEN
      SELECT * INTO v_rule FROM psy_affiliate_commission_rules
      WHERE package_id IS NULL AND is_active LIMIT 1;
    END IF;

    IF v_rule.id IS NOT NULL THEN
      IF v_rule.commission_type = 'fixed' THEN
        v_amount := COALESCE(v_rule.amount, 0);
      ELSE
        v_amount := ROUND(COALESCE(NEW.total, 0) * COALESCE(v_rule.rate_percent, 0) / 100, 2);
        IF v_rule.cap_amount IS NOT NULL THEN
          v_amount := LEAST(v_amount, v_rule.cap_amount);
        END IF;
      END IF;
    ELSE
      v_amount := 0;
    END IF;
  END IF;

  v_month := date_trunc('month', now())::date;

  UPDATE psy_referrals SET
    status = 'qualified',
    qualified_at = now(),
    qualifying_payment_id = NEW.id,
    qualifying_package_id = v_pkg_id,
    commission_amount = v_amount,
    commission_month = v_month
  WHERE id = v_ref_id;

  IF v_source = 'ghl_affiliate' THEN
    PERFORM recalc_affiliate_commission_tier(v_referrer_affiliate_id, v_month);
    SELECT commission_amount INTO v_amount FROM psy_referrals WHERE id = v_ref_id;
  END IF;

  INSERT INTO psy_notifications (user_id, type, title, body, link)
  SELECT id, 'affiliate',
    '💰 Komisen Affiliate Layak',
    'Satu rujukan pesakit layak komisen RM ' || v_amount::text || '.',
    'affiliate.html'
  FROM psy_profiles WHERE role = 'staff';

  -- Bagitahu pesakit perujuk juga (kalau ada akaun) — supaya dia tahu
  -- serta-merta tanpa perlu check Profile secara manual.
  IF v_amount > 0 THEN
    SELECT user_id INTO v_referrer_user_id FROM psy_patients WHERE id = v_referrer_patient_id;
    IF v_referrer_user_id IS NOT NULL THEN
      INSERT INTO psy_notifications (user_id, type, title, body, link)
      VALUES (
        v_referrer_user_id, 'affiliate',
        '🎉 Kawan Anda Dah Daftar!',
        'Anda layak komisen RM ' || v_amount::text || ' dari rujukan anda.',
        'profile.html'
      );
    END IF;
  END IF;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE LOG 'trg_referral_qualify_on_payment: %', SQLERRM;
  RETURN NEW;
END;
$$;

-- backfill: baiki rujukan sedia ada yang dah 'qualified' sebelum fix ni
-- (qualifying_package_id tersekat NULL) — padan semula ikut items[0].reference_id.
UPDATE psy_referrals r SET qualifying_package_id = (
  SELECT p.id FROM psy_payments p2
  JOIN psy_packages p ON p.id::text = (p2.items -> 0 ->> 'reference_id') OR p.package_id = (p2.items -> 0 ->> 'reference_id')
  WHERE p2.id = r.qualifying_payment_id
  LIMIT 1
)
WHERE r.qualifying_package_id IS NULL AND r.qualifying_payment_id IS NOT NULL;

-- ═══════════════════════════════════════════════════════════════════
-- 29 Okt 2026 (bahagian 2) — Unit tukaran stok→pesakit (issue_unit)
-- Contoh: beli 1 "Gulung" surgical tape = 30 "Inci", pesakit guna 1 Inci
-- setiap kali. Sebelum ni staff WAJIB bagi pesakit dlm unit stok tepat
-- (kena taip 0.033 Gulung) sebab tiada konsep unit kecil langsung.
-- qty_in_stock/qty/balance_after dilebarkan 2dp→4dp supaya pecahan macam
-- 1/30 tak hilang ketepatan bila terkumpul banyak kali.
--
-- NOTA susunan (fix 29 Okt lewat petang): DROP constraint lama + UPDATE
-- data WAJIB jalan SEBELUM ADD constraint baharu yg lagi ketat (tiada
-- lagi 'Biji (pcs)'/'Paket') — kalau tak, ADD constraint akan gagal sbb
-- row sedia ada masih guna nilai yg dah dibuang drpd senarai dibenarkan.
-- ═══════════════════════════════════════════════════════════════════
ALTER TABLE psy_inventory_items DROP CONSTRAINT IF EXISTS psy_inventory_items_unit_check;
ALTER TABLE psy_inventory_items DROP CONSTRAINT IF EXISTS psy_inventory_items_issue_unit_check;
ALTER TABLE psy_inventory_items ADD COLUMN IF NOT EXISTS issue_unit TEXT;
ALTER TABLE psy_inventory_items ADD COLUMN IF NOT EXISTS issue_units_per_stock_unit NUMERIC(10,4);
ALTER TABLE psy_inventory_items ALTER COLUMN qty_in_stock TYPE NUMERIC(12,4);
ALTER TABLE psy_inventory_stock_by_location ALTER COLUMN qty_in_stock TYPE NUMERIC(12,4);
ALTER TABLE psy_stock_movements ALTER COLUMN qty TYPE NUMERIC(12,4);
ALTER TABLE psy_stock_movements ALTER COLUMN balance_after TYPE NUMERIC(12,4);

-- Nilai lapuk dibuang drpd senarai dibenarkan — tukar row sedia ada DULU
-- sebelum constraint baharu (lagi ketat) ditambah di bawah.
UPDATE psy_inventory_items SET unit = 'Pcs' WHERE unit = 'Biji (pcs)';
UPDATE psy_inventory_items SET issue_unit = 'Pcs' WHERE issue_unit = 'Biji (pcs)';

ALTER TABLE psy_inventory_items ADD CONSTRAINT psy_inventory_items_unit_check
  CHECK (unit IN ('Pcs','Botol','Kotak','Pek','Tiub','Tablet',
                   'Kapsul','Set','Gulung','Beg','Pasang','Unit','Gram','Kg','Naskhah','Gelas',
                   'Liter (L)','Mililiter (ml)','Inci (inch)','Sentimeter (cm)','Milimeter (mm)'));
ALTER TABLE psy_inventory_items ADD CONSTRAINT psy_inventory_items_issue_unit_check
  CHECK (issue_unit IS NULL OR issue_unit IN ('Pcs','Botol','Kotak','Pek','Tiub','Tablet',
                   'Kapsul','Set','Gulung','Beg','Pasang','Unit','Gram','Kg','Naskhah','Gelas',
                   'Liter (L)','Mililiter (ml)','Inci (inch)','Sentimeter (cm)','Milimeter (mm)'));
COMMENT ON COLUMN psy_inventory_items.issue_unit IS
  'Unit diberi kepada pesakit, jika berbeza drpd unit stok (cth stok=Gulung, issue_unit=Inci). NULL = tiada tukaran.';
COMMENT ON COLUMN psy_inventory_items.issue_units_per_stock_unit IS
  'Berapa issue_unit dalam 1 unit stok (cth 30 = 1 Gulung ada 30 Inci). Guna utk tukar kuantiti diberi pesakit kpd pecahan unit stok semasa tolak.';

-- 29 Okt 2026 (bahagian 3) — Tambah lokasi stok "Printing" (bahan/cetakan).
INSERT INTO psy_inventory_locations (name, code, is_default) VALUES
  ('Printing', 'PRINT', false)
ON CONFLICT (name) DO NOTHING;

-- 29 Okt 2026 (bahagian 4) — psy_inventory_locations SELECT-sahaja -> FOR ALL,
-- supaya "+ Tambah Lokasi Baharu" di item-form.html boleh insert (dulu cuma
-- staff BACA sahaja dibenarkan, tambah lokasi mesti manual via SQL).
DROP POLICY IF EXISTS "Staff read locations" ON psy_inventory_locations;
DROP POLICY IF EXISTS "Staff manage locations" ON psy_inventory_locations;
CREATE POLICY "Staff manage locations" ON psy_inventory_locations FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
