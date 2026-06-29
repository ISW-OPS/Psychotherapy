-- ════════════════════════════════════════════════════════════════
-- Buang ciri SOAP / Konsultasi (tak digunakan)
-- - Halaman consultation.html & session-notes.html sudah dipadam
-- - Modal SOAP dalam plan-week.html sudah dibuang
-- Semua DROP guna IF EXISTS supaya selamat dijalankan berulang.
-- ════════════════════════════════════════════════════════════════

-- 1) Jadual nota SOAP doktor (tiada FK masuk — selamat drop)
DROP TABLE IF EXISTS psy_soap_notes CASCADE;

-- 2) Kolum SOAP pada psy_plan_weekly_progress (eksklusif SOAP sahaja)
--    NOTA: homework_given DIKEKALKAN — ia kolum nota coach (Nota Mingguan), bukan SOAP.
ALTER TABLE psy_plan_weekly_progress DROP COLUMN IF EXISTS soap_subjective;
ALTER TABLE psy_plan_weekly_progress DROP COLUMN IF EXISTS soap_objective;
ALTER TABLE psy_plan_weekly_progress DROP COLUMN IF EXISTS soap_assessment;
ALTER TABLE psy_plan_weekly_progress DROP COLUMN IF EXISTS soap_plan;
ALTER TABLE psy_plan_weekly_progress DROP COLUMN IF EXISTS risk_flag;
ALTER TABLE psy_plan_weekly_progress DROP COLUMN IF EXISTS risk_note;
ALTER TABLE psy_plan_weekly_progress DROP COLUMN IF EXISTS notes_signed_at;
ALTER TABLE psy_plan_weekly_progress DROP COLUMN IF EXISTS notes_signed_by;
ALTER TABLE psy_plan_weekly_progress DROP COLUMN IF EXISTS notes_signed_by_name;

-- 3) Buang kebenaran RBAC berkaitan consultation (jika ada)
DELETE FROM psy_role_module_actions WHERE module_code = 'consultation';
DELETE FROM psy_module_actions      WHERE module_code = 'consultation';
DELETE FROM psy_modules             WHERE code        = 'consultation';

-- 4) Buang servis katalog "Consultation with Doctor" (yatim — tiada aliran tempahan)
DELETE FROM psy_services WHERE service_id = 'consultation';

SELECT 'OK — SOAP / Konsultasi dibuang' AS status;
