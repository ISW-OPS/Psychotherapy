"""
Generate master_migration.sql — combines all step SQL files in correct order.
Run: python database/_generate_master.py
"""

import os

DB = os.path.join(os.path.dirname(__file__))

# ── Correct run order ─────────────────────────────────────────────────────────
# Numbered steps first (step27 moved before step25 — table must exist before data insert)
# step50/51 conflict resolved: package/treatment first, then library
NUMBERED = [
    "step1_profiles.sql",
    "step2_patients.sql",
    "step3_audit.sql",
    "step4_plans.sql",
    "step5_packages.sql",
    "step6_payments.sql",
    "step7_checkins.sql",
    "step8_library.sql",
    "step9_products.sql",
    "step10_announcements.sql",
    "step11_staff_roles.sql",
    "step12_library_media.sql",
    "step13_coach_assignment.sql",
    "step14_doctor_role.sql",
    "step15_kyc_extra_fields.sql",
    "step16_missing_tables.sql",
    "step17_inventory.sql",         # placeholder only
    "step18_reference_code.sql",
    "step19_kyc_patients_sync.sql",
    "step20_soft_delete.sql",
    "step21_unregistered_status.sql",
    "step22_session_type.sql",
    "step23_dna_reports.sql",
    "step24_session_notes.sql",
    "step27_inventory_tables.sql",  # CREATE TABLE — must come before step25
    "step25_inventory_items.sql",   # INSERT data — requires step27 table
    "step26_meet_link.sql",
    "step28_clinic_closures.sql",
    "step29_kyc_proxy.sql",
    "step30_outcome_status.sql",
    "step31_patient_self_vitals.sql",
    "step32_package_extensions.sql",
    "step33_madu_tracking.sql",
    "step34_kob.sql",
    "step35_kob_skip_payment.sql",
    "step36_kob_slots.sql",
    "step37_kob_questionnaire.sql",
    "step38_kob_package_recommendation.sql",
    "step39_package_agreement.sql",
    "step40_agreement_storage.sql",
    "step41_agreement_clauses.sql",
    "step42_kob_storage_buckets.sql",
    "step43_pakej_rujukan_storage.sql",
    "step44_daily_schedule.sql",
    "step45_seed_daily_schedule.sql",
    "step46_daily_completions.sql",
    "step47_slot_overhaul.sql",
    "step48_feedback_weekly.sql",
    "step49_library_package_filter.sql",
    "step50_package_categories.sql",   # step50 old (packages)
    "step50_library_topic_faq.sql",    # step50 new (library)
    "step51_treatment_completion.sql", # step51 old (treatment)
    "step51_library_editor_fields.sql",# step51 new (library)
    "step52_library_view_meta.sql",
    "step53_library_bookmark_feedback.sql",
    "step54_library_unique_views.sql",
    "step55_library_status.sql",
    "step56_patient_medical_upload.sql",
    "step57_medical_storage_policies.sql",
    "step58_library_categories.sql",
    "step59_faq_categories.sql",
    "step60_medical_records_v2.sql",
    "step61_whatsapp_inbox.sql",
    "step62_whatsapp_realtime.sql",
    "step63_wa_outbox_storage.sql",
    "step64_kepatuhan.sql",
    "step65_checkin_detail.sql",
    "step66_patient_dedup.sql",
]

# Unnumbered steps — patient/profile columns first, then features, then RBAC, then fixes
UNNUMBERED = [
    # Column additions (must be early — other steps may depend on these columns)
    "step_patients_created_by_staff.sql",
    "step_patients_missing_columns.sql",
    "step_profile_personal_fields.sql",
    "step_add_patients_updated_at.sql",
    "step_sessions_per_week.sql",
    # Feature tables / columns
    "step_adherence_alerts.sql",
    "step_bottle_returns.sql",
    "step_coaching_catalog.sql",
    "step_compliance_session_day.sql",
    "step_feedback_patient_meta.sql",
    "step_inventory_auto_po.sql",
    "step_inventory_auto_trigger.sql",
    "step_inventory_consumption_type.sql",
    "step_inventory_supplier_info.sql",
    # Letter / surat system
    "step_letter_base.sql",
    "step_letter_template_overrides.sql",
    "step_letter_files.sql",
    "step_letter_simple.sql",
    "step_letter_auto_fields.sql",
    "step_surat_template_v2.sql",
    "step_surat_approval.sql",
    # Package / plan extras
    "step_package_extension_price.sql",
    "step_package_meet_link.sql",
    "step_patient_address_residence.sql",
    "step_patient_hub_v2.sql",
    "step_plan_schedule_setup.sql",
    "step_plan_session_day.sql",
    "step_procedure_kits.sql",
    "step_product_inventory_link.sql",
    "step_products_enhanced.sql",
    "step_products_image_url.sql",
    "step_referral_system.sql",
    "step_session_notes_soap.sql",
    "step_sync_kyc_to_patient.sql",
    "step_vitals_link_to_week.sql",
    # RBAC system (sequential — each depends on previous)
    "step_rbac_01_permissions.sql",
    "step_rbac_02_seed_permissions.sql",
    "step_rbac_03_role_defaults.sql",
    "step_rbac_04_super_admin.sql",
    "step_rbac_05_v2_redesign.sql",
    "step_rbac_06_v2_seed.sql",
    "step_rbac_07_fix_fk_on_delete.sql",
    "step_rbac_08_fix_all_profile_fks.sql",
    "step_rbac_09_rename_modules.sql",
    # Surat RBAC tighten — must be after RBAC view (psy_user_effective_permissions) exists
    "step_surat_rbac_tighten.sql",
    # Cleanup / RLS fixes (run last so tables definitely exist)
    "step_cleanup_session_no.sql",
    "step_patient_plan_setup_rls.sql",
    "step_patient_docs_week_scope.sql",
    "step_fix_patient_mrn_autogen.sql",
    "step_fix_slot_rls_superadmin.sql",
    "step_create_avatars_bucket.sql",
    "step_agreement_delete_policy.sql",
]

FIX_FILES = [
    "fix_audit_policy.sql",
    "fix_coach_assignment.sql",
    "fix_issue_patient_read.sql",
    "fix_staff_delete_fk.sql",
    "fix_staff_rls.sql",
]

SEED_FILES = [
    "seed_default_agreement_clauses.sql",
    "seed_coaching_catalog_bimbingan.sql",
    "seed_letter_templates.sql",
]

# ── Generator ─────────────────────────────────────────────────────────────────

def read_file(name):
    path = os.path.join(DB, name)
    if not os.path.exists(path):
        print(f"  [SKIP — not found] {name}")
        return f"\n-- ⚠ FILE NOT FOUND: {name}\n"
    with open(path, encoding="utf-8") as f:
        content = f.read().strip()
    return f"\n-- ════════════════════════════════════════════════════════════════\n-- {name}\n-- ════════════════════════════════════════════════════════════════\n\n{content}\n"


def generate(out_name, files, header):
    out_path = os.path.join(DB, out_name)
    parts = [f"-- {header}\n-- Generated: {__import__('datetime').datetime.utcnow().isoformat()}Z\n-- Total files: {len(files)}\n-- Run this entire file in Supabase SQL Editor (new project).\n"]
    for f in files:
        parts.append(read_file(f))
    with open(out_path, "w", encoding="utf-8") as fh:
        fh.write("\n".join(parts))
    print(f"\nOK: Written {out_name} ({len(parts)-1} sections)")


print("Generating master_migration.sql ...")
generate(
    "master_migration.sql",
    NUMBERED + UNNUMBERED + FIX_FILES,
    "ISW System — master_migration.sql\nAll schema DDL in correct dependency order.\nSafe to run on empty Supabase project."
)

print("\nGenerating seeds.sql ...")
generate(
    "seeds.sql",
    SEED_FILES,
    "ISW System — seeds.sql\nReference / default data (not demo/test data).\nRun AFTER master_migration.sql."
)

# ── Chunked parts (run in order: part1 → part2 → part3 → part4) ──────────────
print("\nGenerating chunked parts ...")
generate(
    "part1_step01_10.sql",
    NUMBERED[0:10],
    "ISW — Part 1/4: Step 1-10\nRun first on empty Supabase project."
)
generate(
    "part2_step11_20.sql",
    NUMBERED[10:20],
    "ISW — Part 2/4: Step 11-20\nRun after part1_step01_10.sql."
)
generate(
    "part3_step21_30.sql",
    NUMBERED[20:30],
    "ISW — Part 3/4: Step 21-30\nRun after part2_step11_20.sql."
)
generate(
    "part4_step31_end.sql",
    NUMBERED[30:] + UNNUMBERED + FIX_FILES,
    "ISW — Part 4/4: Step 31+ plus all unnumbered + fixes\nRun after part3_step21_30.sql."
)

print("\nDone.")
