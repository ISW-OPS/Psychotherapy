-- ═══════════════════════════════════════════════════════════════════
-- GABUNGAN MIGRATION TERTUNGGAK — audit management Sept 2026 (batch 2)
-- Digabung 2026-09-30 drpd 7 fail berasingan (senarai di bawah), semua
-- ditulis/disemak SELEPAS 20260925_combined_pending.sql (checkpoint gabungan
-- sebelum ni). Semua idempotent (selamat run berulang). Susunan tiada
-- kebergantungan antara satu sama lain (jadual berlainan) KECUALI 2 fail
-- Library — KEKALKAN turutan (rls_package_restrict dulu, workflow_week_audience
-- lepas, policy kedua menggantikan yang pertama dgn versi lebih lengkap).
-- ═══════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────────
-- FAIL: 20260925_library_rls_package_restrict.sql
-- ─────────────────────────────────────────────────────────────────
-- Audit management batch 3 (25 Sept 2026), Tier 7 #2 — isu keselamatan:
-- psy_library_items policy lama "Anyone read library" USING (true) bermakna
-- sekatan package_ids cuma di UI (isLocked() client-side), sesiapa (termasuk
-- tak login) boleh baca content_url semua rekod terus melalui API. Gantikan
-- dgn policy yang benar-benar kuatkuasa sekatan pakej di server.
-- Rujuk: database/schema/13_library_faq.sql, memory project_audit_tier6_7_sept2026.

DROP POLICY IF EXISTS "Anyone read library" ON psy_library_items;
DROP POLICY IF EXISTS "Patients read allowed library" ON psy_library_items;
CREATE POLICY "Patients read allowed library" ON psy_library_items FOR SELECT
  TO authenticated
  USING (
    is_active = true
    AND (
      package_ids IS NULL OR array_length(package_ids, 1) IS NULL
      OR EXISTS (
        SELECT 1 FROM psy_patients p
        LEFT JOIN psy_packages pk
          ON pk.id::text = p.active_package_id OR pk.package_id = p.active_package_id
        WHERE p.user_id = auth.uid()
          AND (p.active_package_id = ANY(package_ids) OR pk.package_id = ANY(package_ids))
      )
    )
  );

-- ─────────────────────────────────────────────────────────────────
-- FAIL: 20260925_library_workflow_week_audience.sql
-- ─────────────────────────────────────────────────────────────────
-- Audit management batch 3 (25 Sept 2026), Tier 7 #1/#2/#3a/#4 — Library.
-- Rujuk: database/schema/13_library_faq.sql, database/schema/24_storage.sql

-- ═══ 1. Kolum baharu psy_library_items ═══
ALTER TABLE psy_library_items ADD COLUMN IF NOT EXISTS week_number INT;
ALTER TABLE psy_library_items ADD COLUMN IF NOT EXISTS staff_roles TEXT[];
ALTER TABLE psy_library_items ADD COLUMN IF NOT EXISTS publish_at TIMESTAMPTZ;

COMMENT ON COLUMN psy_library_items.status IS
  'draft | review | approved | published | archived. is_active = (status=published). Pesakit nampak published sahaja.';
COMMENT ON COLUMN psy_library_items.week_number IS
  'Minggu rawatan (dalam pakej yg dipilih di package_ids) kandungan ni relevan. NULL = semua minggu.';
COMMENT ON COLUMN psy_library_items.staff_roles IS
  'Kalau diisi, kandungan ni RUJUKAN STAF sahaja (bukan pesakit) — hanya staff dgn salah satu peranan ni nampak. NULL/kosong = kandungan pesakit biasa.';
COMMENT ON COLUMN psy_library_items.publish_at IS
  'Kalau diisi & di masa depan, kandungan tak nampak kpd pesakit walau status=published/is_active=true sehingga masa ni sampai (dikuatkuasa di RLS).';

-- ═══ 2. RLS: kuatkuasa sekatan pakej + role + jadual terbit di server ═══
-- (menggantikan policy dari fail sebelum ni dgn versi lebih lengkap)
DROP POLICY IF EXISTS "Anyone read library" ON psy_library_items;
DROP POLICY IF EXISTS "Patients read allowed library" ON psy_library_items;
CREATE POLICY "Patients read allowed library" ON psy_library_items FOR SELECT
  TO authenticated
  USING (
    is_active = true
    AND (staff_roles IS NULL OR array_length(staff_roles, 1) IS NULL)
    AND (publish_at IS NULL OR publish_at <= now())
    AND (
      package_ids IS NULL OR array_length(package_ids, 1) IS NULL
      OR EXISTS (
        SELECT 1 FROM psy_patients p
        LEFT JOIN psy_packages pk
          ON pk.id::text = p.active_package_id OR pk.package_id = p.active_package_id
        WHERE p.user_id = auth.uid()
          AND (p.active_package_id = ANY(package_ids) OR pk.package_id = ANY(package_ids))
      )
    )
  );

-- ═══ 3. Bucket library-media — had saiz/format (dulu tiada langsung) ═══
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('library-media', 'library-media', true, 524288000, ARRAY[
  'video/mp4','video/quicktime','video/webm',
  'audio/mpeg','audio/mp4','audio/x-m4a','audio/wav',
  'image/png','image/jpeg','image/jpg','image/webp',
  'application/pdf','application/msword',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'application/vnd.ms-powerpoint',
  'application/vnd.openxmlformats-officedocument.presentationml.presentation'
])
ON CONFLICT (id) DO UPDATE
  SET public = EXCLUDED.public,
      file_size_limit = EXCLUDED.file_size_limit,
      allowed_mime_types = EXCLUDED.allowed_mime_types;

DROP POLICY IF EXISTS "library_media_staff_write" ON storage.objects;
CREATE POLICY "library_media_staff_write" ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'library-media' AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "library_media_staff_update" ON storage.objects;
CREATE POLICY "library_media_staff_update" ON storage.objects
    FOR UPDATE TO authenticated
    USING (bucket_id = 'library-media' AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "library_media_staff_delete" ON storage.objects;
CREATE POLICY "library_media_staff_delete" ON storage.objects
    FOR DELETE TO authenticated
    USING (bucket_id = 'library-media' AND EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "library_media_public_read" ON storage.objects;
CREATE POLICY "library_media_public_read" ON storage.objects
    FOR SELECT USING (bucket_id = 'library-media');

-- ─────────────────────────────────────────────────────────────────
-- FAIL: 20260925_recommended_directory.sql
-- ─────────────────────────────────────────────────────────────────
-- Audit management 23 Sept 2026, Tier 5 batch 2 module VI & VII — 2 modul
-- BAHARU: Master Produk & Bahan + Direktori Cadangan.
-- Rujuk: database/schema/39_recommended_directory.sql, database/schema/03_rbac_security.sql

-- ═══ 1. Jadual baharu ═══

CREATE TABLE IF NOT EXISTS psy_recommended_products (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name              TEXT NOT NULL,
  category          TEXT,
  purpose           TEXT,
  qty_note          TEXT,
  requirement_level TEXT NOT NULL DEFAULT 'cadangan'
                    CHECK (requirement_level IN ('wajib','cadangan','opsyenal')),
  price             NUMERIC(10,2),
  notes             TEXT,
  is_active         BOOLEAN NOT NULL DEFAULT true,
  last_verified_at  TIMESTAMPTZ,
  created_by        UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  created_at        TIMESTAMPTZ DEFAULT now(),
  updated_at        TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_rec_products_active ON psy_recommended_products(is_active);

ALTER TABLE psy_recommended_products ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff manage recommended products" ON psy_recommended_products;
CREATE POLICY "Staff manage recommended products" ON psy_recommended_products FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
  WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

CREATE TABLE IF NOT EXISTS psy_recommended_product_sellers (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id  UUID NOT NULL REFERENCES psy_recommended_products(id) ON DELETE CASCADE,
  platform    TEXT,
  seller_name TEXT,
  link        TEXT,
  price       NUMERIC(10,2),
  notes       TEXT,
  sort_order  INT DEFAULT 0,
  created_at  TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_rec_sellers_product ON psy_recommended_product_sellers(product_id);

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
  created_at  TIMESTAMPTZ DEFAULT now(),
  UNIQUE (package_id, product_id, week_number)
);

CREATE INDEX IF NOT EXISTS idx_rec_pkg_map_package ON psy_package_recommended_products(package_id);
CREATE INDEX IF NOT EXISTS idx_rec_pkg_map_product ON psy_package_recommended_products(product_id);

ALTER TABLE psy_package_recommended_products ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff manage package recommended products" ON psy_package_recommended_products;
CREATE POLICY "Staff manage package recommended products" ON psy_package_recommended_products FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
  WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

CREATE TABLE IF NOT EXISTS psy_recommended_restaurants (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name              TEXT NOT NULL,
  category          TEXT,
  location          TEXT,
  maps_url          TEXT,
  menu_notes        TEXT,
  price_range       TEXT,
  status            TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active','inactive')),
  notes             TEXT,
  last_verified_at  TIMESTAMPTZ,
  created_by        UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  created_at        TIMESTAMPTZ DEFAULT now(),
  updated_at        TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_rec_restaurants_status ON psy_recommended_restaurants(status);

ALTER TABLE psy_recommended_restaurants ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff manage recommended restaurants" ON psy_recommended_restaurants;
CREATE POLICY "Staff manage recommended restaurants" ON psy_recommended_restaurants FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
  WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- ═══ 2. Pendaftaran RBAC (2 modul baharu) ═══

INSERT INTO psy_modules (code, label, icon, scope, sort_order) VALUES
  ('produk_bahan',      'Produk & Bahan Luar',  '🧴', 'staff', 101),
  ('direktori_cadangan','Direktori Cadangan',   '📇', 'staff', 102)
ON CONFLICT (code) DO UPDATE SET
  label = EXCLUDED.label, icon = EXCLUDED.icon, scope = EXCLUDED.scope, sort_order = EXCLUDED.sort_order;

-- Module × Action — semua action utk 2 modul baharu
INSERT INTO psy_module_actions (module_code, action_code)
SELECT m.code, a.code FROM psy_modules m CROSS JOIN psy_actions a
WHERE m.code IN ('produk_bahan','direktori_cadangan')
ON CONFLICT DO NOTHING;

-- super_admin / manager / admin dapat automatik (grant sedia ada guna
-- "WHERE scope='staff'" blanket query — cuma perlu ULANG langkah 3 di bawah
-- utk 2 modul baharu ni kembang ke create/edit/delete/export).
INSERT INTO psy_role_module_actions (role_code, module_code, action_code)
SELECT 'super_admin', code, 'view' FROM psy_modules WHERE code IN ('produk_bahan','direktori_cadangan')
ON CONFLICT DO NOTHING;
INSERT INTO psy_role_module_actions (role_code, module_code, action_code)
SELECT 'manager', code, 'view' FROM psy_modules WHERE code IN ('produk_bahan','direktori_cadangan')
ON CONFLICT DO NOTHING;
INSERT INTO psy_role_module_actions (role_code, module_code, action_code)
SELECT 'admin', code, 'view' FROM psy_modules WHERE code IN ('produk_bahan','direktori_cadangan')
ON CONFLICT DO NOTHING;
-- Doctor & Coach — paling relevan (beri cadangan kpd pesakit)
INSERT INTO psy_role_module_actions (role_code, module_code, action_code)
SELECT r.role, m.code, 'view'
FROM (VALUES ('doctor'),('coach')) AS r(role)
CROSS JOIN (VALUES ('produk_bahan'),('direktori_cadangan')) AS m(code)
ON CONFLICT DO NOTHING;

-- Kembangkan 'view' → create/edit/delete/export utk role yg baru diberi view di atas
INSERT INTO psy_role_module_actions (role_code, module_code, action_code)
SELECT rma.role_code, rma.module_code, a.code
FROM psy_role_module_actions rma
CROSS JOIN psy_actions a
WHERE rma.module_code IN ('produk_bahan','direktori_cadangan')
  AND rma.action_code = 'view'
  AND a.code IN ('create','edit','delete','export')
ON CONFLICT DO NOTHING;

-- ─────────────────────────────────────────────────────────────────
-- FAIL: 20260928_rename_telesales_role_to_kob.sql
-- ─────────────────────────────────────────────────────────────────
-- Rename legacy role code 'telesales' (label "KOB" di peranan.html, drives
-- Collector/Closer assign dropdown di roles/staff/kob-list.html/kob-detail.html)
-- -> 'kob', ikut niat asal reka bentuk (lihat komen "staff_role 'kob'" di
-- database/schema/09_kob.sql baris 34/38). Keputusan 28 Sept 2026.
--
-- Kebenaran (psy_role_module_actions) DIKEKALKAN apa adanya (~semua modul,
-- keputusan user 28 Sept — bukan direset ke set KOB-focus yg dirangka utk
-- role 'telesale' berasingan di 03_rbac_security.sql; 'telesale' tu kekal
-- tidak digunakan/orphan, tiada kaitan dgn rename ni).
--
-- Guna INSERT+UPDATE+DELETE (bukan UPDATE terus atas psy_roles.code) sebab
-- psy_role_module_actions.role_code ada FK ke psy_roles(code) TANPA
-- ON UPDATE CASCADE — UPDATE PK terus akan gagal dgn FK violation.
-- Idempotent — selamat di-run berulang kali (no-op lepas kali pertama).

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM psy_roles WHERE code = 'telesales')
     AND NOT EXISTS (SELECT 1 FROM psy_roles WHERE code = 'kob') THEN
    INSERT INTO psy_roles (code, label, description, color, icon, is_active, is_system, sort_order)
    SELECT 'kob', label, description, color, icon, is_active, is_system, sort_order
    FROM psy_roles WHERE code = 'telesales';
  END IF;
END $$;

UPDATE psy_role_module_actions SET role_code = 'kob' WHERE role_code = 'telesales';
UPDATE psy_profiles SET staff_role = 'kob' WHERE staff_role = 'telesales';

DELETE FROM psy_roles WHERE code = 'telesales';

-- ─────────────────────────────────────────────────────────────────
-- FAIL: 20260929_ghl_patient_phone_unique.sql
-- ─────────────────────────────────────────────────────────────────
-- Jaring keselamatan DB terhadap bug dedup pesakit GHL (syncContactToPatient
-- gagal senyap cari padanan phone sedia ada, cipta pesakit BAHARU setiap
-- kali dipanggil semula utk contact yg sama — punca sebenar dalam kod masih
-- disiasat 28-29 Sept 2026). Constraint ni tak fix punca, tapi tukar tingkah
-- laku dari "senyap cipta pendua" ke "INSERT gagal terus" — nampak jelas
-- dalam psy_audit_log/errors, bukan senyap corrupt data lagi.
--
-- Skop HANYA referral_source='GHL' (bukan semua psy_patients) — rekod
-- staff-created/self-signup masih boleh kongsi phone (cth ahli keluarga
-- guna nombor sama), cuma pesakit auto-sync GHL yang patut 1 phone = 1 rekod.
CREATE UNIQUE INDEX IF NOT EXISTS idx_psy_patients_ghl_phone_unique
  ON psy_patients (phone) WHERE referral_source = 'GHL' AND phone IS NOT NULL;

-- ─────────────────────────────────────────────────────────────────
-- FAIL: 20260930_package_version_number.sql
-- ─────────────────────────────────────────────────────────────────
-- Version Management pakej (audit management, gantikan corak manual "(new)" dlm
-- nama pakej — lihat pakej.html versionCell()/pakej-edit.html f-version).
-- psy_packages.version_number sudah ADA dlm CREATE TABLE (database/schema/05_packages.sql)
-- utk pemasangan BAHARU, tapi tiada ALTER TABLE ditulis utk DB SEDIA ADA (testing/prod)
-- — kod UI dah siap sejak 18 Sept 2026 tapi lajur ni tak pernah benar-benar wujud
-- di live DB sehingga migration ni dijalankan.
ALTER TABLE psy_packages ADD COLUMN IF NOT EXISTS version_number INT NOT NULL DEFAULT 1;

COMMENT ON COLUMN psy_packages.version_number IS
  'Nombor version pakej (1, 2, 3, ...) — gantikan corak manual "(new)" dalam nama pakej. Version tertinggi bagi Nama Pakej yang sama = version semasa (implicit ikut nombor, tiada medan status berasingan).';

-- ─────────────────────────────────────────────────────────────────
-- FAIL: 20260930_vitals_threshold_governance.sql
-- ─────────────────────────────────────────────────────────────────
-- Audit management batch 3 (29-30 Sept 2026) — Governance ambang vitals.
-- Menggantikan pendekatan lama (20260923_vitals_critical_emergency.sql, TAK PERNAH
-- dijalankan) yang hardcode nombor kritikal terus dalam fungsi SQL tanpa pengesahan
-- doktor. Kini ambang dibaca dari psy_settings.vitals_thresholds (diedit oleh
-- super_admin/doktor di tetapan.html, tab "Ambang Vitals").
--
-- PENTING: critical_min/critical_max SENGAJA null untuk semua vital dalam seed di
-- bawah — automasi Protokol Kecemasan (is_critical → auto-cipta psy_emergency_alerts)
-- TAK AKAN aktif sehingga seseorang isi nilai melalui UI. Migration ni sendiri TIDAK
-- menghidupkan apa-apa automasi baharu.
--
-- Rujuk: database/schema/10_vitals.sql, database/schema/23_settings.sql

-- ═══ 1. Kolum is_critical (belum wujud di prod) ═══
ALTER TABLE psy_vitals ADD COLUMN IF NOT EXISTS is_critical BOOLEAN NOT NULL DEFAULT false;
CREATE INDEX IF NOT EXISTS idx_psy_vitals_abnormal ON psy_vitals(is_abnormal) WHERE is_abnormal = true;

-- ═══ 2. Seed ambang — normal_* sepadan angka client-side sedia ada (tiada perubahan
-- tingkah laku is_abnormal semasa cutover); critical_* kosong sehingga doktor sahkan ═══
INSERT INTO psy_settings (key, value) VALUES
  ('vitals_thresholds', '{
    "bp_systolic":      {"normal_min": 90,   "normal_max": 129,  "critical_min": null, "critical_max": null},
    "bp_diastolic":      {"normal_min": 60,   "normal_max": 84,   "critical_min": null, "critical_max": null},
    "heart_rate":        {"normal_min": 60,   "normal_max": 100,  "critical_min": null, "critical_max": null},
    "temperature":       {"normal_min": 36.1, "normal_max": 37.2, "critical_min": null, "critical_max": null},
    "spo2":              {"normal_min": 95,   "normal_max": null, "critical_min": null, "critical_max": null},
    "respiratory_rate":  {"normal_min": 12,   "normal_max": 20,   "critical_min": null, "critical_max": null}
  }'::jsonb)
ON CONFLICT (key) DO NOTHING;

-- ═══ 3. fn_vitals_compute_critical() — config-driven, exception-safe sepenuhnya
-- (BEFORE trigger; kalau throw, ia boleh sekat SEMUA simpanan vitals klinik) ═══
CREATE OR REPLACE FUNCTION fn_vitals_compute_critical()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
  v_cfg JSONB;
  v_bp_sys JSONB; v_bp_dia JSONB; v_hr JSONB; v_temp JSONB; v_spo2 JSONB; v_rr JSONB;
BEGIN
  NEW.is_critical := false;

  BEGIN
    SELECT value INTO v_cfg FROM psy_settings WHERE key = 'vitals_thresholds';
  EXCEPTION WHEN OTHERS THEN
    v_cfg := NULL;
  END;

  IF v_cfg IS NULL THEN
    RETURN NEW;
  END IF;

  BEGIN
    v_bp_sys := v_cfg -> 'bp_systolic';
    v_bp_dia := v_cfg -> 'bp_diastolic';
    v_hr     := v_cfg -> 'heart_rate';
    v_temp   := v_cfg -> 'temperature';
    v_spo2   := v_cfg -> 'spo2';
    v_rr     := v_cfg -> 'respiratory_rate';

    NEW.is_critical := (
      (NEW.bp_systolic IS NOT NULL AND v_bp_sys IS NOT NULL AND (
        (v_bp_sys->>'critical_min' IS NOT NULL AND NEW.bp_systolic < (v_bp_sys->>'critical_min')::numeric) OR
        (v_bp_sys->>'critical_max' IS NOT NULL AND NEW.bp_systolic >= (v_bp_sys->>'critical_max')::numeric)
      )) OR
      (NEW.bp_diastolic IS NOT NULL AND v_bp_dia IS NOT NULL AND (
        (v_bp_dia->>'critical_min' IS NOT NULL AND NEW.bp_diastolic < (v_bp_dia->>'critical_min')::numeric) OR
        (v_bp_dia->>'critical_max' IS NOT NULL AND NEW.bp_diastolic >= (v_bp_dia->>'critical_max')::numeric)
      )) OR
      (NEW.heart_rate IS NOT NULL AND v_hr IS NOT NULL AND (
        (v_hr->>'critical_min' IS NOT NULL AND NEW.heart_rate < (v_hr->>'critical_min')::numeric) OR
        (v_hr->>'critical_max' IS NOT NULL AND NEW.heart_rate > (v_hr->>'critical_max')::numeric)
      )) OR
      (NEW.temperature IS NOT NULL AND v_temp IS NOT NULL AND (
        (v_temp->>'critical_min' IS NOT NULL AND NEW.temperature < (v_temp->>'critical_min')::numeric) OR
        (v_temp->>'critical_max' IS NOT NULL AND NEW.temperature >= (v_temp->>'critical_max')::numeric)
      )) OR
      (NEW.spo2 IS NOT NULL AND v_spo2 IS NOT NULL AND
        (v_spo2->>'critical_min' IS NOT NULL AND NEW.spo2 < (v_spo2->>'critical_min')::numeric)
      ) OR
      (NEW.respiratory_rate IS NOT NULL AND v_rr IS NOT NULL AND (
        (v_rr->>'critical_min' IS NOT NULL AND NEW.respiratory_rate < (v_rr->>'critical_min')::numeric) OR
        (v_rr->>'critical_max' IS NOT NULL AND NEW.respiratory_rate > (v_rr->>'critical_max')::numeric)
      ))
    );
  EXCEPTION WHEN OTHERS THEN
    RAISE LOG 'fn_vitals_compute_critical: %', SQLERRM;
    NEW.is_critical := false;
  END;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_vitals_compute_critical ON psy_vitals;
CREATE TRIGGER trg_vitals_compute_critical
  BEFORE INSERT OR UPDATE ON psy_vitals
  FOR EACH ROW EXECUTE FUNCTION fn_vitals_compute_critical();

-- TIADA backfill is_critical — config critical_* kosong (NULL) secara default, jadi
-- backfill akan sentiasa false utk semua rekod sedia ada sehingga doktor isi ambang.

COMMENT ON COLUMN psy_vitals.is_critical IS
  'Bacaan kritikal (bahaya klinikal, perlu tindakan segera) — dikira SERVER-SIDE sahaja '
  '(trg_vitals_compute_critical), staf TAK boleh override/uncheck macam is_abnormal. Bila true, '
  'trg_vitals_notify_emergency (18_notifications_automations.sql) auto-cipta/kemaskini kes di '
  'psy_emergency_alerts — Red Emergency Protocol. Ambang dibaca dari psy_settings.vitals_thresholds '
  '(diedit oleh super_admin/doktor di tetapan.html) — kosong (NULL) = automasi TAK aktif utk vital tu.';
