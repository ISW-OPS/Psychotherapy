-- Modul Suppliers (P18-20) — supplier jadi entiti sendiri, bukan lagi teks
-- bebas dalam psy_inventory_items.supplier_info. Lihat
-- database/schema/32_suppliers.sql (sumber kebenaran) + 24_storage.sql
-- (bucket supplier-docs) utk versi penuh + nota.

CREATE TABLE IF NOT EXISTS psy_suppliers (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  supplier_code       TEXT UNIQUE,
  supplier_type       TEXT NOT NULL DEFAULT 'supplier'
                      CHECK (supplier_type IN ('supplier','manufacturer','distributor','service_provider')),
  name                TEXT NOT NULL,
  registration_no     TEXT,
  gst_no              TEXT,
  tax_type            TEXT,
  currency            TEXT NOT NULL DEFAULT 'MYR',
  category            TEXT,
  is_preferred        BOOLEAN NOT NULL DEFAULT false,
  status              TEXT NOT NULL DEFAULT 'active'
                      CHECK (status IN ('active','inactive','blacklisted')),
  phone               TEXT,
  mobile              TEXT,
  email               TEXT,
  fax                 TEXT,
  website             TEXT,
  address             TEXT,
  city                TEXT,
  state               TEXT,
  postcode            TEXT,
  country             TEXT DEFAULT 'Malaysia',
  business_nature     TEXT,
  payment_terms       TEXT,
  credit_limit        NUMERIC(12,2),
  min_order_amount    NUMERIC(12,2),
  lead_time_days      INT,
  bank_name           TEXT,
  bank_account_no     TEXT,
  bank_account_name   TEXT,
  notes               TEXT,
  created_by          UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_by_name     TEXT,
  updated_by          UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  updated_by_name     TEXT,
  created_at          TIMESTAMPTZ DEFAULT now(),
  updated_at          TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_suppliers_status ON psy_suppliers(status);
CREATE INDEX IF NOT EXISTS idx_suppliers_name   ON psy_suppliers(name);

CREATE SEQUENCE IF NOT EXISTS psy_supplier_code_seq START 1;

CREATE OR REPLACE FUNCTION psy_set_supplier_code()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.supplier_code IS NULL THEN
    NEW.supplier_code := 'SUP-' || LPAD(nextval('psy_supplier_code_seq')::text, 4, '0');
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_psy_set_supplier_code ON psy_suppliers;
CREATE TRIGGER trg_psy_set_supplier_code
BEFORE INSERT ON psy_suppliers
FOR EACH ROW EXECUTE FUNCTION psy_set_supplier_code();

CREATE TABLE IF NOT EXISTS psy_supplier_contacts (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  supplier_id   UUID NOT NULL REFERENCES psy_suppliers(id) ON DELETE CASCADE,
  name          TEXT NOT NULL,
  position      TEXT,
  phone         TEXT,
  email         TEXT,
  created_at    TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_supplier_contacts_supplier ON psy_supplier_contacts(supplier_id);

CREATE TABLE IF NOT EXISTS psy_supplier_documents (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  supplier_id       UUID NOT NULL REFERENCES psy_suppliers(id) ON DELETE CASCADE,
  file_name         TEXT NOT NULL,
  file_path         TEXT NOT NULL,
  file_size         INT,
  uploaded_by_name  TEXT,
  created_at        TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_supplier_documents_supplier ON psy_supplier_documents(supplier_id);

ALTER TABLE psy_inventory_items ADD COLUMN IF NOT EXISTS supplier_id UUID REFERENCES psy_suppliers(id) ON DELETE SET NULL;

ALTER TABLE psy_suppliers ENABLE ROW LEVEL SECURITY;
ALTER TABLE psy_supplier_contacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE psy_supplier_documents ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff manage suppliers" ON psy_suppliers;
CREATE POLICY "Staff manage suppliers" ON psy_suppliers FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "Staff manage supplier contacts" ON psy_supplier_contacts;
CREATE POLICY "Staff manage supplier contacts" ON psy_supplier_contacts FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "Staff manage supplier documents" ON psy_supplier_documents;
CREATE POLICY "Staff manage supplier documents" ON psy_supplier_documents FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- Storage bucket + policy
INSERT INTO storage.buckets (id, name, public) VALUES ('supplier-docs', 'supplier-docs', false)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "supplier_docs_staff_all" ON storage.objects;
CREATE POLICY "supplier_docs_staff_all" ON storage.objects
    FOR ALL TO authenticated
    USING (bucket_id = 'supplier-docs' AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
    WITH CHECK (bucket_id = 'supplier-docs' AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
