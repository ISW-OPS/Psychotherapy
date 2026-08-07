-- Migration: contact_preference (Keutamaan Hubungan)
-- Additive only — new nullable/defaulted column, no changes to existing data.
-- Safe to re-run even if you already applied an earlier version of this file
-- (the old version allowed 'kedua-dua' too; that option has since been removed).
-- Run on testing (ipmemyiz) first, verify, then run on prod (xmvqvq).

ALTER TABLE psy_patients
  ADD COLUMN IF NOT EXISTS contact_preference TEXT DEFAULT 'pesakit';

ALTER TABLE psy_kyc_submissions
  ADD COLUMN IF NOT EXISTS contact_preference TEXT DEFAULT 'pesakit';

-- Constraint defined separately so re-running this file updates it even if
-- ADD COLUMN above was already a no-op from a previous run.
ALTER TABLE psy_patients
  DROP CONSTRAINT IF EXISTS psy_patients_contact_preference_check;
ALTER TABLE psy_patients
  ADD CONSTRAINT psy_patients_contact_preference_check
    CHECK (contact_preference IN ('pesakit','waris'));

ALTER TABLE psy_kyc_submissions
  DROP CONSTRAINT IF EXISTS psy_kyc_submissions_contact_preference_check;
ALTER TABLE psy_kyc_submissions
  ADD CONSTRAINT psy_kyc_submissions_contact_preference_check
    CHECK (contact_preference IN ('pesakit','waris'));

COMMENT ON COLUMN psy_patients.contact_preference IS
  'Siapa patut terima notifikasi/kemas kini (WhatsApp) pesakit ini: pesakit atau waris. Direkod sahaja setakat ini — belum digunakan oleh Edge Functions penghantaran WhatsApp.';

COMMENT ON COLUMN psy_kyc_submissions.contact_preference IS
  'Siapa patut terima notifikasi/kemas kini (WhatsApp) pesakit ini: pesakit atau waris.';
