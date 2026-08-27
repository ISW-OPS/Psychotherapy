-- Migration: installment_full_price / today_installment_full_price
-- Additive only — new nullable columns, no changes to existing data.
-- Safe to re-run.
-- Run on testing (ipmemyiz) first, verify di pakej-edit.html tab Bayaran,
-- lepas tu run pada prod (xmvqvq).

ALTER TABLE psy_packages
  ADD COLUMN IF NOT EXISTS installment_full_price NUMERIC(10,2);

ALTER TABLE psy_packages
  ADD COLUMN IF NOT EXISTS today_installment_full_price NUMERIC(10,2);

COMMENT ON COLUMN psy_packages.installment_full_price IS
  'Harga "Penuh" rujukan utk pelan Ansuran tier Now — BUKAN sama dgn price (Harga Bayaran Penuh/Full Payment), biasanya LEBIH TINGGI (kos bayar ansuran). Jumlah Komitmen (deposit + baki bulanan) mesti sepadan dgn nilai ni, disahkan di editor pakej-edit.html.';

COMMENT ON COLUMN psy_packages.today_installment_full_price IS
  'Sama makna dgn installment_full_price tapi utk tier Today. NULL = fallback ke installment_full_price (tier Now).';
