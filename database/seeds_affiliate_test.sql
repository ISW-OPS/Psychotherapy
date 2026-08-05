-- ═══════════════════════════════════════════════════════════════════
-- SEED: Data ujian Affiliate/Payout (roles/staff/affiliate.html)
-- Cipta 3 pasang pesakit (perujuk + dirujuk) untuk uji setiap state:
--   A → Sedia Diproses (qualified, belum ada payout)   → uji "Mulakan Bayaran"
--   B → Payout sedia ada status Diproses               → uji "✅ Selesai" & "Tolak"
--   C → Rujukan qualified, belum masuk payout          → uji "Cancel" (void)
-- Selamat run berkali-kali — buang dulu data ujian lama (ikut nama
-- 'TEST Affiliate%') sebelum insert semula. HANYA untuk testing DB.
-- ═══════════════════════════════════════════════════════════════════

BEGIN;

-- ──── Bersihkan data ujian lama (kalau pernah run sebelum ni) ────
DELETE FROM psy_affiliate_payouts WHERE patient_id IN (
  SELECT id FROM psy_patients WHERE full_name LIKE 'TEST Affiliate%'
);
DELETE FROM psy_referrals WHERE referrer_patient_id IN (
  SELECT id FROM psy_patients WHERE full_name LIKE 'TEST Affiliate%'
) OR referee_patient_id IN (
  SELECT id FROM psy_patients WHERE full_name LIKE 'TEST Affiliate%'
);
DELETE FROM psy_patients WHERE full_name LIKE 'TEST Affiliate%';

-- ──── Pesakit ujian (ID tetap supaya senang rujuk dlm insert seterusnya) ────
INSERT INTO psy_patients (id, full_name, phone, status, kob_status, created_by_staff, bank_name, bank_account_no, bank_account_holder)
VALUES
  ('aaaaaaaa-0000-0000-0000-000000000001', 'TEST Affiliate Perujuk A', '0110000001', 'active', 'na', true, 'Maybank',      '112233445566', 'Perujuk A'),
  ('aaaaaaaa-0000-0000-0000-000000000002', 'TEST Affiliate Dirujuk A', '0110000002', 'active', 'na', true, NULL, NULL, NULL),
  ('aaaaaaaa-0000-0000-0000-000000000003', 'TEST Affiliate Perujuk B', '0110000003', 'active', 'na', true, 'CIMB Bank',    '778899001122', 'Perujuk B'),
  ('aaaaaaaa-0000-0000-0000-000000000004', 'TEST Affiliate Dirujuk B', '0110000004', 'active', 'na', true, NULL, NULL, NULL),
  ('aaaaaaaa-0000-0000-0000-000000000005', 'TEST Affiliate Perujuk C', '0110000005', 'active', 'na', true, 'Public Bank',  '334455667788', 'Perujuk C'),
  ('aaaaaaaa-0000-0000-0000-000000000006', 'TEST Affiliate Dirujuk C', '0110000006', 'active', 'na', true, NULL, NULL, NULL);

-- ──── A: qualified, belum ada payout → "Sedia Diproses" ────
-- Test: klik "Mulakan Bayaran" (single) di tab Permohonan Bayaran.
INSERT INTO psy_referrals (id, referrer_patient_id, referee_patient_id, status, qualified_at, commission_amount)
VALUES (
  'aaaaaaaa-1111-0000-0000-000000000001',
  'aaaaaaaa-0000-0000-0000-000000000001',
  'aaaaaaaa-0000-0000-0000-000000000002',
  'qualified', now() - interval '2 days', 50.00
);

-- ──── B: qualified + payout sedia ada status Diproses ────
-- Test: klik "✅ Selesai" (jadi Dibayar) ATAU "Tolak" (unlock balik).
INSERT INTO psy_affiliate_payouts (id, patient_id, amount, status, bank_snapshot, requested_at)
VALUES (
  'bbbbbbbb-2222-0000-0000-000000000001',
  'aaaaaaaa-0000-0000-0000-000000000003',
  75.00, 'processing',
  jsonb_build_object('bank_name', 'CIMB Bank', 'bank_account_no', '778899001122', 'bank_account_holder', 'Perujuk B'),
  now() - interval '1 day'
);
INSERT INTO psy_referrals (id, referrer_patient_id, referee_patient_id, status, qualified_at, commission_amount, payout_id)
VALUES (
  'aaaaaaaa-1111-0000-0000-000000000002',
  'aaaaaaaa-0000-0000-0000-000000000003',
  'aaaaaaaa-0000-0000-0000-000000000004',
  'qualified', now() - interval '3 days', 75.00,
  'bbbbbbbb-2222-0000-0000-000000000001'
);

-- ──── C: qualified, belum ada payout → uji "Cancel" (void) ────
-- Test: klik "Cancel" di tab References (baris status "Layak").
INSERT INTO psy_referrals (id, referrer_patient_id, referee_patient_id, status, qualified_at, commission_amount)
VALUES (
  'aaaaaaaa-1111-0000-0000-000000000003',
  'aaaaaaaa-0000-0000-0000-000000000005',
  'aaaaaaaa-0000-0000-0000-000000000006',
  'qualified', now() - interval '1 day', 60.00
);

COMMIT;
