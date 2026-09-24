-- Audit management 23 Sept 2026, Tier 5 (#G-33, #G-34) — penjejakan "dibaca"
-- pengumuman (impression-based, bila muncul di dashboard/senarai pesakit).
-- Rujuk: database/schema/19_events_announcements.sql

CREATE TABLE IF NOT EXISTS psy_announcement_reads (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  announcement_id UUID NOT NULL REFERENCES psy_announcements(id) ON DELETE CASCADE,
  patient_id      UUID NOT NULL REFERENCES psy_patients(id) ON DELETE CASCADE,
  read_at         TIMESTAMPTZ DEFAULT now(),
  UNIQUE (announcement_id, patient_id)
);

CREATE INDEX IF NOT EXISTS idx_ann_reads_ann ON psy_announcement_reads(announcement_id);

ALTER TABLE psy_announcement_reads ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Patients mark own reads" ON psy_announcement_reads;
CREATE POLICY "Patients mark own reads" ON psy_announcement_reads FOR INSERT
  WITH CHECK (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Patients view own reads" ON psy_announcement_reads;
CREATE POLICY "Patients view own reads" ON psy_announcement_reads FOR SELECT
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Staff view all reads" ON psy_announcement_reads;
CREATE POLICY "Staff view all reads" ON psy_announcement_reads FOR SELECT
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
