-- Audit management 23 Sept 2026, Tier 2 (#B2-4): saranan Sesi 1:1 perlu Next Action +
-- PIC + Due Date boleh dijejak sehingga selesai, bukan berhenti sebagai nota bebas.
-- Rujuk: database/schema/20_referrals.sql

ALTER TABLE psy_clinical_referrals ADD COLUMN IF NOT EXISTS next_action TEXT;
ALTER TABLE psy_clinical_referrals ADD COLUMN IF NOT EXISTS next_action_pic UUID REFERENCES psy_profiles(id) ON DELETE SET NULL;
ALTER TABLE psy_clinical_referrals ADD COLUMN IF NOT EXISTS next_action_due DATE;
ALTER TABLE psy_clinical_referrals ADD COLUMN IF NOT EXISTS next_action_done_at TIMESTAMPTZ;
