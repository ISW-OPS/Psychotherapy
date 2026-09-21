-- No. resit (REC10001..) & no. invois (INV-000001..) berjujukan + diskaun.
-- receipt_ref KEKAL kunci teknikal (webhook, nama fail PDF, redirect) — receipt_no hanya utk paparan.

ALTER TABLE psy_payments ADD COLUMN IF NOT EXISTS receipt_no TEXT;
ALTER TABLE psy_payments ADD COLUMN IF NOT EXISTS discount NUMERIC(10,2) NOT NULL DEFAULT 0;
ALTER TABLE psy_kob_sessions ADD COLUMN IF NOT EXISTS package_discount NUMERIC(12,2) NOT NULL DEFAULT 0;
ALTER TABLE psy_kob_sessions ADD COLUMN IF NOT EXISTS invoice_no TEXT;

CREATE SEQUENCE IF NOT EXISTS psy_receipt_no_seq START 10001;
CREATE SEQUENCE IF NOT EXISTS psy_invoice_no_seq START 1;

CREATE OR REPLACE FUNCTION psy_assign_receipt_no() RETURNS trigger AS $$
BEGIN
  IF NEW.status = 'completed' AND NEW.receipt_no IS NULL THEN
    NEW.receipt_no := 'REC' || nextval('psy_receipt_no_seq');
  END IF;
  RETURN NEW;
END $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION psy_assign_invoice_no() RETURNS trigger AS $$
BEGIN
  IF NEW.recommended_package_id IS NOT NULL AND NEW.invoice_no IS NULL THEN
    NEW.invoice_no := 'INV-' || lpad(nextval('psy_invoice_no_seq')::text, 6, '0');
  END IF;
  RETURN NEW;
END $$ LANGUAGE plpgsql;

-- Backfill rekod sedia ada ikut susunan masa. Trigger pengguna dimatikan sementara
-- supaya trigger promo/referral/baucar (AFTER UPDATE) tak menyala semula.
ALTER TABLE psy_payments DISABLE TRIGGER USER;
ALTER TABLE psy_kob_sessions DISABLE TRIGGER USER;
DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN SELECT id FROM psy_payments WHERE status = 'completed' AND receipt_no IS NULL
           ORDER BY COALESCE(paid_at, created_at), created_at, id LOOP
    UPDATE psy_payments SET receipt_no = 'REC' || nextval('psy_receipt_no_seq') WHERE id = r.id;
  END LOOP;
  FOR r IN SELECT id FROM psy_kob_sessions WHERE recommended_package_id IS NOT NULL AND invoice_no IS NULL
           ORDER BY created_at, id LOOP
    UPDATE psy_kob_sessions SET invoice_no = 'INV-' || lpad(nextval('psy_invoice_no_seq')::text, 6, '0') WHERE id = r.id;
  END LOOP;
END $$;
ALTER TABLE psy_payments ENABLE TRIGGER USER;
ALTER TABLE psy_kob_sessions ENABLE TRIGGER USER;

CREATE UNIQUE INDEX IF NOT EXISTS uq_psy_payments_receipt_no ON psy_payments(receipt_no);
CREATE UNIQUE INDEX IF NOT EXISTS uq_psy_kob_sessions_invoice_no ON psy_kob_sessions(invoice_no);

DROP TRIGGER IF EXISTS trg_psy_assign_receipt_no ON psy_payments;
CREATE TRIGGER trg_psy_assign_receipt_no BEFORE INSERT OR UPDATE OF status ON psy_payments
  FOR EACH ROW EXECUTE FUNCTION psy_assign_receipt_no();

DROP TRIGGER IF EXISTS trg_psy_assign_invoice_no ON psy_kob_sessions;
CREATE TRIGGER trg_psy_assign_invoice_no BEFORE INSERT OR UPDATE OF recommended_package_id ON psy_kob_sessions
  FOR EACH ROW EXECUTE FUNCTION psy_assign_invoice_no();

NOTIFY pgrst, 'reload schema';
