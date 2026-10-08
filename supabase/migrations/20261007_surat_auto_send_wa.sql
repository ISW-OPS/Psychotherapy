-- ═══════════════════════════════════════════════════════════════════
-- Audit #143 — Surat: auto-hantar WhatsApp kepada pesakit lepas surat sedia
-- Rekod status penghantaran pada psy_letter_issued (lihat juga
-- database/schema/15_letters.sql + supabase/functions/letters-send-wa/index.ts).
-- ═══════════════════════════════════════════════════════════════════

ALTER TABLE psy_letter_issued ADD COLUMN IF NOT EXISTS wa_sent_at      TIMESTAMPTZ;
ALTER TABLE psy_letter_issued ADD COLUMN IF NOT EXISTS wa_send_status TEXT;

COMMENT ON COLUMN psy_letter_issued.wa_sent_at IS
  'Waktu mesej WhatsApp "surat sedia" berjaya dihantar kepada pesakit (letters-send-wa). NULL = belum/tak cuba.';
COMMENT ON COLUMN psy_letter_issued.wa_send_status IS
  'sent = WA berjaya hantar · failed = cuba tapi gagal (cth tiada no. telefon/GHL error) · NULL = belum cuba (surat internal, atau request lama sebelum ciri ni wujud).';
