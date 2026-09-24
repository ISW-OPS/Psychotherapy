-- Audit management 23 Sept 2026, Tier 5 (#H-35, #H-36) — kuatkuasa kapasiti
-- pendaftaran acara + keluarkan meet_link dari psy_events (RLS row-level tak
-- boleh sembunyi satu lajur sahaja — jadual berasingan supaya pesakit yang
-- BELUM daftar betul-betul tak dapat baca pautan Meet, bukan sekadar disorok
-- di UI). Rujuk: database/schema/19_events_announcements.sql

CREATE TABLE IF NOT EXISTS psy_event_meet_links (
  event_id   UUID PRIMARY KEY REFERENCES psy_events(id) ON DELETE CASCADE,
  meet_link  TEXT,
  updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE psy_event_meet_links ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff manage event meet links" ON psy_event_meet_links;
CREATE POLICY "Staff manage event meet links" ON psy_event_meet_links FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
  WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "Registered patients read meet link" ON psy_event_meet_links;
CREATE POLICY "Registered patients read meet link" ON psy_event_meet_links FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM psy_event_registrations r
    JOIN psy_patients p ON p.id = r.patient_id
    WHERE r.event_id = psy_event_meet_links.event_id
      AND p.user_id = auth.uid() AND r.status <> 'batal'
  ));

-- Backfill dari lajur lama SEBELUM dibuang
INSERT INTO psy_event_meet_links (event_id, meet_link)
SELECT id, meet_link FROM psy_events WHERE meet_link IS NOT NULL
ON CONFLICT (event_id) DO UPDATE SET meet_link = EXCLUDED.meet_link;

ALTER TABLE psy_events DROP COLUMN IF EXISTS meet_link;

-- #H-35 — kuatkuasa kapasiti pendaftaran acara (server-side, staf override dibenarkan)
CREATE OR REPLACE FUNCTION trg_enforce_event_capacity()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_capacity INT;
  v_count    INT;
  v_is_staff BOOLEAN;
BEGIN
  IF NEW.status = 'batal' THEN RETURN NEW; END IF;
  SELECT EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff') INTO v_is_staff;
  IF v_is_staff THEN RETURN NEW; END IF;

  SELECT capacity INTO v_capacity FROM psy_events WHERE id = NEW.event_id;
  IF v_capacity IS NULL THEN RETURN NEW; END IF;

  SELECT COUNT(*) INTO v_count FROM psy_event_registrations
    WHERE event_id = NEW.event_id AND status <> 'batal' AND id <> COALESCE(NEW.id, '00000000-0000-0000-0000-000000000000'::uuid);
  IF v_count >= v_capacity THEN
    RAISE EXCEPTION 'Acara ini telah penuh (kapasiti % peserta).', v_capacity;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_enforce_event_capacity ON psy_event_registrations;
CREATE TRIGGER trg_enforce_event_capacity
  BEFORE INSERT OR UPDATE ON psy_event_registrations
  FOR EACH ROW EXECUTE FUNCTION trg_enforce_event_capacity();
