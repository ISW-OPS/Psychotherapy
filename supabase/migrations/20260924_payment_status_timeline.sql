-- Audit management 23 Sept 2026, Tier 3 (#B1-25/26, item 2 of 3 previously scoped out):
-- Status Timeline — jejak SETIAP perubahan status bayaran, bukan cuma status terkini.
-- Rujuk: database/schema/06_payments.sql

CREATE TABLE IF NOT EXISTS psy_payment_status_log (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  payment_id  UUID NOT NULL REFERENCES psy_payments(id) ON DELETE CASCADE,
  old_status  TEXT,
  new_status  TEXT NOT NULL,
  changed_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_payment_status_log_payment ON psy_payment_status_log(payment_id, changed_at);

ALTER TABLE psy_payment_status_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff read payment status log" ON psy_payment_status_log;
CREATE POLICY "Staff read payment status log" ON psy_payment_status_log FOR SELECT
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

CREATE OR REPLACE FUNCTION trg_log_payment_status()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO psy_payment_status_log (payment_id, old_status, new_status) VALUES (NEW.id, NULL, NEW.status);
  ELSIF TG_OP = 'UPDATE' AND NEW.status IS DISTINCT FROM OLD.status THEN
    INSERT INTO psy_payment_status_log (payment_id, old_status, new_status) VALUES (NEW.id, OLD.status, NEW.status);
  END IF;
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE LOG 'trg_log_payment_status: %', SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_log_payment_status ON psy_payments;
CREATE TRIGGER trg_log_payment_status
  AFTER INSERT OR UPDATE OF status ON psy_payments
  FOR EACH ROW EXECUTE FUNCTION trg_log_payment_status();

-- Backfill sekali sahaja — bayaran sedia ada dapat SATU baris "current status"
-- (bukan sejarah penuh, sbb sejarah lama tak wujud, tapi baris ni supaya timeline
-- UI tak kosong terus utk rekod lama).
INSERT INTO psy_payment_status_log (payment_id, old_status, new_status, changed_at)
SELECT id, NULL, status, COALESCE(paid_at, created_at)
FROM psy_payments p
WHERE NOT EXISTS (SELECT 1 FROM psy_payment_status_log l WHERE l.payment_id = p.id);
