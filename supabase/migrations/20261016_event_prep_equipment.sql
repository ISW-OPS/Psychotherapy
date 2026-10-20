-- Sambung Persediaan & Peralatan ke modul Equipment (psy_equipment — aset
-- bertag EQ-xxxx, berasingan dari psy_inventory_items yang pukal/konsumsi).
ALTER TABLE psy_event_prep_items DROP CONSTRAINT IF EXISTS psy_event_prep_items_source_check;
ALTER TABLE psy_event_prep_items ADD CONSTRAINT psy_event_prep_items_source_check
  CHECK (source IN ('inventory','manual','equipment'));

ALTER TABLE psy_event_prep_items
  ADD COLUMN IF NOT EXISTS equipment_id UUID REFERENCES psy_equipment(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_psy_event_prep_items_equipment ON psy_event_prep_items(equipment_id);
