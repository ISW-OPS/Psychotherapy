-- ============================================================
-- DROP ALL TABLES — ISW System
-- ⚠️ SEMUA DATA AKAN HILANG KEKAL
-- Run dalam Supabase SQL Editor sebelum run_all_migrations.sql
-- ============================================================

-- Drop triggers & functions
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS handle_new_user() CASCADE;
DROP FUNCTION IF EXISTS fn_complete_expired_treatments() CASCADE;
DO $$ BEGIN
  DROP TRIGGER IF EXISTS trg_psy_order_deduct_inventory ON psy_orders;
EXCEPTION WHEN undefined_table THEN NULL; END $$;
DROP FUNCTION IF EXISTS psy_order_deduct_inventory() CASCADE;

-- Drop ALL psy_* tables (CASCADE handles FK relations)
DROP TABLE IF EXISTS psy_adherence_alerts CASCADE;
DROP TABLE IF EXISTS psy_announcements CASCADE;
DROP TABLE IF EXISTS psy_appointments CASCADE;
DROP TABLE IF EXISTS psy_audit_log CASCADE;
DROP TABLE IF EXISTS psy_bottle_returns CASCADE;
DROP TABLE IF EXISTS psy_clinic_closures CASCADE;
DROP TABLE IF EXISTS psy_coaching_catalog CASCADE;
DROP TABLE IF EXISTS psy_coaching_sessions CASCADE;
DROP TABLE IF EXISTS psy_daily_checkins CASCADE;
DROP TABLE IF EXISTS psy_daily_completions CASCADE;
DROP TABLE IF EXISTS psy_dna_reports CASCADE;
DROP TABLE IF EXISTS psy_feedback CASCADE;
DROP TABLE IF EXISTS psy_feedback_weekly CASCADE;
DROP TABLE IF EXISTS psy_inventory_items CASCADE;
DROP TABLE IF EXISTS psy_inventory_requests CASCADE;
DROP TABLE IF EXISTS psy_kob_agreements CASCADE;
DROP TABLE IF EXISTS psy_kob_sessions CASCADE;
DROP TABLE IF EXISTS psy_kob_slot_config CASCADE;
DROP TABLE IF EXISTS psy_kyc_submissions CASCADE;
DROP TABLE IF EXISTS psy_lab_orders CASCADE;
DROP TABLE IF EXISTS psy_letter_auto_fields CASCADE;
DROP TABLE IF EXISTS psy_letter_issued CASCADE;
DROP TABLE IF EXISTS psy_letter_requests CASCADE;
DROP TABLE IF EXISTS psy_letter_template_files CASCADE;
DROP TABLE IF EXISTS psy_letter_template_overrides CASCADE;
DROP TABLE IF EXISTS psy_letter_templates CASCADE;
DROP TABLE IF EXISTS psy_library_items CASCADE;
DROP TABLE IF EXISTS psy_medical_reports CASCADE;
DROP TABLE IF EXISTS psy_notifications CASCADE;
DROP TABLE IF EXISTS psy_orders CASCADE;
DROP TABLE IF EXISTS psy_package_categories CASCADE;
DROP TABLE IF EXISTS psy_package_purchases CASCADE;
DROP TABLE IF EXISTS psy_packages CASCADE;
DROP TABLE IF EXISTS psy_patient_documents CASCADE;
DROP TABLE IF EXISTS psy_patient_notes CASCADE;
DROP TABLE IF EXISTS psy_patients CASCADE;
DROP TABLE IF EXISTS psy_payments CASCADE;
DROP TABLE IF EXISTS psy_plan_check_ins CASCADE;
DROP TABLE IF EXISTS psy_plan_compliance CASCADE;
DROP TABLE IF EXISTS psy_plan_weekly_progress CASCADE;
DROP TABLE IF EXISTS psy_prescriptions CASCADE;
DROP TABLE IF EXISTS psy_procedure_kits CASCADE;
DROP TABLE IF EXISTS psy_products CASCADE;
DROP TABLE IF EXISTS psy_profiles CASCADE;
DROP TABLE IF EXISTS psy_risk_alerts CASCADE;
DROP TABLE IF EXISTS psy_services CASCADE;
DROP TABLE IF EXISTS psy_slot_date_overrides CASCADE;
DROP TABLE IF EXISTS psy_soap_notes CASCADE;
DROP TABLE IF EXISTS psy_treatment_plans CASCADE;
DROP TABLE IF EXISTS psy_vitals CASCADE;
DROP TABLE IF EXISTS psy_weekly_feedback CASCADE;

-- ⚠️ CATCH-ALL: drop ANY remaining psy_* tables (dynamic)
DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN SELECT tablename FROM pg_tables WHERE schemaname='public' AND tablename LIKE 'psy_%' LOOP
    EXECUTE 'DROP TABLE IF EXISTS public.' || quote_ident(r.tablename) || ' CASCADE';
  END LOOP;
END $$;

-- ⚠️ DELETE auth.users — uncomment kalau nak reset SEMUA akaun login
-- DELETE FROM auth.users;

SELECT 'All ISW tables dropped — ready for run_all_migrations.sql' AS status;
