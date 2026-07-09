-- STEP 85 — Templat mesej "Saranan Rujukan" boleh-edit oleh staff
-- ─────────────────────────────────────────────────────────────────────────
-- Sebelum ni mesej WhatsApp saranan (salam, "Berikut saranan daripada…",
-- baris tempoh, penutup) HARDCODED dalam rujukan-konsultasi.html — staff
-- kena minta developer untuk ubah ayat.
--
-- Kini ia jadi templat dalam psy_auto_messages (key='referral_saranan') yang
-- super_admin boleh edit sendiri via auto-mesej.html. Placeholder diganti oleh
-- kod: {nama} {pengesyor} {saranan} {tempoh} {tarikh}. Baris {tempoh}/{tarikh}
-- dibuang auto kalau tiada tempoh ikut diisi.
--
-- ON CONFLICT DO NOTHING — re-run tak akan tulis-ganti suntingan staff.
-- Idempotent. WAJIB run di TESTING & PRODUCTION.

INSERT INTO psy_auto_messages (key, name, description, channel, trigger_type, channels, audience, message_template, placeholders, is_active)
VALUES (
  'referral_saranan',
  'Saranan Rujukan (WhatsApp)',
  'Mesej yang dihantar ke pesakit selepas konsultasi rujukan (butang "Hantar ke WhatsApp"). Boleh edit ayat & susun placeholder.',
  'whatsapp',
  'on_action',
  '["whatsapp"]'::jsonb,
  '["patient"]'::jsonb,
  E'Salam {nama}, \U0001F44B\nBerikut saranan daripada {pengesyor} (Ibnu Sina Wellness):\n\n{saranan}\n\n⏱️ Sila ikut selama *{tempoh} hari* bermula {tarikh}.\n\nTerima kasih & semoga cepat sihat. \U0001F33F',
  '["{nama}","{pengesyor}","{saranan}","{tempoh}","{tarikh}"]'::jsonb,
  true
)
ON CONFLICT (key) DO NOTHING;

SELECT 'Step 85 OK — templat referral_saranan disemai' AS status;
