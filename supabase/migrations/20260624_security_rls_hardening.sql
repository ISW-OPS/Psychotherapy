-- ════════════════════════════════════════════════════════════════
-- Security RLS hardening — 24 Jun 2026
-- Membaiki 2 kelemahan HIGH dari audit sistem:
--   1. psy_payments INSERT dulu WITH CHECK (true) → sesiapa boleh palsukan
--      rekod bayaran "completed" untuk MANA-MANA patient_id. Kini terhad
--      kepada patient_id milik pemanggil sahaja.
--   2. Storage 'medical-reports' INSERT dulu hanya semak pemanggil ialah
--      *seorang* pesakit, BUKAN bahawa folder sasaran (segmen path ke-2)
--      ialah id pesakit DIA sendiri → pesakit boleh tulis fail ke folder
--      perubatan pesakit lain. Kini wajib folder = id pesakit sendiri.
-- Idempotent: DROP dulu, kemudian CREATE semula.
-- Staff kekal boleh insert semua (polisi "Staff manage all payments" /
-- "Staff can upload medical reports" tidak disentuh).
-- ════════════════════════════════════════════════════════════════

-- 1) psy_payments: pesakit hanya boleh insert baris bayaran MILIK SENDIRI.
DROP POLICY IF EXISTS "Patients insert own payments" ON psy_payments;
CREATE POLICY "Patients insert own payments" ON psy_payments
  FOR INSERT WITH CHECK (
    patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid())
  );

-- 2) medical-reports: pesakit hanya boleh muat naik ke folder SENDIRI
--    (path = patient/<id_pesakit_sendiri>/...). Selaras dgn polisi baca.
DROP POLICY IF EXISTS "Patients can upload own medical reports" ON storage.objects;
CREATE POLICY "Patients can upload own medical reports" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'medical-reports'
    AND (storage.foldername(name))[1] = 'patient'
    AND EXISTS (
      SELECT 1 FROM psy_patients
      WHERE user_id = auth.uid() AND id::text = (storage.foldername(name))[2]
    )
  );

-- ────────────────────────────────────────────────────────────────
-- BELUM DIBAIKI DI SINI (perlu refactor app — flagged):
--   psy_notifications INSERT masih WITH CHECK (true) sebab notify() di
--   client menulis baris merentas-pengguna (cth pesakit surat.html
--   memberitahu staff signer). Untuk amankan dengan betul tanpa pecahkan
--   app, perlu fungsi SECURITY DEFINER create_notification(...) supaya
--   client tak boleh spoof sasaran sewenang-wenangnya. Risiko: spam/spoof
--   notifikasi (MEDIUM), bukan pendedahan data.
-- ════════════════════════════════════════════════════════════════
