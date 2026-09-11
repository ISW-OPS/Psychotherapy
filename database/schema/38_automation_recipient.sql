-- ═══════════════════════════════════════════════════════════════════
-- 38 — AUTOMATION MESSAGE RECIPIENT (patient | coach)
-- Bagi mesej sequence (psy_automation_messages) boleh ditujukan kepada
-- coach pesakit (cth eskalasi Sesi Confirm) bukan pesakit itu sendiri.
-- ═══════════════════════════════════════════════════════════════════

alter table psy_automation_messages
  add column if not exists recipient text not null default 'patient'
  check (recipient in ('patient', 'coach'));
