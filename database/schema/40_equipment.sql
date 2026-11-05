-- ═══════════════════════════════════════════════════════════════════
-- 40 — EQUIPMENT STORE + PERMINTAAN MAINTENANCE
-- psy_equipment: rekod peralatan (berasingan dari item inventori)
-- psy_equipment_documents: lampiran (invois, waranti, manual, foto)
-- psy_equipment_maintenance: staf lapor masalah → manager lulus/tolak → selesai
-- Kod peralatan (EQ-0001...) & no. permohonan (MR-2026-00001...) dijana DB.
-- Asal: migration 20261008-20261012 (digabung ke schema bersih).
-- ═══════════════════════════════════════════════════════════════════

CREATE SEQUENCE IF NOT EXISTS psy_equipment_code_seq;
CREATE SEQUENCE IF NOT EXISTS psy_maint_request_seq;

CREATE TABLE IF NOT EXISTS psy_equipment (
  id                       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name                     TEXT NOT NULL,
  code                     TEXT UNIQUE DEFAULT 'EQ-' || lpad(nextval('psy_equipment_code_seq')::text, 4, '0'),
  location_id              UUID REFERENCES psy_inventory_locations(id) ON DELETE SET NULL,
  category                 TEXT,
  -- storage_location: lokasi fizikal/bilik peralatan (cth "IT Room", "Treatment
  -- Room") dari senarai tetap shared/equipmentMasterData.js — BERBEZA drpd
  -- location_id (rujuk psy_inventory_locations, gudang stok konsumabel spt
  -- "General Inventory"/"Clinical Pharmacy", bukan bilik). location_id tak
  -- pernah terdedah di UI (equipment-add.html) setakat ni.
  storage_location         TEXT,
  brand                    TEXT,
  model                    TEXT,
  serial_no                TEXT,
  description              TEXT,
  purchase_date            DATE,
  purchase_cost            NUMERIC(12,2),
  warranty_expiry          DATE,
  condition                TEXT CHECK (condition IS NULL OR condition IN ('good','fair','poor')),
  supplier                 TEXT,
  supplier_id              UUID REFERENCES psy_suppliers(id) ON DELETE SET NULL,
  invoice_no               TEXT,
  po_no                    TEXT,
  remarks                  TEXT,
  assigned_to_name         TEXT,
  last_service_date        DATE,
  next_maintenance_date    DATE,
  maintenance_cycle_months INT,
  maintenance_remarks      TEXT,
  image_url                TEXT,
  status                   TEXT NOT NULL DEFAULT 'available'
                           CHECK (status IN ('available','in_use','under_maintenance','damaged','lost','retired')),
  notes                    TEXT,
  created_at               TIMESTAMPTZ DEFAULT now(),
  updated_at               TIMESTAMPTZ DEFAULT now()
);

-- 5 Nov 2026 — supplier_id FK (equipment-add.html Pembekal kini dropdown dari
-- psy_suppliers, bukan free text) — kolum `supplier` TEXT lama DIKEKALKAN
-- (equipment-detail.html papar terus drpd situ, tiada join perlu), cuma
-- diisi dari nama supplier yg dipilih.
ALTER TABLE psy_equipment ADD COLUMN IF NOT EXISTS supplier_id UUID REFERENCES psy_suppliers(id) ON DELETE SET NULL;
ALTER TABLE psy_equipment ADD COLUMN IF NOT EXISTS storage_location TEXT;

CREATE TABLE IF NOT EXISTS psy_equipment_documents (
  id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  equipment_id       UUID NOT NULL REFERENCES psy_equipment(id) ON DELETE CASCADE,
  file_name          TEXT NOT NULL,
  file_path          TEXT NOT NULL,
  file_size          BIGINT,
  file_type          TEXT,
  uploaded_by        UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  uploaded_by_name   TEXT,
  created_at         TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS psy_equipment_maintenance (
  id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  equipment_id       UUID NOT NULL REFERENCES psy_equipment(id) ON DELETE CASCADE,
  request_no         TEXT UNIQUE
                     DEFAULT 'MR-' || to_char(now(), 'YYYY') || '-' || lpad(nextval('psy_maint_request_seq')::text, 5, '0'),
  issue              TEXT NOT NULL,
  request_type       TEXT,
  issue_category     TEXT,
  priority           TEXT CHECK (priority IS NULL OR priority IN ('low','medium','high','urgent')),
  preferred_date     DATE,
  notes              TEXT,
  photo_url          TEXT,
  status             TEXT NOT NULL DEFAULT 'baru'
                     CHECK (status IN ('baru','diluluskan','dalam_servis','selesai','ditolak')),
  reported_by        UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  reported_by_name   TEXT,
  manager_note       TEXT,
  handled_by         UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  handled_by_name    TEXT,
  handled_at         TIMESTAMPTZ,
  scheduled_date     DATE,
  created_at         TIMESTAMPTZ DEFAULT now(),
  updated_at         TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_equip_maint_status    ON psy_equipment_maintenance (status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_equip_maint_equipment ON psy_equipment_maintenance (equipment_id);
CREATE INDEX IF NOT EXISTS idx_equip_docs_equipment  ON psy_equipment_documents (equipment_id);

ALTER TABLE psy_equipment             ENABLE ROW LEVEL SECURITY;
ALTER TABLE psy_equipment_documents   ENABLE ROW LEVEL SECURITY;
ALTER TABLE psy_equipment_maintenance ENABLE ROW LEVEL SECURITY;

-- Staff boleh baca peralatan
DROP POLICY IF EXISTS "staff read equipment" ON psy_equipment;
CREATE POLICY "staff read equipment" ON psy_equipment FOR SELECT
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- Manager/admin urus peralatan (tambah, ubah)
DROP POLICY IF EXISTS "manager manage equipment" ON psy_equipment;
CREATE POLICY "manager manage equipment" ON psy_equipment FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff' AND staff_role IN ('super_admin','admin','manager')))
  WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff' AND staff_role IN ('super_admin','admin','manager')));

-- Staff boleh baca & lapor masalah
DROP POLICY IF EXISTS "staff read maintenance" ON psy_equipment_maintenance;
CREATE POLICY "staff read maintenance" ON psy_equipment_maintenance FOR SELECT
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "staff report maintenance" ON psy_equipment_maintenance;
CREATE POLICY "staff report maintenance" ON psy_equipment_maintenance FOR INSERT
  WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff') AND reported_by = auth.uid());

-- Manager/admin kemaskini status (lulus/tolak/selesai)
DROP POLICY IF EXISTS "manager update maintenance" ON psy_equipment_maintenance;
CREATE POLICY "manager update maintenance" ON psy_equipment_maintenance FOR UPDATE
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff' AND staff_role IN ('super_admin','admin','manager')))
  WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff' AND staff_role IN ('super_admin','admin','manager')));

-- Lampiran dokumen
DROP POLICY IF EXISTS "staff read equipment docs" ON psy_equipment_documents;
CREATE POLICY "staff read equipment docs" ON psy_equipment_documents FOR SELECT
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "manager manage equipment docs" ON psy_equipment_documents;
CREATE POLICY "manager manage equipment docs" ON psy_equipment_documents FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff' AND staff_role IN ('super_admin','admin','manager')))
  WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff' AND staff_role IN ('super_admin','admin','manager')));

-- ───────────────────────────────────────────────────────────────────
-- RBAC: modul 'equipment' (Equipment Store)
-- Coach: lihat + lapor masalah. Manager/Admin/Super Admin: view, create, edit.
-- ───────────────────────────────────────────────────────────────────
INSERT INTO psy_modules (code, label, icon, scope, sort_order) VALUES
  ('equipment', 'Equipment Store', '🛠️', 'staff', 112)
ON CONFLICT (code) DO UPDATE SET label = EXCLUDED.label, icon = EXCLUDED.icon;

INSERT INTO psy_module_actions (module_code, action_code) VALUES
  ('equipment', 'view'), ('equipment', 'create'), ('equipment', 'edit')
ON CONFLICT DO NOTHING;

INSERT INTO psy_role_module_actions (role_code, module_code, action_code) VALUES
  ('coach',       'equipment', 'view'),
  ('coach',       'equipment', 'create'),
  ('manager',     'equipment', 'view'),
  ('manager',     'equipment', 'create'),
  ('manager',     'equipment', 'edit'),
  ('admin',       'equipment', 'view'),
  ('admin',       'equipment', 'create'),
  ('admin',       'equipment', 'edit'),
  ('super_admin', 'equipment', 'view'),
  ('super_admin', 'equipment', 'create'),
  ('super_admin', 'equipment', 'edit')
ON CONFLICT DO NOTHING;
