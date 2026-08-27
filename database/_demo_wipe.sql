-- ============================================================
-- WIPE DEMO/TESTING DATA — ISW System (TESTING project sahaja: ipmemyizigwgivccytcu)
-- Buang SEMUA data pesakit + segala yang terikat dengannya.
-- TIDAK sentuh: psy_profiles (akaun staff/coach), psy_roles/modules/RBAC,
-- psy_packages/coaching_catalog (katalog pakej), psy_settings, template/reference tables.
-- ============================================================

BEGIN;

TRUNCATE TABLE
  -- terus FK -> psy_patients
  psy_adherence_alerts,
  psy_affiliate_payouts,
  psy_appointments,
  psy_bottle_returns,
  psy_clinical_referrals,
  psy_coach_tasks,
  psy_coaching_sessions,
  psy_continuity_offers,
  psy_daily_checkins,
  psy_daily_completions,
  psy_dna_test_process,
  psy_emergency_alerts,
  psy_event_registrations,
  psy_feedback,
  psy_kepatuhan_log,
  psy_kepatuhan_weekly,
  psy_kob_agreements,
  psy_kob_installment_checkpoints,
  psy_kob_sessions,
  psy_letter_issued,
  psy_letter_requests,
  psy_medical_reports,
  psy_package_purchases,
  psy_patient_documents,
  psy_patient_event_visits,
  psy_patient_events,
  psy_patient_notes,
  psy_patient_reaksi_reports,
  psy_payments,
  psy_plan_check_ins,
  psy_plan_compliance,
  psy_plan_week_overrides,
  psy_plan_weekly_progress,
  psy_points_ledger,
  psy_promo_claims,
  psy_promo_redemptions,
  psy_reaksi_advice_log,
  psy_referrals,
  psy_risk_alerts,
  psy_supply_disbursements,
  psy_treatment_plans,
  psy_vitals,
  psy_vouchers,
  psy_wa_conversations,
  psy_weekly_feedback,
  -- cascade-children of the above (patient_events/medical_reports/wa_conversations)
  psy_patient_event_logs,
  psy_patient_event_docs,
  psy_medical_report_comments,
  psy_wa_messages,
  -- patient registration/instance data not directly FK'd but per-patient
  psy_kyc_submissions,
  psy_orders,
  -- operational logs not tied to a patient (staff restock requests)
  psy_inventory_requests,
  -- root table
  psy_patients
RESTART IDENTITY CASCADE;

COMMIT;

SELECT 'Demo/testing patient data wiped. Catalog, staff accounts, RBAC, settings untouched.' AS status;
