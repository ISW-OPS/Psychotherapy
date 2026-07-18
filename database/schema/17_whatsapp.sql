-- ═══════════════════════════════════════════════════════════════════
-- 17 — WHATSAPP INBOX (cache GHL Conversations)
-- ISW jadi muka depan; GHL Conversations API sumber sebenar.
-- Edge Function `ghl-inbox` (service role) yang tulis; staff hanya SELECT.
-- Jadual: psy_wa_conversations, psy_wa_messages
-- ═══════════════════════════════════════════════════════════════════

-- ──── psy_wa_conversations — satu baris per perbualan GHL ────
CREATE TABLE IF NOT EXISTS psy_wa_conversations (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ghl_conversation_id  TEXT UNIQUE NOT NULL,
  ghl_contact_id       TEXT,
  contact_name         TEXT,
  phone_e164           TEXT,
  wa_number            TEXT,                 -- nombor talian mana mesej masuk
  last_message         TEXT,
  last_message_at      TIMESTAMPTZ,
  unread               INT DEFAULT 0,
  patient_id           UUID REFERENCES psy_patients(id) ON DELETE SET NULL, -- diisi bila phone padan
  synced_at            TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_wa_conv_last      ON psy_wa_conversations(last_message_at DESC);
CREATE INDEX IF NOT EXISTS idx_wa_conv_phone     ON psy_wa_conversations(phone_e164);
CREATE INDEX IF NOT EXISTS idx_wa_conv_patient   ON psy_wa_conversations(patient_id);

ALTER TABLE psy_wa_conversations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "staff_wa_conv_read" ON psy_wa_conversations;
CREATE POLICY "staff_wa_conv_read" ON psy_wa_conversations FOR SELECT
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- ──── psy_wa_messages — satu baris per mesej ────
CREATE TABLE IF NOT EXISTS psy_wa_messages (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ghl_message_id       TEXT UNIQUE,
  ghl_conversation_id  TEXT NOT NULL,
  direction            TEXT,                 -- 'inbound' / 'outbound'
  body                 TEXT,
  msg_type             TEXT DEFAULT 'whatsapp',
  sent_by              UUID,                 -- staff id ISW kalau dihantar dari ISW
  sent_by_name         TEXT,
  created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_wa_msg_conv ON psy_wa_messages(ghl_conversation_id, created_at ASC);

ALTER TABLE psy_wa_messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "staff_wa_msg_read" ON psy_wa_messages;
CREATE POLICY "staff_wa_msg_read" ON psy_wa_messages FOR SELECT
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- ──── Realtime — mesej baru muncul sendiri + badge unread live ────
DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE psy_wa_messages;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE psy_wa_conversations;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- REPLICA IDENTITY FULL supaya payload UPDATE bawa nilai lama (untuk kira unread)
ALTER TABLE psy_wa_messages      REPLICA IDENTITY FULL;
ALTER TABLE psy_wa_conversations REPLICA IDENTITY FULL;
