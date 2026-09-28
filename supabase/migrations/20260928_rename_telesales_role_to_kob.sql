-- Rename legacy role code 'telesales' (label "KOB" di peranan.html, drives
-- Collector/Closer assign dropdown di roles/staff/kob-list.html/kob-detail.html)
-- -> 'kob', ikut niat asal reka bentuk (lihat komen "staff_role 'kob'" di
-- database/schema/09_kob.sql baris 34/38). Keputusan 28 Sept 2026.
--
-- Kebenaran (psy_role_module_actions) DIKEKALKAN apa adanya (~semua modul,
-- keputusan user 28 Sept — bukan direset ke set KOB-focus yg dirangka utk
-- role 'telesale' berasingan di 03_rbac_security.sql; 'telesale' tu kekal
-- tidak digunakan/orphan, tiada kaitan dgn rename ni).
--
-- Guna INSERT+UPDATE+DELETE (bukan UPDATE terus atas psy_roles.code) sebab
-- psy_role_module_actions.role_code ada FK ke psy_roles(code) TANPA
-- ON UPDATE CASCADE — UPDATE PK terus akan gagal dgn FK violation.
-- Idempotent — selamat di-run berulang kali (no-op lepas kali pertama).

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM psy_roles WHERE code = 'telesales')
     AND NOT EXISTS (SELECT 1 FROM psy_roles WHERE code = 'kob') THEN
    INSERT INTO psy_roles (code, label, description, color, icon, is_active, is_system, sort_order)
    SELECT 'kob', label, description, color, icon, is_active, is_system, sort_order
    FROM psy_roles WHERE code = 'telesales';
  END IF;
END $$;

UPDATE psy_role_module_actions SET role_code = 'kob' WHERE role_code = 'telesales';
UPDATE psy_profiles SET staff_role = 'kob' WHERE staff_role = 'telesales';

DELETE FROM psy_roles WHERE code = 'telesales';
