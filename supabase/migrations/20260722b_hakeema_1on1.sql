-- Sesi 1:1 Hakeema — auto-jana rujukan klinikal (psy_clinical_referrals) dari
-- week plan pesakit (cth minggu 6 & 11, atau bulanan/suku tahun ikut tanda
-- "hakeema_1on1" pada coaching_schedule pakej). Reuse enjin Rujukan sedia ada
-- (borang konsultasi, upload dokumen, auto-hantar WhatsApp saranan, follow-up).

ALTER TABLE psy_clinical_referrals
  ADD COLUMN IF NOT EXISTS plan_id     UUID REFERENCES psy_treatment_plans(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS week_number INT,
  ADD COLUMN IF NOT EXISTS source      TEXT NOT NULL DEFAULT 'manual';

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'psy_clinical_referrals_source_check'
  ) THEN
    ALTER TABLE psy_clinical_referrals
      ADD CONSTRAINT psy_clinical_referrals_source_check CHECK (source IN ('manual','plan_1on1'));
  END IF;
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS uq_psy_clinical_referrals_plan_1on1
  ON psy_clinical_referrals(plan_id, week_number) WHERE source = 'plan_1on1';
