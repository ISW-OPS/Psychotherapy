-- ═══════════════════════════════════════════════════════════════════
-- GABUNGAN MIGRATION TERTUNGGAK — audit management Sept 2026
-- Digabung 2026-09-25 drpd 7 fail berasingan (senarai di bawah).
-- Semua idempotent (selamat run berulang). Susunan tiada kebergantungan
-- antara satu sama lain (jadual berlainan), tapi dikekalkan ikut tier.
-- ═══════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────────
-- FAIL: 20260923_reaksi_conflict_contraindication.sql
-- ─────────────────────────────────────────────────────────────────
-- Audit management 23 Sept 2026, Tier 1 (#B2-2 conflict-check, #B2-3 contraindication).
-- Rujuk: database/schema/12_reaksi.sql

-- #B2-2 — status 'needs_review' utk saranan yang tergantung sbb >1 reaksi
-- triggered serentak (conflict-check). Cron reaksi-advice-send cuma proses
-- status='draft', jadi 'needs_review' auto tak terhantar sehingga staf Lulus/Skip.
ALTER TABLE psy_reaksi_advice_log DROP CONSTRAINT IF EXISTS psy_reaksi_advice_log_status_check;
ALTER TABLE psy_reaksi_advice_log ADD CONSTRAINT psy_reaksi_advice_log_status_check
  CHECK (status IN ('draft','sent','skipped','needs_review'));

-- #B2-3 — kata kunci contraindication (padan drpd psy_patients.medical_condition)
ALTER TABLE psy_reaksi_actions ADD COLUMN IF NOT EXISTS contraindication_keywords TEXT;

-- #B2-39/#B2-45 — status semakan (Draft/Reviewed/Approved/Active). DEFAULT 'active'
-- supaya rekod sedia ada tak terjejas; kod baharu (import/drawer) set 'draft' eksplisit.
ALTER TABLE psy_reaksi_actions ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'active';
ALTER TABLE psy_reaksi_actions DROP CONSTRAINT IF EXISTS psy_reaksi_actions_status_check;
ALTER TABLE psy_reaksi_actions ADD CONSTRAINT psy_reaksi_actions_status_check
  CHECK (status IN ('draft','reviewed','approved','active'));

-- #B2-2 — notify coach bila baris 'needs_review' dicipta (patient client tak boleh
-- INSERT terus ke psy_notifications, RLS staff-only)
CREATE OR REPLACE FUNCTION trg_reaksi_advice_notify_review()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_coach_id     UUID;
  v_patient_name TEXT;
BEGIN
  IF NEW.status <> 'needs_review' THEN RETURN NEW; END IF;
  IF NOT (NEW.send_after IS NULL OR NEW.send_after <= NEW.created_at + interval '2 minutes') THEN RETURN NEW; END IF;

  SELECT pt.coach_id, COALESCE(pr.full_name, pt.full_name, 'Pesakit')
    INTO v_coach_id, v_patient_name
  FROM psy_patients pt
  LEFT JOIN psy_profiles pr ON pr.id = pt.user_id
  WHERE pt.id = NEW.patient_id;
  IF v_coach_id IS NULL THEN RETURN NEW; END IF;

  INSERT INTO psy_notifications (user_id, type, title, body, link)
  VALUES (
    v_coach_id, 'reaksi',
    '⚠️ Cadangan Perlu Disemak: ' || v_patient_name,
    v_patient_name || ' alami beberapa reaksi serentak — cadangan digenerate TAPI belum dihantar sehingga disemak. Sila semak di reaksi-laporan.html.',
    'reaksi-laporan.html'
  );

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE LOG 'trg_reaksi_advice_notify_review: %', SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_reaksi_advice_notify_review ON psy_reaksi_advice_log;
CREATE TRIGGER trg_reaksi_advice_notify_review
  AFTER INSERT ON psy_reaksi_advice_log
  FOR EACH ROW EXECUTE FUNCTION trg_reaksi_advice_notify_review();


-- ─────────────────────────────────────────────────────────────────
-- FAIL: 20260924_referral_next_action.sql
-- ─────────────────────────────────────────────────────────────────
-- Audit management 23 Sept 2026, Tier 2 (#B2-4): saranan Sesi 1:1 perlu Next Action +
-- PIC + Due Date boleh dijejak sehingga selesai, bukan berhenti sebagai nota bebas.
-- Rujuk: database/schema/20_referrals.sql

ALTER TABLE psy_clinical_referrals ADD COLUMN IF NOT EXISTS next_action TEXT;
ALTER TABLE psy_clinical_referrals ADD COLUMN IF NOT EXISTS next_action_pic UUID REFERENCES psy_profiles(id) ON DELETE SET NULL;
ALTER TABLE psy_clinical_referrals ADD COLUMN IF NOT EXISTS next_action_due DATE;
ALTER TABLE psy_clinical_referrals ADD COLUMN IF NOT EXISTS next_action_done_at TIMESTAMPTZ;


-- ─────────────────────────────────────────────────────────────────
-- FAIL: 20260924_points_manual_adjust_voucher_expiry.sql
-- ─────────────────────────────────────────────────────────────────
-- Audit management 23 Sept 2026, Tier 5 (#C-13) — pelarasan mata manual (staf,
-- sebab wajib, audit trail) + tempoh sah 90 hari utk baucar tukar mata.
-- Rujuk: database/schema/31_points.sql

CREATE OR REPLACE FUNCTION redeem_point_reward(p_reward_id UUID)
RETURNS psy_vouchers
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_patient_id UUID;
  v_reward     psy_point_rewards%ROWTYPE;
  v_balance    INT;
  v_redeemed   INT;
  v_voucher    psy_vouchers%ROWTYPE;
BEGIN
  SELECT id INTO v_patient_id FROM psy_patients WHERE user_id = auth.uid() LIMIT 1;
  IF v_patient_id IS NULL THEN
    RAISE EXCEPTION 'Rekod pesakit tidak dijumpai.';
  END IF;

  SELECT * INTO v_reward FROM psy_point_rewards WHERE id = p_reward_id;
  IF v_reward.id IS NULL OR NOT v_reward.is_active THEN
    RAISE EXCEPTION 'Ganjaran ini tidak sah atau tidak lagi ditawarkan.';
  END IF;

  IF v_reward.max_redemptions_per_patient IS NOT NULL THEN
    SELECT COUNT(*) INTO v_redeemed FROM psy_points_ledger
      WHERE patient_id = v_patient_id AND source_type = 'reward_redeem' AND source_ref = v_reward.id;
    IF v_redeemed >= v_reward.max_redemptions_per_patient THEN
      RAISE EXCEPTION 'Anda telah mencapai had tukaran untuk ganjaran ini.';
    END IF;
  END IF;

  SELECT COALESCE(SUM(points), 0) INTO v_balance FROM psy_points_ledger WHERE patient_id = v_patient_id;
  IF v_balance < v_reward.points_cost THEN
    RAISE EXCEPTION 'Mata tidak mencukupi.';
  END IF;

  INSERT INTO psy_points_ledger (patient_id, source_type, source_ref, points, note)
  VALUES (v_patient_id, 'reward_redeem', v_reward.id, -v_reward.points_cost, 'Tukar: ' || v_reward.name);

  INSERT INTO psy_vouchers (patient_id, source_type, source_ref, amount, note, expires_at)
  VALUES (v_patient_id, 'point_redeem', v_reward.id, v_reward.voucher_amount, 'Ditukar dari mata: ' || v_reward.name, now() + interval '90 days')
  RETURNING * INTO v_voucher;

  RETURN v_voucher;
END;
$$;

GRANT EXECUTE ON FUNCTION redeem_point_reward(UUID) TO authenticated;

CREATE OR REPLACE FUNCTION adjust_points_manual(p_patient_id UUID, p_points INT, p_reason TEXT)
RETURNS psy_points_ledger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_is_staff BOOLEAN;
  v_row      psy_points_ledger%ROWTYPE;
BEGIN
  SELECT EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff') INTO v_is_staff;
  IF NOT v_is_staff THEN
    RAISE EXCEPTION 'Hanya staf boleh laras mata pesakit.';
  END IF;
  IF p_points = 0 THEN
    RAISE EXCEPTION 'Bilangan mata mesti bukan sifar.';
  END IF;
  IF p_reason IS NULL OR btrim(p_reason) = '' THEN
    RAISE EXCEPTION 'Sebab pelarasan diperlukan.';
  END IF;

  INSERT INTO psy_points_ledger (patient_id, source_type, points, note)
  VALUES (p_patient_id, 'manual_adjustment', p_points, btrim(p_reason))
  RETURNING * INTO v_row;

  RETURN v_row;
END;
$$;

GRANT EXECUTE ON FUNCTION adjust_points_manual(UUID, INT, TEXT) TO authenticated;


-- ─────────────────────────────────────────────────────────────────
-- FAIL: 20260924_promo_scope_stack_eligibility.sql
-- ─────────────────────────────────────────────────────────────────
-- Audit management 23 Sept 2026, Tier 5 (#D-15, #D-16, #D-17) — skop
-- "Terpakai Untuk" (Produk/Kategori/Pakej), gabung baucar (stackable),
-- eligibility pelanggan baharu, label kempen.
-- Rujuk: database/schema/29_promo_codes.sql

ALTER TABLE psy_promo_codes ADD COLUMN IF NOT EXISTS applies_to TEXT NOT NULL DEFAULT 'all'
  CHECK (applies_to IN ('all','product','category','package'));
ALTER TABLE psy_promo_codes ADD COLUMN IF NOT EXISTS applies_to_values TEXT[];
ALTER TABLE psy_promo_codes ADD COLUMN IF NOT EXISTS stackable BOOLEAN NOT NULL DEFAULT true;
ALTER TABLE psy_promo_codes ADD COLUMN IF NOT EXISTS new_customer_only BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE psy_promo_codes ADD COLUMN IF NOT EXISTS campaign TEXT;


-- ─────────────────────────────────────────────────────────────────
-- FAIL: 20260924_announcement_reads.sql
-- ─────────────────────────────────────────────────────────────────
-- Audit management 23 Sept 2026, Tier 5 (#G-33, #G-34) — penjejakan "dibaca"
-- pengumuman (impression-based, bila muncul di dashboard/senarai pesakit).
-- Rujuk: database/schema/19_events_announcements.sql

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


-- ─────────────────────────────────────────────────────────────────
-- FAIL: 20260924_event_meet_link_capacity.sql
-- ─────────────────────────────────────────────────────────────────
-- Audit management 23 Sept 2026, Tier 5 (#H-35, #H-36) — kuatkuasa kapasiti
-- pendaftaran acara + keluarkan meet_link dari psy_events (RLS row-level tak
-- boleh sembunyi satu lajur sahaja — jadual berasingan supaya pesakit yang
-- BELUM daftar betul-betul tak dapat baca pautan Meet, bukan sekadar disorok
-- di UI). Rujuk: database/schema/19_events_announcements.sql

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

-- Backfill dari lajur lama SEBELUM dibuang
INSERT INTO psy_event_meet_links (event_id, meet_link)
SELECT id, meet_link FROM psy_events WHERE meet_link IS NOT NULL
ON CONFLICT (event_id) DO UPDATE SET meet_link = EXCLUDED.meet_link;

ALTER TABLE psy_events DROP COLUMN IF EXISTS meet_link;

-- #H-35 — kuatkuasa kapasiti pendaftaran acara (server-side, staf override dibenarkan)
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


-- ─────────────────────────────────────────────────────────────────
-- FAIL: 20260924_split_invoice_receipt_payment.sql
-- ─────────────────────────────────────────────────────────────────
-- Audit management 23 Sept 2026 (#F-23, Tier 3→5 — sengaja ditangguh di Tier 3,
-- kini dibuat) — Pisah Invoice/Receipt/Payment jadi 3 jadual berasingan.
-- Rujuk: database/schema/06_payments.sql (sumber kebenaran, dah dikemaskini).
--
-- PENDEKATAN: tambahan sahaja (additive) — psy_payments KEKAL bentuk sedia ada,
-- SEMUA laluan tulis sedia ada (webhook gateway, autocharge ansuran, GHL sync,
-- entri manual staf KOB/kedai) TAK disentuh langsung. Cuma denda tidak hadir
-- (plan-week.html) dipindah guna psy_invoices sebenar (kod app dikemaskini
-- berasingan, bukan dalam migration ni).

-- ──── 1. Betulkan trigger invoice_no sedia ada (elak nombor berganda) ────
ALTER TABLE psy_payments ADD COLUMN IF NOT EXISTS invoice_id UUID;

CREATE OR REPLACE FUNCTION psy_assign_payment_invoice_no() RETURNS trigger AS $$
BEGIN
  IF NEW.invoice_no IS NULL AND NEW.status IN ('pending','completed')
     AND (NEW.intent ->> 'kob_session_id') IS NULL
     AND NEW.invoice_id IS NULL THEN
    NEW.invoice_no := 'INV-' || lpad(nextval('psy_invoice_no_seq')::text, 6, '0');
  END IF;
  RETURN NEW;
END $$ LANGUAGE plpgsql;

-- ──── 2. psy_receipts — trigger-created sahaja, tiada laluan client INSERT ────
CREATE TABLE IF NOT EXISTS psy_receipts (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  payment_id UUID NOT NULL UNIQUE REFERENCES psy_payments(id) ON DELETE CASCADE,
  patient_id UUID REFERENCES psy_patients(id),
  receipt_no TEXT,
  total      NUMERIC(10,2) NOT NULL,
  issued_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  pdf_url    TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_psy_receipts_patient ON psy_receipts(patient_id);

ALTER TABLE psy_receipts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Patients read own receipts" ON psy_receipts;
CREATE POLICY "Patients read own receipts" ON psy_receipts FOR SELECT
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Staff read all receipts" ON psy_receipts;
CREATE POLICY "Staff read all receipts" ON psy_receipts FOR SELECT
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

CREATE OR REPLACE FUNCTION trg_create_receipt_on_payment_completed()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NEW.status = 'completed' AND (TG_OP = 'INSERT' OR OLD.status IS DISTINCT FROM 'completed') THEN
    INSERT INTO psy_receipts (payment_id, patient_id, receipt_no, total, pdf_url)
    VALUES (NEW.id, NEW.patient_id, NEW.receipt_no, NEW.total, NEW.receipt_url)
    ON CONFLICT (payment_id) DO NOTHING;
  END IF;
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE LOG 'trg_create_receipt_on_payment_completed: %', SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_create_receipt_on_payment_completed ON psy_payments;
CREATE TRIGGER trg_create_receipt_on_payment_completed
  AFTER INSERT OR UPDATE OF status ON psy_payments
  FOR EACH ROW EXECUTE FUNCTION trg_create_receipt_on_payment_completed();

-- Backfill sejarah — semua bayaran 'completed' sedia ada dapat rekod resit serta-merta.
INSERT INTO psy_receipts (payment_id, patient_id, receipt_no, total, pdf_url, issued_at)
SELECT id, patient_id, receipt_no, total, receipt_url, COALESCE(paid_at, created_at)
FROM psy_payments WHERE status = 'completed'
ON CONFLICT (payment_id) DO NOTHING;

-- ──── 3. psy_invoices — amaun tertunggak, boleh wujud sebelum sebarang bayaran ────
CREATE TABLE IF NOT EXISTS psy_invoices (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  invoice_no  TEXT UNIQUE,
  patient_id  UUID NOT NULL REFERENCES psy_patients(id),
  description TEXT NOT NULL,
  amount      NUMERIC(10,2) NOT NULL CHECK (amount > 0),
  status      TEXT NOT NULL DEFAULT 'unpaid' CHECK (status IN ('unpaid','partially_paid','paid','void')),
  source_type TEXT,
  source_ref  TEXT,
  created_by  UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  created_at  TIMESTAMPTZ DEFAULT now(),
  updated_at  TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_psy_invoices_patient ON psy_invoices(patient_id, status);

ALTER TABLE psy_invoices ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Patients read own invoices" ON psy_invoices;
CREATE POLICY "Patients read own invoices" ON psy_invoices FOR SELECT
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Staff manage invoices" ON psy_invoices;
CREATE POLICY "Staff manage invoices" ON psy_invoices FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

CREATE OR REPLACE FUNCTION psy_assign_invoice_no() RETURNS trigger AS $$
BEGIN
  IF NEW.invoice_no IS NULL THEN
    NEW.invoice_no := 'INV-' || lpad(nextval('psy_invoice_no_seq')::text, 6, '0');
  END IF;
  RETURN NEW;
END $$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_psy_assign_invoice_no ON psy_invoices;
CREATE TRIGGER trg_psy_assign_invoice_no BEFORE INSERT ON psy_invoices
  FOR EACH ROW EXECUTE FUNCTION psy_assign_invoice_no();

ALTER TABLE psy_payments DROP CONSTRAINT IF EXISTS psy_payments_invoice_id_fkey;
ALTER TABLE psy_payments ADD CONSTRAINT psy_payments_invoice_id_fkey
  FOREIGN KEY (invoice_id) REFERENCES psy_invoices(id);
CREATE INDEX IF NOT EXISTS idx_psy_payments_invoice ON psy_payments(invoice_id);

CREATE OR REPLACE FUNCTION trg_update_invoice_status_on_payment()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_amount NUMERIC;
  v_paid   NUMERIC;
BEGIN
  IF NEW.invoice_id IS NULL THEN RETURN NEW; END IF;
  SELECT amount INTO v_amount FROM psy_invoices WHERE id = NEW.invoice_id;
  IF v_amount IS NULL THEN RETURN NEW; END IF;
  SELECT COALESCE(SUM(total), 0) INTO v_paid FROM psy_payments
    WHERE invoice_id = NEW.invoice_id AND status = 'completed';
  UPDATE psy_invoices SET
    status = CASE
      WHEN v_paid <= 0 THEN 'unpaid'
      WHEN v_paid + 0.005 >= v_amount THEN 'paid'
      ELSE 'partially_paid'
    END,
    updated_at = now()
  WHERE id = NEW.invoice_id AND status <> 'void';
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE LOG 'trg_update_invoice_status_on_payment: %', SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_update_invoice_status_on_payment ON psy_payments;
CREATE TRIGGER trg_update_invoice_status_on_payment
  AFTER INSERT OR UPDATE OF status ON psy_payments
  FOR EACH ROW EXECUTE FUNCTION trg_update_invoice_status_on_payment();


-- ─────────────────────────────────────────────────────────────────
-- FAIL: 20260925_patients_created_by.sql
-- ─────────────────────────────────────────────────────────────────
-- Jejak SIAPA cipta rekod pesakit manual dalam PT System (roles/staff/patients.html
-- "+ Tambah Pesakit / Tempah KOB") — sebelum ni cuma `created_by_staff` (boolean,
-- true/false je). Punca rekod pendua Sept 2026: staf create manual SEBELUM cron
-- ghl-pull-sync sempat proses contact GHL yang sama, dua patient_id berasingan
-- tercipta. `created_by`/`created_by_name` bantu kenal pasti punca (rekod mana
-- dicipta staf manual vs auto-sync GHL, referral_source dah bezakan tu — lajur
-- ni tambah SIAPA secara khusus).

ALTER TABLE psy_patients ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES psy_profiles(id) ON DELETE SET NULL;
ALTER TABLE psy_patients ADD COLUMN IF NOT EXISTS created_by_name TEXT;


-- ─────────────────────────────────────────────────────────────────
-- FAIL: 20260925_ghl_kob_code.sql
-- ─────────────────────────────────────────────────────────────────
-- GHL Workflow "SU KOB Auto ID" prepend kod (cth "KOB'26-000139") depan
-- nama contact ("KOB'26-000139. Pn Syamira"). ghl-booking-webhook kini
-- auto-asingkan kod tu drpd full_name, simpan berasingan di sini — BUKAN
-- reference_code ("Kod Pesakit", diisi lepas pesakit signup pakej OB,
-- tujuan lain). Rujuk: database/schema/04_patients.sql,
-- supabase/functions/_shared/ghl-sync.ts (splitGhlNameCode).

ALTER TABLE psy_patients ADD COLUMN IF NOT EXISTS ghl_kob_code TEXT;


-- ─────────────────────────────────────────────────────────────────
-- FAIL: 20260925_registrant_capacity.sql
-- ─────────────────────────────────────────────────────────────────
-- GHL borang tanya 2 soalan berasingan pasal pendaftar: "Peranan
-- Pendaftar" (Pesakit/Waris Bertanggungjawab/Waris Wakil/Waris — map ke
-- contact_preference sedia ada) DAN "Anda mengisi borang ini sebagai?"
-- (sejauh mana terlibat — sendiri/urus penuh/bantu isi sahaja, medan
-- BAHARU registrant_capacity, TIADA di sistem lagi). Rujuk:
-- database/schema/04_patients.sql, supabase/functions/ghl-booking-webhook.

ALTER TABLE psy_patients ADD COLUMN IF NOT EXISTS registrant_capacity TEXT;


-- ─────────────────────────────────────────────────────────────────
-- FAIL: 20260925_ghl_contact_id.sql
-- ─────────────────────────────────────────────────────────────────
-- Simpan ID dalaman contact GHL ({{contact.id}}) sebagai rujukan pantas/
-- debug & future API call terus ke GHL. TIDAK dipakai untuk padanan
-- pesakit (kekal ikut telefon). Rujuk: database/schema/04_patients.sql,
-- supabase/functions/ghl-booking-webhook.

ALTER TABLE psy_patients ADD COLUMN IF NOT EXISTS ghl_contact_id TEXT;


