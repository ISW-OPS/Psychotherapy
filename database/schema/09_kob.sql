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
  -- kiv = sesi selesai TAPI pesakit tak teruskan pakej (parking, bukan cancel).
  -- no_show = staff sahkan pesakit tak hadir (BEZA drpd "Terlepas" — tu label
  -- terbitan sementara ikut masa lepas, no_show status TETAP yg staff set sendiri).
  status              TEXT NOT NULL DEFAULT 'booked'
                      CHECK (status IN ('booked','hadir','completed','reschedule','cancelled','kiv','no_show')),
  -- Asal tempahan: 'system' = dicipta dalam ISW system (staff/pesakit sendiri),
  -- 'ghl' = disync automatik dari GHL Calendar (lihat _shared/ghl-sync.ts).
  source              TEXT NOT NULL DEFAULT 'system' CHECK (source IN ('system','ghl')),

  -- LEGACY — peranan "Doktor" dibuang (gantikan Collector/Closer di bawah). Lajur ni
  -- kekal utk baca rekod lama sahaja, TAK DIISI LAGI utk rekod baharu.
  doctor_hadir_id     UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  doctor_hadir_name   TEXT,
  hadir_at            TIMESTAMPTZ,
  doctor_selesai_id   UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  doctor_selesai_name TEXT,
  selesai_at          TIMESTAMPTZ,

  -- Collector — staff "owner" pesakit sepanjang proses KOB. Ditugaskan/ditukar bila-bila
  -- (macam coach_id pesakit), TIDAK auto-terikat dgn butang Hadir/Selesai. Assign/tukar di
  -- kob-detail.html (openChangeKobRole). Staff yg layak dipilih = staff_role 'kob'.
  collector_id        UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  collector_name      TEXT,
  -- Closer — staff yang handle sesi presentation KOB. Berasingan drpd Collector, ditugaskan/
  -- ditukar bila-bila sama cara. Staff yg layak dipilih = staff_role 'kob'.
  closer_id           UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  closer_name         TEXT,

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
  package_discount          NUMERIC(12,2) NOT NULL DEFAULT 0,  -- diskaun (papar di invois; harga asal = recommended_package_price + package_discount)
  invoice_no                TEXT UNIQUE,                       -- no. invois (INV-000001..) — auto bila pakej dicadangkan
  package_payment_mode      TEXT CHECK (package_payment_mode IN ('full','installment')),
  intended_payment_mode     TEXT CHECK (intended_payment_mode IN ('full','installment','manual_installment')),

  -- Kunci Harga — staff klik "Kunci Harga" di Langkah 3 (kob-detail.html) utk tetapkan
  -- harga Now/Today bayaran ini TAK boleh berubah lagi (walaupun harga pakej diedit
  -- kemudian di pakej-edit.html). locked_price_amount snapshot harga sebenar masa
  -- dikunci (bukan dikira semula dari pkgMeta tiap kali). NULL = belum dikunci.
  locked_price_tier         TEXT CHECK (locked_price_tier IN ('now','today')),
  locked_price_amount       NUMERIC(12,2),
  locked_at                 TIMESTAMPTZ,
  locked_by                 UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  locked_by_name            TEXT,

  -- "OB Lock Harga" (reservation) — pesakit bayar OB Lock Harga hari ni utk "freeze"
  -- harga semasa SEBELUM pakej rasmi mula (beza drpd Ansuran Manual di Langkah 4,
  -- yang untuk pesakit yg DAH mula pakej). Tiada tarikh/jadual bayaran seterusnya
  -- di sini — cuma satu OB Lock Harga + tempoh lock. TAKDE REFUND kalau tempoh luput
  -- tanpa bayaran penuh (lock_status 'forfeited').
  lock_deposit_amount          NUMERIC(12,2),
  -- Rujuk terus psy_payments.id rekod OB Lock Harga ni — elak ambiguiti bila lock
  -- diluputkan+dikunci semula (byk baris 'kob_price_lock_deposit' sepanjang masa),
  -- supaya saveManualPayment() tahu TEPAT baris mana nak reclassify ke 'kob_package'
  -- bila pesakit akhirnya mula pakej.
  lock_deposit_payment_id      UUID REFERENCES psy_payments(id) ON DELETE SET NULL,
  lock_deposit_paid_at         TIMESTAMPTZ,
  -- 'gateway' = dibayar via pautan HitPay (payments-kob-initiate mode='price_lock'),
  -- rekod oleh webhook (fulfillKobPriceLock), bukan staff terus.
  lock_deposit_method          TEXT CHECK (lock_deposit_method IN ('cash','transfer','gateway')),
  lock_deposit_reference       TEXT,
  lock_deposit_recorded_by     UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  lock_deposit_recorded_by_name TEXT,
  lock_expiry_date             DATE,
  -- active = dalam tempoh; tempoh_tamat = tarikh dah sampai, menunggu staff lanjutkan/
  -- luputkan; forfeited = staff dah luputkan (OB Lock Harga burn, harga dibuka balik);
  -- completed = pesakit dah bayar penuh/mula ansuran dalam tempoh (OB Lock Harga
  -- dikreditkan ke harga pakej).
  lock_status                   TEXT CHECK (lock_status IN ('active','tempoh_tamat','forfeited','completed')),
  lock_extended_count           INT NOT NULL DEFAULT 0,
  lock_forfeited_at             TIMESTAMPTZ,
  lock_forfeited_by             UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  lock_forfeited_by_name        TEXT,

  reschedule_count    INT NOT NULL DEFAULT 0,
  reschedule_reason   TEXT,

  created_at          TIMESTAMPTZ DEFAULT now(),
  updated_at          TIMESTAMPTZ DEFAULT now()
);

COMMENT ON COLUMN psy_kob_sessions.questionnaire IS
  'Structured Q&A captured during KOB. Keys: anak[], tidur{}, gaya_hidup{}, masalah_kesihatan{} — see kob-detail.html for shape.';

COMMENT ON COLUMN psy_kob_sessions.recommended_package_id IS
  'Package recommended by doctor during KOB. Patient must pay before agreement signing.';

COMMENT ON COLUMN psy_kob_sessions.locked_price_tier IS
  'Staff-locked price tier (now/today) for this KOB payment, set via "Kunci Harga" button in
   kob-detail.html Langkah 3. When set, overrides wizPayTier in UI + payments-kob-initiate tier
   param, and keeps working even if the package price changes afterwards (snapshot in
   locked_price_amount). NULL = not locked, staff can still freely switch tiers.';

COMMENT ON COLUMN psy_kob_sessions.lock_deposit_amount IS
  '"OB Lock Harga" — reservation amount paid to lock the price (separate from the Langkah 4
   payment plan — no schedule/dates attached, just one upfront amount). Credited toward the
   package price ONLY while lock_status is still active/tempoh_tamat (not forfeited) when the
   real payment is finally recorded. NEVER refunded if the lock lapses (lock_status = forfeited).';

COMMENT ON COLUMN psy_kob_sessions.lock_status IS
  'active = within lock_expiry_date. tempoh_tamat = date reached, awaiting staff action
   (wizExtendLock to push the date out, or wizForfeitLock to burn the OB Lock Harga + release
   the locked price). forfeited = terminal, OB Lock Harga kept (no refund), locked_price_*
   cleared. completed = terminal, real package payment recorded while lock was still valid
   (OB Lock Harga credited toward the price — see getKobLockDepositCredit() in kob-detail.html).';

COMMENT ON COLUMN psy_kob_sessions.intended_payment_mode IS
  'Plan staff PILIH utk pesakit di wizard kob-detail.html (wizSelectPlan, Langkah 4) — SEBELUM
   sebarang bayaran cuba dibuat. Beza dengan package_payment_mode (hanya diisi SELEPAS bayaran
   berjaya). Dibaca oleh kob.html (roles/patient) utk papar butang self-checkout yang sepadan:
   installment = "Bayar Deposit Ansuran" (payments-kob-initiate, deposit amount), full/NULL =
   "Bayar Sekarang" (payments-initiate, harga penuh), manual_installment = kekal WhatsApp sahaja
   (jadual staff-entered, tiada formula deposit utk self-checkout).';

CREATE SEQUENCE IF NOT EXISTS psy_invoice_no_seq START 1;

CREATE OR REPLACE FUNCTION psy_assign_invoice_no() RETURNS trigger AS $$
BEGIN
  IF NEW.recommended_package_id IS NOT NULL AND NEW.invoice_no IS NULL THEN
    NEW.invoice_no := 'INV-' || lpad(nextval('psy_invoice_no_seq')::text, 6, '0');
  END IF;
  RETURN NEW;
END $$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_psy_assign_invoice_no ON psy_kob_sessions;
CREATE TRIGGER trg_psy_assign_invoice_no BEFORE INSERT OR UPDATE OF recommended_package_id ON psy_kob_sessions
  FOR EACH ROW EXECUTE FUNCTION psy_assign_invoice_no();

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

-- ──── psy_kob_installment_checkpoints ────
-- Checkpoint kumulatif pakej ansuran (Pelan Pelaburan Ansuran) bila
-- package_payment_mode = 'installment'. Dijana sekali dari template
-- psy_packages.installment_checkpoints semasa deposit disahkan (due_date
-- = tarikh deposit + month_offset bulan). Pesakit bayar apa-apa amount
-- bila-bila (rekod psy_payments biasa, tiada padanan 1:1) — checkpoint
-- disemak dgn banding JUMLAH TERKUMPUL psy_payments vs target_cumulative.
CREATE TABLE IF NOT EXISTS psy_kob_installment_checkpoints (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  kob_session_id    UUID NOT NULL REFERENCES psy_kob_sessions(id) ON DELETE CASCADE,
  patient_id        UUID NOT NULL REFERENCES psy_patients(id) ON DELETE CASCADE,
  seq               INT NOT NULL,
  month_offset      INT NOT NULL,
  due_date          DATE NOT NULL,
  target_cumulative NUMERIC(10,2) NOT NULL,
  status            TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','met','overdue')),
  met_at            TIMESTAMPTZ,
  created_at        TIMESTAMPTZ DEFAULT now(),
  CONSTRAINT psy_kob_installment_checkpoints_unique_seq UNIQUE (kob_session_id, seq)
);

-- Dedup peringatan auto "N hari sebelum due date" (runInstallmentReminderCheck,
-- event-reminders) — elak hantar berulang; lihat psy_auto_messages key='installment_reminder'.
ALTER TABLE psy_kob_installment_checkpoints
  ADD COLUMN IF NOT EXISTS installment_reminder_sent_at TIMESTAMPTZ;

-- Auto-Caj (kad tersimpan HitPay) — runInstallmentAutoChargeCheck (event-reminders)
-- cuba caj checkpoint ON due_date guna psy_kob_card_authorizations.gateway_auth_ref
-- SEBELUM jatuh balik ke pautan manual/overdue. autocharge_attempts dihadkan (3x,
-- 1x/hari) — lepas tu serah balik ke aliran manual sedia ada (installment_overdue).
ALTER TABLE psy_kob_installment_checkpoints
  ADD COLUMN IF NOT EXISTS autocharge_status TEXT NOT NULL DEFAULT 'not_attempted'
    CHECK (autocharge_status IN ('not_attempted','succeeded','failed')),
  ADD COLUMN IF NOT EXISTS autocharge_last_attempt_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS autocharge_attempts INT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS autocharge_payment_id UUID REFERENCES psy_payments(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_kob_checkpoints_session ON psy_kob_installment_checkpoints(kob_session_id);
CREATE INDEX IF NOT EXISTS idx_kob_checkpoints_patient ON psy_kob_installment_checkpoints(patient_id, status);
CREATE INDEX IF NOT EXISTS idx_kob_checkpoints_overdue ON psy_kob_installment_checkpoints(due_date) WHERE status = 'pending';

ALTER TABLE psy_kob_installment_checkpoints ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Patient read own checkpoints" ON psy_kob_installment_checkpoints;
CREATE POLICY "Patient read own checkpoints" ON psy_kob_installment_checkpoints FOR SELECT
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Staff manage checkpoints" ON psy_kob_installment_checkpoints;
CREATE POLICY "Staff manage checkpoints" ON psy_kob_installment_checkpoints FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

COMMENT ON COLUMN psy_kob_installment_checkpoints.seq IS
  '0 = checkpoint deposit (dibayar semasa sesi KOB, terus met). 1,2,3... = checkpoint seterusnya ikut turutan month_offset.';
COMMENT ON COLUMN psy_kob_installment_checkpoints.target_cumulative IS
  'Jumlah TERKUMPUL (bukan tambahan) yang wajib dicecah menjelang due_date. Checkpoint terakhir = harga penuh pakej (baki).';
COMMENT ON COLUMN psy_kob_installment_checkpoints.status IS
  'met = jumlah terkumpul psy_payments dah cecah target (disemak automatik tiap kali bayaran baru direkod). overdue ditetapkan oleh installment-overdue-check (cron harian) bila due_date lepas & belum met.';

-- ──── psy_kob_card_authorizations ────
-- Kad tersimpan HitPay (recurring-billing, save_payment_method=true) SATU
-- rekod per sesi KOB ansuran — bukan per checkpoint. Pesakit lampir kad
-- SEKALI (hosted page, dijana createKobCardAttachLink), kemudian tiap
-- checkpoint dicaj ON-DEMAND guna gateway_auth_ref (jumlah BERBEZA setiap
-- kali, ikut target_cumulative checkpoint semasa — bukan cycle/subscription
-- tetap HitPay). status='attached' ditetapkan oleh webhook JSON berasingan
-- (payments-webhook-recurring, event method_attached) — BEZA drpd webhook
-- form-encoded payments-webhook biasa (payment-requests).
CREATE TABLE IF NOT EXISTS psy_kob_card_authorizations (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  kob_session_id    UUID NOT NULL REFERENCES psy_kob_sessions(id) ON DELETE CASCADE,
  patient_id        UUID NOT NULL REFERENCES psy_patients(id) ON DELETE CASCADE,
  gateway_provider  TEXT NOT NULL DEFAULT 'hitpay',
  gateway_auth_ref  TEXT NOT NULL,   -- id 'recurring-billing' HitPay
  status            TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','attached','detached','failed')),
  card_last4        TEXT,
  card_brand        TEXT,
  attached_at       TIMESTAMPTZ,
  detached_at       TIMESTAMPTZ,
  created_at        TIMESTAMPTZ DEFAULT now(),
  CONSTRAINT psy_kob_card_authorizations_unique_session UNIQUE (kob_session_id)
);

CREATE INDEX IF NOT EXISTS idx_kob_card_auth_patient ON psy_kob_card_authorizations(patient_id);

ALTER TABLE psy_kob_card_authorizations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Patient read own card auth" ON psy_kob_card_authorizations;
CREATE POLICY "Patient read own card auth" ON psy_kob_card_authorizations FOR SELECT
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Staff manage card auth" ON psy_kob_card_authorizations;
CREATE POLICY "Staff manage card auth" ON psy_kob_card_authorizations FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- ──── trigger: auto-detach kad auto-caj bila pesakit stop/tamat rawatan ────
-- Audit Tier 9 #47 dah elak cron auto-caj pesakit stop (defensive skip, lihat
-- supabase/functions/event-reminders/index.ts), TAPI itu cuma semakan setiap
-- kali cron jalan — rekod kad sendiri (status='attached') tak pernah ditukar
-- secara automatik, kekal 'attached' sampai staff tekan "⏸️ Henti Auto-Caj"
-- manual (roles/staff/patient-hub.html stopAutoChargePH()). Trigger ni padankan
-- tindakan sama secara automatik bila outcome_status pesakit bertukar ke
-- 'berhenti'/'meninggal' — supaya rekod kad sentiasa tepat walau staf terlupa.
CREATE OR REPLACE FUNCTION auto_detach_card_on_patient_stop()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_row RECORD;
BEGIN
  IF NEW.outcome_status IN ('berhenti', 'meninggal')
     AND OLD.outcome_status IS DISTINCT FROM NEW.outcome_status THEN
    FOR v_row IN
      UPDATE psy_kob_card_authorizations
        SET status = 'detached', detached_at = now()
        WHERE patient_id = NEW.id AND status = 'attached'
        RETURNING id
    LOOP
      INSERT INTO psy_audit_log (actor_name, action, target, meta)
      VALUES ('Sistem (Auto)', 'kob.autocharge_stopped', v_row.id::text,
        jsonb_build_object('reason', 'patient_treatment_stopped', 'patient_id', NEW.id, 'outcome_status', NEW.outcome_status));
    END LOOP;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_auto_detach_card_on_patient_stop ON psy_patients;
CREATE TRIGGER trg_auto_detach_card_on_patient_stop
  AFTER UPDATE OF outcome_status ON psy_patients
  FOR EACH ROW
  EXECUTE FUNCTION auto_detach_card_on_patient_stop();

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

-- ──── psy_kob_agreements — Nama/IC tulisan tangan (LEGACY) + Waris/Penjamin ────
-- *_image_url di bawah adalah bukti tulisan-tangan LEGACY — sejak nama/IC ditukar
-- ke medan TAIP (bukan lukisan tangan), lajur ni TAK DIISI LAGI utk rekod baharu,
-- kekal hanya utk baca rekod lama. Waris/Penjamin (nama+IC+tandatangan) wajib
-- diisi di UI (validasi client-side), tapi nullable di DB supaya rekod lama tak terjejas.
ALTER TABLE psy_kob_agreements ADD COLUMN IF NOT EXISTS patient_name_image_url TEXT;
ALTER TABLE psy_kob_agreements ADD COLUMN IF NOT EXISTS patient_ic_image_url TEXT;
ALTER TABLE psy_kob_agreements ADD COLUMN IF NOT EXISTS guardian_name_image_url TEXT;
ALTER TABLE psy_kob_agreements ADD COLUMN IF NOT EXISTS guardian_ic_image_url TEXT;
ALTER TABLE psy_kob_agreements ADD COLUMN IF NOT EXISTS guardian_signature_url TEXT;
-- Nama/IC Waris/Penjamin kini medan TAIP (dulu cuma wujud sbg imej tulisan tangan
-- di atas, tiada lajur teks) — perlukan lajur teks baharu, sama konsep dgn
-- patient_name/patient_ic sedia ada.
ALTER TABLE psy_kob_agreements ADD COLUMN IF NOT EXISTS guardian_name TEXT;
ALTER TABLE psy_kob_agreements ADD COLUMN IF NOT EXISTS guardian_ic TEXT;

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

DROP POLICY IF EXISTS "Staff delete agreement" ON psy_kob_agreements;
CREATE POLICY "Staff delete agreement" ON psy_kob_agreements FOR DELETE
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- ──── psy_kob_slot_config ────
-- Templat slot tetap untuk KOB & Rawatan (Rabu-Ahad). Admin boleh on/off
-- setiap slot; tiada kapasiti per-pesakit.
CREATE TABLE IF NOT EXISTS psy_kob_slot_config (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  -- 'sesi_1on1' = Sesi 1:1 (Hakeema/Hakeem/Dr), diurus kad "C. Slot Sesi 1:1" kob-slots.html —
  -- guna baris-per-blok SAMA seperti KOB/Rawatan, reuse penuh (bukan jadual/model berasingan).
  slot_type    TEXT NOT NULL DEFAULT 'kob' CHECK (slot_type IN ('kob','rawatan','sesi_1on1')),
  day_of_week  INT NOT NULL CHECK (day_of_week IN (0, 3, 4, 5, 6)),  -- 0=Ahad, 3=Rabu, 4=Khamis, 5=Jumaat, 6=Sabtu
  slot_start   TIME NOT NULL,
  slot_end     TIME NOT NULL,
  is_active    BOOLEAN NOT NULL DEFAULT true,
  label        TEXT NOT NULL,         -- paparan cth "7-9 pg"
  sort_order   INT NOT NULL DEFAULT 0,
  note         TEXT,                  -- nota peringatan untuk slot
  max_bookings INT,                   -- audit #B2-47 (Tier 4): kapasiti maksimum blok ni (rawatan & sesi_1on1); NULL = tiada had/belum dikonfigur
  -- Jadual Slot Sesi 1:1 redesign (7 Okt 2026) — tempoh seorang pesakit dlm blok ni (minit).
  -- Dipakai sesi_1on1 sahaja utk auto-jana slot diskret (09:00,09:30,...) dari slot_start+max_bookings
  -- — SETIAP slot = SATU janji temu individu (bukan 1 blok = 1 kaunter kapasiti). NULL = kekal mod
  -- lama (blok utuh, tiada slot diskret) — kob/rawatan tak guna medan ni.
  slot_duration_minutes INT,
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

-- Seed lalai Slot Sesi 1:1 (Hakeema/Hakeem/Dr) — 2 blok (pagi/petang) x hari Rabu-Ahad,
-- sama pattern macam KOB/Rawatan di atas (baris-per-blok, ON/OFF per hari di UI).
INSERT INTO psy_kob_slot_config (slot_type, day_of_week, slot_start, slot_end, label, sort_order, is_active)
SELECT
  'sesi_1on1',
  d.day_of_week,
  s.slot_start::time,
  s.slot_end::time,
  s.label,
  s.sort_order,
  true
FROM
  (VALUES (3), (4), (5), (6), (0)) AS d(day_of_week),
  (VALUES
    ('09:00', '12:00', '9-12 pg',  1),
    ('14:00', '17:00', '2-5 ptg',  2)
  ) AS s(slot_start, slot_end, label, sort_order)
ON CONFLICT ON CONSTRAINT psy_kob_slot_config_unique DO NOTHING;
