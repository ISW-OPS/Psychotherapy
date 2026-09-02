-- Letter Module: staff-as-requester + real approval workflow (draft/submitted/pending_approval/
-- revision_requested) + auto-issue for templates that don't need approval.
-- Rujuk database/schema/15_letters.sql untuk nota penuh.

ALTER TABLE psy_letter_templates ADD COLUMN IF NOT EXISTS department TEXT;

ALTER TABLE psy_letter_requests ALTER COLUMN patient_id DROP NOT NULL;
ALTER TABLE psy_letter_requests ALTER COLUMN patient_name DROP NOT NULL;
ALTER TABLE psy_letter_requests ADD COLUMN IF NOT EXISTS requester_type TEXT NOT NULL DEFAULT 'patient';
ALTER TABLE psy_letter_requests ADD COLUMN IF NOT EXISTS requested_by_staff_id UUID REFERENCES psy_profiles(id) ON DELETE SET NULL;
ALTER TABLE psy_letter_requests ADD COLUMN IF NOT EXISTS requested_by_staff_name TEXT;
ALTER TABLE psy_letter_requests ADD COLUMN IF NOT EXISTS revision_note TEXT;
ALTER TABLE psy_letter_requests ADD COLUMN IF NOT EXISTS recipient TEXT;

ALTER TABLE psy_letter_requests DROP CONSTRAINT IF EXISTS psy_letter_requests_requester_type_check;
ALTER TABLE psy_letter_requests ADD CONSTRAINT psy_letter_requests_requester_type_check
  CHECK (requester_type IN ('patient','staff'));

-- PENTING: constraint LAMA yang live sekarang cuma benarkan ('pending','issued','rejected','cancelled')
-- — 'pending_approval' pun tak sah di bawah constraint lama ni. Kena DROP constraint lama DULU
-- sebelum UPDATE data, barulah ADD constraint baru selepas data dah bersih.
ALTER TABLE psy_letter_requests DROP CONSTRAINT IF EXISTS psy_letter_requests_status_check;

-- Rekod lama guna status 'pending' — sepadankan ke 'pending_approval'.
UPDATE psy_letter_requests SET status = 'pending_approval' WHERE status = 'pending';

-- Jaring keselamatan: mana-mana rekod lama/seed guna status lain yang tak dikenali langsung
-- (bukan 'pending' pun) — sepadankan ke 'pending_approval' supaya staff boleh semak & proses
-- manual, bukan hilang senyap. Tanpa ni, ADD CONSTRAINT di bawah akan gagal setiap kali jumpa
-- rekod lama yang tak dijangka.
UPDATE psy_letter_requests SET status = 'pending_approval'
  WHERE status NOT IN ('draft','submitted','pending_approval','revision_requested','rejected','issued','cancelled');

ALTER TABLE psy_letter_requests ADD CONSTRAINT psy_letter_requests_status_check
  CHECK (status IN ('draft','submitted','pending_approval','revision_requested','rejected','issued','cancelled'));
ALTER TABLE psy_letter_requests ALTER COLUMN status SET DEFAULT 'draft';

CREATE INDEX IF NOT EXISTS idx_letter_req_staff ON psy_letter_requests(requested_by_staff_id);

DROP POLICY IF EXISTS "Staff manage own letter requests" ON psy_letter_requests;
CREATE POLICY "Staff manage own letter requests" ON psy_letter_requests
  FOR ALL USING (requested_by_staff_id = auth.uid())
  WITH CHECK (requested_by_staff_id = auth.uid());

-- Auto-issue: requester sendiri (pesakit/staff) insert psy_letter_issued terus utk request
-- kepunyaan mereka bila template tak perlukan kelulusan.
DROP POLICY IF EXISTS "issued_self_auto_insert" ON psy_letter_issued;
CREATE POLICY "issued_self_auto_insert" ON psy_letter_issued FOR INSERT
  WITH CHECK (
    request_id IN (
      SELECT id FROM psy_letter_requests
      WHERE (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()))
         OR (requested_by_staff_id = auth.uid())
    )
  );

DROP POLICY IF EXISTS "issued_self_read" ON psy_letter_issued;
CREATE POLICY "issued_self_read" ON psy_letter_issued FOR SELECT
  USING (
    request_id IN (SELECT id FROM psy_letter_requests WHERE requested_by_staff_id = auth.uid())
  );

-- ──── psy_letter_request_attachments ────
CREATE TABLE IF NOT EXISTS psy_letter_request_attachments (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id       UUID NOT NULL REFERENCES psy_letter_requests(id) ON DELETE CASCADE,
  file_name        TEXT NOT NULL,
  file_path        TEXT NOT NULL,
  file_size        INT,
  file_type        TEXT,
  uploaded_by      UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  uploaded_by_name TEXT,
  created_at       TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_letter_attach_request ON psy_letter_request_attachments(request_id);

ALTER TABLE psy_letter_request_attachments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "attach_staff_all" ON psy_letter_request_attachments;
CREATE POLICY "attach_staff_all" ON psy_letter_request_attachments FOR ALL
  USING (user_has_perm('communication','view'))
  WITH CHECK (user_has_perm('communication','create'));

DROP POLICY IF EXISTS "attach_self_all" ON psy_letter_request_attachments;
CREATE POLICY "attach_self_all" ON psy_letter_request_attachments FOR ALL
  USING (
    request_id IN (
      SELECT id FROM psy_letter_requests
      WHERE (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()))
         OR (requested_by_staff_id = auth.uid())
    )
  )
  WITH CHECK (
    request_id IN (
      SELECT id FROM psy_letter_requests
      WHERE (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()))
         OR (requested_by_staff_id = auth.uid())
    )
  );

-- ──── Storage: letter-attachments bucket ────
INSERT INTO storage.buckets (id, name, public) VALUES ('letter-attachments', 'letter-attachments', false)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "letter_attachments_staff_all" ON storage.objects;
CREATE POLICY "letter_attachments_staff_all" ON storage.objects
    FOR ALL TO authenticated
    USING (bucket_id = 'letter-attachments' AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
    WITH CHECK (bucket_id = 'letter-attachments' AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "letter_attachments_self_all" ON storage.objects;
CREATE POLICY "letter_attachments_self_all" ON storage.objects
    FOR ALL TO authenticated
    USING (
      bucket_id = 'letter-attachments'
      AND (storage.foldername(name))[1] IN (
        SELECT id::text FROM psy_letter_requests
        WHERE (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()))
           OR (requested_by_staff_id = auth.uid())
      )
    )
    WITH CHECK (
      bucket_id = 'letter-attachments'
      AND (storage.foldername(name))[1] IN (
        SELECT id::text FROM psy_letter_requests
        WHERE (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()))
           OR (requested_by_staff_id = auth.uid())
      )
    );
