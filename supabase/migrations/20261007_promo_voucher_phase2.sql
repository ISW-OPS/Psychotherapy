-- ═══════════════════════════════════════════════════════════════════
-- Fasa 2 — Promo & Voucher (staff web)
-- Lock 6 Okt 2026:
--   • Cannot Stack untuk MVP → can_combine (kolum `stackable`) default FALSE
--   • Medan baharu: max_discount, show_on_shop, customer_eligibility, selected_patient_ids
--   • Voucher: voucher_code (kod unik), title, min_subtotal, applies_to(+values), issued_by
-- Guna ALTER ... IF NOT EXISTS supaya selamat dijalankan semula.
-- ═══════════════════════════════════════════════════════════════════

-- ──── psy_promo_codes ────
ALTER TABLE psy_promo_codes
  ADD COLUMN IF NOT EXISTS name                  TEXT,           -- nama promosi (cth "New Patient 10% Off")
  ADD COLUMN IF NOT EXISTS max_discount          NUMERIC(10,2),
  ADD COLUMN IF NOT EXISTS show_on_shop          BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS customer_eligibility  TEXT NOT NULL DEFAULT 'all',
  ADD COLUMN IF NOT EXISTS selected_patient_ids  UUID[];

ALTER TABLE psy_promo_codes DROP CONSTRAINT IF EXISTS psy_promo_codes_max_discount_check;
ALTER TABLE psy_promo_codes ADD CONSTRAINT psy_promo_codes_max_discount_check
  CHECK (max_discount IS NULL OR max_discount > 0);

ALTER TABLE psy_promo_codes DROP CONSTRAINT IF EXISTS psy_promo_codes_customer_eligibility_check;
ALTER TABLE psy_promo_codes ADD CONSTRAINT psy_promo_codes_customer_eligibility_check
  CHECK (customer_eligibility IN ('all','new','existing','selected'));

-- Backfill: kod lama yang ditanda pelanggan baharu → 'new'
UPDATE psy_promo_codes SET customer_eligibility = 'new'
  WHERE new_customer_only = true AND customer_eligibility = 'all';

-- MVP: tak boleh gabung secara lalai
ALTER TABLE psy_promo_codes ALTER COLUMN stackable SET DEFAULT false;

-- ──── psy_vouchers ────
-- voucher_code: DEFAULT jana kod sendiri supaya laluan sedia ada (trigger rujukan,
-- redeem_point_reward) yang insert tanpa kod tak pecah. Default volatile → setiap baris dapat kod sendiri.
ALTER TABLE psy_vouchers
  ADD COLUMN IF NOT EXISTS voucher_code  TEXT NOT NULL DEFAULT ('VC' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8))),
  ADD COLUMN IF NOT EXISTS title         TEXT,
  ADD COLUMN IF NOT EXISTS min_subtotal  NUMERIC(10,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS applies_to    TEXT NOT NULL DEFAULT 'all',
  ADD COLUMN IF NOT EXISTS applies_to_values TEXT[],
  ADD COLUMN IF NOT EXISTS issued_by     UUID REFERENCES psy_profiles(id) ON DELETE SET NULL;

ALTER TABLE psy_vouchers DROP CONSTRAINT IF EXISTS psy_vouchers_applies_to_check;
ALTER TABLE psy_vouchers ADD CONSTRAINT psy_vouchers_applies_to_check
  CHECK (applies_to IN ('all','product','category','package'));

CREATE UNIQUE INDEX IF NOT EXISTS idx_psy_vouchers_voucher_code ON psy_vouchers(voucher_code);

-- Masa mula & tamat promosi (lalai 00:00 hingga 23:59:59, masa tempatan Malaysia)
ALTER TABLE psy_promo_codes
  ADD COLUMN IF NOT EXISTS start_time TIME NOT NULL DEFAULT '00:00:00',
  ADD COLUMN IF NOT EXISTS end_time   TIME NOT NULL DEFAULT '23:59:59';
