-- ═══════════════════════════════════════════════════════════════════
-- 09 — KOB (KURSUS ORIENTASI BESTARI)
-- Jadual: psy_kob_sessions, psy_kob_agreements, psy_kob_slot_config
-- ═══════════════════════════════════════════════════════════════════

-- ──── psy_kob_sessions ────
-- Tempahan, kehadiran & nota sesi KOB.
CREATE TABLE IF NOT EXISTS psy_kob_sessions (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id          UUID NOT NULL REFERENCES psy_patients(id) ON DELETE CASCADE,
  scheduled_at        TIMESTAMPTZ NOT NULL,
  mode                TEXT NOT NULL DEFAULT 'f2f' CHECK (mode IN ('f2f','online')),
  meet_link           TEXT,
  status              TEXT NOT NULL DEFAULT 'booked'
                      CHECK (status IN ('booked','hadir','completed','reschedule','cancelled')),

  -- Doktor yang tanda kehadiran (mungkin berbeza dengan yang selesaikan)
  doctor_hadir_id     UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  doctor_hadir_name   TEXT,
  hadir_at            TIMESTAMPTZ,

  -- Doktor yang tanda selesai
  doctor_selesai_id   UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  doctor_selesai_name TEXT,
  selesai_at          TIMESTAMPTZ,

  -- Nota klinikal doktor
  notes               TEXT,
  -- Laporan / dokumen sokongan yang dimuat naik untuk KOB ini
  documents           JSONB DEFAULT '[]',

  -- Soal selidik berstruktur diisi doktor semasa sesi
  questionnaire       JSONB DEFAULT '{}',

  -- Cadangan pakej rawatan oleh doktor semasa KOB
  recommended_package_id    TEXT,
  recommended_package_name  TEXT,
  recommended_package_price NUMERIC(10,2),
  recommended_at            TIMESTAMPTZ,
  recommended_by            UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  recommended_by_name       TEXT,
  package_payment_status    TEXT DEFAULT 'pending'
                            CHECK (package_payment_status IN ('pending','partial','paid','skipped','declined','na')),
  package_paid_at           TIMESTAMPTZ,
  package_receipt_ref       TEXT,
  package_payment_mode      TEXT CHECK (package_payment_mode IN ('full','installment')),

  reschedule_count    INT NOT NULL DEFAULT 0,
  reschedule_reason   TEXT,

  created_at          TIMESTAMPTZ DEFAULT now(),
  updated_at          TIMESTAMPTZ DEFAULT now()
);

COMMENT ON COLUMN psy_kob_sessions.questionnaire IS
  'Structured Q&A captured during KOB. Keys: anak[], tidur{}, gaya_hidup{}, masalah_kesihatan{} — see kob-detail.html for shape.';

COMMENT ON COLUMN psy_kob_sessions.recommended_package_id IS
  'Package recommended by doctor during KOB. Patient must pay before agreement signing.';

CREATE INDEX IF NOT EXISTS idx_kob_patient ON psy_kob_sessions(patient_id);
CREATE INDEX IF NOT EXISTS idx_kob_scheduled ON psy_kob_sessions(scheduled_at);
CREATE INDEX IF NOT EXISTS idx_kob_status ON psy_kob_sessions(status);

ALTER TABLE psy_kob_sessions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Patient read own KOB" ON psy_kob_sessions;
CREATE POLICY "Patient read own KOB" ON psy_kob_sessions FOR SELECT
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Patient book own KOB" ON psy_kob_sessions;
CREATE POLICY "Patient book own KOB" ON psy_kob_sessions FOR INSERT
  WITH CHECK (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Patient reschedule own KOB" ON psy_kob_sessions;
CREATE POLICY "Patient reschedule own KOB" ON psy_kob_sessions FOR UPDATE
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Staff manage KOB sessions" ON psy_kob_sessions;
CREATE POLICY "Staff manage KOB sessions" ON psy_kob_sessions FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- ──── psy_kob_installments ────
-- Jadual ansuran pakej (Pelan Pelaburan Ansuran) bila
-- package_payment_mode = 'installment'. Dijana sekali semasa cadangan
-- pakej disahkan (bilangan ikut psy_packages.installment_count, tarikh due
-- ikut interval = duration_weeks / installment_count, ansuran terakhir
-- serap baki bulat). Tiap ansuran dipadan ke satu rekod psy_payments bila
-- staff sahkan bayaran manual di kob-detail.html.
CREATE TABLE IF NOT EXISTS psy_kob_installments (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  kob_session_id   UUID NOT NULL REFERENCES psy_kob_sessions(id) ON DELETE CASCADE,
  patient_id       UUID NOT NULL REFERENCES psy_patients(id) ON DELETE CASCADE,
  seq              INT NOT NULL,
  due_date         DATE NOT NULL,
  amount           NUMERIC(10,2) NOT NULL,
  status           TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','paid','overdue')),
  paid_payment_id  UUID REFERENCES psy_payments(id) ON DELETE SET NULL,
  paid_at          TIMESTAMPTZ,
  created_at       TIMESTAMPTZ DEFAULT now(),
  CONSTRAINT psy_kob_installments_unique_seq UNIQUE (kob_session_id, seq)
);

CREATE INDEX IF NOT EXISTS idx_kob_installments_session ON psy_kob_installments(kob_session_id);
CREATE INDEX IF NOT EXISTS idx_kob_installments_patient ON psy_kob_installments(patient_id, status);
CREATE INDEX IF NOT EXISTS idx_kob_installments_overdue ON psy_kob_installments(due_date) WHERE status = 'pending';

ALTER TABLE psy_kob_installments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Patient read own installments" ON psy_kob_installments;
CREATE POLICY "Patient read own installments" ON psy_kob_installments FOR SELECT
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Staff manage installments" ON psy_kob_installments;
CREATE POLICY "Staff manage installments" ON psy_kob_installments FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

COMMENT ON COLUMN psy_kob_installments.seq IS
  '1 = ansuran pertama (deposit, dibayar semasa sesi KOB). Nombor menaik ikut tarikh due.';
COMMENT ON COLUMN psy_kob_installments.amount IS
  'Harga pakej ÷ installment_count, dibundarkan ke bawah — ansuran seq TERAKHIR serap baki supaya jumlah keseluruhan tepat sama dengan harga pakej.';
COMMENT ON COLUMN psy_kob_installments.status IS
  'overdue ditetapkan oleh installment-overdue-check (cron harian) bila due_date lepas & masih pending. Auto set false semula (booking_blocked pesakit) bila ansuran ini dibayar.';

-- ──── psy_kob_agreements ────
-- Rekod perjanjian yang ditandatangani pesakit.
CREATE TABLE IF NOT EXISTS psy_kob_agreements (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id        UUID NOT NULL REFERENCES psy_patients(id) ON DELETE CASCADE,
  kob_session_id    UUID REFERENCES psy_kob_sessions(id) ON DELETE SET NULL,
  agreement_version TEXT NOT NULL DEFAULT 'ISW.SOP OB KOB FORM 03 CONTRACT 250711',
  patient_name      TEXT NOT NULL,
  patient_ic        TEXT NOT NULL,
  signature_url     TEXT NOT NULL,   -- tandatangan PNG mentah dalam storage
  signed_pdf_url    TEXT,            -- PDF terjana dengan tandatangan tertanam
  signed_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
  ip_address        TEXT,
  user_agent        TEXT,
  created_at        TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_kob_agreements_patient ON psy_kob_agreements(patient_id);

ALTER TABLE psy_kob_agreements ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Patient read own agreement" ON psy_kob_agreements;
CREATE POLICY "Patient read own agreement" ON psy_kob_agreements FOR SELECT
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Patient sign own agreement" ON psy_kob_agreements;
CREATE POLICY "Patient sign own agreement" ON psy_kob_agreements FOR INSERT
  WITH CHECK (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Patient cancel own unfinalized agreement" ON psy_kob_agreements;
CREATE POLICY "Patient cancel own unfinalized agreement" ON psy_kob_agreements FOR DELETE
  USING (
    patient_id IN (
      SELECT id FROM psy_patients
      WHERE user_id = auth.uid()
        AND (kob_status IS NULL OR kob_status != 'completed')
    )
  );

DROP POLICY IF EXISTS "Staff read all agreements" ON psy_kob_agreements;
CREATE POLICY "Staff read all agreements" ON psy_kob_agreements FOR SELECT
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "Staff insert agreement on behalf of patient" ON psy_kob_agreements;
CREATE POLICY "Staff insert agreement on behalf of patient" ON psy_kob_agreements FOR INSERT
  WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "Staff update agreement" ON psy_kob_agreements;
CREATE POLICY "Staff update agreement" ON psy_kob_agreements FOR UPDATE
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- ──── psy_kob_slot_config ────
-- Templat slot tetap untuk KOB & Rawatan (Rabu-Ahad). Admin boleh on/off
-- setiap slot; tiada kapasiti per-pesakit.
CREATE TABLE IF NOT EXISTS psy_kob_slot_config (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slot_type    TEXT NOT NULL DEFAULT 'kob' CHECK (slot_type IN ('kob','rawatan')),
  day_of_week  INT NOT NULL CHECK (day_of_week IN (0, 3, 4, 5, 6)),  -- 0=Ahad, 3=Rabu, 4=Khamis, 5=Jumaat, 6=Sabtu
  slot_start   TIME NOT NULL,
  slot_end     TIME NOT NULL,
  is_active    BOOLEAN NOT NULL DEFAULT true,
  label        TEXT NOT NULL,         -- paparan cth "7-9 pg"
  sort_order   INT NOT NULL DEFAULT 0,
  note         TEXT,                  -- nota peringatan untuk slot
  created_at   TIMESTAMPTZ DEFAULT now(),
  updated_at   TIMESTAMPTZ DEFAULT now(),
  CONSTRAINT psy_kob_slot_config_unique UNIQUE (slot_type, day_of_week, slot_start)
);

CREATE INDEX IF NOT EXISTS idx_kob_slots_day ON psy_kob_slot_config(day_of_week, is_active);

ALTER TABLE psy_kob_slot_config ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone read kob slots" ON psy_kob_slot_config;
CREATE POLICY "Anyone read kob slots" ON psy_kob_slot_config
  FOR SELECT USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "Admin manage kob slots" ON psy_kob_slot_config;
CREATE POLICY "Admin manage kob slots" ON psy_kob_slot_config FOR ALL
  USING (EXISTS (
    SELECT 1 FROM psy_profiles
    WHERE id = auth.uid() AND role = 'staff'
      AND staff_role IN ('admin','manager','doctor','super_admin')
  ))
  WITH CHECK (EXISTS (
    SELECT 1 FROM psy_profiles
    WHERE id = auth.uid() AND role = 'staff'
      AND staff_role IN ('admin','manager','doctor','super_admin')
  ));

-- ──── data rujukan ────
-- Slot templat: 5 slot × 2 jenis (kob, rawatan) × 5 hari (Rabu-Ahad)
INSERT INTO psy_kob_slot_config (slot_type, day_of_week, slot_start, slot_end, label, sort_order, is_active)
SELECT
  t.slot_type,
  d.day_of_week,
  s.slot_start::time,
  s.slot_end::time,
  s.label,
  s.sort_order,
  true
FROM
  (VALUES ('kob'), ('rawatan')) AS t(slot_type),
  (VALUES (3), (4), (5), (6), (0)) AS d(day_of_week),
  (VALUES
    ('07:00', '09:00', '7-9 pg',          1),
    ('09:30', '11:30', '9.30-11.30 pg',   2),
    ('14:00', '16:00', '2-4 ptg',         3),
    ('14:30', '16:30', '2.30-4.30 ptg',   4),
    ('16:30', '18:30', '4.30-6.30 ptg',   5)
  ) AS s(slot_start, slot_end, label, sort_order)
ON CONFLICT ON CONSTRAINT psy_kob_slot_config_unique DO NOTHING;
