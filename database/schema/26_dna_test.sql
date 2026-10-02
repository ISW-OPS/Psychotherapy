-- ═══════════════════════════════════════════════════════════════════
-- 26 — DNA TEST (OH MY GENE / ATGC)
-- Proses ujian DNA per-pesakit: Sample Collection → Barcode & Packaging
-- → Activate Kit (ATGC) → Muat Naik Laporan → Consultation → Completed.
-- Jadual: psy_dna_test_process (satu baris = satu proses ujian DNA).
-- Nota: bucket storage 'dna-test' didaftar dalam 24_storage.sql.
-- Nota: Consultation (Step 5) reuse psy_appointments sedia ada
--       (service='DNA Test Consultation'), rujuk via appointment_id.
-- ═══════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS psy_dna_test_process (
  id                              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id                      UUID NOT NULL REFERENCES psy_patients(id) ON DELETE CASCADE,
  coach_id                        UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  -- Ditambah 24 Sept 2026 (audit management #B1-7/8 Tier 4) — pautan ke pelan
  -- rawatan yang cetus proses ni, supaya boleh kira "berapa proses DNA test dah
  -- dicipta utk pelan ni" (banding dgn pakej.dna_test_count) sebelum auto-cipta lagi.
  plan_id                         UUID REFERENCES psy_treatment_plans(id) ON DELETE SET NULL,
  current_step                    INT NOT NULL DEFAULT 1 CHECK (current_step BETWEEN 1 AND 6),
  status                          TEXT NOT NULL DEFAULT 'in_progress'
                                    CHECK (status IN ('in_progress','completed','cancelled')),

  -- Step 1: Sample Collection
  kit_received_at                 DATE,       -- tarikh pesakit terima DNA Test Kit
  sample_appointment_id           UUID REFERENCES psy_appointments(id) ON DELETE SET NULL,
                                               -- janji temu pesakit datang ambil sampel (reuse psy_appointments, macam Step 5)
  sample_reminder_sent_at         TIMESTAMPTZ, -- dedup peringatan WA sehari sebelum tarikh janji temu sampel
  sample_checklist                JSONB DEFAULT '{}'::jsonb,
  sample_notes                    TEXT,
  sample_collected_at             TIMESTAMPTZ,
  sample_collected_by             UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,

  -- Step 2: Barcode & Packaging
  barcode_number                  TEXT,
  packaging_checklist             JSONB DEFAULT '{}'::jsonb,
  sample_photo_path               TEXT,
  packaging_notes                 TEXT,
  packaging_completed_at          TIMESTAMPTZ,
  sample_sent_to_lab_at           DATE,       -- tarikh sample dihantar ke makmal

  -- Step 3: Activate Kit (ATGC — portal luar, dikemaskini manual)
  atgc_status                     TEXT DEFAULT 'not_activated' CHECK (atgc_status IN ('not_activated','activated')),
  atgc_activated_at               TIMESTAMPTZ,
  atgc_activated_by               UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  -- Coach yang URUSKAN langkah ni (dipilih staf via dropdown) — BEZA drpd
  -- atgc_activated_by (akaun yang literal klik butang, cth Customer Service
  -- boleh klik bagi pihak coach). Audit management batch (30 Sept 2026).
  atgc_coach_id                   UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,

  -- Step 4: Muat Naik Laporan DNA (dari portal ATGC — boleh >1 fail setiap kategori)
  -- report_files: {"plant_based": ["path1","path2"], "health_risk": [...], "carrier_drug": [...], "summary": [...]}
  report_files                    JSONB DEFAULT '{}'::jsonb,
  -- report_files_meta: {"path1": {"uploaded_at": "...", "uploaded_by": "uuid", "uploaded_by_name": "..."}}
  -- Berasingan drpd report_files (bukan ubah bentuk sedia ada — elak pecahkan
  -- consumer lain cth rekod-perubatan.html yg jangka array string path).
  report_files_meta               JSONB DEFAULT '{}'::jsonb,
  report_notes                    TEXT,
  reports_uploaded_at              TIMESTAMPTZ,
  lab_report_issued_at            DATE,       -- tarikh laporan dikeluarkan oleh lab (bukan tarikh upload)
  reports_emailed_at              TIMESTAMPTZ, -- tarikh laporan dihantar ke pesakit via emel
  -- Staff yg uruskan muat naik/susulan laporan langkah ni (dipilih via dropdown) —
  -- sama corak macam atgc_coach_id (Step 3), supaya setiap langkah ada "siapa handle".
  report_handler_id               UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,

  -- Step 5: Consultation (reuse psy_appointments)
  appointment_id                  UUID REFERENCES psy_appointments(id) ON DELETE SET NULL,
  consultation_prep_checklist     JSONB DEFAULT '{}'::jsonb,
  consultation_notes              TEXT,
  consultation_marked_ready_at    TIMESTAMPTZ,
  consultation_attachments        JSONB DEFAULT '[]'::jsonb,  -- lampiran bebas (skrip/nota/dll) khusus proses ni

  -- Step 6: Completed
  completed_at                    TIMESTAMPTZ,
  completed_by                    UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,

  created_by                      UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  created_at                      TIMESTAMPTZ DEFAULT now(),
  updated_at                      TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_dna_test_patient ON psy_dna_test_process(patient_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_dna_test_status  ON psy_dna_test_process(status);
CREATE INDEX IF NOT EXISTS idx_dna_test_plan    ON psy_dna_test_process(plan_id) WHERE plan_id IS NOT NULL;

ALTER TABLE psy_dna_test_process ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "dna_test staff manage" ON psy_dna_test_process;
CREATE POLICY "dna_test staff manage" ON psy_dna_test_process FOR ALL
  USING (isw_is_staff()) WITH CHECK (isw_is_staff());

DROP POLICY IF EXISTS "dna_test patient read own" ON psy_dna_test_process;
CREATE POLICY "dna_test patient read own" ON psy_dna_test_process FOR SELECT
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

-- ──── Fungsi trigger: updated_at ────
CREATE OR REPLACE FUNCTION dna_test_touch_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END; $$;

DROP TRIGGER IF EXISTS trg_dna_test_touch ON psy_dna_test_process;
CREATE TRIGGER trg_dna_test_touch BEFORE UPDATE ON psy_dna_test_process
  FOR EACH ROW EXECUTE FUNCTION dna_test_touch_updated_at();

COMMENT ON COLUMN psy_dna_test_process.atgc_status IS
  'ATGC = portal lab luar (ohmygene). Diaktifkan manual oleh coach di luar sistem, status dikemaskini manual selepas itu.';
