-- ISW — Part 3/4: Step 21-30
Run after part2_step11_20.sql.
-- Generated: 2026-06-12T04:04:17.895355Z
-- Total files: 10
-- Run this entire file in Supabase SQL Editor (new project).


-- ════════════════════════════════════════════════════════════════
-- step21_unregistered_status.sql
-- ════════════════════════════════════════════════════════════════

-- Step 21: New patient statuses — unregistered, archived, deceased
-- Run in Supabase SQL Editor after step20_soft_delete.sql

ALTER TABLE psy_patients DROP CONSTRAINT IF EXISTS psy_patients_status_check;
ALTER TABLE psy_patients ADD CONSTRAINT psy_patients_status_check
  CHECK (status IN ('pending_kyc','active','inactive','rejected','deleted','unregistered','archived','deceased'));

-- Add email column + index for fast auto-link lookup on patient signup
ALTER TABLE psy_patients ADD COLUMN IF NOT EXISTS email TEXT;
CREATE INDEX IF NOT EXISTS idx_psy_patients_email ON psy_patients(email);

-- Default status for new staff-created patients going forward is 'unregistered'
-- (no DB default change needed — handled in application layer)

SELECT 'Step 21 OK — unregistered / archived / deceased statuses added' AS status;


-- ════════════════════════════════════════════════════════════════
-- step22_session_type.sql
-- ════════════════════════════════════════════════════════════════

-- Add session_type and consultation_done status to psy_plan_weekly_progress

-- 1. Add session_type column (f2f / online)
ALTER TABLE psy_plan_weekly_progress
  ADD COLUMN IF NOT EXISTS session_type TEXT NOT NULL DEFAULT 'f2f'
  CHECK (session_type IN ('f2f', 'online'));

-- 2. Add consultation_done to status constraint
ALTER TABLE psy_plan_weekly_progress
  DROP CONSTRAINT IF EXISTS psy_plan_weekly_progress_status_check;

ALTER TABLE psy_plan_weekly_progress
  ADD CONSTRAINT psy_plan_weekly_progress_status_check
  CHECK (status IN ('pending', 'booked', 'hadir', 'consultation_done', 'reschedule', 'cancel', 'dna'));


-- ════════════════════════════════════════════════════════════════
-- step23_dna_reports.sql
-- ════════════════════════════════════════════════════════════════

-- DNA Reports table (idempotent)
CREATE TABLE IF NOT EXISTS psy_dna_reports (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id      UUID NOT NULL REFERENCES psy_patients(id) ON DELETE CASCADE,
  file_name       TEXT NOT NULL,
  file_path       TEXT NOT NULL,
  file_url        TEXT NOT NULL,
  notes           TEXT,
  uploaded_by     UUID REFERENCES auth.users(id),
  uploaded_by_name TEXT,
  uploaded_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE psy_dna_reports ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "staff_dna_all" ON psy_dna_reports FOR ALL
    USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "patient_dna_read" ON psy_dna_reports FOR SELECT
    USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;


-- ════════════════════════════════════════════════════════════════
-- step24_session_notes.sql
-- ════════════════════════════════════════════════════════════════

-- Merge coaching session notes into weekly progress (single source of truth)
ALTER TABLE psy_plan_weekly_progress
  ADD COLUMN IF NOT EXISTS notes           TEXT,
  ADD COLUMN IF NOT EXISTS mood_before     INT,
  ADD COLUMN IF NOT EXISTS mood_after      INT,
  ADD COLUMN IF NOT EXISTS goals_discussed TEXT[],
  ADD COLUMN IF NOT EXISTS homework_given  TEXT[],
  ADD COLUMN IF NOT EXISTS coach_id        UUID REFERENCES auth.users(id),
  ADD COLUMN IF NOT EXISTS coach_name      TEXT;


-- ════════════════════════════════════════════════════════════════
-- step27_inventory_tables.sql
-- ════════════════════════════════════════════════════════════════

-- Create psy_inventory_items and psy_inventory_requests tables
-- Run this if step17_inventory.sql was missing/corrupt

-- ── Inventory Items ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS psy_inventory_items (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name             TEXT NOT NULL,
  category         TEXT NOT NULL DEFAULT 'Bekalan Coaching',
  unit             TEXT NOT NULL DEFAULT 'unit',
  qty_in_stock     NUMERIC(10,2) NOT NULL DEFAULT 0,
  min_qty          NUMERIC(10,2) NOT NULL DEFAULT 5,
  requires_approval BOOLEAN NOT NULL DEFAULT false,
  notes            TEXT,
  created_at       TIMESTAMPTZ DEFAULT now(),
  updated_at       TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE psy_inventory_items ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "Staff read inventory items" ON psy_inventory_items
    FOR SELECT USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "Admin manage inventory items" ON psy_inventory_items
    FOR ALL USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff' AND staff_role IN ('admin','manager')));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ── Inventory Requests ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS psy_inventory_requests (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  item_id           UUID REFERENCES psy_inventory_items(id) ON DELETE SET NULL,
  item_name         TEXT NOT NULL,
  qty_requested     NUMERIC(10,2) NOT NULL,
  unit_price        NUMERIC(10,2),
  total_amount      NUMERIC(10,2),
  reason            TEXT,
  status            TEXT NOT NULL DEFAULT 'pending_approval'
                    CHECK (status IN ('pending_approval','approved','rejected','purchased')),
  requested_by      UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  requested_by_name TEXT NOT NULL DEFAULT '',
  approved_by       UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  approved_at       TIMESTAMPTZ,
  rejected_reason   TEXT,
  purchased_at      TIMESTAMPTZ,
  created_at        TIMESTAMPTZ DEFAULT now(),
  updated_at        TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE psy_inventory_requests ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "Staff read all requests" ON psy_inventory_requests
    FOR SELECT USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "Staff insert own requests" ON psy_inventory_requests
    FOR INSERT WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "Manager admin update requests" ON psy_inventory_requests
    FOR UPDATE USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff' AND staff_role IN ('admin','manager')));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;


-- ════════════════════════════════════════════════════════════════
-- step25_inventory_items.sql
-- ════════════════════════════════════════════════════════════════

-- ISW Default Inventory Items
-- Run this after step17_inventory.sql
-- Clears existing items and inserts fresh ISW defaults

DELETE FROM psy_inventory_items;

INSERT INTO psy_inventory_items (name, category, unit, qty_in_stock, min_qty, requires_approval, notes)
VALUES

-- ── MADU & PRODUK ─────────────────────────────────────────
('Lebah Thoharah (LTH)',            'Madu & Produk', 'kg',     0, 5,  false, 'Program NLC / JS / JS+ / EOL'),
('LTH Plus Green (LTHPG)',          'Madu & Produk', 'kg',     0, 5,  false, 'Program NLC / JS / JS+ / EOL'),
('Ibu Bumi (IB)',                   'Madu & Produk', 'kg',     0, 5,  false, 'Program OBD / OBP'),
('Young & Healthy Plus Green (YHPG)','Madu & Produk','kg',     0, 5,  false, 'Program OBD / OBP'),
('Madu Kelulut',                    'Madu & Produk', 'botol',  0, 3,  false, NULL),
('Minyak Zaitun Tulen',             'Madu & Produk', 'botol',  0, 3,  false, NULL),

-- ── STARTER KIT ───────────────────────────────────────────
('SDS OB',                          'Starter Kit',   'unit',   0, 5,  false, 'Starter kit OBD / OBP'),
('GHF',                             'Starter Kit',   'unit',   0, 5,  false, 'Starter kit OBD / OBP'),
('BNP',                             'Starter Kit',   'unit',   0, 5,  false, 'Bekalan pantang NLC / JS'),
('NSS',                             'Starter Kit',   'unit',   0, 5,  false, 'Bekalan pantang NLC / JS'),
('Voucher Konsultasi',              'Starter Kit',   'unit',   0, 10, false, 'Diedarkan semasa onboarding'),

-- ── SUPLEMEN & RESEPI ─────────────────────────────────────
('Resepi Superimun',                'Suplemen & Resepi', 'unit', 0, 5, false, 'Diberi semasa onboarding'),
('Resepi Superenergi',              'Suplemen & Resepi', 'unit', 0, 5, false, 'Diberi semasa onboarding'),
('Barley Organik',                  'Suplemen & Resepi', 'kg',   0, 5, false, NULL),
('Spirulina',                       'Suplemen & Resepi', 'botol',0, 3, false, NULL),
('Probiotik Advanced',              'Suplemen & Resepi', 'botol',0, 3, false, NULL),
('Magnesium Glycinate',             'Suplemen & Resepi', 'botol',0, 3, false, NULL),
('Vitamin D3',                      'Suplemen & Resepi', 'botol',0, 3, false, NULL),
('Omega-3 Fish Oil',                'Suplemen & Resepi', 'botol',0, 3, false, NULL),

-- ── BUKU & BAHAN CETAK ────────────────────────────────────
('Buku P101',                       'Buku & Bahan Cetak', 'naskhah', 0, 10, false, '7 buku per set starter kit'),
('List Pantang',                    'Buku & Bahan Cetak', 'naskhah', 0, 10, false, 'Diedarkan semasa onboarding'),
('Peta OB',                         'Buku & Bahan Cetak', 'naskhah', 0, 10, false, 'Diedarkan semasa onboarding OBD / OBP'),
('Workbook Refleksi Harian',        'Buku & Bahan Cetak', 'naskhah', 0, 10, false, NULL),
('Jadual Terapi Mingguan',          'Buku & Bahan Cetak', 'naskhah', 0, 10, false, NULL),
('Mood Tracker',                    'Buku & Bahan Cetak', 'naskhah', 0, 10, false, NULL),
('Buku Gaya Hidup Fitrah',          'Buku & Bahan Cetak', 'naskhah', 0,  5, false, NULL),
('Kitab Doa Syifa',                 'Buku & Bahan Cetak', 'naskhah', 0,  5, false, NULL),

-- ── BROSUR & MARKETING ────────────────────────────────────
('Brochure Madu',                   'Brosur & Marketing', 'unit', 0, 20, false, NULL),
('Brochure ISW',                    'Brosur & Marketing', 'unit', 0, 20, false, NULL),
('Brochure OB',                     'Brosur & Marketing', 'unit', 0, 20, false, NULL),

-- ── BEKALAN COACHING ──────────────────────────────────────
('Air Afiyah',                      'Bekalan Coaching', 'botol', 0, 10, false, '1 botol = 1.5L'),
('Air Za''afaran',                  'Bekalan Coaching', 'botol', 0,  5, false, 'Untuk sesi Perubatan Rohani'),
('Herba Kolon',                     'Bekalan Coaching', 'set',   0,  3, false, '1 set = 1 kursus rawatan'),
('Kurma Ajwa',                      'Bekalan Coaching', 'biji',  0, 50, false, '49 biji per pesakit 777 VIP'),

-- ── PERALATAN KLINIK ──────────────────────────────────────
('DNA Test Kit',                    'Peralatan Klinik', 'set',  0, 2, true,  'Perlu kelulusan · hantar ke lab luar'),
('Enema Kit',                       'Peralatan Klinik', 'set',  0, 3, true,  'Perlu kelulusan'),
('Mesin Ozon',                      'Peralatan Klinik', 'unit', 0, 1, true,  'Rekod nombor siri setiap unit')

;


-- ════════════════════════════════════════════════════════════════
-- step26_meet_link.sql
-- ════════════════════════════════════════════════════════════════

-- Add meet_link column to psy_plan_weekly_progress for online sessions
ALTER TABLE psy_plan_weekly_progress
  ADD COLUMN IF NOT EXISTS meet_link TEXT;


-- ════════════════════════════════════════════════════════════════
-- step28_clinic_closures.sql
-- ════════════════════════════════════════════════════════════════

-- ============================================================
-- step28_clinic_closures.sql
-- Calendar lock for public holidays, Hari Raya, and ad-hoc clinic closure days.
-- Booking flow checks this table to auto-block the date.
-- ============================================================

CREATE TABLE IF NOT EXISTS psy_clinic_closures (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  closure_date DATE NOT NULL,
  label       TEXT NOT NULL,
  category    TEXT NOT NULL DEFAULT 'public_holiday'
              CHECK (category IN ('public_holiday','hari_raya','clinic_closed','training','other')),
  is_recurring BOOLEAN NOT NULL DEFAULT false,  -- annual recurrence on same MM-DD
  notes       TEXT,
  created_by  UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at  TIMESTAMPTZ DEFAULT now(),
  updated_at  TIMESTAMPTZ DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS uniq_clinic_closure_date
  ON psy_clinic_closures (closure_date);

CREATE INDEX IF NOT EXISTS idx_clinic_closure_date
  ON psy_clinic_closures (closure_date);

ALTER TABLE psy_clinic_closures ENABLE ROW LEVEL SECURITY;

-- Everyone authenticated (staff + patient) can read — used by booking + patient dashboard
DO $$ BEGIN
  CREATE POLICY "Anyone read clinic closures" ON psy_clinic_closures
    FOR SELECT USING (auth.uid() IS NOT NULL);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Only admin/manager can mutate
DO $$ BEGIN
  CREATE POLICY "Admin manage clinic closures" ON psy_clinic_closures
    FOR ALL USING (
      EXISTS (SELECT 1 FROM psy_profiles
              WHERE id = auth.uid()
              AND role = 'staff'
              AND staff_role IN ('admin','manager'))
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;


-- ════════════════════════════════════════════════════════════════
-- step29_kyc_proxy.sql
-- ════════════════════════════════════════════════════════════════

-- ============================================================
-- step29_kyc_proxy.sql
-- Track whether KYC submission was filled by patient themselves
-- or by a representative (pewaris/keluarga) — for review attention.
-- ============================================================

ALTER TABLE psy_kyc_submissions
  ADD COLUMN IF NOT EXISTS submitted_by_proxy BOOLEAN NOT NULL DEFAULT false;

COMMENT ON COLUMN psy_kyc_submissions.submitted_by_proxy IS
  'true = wakil/keluarga isi borang ini (info mesti tepat & boleh disahkan dengan pesakit sebenar)';


-- ════════════════════════════════════════════════════════════════
-- step30_outcome_status.sql
-- ════════════════════════════════════════════════════════════════

-- ============================================================
-- step30_outcome_status.sql
-- Clinical outcome status for reporting & statistics.
-- Separate from system 'status' (active/inactive) — this is treatment outcome.
-- ============================================================

ALTER TABLE psy_patients
  ADD COLUMN IF NOT EXISTS outcome_status TEXT
  CHECK (outcome_status IN ('otw','berhenti','meninggal','completed'));

ALTER TABLE psy_patients
  ADD COLUMN IF NOT EXISTS outcome_status_at TIMESTAMPTZ;

ALTER TABLE psy_patients
  ADD COLUMN IF NOT EXISTS outcome_status_notes TEXT;

CREATE INDEX IF NOT EXISTS idx_psy_patients_outcome_status
  ON psy_patients (outcome_status) WHERE outcome_status IS NOT NULL;

COMMENT ON COLUMN psy_patients.outcome_status IS
  'Clinical outcome: otw=On-going Treatment, berhenti=stopped, meninggal=passed away, completed=selesai rawatan';
