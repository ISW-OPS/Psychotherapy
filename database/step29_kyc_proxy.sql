-- ============================================================
-- step29_kyc_proxy.sql
-- Track whether KYC submission was filled by patient themselves
-- or by a representative (pewaris/keluarga) — for review attention.
-- ============================================================

ALTER TABLE psy_kyc_submissions
  ADD COLUMN IF NOT EXISTS submitted_by_proxy BOOLEAN NOT NULL DEFAULT false;

COMMENT ON COLUMN psy_kyc_submissions.submitted_by_proxy IS
  'true = wakil/keluarga isi borang ini (info mesti tepat & boleh disahkan dengan pesakit sebenar)';
