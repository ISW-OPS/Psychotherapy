-- ═══════════════════════════════════════════════════════════════════
-- MIGRASI: Modul DNA Test (OH MY GENE / ATGC)
-- Run SEKALI di Supabase SQL Editor (testing & prod).
-- Kandungan:
--   A) RBAC — daftar modul dna_test + grant super_admin/manager/admin/coach
--      (bukan doctor — DNA Test dikendalikan oleh coach sahaja)
--   B) Bucket storage 'dna-test' + polisi staff
--   C) Jadual + trigger modul (salinan database/schema/26_dna_test.sql)
-- ═══════════════════════════════════════════════════════════════════

-- ──── A) RBAC — modul dna_test ────
INSERT INTO psy_modules (code, label, icon, scope, sort_order) VALUES
  ('dna_test', 'DNA Test', '🧬', 'staff', 84)
ON CONFLICT (code) DO UPDATE SET
  label = EXCLUDED.label, icon = EXCLUDED.icon,
  scope = EXCLUDED.scope, sort_order = EXCLUDED.sort_order;

-- Semua action boleh ditick (tiada cell "—")
INSERT INTO psy_module_actions (module_code, action_code)
SELECT 'dna_test', code FROM psy_actions
ON CONFLICT DO NOTHING;

-- Grant: super_admin/manager/admin (akses pentadbiran biasa) + coach (jalankan proses)
INSERT INTO psy_role_module_actions (role_code, module_code, action_code)
SELECT r, 'dna_test', a
FROM unnest(ARRAY['super_admin','manager','admin','coach']) r
CROSS JOIN unnest(ARRAY['view','create','edit','delete','export']) a
ON CONFLICT DO NOTHING;

-- Tetapan: super_admin + manager sahaja
INSERT INTO psy_role_module_actions (role_code, module_code, action_code) VALUES
  ('super_admin', 'dna_test', 'settings'),
  ('manager',     'dna_test', 'settings')
ON CONFLICT DO NOTHING;

-- ──── B) Bucket storage 'dna-test' ────
INSERT INTO storage.buckets (id, name, public) VALUES ('dna-test', 'dna-test', false)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "dna_test_staff_all" ON storage.objects;
CREATE POLICY "dna_test_staff_all" ON storage.objects
    FOR ALL TO authenticated
    USING (bucket_id = 'dna-test' AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
    WITH CHECK (bucket_id = 'dna-test' AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- ──── C0) Pastikan helper RLS wujud (DB lama mungkin belum ada) ────
CREATE OR REPLACE FUNCTION public.isw_is_staff()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.psy_profiles
    WHERE id = auth.uid() AND role = 'staff'
  );
$$;

GRANT EXECUTE ON FUNCTION public.isw_is_staff() TO authenticated;

-- ──── C) Jadual + trigger (salinan schema/26_dna_test.sql) ────
-- ═══════════════════════════════════════════════════════════════════
-- 26 — DNA TEST (OH MY GENE / ATGC)
-- Proses ujian DNA per-pesakit: Sample Collection → Barcode & Packaging
-- → Activate Kit (ATGC) → Muat Naik Laporan → Consultation → Completed.
-- Jadual: psy_dna_test_process (satu baris = satu proses ujian DNA).
-- Nota: Consultation (Step 5) reuse psy_appointments sedia ada
--       (service='DNA Test Consultation'), rujuk via appointment_id.
-- ═══════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS psy_dna_test_process (
  id                              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id                      UUID NOT NULL REFERENCES psy_patients(id) ON DELETE CASCADE,
  coach_id                        UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  current_step                    INT NOT NULL DEFAULT 1 CHECK (current_step BETWEEN 1 AND 6),
  status                          TEXT NOT NULL DEFAULT 'in_progress'
                                    CHECK (status IN ('in_progress','completed','cancelled')),

  -- Step 1: Sample Collection
  kit_received_at                 DATE,
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
  sample_sent_to_lab_at           DATE,

  -- Step 3: Activate Kit (ATGC — portal luar, dikemaskini manual)
  atgc_status                     TEXT DEFAULT 'not_activated' CHECK (atgc_status IN ('not_activated','activated')),
  atgc_activated_at               TIMESTAMPTZ,
  atgc_activated_by               UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,

  -- Step 4: Muat Naik Laporan DNA (dari portal ATGC — boleh >1 fail setiap kategori)
  report_files                    JSONB DEFAULT '{}'::jsonb,
  report_notes                    TEXT,
  reports_uploaded_at              TIMESTAMPTZ,
  lab_report_issued_at            DATE,
  reports_emailed_at              TIMESTAMPTZ,

  -- Step 5: Consultation (reuse psy_appointments)
  appointment_id                  UUID REFERENCES psy_appointments(id) ON DELETE SET NULL,
  consultation_prep_checklist     JSONB DEFAULT '{}'::jsonb,
  consultation_notes              TEXT,
  consultation_marked_ready_at    TIMESTAMPTZ,
  consultation_attachments        JSONB DEFAULT '[]'::jsonb,

  -- Step 6: Completed
  completed_at                    TIMESTAMPTZ,
  completed_by                    UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,

  created_by                      UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  created_at                      TIMESTAMPTZ DEFAULT now(),
  updated_at                      TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_dna_test_patient ON psy_dna_test_process(patient_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_dna_test_status  ON psy_dna_test_process(status);

ALTER TABLE psy_dna_test_process ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "dna_test staff manage" ON psy_dna_test_process;
CREATE POLICY "dna_test staff manage" ON psy_dna_test_process FOR ALL
  USING (isw_is_staff()) WITH CHECK (isw_is_staff());

DROP POLICY IF EXISTS "dna_test patient read own" ON psy_dna_test_process;
CREATE POLICY "dna_test patient read own" ON psy_dna_test_process FOR SELECT
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

CREATE OR REPLACE FUNCTION dna_test_touch_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END; $$;

DROP TRIGGER IF EXISTS trg_dna_test_touch ON psy_dna_test_process;
CREATE TRIGGER trg_dna_test_touch BEFORE UPDATE ON psy_dna_test_process
  FOR EACH ROW EXECUTE FUNCTION dna_test_touch_updated_at();
