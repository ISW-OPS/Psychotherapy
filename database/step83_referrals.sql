-- ═══════════════════════════════════════════════════════════════
-- step83: Rujukan Pesakit (referral) — Jul 2026
-- Coach/staff rujuk pesakit kepada doctor / coach lain / manager
-- (Hakeem/Hakeema). Sasaran dipilih secara spesifik (target_id).
-- Notifikasi guna psy_notifications type 'referral'.
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS psy_referrals (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id       UUID NOT NULL REFERENCES psy_patients(id) ON DELETE CASCADE,
  referred_by      UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  referred_by_name TEXT,
  target_role      TEXT NOT NULL CHECK (target_role IN ('doctor','coach','manager')),
  target_id        UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  target_name      TEXT,
  reason           TEXT NOT NULL,
  priority         TEXT NOT NULL DEFAULT 'biasa' CHECK (priority IN ('biasa','segera')),
  status           TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','accepted','resolved','declined')),
  resolution_note  TEXT,
  created_at       TIMESTAMPTZ DEFAULT now(),
  updated_at       TIMESTAMPTZ DEFAULT now(),
  resolved_at      TIMESTAMPTZ
);

ALTER TABLE psy_referrals ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  CREATE POLICY "Staff manage referrals" ON psy_referrals FOR ALL
    USING      (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
    WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE INDEX IF NOT EXISTS idx_psy_referrals_target  ON psy_referrals(target_id, status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_psy_referrals_patient ON psy_referrals(patient_id, created_at DESC);

-- Benarkan jenis notifikasi 'referral'
DO $$ DECLARE r RECORD; BEGIN
  FOR r IN SELECT conname FROM pg_constraint
    WHERE conrelid = 'psy_notifications'::regclass AND contype = 'c'
      AND pg_get_constraintdef(oid) LIKE '%type%'
  LOOP EXECUTE 'ALTER TABLE psy_notifications DROP CONSTRAINT ' || quote_ident(r.conname); END LOOP;
END $$;
ALTER TABLE psy_notifications ADD CONSTRAINT psy_notifications_type_check
  CHECK (type IN ('appointment','order','plan','system','reaksi','kyc','referral'));

SELECT 'Step 83 OK -- psy_referrals + referral notif type' AS status;
