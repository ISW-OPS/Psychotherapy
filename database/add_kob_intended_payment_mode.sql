-- Migration: intended_payment_mode
-- Additive only — new nullable column, no changes to existing data.
-- Safe to re-run.
-- Run on testing (ipmemyiz) first, verify di kob-detail.html (wizSelectPlan) +
-- kob.html (self-checkout), lepas tu run pada prod (xmvqvq).

ALTER TABLE psy_kob_sessions
  ADD COLUMN IF NOT EXISTS intended_payment_mode TEXT
    CHECK (intended_payment_mode IN ('full','installment','manual_installment'));

COMMENT ON COLUMN psy_kob_sessions.intended_payment_mode IS
  'Plan staff PILIH utk pesakit di wizard kob-detail.html (wizSelectPlan, Langkah 4) — SEBELUM
   sebarang bayaran cuba dibuat. Beza dengan package_payment_mode (hanya diisi SELEPAS bayaran
   berjaya). Dibaca oleh kob.html (roles/patient) utk papar butang self-checkout yang sepadan:
   installment = "Bayar Deposit Ansuran" (payments-kob-initiate, deposit amount), full/NULL =
   "Bayar Sekarang" (payments-initiate, harga penuh), manual_installment = kekal WhatsApp sahaja
   (jadual staff-entered, tiada formula deposit utk self-checkout).';
