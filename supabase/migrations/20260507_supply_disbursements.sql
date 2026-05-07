-- ── psy_supply_disbursements ──────────────────────────────────
-- Tracks items given to patients from inventory stock
CREATE TABLE IF NOT EXISTS psy_supply_disbursements (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id    UUID NOT NULL REFERENCES psy_patients(id) ON DELETE CASCADE,
  item_id       UUID REFERENCES psy_inventory_items(id) ON DELETE SET NULL,
  item_name     TEXT NOT NULL,
  unit          TEXT,
  qty           NUMERIC(10,2) NOT NULL,
  notes         TEXT,
  given_by      UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  given_by_name TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE psy_supply_disbursements ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "supply_disb_staff" ON psy_supply_disbursements;
CREATE POLICY "supply_disb_staff" ON psy_supply_disbursements
  FOR ALL USING (EXISTS (
    SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'
  ));
