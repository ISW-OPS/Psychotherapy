-- ═══════════════════════════════════════════════════════════════════
-- 20261021 — Jadual Rakaman Production (notifikasi WhatsApp milestone)
-- Pesakit capai milestone (W3/W5/W7/W9/W12 dalam pakej 12 minggu asal,
-- M1/M2/M3/Q1/Q2/Q3 dalam fasa sambungan) → notify Team Production (luar
-- sistem, WhatsApp sahaja) + queue staf jejak/urus.
-- Idempoten — selamat dijalankan berulang.
-- ═══════════════════════════════════════════════════════════════════

-- ──── psy_production_recordings ────
CREATE TABLE IF NOT EXISTS psy_production_recordings (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id      UUID NOT NULL REFERENCES psy_patients(id) ON DELETE CASCADE,
  milestone       TEXT NOT NULL
                   CONSTRAINT psy_production_recordings_milestone_check
                   CHECK (milestone IN ('w3','w5','w7','w9','w12','m1','m2','m3','q1','q2','q3')),
  milestone_label TEXT,
  -- Jadual ni LOG PENGHANTARAN notis sahaja (pending/notified) — Team Production
  -- tiada akaun ISW & tiada staf ditugaskan follow-up balik status rakaman
  -- sebenar, jadi 'recorded'/'skipped' + recorded_at/recorded_by DIBUANG sengaja.
  status          TEXT NOT NULL DEFAULT 'pending'
                   CONSTRAINT psy_production_recordings_status_check
                   CHECK (status IN ('pending','notified')),
  wa_sent_at      TIMESTAMPTZ,
  wa_send_status  TEXT,
  created_at      TIMESTAMPTZ DEFAULT now(),
  CONSTRAINT psy_production_recordings_patient_milestone_key UNIQUE (patient_id, milestone)
);

CREATE INDEX IF NOT EXISTS idx_psy_production_recordings_status
  ON psy_production_recordings(status);

CREATE INDEX IF NOT EXISTS idx_psy_production_recordings_patient
  ON psy_production_recordings(patient_id);

ALTER TABLE psy_production_recordings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff manage production recordings" ON psy_production_recordings;
CREATE POLICY "Staff manage production recordings" ON psy_production_recordings FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

COMMENT ON TABLE psy_production_recordings IS
  'Queue notifikasi WhatsApp kpd Team Production (luar sistem, tiada akaun ISW) bila pesakit capai milestone rakaman progress report. Diisi auto oleh cron, diurus staf di production-queue.html.';

COMMENT ON COLUMN psy_production_recordings.milestone_label IS
  'Label paparan diisi masa insert, cth "Minggu 3" / "Bulan 1" / "Suku 1".';

COMMENT ON COLUMN psy_production_recordings.status IS
  'pending = dikesan, belum/gagal hantar WA; notified = WA dah hantar. Log penghantaran sahaja — tiada penjejakan status rakaman sebenar (Team Production tiada akaun ISW, tiada staf ditugaskan follow-up balik).';

COMMENT ON COLUMN psy_production_recordings.wa_send_status IS
  'Status penghantaran WA terakhir (sent/failed) — rujukan debug, bukan status rekod (lihat column status).';

-- ──── RBAC: modul 'production_recordings' ────
INSERT INTO psy_modules (code, label, icon, scope, sort_order) VALUES
  ('production_recordings', 'Jadual Rakaman Production', '🎥', 'staff', 86)
ON CONFLICT (code) DO UPDATE SET
  label = EXCLUDED.label, icon = EXCLUDED.icon, scope = EXCLUDED.scope, sort_order = EXCLUDED.sort_order;

INSERT INTO psy_module_actions (module_code, action_code)
SELECT 'production_recordings', a.code FROM psy_actions a
ON CONFLICT DO NOTHING;

-- Grant: 'view' sahaja utk semua role berkaitan — halaman ni log baca-sahaja
-- (tiada butang tindakan langsung, lihat komen column status di atas).
INSERT INTO psy_role_module_actions (role_code, module_code, action_code) VALUES
  ('super_admin', 'production_recordings', 'view'),
  ('manager',     'production_recordings', 'view'),
  ('admin',       'production_recordings', 'view'),
  ('coach',       'production_recordings', 'view')
ON CONFLICT DO NOTHING;

-- ═══════════════════════════════════════════════════════════════════
-- Lanjutan (sambungan hari sama) — due_date, supaya cron hantar WA SEHARI
-- SEBELUM tarikh rawatan sebenar (bukan terus bila milestone dikesan).
-- ═══════════════════════════════════════════════════════════════════
ALTER TABLE psy_production_recordings ADD COLUMN IF NOT EXISTS due_date DATE;

CREATE INDEX IF NOT EXISTS idx_psy_production_recordings_due_date
  ON psy_production_recordings(due_date);

-- ═══════════════════════════════════════════════════════════════════
-- Tetingkap Pendaftaran Acara (bila dibuka / bila ditutup) + Keperluan
-- custom — acara-baru.html/acara-edit.html boleh set terus, acara-detail.html
-- (staf) + event-detail.html (pesakit) papar & kuatkuasa.
-- registration_deadline dah SEDIA ADA (lajur lama, tak pernah dipakai) —
-- guna terus sebagai "bila ditutup"; NULL = default tutup pada start_at
-- (tingkah laku asal). registration_opens_at BAHARU, NULL = terus dibuka
-- bila acara dicipta (tiada sekatan awal).
-- ═══════════════════════════════════════════════════════════════════
ALTER TABLE psy_events ADD COLUMN IF NOT EXISTS registration_opens_at TIMESTAMPTZ;
ALTER TABLE psy_events ADD COLUMN IF NOT EXISTS requirements TEXT;

COMMENT ON COLUMN psy_events.registration_opens_at IS
  'Bila pendaftaran mula dibuka. NULL = dibuka terus bila acara dicipta/publish.';
COMMENT ON COLUMN psy_events.registration_deadline IS
  'Bila pendaftaran ditutup. NULL = default tutup pada start_at (tingkah laku asal sebelum tetingkap ni dibina).';
COMMENT ON COLUMN psy_events.requirements IS
  'Senarai keperluan custom (satu baris = satu item) dipaparkan di tab Maklumat Event. NULL/kosong = seksyen Keperluan disorok.';

-- Kuatkuasa tetingkap pendaftaran server-side (staf override, sama corak dgn
-- trg_enforce_event_capacity) — elak pesakit daftar sebelum dibuka / lepas tutup
-- walau cuba terus panggil API, bukan sekadar sorok butang di UI.
CREATE OR REPLACE FUNCTION trg_enforce_registration_window()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_opens_at   TIMESTAMPTZ;
  v_closes_at  TIMESTAMPTZ;
  v_start_at   TIMESTAMPTZ;
  v_is_staff   BOOLEAN;
BEGIN
  IF NEW.status = 'batal' THEN RETURN NEW; END IF;
  SELECT EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff') INTO v_is_staff;
  IF v_is_staff THEN RETURN NEW; END IF;

  SELECT registration_opens_at, registration_deadline, start_at
    INTO v_opens_at, v_closes_at, v_start_at
    FROM psy_events WHERE id = NEW.event_id;

  IF v_opens_at IS NOT NULL AND now() < v_opens_at THEN
    RAISE EXCEPTION 'Pendaftaran acara ini belum dibuka.';
  END IF;
  IF now() > COALESCE(v_closes_at, v_start_at) THEN
    RAISE EXCEPTION 'Pendaftaran acara ini telah ditutup.';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_enforce_registration_window ON psy_event_registrations;
CREATE TRIGGER trg_enforce_registration_window
  BEFORE INSERT OR UPDATE ON psy_event_registrations
  FOR EACH ROW EXECUTE FUNCTION trg_enforce_registration_window();

-- ═══════════════════════════════════════════════════════════════════
-- PIC (Person In Charge) acara — koordinator, berasingan dari Program
-- Host (speaker/penceramah). Pilih dari senarai staff sedia ada (bukan
-- taip manual) — telefon/emel diambil terus dari psy_profiles.
-- ═══════════════════════════════════════════════════════════════════
ALTER TABLE psy_events ADD COLUMN IF NOT EXISTS pic_id UUID REFERENCES psy_profiles(id) ON DELETE SET NULL;

-- ═══════════════════════════════════════════════════════════════════
-- Sumber pendaftaran peserta (Portal Patient / Staf Manual) — tab
-- "Peserta & Kehadiran" gabungan di acara-detail.html.
-- ═══════════════════════════════════════════════════════════════════
ALTER TABLE psy_event_registrations ADD COLUMN IF NOT EXISTS source TEXT DEFAULT 'portal';

-- ═══════════════════════════════════════════════════════════════════
-- PIC kembali ke Persediaan & Peralatan (per-barang) — pilih dari
-- senarai staff, bukan taip manual.
-- ═══════════════════════════════════════════════════════════════════
ALTER TABLE psy_event_prep_items ADD COLUMN IF NOT EXISTS pic_id UUID REFERENCES psy_profiles(id) ON DELETE SET NULL;

-- ═══════════════════════════════════════════════════════════════════
-- Pemulangan Barang — tab baharu gantikan persediaan-event-keluar.html.
-- Satu rekod pemulangan per barang (UNIQUE prep_item_id) — ringkas,
-- bukan log berbilang pergerakan. qty_borrowed = snapshot qty_needed
-- barang tu masa rekod dicipta (elak berubah kalau staff edit
-- kuantiti kemudian).
-- ═══════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS psy_event_item_returns (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id      UUID NOT NULL REFERENCES psy_events(id) ON DELETE CASCADE,
  prep_item_id  UUID NOT NULL REFERENCES psy_event_prep_items(id) ON DELETE CASCADE,
  qty_borrowed  NUMERIC(10,2) NOT NULL DEFAULT 0,
  qty_returned  NUMERIC(10,2) NOT NULL DEFAULT 0,
  condition     TEXT CHECK (condition IS NULL OR condition IN ('baik','rosak','hilang')),
  returned_at   TIMESTAMPTZ,
  pic_id        UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  created_at    TIMESTAMPTZ DEFAULT now(),
  updated_at    TIMESTAMPTZ DEFAULT now(),
  UNIQUE (prep_item_id)
);
CREATE INDEX IF NOT EXISTS idx_psy_event_item_returns_event ON psy_event_item_returns(event_id);
ALTER TABLE psy_event_item_returns ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Staff manage event item returns" ON psy_event_item_returns;
CREATE POLICY "Staff manage event item returns" ON psy_event_item_returns FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
