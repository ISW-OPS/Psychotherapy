-- Purchase Request: Staff ID (registration_no sedia ada) + lampiran invois/resit.
-- Jalankan sekali di TESTING dan PROD. Selamat run berulang (IF NOT EXISTS / ON CONFLICT).

ALTER TABLE psy_inventory_requests ADD COLUMN IF NOT EXISTS requested_by_staff_code TEXT;

CREATE TABLE IF NOT EXISTS psy_inventory_request_attachments (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id        UUID NOT NULL REFERENCES psy_inventory_requests(id) ON DELETE CASCADE,
  file_name         TEXT NOT NULL,
  file_path         TEXT NOT NULL,
  file_size         BIGINT,
  file_type         TEXT,
  uploaded_by       UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  uploaded_by_name  TEXT,
  created_at        TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_inv_request_attachments_request ON psy_inventory_request_attachments(request_id);

ALTER TABLE psy_inventory_request_attachments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff manage request attachments" ON psy_inventory_request_attachments;
CREATE POLICY "Staff manage request attachments" ON psy_inventory_request_attachments FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- Guna semula bucket 'stock-in-docs' sedia ada (dah wujud, staff-only) — tiada bucket/polisi baharu diperlukan.
