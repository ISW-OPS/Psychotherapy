-- ═══════════════════════════════════════════════════════════════
-- Sesi 1:1 — Follow-up auto-hantar (#17b) + Reminder harian per-saranan (#17c)
-- Audit 8 Okt 2026. Idempotent — selamat run berulang.
-- ═══════════════════════════════════════════════════════════════

-- #17b — dedup follow-up auto-hantar (cron event-reminders). follow_up_date/
-- follow_up_result/follow_up_note sendiri KEKAL dlm consultation JSONB (sedia
-- ada) — hanya timestamp "sudah auto-hantar" perlu kolum top-level supaya
-- query cron senang & cekap (bukan scan JSONB tiap baris).
ALTER TABLE psy_clinical_referrals ADD COLUMN IF NOT EXISTS follow_up_sent_at TIMESTAMPTZ;

-- #17c — reminder harian per-saranan (checkbox + <input type=time> di
-- sesi-1on1-detail.html). reminder_time = jam reminder dihantar setiap hari;
-- reminder_last_sent_date = dedup elak hantar >1x sehari.
ALTER TABLE psy_clinical_referrals ADD COLUMN IF NOT EXISTS reminder_time TIME;
ALTER TABLE psy_clinical_referrals ADD COLUMN IF NOT EXISTS reminder_last_sent_date DATE;
