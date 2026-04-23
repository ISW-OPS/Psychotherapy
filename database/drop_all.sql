-- ============================================================
-- DROP ALL TABLES — ISW System
-- ⚠️ SEMUA DATA AKAN HILANG KEKAL
-- Run dalam Supabase SQL Editor
-- ============================================================

-- Drop trigger & function dulu
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS handle_new_user();

-- Tables baru (psy_ prefix)
DROP TABLE IF EXISTS psy_plan_compliance CASCADE;
DROP TABLE IF EXISTS psy_plan_weekly_progress CASCADE;
DROP TABLE IF EXISTS psy_plan_check_ins CASCADE;
DROP TABLE IF EXISTS psy_daily_checkins CASCADE;
DROP TABLE IF EXISTS psy_package_purchases CASCADE;
DROP TABLE IF EXISTS psy_packages CASCADE;
DROP TABLE IF EXISTS psy_payments CASCADE;
DROP TABLE IF EXISTS psy_orders CASCADE;
DROP TABLE IF EXISTS psy_products CASCADE;
DROP TABLE IF EXISTS psy_services CASCADE;
DROP TABLE IF EXISTS psy_library_items CASCADE;
DROP TABLE IF EXISTS psy_announcements CASCADE;
DROP TABLE IF EXISTS psy_notifications CASCADE;
DROP TABLE IF EXISTS psy_audit_log CASCADE;
DROP TABLE IF EXISTS psy_lab_orders CASCADE;
DROP TABLE IF EXISTS psy_prescriptions CASCADE;
DROP TABLE IF EXISTS psy_coaching_sessions CASCADE;
DROP TABLE IF EXISTS psy_kyc_submissions CASCADE;
DROP TABLE IF EXISTS psy_risk_alerts CASCADE;
DROP TABLE IF EXISTS psy_soap_notes CASCADE;
DROP TABLE IF EXISTS psy_vitals CASCADE;
DROP TABLE IF EXISTS psy_appointments CASCADE;
DROP TABLE IF EXISTS psy_treatment_plans CASCADE;
DROP TABLE IF EXISTS psy_patients CASCADE;
DROP TABLE IF EXISTS psy_profiles CASCADE;

-- Tables lama (tanpa prefix) — selamat kalau dah takde
DROP TABLE IF EXISTS plan_compliance CASCADE;
DROP TABLE IF EXISTS plan_weekly_progress CASCADE;
DROP TABLE IF EXISTS plan_check_ins CASCADE;
DROP TABLE IF EXISTS daily_checkins CASCADE;
DROP TABLE IF EXISTS package_purchases CASCADE;
DROP TABLE IF EXISTS packages CASCADE;
DROP TABLE IF EXISTS payments CASCADE;
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS products CASCADE;
DROP TABLE IF EXISTS services CASCADE;
DROP TABLE IF EXISTS library_items CASCADE;
DROP TABLE IF EXISTS announcements CASCADE;
DROP TABLE IF EXISTS notifications CASCADE;
DROP TABLE IF EXISTS audit_log CASCADE;
DROP TABLE IF EXISTS lab_orders CASCADE;
DROP TABLE IF EXISTS prescriptions CASCADE;
DROP TABLE IF EXISTS coaching_sessions CASCADE;
DROP TABLE IF EXISTS kyc_submissions CASCADE;
DROP TABLE IF EXISTS risk_alerts CASCADE;
DROP TABLE IF EXISTS soap_notes CASCADE;
DROP TABLE IF EXISTS vitals CASCADE;
DROP TABLE IF EXISTS appointments CASCADE;
DROP TABLE IF EXISTS treatment_plans CASCADE;
DROP TABLE IF EXISTS patients CASCADE;
DROP TABLE IF EXISTS profiles CASCADE;
