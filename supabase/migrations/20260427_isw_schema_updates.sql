-- =============================================================
-- ISW Schema Updates — Run in Supabase SQL Editor
-- Date: 2026-04-27
-- =============================================================

-- ── 1. psy_patients — add optional profile columns ───────────
ALTER TABLE psy_patients
  ADD COLUMN IF NOT EXISTS marital_status TEXT,
  ADD COLUMN IF NOT EXISTS occupation     TEXT,
  ADD COLUMN IF NOT EXISTS full_name      TEXT,
  ADD COLUMN IF NOT EXISTS dob            DATE,
  ADD COLUMN IF NOT EXISTS gender         TEXT;

-- ── 2. psy_products — image upload ───────────────────────────
ALTER TABLE psy_products
  ADD COLUMN IF NOT EXISTS image_url TEXT;

-- ── 3. psy_packages — image upload ───────────────────────────
ALTER TABLE psy_packages
  ADD COLUMN IF NOT EXISTS image_url TEXT;

-- ── 4. psy_plan_weekly_progress — Google Meet link ───────────
ALTER TABLE psy_plan_weekly_progress
  ADD COLUMN IF NOT EXISTS meet_link          TEXT,
  ADD COLUMN IF NOT EXISTS feedback_rating    SMALLINT,
  ADD COLUMN IF NOT EXISTS feedback_comment   TEXT,
  ADD COLUMN IF NOT EXISTS feedback_at        TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS updated_at         TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS updated_by_name    TEXT;

-- ── 5. psy_notifications ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS psy_notifications (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  type        TEXT NOT NULL DEFAULT 'system',
  title       TEXT NOT NULL,
  body        TEXT,
  link        TEXT,
  is_read     BOOLEAN NOT NULL DEFAULT FALSE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_notifications_user ON psy_notifications(user_id, is_read);

-- ── 6. psy_payments ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS psy_payments (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  receipt_ref    TEXT NOT NULL,
  patient_id     UUID REFERENCES psy_patients(id) ON DELETE SET NULL,
  user_id        UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  items          JSONB DEFAULT '[]',
  subtotal       NUMERIC(10,2) NOT NULL DEFAULT 0,
  service_charge NUMERIC(10,2) NOT NULL DEFAULT 0,
  sst            NUMERIC(10,2) NOT NULL DEFAULT 0,
  total          NUMERIC(10,2) NOT NULL DEFAULT 0,
  payment_method TEXT,
  status         TEXT NOT NULL DEFAULT 'completed',
  paid_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_payments_patient ON psy_payments(patient_id);
CREATE INDEX IF NOT EXISTS idx_payments_paid_at ON psy_payments(paid_at DESC);

-- ── 7. psy_package_purchases ─────────────────────────────────
CREATE TABLE IF NOT EXISTS psy_package_purchases (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id     UUID NOT NULL REFERENCES psy_patients(id) ON DELETE CASCADE,
  package_id     TEXT NOT NULL,
  package_name   TEXT,
  price          NUMERIC(10,2) NOT NULL DEFAULT 0,
  expires_at     TIMESTAMPTZ,
  status         TEXT NOT NULL DEFAULT 'active',
  payment_method TEXT,
  purchased_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_pkg_purchases_patient ON psy_package_purchases(patient_id);

-- ── 8. psy_announcements (patient dashboard carousel) ────────
CREATE TABLE IF NOT EXISTS psy_announcements (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title      TEXT NOT NULL,
  body       TEXT,
  tag        TEXT,
  cta_label  TEXT,
  cta_url    TEXT,
  bg         TEXT DEFAULT 'from-navy to-green-dark',
  is_active  BOOLEAN NOT NULL DEFAULT TRUE,
  sort_order SMALLINT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
INSERT INTO psy_announcements (title, body, tag, bg, is_active, sort_order)
VALUES (
  'Selamat Datang ke ISW',
  'Platform kesihatan holistik anda — rawatan BPS-S, coaching, dan lebih banyak lagi.',
  'Info',
  'from-navy to-green-dark',
  TRUE, 0
)
ON CONFLICT DO NOTHING;

-- ── 9. psy_plan_check_ins ────────────────────────────────────
CREATE TABLE IF NOT EXISTS psy_plan_check_ins (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id     UUID NOT NULL REFERENCES psy_treatment_plans(id) ON DELETE CASCADE,
  patient_id  UUID REFERENCES psy_patients(id) ON DELETE CASCADE,
  pillar      TEXT NOT NULL,
  goal_index  SMALLINT NOT NULL,
  goal_text   TEXT,
  week_number SMALLINT NOT NULL,
  checked_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_checkin_unique
  ON psy_plan_check_ins(plan_id, week_number, pillar, goal_index);

-- ── 10. psy_plan_compliance ──────────────────────────────────
CREATE TABLE IF NOT EXISTS psy_plan_compliance (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id      UUID NOT NULL REFERENCES psy_treatment_plans(id) ON DELETE CASCADE,
  patient_id   UUID REFERENCES psy_patients(id) ON DELETE CASCADE,
  week_number  SMALLINT NOT NULL,
  madu_sudu    SMALLINT,
  nafas_kali   SMALLINT,
  bumi_minit   SMALLINT,
  kelapa_kali  SMALLINT,
  kolon_kali   SMALLINT,
  berjemur     BOOLEAN,
  pantang      BOOLEAN,
  notes        TEXT,
  updated_by   UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_compliance_unique
  ON psy_plan_compliance(plan_id, week_number);

-- ── 11. psy_daily_checkins — ensure correct columns ──────────
ALTER TABLE psy_daily_checkins
  ADD COLUMN IF NOT EXISTS energy_score   SMALLINT,
  ADD COLUMN IF NOT EXISTS sleep_hours    NUMERIC(4,1),
  ADD COLUMN IF NOT EXISTS sleep_quality  SMALLINT,
  ADD COLUMN IF NOT EXISTS symptoms       JSONB DEFAULT '[]',
  ADD COLUMN IF NOT EXISTS activities     JSONB DEFAULT '[]',
  ADD COLUMN IF NOT EXISTS notes          TEXT;

-- ── 12. psy_risk_alerts — ensure columns ─────────────────────
ALTER TABLE psy_risk_alerts
  ADD COLUMN IF NOT EXISTS patient_name TEXT,
  ADD COLUMN IF NOT EXISTS description  TEXT,
  ADD COLUMN IF NOT EXISTS severity     TEXT DEFAULT 'medium';

-- ── 13. FK CASCADE on psy_patients delete ─────────────────────
-- These must be run if the FKs don't already cascade.
-- Check existing constraints first in Supabase → Table Editor → patient table.
-- If "psy_appointments_patient_id_fkey" does NOT cascade:
--   ALTER TABLE psy_appointments
--     DROP CONSTRAINT IF EXISTS psy_appointments_patient_id_fkey,
--     ADD CONSTRAINT psy_appointments_patient_id_fkey
--       FOREIGN KEY (patient_id) REFERENCES psy_patients(id) ON DELETE CASCADE;
-- Repeat for: psy_treatment_plans, psy_soap_notes, psy_vitals,
--   psy_daily_checkins, psy_coaching_sessions, psy_invoices,
--   psy_package_purchases, psy_plan_check_ins, psy_plan_compliance

-- ── 14. psy_orders — ensure columns ──────────────────────────
ALTER TABLE psy_orders
  ADD COLUMN IF NOT EXISTS order_ref       TEXT,
  ADD COLUMN IF NOT EXISTS delivery_method TEXT,
  ADD COLUMN IF NOT EXISTS delivery_address TEXT,
  ADD COLUMN IF NOT EXISTS courier         TEXT,
  ADD COLUMN IF NOT EXISTS tracking_number TEXT,
  ADD COLUMN IF NOT EXISTS paid_at         TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS shipped_at      TIMESTAMPTZ;

-- ── 15. RLS — enable on new tables ───────────────────────────
ALTER TABLE psy_notifications   ENABLE ROW LEVEL SECURITY;
ALTER TABLE psy_payments        ENABLE ROW LEVEL SECURITY;
ALTER TABLE psy_package_purchases ENABLE ROW LEVEL SECURITY;
ALTER TABLE psy_announcements   ENABLE ROW LEVEL SECURITY;
ALTER TABLE psy_plan_check_ins  ENABLE ROW LEVEL SECURITY;
ALTER TABLE psy_plan_compliance ENABLE ROW LEVEL SECURITY;

-- psy_notifications: each user sees only their own
CREATE POLICY IF NOT EXISTS "notif_own" ON psy_notifications
  FOR ALL USING (auth.uid() = user_id);

-- psy_payments: patient sees their own; staff sees all
CREATE POLICY IF NOT EXISTS "pay_own" ON psy_payments
  FOR SELECT USING (
    auth.uid() = user_id
    OR EXISTS (
      SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'
    )
  );
CREATE POLICY IF NOT EXISTS "pay_insert" ON psy_payments
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- psy_package_purchases: patient sees own; staff sees all
CREATE POLICY IF NOT EXISTS "pkgpur_patient" ON psy_package_purchases
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM psy_patients WHERE id = patient_id AND user_id = auth.uid())
    OR EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff')
  );
CREATE POLICY IF NOT EXISTS "pkgpur_insert" ON psy_package_purchases
  FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM psy_patients WHERE id = patient_id AND user_id = auth.uid())
    OR EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff')
  );
CREATE POLICY IF NOT EXISTS "pkgpur_update" ON psy_package_purchases
  FOR UPDATE USING (
    EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff')
  );

-- psy_announcements: anyone can read; only staff insert/update/delete
CREATE POLICY IF NOT EXISTS "ann_read" ON psy_announcements
  FOR SELECT USING (is_active = TRUE);
CREATE POLICY IF NOT EXISTS "ann_staff" ON psy_announcements
  FOR ALL USING (
    EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff')
  );

-- psy_plan_check_ins: patient sees own; staff sees all
CREATE POLICY IF NOT EXISTS "checkin_patient" ON psy_plan_check_ins
  FOR ALL USING (
    auth.uid() IN (
      SELECT user_id FROM psy_patients WHERE id = patient_id
    )
    OR EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff')
  );

-- psy_plan_compliance: staff full access; patient read-only
CREATE POLICY IF NOT EXISTS "compliance_staff" ON psy_plan_compliance
  FOR ALL USING (
    EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff')
  );
CREATE POLICY IF NOT EXISTS "compliance_patient_read" ON psy_plan_compliance
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM psy_treatment_plans tp
      JOIN psy_patients pa ON pa.id = tp.patient_id
      WHERE tp.id = plan_id AND pa.user_id = auth.uid()
    )
  );

-- ── 16. Storage — medical-reports bucket policy ───────────────
-- Run this to allow authenticated users to read their own documents:
-- INSERT INTO storage.buckets (id, name, public) VALUES ('medical-reports', 'medical-reports', false)
-- ON CONFLICT DO NOTHING;
--
-- CREATE POLICY IF NOT EXISTS "auth_read_medical" ON storage.objects
--   FOR SELECT USING (
--     bucket_id = 'medical-reports' AND auth.role() = 'authenticated'
--   );
-- CREATE POLICY IF NOT EXISTS "auth_insert_medical" ON storage.objects
--   FOR INSERT WITH CHECK (
--     bucket_id = 'medical-reports' AND auth.role() = 'authenticated'
--   );
