-- ═══════════════════════════════════════════════════════════════════
-- 43 — PACKAGE SUPPLY INVOICE HEADER (nombor invois tetap per pakej)
-- Satu baris per (patient_id, plan_id) — pegang SATU nombor invois rasmi
-- yang kekal sepanjang pakej tu, walau berapa kali bekalan ditambah
-- lepas tu. Kandungan penuh invois (senarai produk + rekod mingguan)
-- TIDAK disimpan di sini — ia dikira secara LIVE setiap kali dibuka,
-- dengan menggabungkan semua baris psy_supply_invoices (42_supply_invoices.sql)
-- bagi plan_id yang sama. Jadual ni cuma "pemegang nombor".
--
-- Dicipta lazy (get-or-create) oleh shared/supplyInvoice.js
-- getOrCreatePackageSupplyInvoiceNo() — dipanggil SEKALI sebaik bekalan
-- PERTAMA pakej tu diberi (dari createSupplyInvoice()), supaya nombor
-- wujud dari transaksi pertama walau staff belum buka paparan invois lagi.
-- ═══════════════════════════════════════════════════════════════════

CREATE SEQUENCE IF NOT EXISTS psy_package_supply_invoice_no_seq START 1;

CREATE TABLE IF NOT EXISTS psy_package_supply_invoices (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  invoice_no    TEXT UNIQUE,
  patient_id    UUID NOT NULL REFERENCES psy_patients(id),
  plan_id       UUID NOT NULL REFERENCES psy_treatment_plans(id) ON DELETE CASCADE,
  created_at    TIMESTAMPTZ DEFAULT now(),
  UNIQUE (patient_id, plan_id)
);

CREATE INDEX IF NOT EXISTS idx_package_supply_invoices_patient ON psy_package_supply_invoices(patient_id);

ALTER TABLE psy_package_supply_invoices ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Patients read own package supply invoices" ON psy_package_supply_invoices;
CREATE POLICY "Patients read own package supply invoices" ON psy_package_supply_invoices FOR SELECT
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Staff manage package supply invoices" ON psy_package_supply_invoices;
CREATE POLICY "Staff manage package supply invoices" ON psy_package_supply_invoices FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

CREATE OR REPLACE FUNCTION psy_assign_package_supply_invoice_no() RETURNS trigger AS $$
BEGIN
  IF NEW.invoice_no IS NULL THEN
    NEW.invoice_no := 'INV-BK-' || lpad(nextval('psy_package_supply_invoice_no_seq')::text, 4, '0');
  END IF;
  RETURN NEW;
END $$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_psy_assign_package_supply_invoice_no ON psy_package_supply_invoices;
CREATE TRIGGER trg_psy_assign_package_supply_invoice_no BEFORE INSERT ON psy_package_supply_invoices
  FOR EACH ROW EXECUTE FUNCTION psy_assign_package_supply_invoice_no();

COMMENT ON TABLE psy_package_supply_invoices IS
  'Pemegang nombor invois bekalan PAKEJ (satu nombor tetap per patient_id+plan_id). Kandungan invois dikira live dari psy_supply_invoices, bukan disimpan di sini.';
