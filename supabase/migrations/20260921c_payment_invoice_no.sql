-- Invois auto (INV-…) untuk SEMUA bayaran bukan-pakej-KOB. Jalankan selepas 20260921 & 20260921b.
ALTER TABLE psy_payments ADD COLUMN IF NOT EXISTS invoice_no TEXT;
CREATE SEQUENCE IF NOT EXISTS psy_invoice_no_seq START 1;

CREATE OR REPLACE FUNCTION psy_assign_payment_invoice_no() RETURNS trigger AS $$
BEGIN
  IF NEW.invoice_no IS NULL AND NEW.status IN ('pending','completed')
     AND (NEW.intent ->> 'kob_session_id') IS NULL THEN
    NEW.invoice_no := 'INV-' || lpad(nextval('psy_invoice_no_seq')::text, 6, '0');
  END IF;
  RETURN NEW;
END $$ LANGUAGE plpgsql;

-- Backfill ikut masa (trigger pengguna dimatikan sementara supaya trigger promo/referral/baucar tak menyala semula)
ALTER TABLE psy_payments DISABLE TRIGGER USER;
DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN SELECT id FROM psy_payments
           WHERE invoice_no IS NULL AND status IN ('pending','completed') AND (intent ->> 'kob_session_id') IS NULL
           ORDER BY COALESCE(paid_at, created_at), created_at, id LOOP
    UPDATE psy_payments SET invoice_no = 'INV-' || lpad(nextval('psy_invoice_no_seq')::text, 6, '0') WHERE id = r.id;
  END LOOP;
END $$;
ALTER TABLE psy_payments ENABLE TRIGGER USER;

CREATE UNIQUE INDEX IF NOT EXISTS uq_psy_payments_invoice_no ON psy_payments(invoice_no);

DROP TRIGGER IF EXISTS trg_psy_assign_payment_invoice_no ON psy_payments;
CREATE TRIGGER trg_psy_assign_payment_invoice_no BEFORE INSERT OR UPDATE OF status ON psy_payments
  FOR EACH ROW EXECUTE FUNCTION psy_assign_payment_invoice_no();

NOTIFY pgrst, 'reload schema';
