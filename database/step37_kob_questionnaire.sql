-- ============================================================
-- step37_kob_questionnaire.sql
-- Structured questionnaire for KOB session — doctor fills during consultation.
-- Stored as JSONB so we can evolve the question set without schema changes.
-- ============================================================

ALTER TABLE psy_kob_sessions
  ADD COLUMN IF NOT EXISTS questionnaire JSONB DEFAULT '{}';

COMMENT ON COLUMN psy_kob_sessions.questionnaire IS
  'Structured Q&A captured during KOB. Keys: anak[], tidur{}, gaya_hidup{}, masalah_kesihatan{} — see kob-detail.html for shape.';

SELECT 'Step 37 OK — KOB questionnaire column ready' AS status;
