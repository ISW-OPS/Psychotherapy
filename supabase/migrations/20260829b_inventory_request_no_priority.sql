-- Tambah request_no (auto-generate PR-00001, ...) + priority (tinggi/sederhana/rendah)
-- pada psy_inventory_requests. Lihat database/schema/14_products_inventory.sql utk
-- versi sumber kebenaran + nota lengkap.

ALTER TABLE psy_inventory_requests ADD COLUMN IF NOT EXISTS request_no TEXT UNIQUE;
ALTER TABLE psy_inventory_requests ADD COLUMN IF NOT EXISTS priority TEXT NOT NULL DEFAULT 'sederhana';
ALTER TABLE psy_inventory_requests DROP CONSTRAINT IF EXISTS psy_inventory_requests_priority_check;
ALTER TABLE psy_inventory_requests ADD CONSTRAINT psy_inventory_requests_priority_check
  CHECK (priority IN ('tinggi','sederhana','rendah'));

CREATE SEQUENCE IF NOT EXISTS psy_inventory_request_no_seq START 1;

CREATE OR REPLACE FUNCTION psy_inventory_set_request_no()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.request_no IS NULL THEN
    NEW.request_no := 'PR-' || LPAD(nextval('psy_inventory_request_no_seq')::text, 5, '0');
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_psy_inventory_set_request_no ON psy_inventory_requests;
CREATE TRIGGER trg_psy_inventory_set_request_no
BEFORE INSERT ON psy_inventory_requests
FOR EACH ROW EXECUTE FUNCTION psy_inventory_set_request_no();

-- Backfill request_no utk baris sedia ada.
DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN SELECT id FROM psy_inventory_requests WHERE request_no IS NULL ORDER BY created_at LOOP
    UPDATE psy_inventory_requests
      SET request_no = 'PR-' || LPAD(nextval('psy_inventory_request_no_seq')::text, 5, '0')
      WHERE id = r.id;
  END LOOP;
END $$;
