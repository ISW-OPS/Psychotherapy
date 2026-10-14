-- Tambah lajur gateway_channel — channel SEBENAR pesakit guna di gateway
-- (fpx/card/paynow_online/dll), diambil dari HitPay GET /payment-requests/{id}
-- (medan payments[].payment_type) selepas webhook disahkan. Webhook form-encoded
-- lama (verifyWebhook) cuma bawa status/amount/reference — tiada channel.
-- Rujuk: supabase/functions/_shared/payments/hitpay.ts (getPaymentChannel),
-- supabase/functions/payments-webhook/index.ts (pemanggil, best-effort).
ALTER TABLE psy_payments ADD COLUMN IF NOT EXISTS gateway_channel TEXT;

COMMENT ON COLUMN psy_payments.gateway_channel IS
  'Channel sebenar di gateway (cth "card", "fpx", "paynow_online") — khusus payment_method=''gateway''. '
  'NULL utk bayaran lama (sebelum migration ni) atau kalau panggilan enrich gagal/belum sempat jalan.';
