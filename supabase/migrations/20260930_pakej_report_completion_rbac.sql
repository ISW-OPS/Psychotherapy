-- Audit management batch 3 (30 Sept 2026) — Laporan Siap/Berhenti/Meninggal
-- per-pakej (pakej-laporan.html + pakej-report.html) kini guna outcome_status
-- sebenar (bukan status cetek). Coach & Doktor diberi akses 'view' modul
-- package/pakej_laporan (sebelum ni tiada langsung, tersekat RBAC).
-- Rujuk: database/schema/03_rbac_security.sql

INSERT INTO psy_role_module_actions (role_code, module_code, action_code)
SELECT 'doctor', m.code, 'view'
FROM (VALUES ('package'), ('pakej_laporan')) AS m(code)
ON CONFLICT DO NOTHING;

INSERT INTO psy_role_module_actions (role_code, module_code, action_code)
SELECT 'coach', m.code, 'view'
FROM (VALUES ('package'), ('pakej_laporan')) AS m(code)
ON CONFLICT DO NOTHING;
