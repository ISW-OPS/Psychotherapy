-- ═══════════════════════════════════════════════════════════════
-- ACARA & PENGUMUMAN
-- Jadual: psy_announcements, psy_events, psy_event_registrations,
--         psy_event_materials, psy_announcement_categories,
--         psy_announcement_types
-- ═══════════════════════════════════════════════════════════════

-- ──── psy_announcements ────
CREATE TABLE IF NOT EXISTS psy_announcements (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title       TEXT NOT NULL,
  body        TEXT,
  tag         TEXT,
  bg          TEXT DEFAULT 'from-navy to-green-dark',
  cta_label   TEXT,
  cta_url     TEXT,
  image_url   TEXT,
  is_active   BOOLEAN DEFAULT true,
  sort_order  INT DEFAULT 0,
  starts_at   TIMESTAMPTZ,
  ends_at     TIMESTAMPTZ,
  category    TEXT,
  content     TEXT,
  audience    JSONB DEFAULT '["patient"]'::jsonb,
  expires_at  TIMESTAMPTZ,
  package_ids JSONB DEFAULT '[]'::jsonb,
  created_at  TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE psy_announcements ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone read active announcements" ON psy_announcements;
CREATE POLICY "Anyone read active announcements" ON psy_announcements FOR SELECT
  USING (is_active = true);

DROP POLICY IF EXISTS "Staff manage announcements" ON psy_announcements;
CREATE POLICY "Staff manage announcements" ON psy_announcements FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- ──── psy_announcement_reads (audit #G-33/34, Tier 5) ────
-- Tanda "dibaca" bila pengumuman muncul di dashboard pesakit (impression-based,
-- bukan scroll-tracking terperinci) — cukup utk staf nampak jangkauan sebenar
-- vs sasaran, tanpa infrastruktur analytics berasingan.
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

-- ──── psy_events (acara / kelas) ────
CREATE TABLE IF NOT EXISTS psy_events (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title                 TEXT NOT NULL,
  description           TEXT,
  type                  TEXT DEFAULT 'kelas',
  start_at              TIMESTAMPTZ NOT NULL,
  end_at                TIMESTAMPTZ,
  mode                  TEXT DEFAULT 'online',
  location              TEXT,
  address               TEXT,
  maps_url              TEXT,
  capacity              INT,
  registration_deadline TIMESTAMPTZ,
  cover_image           TEXT,
  tag                   TEXT,
  host                  TEXT,
  host_role             TEXT, -- Penceramah / Coach / Moderator
  price                 NUMERIC DEFAULT 0,
  status                TEXT DEFAULT 'published',
  recording_url         TEXT,
  audience              JSONB DEFAULT '["patient"]'::jsonb,
  package_ids           JSONB DEFAULT '[]'::jsonb,
  created_by            UUID,
  created_at            TIMESTAMPTZ DEFAULT now(),
  updated_at            TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE psy_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "events read" ON psy_events;
CREATE POLICY "events read" ON psy_events FOR SELECT USING (
  status = 'published' OR auth.uid() IN (SELECT id FROM psy_profiles WHERE role = 'staff'));

DROP POLICY IF EXISTS "events staff manage" ON psy_events;
CREATE POLICY "events staff manage" ON psy_events FOR ALL
  USING (auth.uid() IN (SELECT id FROM psy_profiles WHERE role = 'staff'))
  WITH CHECK (auth.uid() IN (SELECT id FROM psy_profiles WHERE role = 'staff'));

-- ──── psy_event_meet_links (audit #H-36, Tier 5) ────
-- meet_link SENGAJA DIKELUARKAN dari psy_events (lihat migration
-- 20260924_event_meet_link_capacity.sql utk ALTER TABLE DROP COLUMN + backfill
-- data sedia ada) — RLS Postgres cuma boleh benar/tolak SEBARIS, bukan sembunyi
-- SATU LAJUR sahaja. Dulu meet_link tinggal dlm psy_events (dibaca terus lepas
-- event 'published', tak kira pesakit dah daftar atau belum; UI event-detail.html
-- cuma sorok butang client-side, data sebenar tetap ADA dlm respons API). Jadual
-- berasingan + RLS sendiri tutup jurang tu betul-betul. Staf (acara-baru.html/
-- acara-edit.html/acara-detail.html/events.html) baca/tulis terus jadual ni.
CREATE TABLE IF NOT EXISTS psy_event_meet_links (
  event_id   UUID PRIMARY KEY REFERENCES psy_events(id) ON DELETE CASCADE,
  meet_link  TEXT,
  updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE psy_event_meet_links ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff manage event meet links" ON psy_event_meet_links;
CREATE POLICY "Staff manage event meet links" ON psy_event_meet_links FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
  WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "Registered patients read meet link" ON psy_event_meet_links;
CREATE POLICY "Registered patients read meet link" ON psy_event_meet_links FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM psy_event_registrations r
    JOIN psy_patients p ON p.id = r.patient_id
    WHERE r.event_id = psy_event_meet_links.event_id
      AND p.user_id = auth.uid() AND r.status <> 'batal'
  ));

-- ──── psy_event_registrations (pendaftaran acara) ────
CREATE TABLE IF NOT EXISTS psy_event_registrations (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id         UUID REFERENCES psy_events(id) ON DELETE CASCADE,
  patient_id       UUID REFERENCES psy_patients(id) ON DELETE CASCADE,
  status           TEXT DEFAULT 'registered',
  reminder_sent_at TIMESTAMPTZ, -- penanda dedup peringatan WhatsApp 1 jam (Edge Function event-reminders)
  registered_at    TIMESTAMPTZ DEFAULT now(),
  UNIQUE (event_id, patient_id)
);

CREATE INDEX IF NOT EXISTS idx_event_regs_event   ON psy_event_registrations(event_id);
CREATE INDEX IF NOT EXISTS idx_event_regs_patient ON psy_event_registrations(patient_id);

ALTER TABLE psy_event_registrations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "regs read" ON psy_event_registrations;
CREATE POLICY "regs read" ON psy_event_registrations FOR SELECT USING (
  patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid())
  OR auth.uid() IN (SELECT id FROM psy_profiles WHERE role = 'staff'));

DROP POLICY IF EXISTS "regs patient insert" ON psy_event_registrations;
CREATE POLICY "regs patient insert" ON psy_event_registrations FOR INSERT WITH CHECK (
  patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "regs patient update" ON psy_event_registrations;
CREATE POLICY "regs patient update" ON psy_event_registrations FOR UPDATE USING (
  patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid())
  OR auth.uid() IN (SELECT id FROM psy_profiles WHERE role = 'staff'));

DROP POLICY IF EXISTS "regs staff delete" ON psy_event_registrations;
CREATE POLICY "regs staff delete" ON psy_event_registrations FOR DELETE USING (
  auth.uid() IN (SELECT id FROM psy_profiles WHERE role = 'staff'));

-- ──── Trigger: kuatkuasa kapasiti acara (audit #H-35, Tier 5) ────
-- Dulu client terus upsert tanpa apa-apa semakan — kapasiti cuma paparan
-- ("6 sesi/8 slot" style), tak dikuatkuasa langsung. Server-side (bukan
-- client) supaya tak boleh dipintas — staf (INSERT terus dari admin,
-- cth manual add) tetap dibenarkan lepas kapasiti (override sengaja).
CREATE OR REPLACE FUNCTION trg_enforce_event_capacity()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_capacity INT;
  v_count    INT;
  v_is_staff BOOLEAN;
BEGIN
  IF NEW.status = 'batal' THEN RETURN NEW; END IF;
  SELECT EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff') INTO v_is_staff;
  IF v_is_staff THEN RETURN NEW; END IF;

  SELECT capacity INTO v_capacity FROM psy_events WHERE id = NEW.event_id;
  IF v_capacity IS NULL THEN RETURN NEW; END IF;

  SELECT COUNT(*) INTO v_count FROM psy_event_registrations
    WHERE event_id = NEW.event_id AND status <> 'batal' AND id <> COALESCE(NEW.id, '00000000-0000-0000-0000-000000000000'::uuid);
  IF v_count >= v_capacity THEN
    RAISE EXCEPTION 'Acara ini telah penuh (kapasiti % peserta).', v_capacity;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_enforce_event_capacity ON psy_event_registrations;
CREATE TRIGGER trg_enforce_event_capacity
  BEFORE INSERT OR UPDATE ON psy_event_registrations
  FOR EACH ROW EXECUTE FUNCTION trg_enforce_event_capacity();

-- ──── psy_event_materials (bahan / rakaman acara) ────
CREATE TABLE IF NOT EXISTS psy_event_materials (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id   UUID REFERENCES psy_events(id) ON DELETE CASCADE,
  title      TEXT NOT NULL,
  type       TEXT DEFAULT 'pautan',
  url        TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_event_materials_event ON psy_event_materials(event_id);

ALTER TABLE psy_event_materials ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "materials read" ON psy_event_materials;
CREATE POLICY "materials read" ON psy_event_materials FOR SELECT USING (
  EXISTS (SELECT 1 FROM psy_events e WHERE e.id = event_id
          AND (e.status = 'published' OR auth.uid() IN (SELECT id FROM psy_profiles WHERE role = 'staff'))));

DROP POLICY IF EXISTS "materials staff manage" ON psy_event_materials;
CREATE POLICY "materials staff manage" ON psy_event_materials FOR ALL
  USING (auth.uid() IN (SELECT id FROM psy_profiles WHERE role = 'staff'))
  WITH CHECK (auth.uid() IN (SELECT id FROM psy_profiles WHERE role = 'staff'));

-- ──── psy_announcement_categories (kategori pengumuman — super admin CRUD) ────
CREATE TABLE IF NOT EXISTS psy_announcement_categories (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name       TEXT NOT NULL UNIQUE,
  sort_order INT DEFAULT 0,
  is_active  BOOLEAN DEFAULT true,
  created_by UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE psy_announcement_categories ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "ann_cat read" ON psy_announcement_categories;
CREATE POLICY "ann_cat read" ON psy_announcement_categories FOR SELECT USING (
  auth.uid() IN (SELECT id FROM psy_profiles WHERE role = 'staff'));

DROP POLICY IF EXISTS "ann_cat manage" ON psy_announcement_categories;
CREATE POLICY "ann_cat manage" ON psy_announcement_categories FOR ALL
  USING (auth.uid() IN (SELECT id FROM psy_profiles WHERE staff_role = 'super_admin'))
  WITH CHECK (auth.uid() IN (SELECT id FROM psy_profiles WHERE staff_role = 'super_admin'));

-- ──── psy_announcement_types (jenis pengumuman — super admin CRUD) ────
CREATE TABLE IF NOT EXISTS psy_announcement_types (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  key         TEXT NOT NULL UNIQUE,
  title       TEXT NOT NULL,
  description TEXT DEFAULT '',
  kind        TEXT NOT NULL DEFAULT 'announcement',
  mode        TEXT,
  etype       TEXT,
  label       TEXT,
  sort_order  INT DEFAULT 0,
  is_active   BOOLEAN DEFAULT true,
  created_by  UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  created_at  TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ann_types_sort ON psy_announcement_types(sort_order);

ALTER TABLE psy_announcement_types ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "ann_types read" ON psy_announcement_types;
CREATE POLICY "ann_types read" ON psy_announcement_types FOR SELECT USING (
  auth.uid() IN (SELECT id FROM psy_profiles WHERE role = 'staff'));

DROP POLICY IF EXISTS "ann_types manage" ON psy_announcement_types;
CREATE POLICY "ann_types manage" ON psy_announcement_types FOR ALL
  USING (auth.uid() IN (SELECT id FROM psy_profiles WHERE staff_role = 'super_admin'))
  WITH CHECK (auth.uid() IN (SELECT id FROM psy_profiles WHERE staff_role = 'super_admin'));

-- ──── data rujukan ────
INSERT INTO psy_announcements (title, body, tag, bg, cta_label, cta_url, sort_order) VALUES
  ('Kelas Mindfulness Percuma', 'Setiap Sabtu 9AM — Sertai sesi meditasi & pernafasan bersama Coach Izzah.', 'Kelas Minggu Ini', 'from-navy to-teal', 'Daftar Sekarang', 'https://wa.me/60123456789', 1),
  ('Program Detox Digital', 'Cabaran 7 hari kurangkan screen time untuk kesejahteraan mental anda.', 'Challenge Baru', 'from-green-dark to-teal', 'Sertai Cabaran', null, 2),
  ('Pakej Ramadan Khas', 'Rawatan holistik dengan fokus spiritual — promosi sehingga hujung bulan.', 'Promosi', 'from-navy to-green-dark', 'Lihat Pakej', 'pakej.html', 3)
ON CONFLICT DO NOTHING;

-- ═══════════════════════════════════════════════════════════════════
-- Persediaan Event (Inventory Event) — Modul Persediaan Event v1
-- Checklist peralatan/bahan untuk setiap Acara & Kelas. Murni perancangan —
-- TIADA potong/pulang stok automatik. "Stok Sedia Ada" dikira LIVE dari
-- psy_inventory_items.qty_in_stock masa paparan (bukan snapshot di sini).
-- Migration: supabase/migrations/20261014_event_prep_items.sql
-- ═══════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS psy_event_prep_items (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id         UUID NOT NULL REFERENCES psy_events(id) ON DELETE CASCADE,
  source           TEXT NOT NULL DEFAULT 'manual' CHECK (source IN ('inventory','manual')),
  inventory_item_id UUID REFERENCES psy_inventory_items(id) ON DELETE SET NULL,
  item_name        TEXT NOT NULL,
  category         TEXT,
  unit             TEXT,
  qty_needed       NUMERIC(10,2) NOT NULL DEFAULT 1,
  pic_id           UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  deadline_date    DATE,
  status           TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('ready','preparing','pending','not_available')),
  notes            TEXT,
  created_by       UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  created_at       TIMESTAMPTZ DEFAULT now(),
  updated_at       TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_psy_event_prep_items_event ON psy_event_prep_items(event_id);

ALTER TABLE psy_event_prep_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff manage event prep items" ON psy_event_prep_items;
CREATE POLICY "Staff manage event prep items" ON psy_event_prep_items FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

COMMENT ON TABLE psy_event_prep_items IS
  'Checklist persediaan peralatan/bahan untuk Acara & Kelas (psy_events) — Modul Persediaan Event v1. Tiada kaitan pergerakan stok automatik.';
COMMENT ON COLUMN psy_event_prep_items.source IS
  '''inventory'' = dipautkan ke psy_inventory_items (stok sedia ada dikira live); ''manual'' = item bebas, tiada pautan inventori.';
COMMENT ON COLUMN psy_event_prep_items.status IS
  'Ditetapkan staff sendiri: pending (baru/belum mula) -> preparing (sedang disiapkan) -> ready (sedia); not_available = tak dapat disediakan.';
-- Persediaan Event v2: Checklist Setup, Template, Nota, Pengeluaran & Pemulangan
-- Susulan kepada 20261014_event_prep_items.sql (psy_event_prep_items, v1)

-- ── Checklist Setup (tugasan persediaan — bukan barang fizikal) ──
CREATE TABLE IF NOT EXISTS psy_event_checklist_tasks (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id    UUID NOT NULL REFERENCES psy_events(id) ON DELETE CASCADE,
  task        TEXT NOT NULL,
  pic_id      UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  target_date DATE,
  status      TEXT NOT NULL DEFAULT 'belum_mula' CHECK (status IN ('belum_mula','dalam_proses','selesai')),
  created_at  TIMESTAMPTZ DEFAULT now(),
  updated_at  TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_psy_event_checklist_tasks_event ON psy_event_checklist_tasks(event_id);
ALTER TABLE psy_event_checklist_tasks ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Staff manage event checklist tasks" ON psy_event_checklist_tasks;
CREATE POLICY "Staff manage event checklist tasks" ON psy_event_checklist_tasks FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- ── Template persediaan (senarai barang guna-semula) ──
CREATE TABLE IF NOT EXISTS psy_event_prep_templates (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name        TEXT NOT NULL,
  description TEXT,
  created_by  UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  created_at  TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE psy_event_prep_templates ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Staff manage event prep templates" ON psy_event_prep_templates;
CREATE POLICY "Staff manage event prep templates" ON psy_event_prep_templates FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

CREATE TABLE IF NOT EXISTS psy_event_prep_template_items (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  template_id       UUID NOT NULL REFERENCES psy_event_prep_templates(id) ON DELETE CASCADE,
  source            TEXT NOT NULL DEFAULT 'manual' CHECK (source IN ('inventory','manual')),
  inventory_item_id UUID REFERENCES psy_inventory_items(id) ON DELETE SET NULL,
  item_name         TEXT NOT NULL,
  category          TEXT,
  unit              TEXT,
  qty_needed        NUMERIC(10,2) NOT NULL DEFAULT 1
);
CREATE INDEX IF NOT EXISTS idx_psy_event_prep_template_items_template ON psy_event_prep_template_items(template_id);
ALTER TABLE psy_event_prep_template_items ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Staff manage event prep template items" ON psy_event_prep_template_items;
CREATE POLICY "Staff manage event prep template items" ON psy_event_prep_template_items FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- ── Metadata persediaan 1:1 per acara (template digunakan, nota, tarikh akhir persediaan) ──
CREATE TABLE IF NOT EXISTS psy_event_prep_meta (
  event_id      UUID PRIMARY KEY REFERENCES psy_events(id) ON DELETE CASCADE,
  template_id   UUID REFERENCES psy_event_prep_templates(id) ON DELETE SET NULL,
  notes         TEXT,
  deadline_date DATE,
  updated_at    TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE psy_event_prep_meta ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Staff manage event prep meta" ON psy_event_prep_meta;
CREATE POLICY "Staff manage event prep meta" ON psy_event_prep_meta FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- ── Pengeluaran & Pemulangan barang (stok keluar untuk event + rekod pulangan) ──
CREATE TABLE IF NOT EXISTS psy_event_stock_issuance (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id          UUID NOT NULL REFERENCES psy_events(id) ON DELETE CASCADE,
  prep_item_id      UUID REFERENCES psy_event_prep_items(id) ON DELETE SET NULL,
  inventory_item_id UUID REFERENCES psy_inventory_items(id) ON DELETE SET NULL,
  item_name         TEXT NOT NULL,
  qty               NUMERIC(10,2) NOT NULL,
  location_id       UUID REFERENCES psy_inventory_locations(id) ON DELETE SET NULL,
  borrowed_by       UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  issued_by         UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  issued_at         TIMESTAMPTZ DEFAULT now(),
  status            TEXT NOT NULL DEFAULT 'dikeluarkan' CHECK (status IN ('dikeluarkan','dipulangkan')),
  returned_at       TIMESTAMPTZ,
  notes             TEXT
);
CREATE INDEX IF NOT EXISTS idx_psy_event_stock_issuance_event ON psy_event_stock_issuance(event_id);
ALTER TABLE psy_event_stock_issuance ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Staff manage event stock issuance" ON psy_event_stock_issuance;
CREATE POLICY "Staff manage event stock issuance" ON psy_event_stock_issuance FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
-- Sambung Persediaan & Peralatan ke modul Equipment (psy_equipment — aset
-- bertag EQ-xxxx, berasingan dari psy_inventory_items yang pukal/konsumsi).
ALTER TABLE psy_event_prep_items DROP CONSTRAINT IF EXISTS psy_event_prep_items_source_check;
ALTER TABLE psy_event_prep_items ADD CONSTRAINT psy_event_prep_items_source_check
  CHECK (source IN ('inventory','manual','equipment'));

ALTER TABLE psy_event_prep_items
  ADD COLUMN IF NOT EXISTS equipment_id UUID REFERENCES psy_equipment(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_psy_event_prep_items_equipment ON psy_event_prep_items(equipment_id);
