-- Generalize Sesi 1:1 (dulu Hakeema sahaja) kepada 3 jenis: Hakeema / Hakeem / Dr Session.
-- Ditanda terus sebagai checkbox ad-hoc di plan-week.html (bukan lagi pra-set di pakej-edit.html).

ALTER TABLE psy_clinical_referrals
  ADD COLUMN IF NOT EXISTS session_type TEXT CHECK (session_type IN ('hakeema','hakeem','dr'));

-- Rekod plan_1on1 sedia ada semuanya Hakeema (satu-satunya jenis sebelum ini).
UPDATE psy_clinical_referrals SET session_type = 'hakeema'
  WHERE source = 'plan_1on1' AND session_type IS NULL;

DROP INDEX IF EXISTS uq_psy_clinical_referrals_plan_1on1;
CREATE UNIQUE INDEX IF NOT EXISTS uq_psy_clinical_referrals_plan_1on1
  ON psy_clinical_referrals(plan_id, week_number, session_type) WHERE source = 'plan_1on1';
