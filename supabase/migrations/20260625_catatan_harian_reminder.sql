-- =====================================================================
-- Mesej Automatik — sambung pencetus "Peringatan Catatan Harian"
-- ---------------------------------------------------------------------
-- Edge function event-reminders (runCatatanHarianReminder) hantar WA pada
-- send_at_time kpd pesakit aktif yang BELUM isi Catatan Harian hari itu.
-- Migrasi ini set jadual + saluran. Kekal is_active = FALSE — staff
-- aktifkan dari UI Mesej Automatik bila GHL sedia & sudah diuji.
-- Idempotent.
-- =====================================================================

update psy_auto_messages set
  days_of_week = coalesce(days_of_week, '[0,1,2,3,4,5,6]'::jsonb),  -- setiap hari
  send_at_time = coalesce(send_at_time, '20:00'::time),
  channels     = coalesce(channels, '["whatsapp"]'::jsonb),
  audience     = coalesce(audience, '["patient"]'::jsonb),
  message_template = E'Salam {nama} 👋\n\nKami perasan anda belum isi *Catatan Harian* hari ini. Luangkan 2 minit untuk rekod amalan & perasaan anda — konsistensi setiap hari membantu pemulihan anda lebih cepat. 🌱\n\nIsi sekarang di aplikasi Ibnu Sina Wellness.\n\n— Ibnu Sina Wellness',
  description  = 'Hantar WA kpd pesakit aktif yang belum isi Catatan Harian pada masa ditetapkan (cth 20:00). Dedup 1×/hari. Aktifkan di UI bila sedia.'
where key = 'catatan_harian';

select 'OK — catatan_harian reminder wired (is_active kekal seperti sedia ada)' as status;
