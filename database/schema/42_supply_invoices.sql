-- ═══════════════════════════════════════════════════════════════════
-- 42 — SUPPLY INVOICES (invois bekalan produk kepada pesakit)
-- Invois BUKAN-DUIT dikeluarkan setiap kali produk/bekalan (cth madu)
-- diberi kepada pesakit — snapshot kuantiti diberi HARI INI + jumlah
-- dirancang seluruh pakej + baki SELEPAS pemberian ini. Snapshot kekal
-- (immutable) supaya sejarah tak berubah walau baki berubah kemudian.
--
-- Ditulis dari shared/supplyInvoice.js createSupplyInvoice() — dipanggil
-- SELEPAS addStockToLocation() (shared/inventoryStock.js) berjaya, dari
-- DUA laluan: "+ Bagi Bekalan" manual (roles/staff/patient-hub.html
-- submitSupply()) & auto-deduct lepas sesi Hadir (roles/staff/plan-week.html
-- applySupplyStock()). psy_stock_movements (36_stock_movements.sql) kekal
-- SUMBER KEBENARAN stok — jadual ni cuma dokumen invois, tak pernah ditulis
-- balik ke ledger.
-- ═══════════════════════════════════════════════════════════════════

CREATE SEQUENCE IF NOT EXISTS psy_supply_invoice_no_seq START 1;

CREATE TABLE IF NOT EXISTS psy_supply_invoices (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  invoice_no    TEXT UNIQUE,
  patient_id    UUID NOT NULL REFERENCES psy_patients(id),
  plan_id       UUID REFERENCES psy_treatment_plans(id) ON DELETE SET NULL,
  week_number   INT,
  source        TEXT NOT NULL DEFAULT 'manual' CHECK (source IN ('manual', 'auto_weekly')),
  -- items: [{item_id, name, unit, qty_given, qty_planned_total, qty_given_cumulative, qty_remaining}]
  items         JSONB NOT NULL DEFAULT '[]',
  given_by      UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  given_by_name TEXT,
  notes         TEXT,
  created_at    TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_supply_invoices_patient ON psy_supply_invoices(patient_id, created_at DESC);

ALTER TABLE psy_supply_invoices ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Patients read own supply invoices" ON psy_supply_invoices;
CREATE POLICY "Patients read own supply invoices" ON psy_supply_invoices FOR SELECT
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Staff manage supply invoices" ON psy_supply_invoices;
CREATE POLICY "Staff manage supply invoices" ON psy_supply_invoices FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

CREATE OR REPLACE FUNCTION psy_assign_supply_invoice_no() RETURNS trigger AS $$
BEGIN
  IF NEW.invoice_no IS NULL THEN
    NEW.invoice_no := 'INV-BKL-' || lpad(nextval('psy_supply_invoice_no_seq')::text, 6, '0');
  END IF;
  RETURN NEW;
END $$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_psy_assign_supply_invoice_no ON psy_supply_invoices;
CREATE TRIGGER trg_psy_assign_supply_invoice_no BEFORE INSERT ON psy_supply_invoices
  FOR EACH ROW EXECUTE FUNCTION psy_assign_supply_invoice_no();

COMMENT ON TABLE psy_supply_invoices IS
  'Invois bekalan produk (bukan duit) — snapshot kuantiti diberi + baki pakej setiap kali bekalan dikeluarkan kepada pesakit.';

-- Pautan terus dari baris ledger (psy_stock_movements) ke invois yg merekodkannya, supaya
-- UI sejarah bekalan boleh papar butang "Lihat Invois" terus tanpa carian masa/nama yg rapuh.
ALTER TABLE psy_stock_movements ADD COLUMN IF NOT EXISTS supply_invoice_id UUID REFERENCES psy_supply_invoices(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS idx_stock_movements_supply_invoice ON psy_stock_movements(supply_invoice_id);
