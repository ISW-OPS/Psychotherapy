-- ═══════════════════════════════════════════════════════════════════
-- SKEMA: PEMBAYARAN & PESANAN
-- Jadual: psy_payments, psy_orders
-- Gateway bayaran provider-agnostic (HitPay/Fiuu) via kolum gateway_*.
-- ═══════════════════════════════════════════════════════════════════

-- ──────────────────────────────────────────────────────────────
-- psy_payments — rekod bayaran (manual + gateway)
-- ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS psy_payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  receipt_ref TEXT UNIQUE NOT NULL,
  patient_id UUID REFERENCES psy_patients(id),
  user_id UUID REFERENCES psy_profiles(id) ON DELETE CASCADE,
  items JSONB DEFAULT '[]',
  subtotal NUMERIC(10,2) DEFAULT 0,
  service_charge NUMERIC(10,2) DEFAULT 0,
  sst NUMERIC(10,2) DEFAULT 0,
  total NUMERIC(10,2) NOT NULL,
  payment_method TEXT CHECK (payment_method IN ('fpx','card','transfer','ghl','manual','gateway')),
  -- 'voided' ditambah 24 Sept 2026 (audit management #B1-24) — transaksi yg tersalah
  -- rekod terus (bukan pesakit betul-betul minta wang balik). Beza drpd 'refunded'
  -- (bayaran sah, wang dipulangkan). Lihat psy_payment_adjustments utk sebab/approver.
  status TEXT DEFAULT 'completed' CHECK (status IN ('pending','completed','refunded','failed','voided')),
  -- Ditambah 24 Sept 2026 (audit management #B1-23) — bayaran ujian/demo, DIKECUALIKAN
  -- drpd semua laporan kewangan sebenar (KPI dashboard, laporan bulanan dll).
  is_test BOOLEAN NOT NULL DEFAULT false,
  -- Ditambah 24 Sept 2026 (audit management #B1-27) — status penghantaran resit/invois
  -- (WhatsApp) supaya staf tahu ia dihantar atau gagal, bukan senyap "fire and forget".
  receipt_last_sent_at     TIMESTAMPTZ,
  receipt_last_sent_status TEXT CHECK (receipt_last_sent_status IS NULL OR receipt_last_sent_status IN ('sent','failed')),
  ghl_transaction_id TEXT,
  invoice_number TEXT,                        -- bayaran manual — no. invois ditaip staff/doktor
  manual_method TEXT CHECK (manual_method IN ('transfer','cash','other')),  -- kaedah bayaran manual (payment_method='manual')
  invoice_no TEXT UNIQUE,                     -- no. invois (INV-…) utk bayaran BUKAN pakej KOB — auto bila 'pending'/'completed'; bayaran KOB guna psy_kob_sessions.invoice_no
  bank_reference TEXT,                        -- no. rujukan transaksi bank / transfer (bayaran manual)
  recorded_by UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,  -- staf yg merekod bayaran manual (paid_at = tarikh bayaran SEBENAR; created_at = masa direkod)
  paid_for_type TEXT CHECK (paid_for_type IN ('package','installment','invoice','consultation','product','other')),  -- bayaran ni utk apa (bayaran manual)
  paid_for_seq INT,                           -- checkpoint ansuran yg dilunaskan (paid_for_type='installment')
  paid_for_ref TEXT,                          -- rujukan sasaran (cth invoice_no yg dilunaskan, paid_for_type='invoice')
  is_partial BOOLEAN NOT NULL DEFAULT false,  -- bayaran separa (kurang drpd baki sasaran) — dibenderakan
  receipt_no TEXT UNIQUE,                     -- no. resit paparan (REC10001..) — auto bila status jadi 'completed'; receipt_ref kekal kunci teknikal
  discount NUMERIC(10,2) NOT NULL DEFAULT 0,  -- diskaun pada bayaran ini (papar di resit; subtotal = total + discount)
  receipt_url TEXT,                           -- bayaran manual — resit yang di-upload
  notes TEXT,
  -- Ditambah 14 Okt 2026 — jualan walk-in (pembeli bukan pesakit, cth datang terus
  -- ke HQ). patient_id KEKAL NULL untuk baris ni; nama/telefon disimpan di sini
  -- (bukan psy_patients) sbb pembeli tiada akaun pesakit. Lihat roles/staff/jualan-walkin.html.
  buyer_name TEXT,
  buyer_phone TEXT,
  -- gateway bayaran (HitPay/Fiuu) — pending row dicipta sebelum redirect,
  -- webhook padankan gateway_ref & jalankan fulfillment ikut intent
  gateway_provider TEXT,                      -- 'hitpay' | 'fiuu' | NULL (manual)
  gateway_ref      TEXT,                      -- id rujukan dari gateway
  gateway_status   TEXT,                      -- status mentah dari gateway
  gateway_channel  TEXT,                      -- channel SEBENAR (fpx/card/paynow_online/dll) — diisi selepas webhook, lihat 20261014_payment_gateway_channel.sql
  checkout_url     TEXT,                      -- pautan checkout gateway (utk staff share/salin semula bila status pending)
  intent           JSONB DEFAULT '{}'::jsonb, -- niat bayaran utk fulfillment
  fulfilled_at     TIMESTAMPTZ,               -- bila fulfillment benar-benar jalan
  paid_at TIMESTAMPTZ DEFAULT now(),
  created_at TIMESTAMPTZ DEFAULT now()
);

-- No. resit paparan berjujukan — diberi sekali bila bayaran 'completed' (bukan masa 'pending' gateway, elak nombor terbuang).
CREATE SEQUENCE IF NOT EXISTS psy_receipt_no_seq START 10001;

CREATE OR REPLACE FUNCTION psy_assign_receipt_no() RETURNS trigger AS $$
BEGIN
  IF NEW.status = 'completed' AND NEW.receipt_no IS NULL THEN
    NEW.receipt_no := 'REC' || nextval('psy_receipt_no_seq');
  END IF;
  RETURN NEW;
END $$ LANGUAGE plpgsql;

-- Invois utk bayaran bukan-KOB (kedai, sambungan minggu, dll): jujukan dikongsi dgn invois pakej KOB.
CREATE SEQUENCE IF NOT EXISTS psy_invoice_no_seq START 1;

-- Audit management #F-23 (Tier 3→5, pisah Invoice/Receipt/Payment) — pautan ke psy_invoices
-- SEBENAR (jadual di hujung fail ni). Baris yg menyelesaikan invois tu TAK perlu invoice_no
-- sendiri (invois asal DAH ada nombor) — elak dua nombor invois berlainan rujuk benda sama.
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

DROP TRIGGER IF EXISTS trg_psy_assign_payment_invoice_no ON psy_payments;
CREATE TRIGGER trg_psy_assign_payment_invoice_no BEFORE INSERT OR UPDATE OF status ON psy_payments
  FOR EACH ROW EXECUTE FUNCTION psy_assign_payment_invoice_no();

DROP TRIGGER IF EXISTS trg_psy_assign_receipt_no ON psy_payments;
CREATE TRIGGER trg_psy_assign_receipt_no BEFORE INSERT OR UPDATE OF status ON psy_payments
  FOR EACH ROW EXECUTE FUNCTION psy_assign_receipt_no();

CREATE INDEX IF NOT EXISTS idx_psy_payments_patient ON psy_payments(patient_id);
CREATE INDEX IF NOT EXISTS idx_psy_payments_receipt ON psy_payments(receipt_ref);
CREATE INDEX IF NOT EXISTS idx_psy_payments_gateway_ref ON psy_payments (gateway_ref);

ALTER TABLE psy_payments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Patients read own payments" ON psy_payments;
CREATE POLICY "Patients read own payments" ON psy_payments FOR SELECT
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

-- pesakit hanya boleh insert baris bayaran MILIK SENDIRI
DROP POLICY IF EXISTS "Patients insert own payments" ON psy_payments;
CREATE POLICY "Patients insert own payments" ON psy_payments
  FOR INSERT WITH CHECK (
    patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid())
  );

DROP POLICY IF EXISTS "Staff manage all payments" ON psy_payments;
CREATE POLICY "Staff manage all payments" ON psy_payments FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

COMMENT ON COLUMN psy_payments.intent IS
  'Snapshot pendingItems + konteks bayaran; dibaca oleh payments-webhook untuk fulfillment idempotent selepas gateway sahkan.';

-- ──────────────────────────────────────────────────────────────
-- psy_payment_adjustments — Void/Refund/Correction workflow (audit #B1-24, 24 Sept 2026)
-- Transaksi kewangan tersalah TAK boleh dipadam terus — kena melalui rekod ni dgn
-- sebab+amount+approver. type='void' (transaksi tak sepatutnya wujud, status→'voided'),
-- 'refund' (bayaran sah, wang dipulangkan, status→'refunded'), 'correction'
-- (dokumentasi pembetulan — TAK ubah amount psy_payments terus, sbb amount berkait
-- invois/jadual ansuran KOB; staf betulkan rekod berkaitan secara manual selepas
-- catat sebab di sini).
-- ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS psy_payment_adjustments (
  id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  payment_id         UUID NOT NULL REFERENCES psy_payments(id) ON DELETE CASCADE,
  type               TEXT NOT NULL CHECK (type IN ('void','refund','correction')),
  reason             TEXT NOT NULL,
  amount             NUMERIC(10,2),  -- refund/correction; NULL utk void (batal penuh)
  requested_by       UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  requested_by_name  TEXT,
  requested_at       TIMESTAMPTZ DEFAULT now(),
  approved_by        UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  approved_by_name   TEXT,
  approved_at        TIMESTAMPTZ,
  status             TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected')),
  notes              TEXT,
  created_at         TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_payment_adj_payment ON psy_payment_adjustments(payment_id);
CREATE INDEX IF NOT EXISTS idx_payment_adj_status  ON psy_payment_adjustments(status, requested_at);

ALTER TABLE psy_payment_adjustments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff manage payment adjustments" ON psy_payment_adjustments;
CREATE POLICY "Staff manage payment adjustments" ON psy_payment_adjustments FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

COMMENT ON COLUMN psy_payment_adjustments.status IS
  'pending = menunggu kelulusan super_admin; approved = diluluskan & kesan diterapkan (psy_payments.status dikemaskini); rejected = ditolak, psy_payments tak berubah.';

-- ──────────────────────────────────────────────────────────────
-- psy_payment_status_log — Status Timeline (audit #B1-25/26, 24 Sept 2026)
-- Tambahan SEMATA-MATA (trigger auto-isi) — psy_payments.status tetap satu kolum
-- macam sedia ada, jadual ni cuma simpan SETIAP perubahan supaya boleh papar
-- "carta perjalanan" Created→Gateway/Manual→Verified→Paid/Failed/Refunded/Voided
-- kat UI. Bayaran SEDIA ADA (sebelum trigger dipasang) tiada sejarah — timeline
-- bermula dari bila migration ni run.
-- ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS psy_payment_status_log (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  payment_id  UUID NOT NULL REFERENCES psy_payments(id) ON DELETE CASCADE,
  old_status  TEXT,          -- NULL utk baris pertama (payment baru dicipta)
  new_status  TEXT NOT NULL,
  changed_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_payment_status_log_payment ON psy_payment_status_log(payment_id, changed_at);

ALTER TABLE psy_payment_status_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff read payment status log" ON psy_payment_status_log;
CREATE POLICY "Staff read payment status log" ON psy_payment_status_log FOR SELECT
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
-- Tiada INSERT/UPDATE/DELETE policy utk client — cuma trigger (SECURITY DEFINER) yg tulis.

CREATE OR REPLACE FUNCTION trg_log_payment_status()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO psy_payment_status_log (payment_id, old_status, new_status) VALUES (NEW.id, NULL, NEW.status);
  ELSIF TG_OP = 'UPDATE' AND NEW.status IS DISTINCT FROM OLD.status THEN
    INSERT INTO psy_payment_status_log (payment_id, old_status, new_status) VALUES (NEW.id, OLD.status, NEW.status);
  END IF;
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE LOG 'trg_log_payment_status: %', SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_log_payment_status ON psy_payments;
CREATE TRIGGER trg_log_payment_status
  AFTER INSERT OR UPDATE OF status ON psy_payments
  FOR EACH ROW EXECUTE FUNCTION trg_log_payment_status();

-- ──────────────────────────────────────────────────────────────
-- psy_receipts — Receipt DIPISAH dari Payment (audit #F-23, Tier 5).
-- Dulu psy_payments buat kerja invois+bayaran+resit SEKALI GUS dalam SATU baris
-- (receipt_no/receipt_url cuma kolum di atas). Jadual ni jamin secara STRUKTUR
-- (bukan sekadar konvensyen UI) yang resit CUMA wujud SELEPAS bayaran disahkan —
-- baris cuma boleh dicipta oleh trigger di bawah (SECURITY DEFINER), TIADA laluan
-- client INSERT langsung. Zero perubahan pada mana-mana laluan tulis psy_payments
-- sedia ada (webhook gateway, KOB, entri manual staf semua kekal sama).
-- ──────────────────────────────────────────────────────────────
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
-- Tiada INSERT/UPDATE/DELETE policy client — cuma trigger (SECURITY DEFINER) yg tulis.

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

-- ──────────────────────────────────────────────────────────────
-- psy_invoices — Invoice DIPISAH dari Payment (audit #F-23, Tier 5). Amaun
-- TERTUNGGAK yang boleh wujud SEBELUM sebarang percubaan bayaran — cth denda
-- tidak hadir (plan-week.html) yang dulu "menyamar" sebagai baris psy_payments
-- status='pending' (komen kod asal sendiri panggil ni "invois tertunggak").
-- Invois KOB (pakej/ansuran) SENGAJA TAK dipindah ke sini — kekal di
-- psy_kob_sessions.invoice_no + psy_kob_installment_checkpoints, yang sudah
-- berfungsi baik & disentuh banyak fail (kob.html/kob-detail.html/patient-hub.html
-- dll) — risiko tinggi sentuh tanpa faedah.
-- ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS psy_invoices (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  invoice_no  TEXT UNIQUE,
  patient_id  UUID NOT NULL REFERENCES psy_patients(id),
  description TEXT NOT NULL,
  amount      NUMERIC(10,2) NOT NULL CHECK (amount > 0),
  status      TEXT NOT NULL DEFAULT 'unpaid' CHECK (status IN ('unpaid','partially_paid','paid','void')),
  source_type TEXT,   -- cth 'absence_fee'
  source_ref  TEXT,   -- rujukan longgar (cth psy_plan_weekly_progress.id)
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

-- invoice_no auto — jujukan SAMA dgn psy_payments.invoice_no (satu rantaian nombor invois).
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

-- Pautan FK psy_payments.invoice_id → psy_invoices (kolum dah dicipta di atas,
-- constraint di sini sbb psy_invoices baru wujud sekarang).
ALTER TABLE psy_payments DROP CONSTRAINT IF EXISTS psy_payments_invoice_id_fkey;
ALTER TABLE psy_payments ADD CONSTRAINT psy_payments_invoice_id_fkey
  FOREIGN KEY (invoice_id) REFERENCES psy_invoices(id);
CREATE INDEX IF NOT EXISTS idx_psy_payments_invoice ON psy_payments(invoice_id);

-- Bila bayaran yg menyelesaikan invois berubah status (completed BARU, atau
-- lepas tu direfund/void), kira SEMULA baki dari SUM sebenar & kemaskini status
-- invois — jangan hanya "masuk paid" sekali dan lupa, supaya refund/void betul2
-- buka semula invois tu (bukan tinggal 'paid' walau duit dah dipulangkan).
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

-- ──────────────────────────────────────────────────────────────
-- psy_orders — pesanan produk pesakit (penghantaran bekalan)
-- ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS psy_orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_ref TEXT UNIQUE NOT NULL,
  patient_id UUID NOT NULL,
  items JSONB NOT NULL DEFAULT '[]',
  total NUMERIC(10,2) DEFAULT 0,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending','paid','packed','shipped','delivered','cancelled')),
  delivery_method TEXT DEFAULT 'pos' CHECK (delivery_method IN ('pickup','pos')),
  delivery_address TEXT,
  courier TEXT,
  tracking_number TEXT,
  tracking_photo_url TEXT,
  notes TEXT,
  paid_at TIMESTAMPTZ,
  packed_at TIMESTAMPTZ,
  shipped_at TIMESTAMPTZ,
  delivered_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE psy_orders ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Patient view own orders" ON psy_orders;
CREATE POLICY "Patient view own orders" ON psy_orders FOR SELECT
  USING (patient_id = auth.uid());

DROP POLICY IF EXISTS "Patient insert own orders" ON psy_orders;
CREATE POLICY "Patient insert own orders" ON psy_orders FOR INSERT
  WITH CHECK (patient_id = auth.uid());

DROP POLICY IF EXISTS "Patient confirm delivery" ON psy_orders;
CREATE POLICY "Patient confirm delivery" ON psy_orders FOR UPDATE
  USING (patient_id = auth.uid() AND status = 'shipped')
  WITH CHECK (status = 'delivered');

DROP POLICY IF EXISTS "Staff manage orders" ON psy_orders;
CREATE POLICY "Staff manage orders" ON psy_orders FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- Nota trigger pada psy_orders (diletak bersama fungsi masing-masing):
--   trg_psy_order_deduct_inventory → 14_products_inventory.sql
--   trg_notify_staff_new_order     → 18_notifications_automations.sql

-- ──────────────────────────────────────────────────────────────
-- psy_ghl_transactions — ledger RAW transaksi GHL (Laluan A, guna
-- GHL_ISW_TOKEN sahaja, TIADA akses Stripe secret diperlukan).
-- TUJUAN: reconciliation kewangan/accounting — BUKAN untuk paparan
-- sejarah bayaran pesakit (itu kekal psy_payments, diisi ghl-pull-sync
-- untuk yuran KOB sahaja). Jadual BERASINGAN sengaja — grain berbeza
-- (SEMUA transaksi lokasi, bukan sekadar yang lulus gate KOB) & elak
-- double-count rekod yang SAMA muncul di psy_payments (dari sudut
-- pandang GHL Transaction) DAN di sini (dari sudut pandang ledger
-- mentah) kalau digabung jadi satu jadual.
-- Diisi oleh supabase/functions/ghl-transactions-sync/index.ts.
-- ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS psy_ghl_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ghl_transaction_id TEXT UNIQUE NOT NULL,   -- GHL `_id`
  contact_id TEXT,
  contact_name TEXT,
  contact_email TEXT,
  patient_id UUID REFERENCES psy_patients(id),   -- padan ikut email bila boleh, NULL kalau tak jumpa
  amount NUMERIC(10,2) NOT NULL DEFAULT 0,   -- RM (unit manusia, BUKAN sen — GHL amount top-level dah RM)
  amount_refunded NUMERIC(10,2) DEFAULT 0,
  currency TEXT DEFAULT 'MYR',
  status TEXT,                               -- succeeded/failed/pending/dll (mentah GHL)
  payment_provider_type TEXT,                -- 'stripe' | 'manual' | lain
  entity_type TEXT,                          -- 'order' | 'invoice'
  entity_source_type TEXT,                   -- 'payment_link' | 'text2Pay' | dll
  entity_source_name TEXT,                   -- nama produk/invois
  entity_id TEXT,
  charge_id TEXT,                            -- Stripe payment_intent id (stripe sahaja, NULL kalau manual)
  payment_method_type TEXT,                  -- 'fpx' | 'card' | 'bank_transfer' | dll (derived, lihat sync fn)
  receipt_url TEXT,                          -- resit rasmi Stripe (stripe sahaja)
  invoice_number TEXT,                       -- cth "INV-000952" (entityType='invoice' sahaja, dari entitySourceMeta)
  issue_date TIMESTAMPTZ,                    -- tarikh invois DIISUKAN (BEZA dari ghl_created_at = bila transaksi/bayaran direkod; perlu panggilan /invoices/ berasingan, lihat sync fn)
  live_mode BOOLEAN,
  ghl_created_at TIMESTAMPTZ,                -- createdAt GHL (masa transaksi sebenar)
  ghl_updated_at TIMESTAMPTZ,
  fulfilled_at TIMESTAMPTZ,
  raw JSONB DEFAULT '{}'::jsonb,              -- objek PENUH GHL — safety net field yang terlepas
  synced_at TIMESTAMPTZ DEFAULT now(),
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ghl_tx_patient ON psy_ghl_transactions(patient_id);
CREATE INDEX IF NOT EXISTS idx_ghl_tx_contact ON psy_ghl_transactions(contact_id);
CREATE INDEX IF NOT EXISTS idx_ghl_tx_created ON psy_ghl_transactions(ghl_created_at);

ALTER TABLE psy_ghl_transactions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff manage ghl transactions" ON psy_ghl_transactions;
CREATE POLICY "Staff manage ghl transactions" ON psy_ghl_transactions FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- ──────────────────────────────────────────────────────────────
-- vw_payment_ledger — VIEW gabungan untuk accountant trace SEMUA
-- bayaran dalam SATU senarai (roles/staff/payment-ledger.html).
-- UNION psy_payments (sumber='ISW') + psy_ghl_transactions
-- (sumber='GHL') — DEDUP eksplisit: baris GHL yang `ghl_transaction_id`
-- dia DAH wujud dalam psy_payments (kes yuran KOB yang lulus gate
-- ghl-pull-sync) DIKECUALIKAN dari sisi GHL supaya bayaran yang SAMA
-- tak muncul dua kali. security_invoker=true — VIEW jalan ikut
-- kebenaran PEMANGGIL (RLS "Staff manage..." pada 2 jadual asal
-- terpakai terus), bukan pemilik view.
-- ──────────────────────────────────────────────────────────────
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

-- ──── psy_notifications: benarkan type 'payment' ────
-- GOTCHA (rujuk 27_affiliate.sql): jangan tulis semula senarai type inline
-- dalam CREATE TABLE — kekalkan semua nilai sedia ada + tambah 'payment'.
-- Dipakai oleh payments-webhook (notifyStaffPaymentReceived) supaya coach
-- + admin/manager dapat notifikasi loceng bila pesakit bayar apa-apa jenis
-- (pakej/KOB/temujanji/sambungan minggu), bukan sekadar shop_order.
DO $$
DECLARE
  v_types TEXT;
BEGIN
  SELECT COALESCE(string_agg(DISTINCT quote_literal(type), ','), '') INTO v_types
  FROM psy_notifications;

  IF v_types = '' THEN
    v_types := quote_literal('system');
  END IF;
  IF position('payment' in v_types) = 0 THEN
    v_types := v_types || ',' || quote_literal('payment');
  END IF;

  ALTER TABLE psy_notifications DROP CONSTRAINT IF EXISTS psy_notifications_type_check;
  EXECUTE format(
    'ALTER TABLE psy_notifications ADD CONSTRAINT psy_notifications_type_check CHECK (type IN (%s))',
    v_types
  );
END $$;
