-- Audit management 23 Sept 2026 (#F-23, Tier 3→5 — sengaja ditangguh di Tier 3,
-- kini dibuat) — Pisah Invoice/Receipt/Payment jadi 3 jadual berasingan.
-- Rujuk: database/schema/06_payments.sql (sumber kebenaran, dah dikemaskini).
--
-- PENDEKATAN: tambahan sahaja (additive) — psy_payments KEKAL bentuk sedia ada,
-- SEMUA laluan tulis sedia ada (webhook gateway, autocharge ansuran, GHL sync,
-- entri manual staf KOB/kedai) TAK disentuh langsung. Cuma denda tidak hadir
-- (plan-week.html) dipindah guna psy_invoices sebenar (kod app dikemaskini
-- berasingan, bukan dalam migration ni).

-- ──── 1. Betulkan trigger invoice_no sedia ada (elak nombor berganda) ────
ALTER TABLE psy_payments ADD COLUMN IF NOT EXISTS invoice_id UUID;

CREATE OR REPLACE FUNCTION psy_assign_payment_invoice_no() RETURNS trigger AS $$
BEGIN
  IF NEW.invoice_no IS NULL AND NEW.status IN ('pending','completed')
     AND (NEW.intent ->> 'kob_session_id') IS NULL
     AND NEW.invoice_id IS NULL THEN
    NEW.invoice_no := 'INV-' || lpad(nextval('psy_invoice_no_seq')::text, 6, '0');
  END IF;
  RETURN NEW;
END $$ LANGUAGE plpgsql;

-- ──── 2. psy_receipts — trigger-created sahaja, tiada laluan client INSERT ────
CREATE TABLE IF NOT EXISTS psy_receipts (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  payment_id UUID NOT NULL UNIQUE REFERENCES psy_payments(id) ON DELETE CASCADE,
  patient_id UUID REFERENCES psy_patients(id),
  receipt_no TEXT,
  total      NUMERIC(10,2) NOT NULL,
  issued_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  pdf_url    TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_psy_receipts_patient ON psy_receipts(patient_id);

ALTER TABLE psy_receipts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Patients read own receipts" ON psy_receipts;
CREATE POLICY "Patients read own receipts" ON psy_receipts FOR SELECT
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Staff read all receipts" ON psy_receipts;
CREATE POLICY "Staff read all receipts" ON psy_receipts FOR SELECT
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

CREATE OR REPLACE FUNCTION trg_create_receipt_on_payment_completed()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NEW.status = 'completed' AND (TG_OP = 'INSERT' OR OLD.status IS DISTINCT FROM 'completed') THEN
    INSERT INTO psy_receipts (payment_id, patient_id, receipt_no, total, pdf_url)
    VALUES (NEW.id, NEW.patient_id, NEW.receipt_no, NEW.total, NEW.receipt_url)
    ON CONFLICT (payment_id) DO NOTHING;
  END IF;
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE LOG 'trg_create_receipt_on_payment_completed: %', SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_create_receipt_on_payment_completed ON psy_payments;
CREATE TRIGGER trg_create_receipt_on_payment_completed
  AFTER INSERT OR UPDATE OF status ON psy_payments
  FOR EACH ROW EXECUTE FUNCTION trg_create_receipt_on_payment_completed();

-- Backfill sejarah — semua bayaran 'completed' sedia ada dapat rekod resit serta-merta.
INSERT INTO psy_receipts (payment_id, patient_id, receipt_no, total, pdf_url, issued_at)
SELECT id, patient_id, receipt_no, total, receipt_url, COALESCE(paid_at, created_at)
FROM psy_payments WHERE status = 'completed'
ON CONFLICT (payment_id) DO NOTHING;

-- ──── 3. psy_invoices — amaun tertunggak, boleh wujud sebelum sebarang bayaran ────
CREATE TABLE IF NOT EXISTS psy_invoices (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  invoice_no  TEXT UNIQUE,
  patient_id  UUID NOT NULL REFERENCES psy_patients(id),
  description TEXT NOT NULL,
  amount      NUMERIC(10,2) NOT NULL CHECK (amount > 0),
  status      TEXT NOT NULL DEFAULT 'unpaid' CHECK (status IN ('unpaid','partially_paid','paid','void')),
  source_type TEXT,
  source_ref  TEXT,
  created_by  UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  created_at  TIMESTAMPTZ DEFAULT now(),
  updated_at  TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_psy_invoices_patient ON psy_invoices(patient_id, status);

ALTER TABLE psy_invoices ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Patients read own invoices" ON psy_invoices;
CREATE POLICY "Patients read own invoices" ON psy_invoices FOR SELECT
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Staff manage invoices" ON psy_invoices;
CREATE POLICY "Staff manage invoices" ON psy_invoices FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

CREATE OR REPLACE FUNCTION psy_assign_invoice_no() RETURNS trigger AS $$
BEGIN
  IF NEW.invoice_no IS NULL THEN
    NEW.invoice_no := 'INV-' || lpad(nextval('psy_invoice_no_seq')::text, 6, '0');
  END IF;
  RETURN NEW;
END $$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_psy_assign_invoice_no ON psy_invoices;
CREATE TRIGGER trg_psy_assign_invoice_no BEFORE INSERT ON psy_invoices
  FOR EACH ROW EXECUTE FUNCTION psy_assign_invoice_no();

ALTER TABLE psy_payments DROP CONSTRAINT IF EXISTS psy_payments_invoice_id_fkey;
ALTER TABLE psy_payments ADD CONSTRAINT psy_payments_invoice_id_fkey
  FOREIGN KEY (invoice_id) REFERENCES psy_invoices(id);
CREATE INDEX IF NOT EXISTS idx_psy_payments_invoice ON psy_payments(invoice_id);

CREATE OR REPLACE FUNCTION trg_update_invoice_status_on_payment()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_amount NUMERIC;
  v_paid   NUMERIC;
BEGIN
  IF NEW.invoice_id IS NULL THEN RETURN NEW; END IF;
  SELECT amount INTO v_amount FROM psy_invoices WHERE id = NEW.invoice_id;
  IF v_amount IS NULL THEN RETURN NEW; END IF;
  SELECT COALESCE(SUM(total), 0) INTO v_paid FROM psy_payments
    WHERE invoice_id = NEW.invoice_id AND status = 'completed';
  UPDATE psy_invoices SET
    status = CASE
      WHEN v_paid <= 0 THEN 'unpaid'
      WHEN v_paid + 0.005 >= v_amount THEN 'paid'
      ELSE 'partially_paid'
    END,
    updated_at = now()
  WHERE id = NEW.invoice_id AND status <> 'void';
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE LOG 'trg_update_invoice_status_on_payment: %', SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_update_invoice_status_on_payment ON psy_payments;
CREATE TRIGGER trg_update_invoice_status_on_payment
  AFTER INSERT OR UPDATE OF status ON psy_payments
  FOR EACH ROW EXECUTE FUNCTION trg_update_invoice_status_on_payment();
