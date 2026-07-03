-- ════════════════════════════════════════════════════════════════
-- step77: Continuity package offers
-- Jalankan sekali di PROD (xmvqvq) via Supabase SQL Editor. Idempotent.
--
-- Coach cadang pakej sambungan kpd pesakit yang tinggal ≤4 minggu rawatan.
-- Tawaran tersimpan (bukan sekadar notifikasi) supaya coach nampak status.
-- Pesakit Terima → terus ke pembayaran (localStorage isw_pending_payment).
-- package_uuid = psy_packages.id (UUID yg app guna sbg active_package_id).
-- ════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS psy_continuity_offers (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id       UUID REFERENCES psy_treatment_plans(id) ON DELETE CASCADE,
  patient_id    UUID NOT NULL REFERENCES psy_patients(id) ON DELETE CASCADE,
  suggested_by  UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  package_uuid  UUID,
  package_name  TEXT,
  price         NUMERIC(10,2),
  note          TEXT,
  status        TEXT DEFAULT 'sent' CHECK (status IN ('sent','viewed','accepted','declined','cancelled')),
  created_at    TIMESTAMPTZ DEFAULT now(),
  responded_at  TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_psy_continuity_offers_patient
  ON psy_continuity_offers(patient_id, status, created_at DESC);

ALTER TABLE psy_continuity_offers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff manage continuity offers" ON psy_continuity_offers;
CREATE POLICY "Staff manage continuity offers" ON psy_continuity_offers FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "Patients read own continuity offers" ON psy_continuity_offers;
CREATE POLICY "Patients read own continuity offers" ON psy_continuity_offers FOR SELECT
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Patients respond own continuity offers" ON psy_continuity_offers;
CREATE POLICY "Patients respond own continuity offers" ON psy_continuity_offers FOR UPDATE
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

COMMENT ON TABLE psy_continuity_offers IS
  'Cadangan pakej sambungan oleh coach utk pesakit baki ≤4 minggu. Terima → pembayaran.';

SELECT 'step77 OK -- psy_continuity_offers ready' AS status;
