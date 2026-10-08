-- ═══════════════════════════════════════════════════════════════════════════
-- 07 — PELAN RAWATAN
-- Jadual: psy_treatment_plans, psy_plan_weekly_progress, psy_plan_check_ins,
--         psy_plan_compliance, psy_plan_week_overrides, psy_supply_disbursements
-- Fungsi: fn_auto_inactive_on_session_done, fn_complete_expired_treatments
-- ═══════════════════════════════════════════════════════════════════════════

-- ──────────────────────────────────────────────────────────────
-- psy_treatment_plans — pelan rawatan utama setiap pesakit
-- ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS psy_treatment_plans (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id          UUID NOT NULL REFERENCES psy_patients(id),
  doctor_id           UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  name                TEXT NOT NULL,
  template            TEXT,
  duration_unit       TEXT DEFAULT 'week',
  duration_weeks      INT DEFAULT 13,
  current_week        INT DEFAULT 1,
  coaching_schedule   JSONB DEFAULT '[]',
  status              TEXT DEFAULT 'active' CHECK (status IN ('draft','active','completed','paused')),
  -- jadual pilihan pesakit (wizard setup)
  preferred_pair      TEXT,                     -- legacy: fri_sat / sat_sun (tiada CHECK lagi)
  preferred_time_day1 TIME,                     -- jam sesi hari pertama
  preferred_time_day2 TIME,                     -- jam sesi hari kedua
  preferred_days      JSONB DEFAULT NULL,       -- [dow JS 0-6] ikut turutan sesi
  schedule_auto_alt_day INT,                    -- NULL = hari tetap biasa. Diisi (dow JS 0-6) bila
                                                  -- setup guna mod auto fallback (cth preferred_days=[5]
                                                  -- Jumaat, tapi cuba Sabtu(6) kalau Jumaat tutup, cascade
                                                  -- +1 minggu kalau dua-dua tutup — lihat
                                                  -- ssGenerateSingleDayCascade di patient-hub.html /
                                                  -- computeChainedDateSafe di plan-week.html).
  sessions_per_week   INT   DEFAULT NULL,       -- disalin dari pakej masa setup
  schedule_setup_at   TIMESTAMPTZ,
  start_date          DATE,                     -- anchor sebenar Minggu 1
  created_at          TIMESTAMPTZ DEFAULT now()
);

-- Jaringan keselamatan: satu pesakit tak boleh ada 2 plan AKTIF utk pakej (template) yang
-- sama serentak — cth webhook bayaran retry serentak (race condition) cuba insert berganda.
CREATE UNIQUE INDEX IF NOT EXISTS uq_treatment_plans_active_patient_template
  ON psy_treatment_plans(patient_id, template) WHERE status = 'active';

ALTER TABLE psy_treatment_plans ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff manage plans" ON psy_treatment_plans;
CREATE POLICY "Staff manage plans" ON psy_treatment_plans FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "Patients read own plans" ON psy_treatment_plans;
CREATE POLICY "Patients read own plans" ON psy_treatment_plans FOR SELECT
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Patients insert own plans" ON psy_treatment_plans;
CREATE POLICY "Patients insert own plans" ON psy_treatment_plans FOR INSERT
  WITH CHECK (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

-- Patient boleh update plan sendiri untuk setup jadual sahaja
DROP POLICY IF EXISTS "Patients update own plan setup" ON psy_treatment_plans;
CREATE POLICY "Patients update own plan setup" ON psy_treatment_plans FOR UPDATE
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()))
  WITH CHECK (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Staff can read all treatment plans" ON psy_treatment_plans;
CREATE POLICY "Staff can read all treatment plans" ON psy_treatment_plans FOR SELECT
  USING (
    auth.uid() IN (SELECT id FROM psy_profiles WHERE role = 'staff')
    OR auth.uid() IN (SELECT user_id FROM psy_patients WHERE id = patient_id)
  );

COMMENT ON COLUMN psy_treatment_plans.start_date IS
  'Tarikh sebenar program bermula (anchor Minggu 1). NULL = fallback ke created_at. '
  'Guna untuk pesakit yang dimasukkan lewat / mid-program (cth dah di week 7/12) supaya '
  'semua tarikh sesi dikira dari tarikh sebenar, bukan tarikh plan dicipta.';

COMMENT ON COLUMN psy_treatment_plans.preferred_pair IS
  'Pasangan hari pilihan patient: fri_sat (Jumaat+Sabtu) atau sat_sun (Sabtu+Ahad).';

COMMENT ON COLUMN psy_treatment_plans.preferred_time_day1 IS
  'Jam pilihan hari pertama dalam pair (Jumaat untuk fri_sat, Sabtu untuk sat_sun).';

COMMENT ON COLUMN psy_treatment_plans.preferred_time_day2 IS
  'Jam pilihan hari kedua dalam pair (Sabtu untuk fri_sat, Ahad untuk sat_sun).';

COMMENT ON COLUMN psy_treatment_plans.schedule_setup_at IS
  'Bila patient siap setup jadual. NULL = belum setup, tunjuk wizard.';

COMMENT ON COLUMN psy_treatment_plans.preferred_days IS
  'Hari sesi terpilih dalam nombor getDay() JS (0=Ahad..6=Sabtu), ikut turutan sesi. Cth [5,6]=Jum+Sab, [6]=Sab sahaja. Sumber kebenaran baharu; fallback ke preferred_pair utk plan lama.';

COMMENT ON COLUMN psy_treatment_plans.schedule_auto_alt_day IS
  'NULL = hari tetap biasa (preferred_days ikut betul-betul). Diisi (getDay() JS) bila plan disetup
   guna mod "auto fallback" 1 sesi/minggu (staff punya "Setup Jadual Rawatan", pakej tiada Pilihan
   Hari Sesi disetkan) — preferred_days[0] = hari UTAMA (cth Jumaat), lajur ni = hari ALTERNATIF
   (cth Sabtu) yang dicuba kalau hari utama tutup. Dibaca oleh computeChainedDateSafe() di
   plan-week.html supaya cascadeBookFutureWeeks() elak book atas hari yang tutup untuk plan jenis ni.';

COMMENT ON COLUMN psy_treatment_plans.sessions_per_week IS
  'Bilangan sesi/minggu (1-2) disalin dari pakej masa setup jadual.';

-- ──────────────────────────────────────────────────────────────
-- psy_plan_weekly_progress — rekod sesi mingguan (1 baris per sesi)
-- ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS psy_plan_weekly_progress (
  id                       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id                  UUID NOT NULL REFERENCES psy_treatment_plans(id) ON DELETE CASCADE,
  patient_id               UUID NOT NULL REFERENCES psy_patients(id) ON DELETE CASCADE,
  week_number              INT NOT NULL,
  session_day              INT DEFAULT 1
                             CONSTRAINT psy_plan_weekly_progress_session_day_check
                             CHECK (session_day BETWEEN 1 AND 7),
  status                   TEXT NOT NULL
                             CONSTRAINT psy_plan_weekly_progress_status_check
                             CHECK (status IN (
                               'pending','booked','hadir','reschedule','cancel','consultation_done',
                               'extension_pending_payment','extension_paid'
                             )),
  session_type             TEXT NOT NULL DEFAULT 'f2f' CHECK (session_type IN ('f2f','online')),
  session_date             TIMESTAMPTZ,
  meet_link                TEXT,
  score                    INT CHECK (score BETWEEN 0 AND 10),
  -- nota sesi coach (single source of truth)
  notes                    TEXT,
  mood_before              INT,
  mood_after               INT,
  goals_discussed          TEXT[],
  homework_given           TEXT[],
  coach_id                 UUID REFERENCES auth.users(id),
  coach_name               TEXT,
  substitute_coach_id      UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  coaching_checks          JSONB DEFAULT '{}',
  reaksi_pemulihan         JSONB DEFAULT '{}',  -- checklist Reaksi Pemulihan diisi coach masa sesi
  appointment_id           UUID,  -- FK → psy_appointments (dipasang di hujung 08_sessions_scheduling.sql)
  -- extension (minggu tambahan berbayar)
  is_extension             BOOLEAN DEFAULT false,
  extension_for_week       INT,
  extension_price          NUMERIC(10,2),
  extension_paid_at        TIMESTAMPTZ,
  absence_reason           TEXT,
  -- pengesahan kehadiran pesakit
  patient_confirmed        BOOLEAN DEFAULT NULL,
  patient_absence_reason   TEXT DEFAULT NULL,
  patient_confirmed_at     TIMESTAMPTZ DEFAULT NULL,
  confirm_reminder_sent_at TIMESTAMPTZ,  -- dedup peringatan (per sesi)
  confirm_escalated_at     TIMESTAMPTZ,  -- dedup escalation coach (per sesi)
  -- tandatangan pesakit (pilihan; path dalam bucket medical-reports)
  patient_signature_path   TEXT DEFAULT NULL,
  patient_signed_at        TIMESTAMPTZ DEFAULT NULL,
  patient_signed_name      TEXT DEFAULT NULL,
  updated_by               UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  updated_by_name          TEXT,
  created_at               TIMESTAMPTZ DEFAULT now(),
  updated_at               TIMESTAMPTZ DEFAULT now(),
  CONSTRAINT psy_plan_weekly_progress_plan_week_day_key UNIQUE (plan_id, week_number, session_day)
);

CREATE INDEX IF NOT EXISTS idx_psy_weekly_plan ON psy_plan_weekly_progress(plan_id);

CREATE INDEX IF NOT EXISTS idx_psy_weekly_patient ON psy_plan_weekly_progress(patient_id);

-- Index bantu enjin cari sesi belum-sahkan dalam tetingkap
CREATE INDEX IF NOT EXISTS idx_pwp_confirm_window
  ON psy_plan_weekly_progress (session_date)
  WHERE status = 'booked' AND patient_confirmed IS NULL;

ALTER TABLE psy_plan_weekly_progress ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff manage weekly progress" ON psy_plan_weekly_progress;
CREATE POLICY "Staff manage weekly progress" ON psy_plan_weekly_progress FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "Patients read own progress" ON psy_plan_weekly_progress;
CREATE POLICY "Patients read own progress" ON psy_plan_weekly_progress FOR SELECT
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Patients insert own progress" ON psy_plan_weekly_progress;
CREATE POLICY "Patients insert own progress" ON psy_plan_weekly_progress FOR INSERT
  WITH CHECK (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Patients update own progress" ON psy_plan_weekly_progress;
CREATE POLICY "Patients update own progress" ON psy_plan_weekly_progress FOR UPDATE
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Staff can read all weekly progress" ON psy_plan_weekly_progress;
CREATE POLICY "Staff can read all weekly progress" ON psy_plan_weekly_progress FOR SELECT
  USING (
    auth.uid() IN (SELECT id FROM psy_profiles WHERE role = 'staff')
    OR auth.uid() IN (SELECT user_id FROM psy_patients WHERE id = patient_id)
  );

COMMENT ON COLUMN psy_plan_weekly_progress.session_day IS
  '1 = sesi pertama dalam minggu (Jum/Sab), 2 = sesi kedua (Sab/Ahad). Default 1 untuk backward compat.';

COMMENT ON COLUMN psy_plan_weekly_progress.is_extension IS
  'true = minggu tambahan (extension) selepas miss sesi. Perlu bayar sebelum tempah.';

COMMENT ON COLUMN psy_plan_weekly_progress.extension_for_week IS
  'Refer minggu asal yang miss, untuk audit trail.';

COMMENT ON COLUMN psy_plan_weekly_progress.absence_reason IS
  'Sebab pesakit tidak hadir, diisi semasa pesakit menjadual semula (reschedule) sesi yang tertinggal. Dipaparkan kepada staff.';

COMMENT ON COLUMN psy_plan_weekly_progress.substitute_coach_id IS
  'Coach ganti untuk sesi ini sahaja — patient kekal bawah coach asal.';

COMMENT ON COLUMN psy_plan_weekly_progress.reaksi_pemulihan IS
  'Checklist Reaksi Pemulihan diisi coach masa sesi (tracking sahaja, tiada skor). Format: {item_key: true}';

-- Nota: trigger trg_notify_patient_new_week berada dalam
-- 18_notifications_automations.sql bersama fungsinya.

-- ──────────────────────────────────────────────────────────────
-- Fungsi: selesai semua sesi / pakej tamat → auto-complete pelan;
-- pakej sambungan (continuity) beratur di-auto-aktif, jika tiada
-- → pesakit ditanda inactive + outcome completed.
-- ──────────────────────────────────────────────────────────────
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

  -- v_all_done: tiada sesi teras belum selesai + tiada minggu continuity BERBAYAR belum selesai.
  -- Minggu continuity ditanda extension_for_week = 0; absen (extension_for_week >= 1) tak menghalang.
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

  -- 'warded' ditambah 7 Okt 2026 (audit #124) — pesakit masuk wad TIDAK boleh
  -- ditimpa balik ke 'inactive' oleh automasi ni semata kerana sesi lama ditanda
  -- selesai; status klinikal 'warded' dikawal oleh modul Rekod Klinikal Pesakit.
  IF v_pstatus IN ('inactive','archived','deceased','deleted','warded') THEN
    RETURN NEW;
  END IF;

  IF (v_has_core AND v_all_done) OR v_pkg_expired THEN
    -- Pelan lama SELESAI (kekal di History — tiada data dipadam).
    UPDATE psy_treatment_plans SET status = 'completed'
      WHERE id = NEW.plan_id AND status <> 'completed';

    IF v_next_pkg IS NOT NULL AND v_next_pkg <> '' THEN
      -- ── Ada pakej sambungan beratur → AUTO-AKTIF, pesakit KEKAL aktif ──
      UPDATE psy_patients
        SET active_package_id    = v_next_pkg,
            active_package_name  = COALESCE(v_next_name, active_package_name),
            package_purchased_at = now(),
            package_expires_at   = now() + interval '3 months',
            next_package_id      = NULL,
            next_package_name    = NULL,
            status               = 'active'
        WHERE id = v_patient_id;

      -- Purchase beratur → aktif (tempoh 3 bulan bermula dari pengaktifan).
      UPDATE psy_package_purchases
        SET status = 'active', expires_at = now() + interval '3 months'
        WHERE patient_id = v_patient_id AND package_id = v_next_pkg AND status = 'queued';

      -- Cipta pelan baru dari pakej sambungan (jika belum wujud). Baris mingguan dijana
      -- kemudian bila pesakit set jadual (sama seperti pakej baru biasa).
      -- NOT EXISTS di bawah cuma "best-effort" — boleh race bila >1 baris psy_plan_weekly_progress
      -- ditanda hadir hampir serentak (setiap satu cetus trigger ni secara berasingan).
      -- uq_treatment_plans_active_patient_template (unique index) ialah jaringan keselamatan
      -- SEBENAR; tangkap unique_violation di sini supaya UPDATE hadir yang mencetuskan trigger
      -- ni tak gagal walaupun panggilan/trigger lain menang race dulu (punca duplicate plan
      -- prod 7 Ogos — 3 baris "Overhaul Body Diamond Y1" dicipta dlm 44 saat utk 1 pesakit).
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
        NULL; -- plan aktif utk pakej sambungan ni dah dicipta oleh panggilan serentak — abaikan.
      END;
    ELSE
      -- ── Tiada sambungan → pesakit inactive + outcome completed ──
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

DROP TRIGGER IF EXISTS trg_auto_inactive ON psy_plan_weekly_progress;

CREATE TRIGGER trg_auto_inactive
  AFTER UPDATE ON psy_plan_weekly_progress
  FOR EACH ROW
  EXECUTE FUNCTION fn_auto_inactive_on_session_done();

-- ──────────────────────────────────────────────────────────────
-- Audit management (Pelan Mingguan — Status Sesi): elak satu sesi bercanggah
-- (cth "Tidak Hadir"/dijadual-semula TAPI masih bertanda "Disahkan" pesakit).
-- Pengesahan (patient_confirmed) ditulis oleh fungsi berasingan drpd status
-- (markConfirmed di kehadiran.html vs markStatus/appointments.html/dashboard.html
-- yg semuanya tulis terus ke jadual ni) — jadi guard diletak di trigger, bukan
-- disemak berulang kali di setiap laluan JS.
CREATE OR REPLACE FUNCTION fn_clear_confirm_on_status_change()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status IN ('cancel','reschedule') AND NEW.status IS DISTINCT FROM OLD.status THEN
    NEW.patient_confirmed := NULL;
    NEW.patient_confirmed_at := NULL;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_clear_confirm_on_status_change ON psy_plan_weekly_progress;

CREATE TRIGGER trg_clear_confirm_on_status_change
  BEFORE UPDATE ON psy_plan_weekly_progress
  FOR EACH ROW
  EXECUTE FUNCTION fn_clear_confirm_on_status_change();

-- ──────────────────────────────────────────────────────────────
-- psy_plan_check_ins — check-in matlamat pillar (bio/psycho/social/spiritual)
-- ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS psy_plan_check_ins (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id      UUID NOT NULL REFERENCES psy_treatment_plans(id) ON DELETE CASCADE,
  patient_id   UUID NOT NULL REFERENCES psy_patients(id) ON DELETE CASCADE,
  pillar       TEXT NOT NULL CHECK (pillar IN ('bio','psycho','social','spiritual')),
  goal_index   INT NOT NULL,
  goal_text    TEXT,
  completed_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (plan_id, pillar, goal_index)
);

ALTER TABLE psy_plan_check_ins ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Patients manage own check-ins" ON psy_plan_check_ins;
CREATE POLICY "Patients manage own check-ins" ON psy_plan_check_ins FOR ALL
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()))
  WITH CHECK (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Staff read check-ins" ON psy_plan_check_ins;
CREATE POLICY "Staff read check-ins" ON psy_plan_check_ins FOR SELECT
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- ──────────────────────────────────────────────────────────────
-- psy_plan_compliance — kepatuhan rawatan per minggu per sesi
-- ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS psy_plan_compliance (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id     UUID NOT NULL REFERENCES psy_treatment_plans(id) ON DELETE CASCADE,
  patient_id  UUID NOT NULL REFERENCES psy_patients(id) ON DELETE CASCADE,
  week_number INT NOT NULL,
  session_day INT NOT NULL DEFAULT 1,
  madu_sudu   INT,
  nafas_kali  INT,
  bumi_minit  INT,
  berjemur    BOOLEAN,
  pantang     BOOLEAN,
  kelapa_kali INT,
  kolon_kali  INT,
  notes       TEXT,
  created_at  TIMESTAMPTZ DEFAULT now(),
  updated_at  TIMESTAMPTZ DEFAULT now(),
  CONSTRAINT psy_plan_compliance_plan_week_session_key UNIQUE (plan_id, week_number, session_day)
);

CREATE INDEX IF NOT EXISTS idx_psy_compliance_plan ON psy_plan_compliance(plan_id, week_number);

CREATE INDEX IF NOT EXISTS idx_psy_compliance_plan_week_sess
  ON psy_plan_compliance (plan_id, week_number, session_day);

ALTER TABLE psy_plan_compliance ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff manage compliance" ON psy_plan_compliance;
CREATE POLICY "Staff manage compliance" ON psy_plan_compliance FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "Patients manage own compliance" ON psy_plan_compliance;
CREATE POLICY "Patients manage own compliance" ON psy_plan_compliance FOR ALL
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()))
  WITH CHECK (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Staff can read all compliance" ON psy_plan_compliance;
CREATE POLICY "Staff can read all compliance" ON psy_plan_compliance FOR SELECT
  USING (
    auth.uid() IN (SELECT id FROM psy_profiles WHERE role = 'staff')
    OR auth.uid() IN (SELECT user_id FROM psy_patients WHERE id = patient_id)
  );

COMMENT ON COLUMN psy_plan_compliance.session_day IS
  'Sesi dalam minggu (1 atau 2) untuk kepatuhan ini. Default 1.';

-- ──────────────────────────────────────────────────────────────
-- psy_plan_week_overrides — pengecualian per-pesakit per-minggu
-- (bekalan, sesi, hari-sesi, bimbingan, aktiviti). Templat pakej = DEFAULT;
-- logik baca di UI: override ?? default_pakej.
-- ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS psy_plan_week_overrides (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id               UUID NOT NULL REFERENCES psy_treatment_plans(id) ON DELETE CASCADE,
  week_number           INT  NOT NULL,
  patient_id            UUID REFERENCES psy_patients(id) ON DELETE CASCADE,
  sessions_override     INT
                          CONSTRAINT psy_plan_week_overrides_sessions_override_check
                          CHECK (sessions_override BETWEEN 1 AND 7),
  supplies_override     JSONB,  -- NULL=ikut pakej; []=tiada bekalan; [..]=ganti penuh
  session_days_override JSONB,
  guidance_override     JSONB,
  aktiviti_override     JSONB,
  note                  TEXT,
  updated_by            UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  updated_at            TIMESTAMPTZ DEFAULT now(),
  CONSTRAINT psy_plan_week_overrides_plan_id_week_number_key UNIQUE (plan_id, week_number)
);

CREATE INDEX IF NOT EXISTS idx_psy_plan_week_overrides_plan
  ON psy_plan_week_overrides(plan_id, week_number);

ALTER TABLE psy_plan_week_overrides ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff manage week overrides" ON psy_plan_week_overrides;
CREATE POLICY "Staff manage week overrides" ON psy_plan_week_overrides FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "Patients read own week overrides" ON psy_plan_week_overrides;
CREATE POLICY "Patients read own week overrides" ON psy_plan_week_overrides FOR SELECT
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

COMMENT ON TABLE psy_plan_week_overrides IS
  'Pengecualian bekalan/sesi per-pesakit per-minggu. Kalau tiada baris = ikut default pakej sepenuhnya.';

COMMENT ON COLUMN psy_plan_week_overrides.session_days_override IS
  'Hari-sesi aktif minggu ini untuk pesakit ini. NULL=ikut pakej; [1,2]/[1]/[2].';

COMMENT ON COLUMN psy_plan_week_overrides.guidance_override IS
  'Bimbingan/Calling khas pesakit ini per-sesi. {"1":[...],"2":[...]}. NULL=ikut pakej; []=tiada.';

COMMENT ON COLUMN psy_plan_week_overrides.aktiviti_override IS
  'Aktiviti khas pesakit ini per-sesi. {"1":[...],"2":[...]}. NULL=ikut pakej; []=tiada.';

-- ──────────────────────────────────────────────────────────────
-- psy_supply_disbursements — barang diberi kepada pesakit dari stok inventori
-- ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS psy_supply_disbursements (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id    UUID NOT NULL REFERENCES psy_patients(id) ON DELETE CASCADE,
  item_id       UUID,  -- FK → psy_inventory_items (dipasang di hujung 14_products_inventory.sql)
  item_name     TEXT NOT NULL,
  unit          TEXT,
  qty           NUMERIC(10,2) NOT NULL,
  notes         TEXT,
  given_by      UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  given_by_name TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE psy_supply_disbursements ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "supply_disb_staff" ON psy_supply_disbursements;
CREATE POLICY "supply_disb_staff" ON psy_supply_disbursements FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- ──────────────────────────────────────────────────────────────
-- Fungsi: auto-complete pelan bila pakej pesakit tamat tempoh
-- (panggil manual atau via pg_cron harian)
-- ──────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION fn_complete_expired_treatments()
RETURNS TABLE (patient_id UUID, plan_id UUID, action TEXT) AS $$
BEGIN
  RETURN QUERY
  WITH expired_patients AS (
    SELECT p.id AS pat_id, p.user_id, p.active_package_name
    FROM psy_patients p
    WHERE p.active_package_id IS NOT NULL
      AND p.package_expires_at IS NOT NULL
      AND p.package_expires_at < now()
      AND (p.outcome_status IS NULL OR p.outcome_status <> 'completed')
  ),
  plan_updates AS (
    UPDATE psy_treatment_plans tp
       SET status = 'completed'
      FROM expired_patients ep
     WHERE tp.patient_id = ep.pat_id
       AND tp.status = 'active'
    RETURNING tp.id, tp.patient_id
  ),
  patient_updates AS (
    UPDATE psy_patients p
       SET outcome_status = 'completed'
      FROM expired_patients ep
     WHERE p.id = ep.pat_id
    RETURNING p.id
  ),
  notif_inserts AS (
    INSERT INTO psy_notifications (user_id, type, title, body, link, is_read)
    SELECT ep.user_id, 'plan',
           'Rawatan Anda Telah Tamat 🎉',
           'Tahniah atas penyelesaian rawatan ' || COALESCE(ep.active_package_name, 'anda') || '. Sila kongsi maklum balas anda.',
           'feedback.html',
           false
      FROM expired_patients ep
      WHERE NOT EXISTS (
        SELECT 1 FROM psy_notifications n
         WHERE n.user_id = ep.user_id
           AND n.type = 'plan'
           AND n.title LIKE 'Rawatan Anda Telah Tamat%'
      )
    RETURNING user_id
  )
  SELECT ep.pat_id, pu.id, 'completed'::TEXT
    FROM expired_patients ep
    LEFT JOIN plan_updates pu ON pu.patient_id = ep.pat_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION fn_complete_expired_treatments() IS
  'Auto-mark treatment plans + patient outcome_status sebagai completed bila pakej tamat. Insert notifikasi feedback. Boleh dipanggil manual atau via pg_cron.';

-- ──────────────────────────────────────────────────────────────
-- Pautan silang domain (jadual dari fail 04/05 yang rujuk pelan;
-- FK hanya boleh dipasang selepas psy_treatment_plans wujud)
-- ──────────────────────────────────────────────────────────────
ALTER TABLE psy_patient_documents DROP CONSTRAINT IF EXISTS psy_patient_documents_plan_id_fkey;
ALTER TABLE psy_patient_documents ADD CONSTRAINT psy_patient_documents_plan_id_fkey
  FOREIGN KEY (plan_id) REFERENCES psy_treatment_plans(id) ON DELETE CASCADE;

ALTER TABLE psy_continuity_offers DROP CONSTRAINT IF EXISTS psy_continuity_offers_plan_id_fkey;
ALTER TABLE psy_continuity_offers ADD CONSTRAINT psy_continuity_offers_plan_id_fkey
  FOREIGN KEY (plan_id) REFERENCES psy_treatment_plans(id) ON DELETE CASCADE;

-- Realtime — kehadiran mingguan auto-tolak ke UI (RLS dihormati)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'psy_plan_weekly_progress'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE psy_plan_weekly_progress;
  END IF;
END $$;
