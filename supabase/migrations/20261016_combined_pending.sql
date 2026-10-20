-- GABUNGAN SEMUA migration bertarikh 20261006-20261016 jadi SATU fail (supaya
-- boleh run sekali sahaja, tak payah buka >20 fail berasingan). Termasuk yang
-- dah disahkan RUN kat PROD (xmvqvqrifhwoehdfsoau, semak 16 Okt 2026) — semua
-- statement idempoten (IF NOT EXISTS / DROP+CREATE / ON CONFLICT), jadi SELAMAT
-- dijalankan berulang kali tanpa kesan kalau dah run. Ni supaya fail SAMA boleh
-- dipakai utk "catch-up" DB testing (status belum disahkan dari sini — akaun
-- Supabase berasingan) TANPA perlu kira fail mana dah/belum run kat situ.
-- Semua fail sumber asal dalam folder migrations/ (kecuali README.md) dah
-- dipadam lepas digabung.

-- ════════════════════════════════════════════════════════════════
-- 1) Persediaan Event (Inventory Event) v1 — checklist peralatan/bahan per-acara.
-- Murni perancangan: TIADA potong/pulang stok automatik — "Stok Sedia Ada"
-- dikira LIVE dari psy_inventory_items.qty_in_stock masa paparan, bukan snapshot
-- di sini. Status ditetapkan staff sendiri (bukan auto dari perbandingan stok).
-- ════════════════════════════════════════════════════════════════
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

-- ════════════════════════════════════════════════════════════════
-- 2) Persediaan Event v2: Checklist Setup, Template, Nota, Pengeluaran & Pemulangan
-- ════════════════════════════════════════════════════════════════

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

-- ════════════════════════════════════════════════════════════════
-- 4) psy_package_purchases ada RLS policy utk staff SELECT & UPDATE sahaja —
-- TIADA policy INSERT. Bila staff tanda KOB "Hadir"/"Selesai" dgn pakej
-- dicadang (kob-detail.html), atau assign pakej di patient-form.html/
-- patients.html, kod cuba INSERT terus ke jadual ni sbg staff → kena block
-- RLS: "new row violates row-level security policy for table psy_package_purchases".
-- ════════════════════════════════════════════════════════════════
DROP POLICY IF EXISTS "Staff insert purchases" ON psy_package_purchases;
CREATE POLICY "Staff insert purchases" ON psy_package_purchases FOR INSERT
  WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- ════════════════════════════════════════════════════════════════
-- 5) Status semakan Draft→Reviewed→Approved→Active utk Kategori & Reaksi
-- (dah wujud pada psy_reaksi_actions sejak 23 Sept). DEFAULT 'active' supaya
-- rekod sedia ada TIDAK terjejas.
-- ════════════════════════════════════════════════════════════════
ALTER TABLE psy_reaksi_kategori ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'active';
ALTER TABLE psy_reaksi_item     ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'active';

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_reaksi_kategori_status') THEN
    ALTER TABLE psy_reaksi_kategori ADD CONSTRAINT chk_reaksi_kategori_status
      CHECK (status IN ('draft','reviewed','approved','active'));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_reaksi_item_status') THEN
    ALTER TABLE psy_reaksi_item ADD CONSTRAINT chk_reaksi_item_status
      CHECK (status IN ('draft','reviewed','approved','active'));
  END IF;
END $$;

-- ════════════════════════════════════════════════════════════════
-- 6) Jadual Slot Sesi 1:1 redesign — blok ("9-12 pg") boleh auto-pecah jadi
-- slot diskret individu (2:00-2:30, 2:30-3:00, ...), setiap satu = SATU
-- janji temu, bukan sekadar kaunter kapasiti global.
-- ════════════════════════════════════════════════════════════════
ALTER TABLE psy_kob_slot_config ADD COLUMN IF NOT EXISTS slot_duration_minutes INT;

COMMENT ON COLUMN psy_kob_slot_config.slot_duration_minutes IS
  'Tempoh seorang pesakit (minit) dlm blok ni — dipakai slot_type=sesi_1on1 sahaja utk auto-jana slot diskret (slot_start + i*duration, i=0..max_bookings-1). NULL = mod lama (blok utuh, max_bookings jadi kaunter kapasiti sahaja, tiada slot diskret). kob/rawatan tak guna medan ni.';

-- ════════════════════════════════════════════════════════════════
-- 7) Rekod Klinikal Pesakit auto-create — status baharu 'warded' (Masuk
-- Wad/Hospital) ke psy_patients.status + lindungi drpd ditimpa semula oleh
-- fn_auto_inactive_on_session_done + trigger auto-cipta psy_patient_events
-- bila status bertukar KE 'warded'.
-- ════════════════════════════════════════════════════════════════
ALTER TABLE psy_patients DROP CONSTRAINT IF EXISTS psy_patients_status_check;
ALTER TABLE psy_patients ADD CONSTRAINT psy_patients_status_check CHECK (status IN (
  'pending_kyc','active','inactive','rejected','deleted',
  'unregistered','archived','deceased','warded'
));

CREATE OR REPLACE FUNCTION fn_auto_inactive_on_session_done()
RETURNS TRIGGER AS $$
DECLARE
  v_patient_id    UUID;
  v_pstatus       TEXT;
  v_pkg_expired   BOOLEAN;
  v_all_done      BOOLEAN;
  v_has_core      BOOLEAN;
  v_next_pkg      TEXT;
  v_next_name     TEXT;
BEGIN
  IF NEW.status NOT IN ('hadir','consultation_done') THEN
    RETURN NEW;
  END IF;
  IF TG_OP = 'UPDATE' AND OLD.status = NEW.status THEN
    RETURN NEW;
  END IF;

  SELECT patient_id INTO v_patient_id FROM psy_treatment_plans WHERE id = NEW.plan_id;
  IF v_patient_id IS NULL THEN RETURN NEW; END IF;

  SELECT
    EXISTS (SELECT 1 FROM psy_plan_weekly_progress
            WHERE plan_id = NEW.plan_id AND COALESCE(is_extension,false) = false),
    NOT EXISTS (
      SELECT 1 FROM psy_plan_weekly_progress
      WHERE plan_id = NEW.plan_id
        AND status NOT IN ('hadir','consultation_done')
        AND (
          COALESCE(is_extension,false) = false
          OR (COALESCE(extension_for_week, -1) = 0 AND status <> 'extension_pending_payment')
        )
    )
    INTO v_has_core, v_all_done;

  SELECT status, (package_expires_at IS NOT NULL AND package_expires_at < now()),
         next_package_id, next_package_name
    INTO v_pstatus, v_pkg_expired, v_next_pkg, v_next_name
    FROM psy_patients WHERE id = v_patient_id;

  IF v_pstatus IN ('inactive','archived','deceased','deleted','warded') THEN
    RETURN NEW;
  END IF;

  IF (v_has_core AND v_all_done) OR v_pkg_expired THEN
    UPDATE psy_treatment_plans SET status = 'completed'
      WHERE id = NEW.plan_id AND status <> 'completed';

    IF v_next_pkg IS NOT NULL AND v_next_pkg <> '' THEN
      UPDATE psy_patients
        SET active_package_id    = v_next_pkg,
            active_package_name  = COALESCE(v_next_name, active_package_name),
            package_purchased_at = now(),
            package_expires_at   = now() + interval '3 months',
            next_package_id      = NULL,
            next_package_name    = NULL,
            status               = 'active'
        WHERE id = v_patient_id;

      UPDATE psy_package_purchases
        SET status = 'active', expires_at = now() + interval '3 months'
        WHERE patient_id = v_patient_id AND package_id = v_next_pkg AND status = 'queued';

      BEGIN
        INSERT INTO psy_treatment_plans
          (patient_id, name, template, duration_unit, duration_weeks, current_week, coaching_schedule, status)
        SELECT v_patient_id, COALESCE(pk.name,'Pakej') || ' Treatment Plan', pk.package_id,
               COALESCE(pk.duration_unit,'week'), COALESCE(pk.duration_weeks,12), 1,
               COALESCE(pk.coaching_schedule, '[]'::jsonb), 'active'
        FROM psy_packages pk
        WHERE pk.package_id = v_next_pkg
          AND NOT EXISTS (
            SELECT 1 FROM psy_treatment_plans
            WHERE patient_id = v_patient_id AND template = v_next_pkg AND status = 'active'
          );
      EXCEPTION WHEN unique_violation THEN
        NULL;
      END;
    ELSE
      UPDATE psy_patients
        SET status = 'inactive',
            outcome_status = CASE WHEN outcome_status IS NULL OR outcome_status = ''
                                  THEN 'completed' ELSE outcome_status END,
            outcome_status_at = CASE WHEN outcome_status IS NULL OR outcome_status = ''
                                     THEN now() ELSE outcome_status_at END
        WHERE id = v_patient_id;
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION trg_patient_warded_auto_event()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NEW.status <> 'warded' OR OLD.status IS NOT DISTINCT FROM 'warded' THEN
    RETURN NEW;
  END IF;

  IF EXISTS (
    SELECT 1 FROM psy_patient_events
    WHERE patient_id = NEW.id AND event_type = 'warded' AND status = 'open'
  ) THEN
    RETURN NEW;
  END IF;

  INSERT INTO psy_patient_events (
    patient_id, event_type, priority, status, event_date,
    need_visit, visit_priority, assigned_to, notify_roles, notes, reported_by
  ) VALUES (
    NEW.id, 'warded', 'high', 'open', CURRENT_DATE,
    true, 'high', NEW.coach_id, '["manager","coach"]'::jsonb,
    'Rekod dicipta automatik — status pesakit ditukar ke Warded (Masuk Wad/Hospital).',
    NULL
  );

  -- Audit #146 (sub-3) — task peribadi auto-cipta & dipautkan kpd coach
  -- pesakit ni (psy_coach_tasks.patient_id). Marker '[auto:warded]' dlm
  -- notes elak duplikasi kalau status toggle warded→aktif→warded berulang.
  IF NEW.coach_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM psy_coach_tasks
    WHERE patient_id = NEW.id AND coach_id = NEW.coach_id
      AND status <> 'selesai' AND notes LIKE '%[auto:warded]%'
  ) THEN
    INSERT INTO psy_coach_tasks (
      coach_id, title, notes, task_date, priority, status, patient_id
    ) VALUES (
      NEW.coach_id,
      '🏥 Pesakit ' || COALESCE(NEW.full_name, 'Tanpa Nama') || ' masuk Wad/Hospital — rancang lawatan',
      'Dicipta automatik — status pesakit ditukar ke Warded. [auto:warded]',
      CURRENT_DATE, 'tinggi', 'belum_mula', NEW.id
    );
  END IF;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE LOG 'trg_patient_warded_auto_event: %', SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_patient_warded_auto_event ON psy_patients;
CREATE TRIGGER trg_patient_warded_auto_event
  AFTER UPDATE ON psy_patients
  FOR EACH ROW EXECUTE FUNCTION trg_patient_warded_auto_event();

-- ════════════════════════════════════════════════════════════════
-- 8) Sesi 1:1 — Follow-up auto-hantar (#17b) + Reminder harian per-saranan (#17c)
-- ════════════════════════════════════════════════════════════════
ALTER TABLE psy_clinical_referrals ADD COLUMN IF NOT EXISTS follow_up_sent_at TIMESTAMPTZ;
ALTER TABLE psy_clinical_referrals ADD COLUMN IF NOT EXISTS reminder_time TIME;
ALTER TABLE psy_clinical_referrals ADD COLUMN IF NOT EXISTS reminder_last_sent_date DATE;

-- ════════════════════════════════════════════════════════════════
-- 9) Naikkan had saiz upload: gambar minimum 15MB, fail minimum 50MB.
-- Nota: had global projek Supabase (Dashboard → Storage → Settings) perlu
-- disemak/dinaikkan berasingan — tak boleh diubah via SQL.
-- ════════════════════════════════════════════════════════════════
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('avatars', 'avatars', true, 15728640, ARRAY['image/png','image/jpeg','image/jpg','image/webp','image/gif'])
ON CONFLICT (id) DO UPDATE
  SET file_size_limit = EXCLUDED.file_size_limit,
      allowed_mime_types = EXCLUDED.allowed_mime_types;

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('inventory-images', 'inventory-images', true, 15728640, ARRAY['image/png','image/jpeg','image/jpg','image/webp'])
ON CONFLICT (id) DO UPDATE
  SET file_size_limit = EXCLUDED.file_size_limit,
      allowed_mime_types = EXCLUDED.allowed_mime_types;

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('inventory-print-files', 'inventory-print-files', true, 52428800, ARRAY['application/pdf','image/png'])
ON CONFLICT (id) DO UPDATE
  SET file_size_limit = EXCLUDED.file_size_limit,
      allowed_mime_types = EXCLUDED.allowed_mime_types;

-- ════════════════════════════════════════════════════════════════
-- 10) Menu & Hidangan Cadangan: tukar drpd teks bebas kepada senarai
-- berstruktur [{name, image_url}] supaya setiap menu boleh ada gambar sendiri.
-- ════════════════════════════════════════════════════════════════
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'psy_recommended_products' AND column_name = 'menu_items' AND data_type <> 'jsonb'
  ) THEN
    ALTER TABLE psy_recommended_products ADD COLUMN menu_items_new JSONB DEFAULT '[]';

    UPDATE psy_recommended_products
    SET menu_items_new = COALESCE(
      (SELECT jsonb_agg(jsonb_build_object('name', trim(line), 'image_url', null))
       FROM unnest(string_to_array(menu_items, E'\n')) AS line
       WHERE trim(line) <> ''),
      '[]'::jsonb
    )
    WHERE menu_items IS NOT NULL AND trim(menu_items) <> '';

    ALTER TABLE psy_recommended_products DROP COLUMN menu_items;
    ALTER TABLE psy_recommended_products RENAME COLUMN menu_items_new TO menu_items;
  END IF;
END $$;

ALTER TABLE psy_recommended_products ADD COLUMN IF NOT EXISTS menu_items JSONB DEFAULT '[]';

-- ════════════════════════════════════════════════════════════════
-- 11) Fasa 6 — Mission (jadual + enjin, skop MVP). mission_type 'daily_checkin'
-- = automatik (trigger bila pesakit isi Catatan Harian); 'manual' = pesakit
-- tekan butang sendiri (RPC advance_my_mission), had sekali sehari.
-- ════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS psy_missions (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name                  TEXT NOT NULL,
  description           TEXT,
  mission_type          TEXT NOT NULL DEFAULT 'manual' CHECK (mission_type IN ('daily_checkin', 'manual')),
  target                INT NOT NULL DEFAULT 1 CHECK (target > 0),
  reward_points         INT NOT NULL DEFAULT 0 CHECK (reward_points >= 0),
  repeat_cycle          TEXT NOT NULL DEFAULT 'none' CHECK (repeat_cycle IN ('none', 'weekly')),
  customer_eligibility  TEXT NOT NULL DEFAULT 'all' CHECK (customer_eligibility IN ('all', 'new', 'existing')),
  start_date            DATE,
  end_date              DATE,
  is_active             BOOLEAN NOT NULL DEFAULT true,
  created_by            UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  created_at            TIMESTAMPTZ DEFAULT now(),
  updated_at            TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE psy_missions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone read active missions" ON psy_missions;
CREATE POLICY "Anyone read active missions" ON psy_missions FOR SELECT USING (true);

DROP POLICY IF EXISTS "Staff manage missions" ON psy_missions;
CREATE POLICY "Staff manage missions" ON psy_missions
  FOR ALL USING      (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
           WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

CREATE TABLE IF NOT EXISTS psy_mission_progress (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  mission_id        UUID NOT NULL REFERENCES psy_missions(id) ON DELETE CASCADE,
  patient_id        UUID NOT NULL REFERENCES psy_patients(id) ON DELETE CASCADE,
  cycle_start       DATE NOT NULL DEFAULT '2000-01-01',
  progress          INT NOT NULL DEFAULT 0,
  status            TEXT NOT NULL DEFAULT 'in_progress' CHECK (status IN ('in_progress', 'completed', 'claimed')),
  last_advanced_on  DATE,
  completed_at      TIMESTAMPTZ,
  claimed_at        TIMESTAMPTZ,
  created_at        TIMESTAMPTZ DEFAULT now(),
  updated_at        TIMESTAMPTZ DEFAULT now(),
  UNIQUE (mission_id, patient_id, cycle_start)
);

CREATE INDEX IF NOT EXISTS idx_mission_progress_patient ON psy_mission_progress(patient_id, status);

ALTER TABLE psy_mission_progress ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Patients view own mission progress" ON psy_mission_progress;
CREATE POLICY "Patients view own mission progress" ON psy_mission_progress FOR SELECT
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Staff view all mission progress" ON psy_mission_progress;
CREATE POLICY "Staff view all mission progress" ON psy_mission_progress FOR SELECT
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

CREATE OR REPLACE FUNCTION advance_my_mission(p_mission_id UUID)
RETURNS psy_mission_progress
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_patient_id UUID;
  v_mission    psy_missions%ROWTYPE;
  v_cycle      DATE;
  v_row        psy_mission_progress%ROWTYPE;
BEGIN
  SELECT id INTO v_patient_id FROM psy_patients WHERE user_id = auth.uid() LIMIT 1;
  IF v_patient_id IS NULL THEN RAISE EXCEPTION 'Rekod pesakit tidak dijumpai.'; END IF;

  SELECT * INTO v_mission FROM psy_missions WHERE id = p_mission_id;
  IF v_mission.id IS NULL OR NOT v_mission.is_active THEN RAISE EXCEPTION 'Mission tidak sah.'; END IF;
  IF v_mission.mission_type <> 'manual' THEN RAISE EXCEPTION 'Mission ini dikemaskini automatik, bukan secara manual.'; END IF;
  IF v_mission.start_date IS NOT NULL AND CURRENT_DATE < v_mission.start_date THEN RAISE EXCEPTION 'Mission belum bermula.'; END IF;
  IF v_mission.end_date IS NOT NULL AND CURRENT_DATE > v_mission.end_date THEN RAISE EXCEPTION 'Mission sudah tamat.'; END IF;

  v_cycle := CASE WHEN v_mission.repeat_cycle = 'weekly' THEN date_trunc('week', CURRENT_DATE)::date ELSE DATE '2000-01-01' END;

  INSERT INTO psy_mission_progress (mission_id, patient_id, cycle_start)
  VALUES (p_mission_id, v_patient_id, v_cycle)
  ON CONFLICT (mission_id, patient_id, cycle_start) DO NOTHING;

  SELECT * INTO v_row FROM psy_mission_progress
    WHERE mission_id = p_mission_id AND patient_id = v_patient_id AND cycle_start = v_cycle;

  IF v_row.status IN ('completed', 'claimed') THEN RAISE EXCEPTION 'Mission ini sudah selesai untuk tempoh semasa.'; END IF;
  IF v_row.last_advanced_on = CURRENT_DATE THEN RAISE EXCEPTION 'Anda sudah kemaskini mission ini hari ini.'; END IF;

  UPDATE psy_mission_progress SET
    progress = LEAST(v_mission.target, progress + 1),
    last_advanced_on = CURRENT_DATE,
    status = CASE WHEN progress + 1 >= v_mission.target THEN 'completed' ELSE 'in_progress' END,
    completed_at = CASE WHEN progress + 1 >= v_mission.target THEN now() ELSE completed_at END,
    updated_at = now()
  WHERE id = v_row.id
  RETURNING * INTO v_row;

  RETURN v_row;
END;
$$;

GRANT EXECUTE ON FUNCTION advance_my_mission(UUID) TO authenticated;

CREATE OR REPLACE FUNCTION claim_mission_reward(p_progress_id UUID)
RETURNS psy_mission_progress
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_patient_id UUID;
  v_row        psy_mission_progress%ROWTYPE;
  v_mission    psy_missions%ROWTYPE;
BEGIN
  SELECT id INTO v_patient_id FROM psy_patients WHERE user_id = auth.uid() LIMIT 1;
  IF v_patient_id IS NULL THEN RAISE EXCEPTION 'Rekod pesakit tidak dijumpai.'; END IF;

  SELECT * INTO v_row FROM psy_mission_progress WHERE id = p_progress_id AND patient_id = v_patient_id;
  IF v_row.id IS NULL THEN RAISE EXCEPTION 'Progress mission tidak dijumpai.'; END IF;
  IF v_row.status = 'claimed' THEN RAISE EXCEPTION 'Ganjaran ini sudah dituntut.'; END IF;
  IF v_row.status <> 'completed' THEN RAISE EXCEPTION 'Mission belum selesai.'; END IF;

  SELECT * INTO v_mission FROM psy_missions WHERE id = v_row.mission_id;

  UPDATE psy_mission_progress SET status = 'claimed', claimed_at = now(), updated_at = now()
  WHERE id = p_progress_id RETURNING * INTO v_row;

  IF v_mission.reward_points > 0 THEN
    INSERT INTO psy_points_ledger (patient_id, source_type, source_ref, points, note)
    VALUES (v_patient_id, 'mission_complete', v_row.id, v_mission.reward_points, 'Mission selesai: ' || v_mission.name);
  END IF;

  RETURN v_row;
END;
$$;

GRANT EXECUTE ON FUNCTION claim_mission_reward(UUID) TO authenticated;

CREATE OR REPLACE FUNCTION trg_advance_daily_checkin_missions()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_mission  RECORD;
  v_cycle    DATE;
  v_has_paid BOOLEAN;
BEGIN
  FOR v_mission IN
    SELECT * FROM psy_missions
    WHERE mission_type = 'daily_checkin' AND is_active
      AND (start_date IS NULL OR start_date <= NEW.log_date)
      AND (end_date IS NULL OR end_date >= NEW.log_date)
  LOOP
    IF v_mission.customer_eligibility IN ('new', 'existing') THEN
      SELECT EXISTS (SELECT 1 FROM psy_payments WHERE patient_id = NEW.patient_id AND status = 'completed') INTO v_has_paid;
      IF v_mission.customer_eligibility = 'new' AND v_has_paid THEN CONTINUE; END IF;
      IF v_mission.customer_eligibility = 'existing' AND NOT v_has_paid THEN CONTINUE; END IF;
    END IF;

    v_cycle := CASE WHEN v_mission.repeat_cycle = 'weekly' THEN date_trunc('week', NEW.log_date)::date ELSE DATE '2000-01-01' END;

    INSERT INTO psy_mission_progress (mission_id, patient_id, cycle_start)
    VALUES (v_mission.id, NEW.patient_id, v_cycle)
    ON CONFLICT (mission_id, patient_id, cycle_start) DO NOTHING;

    UPDATE psy_mission_progress SET
      progress = LEAST(v_mission.target, progress + 1),
      last_advanced_on = NEW.log_date,
      status = CASE WHEN status = 'in_progress' AND progress + 1 >= v_mission.target THEN 'completed' ELSE status END,
      completed_at = CASE WHEN status = 'in_progress' AND progress + 1 >= v_mission.target THEN now() ELSE completed_at END,
      updated_at = now()
    WHERE mission_id = v_mission.id AND patient_id = NEW.patient_id AND cycle_start = v_cycle
      AND status = 'in_progress' AND (last_advanced_on IS DISTINCT FROM NEW.log_date);
  END LOOP;
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE LOG 'trg_advance_daily_checkin_missions: %', SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_advance_daily_checkin_missions ON psy_kepatuhan_log;
CREATE TRIGGER trg_advance_daily_checkin_missions
  AFTER INSERT ON psy_kepatuhan_log
  FOR EACH ROW EXECUTE FUNCTION trg_advance_daily_checkin_missions();

-- ════════════════════════════════════════════════════════════════
-- 12) Redesign Produk & Bahan: Seller/Platform jadi entiti MASTER berasingan.
-- ════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS psy_recommended_sellers (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name              TEXT NOT NULL,
  platform          TEXT,
  link              TEXT,
  seller_type       TEXT,
  logo_url          TEXT,
  contact_email     TEXT,
  contact_phone     TEXT,
  address           TEXT,
  notes             TEXT,
  status            TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active','inactive')),
  last_verified_at  TIMESTAMPTZ,
  created_by        UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  updated_by        UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  created_at        TIMESTAMPTZ DEFAULT now(),
  updated_at        TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_rec_sellers_status ON psy_recommended_sellers(status);
CREATE INDEX IF NOT EXISTS idx_rec_sellers_platform ON psy_recommended_sellers(platform);
ALTER TABLE psy_recommended_sellers ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Staff manage recommended sellers" ON psy_recommended_sellers;
CREATE POLICY "Staff manage recommended sellers" ON psy_recommended_sellers FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
  WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

CREATE TABLE IF NOT EXISTS psy_recommended_products (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name              TEXT NOT NULL,
  category          TEXT,
  purpose           TEXT,
  qty_note          TEXT,
  requirement_level TEXT NOT NULL DEFAULT 'cadangan'
                    CHECK (requirement_level IN ('wajib','cadangan','opsyenal')),
  price             NUMERIC(10,2),
  image_url         TEXT,
  notes             TEXT,
  is_active         BOOLEAN NOT NULL DEFAULT true,
  last_verified_at  TIMESTAMPTZ,
  created_by        UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  updated_by        UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  created_at        TIMESTAMPTZ DEFAULT now(),
  updated_at        TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE psy_recommended_products ADD COLUMN IF NOT EXISTS updated_by UUID REFERENCES psy_profiles(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS idx_rec_products_active ON psy_recommended_products(is_active);
ALTER TABLE psy_recommended_products ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Staff manage recommended products" ON psy_recommended_products;
CREATE POLICY "Staff manage recommended products" ON psy_recommended_products FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
  WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DO $$
DECLARE
  has_table boolean;
  has_seller_id boolean;
BEGIN
  SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'psy_recommended_product_sellers') INTO has_table;

  IF NOT has_table THEN
    CREATE TABLE psy_recommended_product_sellers (
      id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      product_id        UUID NOT NULL REFERENCES psy_recommended_products(id) ON DELETE CASCADE,
      seller_id         UUID NOT NULL REFERENCES psy_recommended_sellers(id) ON DELETE CASCADE,
      link              TEXT,
      price             NUMERIC(10,2),
      is_primary        BOOLEAN NOT NULL DEFAULT false,
      last_verified_at  TIMESTAMPTZ,
      notes             TEXT,
      sort_order        INT DEFAULT 0,
      created_at        TIMESTAMPTZ DEFAULT now()
    );
  ELSE
    SELECT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'psy_recommended_product_sellers' AND column_name = 'seller_id') INTO has_seller_id;

    IF NOT has_seller_id THEN
      ALTER TABLE psy_recommended_product_sellers ADD COLUMN seller_id UUID REFERENCES psy_recommended_sellers(id) ON DELETE CASCADE;
      ALTER TABLE psy_recommended_product_sellers ADD COLUMN IF NOT EXISTS is_primary BOOLEAN NOT NULL DEFAULT false;
      ALTER TABLE psy_recommended_product_sellers ADD COLUMN IF NOT EXISTS last_verified_at TIMESTAMPTZ;

      INSERT INTO psy_recommended_sellers (name, platform, link)
      SELECT DISTINCT
        COALESCE(NULLIF(s.seller_name, ''), NULLIF(s.platform, ''), 'Seller tanpa nama'),
        NULLIF(s.platform, ''),
        NULLIF(s.link, '')
      FROM psy_recommended_product_sellers s
      WHERE NOT EXISTS (
        SELECT 1 FROM psy_recommended_sellers x
        WHERE x.name = COALESCE(NULLIF(s.seller_name, ''), NULLIF(s.platform, ''), 'Seller tanpa nama')
          AND COALESCE(x.platform, '') = COALESCE(NULLIF(s.platform, ''), '')
      );

      UPDATE psy_recommended_product_sellers s
      SET seller_id = x.id
      FROM psy_recommended_sellers x
      WHERE s.seller_id IS NULL
        AND x.name = COALESCE(NULLIF(s.seller_name, ''), NULLIF(s.platform, ''), 'Seller tanpa nama')
        AND COALESCE(x.platform, '') = COALESCE(NULLIF(s.platform, ''), '');

      DELETE FROM psy_recommended_product_sellers WHERE seller_id IS NULL;

      ALTER TABLE psy_recommended_product_sellers ALTER COLUMN seller_id SET NOT NULL;
    END IF;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_rec_prod_sellers_product ON psy_recommended_product_sellers(product_id);
CREATE INDEX IF NOT EXISTS idx_rec_prod_sellers_seller ON psy_recommended_product_sellers(seller_id);
CREATE UNIQUE INDEX IF NOT EXISTS uq_rec_product_seller ON psy_recommended_product_sellers(product_id, seller_id);
ALTER TABLE psy_recommended_product_sellers ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Staff manage recommended product sellers" ON psy_recommended_product_sellers;
CREATE POLICY "Staff manage recommended product sellers" ON psy_recommended_product_sellers FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
  WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

CREATE TABLE IF NOT EXISTS psy_package_recommended_products (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  package_id  TEXT NOT NULL,
  product_id  UUID NOT NULL REFERENCES psy_recommended_products(id) ON DELETE CASCADE,
  week_number INT,
  qty         INT DEFAULT 1,
  notes       TEXT,
  created_at  TIMESTAMPTZ DEFAULT now(),
  UNIQUE (package_id, product_id, week_number)
);
ALTER TABLE psy_package_recommended_products ADD COLUMN IF NOT EXISTS qty INT DEFAULT 1;
ALTER TABLE psy_package_recommended_products ADD COLUMN IF NOT EXISTS notes TEXT;
CREATE INDEX IF NOT EXISTS idx_rec_pkg_map_package ON psy_package_recommended_products(package_id);
CREATE INDEX IF NOT EXISTS idx_rec_pkg_map_product ON psy_package_recommended_products(product_id);
ALTER TABLE psy_package_recommended_products ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Staff manage package recommended products" ON psy_package_recommended_products;
CREATE POLICY "Staff manage package recommended products" ON psy_package_recommended_products FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
  WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- ════════════════════════════════════════════════════════════════
-- 13) Gabungan 3 migration tertunda Produk & Bahan (susulan #12 di atas).
-- ════════════════════════════════════════════════════════════════
ALTER TABLE psy_recommended_products ADD COLUMN IF NOT EXISTS image_urls JSONB DEFAULT '[]';

UPDATE psy_recommended_products
SET image_urls = jsonb_build_array(image_url)
WHERE image_url IS NOT NULL AND (image_urls IS NULL OR image_urls = '[]'::jsonb);

ALTER TABLE psy_recommended_sellers ADD COLUMN IF NOT EXISTS description TEXT;
ALTER TABLE psy_recommended_sellers ADD COLUMN IF NOT EXISTS verified_by UUID REFERENCES psy_profiles(id) ON DELETE SET NULL;

ALTER TABLE psy_recommended_products ADD COLUMN IF NOT EXISTS item_type TEXT NOT NULL DEFAULT 'barang';
ALTER TABLE psy_recommended_products ADD COLUMN IF NOT EXISTS address TEXT;
ALTER TABLE psy_recommended_products ADD COLUMN IF NOT EXISTS area TEXT;
ALTER TABLE psy_recommended_products ADD COLUMN IF NOT EXISTS maps_url TEXT;
ALTER TABLE psy_recommended_products ADD COLUMN IF NOT EXISTS contact_phone TEXT;
ALTER TABLE psy_recommended_products ADD COLUMN IF NOT EXISTS website TEXT;
ALTER TABLE psy_recommended_products ADD COLUMN IF NOT EXISTS operating_hours TEXT;
ALTER TABLE psy_recommended_products ADD COLUMN IF NOT EXISTS menu_items TEXT;
ALTER TABLE psy_recommended_products ADD COLUMN IF NOT EXISTS price_range TEXT;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'psy_recommended_products_item_type_check'
  ) THEN
    ALTER TABLE psy_recommended_products
      ADD CONSTRAINT psy_recommended_products_item_type_check
      CHECK (item_type IN ('barang','kedai_makan'));
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_rec_products_item_type ON psy_recommended_products(item_type);

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'psy_recommended_restaurants') THEN
    INSERT INTO psy_recommended_products (
      item_type, name, category, address, maps_url, menu_items, price_range,
      notes, is_active, last_verified_at, created_by
    )
    SELECT
      'kedai_makan', r.name, r.category, r.location, r.maps_url, r.menu_notes, r.price_range,
      r.notes, (r.status = 'active'), r.last_verified_at, r.created_by
    FROM psy_recommended_restaurants r
    WHERE NOT EXISTS (
      SELECT 1 FROM psy_recommended_products p
      WHERE p.item_type = 'kedai_makan' AND p.name = r.name
    );
  END IF;
END $$;

DELETE FROM psy_modules WHERE code = 'direktori_cadangan';

DROP TABLE IF EXISTS psy_recommended_restaurants;

-- ════════════════════════════════════════════════════════════════
-- 14) Fasa 2b — Promosi sebagai Voucher (auto-push ke wallet pesakit).
-- ════════════════════════════════════════════════════════════════
ALTER TABLE psy_promo_codes
  ADD COLUMN IF NOT EXISTS promotion_type TEXT NOT NULL DEFAULT 'promo_code';

ALTER TABLE psy_promo_codes DROP CONSTRAINT IF EXISTS psy_promo_codes_promotion_type_check;
ALTER TABLE psy_promo_codes ADD CONSTRAINT psy_promo_codes_promotion_type_check
  CHECK (promotion_type IN ('promo_code', 'voucher'));

CREATE OR REPLACE FUNCTION _push_promo_wallet_rows(p_promo_id UUID)
RETURNS INT
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_promo psy_promo_codes%ROWTYPE;
  v_expires_at TIMESTAMPTZ;
  v_count INT;
BEGIN
  SELECT * INTO v_promo FROM psy_promo_codes WHERE id = p_promo_id;
  IF v_promo.id IS NULL OR v_promo.promotion_type IS DISTINCT FROM 'voucher' OR NOT v_promo.is_active THEN
    RETURN 0;
  END IF;

  v_expires_at := CASE
    WHEN v_promo.valid_until IS NOT NULL THEN v_promo.valid_until::timestamptz + INTERVAL '1 day' - INTERVAL '1 second'
    WHEN v_promo.wallet_validity_days IS NOT NULL THEN now() + (v_promo.wallet_validity_days || ' days')::interval
    ELSE NULL
  END;

  INSERT INTO psy_promo_claims (patient_id, promo_id, code, discount_type, discount_value, min_subtotal, expires_at)
  SELECT p.id, v_promo.id, v_promo.code, v_promo.discount_type, v_promo.discount_value, v_promo.min_subtotal, v_expires_at
  FROM psy_patients p
  WHERE p.status <> 'deleted'
    AND (
      v_promo.customer_eligibility = 'all' OR v_promo.customer_eligibility IS NULL
      OR (v_promo.customer_eligibility = 'new' AND NOT EXISTS (SELECT 1 FROM psy_payments pay WHERE pay.patient_id = p.id AND pay.status = 'completed'))
      OR (v_promo.customer_eligibility = 'existing' AND EXISTS (SELECT 1 FROM psy_payments pay WHERE pay.patient_id = p.id AND pay.status = 'completed'))
      OR (v_promo.customer_eligibility = 'selected' AND p.id = ANY(COALESCE(v_promo.selected_patient_ids, ARRAY[]::UUID[])))
    )
  ON CONFLICT (promo_id, patient_id) DO NOTHING;

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

CREATE OR REPLACE FUNCTION trg_promo_push_voucher()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NEW.promotion_type = 'voucher' AND NEW.is_active THEN
    PERFORM _push_promo_wallet_rows(NEW.id);
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_promo_push_voucher ON psy_promo_codes;
CREATE TRIGGER trg_promo_push_voucher
  AFTER INSERT OR UPDATE ON psy_promo_codes
  FOR EACH ROW EXECUTE FUNCTION trg_promo_push_voucher();

-- ════════════════════════════════════════════════════════════════
-- 15) Fasa 2 — Promo & Voucher (staff web): Cannot Stack utk MVP, medan
-- baharu max_discount/show_on_shop/customer_eligibility/selected_patient_ids,
-- voucher_code/title/min_subtotal/applies_to/issued_by pada psy_vouchers.
-- ════════════════════════════════════════════════════════════════
ALTER TABLE psy_promo_codes
  ADD COLUMN IF NOT EXISTS name                  TEXT,
  ADD COLUMN IF NOT EXISTS max_discount          NUMERIC(10,2),
  ADD COLUMN IF NOT EXISTS show_on_shop          BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS customer_eligibility  TEXT NOT NULL DEFAULT 'all',
  ADD COLUMN IF NOT EXISTS selected_patient_ids  UUID[];

ALTER TABLE psy_promo_codes DROP CONSTRAINT IF EXISTS psy_promo_codes_max_discount_check;
ALTER TABLE psy_promo_codes ADD CONSTRAINT psy_promo_codes_max_discount_check
  CHECK (max_discount IS NULL OR max_discount > 0);

ALTER TABLE psy_promo_codes DROP CONSTRAINT IF EXISTS psy_promo_codes_customer_eligibility_check;
ALTER TABLE psy_promo_codes ADD CONSTRAINT psy_promo_codes_customer_eligibility_check
  CHECK (customer_eligibility IN ('all','new','existing','selected'));

UPDATE psy_promo_codes SET customer_eligibility = 'new'
  WHERE new_customer_only = true AND customer_eligibility = 'all';

ALTER TABLE psy_promo_codes ALTER COLUMN stackable SET DEFAULT false;

ALTER TABLE psy_vouchers
  ADD COLUMN IF NOT EXISTS voucher_code  TEXT NOT NULL DEFAULT ('VC' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8))),
  ADD COLUMN IF NOT EXISTS title         TEXT,
  ADD COLUMN IF NOT EXISTS min_subtotal  NUMERIC(10,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS applies_to    TEXT NOT NULL DEFAULT 'all',
  ADD COLUMN IF NOT EXISTS applies_to_values TEXT[],
  ADD COLUMN IF NOT EXISTS issued_by     UUID REFERENCES psy_profiles(id) ON DELETE SET NULL;

ALTER TABLE psy_vouchers DROP CONSTRAINT IF EXISTS psy_vouchers_applies_to_check;
ALTER TABLE psy_vouchers ADD CONSTRAINT psy_vouchers_applies_to_check
  CHECK (applies_to IN ('all','product','category','package'));

CREATE UNIQUE INDEX IF NOT EXISTS idx_psy_vouchers_voucher_code ON psy_vouchers(voucher_code);

ALTER TABLE psy_promo_codes
  ADD COLUMN IF NOT EXISTS start_time TIME NOT NULL DEFAULT '00:00:00',
  ADD COLUMN IF NOT EXISTS end_time   TIME NOT NULL DEFAULT '23:59:59';

-- ════════════════════════════════════════════════════════════════
-- 16) Conflict checking utk Reaksi & Tindakan — staf tetapkan sendiri
-- pasangan tindakan yang bercanggah bila tercadang serentak.
-- ════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS psy_reaksi_conflict_pairs (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  action_id_1 UUID NOT NULL REFERENCES psy_reaksi_actions(id) ON DELETE CASCADE,
  action_id_2 UUID NOT NULL REFERENCES psy_reaksi_actions(id) ON DELETE CASCADE,
  note        TEXT,
  created_by  UUID REFERENCES psy_profiles(id),
  created_at  TIMESTAMPTZ DEFAULT now(),
  CONSTRAINT chk_reaksi_conflict_pair_distinct CHECK (action_id_1 <> action_id_2)
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_reaksi_conflict_pair
  ON psy_reaksi_conflict_pairs (LEAST(action_id_1, action_id_2), GREATEST(action_id_1, action_id_2));

ALTER TABLE psy_reaksi_conflict_pairs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff manage reaksi conflict pairs" ON psy_reaksi_conflict_pairs;
CREATE POLICY "Staff manage reaksi conflict pairs" ON psy_reaksi_conflict_pairs FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "Authenticated read reaksi conflict pairs" ON psy_reaksi_conflict_pairs;
CREATE POLICY "Authenticated read reaksi conflict pairs" ON psy_reaksi_conflict_pairs FOR SELECT
  USING (auth.uid() IS NOT NULL);

ALTER TABLE psy_reaksi_advice_log ADD COLUMN IF NOT EXISTS conflict_pairs JSONB NOT NULL DEFAULT '[]';

-- ════════════════════════════════════════════════════════════════
-- 17) Fasa 5 — Mata Shop. RM1 jumlah produk LAYAK (shop_order tulen sahaja,
-- selepas diskaun, tak termasuk caj penghantaran) = 1 mata, auto bila
-- psy_payments jadi 'completed', dibalikkan bila jadi 'refunded'/'voided'.
-- ════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION _shop_points_eligible_amount(p_payment psy_payments)
RETURNS NUMERIC
LANGUAGE plpgsql
AS $$
DECLARE
  v_items JSONB;
  v_item JSONB;
  v_delivery NUMERIC := 0;
  v_only_shop BOOLEAN := true;
BEGIN
  v_items := p_payment.intent -> 'items';
  IF v_items IS NULL OR jsonb_typeof(v_items) <> 'array' OR jsonb_array_length(v_items) = 0 THEN
    RETURN 0;
  END IF;

  FOR v_item IN SELECT * FROM jsonb_array_elements(v_items) LOOP
    IF (v_item ->> 'type') IS DISTINCT FROM 'shop_order' THEN
      v_only_shop := false;
    ELSE
      v_delivery := v_delivery + (CASE WHEN v_item ->> 'deliveryMethod' = 'pos' THEN 8 ELSE 0 END);
    END IF;
  END LOOP;

  IF NOT v_only_shop THEN
    RETURN 0;
  END IF;

  RETURN GREATEST(0, COALESCE(p_payment.total, 0) - v_delivery);
END;
$$;

CREATE OR REPLACE FUNCTION trg_shop_points_on_payment()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_points INT;
  v_eligible NUMERIC;
BEGIN
  IF NEW.status = 'completed' AND (TG_OP = 'INSERT' OR OLD.status IS DISTINCT FROM 'completed') THEN
    IF NOT EXISTS (SELECT 1 FROM psy_points_ledger WHERE source_type = 'shop_purchase' AND source_ref = NEW.id) THEN
      v_eligible := _shop_points_eligible_amount(NEW);
      v_points := floor(v_eligible)::int;
      IF v_points > 0 AND NEW.patient_id IS NOT NULL THEN
        INSERT INTO psy_points_ledger (patient_id, source_type, source_ref, points, note)
        VALUES (NEW.patient_id, 'shop_purchase', NEW.id, v_points, 'Pembelian Shop — resit ' || COALESCE(NEW.receipt_ref, NEW.id::text));
      END IF;
    END IF;
  END IF;

  IF NEW.status IN ('refunded', 'voided') AND OLD.status IS DISTINCT FROM NEW.status AND OLD.status = 'completed' THEN
    IF EXISTS (SELECT 1 FROM psy_points_ledger WHERE source_type = 'shop_purchase' AND source_ref = NEW.id)
       AND NOT EXISTS (SELECT 1 FROM psy_points_ledger WHERE source_type = 'shop_refund' AND source_ref = NEW.id) THEN
      SELECT -points INTO v_points FROM psy_points_ledger WHERE source_type = 'shop_purchase' AND source_ref = NEW.id;
      IF v_points IS NOT NULL AND v_points <> 0 THEN
        INSERT INTO psy_points_ledger (patient_id, source_type, source_ref, points, note)
        VALUES (NEW.patient_id, 'shop_refund', NEW.id, v_points, 'Pembalikan mata — bayaran ' || NEW.status);
      END IF;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_shop_points_on_payment ON psy_payments;
CREATE TRIGGER trg_shop_points_on_payment
  AFTER INSERT OR UPDATE OF status ON psy_payments
  FOR EACH ROW EXECUTE FUNCTION trg_shop_points_on_payment();

-- ════════════════════════════════════════════════════════════════
-- 18) Surat: auto-hantar WhatsApp kepada pesakit lepas surat sedia.
-- ════════════════════════════════════════════════════════════════
ALTER TABLE psy_letter_issued ADD COLUMN IF NOT EXISTS wa_sent_at      TIMESTAMPTZ;
ALTER TABLE psy_letter_issued ADD COLUMN IF NOT EXISTS wa_send_status TEXT;

-- ════════════════════════════════════════════════════════════════
-- 19) Notification + banner amaran utk pesakit buah pinggang/dialisis.
-- ════════════════════════════════════════════════════════════════
ALTER TABLE psy_patients ADD COLUMN IF NOT EXISTS has_kidney_condition BOOLEAN NOT NULL DEFAULT false;

CREATE OR REPLACE FUNCTION notify_patient_kidney_alert(p_coach_id UUID, p_patient_id UUID, p_patient_name TEXT)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO psy_notifications (user_id, type, title, body, link)
  VALUES (
    p_coach_id,
    'kidney_alert',
    '⚠️ Pesakit Buah Pinggang/Dialisis',
    'Pesakit ' || COALESCE(p_patient_name, 'ini') ||
      ' ada masalah buah pinggang/dialisis — perhatikan kadar peminuman air pesakit ' ||
      '& ELAK penyuntikan/pengambilan darah di lengan yang ada akses dialisis (fistula/kolaps vena).',
    'patient-hub.html?id=' || p_patient_id::TEXT
  );
EXCEPTION WHEN OTHERS THEN
  RAISE LOG 'notify_patient_kidney_alert: %', SQLERRM;
END;
$$;

CREATE OR REPLACE FUNCTION trg_patient_kidney_alert_notify()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_became_flagged BOOLEAN;
  v_coach_changed BOOLEAN;
BEGIN
  v_became_flagged := NEW.has_kidney_condition = true
    AND OLD.has_kidney_condition IS DISTINCT FROM true;
  v_coach_changed := NEW.has_kidney_condition = true
    AND NEW.coach_id IS NOT NULL
    AND NEW.coach_id IS DISTINCT FROM OLD.coach_id;

  IF NOT (v_became_flagged OR v_coach_changed) OR NEW.coach_id IS NULL THEN
    RETURN NEW;
  END IF;

  PERFORM notify_patient_kidney_alert(NEW.coach_id, NEW.id, NEW.full_name);

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE LOG 'trg_patient_kidney_alert_notify: %', SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_patient_kidney_alert_notify ON psy_patients;
CREATE TRIGGER trg_patient_kidney_alert_notify
  AFTER UPDATE ON psy_patients
  FOR EACH ROW EXECUTE FUNCTION trg_patient_kidney_alert_notify();

-- ════════════════════════════════════════════════════════════════
-- 20) RLS psy_procedure_kits — buka baca utk SEMUA pengguna log masuk
-- (kit tak sensitif), dihadkan is_active=true.
-- ════════════════════════════════════════════════════════════════
DROP POLICY IF EXISTS "Read active procedure kits" ON psy_procedure_kits;
CREATE POLICY "Read active procedure kits" ON psy_procedure_kits FOR SELECT
  USING (is_active = true);

-- ════════════════════════════════════════════════════════════════
-- 21) RBAC granular Sesi 1:1 — 2 action baharu 'reschedule'/'complete' utk
-- modul 'rujukan'.
-- ════════════════════════════════════════════════════════════════
INSERT INTO psy_actions (code, label, icon, sort_order) VALUES
  ('reschedule', 'Jadual Semula',    '📅', 32),
  ('complete',   'Tandakan Selesai', '✅', 34)
ON CONFLICT (code) DO UPDATE SET label=EXCLUDED.label, icon=EXCLUDED.icon, sort_order=EXCLUDED.sort_order;

INSERT INTO psy_module_actions (module_code, action_code)
SELECT m.code, a.code
FROM psy_modules m
CROSS JOIN psy_actions a
WHERE a.code IN ('reschedule', 'complete')
ON CONFLICT DO NOTHING;

INSERT INTO psy_role_module_actions (role_code, module_code, action_code)
SELECT r.role_code, 'rujukan', a.action_code
FROM (VALUES ('super_admin'), ('manager'), ('admin'), ('doctor'), ('coach')) AS r(role_code)
CROSS JOIN (VALUES ('reschedule'), ('complete')) AS a(action_code)
ON CONFLICT DO NOTHING;

-- ════════════════════════════════════════════════════════════════
-- 22) Bug sedia ada — polisi RLS write psy_inventory_items tertinggal
-- super_admin, hanya benarkan admin/manager.
-- ════════════════════════════════════════════════════════════════
DROP POLICY IF EXISTS "Admin manage inventory items" ON psy_inventory_items;
CREATE POLICY "Admin manage inventory items" ON psy_inventory_items
  FOR ALL USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff' AND staff_role IN ('super_admin','admin','manager')))
  WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff' AND staff_role IN ('super_admin','admin','manager')));

-- ════════════════════════════════════════════════════════════════
-- 23) Fail print-ready (PDF) dilampir terus pada item inventori.
-- ════════════════════════════════════════════════════════════════
ALTER TABLE psy_inventory_items ADD COLUMN IF NOT EXISTS print_file_url TEXT;
ALTER TABLE psy_inventory_items ADD COLUMN IF NOT EXISTS print_file_size BIGINT;

-- Nota: bucket 'inventory-print-files' dah dicipta kat #9 (had 50MB — jangan
-- insert semula kat sini dgn had 10MB lama, nanti timpa balik had yang dah dinaikkan).

DROP POLICY IF EXISTS "inventory_print_staff_write" ON storage.objects;
CREATE POLICY "inventory_print_staff_write" ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'inventory-print-files' AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "inventory_print_staff_update" ON storage.objects;
CREATE POLICY "inventory_print_staff_update" ON storage.objects
    FOR UPDATE TO authenticated
    USING (bucket_id = 'inventory-print-files' AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "inventory_print_staff_delete" ON storage.objects;
CREATE POLICY "inventory_print_staff_delete" ON storage.objects
    FOR DELETE TO authenticated
    USING (bucket_id = 'inventory-print-files' AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "inventory_print_public_read" ON storage.objects;
CREATE POLICY "inventory_print_public_read" ON storage.objects
    FOR SELECT USING (bucket_id = 'inventory-print-files');

-- ════════════════════════════════════════════════════════════════
-- 24) Treatment plan "auto fallback" 1 sesi/minggu — hari alternatif yang
-- dicuba bila hari utama (preferred_days[0]) tutup.
-- ════════════════════════════════════════════════════════════════
ALTER TABLE psy_treatment_plans ADD COLUMN IF NOT EXISTS schedule_auto_alt_day INT;

-- ════════════════════════════════════════════════════════════════
-- 25) Tarikh kena buat maintenance (diisi manager masa lulus).
-- ════════════════════════════════════════════════════════════════
ALTER TABLE psy_equipment_maintenance
  ADD COLUMN IF NOT EXISTS scheduled_date DATE;

-- ════════════════════════════════════════════════════════════════
-- 26) Lajur gateway_channel — channel SEBENAR pesakit guna di gateway
-- (fpx/card/paynow_online/dll) dari HitPay.
-- ════════════════════════════════════════════════════════════════
ALTER TABLE psy_payments ADD COLUMN IF NOT EXISTS gateway_channel TEXT;

-- ════════════════════════════════════════════════════════════════
-- 27) Jualan Walk-in — jualan produk kepada pembeli bukan pesakit.
-- ════════════════════════════════════════════════════════════════
ALTER TABLE psy_payments ADD COLUMN IF NOT EXISTS buyer_name TEXT;
ALTER TABLE psy_payments ADD COLUMN IF NOT EXISTS buyer_phone TEXT;

CREATE OR REPLACE VIEW vw_payment_ledger WITH (security_invoker = true) AS
SELECT
  p.id::text                       AS id,
  'ISW'                             AS source,
  COALESCE(p.paid_at, p.created_at) AS tx_date,
  p.patient_id,
  COALESCE(pt.full_name, p.buyer_name, CASE WHEN p.patient_id IS NULL THEN 'Walk-in' ELSE 'Pesakit' END) AS contact_name,
  p.total                          AS amount,
  p.payment_method                 AS method,
  COALESCE(p.gateway_provider, p.payment_method) AS provider,
  p.status,
  p.receipt_ref                    AS reference,
  p.ghl_transaction_id,
  p.invoice_number,
  NULL::TIMESTAMPTZ                AS issue_date,
  p.notes
FROM psy_payments p
LEFT JOIN psy_patients pt ON pt.id = p.patient_id

UNION ALL

SELECT
  g.id::text                       AS id,
  'GHL'                             AS source,
  g.ghl_created_at                 AS tx_date,
  g.patient_id,
  g.contact_name,
  g.amount,
  g.payment_provider_type          AS method,
  g.payment_provider_type          AS provider,
  g.status,
  COALESCE(g.invoice_number, g.ghl_transaction_id) AS reference,
  g.ghl_transaction_id,
  g.invoice_number,
  g.issue_date,
  g.entity_source_name             AS notes
FROM psy_ghl_transactions g
WHERE g.ghl_transaction_id IS NULL
   OR g.ghl_transaction_id NOT IN (SELECT ghl_transaction_id FROM psy_payments WHERE ghl_transaction_id IS NOT NULL);

-- ════════════════════════════════════════════════════════════════
-- 28) Produk Shop ikut status Inventori secara automatik — item Inventori
-- jadi Inactive/Discontinued/dipadam → produk dipaut dinyahaktifkan.
-- Tiada auto-aktif semula.
-- ════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION psy_inv_item_is_inactive(p_row JSONB)
RETURNS BOOLEAN LANGUAGE sql IMMUTABLE AS $$
  SELECT COALESCE(p_row->>'status',
                  CASE WHEN p_row->>'is_active' = 'false' THEN 'inactive' ELSE 'active' END) <> 'active'
$$;

CREATE OR REPLACE FUNCTION psy_sync_shop_products_on_inventory_change()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF psy_inv_item_is_inactive(to_jsonb(NEW)) THEN
    UPDATE psy_products
       SET is_active = false, status = 'inactive', updated_at = now()
     WHERE inventory_item_id = NEW.id
       AND (is_active IS DISTINCT FROM false OR status IS DISTINCT FROM 'inactive');
  END IF;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_sync_shop_products_on_inventory_change ON psy_inventory_items;
CREATE TRIGGER trg_sync_shop_products_on_inventory_change
  AFTER INSERT OR UPDATE ON psy_inventory_items
  FOR EACH ROW EXECUTE FUNCTION psy_sync_shop_products_on_inventory_change();

CREATE OR REPLACE FUNCTION psy_deactivate_shop_products_on_inventory_delete()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  UPDATE psy_products
     SET is_active = false, status = 'inactive', updated_at = now()
   WHERE inventory_item_id = OLD.id;
  RETURN OLD;
END $$;

DROP TRIGGER IF EXISTS trg_deactivate_shop_products_on_inventory_delete ON psy_inventory_items;
CREATE TRIGGER trg_deactivate_shop_products_on_inventory_delete
  BEFORE DELETE ON psy_inventory_items
  FOR EACH ROW EXECUTE FUNCTION psy_deactivate_shop_products_on_inventory_delete();

CREATE OR REPLACE FUNCTION psy_check_shop_product_link()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
  v_item JSONB;
BEGIN
  IF NEW.inventory_item_id IS NOT NULL THEN
    SELECT to_jsonb(i) INTO v_item FROM psy_inventory_items i WHERE i.id = NEW.inventory_item_id;
    IF v_item IS NOT NULL AND psy_inv_item_is_inactive(v_item) THEN
      NEW.is_active := false;
      NEW.status := 'inactive';
    END IF;
  END IF;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_check_shop_product_link ON psy_products;
CREATE TRIGGER trg_check_shop_product_link
  BEFORE INSERT OR UPDATE OF inventory_item_id ON psy_products
  FOR EACH ROW EXECUTE FUNCTION psy_check_shop_product_link();

-- ════════════════════════════════════════════════════════════════
-- 29) Delivery log penghantaran Pengumuman — staff kini boleh INSERT terus
-- dari client (pengumuman-baru.html) ke psy_notification_logs (dulu cuma
-- Edge Function service_role yang tulis).
-- ════════════════════════════════════════════════════════════════
DROP POLICY IF EXISTS "notif_logs staff insert" ON psy_notification_logs;
CREATE POLICY "notif_logs staff insert" ON psy_notification_logs FOR INSERT
  WITH CHECK (auth.uid() IN (SELECT id FROM psy_profiles WHERE role = 'staff'));

-- ════════════════════════════════════════════════════════════════
-- 30) Selaraskan claim_promo_code() dengan payments-initiate — tambah semakan
-- customer_eligibility/max_uses_per_patient/start_time/end_time yang sebelum
-- ni cuma ditegakkan di checkout, bukan masa pesakit "claim" kod ke wallet.
-- ════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION claim_promo_code(p_code TEXT)
RETURNS psy_promo_claims
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_patient_id UUID;
  v_promo      psy_promo_codes%ROWTYPE;
  v_now_my     TIMESTAMP;
  v_start_my   TIMESTAMP;
  v_end_my     TIMESTAMP;
  v_expires_at TIMESTAMPTZ;
  v_claim      psy_promo_claims%ROWTYPE;
  v_elig_mode  TEXT;
  v_has_paid   BOOLEAN;
  v_redeemed   INT;
BEGIN
  SELECT id INTO v_patient_id FROM psy_patients WHERE user_id = auth.uid() LIMIT 1;
  IF v_patient_id IS NULL THEN
    RAISE EXCEPTION 'Rekod pesakit tidak dijumpai.';
  END IF;

  SELECT * INTO v_promo FROM psy_promo_codes WHERE code = upper(trim(p_code));
  IF v_promo.id IS NULL OR NOT v_promo.is_active THEN
    RAISE EXCEPTION 'Kod tidak sah atau telah luput.';
  END IF;

  v_now_my := (now() + interval '8 hours');
  v_start_my := CASE WHEN v_promo.valid_from IS NOT NULL THEN v_promo.valid_from::timestamp + COALESCE(v_promo.start_time, '00:00:00')::time ELSE NULL END;
  v_end_my := CASE WHEN v_promo.valid_until IS NOT NULL THEN v_promo.valid_until::timestamp + COALESCE(v_promo.end_time, '23:59:59')::time ELSE NULL END;
  IF (v_start_my IS NOT NULL AND v_now_my < v_start_my) OR (v_end_my IS NOT NULL AND v_now_my > v_end_my) THEN
    RAISE EXCEPTION 'Kod tidak sah atau telah luput.';
  END IF;

  IF v_promo.max_uses IS NOT NULL AND v_promo.used_count >= v_promo.max_uses THEN
    RAISE EXCEPTION 'Kod ini telah mencapai had penggunaan.';
  END IF;

  IF v_promo.max_uses_per_patient IS NOT NULL THEN
    SELECT count(*) INTO v_redeemed FROM psy_promo_redemptions
      WHERE promo_id = v_promo.id AND patient_id = v_patient_id;
    IF v_redeemed >= v_promo.max_uses_per_patient THEN
      RAISE EXCEPTION 'Anda sudah guna had maksimum untuk kod ini.';
    END IF;
  END IF;

  v_elig_mode := COALESCE(v_promo.customer_eligibility, CASE WHEN v_promo.new_customer_only THEN 'new' ELSE 'all' END);
  IF v_elig_mode IN ('new', 'existing') THEN
    SELECT EXISTS (SELECT 1 FROM psy_payments WHERE patient_id = v_patient_id AND status = 'completed') INTO v_has_paid;
    IF v_elig_mode = 'new' AND v_has_paid THEN
      RAISE EXCEPTION 'Kod ini untuk pesakit baharu sahaja.';
    END IF;
    IF v_elig_mode = 'existing' AND NOT v_has_paid THEN
      RAISE EXCEPTION 'Kod ini untuk pesakit sedia ada sahaja.';
    END IF;
  ELSIF v_elig_mode = 'selected' AND NOT (v_patient_id = ANY(COALESCE(v_promo.selected_patient_ids, ARRAY[]::UUID[]))) THEN
    RAISE EXCEPTION 'Kod ini tidak sah untuk akaun anda.';
  END IF;

  v_expires_at := CASE
    WHEN v_promo.valid_until IS NOT NULL THEN v_promo.valid_until::timestamptz + INTERVAL '1 day' - INTERVAL '1 second'
    WHEN v_promo.wallet_validity_days IS NOT NULL THEN now() + (v_promo.wallet_validity_days || ' days')::interval
    ELSE NULL
  END;

  BEGIN
    INSERT INTO psy_promo_claims (patient_id, promo_id, code, discount_type, discount_value, min_subtotal, expires_at)
    VALUES (v_patient_id, v_promo.id, v_promo.code, v_promo.discount_type, v_promo.discount_value, v_promo.min_subtotal, v_expires_at)
    RETURNING * INTO v_claim;
  EXCEPTION WHEN unique_violation THEN
    RAISE EXCEPTION 'Anda sudah menuntut kod ini.';
  END;

  RETURN v_claim;
END;
$$;

-- ════════════════════════════════════════════════════════════════
-- 31) Pelan Mingguan Task Peribadi — pautan SEHALA (task → appointment) dari
-- psy_coach_tasks ke psy_appointments supaya task peribadi sekali sahaja
-- muncul dalam Jadual Temujanji.
-- ════════════════════════════════════════════════════════════════
ALTER TABLE psy_coach_tasks
  ADD COLUMN IF NOT EXISTS linked_appointment_id UUID REFERENCES psy_appointments(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_coach_tasks_linked_appointment ON psy_coach_tasks (linked_appointment_id);

-- ════════════════════════════════════════════════════════════════
-- 32) Library Content — staf pilih sendiri "Kandungan Berkaitan" per item
-- (bukan setakat cadangan automatik ikut topik sama).
-- ════════════════════════════════════════════════════════════════
ALTER TABLE psy_library_items ADD COLUMN IF NOT EXISTS related_item_ids UUID[] DEFAULT '{}';

UPDATE psy_library_items SET related_item_ids = '{}' WHERE related_item_ids IS NULL;

CREATE INDEX IF NOT EXISTS idx_library_related ON psy_library_items USING GIN (related_item_ids);

-- ════════════════════════════════════════════════════════════════
-- 33) Knowledge Base redesign — taksonomi 8 kategori utama (ikut reference
-- client) + subkategori sebenar boleh-tapis (psy_kb_subcategories baharu).
-- 10 kategori lama dinamakan semula/digabung jadi 8 baharu; dokumen sedia
-- ada DIPAUT SEMULA (category_id) supaya tiada dokumen jatuh ke "Tiada
-- Kategori". Semua langkah idempoten (boleh run berulang kali).
-- ════════════════════════════════════════════════════════════════

-- ── Namakan semula kategori sedia ada (1:1) ──
UPDATE psy_kb_categories SET name='SOP & Operations', slug='sop-operations',
  description='SOP operasi, polisi dan aliran kerja pentadbiran dan prosedur harian pusat.',
  icon='📄', color='navy', sort_order=10
  WHERE slug='sop';

UPDATE psy_kb_categories SET name='Clinical Guidelines & Protocols', slug='clinical-guidelines-protocols',
  description='Garis panduan klinikal, keselamatan pesakit dan protokol rawatan yang diluluskan.',
  icon='🩺', color='green', sort_order=20
  WHERE slug='clinical-guidelines';

UPDATE psy_kb_categories SET name='Clinical & Therapy Modules', slug='clinical-therapy-modules',
  description='Modul fisioterapi, kaunseling, bekam dan akupunktur mengikut bidang perkhidmatan.',
  icon='❤️', color='terracotta', sort_order=30
  WHERE slug='psychotherapy-modules';

UPDATE psy_kb_categories SET
  description='Borang pendaftaran, persetujuan termaklum, template laporan dan checklist.',
  icon='📋', color='gold', sort_order=40
  WHERE slug='forms-templates';

UPDATE psy_kb_categories SET name='Staff Training & Development', slug='staff-training-development',
  description='Modul latihan staf, orientasi pekerja baharu, kemahiran komunikasi dan pembangunan profesional.',
  icon='🎓', color='purple', sort_order=50
  WHERE slug='training-materials';

UPDATE psy_kb_categories SET name='Announcements & FAQ', slug='announcements-faq',
  description='Pengumuman rasmi, notis staf dan soalan lazim panduan sistem.',
  icon='📢', color='grey', sort_order=80
  WHERE slug='kb-announcements';

-- ── Kategori baharu (tiada padanan lama) ──
INSERT INTO psy_kb_categories (name, slug, description, icon, color, sort_order) VALUES
  ('Offers, Packages & Sales Workflows', 'offers-packages-sales',
   'Bahan stack tawaran, pakej, harga, aliran kerja jualan dan skrip objection-handling.', '🏷️', 'blue', 60),
  ('Client Education & Wellness Resources', 'client-education-wellness',
   'Bahan pendidikan klien, panduan penjagaan selepas rawatan dan sumber kesejahteraan.', '📖', 'teal', 70)
ON CONFLICT (slug) DO NOTHING;

-- ── Gabung kategori lama yang berlebihan: pindah dokumen ke kategori
-- gabungan baharu DULU, baru padam kategori lama (video-tutorials→staff-
-- training, medication-references→clinical-guidelines, faq→announcements-
-- faq, other-resources→sop-operations) ──
DO $$
DECLARE
  v_target UUID; v_old UUID;
BEGIN
  SELECT id INTO v_old FROM psy_kb_categories WHERE slug = 'video-tutorials';
  IF v_old IS NOT NULL THEN
    SELECT id INTO v_target FROM psy_kb_categories WHERE slug = 'staff-training-development';
    UPDATE psy_kb_resources SET category_id = v_target WHERE category_id = v_old;
    DELETE FROM psy_kb_categories WHERE id = v_old;
  END IF;

  SELECT id INTO v_old FROM psy_kb_categories WHERE slug = 'medication-references';
  IF v_old IS NOT NULL THEN
    SELECT id INTO v_target FROM psy_kb_categories WHERE slug = 'clinical-guidelines-protocols';
    UPDATE psy_kb_resources SET category_id = v_target WHERE category_id = v_old;
    DELETE FROM psy_kb_categories WHERE id = v_old;
  END IF;

  SELECT id INTO v_old FROM psy_kb_categories WHERE slug = 'faq';
  IF v_old IS NOT NULL THEN
    SELECT id INTO v_target FROM psy_kb_categories WHERE slug = 'announcements-faq';
    UPDATE psy_kb_resources SET category_id = v_target WHERE category_id = v_old;
    DELETE FROM psy_kb_categories WHERE id = v_old;
  END IF;

  SELECT id INTO v_old FROM psy_kb_categories WHERE slug = 'other-resources';
  IF v_old IS NOT NULL THEN
    SELECT id INTO v_target FROM psy_kb_categories WHERE slug = 'sop-operations';
    UPDATE psy_kb_resources SET category_id = v_target WHERE category_id = v_old;
    DELETE FROM psy_kb_categories WHERE id = v_old;
  END IF;
END $$;

-- ── Subkategori (jadual baharu + medan FK pada psy_kb_resources) ──
CREATE TABLE IF NOT EXISTS psy_kb_subcategories (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  category_id UUID NOT NULL REFERENCES psy_kb_categories(id) ON DELETE CASCADE,
  name        TEXT NOT NULL,
  slug        TEXT UNIQUE NOT NULL,
  icon        TEXT DEFAULT '📄',
  sort_order  INT  DEFAULT 100,
  is_active   BOOLEAN DEFAULT true,
  created_at  TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_kb_subcategories_category ON psy_kb_subcategories(category_id);

ALTER TABLE psy_kb_subcategories ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "kb_subcat_read" ON psy_kb_subcategories;
CREATE POLICY "kb_subcat_read" ON psy_kb_subcategories FOR SELECT USING (kb_is_staff());
DROP POLICY IF EXISTS "kb_subcat_write" ON psy_kb_subcategories;
CREATE POLICY "kb_subcat_write" ON psy_kb_subcategories FOR ALL USING (kb_is_staff()) WITH CHECK (kb_is_staff());

ALTER TABLE psy_kb_resources ADD COLUMN IF NOT EXISTS subcategory_id UUID REFERENCES psy_kb_subcategories(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS idx_kb_res_subcategory ON psy_kb_resources(subcategory_id);

INSERT INTO psy_kb_subcategories (category_id, name, slug, icon, sort_order)
SELECT c.id, v.name, v.slug, v.icon, v.sort_order
FROM (VALUES
  ('sop-operations','Polisi & Prosedur','sop-polisi-prosedur','📜',10),
  ('sop-operations','Pengurusan Janji Temu','sop-janji-temu','📅',20),
  ('sop-operations','Operasi Harian','sop-operasi-harian','🗂️',30),
  ('sop-operations','Keselamatan & Kerahsiaan','sop-keselamatan-kerahsiaan','🔐',40),
  ('sop-operations','Pengurusan Fasiliti','sop-pengurusan-fasiliti','🏢',50),

  ('clinical-guidelines-protocols','Penilaian & Saringan','cgp-penilaian-saringan','🔎',10),
  ('clinical-guidelines-protocols','Protokol Rawatan','cgp-protokol-rawatan','📘',20),
  ('clinical-guidelines-protocols','Pengurusan Risiko','cgp-pengurusan-risiko','⚠️',30),
  ('clinical-guidelines-protocols','Kriteria Rujukan','cgp-kriteria-rujukan','📎',40),
  ('clinical-guidelines-protocols','Standard Keselamatan','cgp-standard-keselamatan','🛡️',50),

  ('clinical-therapy-modules','Fisioterapi','ctm-fisioterapi','🦵',10),
  ('clinical-therapy-modules','Kaunseling & Psikoterapi','ctm-kaunseling-psikoterapi','🧠',20),
  ('clinical-therapy-modules','Bekam','ctm-bekam','🩹',30),
  ('clinical-therapy-modules','Akupunktur','ctm-akupunktur','📍',40),
  ('clinical-therapy-modules','Latihan & Praktikal','ctm-latihan-praktikal','🏋️',50),

  ('forms-templates','Borang Pesakit','ft-borang-pesakit','📝',10),
  ('forms-templates','Persetujuan Termaklum','ft-persetujuan-termaklum','✍️',20),
  ('forms-templates','Template Laporan','ft-template-laporan','📊',30),
  ('forms-templates','Checklist','ft-checklist','☑️',40),
  ('forms-templates','Dokumen Pentadbiran','ft-dokumen-pentadbiran','🗃️',50),

  ('staff-training-development','Staff Onboarding','std-staff-onboarding','👋',10),
  ('staff-training-development','Customer Service & Communication','std-customer-service-comm','💬',20),
  ('staff-training-development','System & Software Training','std-system-software','💻',30),
  ('staff-training-development','Clinical Skills Training','std-clinical-skills','🩺',40),
  ('staff-training-development','Sales & Service Training','std-sales-service','🎯',50),
  ('staff-training-development','Competency & Assessment','std-competency-assessment','✅',60),

  ('offers-packages-sales','Offer Stack','ops-offer-stack','🎁',10),
  ('offers-packages-sales','Pakej & Harga','ops-pakej-harga','💰',20),
  ('offers-packages-sales','Sales Workflow','ops-sales-workflow','🔁',30),
  ('offers-packages-sales','Upsell & Cross-sell','ops-upsell-crosssell','📈',40),
  ('offers-packages-sales','Skrip & Objection Handling','ops-skrip-objection','🗣️',50),
  ('offers-packages-sales','Customer Journey','ops-customer-journey','🧭',60),

  ('client-education-wellness','Psikoedukasi','cew-psikoedukasi','🧩',10),
  ('client-education-wellness','Bahan Kesejahteraan','cew-bahan-kesejahteraan','🌿',20),
  ('client-education-wellness','Lembaran Kerja & Aktiviti','cew-lembaran-aktiviti','📑',30),
  ('client-education-wellness','Panduan Penjagaan Selepas Rawatan','cew-penjagaan-selepas-rawatan','🩺',40),
  ('client-education-wellness','Video & Infografik','cew-video-infografik','🎞️',50),
  ('client-education-wellness','Rujukan & Sumber Bacaan','cew-rujukan-sumber','📚',60),

  ('announcements-faq','Pengumuman Rasmi','af-pengumuman-rasmi','📢',10),
  ('announcements-faq','Notis & Kemas Kini','af-notis-kemaskini','🔔',20),
  ('announcements-faq','Soalan Lazim (FAQ)','af-soalan-lazim','❓',30),
  ('announcements-faq','Panduan Sistem','af-panduan-sistem','🖥️',40),
  ('announcements-faq','Maklumat Penting','af-maklumat-penting','❗',50),
  ('announcements-faq','Arkib Pengumuman','af-arkib-pengumuman','🗄️',60)
) AS v(cat_slug, name, slug, icon, sort_order)
JOIN psy_kb_categories c ON c.slug = v.cat_slug
ON CONFLICT (slug) DO NOTHING;
