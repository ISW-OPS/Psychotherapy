-- Konfig slot Sesi 1:1 (Hakeema/Hakeem/Dr) — hari beroperasi + jam pagi/petang + tempoh slot.
-- Baris tunggal (singleton, id=1). Diurus di kob-slots.html ("C. Slot Sesi 1:1"), dibaca
-- oleh shared/hk1.js (hk1GetSlots()) di sesi-1on1-form.html.
-- Jadual sendiri (bukan psy_settings) sebab psy_settings RLS kunci tulis kpd super_admin
-- sahaja — Sesi 1:1 config ni sepatutnya boleh diubah SEMUA staff (bukan super_admin sahaja).

CREATE TABLE IF NOT EXISTS psy_hk1_slot_config (
  id                     INT PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  days                   INT[] NOT NULL DEFAULT '{0,3,4,5,6}',
  pagi_start             TIME NOT NULL DEFAULT '09:00',
  pagi_end               TIME NOT NULL DEFAULT '12:00',
  petang_start           TIME NOT NULL DEFAULT '14:00',
  petang_end             TIME NOT NULL DEFAULT '17:00',
  slot_duration_minutes  INT NOT NULL DEFAULT 30,
  updated_at             TIMESTAMPTZ DEFAULT now(),
  updated_by             UUID REFERENCES psy_profiles(id) ON DELETE SET NULL
);

INSERT INTO psy_hk1_slot_config (id) VALUES (1) ON CONFLICT (id) DO NOTHING;

ALTER TABLE psy_hk1_slot_config ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff read hk1 slot config" ON psy_hk1_slot_config;
CREATE POLICY "Staff read hk1 slot config" ON psy_hk1_slot_config
  FOR SELECT USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "Staff manage hk1 slot config" ON psy_hk1_slot_config;
CREATE POLICY "Staff manage hk1 slot config" ON psy_hk1_slot_config FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
